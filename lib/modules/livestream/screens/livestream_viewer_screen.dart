/// 直播间观看页面
/// TikTok 风格全屏展示：顶部胶囊、底部图标栏、左下聊天面板、右下爱心动画
/// 支持弹幕Emoji、设置面板、主播退出拦截

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/modules/livestream/models/livestream.dart';
import 'package:im_client/modules/livestream/providers/livestream_provider.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/modules/livestream/screens/widgets/gift_panel.dart';
import 'package:im_client/modules/livestream/screens/widgets/danmaku_overlay.dart';
import 'package:im_client/modules/livestream/screens/widgets/gift_animation_overlay.dart';
import 'package:im_client/modules/livestream/screens/widgets/like_animation_overlay.dart';
import 'package:im_client/modules/livestream/screens/widgets/pk_overlay.dart';
import 'package:im_client/modules/livestream/screens/widgets/chat_panel.dart';
import 'package:im_client/modules/livestream/screens/widgets/paid_session_overlay.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:im_client/modules/livestream/screens/widgets/cohost_view.dart';
import 'package:im_client/modules/livestream/screens/widgets/cohost_view_tiktok.dart';
import 'package:im_client/modules/livestream/screens/livestream_replay_screen.dart';
import 'package:im_client/modules/livestream/api/livestream_api.dart';
import 'package:im_client/modules/livestream/services/cohost_service.dart';
import 'package:im_client/modules/livestream/services/paid_session_service.dart';
import 'package:im_client/modules/small_video/screens/creator_profile_screen.dart';
import 'package:im_client/modules/small_video/providers/small_video_provider.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/api/call_api.dart';
import 'package:im_client/api/moment_api.dart';
import 'package:im_client/modules/livestream/screens/livestream_share_sheet.dart';
import 'package:im_client/services/websocket_service.dart';
import 'package:im_client/services/storage_service.dart';
import 'package:im_client/modules/livestream/services/webrtc_publisher.dart';
import '../../../utils/image_proxy.dart';

class LivestreamViewerScreen extends StatefulWidget {
  final int livestreamId;
  final String? password;
  final bool isAnchor;
  final bool isActive;
  final void Function(int livestreamId)? onStreamEnded;

  const LivestreamViewerScreen({
    super.key,
    required this.livestreamId,
    this.password,
    this.isAnchor = false,
    this.isActive = true,
    this.onStreamEnded,
  });

  @override
  State<LivestreamViewerScreen> createState() => _LivestreamViewerScreenState();
}

class _LivestreamViewerScreenState extends State<LivestreamViewerScreen> {
  final TextEditingController _danmakuController = TextEditingController();
  final GlobalKey<DanmakuOverlayState> _danmakuKey = GlobalKey();
  LivestreamRoom? _room;
  bool _loading = true;
  bool _isFollowing = false;
  final GlobalKey<GiftAnimationOverlayState> _giftOverlayKey = GlobalKey();
  final GlobalKey<LikeAnimationOverlayState> _likeOverlayKey = GlobalKey();
  final GlobalKey<PKOverlayState> _pkOverlayKey = GlobalKey();
  final GlobalKey<ChatPanelState> _chatPanelKey = GlobalKey();
  final GlobalKey<PaidSessionOverlayState> _paidSessionOverlayKey = GlobalKey();
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  int _viewerCount = 0;
  int _likeCount = 0;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Timer? _videoRetryTimer;
  int _videoInitRetryCount = 0;
  String _activeVideoUrl = '';

  // PK state
  PKData? _pkData;
  List<Map<String, dynamic>> _pkTopA = []; // A方礼物贡献排行
  List<Map<String, dynamic>> _pkTopB = []; // B方礼物贡献排行

  // PK LiveKit state (所有用户都连接：主播publish+subscribe，观众subscribe-only)
  Room? _pkRoom;
  EventsListener<RoomEvent>? _pkRoomListener;
  List<CoHostInfo> _pkParticipants = [];
  bool _pkMicOn = true;
  bool _pkCamOn = true;
  bool _pkSpeakerOn = true; // 主播：是否播放对方音频（喇叭开关）
  bool _isEndingStream = false; // 防止主播结束直播时重复pop

  // Quality switching
  String _currentQuality = 'origin';
  Map<String, String> _qualityUrls = {};

  // Chat panel & danmaku
  bool _showChatPanel = true;
  bool _showDanmaku = true;

  // Camera/Mic control (anchor only)
  bool _isCameraOn = true;
  bool _isMicOn = true;

  // WebRTC local camera (anchor only)
  RTCVideoRenderer? _localRenderer;
  MediaStream? _localStream;
  String? _cameraError;

  // WebRTC Publisher for SRS (RTMP mode)
  WebRTCPublisher? _srsPublisher;

  // Entry banners
  final List<_EntryBanner> _entryBanners = [];

  // Gift combo tracking
  final List<_GiftCombo> _giftCombos = [];

  // Paid session
  int? _paidSessionId;
  bool _paidSessionActive = false;

  // 主播正在1v1付费通话中（其他观众暂停观看）
  bool _isInPaidCall = false;
  // 当前用户是付费通话参与方（发起方/主播方），不受暂停影响
  bool _isPaidCallParticipant = false;

  /// 获取有效付费通话费率: 直播间配置 > 默认100
  int get _effectivePaidCallRate => (_room?.paidCallRate ?? 0) > 0 ? _room!.paidCallRate : 100;

  // CoHost & PaidSession services
  CoHostService? _coHostService;
  PaidSessionService? _paidSessionService;
  List<CoHostInfo> _coHostInfos = [];
  bool _coHostMicOn = true; // 连麦时麦克风状态（本地即时响应）
  bool _coHostCamOn = true; // 连麦时摄像头状态（本地即时响应）
  int? _enlargedCoHostUserId; // TikTok风格连麦：当前放大的用户ID（null表示未放大）

  // 主播侧：远程静音覆盖状态（点击按钮后立即更新UI，无需等LiveKit信令回传）
  final Map<int, bool> _anchorMuteOverrides = {};

  // 连麦用户信息缓存（从WS通知中收集 nickname/avatar）
  final Map<int, ({String nickname, String avatar})> _coHostUserData = {};
  // 当前有效连麦成员（含主播，不含普通观众）
  final Set<int> _activeCoHostUserIds = <int>{};
  // 当前用户信息缓存（用于连麦fallback时显示自己的昵称/头像）
  String _myNickname = '';
  String _myAvatar = '';

  bool get _isCoHosting => _coHostService?.isCoHosting ?? false;

  // 观众端: 接收主播的远程流
  RTCPeerConnection? _viewerPC;
  RTCVideoRenderer? _remoteRenderer;
  MediaStream? _remoteStream;

  // 主播端: 每个观众一个 PeerConnection
  final Map<int, RTCPeerConnection> _viewerPeerConnections = {};
  final List<int> _pendingViewerRequests = []; // localStream 未就绪前缓冲

  // ICE 服务器配置
  List<Map<String, dynamic>> _iceServers = [
    {'urls': ['stun:stun.l.google.com:19302']}
  ];

  // WebRTC 模式标记 + 主播摄像头状态同步
  bool _webrtcMode = false;
  bool _anchorCameraOn = true;

  // 主播离线状态
  bool _hostOffline = false;
  int _hostOfflineCountdown = 90;
  Timer? _hostOfflineTimer;

  // 按分钟付费试看倒计时
  int _trialRemainingSeconds = 0;
  int _trialPricePerMin = 0;
  Timer? _trialTimer;
  bool _firstChargeNotified = false;

  // 门票制试看倒计时
  int _ticketPreviewDuration = 0;
  int _ticketPreviewRemaining = 0;
  Timer? _ticketPreviewTimer;

  // 缓存provider引用，避免dispose后访问context
  LivestreamProvider? _cachedProvider;

  // 是否已初始化（用于isActive延迟加载）
  bool _initialized = false;

  // 在线观众列表 key: userId
  final Map<int, _ViewerInfo> _onlineViewers = {};
  // 礼物累计 key: userId
  final Map<int, int> _viewerGiftTotals = {};

  // 房管系统
  final Set<int> _moderatorIds = {};     // 房管 userId 集合
  final Set<int> _pinnedViewers = {};    // 置顶用户（主播客户端维护，不持久化）
  bool _isMuted = false;                 // 当前用户是否被禁言
  int _myUserId = 0;                     // 当前用户ID

  /// 在线观众前3（置顶用户排最前，然后按礼物值降序）
  List<_ViewerInfo> get _topViewers {
    final sorted = _onlineViewers.values.toList()
      ..sort((a, b) {
        final aPinned = _pinnedViewers.contains(a.userId) ? 1 : 0;
        final bPinned = _pinnedViewers.contains(b.userId) ? 1 : 0;
        if (aPinned != bPinned) return bPinned - aPinned;
        return (_viewerGiftTotals[b.userId] ?? 0).compareTo(_viewerGiftTotals[a.userId] ?? 0);
      });
    return sorted.take(3).toList();
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    if (widget.isActive) {
      _activate();
    }
  }

  void _activate() {
    if (_initialized) return;
    _initialized = true;
    _loadMyUserId();
    _loadIceServers();
    _loadRoom();
    _setupWebSocketListener();
    // 注册强制登出清理回调
    _registerLogoutCallback();
    // 主播端：根据 stream_mode 决定是否初始化 WebRTC 推流
    // RTMP 模式下，主播使用 OBS 等工具推流，不需要初始化 WebRTC
    // WebRTC 模式下，主播使用浏览器直接推流
    // 注意：这里先加载房间信息，在 _loadRoom 中根据 stream_mode 决定
  }

  /// 注册强制登出清理回调
  void _registerLogoutCallback() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.registerLogoutCallback(() async {
      debugPrint('[直播] 检测到强制登出，执行清理...');
      await _cleanupOnForceLogout();
    });
  }

  /// 强制登出时的清理（停止推流、结束直播）
  Future<void> _cleanupOnForceLogout() async {
    if (!widget.isAnchor || _room == null) return;

    try {
      // 1. 停止 SRS 推流
      if (_srsPublisher != null) {
        debugPrint('[直播] 强制登出：停止 SRS 推流...');
        await _srsPublisher!.stopPublish();
        _srsPublisher = null;
      }

      // 2. 结束直播
      debugPrint('[直播] 强制登出：结束直播...');
      final provider = Provider.of<LivestreamProvider>(context, listen: false);
      await provider.endLivestream(widget.livestreamId);

      // 3. 清理本地资源
      _cleanupWebRTC();
    } catch (e) {
      debugPrint('[直播] 强制登出清理失败: $e');
    }
  }

  Future<void> _loadMyUserId() async {
    final uid = await StorageService().getUserId();
    if (uid != null && mounted) {
      setState(() => _myUserId = uid);
      _initInteractionServices();
    }
    // 缓存当前用户信息（用于连麦fallback）
    final userInfo = await StorageService().getUserInfo();
    if (userInfo != null && mounted) {
      _myNickname = userInfo.nickname.isNotEmpty ? userInfo.nickname : (userInfo.username.isNotEmpty ? userInfo.username : (AppLocalizations.of(context)?.meLabel ?? 'Me'));
      _myAvatar = userInfo.avatar;
    }
  }

  void _initInteractionServices() {
    _coHostService = CoHostService(livestreamId: widget.livestreamId, localUserId: _myUserId);
    _paidSessionService = PaidSessionService(livestreamId: widget.livestreamId, localUserId: _myUserId);
    _coHostService!.addListener(_onCoHostChanged);
    _paidSessionService!.addListener(_onPaidSessionChanged);
  }

  void _onCoHostChanged() {
    if (!mounted) return;
    final service = _coHostService!;
    final wasCoHosting = _coHostInfos.isNotEmpty;
    final anchorId = _room?.userId ?? 0;

    setState(() {
      if (anchorId > 0 && service.isCoHosting) {
        _activeCoHostUserIds.add(anchorId);
      }

      if (service.participants.isNotEmpty) {
        // 只展示真正连麦成员（主播 + 连麦嘉宾），过滤仅观看的 LiveKit 订阅者
        final cohostParticipants = service.participants.where((participant) {
          final uid = _parseUserIdFromIdentity(participant.identity);
          return _shouldDisplayCohostParticipant(participant, uid: uid, anchorId: anchorId);
        }).toList();

        // 清理已与 LiveKit 实际状态一致的 anchor 覆盖（避免覆盖阻止后续自行开麦）
        for (final participant in cohostParticipants) {
          final uid = _parseUserIdFromIdentity(participant.identity);
          if (_anchorMuteOverrides.containsKey(uid)) {
            final pub = participant.audioTrackPublications.firstOrNull;
            final livekitMuted = pub?.muted ?? false;
            if (livekitMuted == _anchorMuteOverrides[uid]) {
              _anchorMuteOverrides.remove(uid);
            }
          }
        }

        final allInfos = cohostParticipants.map((participant) {
          final uid = _parseUserIdFromIdentity(participant.identity);
          final isMe = uid == _myUserId;
          final cached = _coHostUserData[uid];
          final viewer = _onlineViewers[uid];
          final nickname = participant.name.isNotEmpty
              ? participant.name
              : isMe
                  ? (_myNickname.isNotEmpty ? _myNickname : (AppLocalizations.of(context)?.meLabel ?? 'Me'))
                  : (cached?.nickname ?? viewer?.nickname ?? '${AppLocalizations.of(context)?.defaultUser ?? 'User'}$uid');
          final avatar = isMe
              ? (_myAvatar.isNotEmpty ? _myAvatar : (cached?.avatar ?? ''))
              : (cached?.avatar ?? viewer?.avatar ?? '');
          return CoHostInfo(
            userId: uid,
            nickname: nickname,
            avatarUrl: avatar,
            participant: participant,
            isMutedOverride: _anchorMuteOverrides[uid],
          );
        }).toList();

        // 确保主播在第一位（TikTok风格连麦视图需要）
        if (anchorId > 0) {
          final anchorIndex = allInfos.indexWhere((info) => info.userId == anchorId);
          if (anchorIndex > 0) {
            final anchor = allInfos.removeAt(anchorIndex);
            allInfos.insert(0, anchor);
          } else if (anchorIndex < 0 && _activeCoHostUserIds.contains(anchorId)) {
            // 部分场景主播参与者未及时出现在 LiveKit：补齐主播卡片，避免主屏黑场
            final anchorViewer = _onlineViewers[anchorId];
            final anchorFallback = _coHostUserData[anchorId];
            allInfos.insert(
              0,
              CoHostInfo(
                userId: anchorId,
                nickname: anchorViewer?.nickname ?? anchorFallback?.nickname ?? (_room?.user?.nickname.isNotEmpty == true ? _room!.user!.nickname : (AppLocalizations.of(context)?.anchorLabel ?? 'Anchor')),
                avatarUrl: anchorViewer?.avatar ?? anchorFallback?.avatar ?? (_room?.user?.avatar ?? ''),
              ),
            );
          }
        }
        _coHostInfos = allInfos;
      } else if (service.isCoHosting && _coHostUserData.isNotEmpty) {
        // LiveKit 未连接但信令层连麦已建立: 从缓存数据构建（无视频，仅头像）
        final anchorData = anchorId > 0 ? _coHostUserData[anchorId] : null;

        _coHostInfos = [
          if (anchorId > 0)
            CoHostInfo(
              userId: anchorId,
              nickname: anchorData?.nickname ?? (_room?.user?.nickname ?? (AppLocalizations.of(context)?.anchorLabel ?? 'Anchor')),
              avatarUrl: anchorData?.avatar ?? (_room?.user?.avatar ?? ''),
            ),
          ..._coHostUserData.entries
              .where((e) => e.key != anchorId && _activeCoHostUserIds.contains(e.key))
              .map((e) => CoHostInfo(
                    userId: e.key,
                    nickname: e.value.nickname,
                    avatarUrl: e.value.avatar,
                  )),
        ];
      } else {
        _coHostInfos = [];
      }
    });

    // 连麦开始：暂停视频播放器 + 静音，释放音频会话给 LiveKit
    final isNowCoHosting = _coHostInfos.isNotEmpty || service.isCoHosting;
    if (!wasCoHosting && isNowCoHosting) {
      _videoController?.setVolume(0);
      _chewieController?.pause();
      _remoteStream?.getAudioTracks().forEach((t) => t.enabled = false);
      
      // 主播端：停止 SRS 推流，切换到 LiveKit 推流
      if (widget.isAnchor && _srsPublisher != null) {
        debugPrint('[直播] 连麦开始，停止 SRS 推流，切换到 LiveKit');
        _srsPublisher!.stopPublish().then((_) {
          _srsPublisher = null;
        });
      }
    }

    // 连麦结束后：恢复视频播放器，重置控制状态
    if (wasCoHosting && !service.isCoHosting) {
      _videoController?.setVolume(1);
      _chewieController?.play();
      _remoteStream?.getAudioTracks().forEach((t) => t.enabled = true);
      _coHostMicOn = true;
      _coHostCamOn = true;
      _coHostUserData.clear();
      _activeCoHostUserIds.clear();
      _anchorMuteOverrides.clear();
      if (widget.isAnchor && !_isMicOn) {
        setState(() => _isMicOn = true);
        _localStream?.getAudioTracks().forEach((t) => t.enabled = true);
      }
      
      // 主播端：连麦结束后重新启动 SRS 推流
      if (widget.isAnchor && _srsPublisher == null && _room != null) {
        debugPrint('[直播] 连麦结束，重新启动 SRS 推流');
        _initSRSPublisher();
      }
    }
  }

  void _onPaidSessionChanged() {
    if (!mounted) return;
    setState(() {
      _paidSessionActive = _paidSessionService?.isActive ?? false;
    });
  }

  void _deactivate() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _chewieController?.pause();
    _hostOfflineTimer?.cancel();
    _ticketPreviewTimer?.cancel();
    _trialTimer?.cancel();
    // 停止SRS推流
    _srsPublisher?.stopPublish();
    _cleanupWebRTC();
  }

  Future<void> _initLocalCamera() async {
    _localRenderer = RTCVideoRenderer();
    await _localRenderer!.initialize();
    try {
      // 尝试 audio+video
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user', 'width': 720, 'height': 1280},
      });
      _localRenderer!.srcObject = _localStream;
      if (mounted) setState(() { _cameraError = null; _isCameraOn = true; });
      // 处理在 localStream 就绪前到达的观众请求
      for (final viewerId in _pendingViewerRequests) {
        _createPeerConnectionForViewer(viewerId);
      }
      _pendingViewerRequests.clear();
    } catch (e) {
      debugPrint('Camera init error, falling back to audio-only: $e');
      // 摄像头失败 → 回退纯音频
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });
        _localRenderer!.srcObject = _localStream;
        if (mounted) setState(() { _cameraError = null; _isCameraOn = false; });
        // 处理在 localStream 就绪前到达的观众请求（音频模式）
        for (final viewerId in _pendingViewerRequests) {
          _createPeerConnectionForViewer(viewerId);
        }
        _pendingViewerRequests.clear();
      } catch (audioError) {
        debugPrint('Audio-only init also failed: $audioError');
        if (mounted) {
          setState(() => _cameraError = AppLocalizations.of(context)?.mediaInitFailed('$audioError') ?? 'Media init failed: $audioError');
        }
      }
    }
  }

  /// 初始化 SRS 推流（RTMP 模式）
  /// 使用 WebRTC 推流到 SRS，SRS 自动转换为 RTMP/HLS
  Future<void> _initSRSPublisher() async {
    if (_room == null) return;
    
    // 先停止旧的推流（如果存在）
    if (_srsPublisher != null) {
      debugPrint('[直播] 检测到旧的推流，先停止...');
      await _srsPublisher!.stopPublish();
      _srsPublisher = null;
      await Future.delayed(const Duration(milliseconds: 500)); // 等待清理完成
    }
    
    _localRenderer = RTCVideoRenderer();
    await _localRenderer!.initialize();
    
    _srsPublisher = WebRTCPublisher();
    
    try {
      // 使用Nginx代理的WebRTC API
      // 注意：需要确保Nginx配置了 /rtc/ 代理到 http://127.0.0.1:1985/rtc/
      final apiUrl = '${EnvConfig.instance.baseUrl}/rtc/v1/publish/';
      
      // 从provider获取push_key
      final provider = Provider.of<LivestreamProvider>(context, listen: false);
      final pushKey = provider.lastPushKey;
      
      debugPrint('[直播] 推流API: $apiUrl');
      debugPrint('[直播] stream_id: ${_room!.streamId}');
      debugPrint('[直播] push_key: ${pushKey ?? "(未设置)"}');
      
      final success = await _srsPublisher!.startPublish(
        streamId: _room!.streamId,
        apiUrl: apiUrl,
        pushKey: pushKey,
        audioOnly: false,
      );
      
      if (success) {
        // 获取本地流用于预览
        _localStream = _srsPublisher!.localStream;
        _localRenderer!.srcObject = _localStream;
        if (mounted) {
          setState(() {
            _cameraError = null;
            _isCameraOn = true;
          });
        }
        debugPrint('[直播] SRS 推流成功: $apiUrl');
      } else {
        if (mounted) {
          setState(() => _cameraError = '推流失败，请检查网络连接');
        }
      }
    } catch (e) {
      debugPrint('[直播] SRS 推流失败: $e');
      if (mounted) {
        setState(() => _cameraError = '推流失败: $e');
      }
    }
  }

  String _getFullImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return EnvConfig.instance.getFileUrl(url);
  }

  @override
  void didUpdateWidget(covariant LivestreamViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // 被激活
      if (!_initialized) {
        _activate();
      } else {
        // 已初始化过，恢复播放和WS
        _chewieController?.play();
        _setupWebSocketListener();
        if (!widget.isAnchor && _room != null) {
          _checkFollowing(_room!.userId);
        }
      }
    } else if (!widget.isActive && oldWidget.isActive) {
      // 被停用
      _deactivate();
    }
  }

  @override
  void dispose() {
    // 注销强制登出清理回调
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.registerLogoutCallback(null);
    } catch (e) {
      debugPrint('[直播] 注销登出回调失败: $e');
    }

    _wsSubscription?.cancel();
    _videoRetryTimer?.cancel();
    _chewieController?.dispose();
    _videoController?.dispose();
    _danmakuController.dispose();
    _localStream?.dispose();
    _localRenderer?.dispose();
    _hostOfflineTimer?.cancel();
    _trialTimer?.cancel();
    _ticketPreviewTimer?.cancel();
    // SRS 推流清理
    _srsPublisher?.stopPublish();
    _srsPublisher?.dispose();
    // 连麦中退出直播间：通知服务端结束连麦（fire-and-forget，仅发API不做本地清理）
    // 不调用 endCoHost() 以避免 dispose 后触发 notifyListeners
    if (_isCoHosting && _coHostService != null) {
      LivestreamApi(ApiClient()).endCoHost(widget.livestreamId).catchError((_) {});
    }
    _coHostService?.removeListener(_onCoHostChanged);
    _coHostService?.dispose();
    _paidSessionService?.removeListener(_onPaidSessionChanged);
    _paidSessionService?.dispose();
    // PK LiveKit 清理
    _pkRoomListener?.dispose();
    _pkRoom?.disconnect();
    _pkRoom?.dispose();
    _cleanupWebRTC();
    _leaveRoom();
    super.dispose();
  }

  Future<void> _loadRoom() async {
    final provider = Provider.of<LivestreamProvider>(context, listen: false);
    _cachedProvider = provider;
    final room = await provider.loadLivestream(widget.livestreamId);
    if (room != null) {
      setState(() {
        _room = room;
        _loading = false;
        _likeCount = room.likeCount;
        _qualityUrls = room.qualityUrls;
      });
      if (!widget.isAnchor) {
        // 观众端逻辑
        // 门票制付费直播：先检查权限
        if (room.isPaid) {
          final paidResult = await provider.joinPaidLivestream(
            widget.livestreamId,
            usePreview: room.allowPreview,
          );
          final allowed = paidResult['allowed'] as bool;
          final previewDur = paidResult['preview_duration'] as int;

          if (!allowed && previewDur <= 0) {
            // 无权进入（无票、无试看）→ 显示购票对话框
            if (mounted) {
              _showBuyTicketDialog(room);
            }
            return;
          }

          if (!allowed && previewDur > 0) {
            // 试看模式：记录试看时长，稍后启动倒计时
            _ticketPreviewDuration = previewDur;
          }
          // allowed=true 或试看模式 → 继续加入
        }

        // 加入直播间
        final joined = await provider.joinLivestream(widget.livestreamId, password: widget.password);
        if (!joined && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.error ?? (AppLocalizations.of(context)?.joinLivestreamFailed ?? 'Failed to join livestream'))),
          );
          Navigator.pop(context);
          return;
        }
        // 拉取当前所有在线观众，初始化列表和人数
        _loadOnlineViewers();
        // 根据系统推流模式决定播放方式。
        // 兜底：部分服务端版本未返回 stream_mode，导致客户端误判为 webrtc。
        final streamMode = _resolveStreamMode(provider.lastStreamMode, room);
        if (streamMode == 'webrtc') {
          // WebRTC P2P 模式
          _webrtcMode = true;
          _requestStream();
        } else {
          // RTMP 模式：使用真实拉流地址
          final urls = _resolvePlayablePullUrls(
            fallbackPullUrl: room.pullUrl,
            preferredQuality: _currentQuality,
          );
          if (urls.isNotEmpty) {
            _initVideoPlayer(urls.first, fallbackUrls: urls.skip(1).toList());
          }
        }
        // 门票制试看倒计时
        if (_ticketPreviewDuration > 0 && mounted) {
          _handleTicketPreviewEntered(room);
        }
        // 按分钟付费房间：客户端主动启动试看倒计时或显示计费提示
        if (room.roomType == 1 && mounted) {
          _handlePaidRoomEntered(room);
        }
      } else {
        // 主播端逻辑
        // 根据系统推流模式决定推流方式
        final streamMode = _resolveStreamMode(provider.lastStreamMode, room);
        _webrtcMode = (streamMode == 'webrtc');
        
        if (streamMode == 'webrtc') {
          // WebRTC P2P 模式：初始化本地摄像头，等待观众请求建立连接
          _initLocalCamera();
          debugPrint('[直播] WebRTC P2P 模式：等待观众连接');
        } else {
          // RTMP 模式：使用 WebRTC 推流到 SRS，SRS 自动转换为 RTMP/HLS
          // 主播端使用 WebRTC 推流（无需额外依赖），SRS 通过 rtc_to_rtmp 转换
          _initSRSPublisher();
          debugPrint('[直播] RTMP 模式：WebRTC 推流到 SRS，SRS 转换为 RTMP/HLS');
        }
      }
      _loadModerators();
      _loadOnlineViewers(); // 拉取当前在线观众列表（主播和观众统一初始化）
      _checkActivePK(); // 检查是否有活跃PK（迟到的观众也能看到PK状态）
      if (!widget.isAnchor && room.user != null) {
        _checkFollowing(room.userId);
      }
    } else {
      setState(() => _loading = false);
    }
  }

  void _initVideoPlayer(String pullUrl, {List<String> fallbackUrls = const []}) {
    if (pullUrl.isEmpty || pullUrl.contains('example.com')) return;
    final candidates = <String>[];
    for (final url in [pullUrl, ...fallbackUrls]) {
      if (url.isEmpty || url.contains('example.com') || candidates.contains(url)) continue;
      candidates.add(url);
    }
    if (candidates.isEmpty) return;
    _tryInitVideoPlayer(candidates, 0);
  }

  void _tryInitVideoPlayer(List<String> candidates, int index) {
    if (index >= candidates.length) {
      debugPrint('[直播] 所有拉流地址初始化失败: $candidates');
      // 兜底：RTMP 拉流全部失败时尝试请求 WebRTC（若主播端支持）
      if (!widget.isAnchor && !_webrtcMode) {
        _webrtcMode = true;
        _requestStream();
      }
      return;
    }

    final pullUrl = candidates[index];
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;

    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(pullUrl))
        ..initialize().then((_) {
          if (mounted) {
            _videoInitRetryCount = 0;
            _chewieController = ChewieController(
              videoPlayerController: _videoController!,
              autoPlay: true,
              showControls: false,
              aspectRatio: _videoController!.value.aspectRatio,
              errorBuilder: (context, errorMessage) {
                return Center(
                  child: Text(AppLocalizations.of(context)?.videoLoadFailed ?? 'Video load failed', style: const TextStyle(color: Colors.white54)),
                );
              },
            );
            setState(() {});
            debugPrint('[直播] 拉流初始化成功: $pullUrl');
          }
        }).catchError((e) {
          debugPrint('[直播] 拉流初始化失败: $pullUrl, error: $e');
          _tryInitVideoPlayer(candidates, index + 1);
        });
    } catch (e) {
      debugPrint('[直播] 拉流播放器创建失败: $pullUrl, error: $e');
      _tryInitVideoPlayer(candidates, index + 1);
    }
  }

  void _scheduleVideoRetryIfNeeded(String url) {
    final shouldRetry = mounted && kIsWeb && url.toLowerCase().contains('.m3u8');
    if (!shouldRetry) {
      return;
    }

    const maxRetries = 5;
    if (_videoInitRetryCount >= maxRetries) {
      debugPrint('[直播] HLS 播放重试达到上限($maxRetries)，停止重试: $url');
      return;
    }

    _videoInitRetryCount++;
    final delaySeconds = _videoInitRetryCount;
    debugPrint('[直播] HLS 初始化失败，${delaySeconds}s 后第 $_videoInitRetryCount 次重试: $url');
    _videoRetryTimer?.cancel();
    _videoRetryTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!mounted || _activeVideoUrl != url) {
        return;
      }
      _initVideoPlayer(url);
    });
  }

  /// 兼容历史脏数据：RTMP/SRS 模式下如果误保存成 m3u8，自动回退为 flv 地址
  String _normalizedRtmpPullUrl(String rawUrl) {
    if (rawUrl.isEmpty) return rawUrl;

    Uri? uri;
    try {
      uri = Uri.parse(rawUrl);
    } catch (_) {
      return rawUrl;
    }

    if (!uri.path.endsWith('.m3u8')) {
      return rawUrl;
    }

    final normalizedPath = uri.path.replaceFirst(RegExp(r'\.m3u8$'), '.flv');
    final normalizedUri = uri.replace(path: normalizedPath);
    final normalized = normalizedUri.toString();
    debugPrint('[直播] 检测到 RTMP 拉流地址为 m3u8，自动改写为 flv: $rawUrl -> $normalized');
    return normalized;
  }

  List<String> _resolvePlayablePullUrls({
    required String fallbackPullUrl,
    String? preferredQuality,
  }) {
    final candidates = <String>[];
    final quality = preferredQuality ?? _currentQuality;
    if (_qualityUrls[quality]?.isNotEmpty == true) {
      candidates.add(_qualityUrls[quality]!);
    }
    if (_qualityUrls['origin']?.isNotEmpty == true) {
      candidates.add(_qualityUrls['origin']!);
    }
    if (fallbackPullUrl.isNotEmpty) {
      candidates.add(fallbackPullUrl);
    }

    final resolved = <String>[];
    for (final raw in candidates) {
      final normalized = _normalizedRtmpPullUrl(raw);
      final webAdapted = _adaptWebFlvUrl(normalized);
      for (final u in [webAdapted, normalized, raw]) {
        if (u.isNotEmpty && !resolved.contains(u)) {
          resolved.add(u);
        }
      }
    }
    return resolved;
  }

  String _resolveStreamMode(String streamMode, LivestreamRoom room) {
    if (streamMode == 'rtmp' || streamMode == 'webrtc') {
      return streamMode;
    }
    final hasRtmpPull = room.pullUrl.isNotEmpty || room.qualityUrls.isNotEmpty;
    final resolved = hasRtmpPull ? 'rtmp' : 'webrtc';
    debugPrint('[直播] stream_mode 无效($streamMode)，按房间数据自动判定为: $resolved');
    return resolved;
  }

  /// Web 端 <video> 无法直接播放 FLV，优先改写为 HLS(m3u8)
  String _adaptWebFlvUrl(String url) {
    if (!kIsWeb || !url.toLowerCase().contains('.flv')) {
      return url;
    }
    try {
      final uri = Uri.parse(url);
      if (!uri.path.toLowerCase().endsWith('.flv')) {
        return url;
      }
      final path = uri.path.replaceFirst(RegExp(r'\.flv$', caseSensitive: false), '.m3u8');
      final hlsUrl = uri.replace(path: path).toString();
      debugPrint('[直播] Web 端检测到 FLV 拉流，自动改写为 HLS: $url -> $hlsUrl');
      return hlsUrl;
    } catch (_) {
      return url;
    }
  }

  // ==================== WebRTC P2P 推流 ====================

  Future<void> _loadIceServers() async {
    try {
      final api = CallApi(ApiClient());
      final res = await api.getIceServers();
      if (res.isSuccess && res.data is List) {
        final servers = (res.data as List)
            .map((s) => IceServer.fromJson(s as Map<String, dynamic>))
            .map((s) => s.toMap())
            .toList();
        if (servers.isNotEmpty) {
          _iceServers = servers;
        }
      }
    } catch (e) {
      debugPrint('Failed to load ICE servers: $e');
    }
  }

  /// 观众发送请求给主播，要求建立 WebRTC 推流
  void _requestStream() {
    if (_room == null) return;
    WebSocketService().send({
      'type': 'livestream_stream_signal',
      'data': {
        'to_user_id': _room!.userId,
        'signal_type': 'request',
        'livestream_id': widget.livestreamId,
      },
    });
  }

  /// 分发 livestream_stream_signal 子类型
  void _handleStreamSignal(Map<String, dynamic> data) {
    final signalType = data['signal_type'] as String? ?? '';
    final fromUserId = (data['from_user_id'] as num?)?.toInt() ?? 0;
    if (fromUserId <= 0) return;

    switch (signalType) {
      case 'request':
        // 主播收到观众请求
        if (widget.isAnchor) {
          if (_localStream == null) {
            // localStream 还没准备好，缓冲请求
            _pendingViewerRequests.add(fromUserId);
          } else {
            _createPeerConnectionForViewer(fromUserId);
          }
        }
        break;
      case 'offer':
        // 观众收到主播的 offer
        if (!widget.isAnchor) {
          _handleViewerOffer(fromUserId, data);
        }
        break;
      case 'answer':
        // 主播收到观众的 answer
        if (widget.isAnchor) {
          final pc = _viewerPeerConnections[fromUserId];
          if (pc != null) {
            final sdp = data['sdp'] as String? ?? '';
            pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
          }
        }
        break;
      case 'candidate':
        // 双方收到 ICE candidate
        final candidate = data['candidate'] as String? ?? '';
        final sdpMid = data['sdp_mid'] as String? ?? '';
        final sdpMLineIndex = (data['sdp_mline_index'] as num?)?.toInt() ?? 0;
        final iceCandidate = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
        if (widget.isAnchor) {
          _viewerPeerConnections[fromUserId]?.addCandidate(iceCandidate);
        } else {
          _viewerPC?.addCandidate(iceCandidate);
        }
        break;
      case 'camera_toggle':
        // 观众收到主播摄像头开关通知
        if (!widget.isAnchor) {
          final cameraOn = data['camera_on'] as bool? ?? true;
          if (mounted) setState(() => _anchorCameraOn = cameraOn);
        }
        break;
    }
  }

  /// 主播为某个观众创建 PeerConnection，添加本地流，发送 offer
  Future<void> _createPeerConnectionForViewer(int viewerUserId) async {
    if (_localStream == null) return;

    final config = {'iceServers': _iceServers};
    final pc = await createPeerConnection(config);
    _viewerPeerConnections[viewerUserId] = pc;

    // 添加本地流的所有 track
    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    // ICE candidate 回调
    pc.onIceCandidate = (candidate) {
      WebSocketService().send({
        'type': 'livestream_stream_signal',
        'data': {
          'to_user_id': viewerUserId,
          'signal_type': 'candidate',
          'candidate': candidate.candidate,
          'sdp_mid': candidate.sdpMid,
          'sdp_mline_index': candidate.sdpMLineIndex,
          'livestream_id': widget.livestreamId,
        },
      });
    };

    pc.onIceConnectionState = (state) {
      debugPrint('[Anchor] Viewer $viewerUserId ICE state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _closeViewerPeerConnection(viewerUserId);
      }
    };

    // 创建 offer 并发送
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    WebSocketService().send({
      'type': 'livestream_stream_signal',
      'data': {
        'to_user_id': viewerUserId,
        'signal_type': 'offer',
        'sdp': offer.sdp,
        'livestream_id': widget.livestreamId,
        'camera_on': _isCameraOn,
      },
    });
  }

  /// 观众收到主播 offer，创建 PC，设置远端描述，生成 answer
  Future<void> _handleViewerOffer(int fromUserId, Map<String, dynamic> data) async {
    final sdp = data['sdp'] as String? ?? '';
    final cameraOn = data['camera_on'] as bool? ?? true;

    // 初始化 remote renderer
    _remoteRenderer ??= RTCVideoRenderer();
    await _remoteRenderer!.initialize();

    // 关闭旧连接
    await _viewerPC?.close();

    final config = {'iceServers': _iceServers};
    _viewerPC = await createPeerConnection(config);

    _viewerPC!.onIceCandidate = (candidate) {
      WebSocketService().send({
        'type': 'livestream_stream_signal',
        'data': {
          'to_user_id': fromUserId,
          'signal_type': 'candidate',
          'candidate': candidate.candidate,
          'sdp_mid': candidate.sdpMid,
          'sdp_mline_index': candidate.sdpMLineIndex,
          'livestream_id': widget.livestreamId,
        },
      });
    };

    _viewerPC!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteRenderer!.srcObject = _remoteStream;
        if (mounted) setState(() {});
      }
    };

    _viewerPC!.onIceConnectionState = (state) {
      debugPrint('[Viewer] ICE state: $state');
    };

    // 设置远端描述（主播的 offer）
    await _viewerPC!.setRemoteDescription(
      RTCSessionDescription(sdp, 'offer'),
    );

    // 创建 answer
    final answer = await _viewerPC!.createAnswer();
    await _viewerPC!.setLocalDescription(answer);

    if (mounted) {
      setState(() => _anchorCameraOn = cameraOn);
    }

    WebSocketService().send({
      'type': 'livestream_stream_signal',
      'data': {
        'to_user_id': fromUserId,
        'signal_type': 'answer',
        'sdp': answer.sdp,
        'livestream_id': widget.livestreamId,
      },
    });
  }

  /// 主播关闭单个观众的 PeerConnection
  void _closeViewerPeerConnection(int userId) {
    final pc = _viewerPeerConnections.remove(userId);
    pc?.close();
  }

  /// 清理所有 WebRTC 资源
  void _cleanupWebRTC() {
    // 主播端：关闭所有观众 PC
    for (final pc in _viewerPeerConnections.values) {
      pc.close();
    }
    _viewerPeerConnections.clear();
    _pendingViewerRequests.clear();

    // 观众端：关闭 viewer PC，释放远程流
    _viewerPC?.close();
    _viewerPC = null;
    // 停止远程流的所有轨道并释放
    if (_remoteStream != null) {
      for (final track in _remoteStream!.getTracks()) {
        track.stop();
      }
      _remoteStream!.dispose();
    }
    _remoteStream = null;
    _remoteRenderer?.srcObject = null;
    _remoteRenderer?.dispose();
    _remoteRenderer = null;
  }

  Future<void> _checkFollowing(int anchorId) async {
    try {
      final provider = Provider.of<LivestreamProvider>(context, listen: false);
      final following = await provider.checkFollowing(anchorId);
      if (mounted) {
        setState(() => _isFollowing = following);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isFollowing = false);
      }
    }
  }

  Future<void> _loadModerators() async {
    try {
      final api = LivestreamApi(ApiClient());
      final res = await api.getModerators(widget.livestreamId);
      if (res.isSuccess && mounted) {
        final list = res.data as List? ?? [];
        setState(() {
          _moderatorIds.clear();
          for (final m in list) {
            final uid = (m['user_id'] as num?)?.toInt() ?? 0;
            if (uid > 0) _moderatorIds.add(uid);
          }
        });
      }
    } catch (_) {}
  }

  /// 拉取当前在线观众列表，初始化 _onlineViewers
  /// 注意：不设置 _viewerCount，人数由服务端 viewer_update WS推送统一管理（含虚拟机器人）
  Future<void> _loadOnlineViewers() async {
    try {
      final api = LivestreamApi(ApiClient());
      final res = await api.getViewers(widget.livestreamId, pageSize: 200);
      if (res.isSuccess && mounted) {
        final data = res.data as Map<String, dynamic>? ?? {};
        final list = data['list'] as List? ?? [];
        setState(() {
          for (final v in list) {
            final uid = (v['user_id'] as num?)?.toInt() ?? 0;
            if (uid <= 0) continue;
            // 真实观众: {user_id, user: {nickname, avatar}}
            // 虚拟机器人: {user_id, nickname, avatar, is_virtual}
            final user = v['user'] as Map<String, dynamic>?;
            final nickname = user?['nickname'] as String? ?? v['nickname'] as String? ?? '';
            final avatar = user?['avatar'] as String? ?? v['avatar'] as String? ?? '';
            _onlineViewers.putIfAbsent(uid, () => _ViewerInfo(
              userId: uid,
              nickname: nickname.isNotEmpty ? nickname : '${AppLocalizations.of(context)?.defaultUser ?? 'User'}$uid',
              avatar: avatar,
            ));
          }
        });
      }
    } catch (_) {}
  }

  /// 进入按分钟付费房间后，客户端主动启动试看倒计时或计费提示
  /// 不完全依赖服务端WS推送，确保UI即时响应
  void _handlePaidRoomEntered(LivestreamRoom room) {
    if (room.trialSeconds > 0) {
      // 有试看：立即启动客户端倒计时
      _trialTimer?.cancel();
      setState(() {
        _trialRemainingSeconds = room.trialSeconds;
        _trialPricePerMin = room.pricePerMin;
      });
      _trialTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) { timer.cancel(); return; }
        setState(() {
          _trialRemainingSeconds--;
        });
        if (_trialRemainingSeconds <= 0) {
          timer.cancel();
          if (mounted) {
            final l = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l?.paidWatchChargingStarted ?? '试看结束，开始计费'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      });
    } else {
      // 无试看：立即显示计费提示（服务端同时扣费，若余额不足会通过WS踢出）
      setState(() {
        _trialPricePerMin = room.pricePerMin;
      });
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l?.paidWatchChargingStarted ?? '已开始按分钟计费 (${room.pricePerMin}金豆/分钟)'),
          duration: const Duration(seconds: 3),
        ),
      );
      _firstChargeNotified = true;
    }
  }

  /// 门票制付费直播试看倒计时
  void _handleTicketPreviewEntered(LivestreamRoom room) {
    _ticketPreviewTimer?.cancel();
    setState(() {
      _ticketPreviewRemaining = _ticketPreviewDuration;
      // 复用试看UI变量
      _trialRemainingSeconds = _ticketPreviewDuration;
      _trialPricePerMin = 0; // 门票制不按分钟
    });
    _ticketPreviewTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _ticketPreviewRemaining--;
        _trialRemainingSeconds = _ticketPreviewRemaining;
      });
      if (_ticketPreviewRemaining <= 0) {
        timer.cancel();
        if (mounted) {
          _showBuyTicketOrLeaveDialog(room);
        }
      }
    });
  }

  /// 显示购票对话框（进入时无票无试看）
  void _showBuyTicketDialog(LivestreamRoom room) {
    setState(() => _loading = false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('付费直播'),
        content: Text('本直播需要购买门票\n门票价格: ${room.ticketPrice}金豆'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final provider = Provider.of<LivestreamProvider>(context, listen: false);
              final ok = await provider.buyTicket(widget.livestreamId);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('购票成功！')),
                );
                // 购票后重新加载
                setState(() => _loading = true);
                _loadRoom();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(provider.error ?? '购票失败，金豆余额不足')),
                );
                Navigator.of(context).pop();
              }
            },
            child: Text('购票 ${room.ticketPrice}金豆'),
          ),
        ],
      ),
    );
  }

  /// 试看结束：购票或离开
  void _showBuyTicketOrLeaveDialog(LivestreamRoom room) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('试看结束'),
        content: Text('试看时间已到，如需继续观看请购买门票\n门票价格: ${room.ticketPrice}金豆'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('离开'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final provider = Provider.of<LivestreamProvider>(context, listen: false);
              final ok = await provider.buyTicket(widget.livestreamId);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('购票成功！继续观看')),
                );
                setState(() {
                  _ticketPreviewDuration = 0;
                  _ticketPreviewRemaining = 0;
                  _trialRemainingSeconds = 0;
                });
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(provider.error ?? '购票失败，金豆余额不足')),
                );
                Navigator.of(context).pop();
              }
            },
            child: Text('购票 ${room.ticketPrice}金豆'),
          ),
        ],
      ),
    );
  }

  void _setupWebSocketListener() {
    _wsSubscription = WebSocketService().messageStream.listen((message) {
      final type = message['type'] as String?;
      if (type != null && type.startsWith('livestream_')) {
        _handleWebSocketMessage(message);
      }
    });
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (type == null) return;

    final data = message['data'] as Map<String, dynamic>?;
    if (data == null) return;

    // PK invite 是 SendToUser 消息，没有 livestream_id，需要特殊处理
    if (type == 'livestream_pk_invite' && widget.isAnchor) {
      _handlePKInvite(data);
      return;
    }
    // PK rejected 通知
    if (type == 'livestream_pk_rejected') {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final nickname = data?['nickname'] as String? ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nickname.isNotEmpty
              ? '$nickname ${l10n?.pkReject ?? 'rejected PK'}'
              : (l10n?.pkReject ?? 'PK rejected'))),
        );
      }
      return;
    }
    // PK LiveKit Token 是 SendToUser 消息，没有 livestream_id，需要在过滤前处理
    if (type == 'livestream_pk_token' && widget.isAnchor) {
      final pkToken = data['token'] as String? ?? '';
      final pkUrl = data['livekit_url'] as String? ?? '';
      if (pkToken.isNotEmpty && pkUrl.isNotEmpty) {
        _connectPKRoom(pkUrl, pkToken, canPublish: true);
      }
      return;
    }

    final lsId = data['livestream_id'];
    if (lsId != widget.livestreamId) {
      if (type?.startsWith('livestream_pk') == true) {
        debugPrint('[PK] WS message FILTERED OUT: type=$type, lsId=$lsId (${lsId.runtimeType}) != widget.livestreamId=${widget.livestreamId} (${widget.livestreamId.runtimeType})');
      }
      return;
    }

    switch (type) {
      case 'livestream_danmaku':
        // 文字消息只显示在聊天面板，不显示在弹幕
        final content = data['content'] as String? ?? '';
        final nickname = data['nickname'] as String? ?? '';
        final avatar = data['avatar'] as String? ?? '';
        final color = data['color'] as String?;
        Color danmakuColor = Colors.white;
        if (color != null && color.startsWith('#') && color.length == 7) {
          try {
            danmakuColor = Color(int.parse('FF${color.substring(1)}', radix: 16));
          } catch (_) {}
        }
        _chatPanelKey.currentState?.addMessage(
          nickname.isNotEmpty ? nickname : (AppLocalizations.of(context)?.defaultUser ?? 'User'),
          content,
          avatar: avatar,
          color: danmakuColor,
        );
        break;

      case 'livestream_gift':
        final giftName = data['gift_name'] as String? ?? '';
        // Resolve localized gift name from i18n JSON
        String resolvedGiftName = giftName;
        final giftNameI18n = data['gift_name_i18n'];
        if (giftNameI18n != null && giftNameI18n is String && giftNameI18n.isNotEmpty) {
          try {
            final i18nMap = json.decode(giftNameI18n) as Map<String, dynamic>;
            final loc = AppLocalizations.of(context);
            final lang = loc?.locale.languageCode ?? 'zh';
            final country = loc?.locale.countryCode;
            final langCode = (country != null && country.isNotEmpty)
                ? '${lang}_${country.toLowerCase()}'
                : lang;
            resolvedGiftName = (i18nMap[langCode] as String?) ??
                               (langCode.contains('_') ? (i18nMap[langCode.split('_').first] as String?) : null) ??
                               (i18nMap['en'] as String?) ??
                               giftName;
          } catch (_) {}
        }
        final senderName = data['sender_name'] as String? ?? '${AppLocalizations.of(context)?.defaultUser ?? 'User'}${data['sender_id']}';
        final senderAvatar = data['sender_avatar'] as String?;
        final senderId = (data['sender_id'] as num?)?.toInt() ?? 0;
        final giftPrice = (data['gift_price'] as num?)?.toInt() ?? 0;
        final giftCount = (data['count'] as num?)?.toInt() ?? 1;
        final giftData = GiftAnimationData.fromAnimationString(
          data['animation_type'] as String? ?? data['gift_animation'] as String? ?? 'banner',
          giftName: resolvedGiftName,
          giftIcon: data['gift_icon'] as String? ?? '',
          count: giftCount,
          senderName: senderName,
          senderAvatar: senderAvatar,
          price: giftPrice,
          isSpecial: data['is_special'] as bool? ?? false,
          tier: (data['tier'] as num?)?.toInt() ?? 1,
          comboEnabled: data['combo_enabled'] as bool? ?? false,
          animationDuration: (data['animation_duration'] as num?)?.toInt() ?? 3000,
          senderId: senderId,
          effectUrl: data['effect_url'] as String? ?? '',
        );
        _giftOverlayKey.currentState?.showGift(giftData);
        // 记录观众礼物数据（用于排行显示）
        if (senderId > 0) {
          _viewerGiftTotals[senderId] = (_viewerGiftTotals[senderId] ?? 0) + giftPrice * giftCount;
          _onlineViewers.putIfAbsent(senderId, () => _ViewerInfo(
            userId: senderId,
            nickname: senderName,
            avatar: senderAvatar ?? '',
          ));
          // 连刷礼物追踪（3个以上特殊显示）
          _trackGiftCombo(senderId, senderName, senderAvatar ?? '', resolvedGiftName, giftCount);
          if (mounted) setState(() {});
        }
        // 礼物事件显示在弹幕
        if (_showDanmaku) {
          _danmakuKey.currentState?.addDanmaku(
            AppLocalizations.of(context)?.giftSentDanmaku(senderName, resolvedGiftName, giftCount) ?? '$senderName sent $resolvedGiftName x$giftCount',
            color: Colors.orange,
          );
        }
        break;

      case 'livestream_viewer_update':
        final count = (data['viewer_count'] as num?)?.toInt() ?? 0;
        if (mounted) {
          setState(() => _viewerCount = count);
        }
        break;

      case 'livestream_user_join':
        final joinUid = (data['user_id'] as num?)?.toInt() ?? 0;
        final nickname = data['nickname'] as String? ?? '';
        final joinAvatar = data['avatar'] as String? ?? '';
        // 记录在线观众
        if (joinUid > 0) {
          _onlineViewers[joinUid] = _ViewerInfo(
            userId: joinUid,
            nickname: nickname.isNotEmpty ? nickname : '${AppLocalizations.of(context)?.defaultUser ?? 'User'}$joinUid',
            avatar: joinAvatar,
          );
          if (mounted) setState(() {});
        }
        if (nickname.isNotEmpty) {
          if (_showDanmaku) {
            _danmakuKey.currentState?.addDanmaku(
              AppLocalizations.of(context)?.enteredLivestream(nickname) ?? '$nickname joined',
              color: Colors.amber,
            );
          }
          _addEntryBanner(nickname);
        }
        break;

      case 'livestream_user_leave':
        final leaveUid = (data['user_id'] as num?)?.toInt() ?? 0;
        final nickname = data['nickname'] as String? ?? '';
        if (leaveUid > 0) {
          _onlineViewers.remove(leaveUid);
          // 主播端清理该观众的 PeerConnection
          if (widget.isAnchor) {
            _closeViewerPeerConnection(leaveUid);
          }
          if (mounted) setState(() {});
        }
        if (nickname.isNotEmpty && _showDanmaku) {
          _danmakuKey.currentState?.addDanmaku(
            AppLocalizations.of(context)?.leftLivestream(nickname) ?? '$nickname left',
            color: Colors.white54,
          );
        }
        break;

      case 'livestream_like':
        final count = (data['like_count'] as num?)?.toInt();
        final likerName = data['nickname'] as String? ?? '';
        if (count != null && mounted) {
          setState(() => _likeCount = count);
        }
        _likeOverlayKey.currentState?.addLike();
        // 点赞事件显示在弹幕
        if (likerName.isNotEmpty && _showDanmaku) {
          _danmakuKey.currentState?.addDanmaku(
            AppLocalizations.of(context)?.userLiked(likerName) ?? '$likerName liked',
            color: Colors.pinkAccent,
          );
        }
        break;

      case 'livestream_pk_start':
        if (mounted) {
          final avatarA = data['avatar_a'] as String? ?? '';
          final avatarB = data['avatar_b'] as String? ?? '';
          debugPrint('[PK] pk_start received: avatarA="$avatarA", avatarB="$avatarB", '
              'userIdA=${data['user_id_a']}, userIdB=${data['user_id_b']}, '
              'nicknameA=${data['nickname_a']}, nicknameB=${data['nickname_b']}');
          setState(() {
            _pkData = PKData(
              pkId: (data['pk_id'] as num?)?.toInt() ?? 0,
              userIdA: (data['user_id_a'] as num?)?.toInt() ?? 0,
              userIdB: (data['user_id_b'] as num?)?.toInt() ?? 0,
              anchorNameA: data['nickname_a'] as String? ?? 'A',
              anchorNameB: data['nickname_b'] as String? ?? 'B',
              avatarA: avatarA,
              avatarB: avatarB,
              scoreA: 0,
              scoreB: 0,
              duration: (data['duration'] as num?)?.toInt() ?? 180,
              remaining: (data['remaining'] as num?)?.toInt() ?? (data['duration'] as num?)?.toInt() ?? 180,
            );
          });
          // PK开始系统消息
          final l10n = AppLocalizations.of(context);
          _chatPanelKey.currentState?.addMessage(
            l10n?.systemLabel ?? 'System',
            '${l10n?.pkStarted ?? 'PK Started'}: ${data['nickname_a'] ?? 'A'} VS ${data['nickname_b'] ?? 'B'}',
            isSystem: true,
          );
          // 所有用户请求PK Token并连接LiveKit（观众subscribe-only，主播等WS token）
          if (!widget.isAnchor) {
            _requestPKTokenAndConnect();
          }
        }
        break;

      case 'livestream_pk_timer':
        final remaining = (data['remaining'] as num?)?.toInt() ?? 0;
        if (_pkData != null && mounted) {
          setState(() => _pkData!.remaining = remaining);
          _pkOverlayKey.currentState?.updateRemaining(remaining);
        }
        break;

      case 'livestream_pk_score':
        final scoreA = (data['score_a'] as num?)?.toInt() ?? 0;
        final scoreB = (data['score_b'] as num?)?.toInt() ?? 0;
        if (_pkData != null && mounted) {
          setState(() {
            _pkTopA = _parsePKTopList(data['top_a']);
            _pkTopB = _parsePKTopList(data['top_b']);
          });
          _pkOverlayKey.currentState?.updateScore(scoreA, scoreB);
        }
        break;

      case 'livestream_pk_end':
        final winnerId = (data['winner_id'] as num?)?.toInt() ?? 0;
        final loserId = (data['loser_id'] as num?)?.toInt() ?? 0;
        final punishSeconds = (data['punish_seconds'] as num?)?.toInt() ?? 0;
        _pkOverlayKey.currentState?.endPK(
          winnerId: winnerId,
          loserId: loserId,
          punishSeconds: punishSeconds,
        );
        // PK结束：断开LiveKit房间
        _disconnectPKRoom();
        // PK结束系统消息
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          String resultText = l10n?.pkDraw ?? 'Draw!';
          if (winnerId > 0 && _pkData != null) {
            final winnerName = winnerId == _pkData!.userIdA
                ? _pkData!.anchorNameA
                : _pkData!.anchorNameB;
            resultText = '${l10n?.pkWinnerIs ?? 'Winner:'} $winnerName';
          }
          _chatPanelKey.currentState?.addMessage(
            l10n?.systemLabel ?? 'System',
            '${l10n?.pkEnded ?? 'PK Ended'} - $resultText',
            isSystem: true,
          );
        }
        // 惩罚结束后自动清除，否则3秒后清除
        if (punishSeconds > 0 && loserId > 0) {
          Future.delayed(Duration(seconds: punishSeconds + 4), () {
            if (mounted) setState(() { _pkData = null; _pkTopA = []; _pkTopB = []; });
          });
        } else {
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() { _pkData = null; _pkTopA = []; _pkTopB = []; });
          });
        }
        break;

      case 'livestream_pk_punish':
        final loserId = (data['loser_id'] as num?)?.toInt() ?? 0;
        final punishSeconds = (data['punish_seconds'] as num?)?.toInt() ?? 60;
        if (_pkData != null && mounted) {
          _pkOverlayKey.currentState?.startPunish(loserId, punishSeconds);
        }
        break;

      case 'livestream_pk_streak':
        final nickname = data['nickname'] as String? ?? '';
        final streak = (data['streak'] as num?)?.toInt() ?? 0;
        if (_showDanmaku && nickname.isNotEmpty && streak > 0) {
          _danmakuKey.currentState?.addDanmaku(
            '$nickname ${AppLocalizations.of(context)?.pkStreak ?? 'Win Streak'} x$streak!',
            color: Colors.amber,
          );
        }
        break;

      // livestream_pk_token 已在 livestream_id 过滤前处理（SendToUser消息无livestream_id）

      case 'livestream_cohost_request':
        final nickname = data['nickname'] as String? ?? (AppLocalizations.of(context)?.defaultUser ?? 'User');
        final avatar = data['avatar'] as String? ?? '';
        final requestUserId = (data['user_id'] as num?)?.toInt() ?? 0;
        // 缓存请求者信息（后续构建CoHostInfo时使用）
        if (requestUserId > 0) {
          _coHostUserData[requestUserId] = (nickname: nickname, avatar: avatar);
        }
        if (mounted && widget.isAnchor && requestUserId > 0) {
          _showCohostRequestDialog(requestUserId, nickname);
        }
        if (mounted && _showDanmaku) {
          _danmakuKey.currentState?.addDanmaku(
            AppLocalizations.of(context)?.cohostRequest(nickname) ?? '$nickname requests co-host',
            color: Colors.cyan,
          );
        }
        break;

      case 'livestream_cohost_accept':
        final cohostUserId = (data['user_id'] as num?)?.toInt() ?? 0;
        final acceptNickname = data['nickname'] as String? ?? '';
        final acceptAvatar = data['avatar'] as String? ?? '';
        // 观众侧：匹配自己（服务端可能发 user_id=我 或 user_id=0）
        final isMyAccept = (cohostUserId == _myUserId) ||
            (cohostUserId == 0 && !widget.isAnchor);
        if (isMyAccept && _coHostService != null) {
          final anchorId = _room?.userId ?? 0;
          if (anchorId > 0) {
            // 始终缓存主播信息（无论 _isCoHosting 状态，避免 token 先到导致缓存为空）
            _coHostUserData[anchorId] = (
              nickname: _room?.user?.nickname ?? (AppLocalizations.of(context)?.anchorLabel ?? 'Anchor'),
              avatar: _room?.user?.avatar ?? '',
            );
            _activeCoHostUserIds
              ..add(anchorId)
              ..add(_myUserId);
            // 重置连麦控制状态
            _coHostMicOn = true;
            _coHostCamOn = true;
            _coHostService!.onCoHostAccepted(anchorId);
          }
        }
        // 主播侧：收到广播确认，缓存对方信息并更新连麦状态
        if (widget.isAnchor && cohostUserId > 0 && cohostUserId != _myUserId && _coHostService != null) {
          // 缓存连麦用户信息
          if (acceptNickname.isNotEmpty) {
            _coHostUserData[cohostUserId] = (nickname: acceptNickname, avatar: acceptAvatar);
          }
          _activeCoHostUserIds
            ..add(_myUserId)
            ..add(cohostUserId);
          _coHostMicOn = true;
          _coHostCamOn = true;
          _coHostService!.onCoHostAccepted(cohostUserId);
        }
        final anchorIdForAccept = _room?.userId ?? 0;
        if (anchorIdForAccept > 0) {
          _activeCoHostUserIds.add(anchorIdForAccept);
        }
        if (cohostUserId > 0) {
          _activeCoHostUserIds.add(cohostUserId);
        }
        if (mounted && _showDanmaku) {
          _danmakuKey.currentState?.addDanmaku(AppLocalizations.of(context)?.cohostEstablished ?? 'Co-host established', color: Colors.green);
        }
        break;

      case 'livestream_cohost_end':
        final endedUserId = (data['user_id'] as num?)?.toInt() ?? 0;
        if (_coHostService != null && endedUserId > 0) {
          _activeCoHostUserIds.remove(endedUserId);
          if (endedUserId == _myUserId) {
            // 我被断开了（主播结束了我的连麦）→ 仅本地清理，不再通知服务端
            _coHostService!.cleanupLocal();
          } else {
            // 对方离开了
            _coHostService!.onCoHostEnded(endedUserId);
          }
        }
        if (mounted && _showDanmaku) {
          _danmakuKey.currentState?.addDanmaku(AppLocalizations.of(context)?.cohostEnded ?? 'Co-host ended', color: Colors.orange);
        }
        break;

      case 'livestream_cohost_reject':
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.cohostRejected ?? 'Anchor rejected your co-host request')),
          );
        }
        break;

      case 'livestream_cohost_token':
        // CoHostService 已通过自己的 WS listener 处理 Token
        // 同时确保缓存数据存在（token 可能先于 accept 到达）
        if (_coHostService != null && !widget.isAnchor) {
          final anchorId = _room?.userId ?? 0;
          if (anchorId > 0 && !_coHostUserData.containsKey(anchorId)) {
            _coHostUserData[anchorId] = (
              nickname: _room?.user?.nickname ?? (AppLocalizations.of(context)?.anchorLabel ?? 'Anchor'),
              avatar: _room?.user?.avatar ?? '',
            );
          }
        }
        break;

      case 'livestream_cohost_mute':
        // 主播远程控制我的麦克风
        final muted = data['muted'] == true;
        if (mounted && _coHostService != null) {
          setState(() => _coHostMicOn = !muted);
          _coHostService!.toggleMic(!muted);
          final l = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(muted ? (l?.anchorMutedYou ?? 'Anchor muted you') : (l?.anchorUnmutedYou ?? 'Anchor unmuted you')),
              backgroundColor: muted ? Colors.redAccent : Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        break;

      case 'livestream_stream_switch':
        // 服务端通知切换拉流地址（连麦混流开始/结束时）
        final newPullUrl = data['pull_url'] as String? ?? '';
        final reason = data['reason'] as String? ?? '';
        if (newPullUrl.isNotEmpty && !_isCoHosting) {
          // 仅观众端切换拉流地址（连麦参与者不需要切换，他们通过LiveKit看）
          debugPrint('[StreamSwitch] 切换拉流: $newPullUrl (reason=$reason)');
          _switchPullUrl(newPullUrl);
        }
        break;

      case 'livestream_host_offline':
        final countdown = (data['countdown'] as num?)?.toInt() ?? 90;
        if (mounted) {
          setState(() {
            _hostOffline = true;
            _hostOfflineCountdown = countdown;
          });
          _hostOfflineTimer?.cancel();
          _hostOfflineTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!mounted) { timer.cancel(); return; }
            setState(() {
              _hostOfflineCountdown--;
              if (_hostOfflineCountdown <= 0) {
                timer.cancel();
              }
            });
          });
        }
        break;

      case 'livestream_host_online':
        _hostOfflineTimer?.cancel();
        if (mounted) {
          setState(() {
            _hostOffline = false;
            _hostOfflineCountdown = 0;
          });
          _chatPanelKey.currentState?.addMessage(AppLocalizations.of(context)?.systemLabel ?? 'System', AppLocalizations.of(context)?.anchorReconnected ?? 'Anchor reconnected', isSystem: true);
          // 观众端 WebRTC 重连
          if (_webrtcMode && !widget.isAnchor) {
            _viewerPC?.close();
            _viewerPC = null;
            _remoteStream = null;
            _requestStream();
          }
        }
        break;

      case 'livestream_ended':
        _chewieController?.pause();
        _hostOfflineTimer?.cancel();
        _cleanupWebRTC();
        if (mounted) {
          // 主播自己结束直播：_isEndingStream为true表示正在由_confirmEndLivestream处理pop
          // _isEndingStream为false表示被服务器强制关闭（如离线超时），需要自行pop
          if (widget.isAnchor) {
            if (!_isEndingStream) {
              Navigator.of(context).pop();
            }
            // _isEndingStream=true时，由_confirmEndLivestream的回调处理pop
            break;
          }
          // 滑动模式：短暂toast + 自动切换下一间
          if (widget.onStreamEnded != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)?.livestreamEndedSwitching ?? 'Livestream ended, switching...'), duration: const Duration(seconds: 1)),
            );
            Future.delayed(const Duration(milliseconds: 800), () {
              widget.onStreamEnded?.call(widget.livestreamId);
            });
          } else {
            // 独立模式：保持原有dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) {
                final l = AppLocalizations.of(context);
                return AlertDialog(
                title: Text(l?.livestreamEndedTitle ?? 'Livestream Ended'),
                content: Text(l?.livestreamEndedReplay ?? 'Anchor has ended the livestream, replay will be available soon'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                    },
                    child: Text(l?.goBack ?? 'Back'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _loadReplays();
                    },
                    child: Text(l?.viewReplay ?? 'View Replay'),
                  ),
                ],
              );
              },
            );
          }
        }
        break;

      case 'livestream_paid_request':
        final requesterName = data['viewer_nickname'] as String? ?? data['requester_name'] as String? ?? (AppLocalizations.of(context)?.defaultUser ?? 'User');
        final sid = (data['session_id'] as num?)?.toInt() ?? 0;
        final rate = (data['rate_per_minute'] as num?)?.toInt() ?? 100;
        final sType = (data['session_type'] as num?)?.toInt() ?? 3;
        final requesterId = (data['viewer_id'] as num?)?.toInt() ?? (data['requester_id'] as num?)?.toInt() ?? 0;
        if (mounted) {
          setState(() {
            _paidSessionId = sid;
          });
          _showPaidSessionRequest(sid, requesterName, rate, sType, requesterId);
        }
        break;

      case 'livestream_paid_accept':
        if (mounted) {
          final l = AppLocalizations.of(context);
          setState(() => _paidSessionActive = true);
          _paidSessionOverlayKey.currentState?.startTimer();
          _chatPanelKey.currentState?.addMessage('', l?.paidSessionEstablished ?? 'Paid session established', isSystem: true);
          // Service auto-handles accept via its own WS listener
        }
        break;

      case 'livestream_paid_reject':
        if (mounted) {
          final l = AppLocalizations.of(context);
          setState(() {
            _paidSessionId = null;
            _paidSessionActive = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l?.paidSessionRejected ?? 'Anchor rejected the paid session request')),
          );
        }
        break;

      case 'livestream_paid_end':
        if (mounted) {
          final l = AppLocalizations.of(context);
          _paidSessionOverlayKey.currentState?.stopTimer();
          _paidSessionService?.onPaidSessionEnded();
          setState(() {
            _paidSessionId = null;
            _paidSessionActive = false;
          });
          _chatPanelKey.currentState?.addMessage('', l?.paidSessionEnded ?? 'Paid session ended', isSystem: true);
        }
        break;

      case 'livestream_paid_charge':
        final totalMinutes = (data['total_minutes'] as num?)?.toInt() ?? 0;
        final viewerBalance = (data['viewer_balance'] as num?)?.toInt() ?? 0;
        _paidSessionOverlayKey.currentState?.updateCharge(totalMinutes, viewerBalance);
        break;

      // ===== 付费通话(LiveKit) =====
      case 'livestream_paid_call_apply':
        final requesterName = data['viewer_nickname'] as String? ?? (AppLocalizations.of(context)?.defaultUser ?? 'User');
        final sid = (data['session_id'] as num?)?.toInt() ?? 0;
        final rate = (data['rate_per_minute'] as num?)?.toInt() ?? 100;
        final sType = (data['session_type'] as num?)?.toInt() ?? 3;
        final requesterId = (data['viewer_id'] as num?)?.toInt() ?? 0;
        if (mounted) {
          setState(() => _paidSessionId = sid);
          _showPaidSessionRequest(sid, requesterName, rate, sType, requesterId);
        }
        break;

      case 'livestream_paid_call_accept':
        if (mounted) {
          final l = AppLocalizations.of(context);
          setState(() {
            _paidSessionActive = true;
            _isPaidCallParticipant = true; // 确保参与方标记（防重连后丢失）
          });
          _paidSessionOverlayKey.currentState?.startTimer();
          _chatPanelKey.currentState?.addMessage('', l?.paidCallEstablished ?? 'Paid call established', isSystem: true);
        }
        break;

      case 'livestream_paid_call_reject':
        if (mounted) {
          final l = AppLocalizations.of(context);
          setState(() {
            _paidSessionId = null;
            _paidSessionActive = false;
            _isPaidCallParticipant = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l?.paidCallRejected ?? 'Anchor rejected the paid call request')),
          );
        }
        break;

      case 'livestream_paid_call_end':
        if (mounted) {
          final l = AppLocalizations.of(context);
          _paidSessionOverlayKey.currentState?.stopTimer();
          _paidSessionService?.onPaidSessionEnded();
          setState(() {
            _paidSessionId = null;
            _paidSessionActive = false;
            _isPaidCallParticipant = false;
            _isInPaidCall = false;
          });
          _chatPanelKey.currentState?.addMessage('', l?.paidCallEnded ?? 'Paid call ended', isSystem: true);
        }
        break;

      case 'livestream_paid_call_charge':
        final totalMinutes = (data['total_minutes'] as num?)?.toInt() ?? 0;
        final viewerBalance = (data['viewer_balance'] as num?)?.toInt() ?? 0;
        _paidSessionOverlayKey.currentState?.updateCharge(totalMinutes, viewerBalance);
        break;

      case 'livestream_paid_call_status':
        final inCall = data['is_in_paid_call'] as bool? ?? false;
        if (mounted) {
          final l = AppLocalizations.of(context);
          final isParticipant = _isPaidCallParticipant || _paidSessionActive || widget.isAnchor;
          // 非通话参与方: 暂停/恢复视频+音频
          if (!isParticipant) {
            if (inCall) {
              // 传统拉流: 暂停播放器+静音
              _chewieController?.pause();
              _videoController?.setVolume(0);
              // WebRTC模式: 禁用远端音频轨道
              _remoteStream?.getAudioTracks().forEach((t) => t.enabled = false);
            } else {
              // 传统拉流: 恢复播放+音量
              _chewieController?.play();
              _videoController?.setVolume(1);
              // WebRTC模式: 恢复远端音频轨道
              _remoteStream?.getAudioTracks().forEach((t) => t.enabled = true);
            }
          }
          setState(() {
            _isInPaidCall = inCall;
          });
          _chatPanelKey.currentState?.addMessage('',
            inCall ? (l?.anchorInPaidCall ?? 'Anchor is in a paid call') : (l?.anchorPaidCallEnded ?? 'Anchor\'s paid call ended'), isSystem: true);
          if (!inCall && !isParticipant) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l?.livestreamResumed ?? 'Livestream Resumed'), duration: const Duration(seconds: 2)),
            );
          }
        }
        break;

      // ===== 按分钟付费观看 =====
      case 'livestream_paid_watch_trial':
        final trialSec = (data['trial_seconds'] as num?)?.toInt() ?? 0;
        final pricePerMin = (data['price_per_min'] as num?)?.toInt() ?? 0;
        if (mounted) {
          _trialTimer?.cancel();
          setState(() {
            _trialRemainingSeconds = trialSec;
            _trialPricePerMin = pricePerMin;
          });
          _trialTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!mounted) { timer.cancel(); return; }
            setState(() {
              _trialRemainingSeconds--;
            });
            if (_trialRemainingSeconds <= 0) {
              timer.cancel();
              if (mounted) {
                final l = AppLocalizations.of(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l?.paidWatchChargingStarted ?? 'Free preview ended, charging started'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          });
        }
        break;

      case 'livestream_paid_watch_charge':
        final chargeAmount = (data['charge_amount'] as num?)?.toInt() ?? 0;
        final balance = (data['viewer_balance'] as num?)?.toInt() ?? 0;
        if (mounted) {
          // Clear trial state when charging starts
          if (_trialRemainingSeconds > 0) {
            _trialTimer?.cancel();
            setState(() => _trialRemainingSeconds = 0);
          }
          final l = AppLocalizations.of(context);
          // 无试看房间首次扣费提示
          if (!_firstChargeNotified && _trialPricePerMin == 0) {
            _firstChargeNotified = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l?.paidWatchChargingStarted ?? '已开始按分钟计费'),
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l?.paidWatchCharged(chargeAmount, balance) ?? 'Charged $chargeAmount gold beans, balance: $balance'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
        break;

      case 'livestream_paid_watch_kick':
        if (mounted) {
          final l = AppLocalizations.of(context);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text(l?.paidWatchInsufficient ?? 'Insufficient Balance'),
              content: Text(l?.paidWatchInsufficientDetail ?? 'Your gold beans are insufficient. Paid viewing has been stopped. Please recharge and re-enter.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  child: Text(l?.confirm ?? 'OK'),
                ),
              ],
            ),
          );
        }
        break;

      case 'livestream_muted':
        final mutedUid = (data['user_id'] as num?)?.toInt() ?? 0;
        if (mutedUid == _myUserId && mounted) {
          final l = AppLocalizations.of(context);
          setState(() => _isMuted = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l?.youAreMuted ?? 'You are muted'), backgroundColor: Colors.redAccent),
          );
        }
        break;

      case 'livestream_kicked':
        final kickedUid = (data['user_id'] as num?)?.toInt() ?? 0;
        if (kickedUid == _myUserId && mounted) {
          final l = AppLocalizations.of(context);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text(l?.youAreKicked ?? 'You have been kicked from the livestream'),
              content: Text(data['reason'] as String? ?? ''),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  child: Text(l?.confirm ?? 'OK'),
                ),
              ],
            ),
          );
        } else if (kickedUid > 0 && mounted) {
          _onlineViewers.remove(kickedUid);
          setState(() {});
        }
        break;

      case 'livestream_moderator_update':
        final modUid = (data['user_id'] as num?)?.toInt() ?? 0;
        final action = data['action'] as String? ?? '';
        if (modUid > 0 && mounted) {
          setState(() {
            if (action == 'added') {
              _moderatorIds.add(modUid);
            } else if (action == 'removed') {
              _moderatorIds.remove(modUid);
            }
          });
        }
        break;

      case 'livestream_stream_signal':
        _handleStreamSignal(data);
        break;

      case 'livestream_mode_switch':
        _handleModeSwitch(data);
        break;
    }
  }

  /// 处理PK邀请（主播端收到）
  void _handlePKInvite(Map<String, dynamic> data) {
    final pkId = (data['pk_id'] as num?)?.toInt() ?? 0;
    final fromNickname = data['from_nickname'] as String? ?? 'Anchor';
    final rawAvatar = data['from_avatar'] as String? ?? '';
    final fromAvatar = rawAvatar.isNotEmpty && !rawAvatar.startsWith('http')
        ? '${EnvConfig.instance.baseUrl}$rawAvatar' : rawAvatar;
    final duration = (data['duration'] as num?)?.toInt() ?? 180;
    final l10n = AppLocalizations.of(context);

    if (pkId == 0 || !mounted) return;

    // 倒计时变量（在dialog外部定义，让StatefulBuilder可以引用）
    int countdown = 30;
    Timer? countdownTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            // 只启动一次倒计时
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown > 1) {
                setDialogState(() => countdown--);
              } else {
                t.cancel();
                countdownTimer = null;
                if (Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                  // 超时自动拒绝
                  LivestreamApi(ApiClient()).rejectPK(widget.livestreamId, pkId: pkId);
                }
              }
            });

            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.sports_mma, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  Text(l10n?.pkInviteTitle ?? 'PK Challenge',
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 头像 + 倒计时环
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 68,
                        height: 68,
                        child: CircularProgressIndicator(
                          value: countdown / 30,
                          strokeWidth: 3,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            countdown <= 5 ? Colors.redAccent : Colors.amber,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: fromAvatar.isNotEmpty ? NetworkImage(fromAvatar.proxied) : null,
                        child: fromAvatar.isEmpty ? const Icon(Icons.person, size: 28) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(fromNickname,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${l10n?.pkInvite ?? 'invites you to PK'} (${duration}s)',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  // 倒计时文字
                  Text(
                    '${countdown}s',
                    style: TextStyle(
                      color: countdown <= 5 ? Colors.redAccent : Colors.amber,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    countdownTimer = null;
                    Navigator.of(ctx).pop();
                    LivestreamApi(ApiClient()).rejectPK(widget.livestreamId, pkId: pkId);
                  },
                  child: Text(l10n?.pkReject ?? 'Reject',
                      style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    countdownTimer?.cancel();
                    countdownTimer = null;
                    Navigator.of(ctx).pop();
                    LivestreamApi(ApiClient()).acceptPK(widget.livestreamId, pkId: pkId);
                  },
                  child: Text(l10n?.pkAccept ?? 'Accept'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      countdownTimer?.cancel();
      countdownTimer = null;
    });
  }

  /// 主播端：显示PK邀请对话框（搜索在线主播）
  void _showPKInviteDialog() async {
    final l10n = AppLocalizations.of(context);
    final api = LivestreamApi(ApiClient());

    // 获取在线主播列表
    final resp = await api.getLiveList(page: 1, pageSize: 50);
    if (!mounted) return;

    if (!resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp.message ?? 'Failed to load anchors')),
      );
      return;
    }

    final List<dynamic> lives = resp.data?['list'] as List<dynamic>? ?? [];
    // 过滤掉自己的直播间
    final others = lives.where((l) {
      final lsId = (l['id'] as num?)?.toInt() ?? 0;
      return lsId != widget.livestreamId;
    }).toList();

    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.pkNoActiveAnchors ?? 'No other anchors online')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.sports_mma, color: Colors.amber, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    l10n?.pkSearchAnchor ?? 'Select an anchor to PK',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: others.length,
                itemBuilder: (_, i) {
                  final ls = others[i] as Map<String, dynamic>;
                  final lsId = (ls['id'] as num?)?.toInt() ?? 0;
                  final user = ls['user'] as Map<String, dynamic>? ?? {};
                  final nickname = user['nickname'] as String? ?? 'Anchor';
                  final avatar = user['avatar'] as String? ?? '';
                  final title = ls['title'] as String? ?? '';
                  final viewerCount = (ls['viewer_count'] as num?)?.toInt() ?? 0;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar.startsWith('http') ? avatar : '${EnvConfig.instance.baseUrl}$avatar') : null,
                      child: avatar.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    title: Text(nickname, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(
                      '$title  ($viewerCount)',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      ),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final result = await api.invitePK(widget.livestreamId, targetLivestreamId: lsId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result.success
                                  ? (l10n?.pkInviteSent ?? 'PK invite sent')
                                  : (result.message ?? 'Failed')),
                            ),
                          );
                        }
                      },
                      child: Text(l10n?.pkInvite ?? 'Invite', style: const TextStyle(fontSize: 12)),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        );
      },
    );
  }

  /// 主播端：PK选项菜单（选择主播 / 随机匹配）
  void _showPKOptionsMenu() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.sports_mma, color: Colors.amber, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'PK',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.person_search, color: Colors.white70),
                title: Text(
                  l10n?.pkSearchAnchor ?? 'Select an anchor to PK',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showPKInviteDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.casino, color: Colors.amber),
                title: Text(
                  l10n?.pkRandomMatch ?? 'Random PK Match',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  l10n?.pkRandomMatchDesc ?? 'Match with a similar-level anchor',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleRandomPK();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// 主播端：随机PK匹配
  void _handleRandomPK() async {
    final l10n = AppLocalizations.of(context);
    final api = LivestreamApi(ApiClient());

    // 显示loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await api.randomPK(widget.livestreamId);
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      if (result.success) {
        final targetId = result.data?['target_livestream_id'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.pkInviteSent ?? 'PK invite sent'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'No matching anchor found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 处理推流模式切换 (WebRTC ↔ RTMP)
  void _handleModeSwitch(Map<String, dynamic> data) {
    try {
      final newMode = data['mode'] as String? ?? 'webrtc';
      debugPrint('[直播] 收到模式切换: $newMode, 当前 webrtcMode=$_webrtcMode, isAnchor=${widget.isAnchor}');

      if (widget.isAnchor) {
        // 主播端：如果切到 RTMP，断开所有观众的 WebRTC PeerConnection
        if (newMode == 'rtmp') {
          for (final pc in _viewerPeerConnections.values) {
            pc.close();
          }
          _viewerPeerConnections.clear();
          _chatPanelKey.currentState?.addMessage(AppLocalizations.of(context)?.systemLabel ?? 'System', AppLocalizations.of(context)?.switchedRtmpMode ?? 'Switched to RTMP mode', isSystem: true);
        } else {
          _chatPanelKey.currentState?.addMessage(AppLocalizations.of(context)?.systemLabel ?? 'System', AppLocalizations.of(context)?.switchedWebrtcMode ?? 'Switched to WebRTC mode', isSystem: true);
        }
        return;
      }

      // 观众端
      if (newMode == 'rtmp' && _webrtcMode) {
        // WebRTC → RTMP: 清理 WebRTC，启动视频播放器
        _cleanupWebRTC();
        _webrtcMode = false;
        final pullUrl = data['pull_url'] as String? ?? '';
        if (data['quality_urls'] is Map) {
          _qualityUrls = Map<String, String>.from(
            (data['quality_urls'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
          );
        }
        final urls = _resolvePlayablePullUrls(
          fallbackPullUrl: pullUrl,
          preferredQuality: _currentQuality,
        );
        if (urls.isNotEmpty) {
          _initVideoPlayer(urls.first, fallbackUrls: urls.skip(1).toList());
        } else {
          debugPrint('[直播] 模式切换到 RTMP 但拉流地址无效: $pullUrl');
        }
        _chatPanelKey.currentState?.addMessage(AppLocalizations.of(context)?.systemLabel ?? 'System', AppLocalizations.of(context)?.switchedToStreaming ?? 'Switched to streaming', isSystem: true);
        if (mounted) setState(() {});
      } else if (newMode == 'webrtc' && !_webrtcMode) {
        // RTMP → WebRTC: 停止视频播放器，启动 WebRTC
        _videoRetryTimer?.cancel();
        _activeVideoUrl = '';
        _videoInitRetryCount = 0;
        _chewieController?.dispose();
        _chewieController = null;
        _videoController?.dispose();
        _videoController = null;
        _webrtcMode = true;
        _requestStream();
        _chatPanelKey.currentState?.addMessage(AppLocalizations.of(context)?.systemLabel ?? 'System', AppLocalizations.of(context)?.switchedToLowLatency ?? 'Switched to WebRTC low-latency', isSystem: true);
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('[直播] 模式切换异常: $e');
    }
  }

  Future<void> _leaveRoom() async {
    if (widget.isAnchor) return;
    // 使用缓存的provider引用，避免dispose后访问deactivated widget的context
    final provider = _cachedProvider;
    if (provider != null) {
      await provider.leaveLivestream(widget.livestreamId);
    }
  }

  void _confirmEndLivestream() {
    if (_isEndingStream) return;
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l?.endLivestream ?? 'End Livestream'),
        content: Text(l?.confirmEndLivestream ?? 'Are you sure you want to end this livestream?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx); // 关闭确认弹窗
              _isEndingStream = true;
              
              // 先停止推流
              if (_srsPublisher != null) {
                debugPrint('[直播] 结束直播，停止推流...');
                await _srsPublisher!.stopPublish();
                _srsPublisher = null;
              }
              
              final provider = Provider.of<LivestreamProvider>(context, listen: false);
              final ok = await provider.endLivestream(widget.livestreamId);
              // WS的livestream_ended可能已经触发Navigator.pop，检查mounted
              if (mounted && ok) {
                Navigator.of(context).pop();
              } else if (mounted && !ok) {
                _isEndingStream = false;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(provider.error ?? (l?.endLivestreamFailed ?? 'Failed to end livestream'))),
                );
              }
            },
            child: Text(l?.endButton ?? 'End'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 非激活状态：显示轻量占位
    if (!widget.isActive) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_room != null && _room!.coverUrl.isNotEmpty)
                Opacity(
                  opacity: 0.5,
                  child: Image.network(
                    _getFullImageUrl(_room!.coverUrl),
                    width: 120, height: 160, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.live_tv, color: Colors.white24, size: 64),
                  ),
                )
              else
                const Icon(Icons.live_tv, color: Colors.white24, size: 64),
              const SizedBox(height: 12),
              Text(
                _room?.title ?? (AppLocalizations.of(context)?.livestreamRoom ?? 'Livestream'),
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_room == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)?.roomNotExist ?? 'Livestream room does not exist', style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)?.goBack ?? 'Back'),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: !widget.isAnchor,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.isAnchor) {
          _confirmEndLivestream();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          onDoubleTap: _doubleTapLike,
          child: Stack(
          children: [
            // 视频区域（连麦时也保留原有背景）
            // ① 主播 + 有摄像头画面
            if (widget.isAnchor && _localStream != null && _cameraError == null && _isCameraOn)
              Positioned.fill(
                child: RTCVideoView(
                  _localRenderer!,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: true,
                ),
              )
            // ② 主播 + 纯音频模式（摄像头不可用/已关闭）→ 封面图 + 语音直播提示
            else if (widget.isAnchor && _localStream != null && _cameraError == null && !_isCameraOn)
              Positioned.fill(
                child: _buildAudioOnlyBackground(),
              )
            // ③ 观众 WebRTC 模式 + 有远端流 + 主播摄像头开
            else if (!widget.isAnchor && _webrtcMode && _remoteStream != null && _anchorCameraOn)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer!,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            // ④ 观众 WebRTC 模式 + 有远端流 + 主播摄像头关（纯音频）
            else if (!widget.isAnchor && _webrtcMode && _remoteStream != null && !_anchorCameraOn)
              Positioned.fill(
                child: _buildAudioOnlyBackground(),
              )
            // ⑤ 传统拉流（真实流媒体服务器）
            else if (_chewieController != null)
              Positioned.fill(child: Chewie(controller: _chewieController!))
            // ⑥ 错误/加载占位
            else
              Positioned.fill(
                child: Container(
                  color: Colors.grey[900],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _cameraError != null
                            ? Icons.videocam_off
                            : (_room!.isLive ? Icons.live_tv : Icons.tv_off),
                        color: _cameraError != null ? Colors.redAccent : Colors.white24,
                        size: 80,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _cameraError != null
                            ? _cameraError!
                            : (widget.isAnchor
                                ? (AppLocalizations.of(context)?.initializingCamera ?? 'Initializing camera...')
                                : (_webrtcMode
                                    ? (AppLocalizations.of(context)?.connectingAnchor ?? 'Connecting to anchor...')
                                    : (_room!.isLive ? (AppLocalizations.of(context)?.anchorLiveConnecting ?? 'Anchor is live, connecting...') : _room!.statusText))),
                        style: TextStyle(
                          color: _cameraError != null ? Colors.redAccent : Colors.white38,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_cameraError != null) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() => _cameraError = null);
                            _initLocalCamera();
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ] else if (widget.isAnchor) ...[
                        const SizedBox(height: 12),
                        const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                        ),
                      ] else if (_webrtcMode && _remoteStream == null) ...[
                        const SizedBox(height: 12),
                        const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                        ),
                      ] else if (_room!.pullUrl.isNotEmpty && !_room!.pullUrl.contains('example.com')) ...[
                        const SizedBox(height: 12),
                        const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // 入场横幅
            ..._entryBanners.map((banner) => Positioned(
              top: MediaQuery.of(context).padding.top + 100,
              left: 12,
              child: _buildEntryBannerWidget(banner),
            )),

            // 弹幕覆盖层
            if (_showDanmaku)
              Positioned.fill(
                child: DanmakuOverlay(key: _danmakuKey),
              ),

            // PK分屏视图（所有用户可见：主播端显示LiveKit音视频，观众端显示头像占位）
            if (_pkData != null) ...[
              Positioned(
                top: MediaQuery.of(context).padding.top + 156,
                left: 6,
                right: 6,
                height: MediaQuery.of(context).size.height * 0.34,
                child: Column(
                  children: [
                    Expanded(
                      child: CoHostView(
                        localUserId: _myUserId,
                        allParticipants: _pkParticipants.isNotEmpty
                            ? _pkParticipants
                            : [
                                // 观众端：从PKData构建头像占位
                                CoHostInfo(
                                  userId: _pkData!.userIdA,
                                  nickname: _pkData!.anchorNameA,
                                  avatarUrl: _pkData!.avatarA,
                                ),
                                CoHostInfo(
                                  userId: _pkData!.userIdB,
                                  nickname: _pkData!.anchorNameB,
                                  avatarUrl: _pkData!.avatarB,
                                ),
                              ],
                        activeSpeakerId: _myUserId,
                        isAnchor: false, // PK: 各主播只控制自己，不能远程静音/踢出对方
                      ),
                    ),
                    // PK礼物贡献前三名
                    _buildPKGiftTop3(),
                    // 仅主播端显示PK控制栏（麦克风+摄像头+喇叭）
                    if (widget.isAnchor && _pkParticipants.isNotEmpty)
                      _buildPKControlBar(),
                  ],
                ),
              ),
            ],

            // PK覆盖层（分数、倒计时、结果动画）— 位于分屏上方
            if (_pkData != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 56,
                left: 0,
                right: 0,
                child: PKOverlay(
                  key: _pkOverlayKey,
                  data: _pkData!,
                  onPKEnd: () {
                    if (mounted) setState(() => _pkData = null);
                  },
                ),
              ),

            // 主播离线遮罩
            if (_hostOffline)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off, color: Colors.white70, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context)?.anchorOfflineWaiting ?? 'Anchor offline, waiting for reconnection...',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        if (_hostOfflineCountdown > 0)
                          Text(
                            AppLocalizations.of(context)?.autoCloseCountdown(_hostOfflineCountdown) ?? 'Auto-close in ${_hostOfflineCountdown}s',
                            style: const TextStyle(color: Colors.white60, fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            // 付费通话暂停遮罩（其他观众看到 — 非通话参与方 & 非主播）
            if (_isInPaidCall && !_isPaidCallParticipant && !_paidSessionActive && !widget.isAnchor)
              Positioned.fill(
                child: Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pause_circle_outline, color: Colors.white70, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)?.livestreamPaused ?? '直播暂停中',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)?.livestreamPausedHint ?? '主播正在1对1通话中，直播暂停期间不收费',
                          style: const TextStyle(color: Colors.white60, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 点赞动画（右下角，侧边栏左侧）
            Positioned(
              right: 52,
              bottom: MediaQuery.of(context).padding.bottom + 56,
              child: LikeAnimationOverlay(key: _likeOverlayKey),
            ),

            // 礼物连刷特效（聊天面板上方）
            ..._giftCombos.map((combo) => Positioned(
              left: 8,
              bottom: MediaQuery.of(context).padding.bottom + 56 + (_showChatPanel ? 225 : 0) +
                  (_giftCombos.indexOf(combo) * 56.0),
              child: _buildGiftComboWidget(combo),
            )),

            // 聊天面板（左下角）
            if (_showChatPanel)
              Positioned(
                left: 8,
                right: 60,
                bottom: MediaQuery.of(context).padding.bottom + 56,
                child: ChatPanel(key: _chatPanelKey),
              ),

            // 右侧边栏（清晰度、聊天、弹幕、分享）
            Positioned(
              right: 8,
              bottom: MediaQuery.of(context).padding.bottom + 60,
              child: _buildRightSidebar(),
            ),

            // 付费连线覆盖层
            if (_paidSessionActive && _paidSessionId != null)
              PaidSessionOverlay(
                key: _paidSessionOverlayKey,
                sessionId: _paidSessionId!,
                ratePerMinute: _effectivePaidCallRate,
                onEnd: () => _endPaidSession(),
              ),

            // 连麦视图（抖音风格：主播全屏，连麦用户右侧浮窗）
            if (_isCoHosting && _coHostInfos.isNotEmpty)
              Positioned.fill(
                child: Stack(
                  children: [
                    CoHostViewTikTok(
                      localUserId: _myUserId,
                      allParticipants: _coHostInfos,
                      activeSpeakerId: _coHostService!.activeSpeakerId,
                      isAnchor: widget.isAnchor,
                      enlargedUserId: _enlargedCoHostUserId,
                      onMuteUser: widget.isAnchor ? (userId, muted) {
                        _muteCoHostUser(userId, muted);
                      } : (userId, muted) {
                        // 连麦用户控制自己的麦克风
                        if (userId == _myUserId) {
                          setState(() => _coHostMicOn = !muted);
                          _coHostService?.toggleMic(!muted);
                        }
                      },
                      onKickUser: widget.isAnchor ? (userId) {
                        _kickCoHostUser(userId);
                      } : null,
                      // 观众和连麦用户也支持本地放大/还原，主播依旧是唯一管理者
                      onEnlargeUser: (userId) {
                        setState(() => _enlargedCoHostUserId = userId);
                      },
                      canSelfControl: !widget.isAnchor && _activeCoHostUserIds.contains(_myUserId),
                      onToggleCamera: (userId, enabled) {
                        // 连麦用户控制自己的摄像头
                        if (userId == _myUserId) {
                          setState(() => _coHostCamOn = enabled);
                          _coHostService?.toggleCamera(enabled);
                        }
                      },
                      onEndCoHost: () async {
                        await _coHostService?.endCoHost();
                        if (mounted) {
                          _chatPanelKey.currentState?.addMessage(
                            AppLocalizations.of(context)?.systemLabel ?? 'System',
                            AppLocalizations.of(context)?.cohostDisconnected ?? 'Co-host disconnected',
                            isSystem: true,
                          );
                        }
                      },
                    ),
                    if (widget.isAnchor)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: MediaQuery.of(context).padding.bottom + 110,
                        child: Center(child: _buildCoHostControlBar()),
                      ),
                  ],
                ),
              ),

            // 顶部信息栏（始终显示）
            Positioned(
              top: MediaQuery.of(context).padding.top + 4,
              left: 8,
              right: 8,
              child: _buildTopBar(),
            ),

            // 试看倒计时横幅（门票制 / 按分钟制共用）
            if (_trialRemainingSeconds > 0)
              Positioned(
                top: MediaQuery.of(context).padding.top + 52,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _ticketPreviewDuration > 0
                              ? '试看中: ${_trialRemainingSeconds}秒, 结束后需购票'
                              : '${AppLocalizations.of(context)?.paidWatchTrialBanner(_trialRemainingSeconds, _trialPricePerMin) ?? 'Free preview: ${_trialRemainingSeconds}s, then $_trialPricePerMin gold beans/min'}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 底部操作栏（输入框 + 图标按钮）
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: _buildBottomBar(),
            ),

            // 礼物动画覆盖层（最高层级，显示在所有UI之上）
            Positioned.fill(
              child: IgnorePointer(
                child: GiftAnimationOverlay(key: _giftOverlayKey),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _doubleTapLike() async {
    _likeOverlayKey.currentState?.addLike();
    final provider = Provider.of<LivestreamProvider>(context, listen: false);
    final ok = await provider.likeLivestream(widget.livestreamId);
    if (ok && mounted) {
      setState(() => _likeCount++);
    }
  }

  // ==================== 顶部栏：主播胶囊 + 设置/关闭 ====================

  Widget _buildTopBar() {
    return Row(
      children: [
        // 主播信息胶囊
        _buildAnchorCapsule(),
        const SizedBox(width: 6),
        // 关注按钮（观众模式）
        if (!widget.isAnchor)
          GestureDetector(
            onTap: () async {
              if (_room == null) return;
              final provider = Provider.of<LivestreamProvider>(context, listen: false);
              final svProvider = Provider.of<SmallVideoProvider>(context, listen: false);
              if (_isFollowing) {
                final ok = await provider.unfollowAnchor(_room!.userId);
                if (ok && mounted) {
                  setState(() => _isFollowing = false);
                  svProvider.updateFollowState(_room!.userId, false);
                }
              } else {
                final ok = await provider.followAnchor(_room!.userId);
                if (ok && mounted) {
                  setState(() => _isFollowing = true);
                  svProvider.updateFollowState(_room!.userId, true);
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _isFollowing ? Colors.grey.withValues(alpha: 0.5) : Colors.redAccent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _isFollowing ? (AppLocalizations.of(context)?.followingAlready ?? 'Following') : (AppLocalizations.of(context)?.followButton ?? '+Follow'),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        const Spacer(),
        // 观众头像列表（按礼物排序前3）
        _buildViewerAvatars(),
        const SizedBox(width: 6),
        // 主播设置（摄像头/麦克风）
        if (widget.isAnchor) ...[
          _buildCircleButton(
            icon: Icons.more_horiz,
            size: 32,
            onTap: _showSettingsPanel,
          ),
          const SizedBox(width: 6),
        ],
        // 关闭按钮
        _buildCircleButton(
          icon: Icons.close,
          size: 32,
          onTap: () => widget.isAnchor ? _confirmEndLivestream() : Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildAnchorCapsule() {
    return Container(
      padding: const EdgeInsets.only(left: 3, top: 3, bottom: 3, right: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 主播头像（观众点击跳转个人主页，主播自己不跳转）
          GestureDetector(
            onTap: widget.isAnchor ? null : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreatorProfileScreen(userId: _room!.userId),
                ),
              ).then((result) {
                if (result is bool && mounted) {
                  setState(() => _isFollowing = result);
                } else if (mounted && _room != null) {
                  _checkFollowing(_room!.userId);
                }
              });
            },
            child: CircleAvatar(
              radius: 16,
              backgroundImage: _room!.user?.avatar.isNotEmpty == true
                  ? NetworkImage(_getFullImageUrl(_room!.user!.avatar))
                  : null,
              child: _room!.user?.avatar.isEmpty != false
                  ? const Icon(Icons.person, size: 16, color: Colors.white70)
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _room!.user?.nickname ?? (AppLocalizations.of(context)?.anchorLabel ?? 'Anchor'),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.redAccent, size: 10),
                  const SizedBox(width: 2),
                  Text(
                    _formatCount(_likeCount),
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 连麦控制栏（独立渲染，不被overlay遮挡） ====================

  Widget _buildCoHostControlBar() {
    // 使用 Listener 代替 GestureDetector，绕过父级 onDoubleTap 的手势竞技场
    // GestureDetector(onDoubleTap) 包裹了整个 Stack，其 DoubleTapRecognizer 会
    // 与子级 TapRecognizer 竞争，导致单击延迟 ~300ms 甚至丢失
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 麦克风（使用本地状态，即时视觉反馈）
          _buildCtrlBtn(
            icon: _coHostMicOn ? Icons.mic : Icons.mic_off,
            active: _coHostMicOn,
            onTap: () {
              setState(() => _coHostMicOn = !_coHostMicOn);
              _coHostService?.toggleMic(_coHostMicOn);
              if (widget.isAnchor) {
                _isMicOn = _coHostMicOn;
                // 同步控制本地 SRS 推流的音频轨道
                _localStream?.getAudioTracks().forEach((t) => t.enabled = _coHostMicOn);
                // 同步控制 SRS Publisher 的音频轨道
                if (_srsPublisher != null) {
                  _srsPublisher!.toggleMute();
                }
              }
            },
          ),
          const SizedBox(width: 20),
          // 摄像头（使用本地状态，即时视觉反馈）
          _buildCtrlBtn(
            icon: _coHostCamOn ? Icons.videocam : Icons.videocam_off,
            active: _coHostCamOn,
            onTap: () {
              setState(() => _coHostCamOn = !_coHostCamOn);
              _coHostService?.toggleCamera(_coHostCamOn);
              if (widget.isAnchor) {
                _isCameraOn = _coHostCamOn;
                // 同步控制本地 SRS 推流的视频轨道
                _localStream?.getVideoTracks().forEach((t) => t.enabled = _coHostCamOn);
                // 同步控制 SRS Publisher 的视频轨道
                if (_srsPublisher != null) {
                  _srsPublisher!.toggleVideo();
                }
              }
            },
          ),
          const SizedBox(width: 20),
          // 断开连麦
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerUp: (_) async {
              await _coHostService?.endCoHost();
              if (mounted) {
                _chatPanelKey.currentState?.addMessage(AppLocalizations.of(context)?.systemLabel ?? 'System', AppLocalizations.of(context)?.cohostDisconnected ?? 'Co-host disconnected', isSystem: true);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.call_end, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(AppLocalizations.of(context)?.hangUp ?? 'Hang up', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 连麦控制按钮 — 使用 Listener 而非 GestureDetector
  /// Listener 直接监听指针事件，不参与手势竞技场，
  /// 从而避免与父级 DoubleTapGestureRecognizer 竞争导致单击延迟/丢失
  Widget _buildCtrlBtn({required IconData icon, required bool active, required VoidCallback onTap}) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerUp: (_) => onTap(),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: active ? const Color(0x33FFFFFF) : const Color(0xCCFF3B30),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  // ==================== PK 状态检查（迟到观众支持） ====================

  /// 检查是否有活跃PK（观众进入直播间时调用）
  /// 解决观众在PK进行中进入，错过pk_start广播导致看不到PK信息的问题
  Future<void> _checkActivePK() async {
    try {
      final resp = await LivestreamApi(ApiClient()).getActivePK(widget.livestreamId);
      if (!resp.success || resp.data == null) return;
      final data = resp.data as Map<String, dynamic>;
      final status = (data['status'] as num?)?.toInt() ?? 0;
      if (status != 1) return; // 非活跃状态

      final avatarA = data['avatar_a'] as String? ?? '';
      final avatarB = data['avatar_b'] as String? ?? '';
      debugPrint('[PK] checkActivePK: avatarA="$avatarA", avatarB="$avatarB", '
          'userIdA=${data['user_id_a']}, userIdB=${data['user_id_b']}');

      final duration = (data['duration'] as num?)?.toInt() ?? 180;
      // 根据 started_at 计算剩余时间
      int remaining = duration;
      final startedAtStr = data['started_at'] as String?;
      if (startedAtStr != null && startedAtStr.isNotEmpty) {
        try {
          final startedAt = DateTime.parse(startedAtStr);
          final elapsed = DateTime.now().toUtc().difference(startedAt.toUtc()).inSeconds;
          remaining = (duration - elapsed).clamp(0, duration);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _pkData = PKData(
            pkId: (data['id'] as num?)?.toInt() ?? 0,
            userIdA: (data['user_id_a'] as num?)?.toInt() ?? 0,
            userIdB: (data['user_id_b'] as num?)?.toInt() ?? 0,
            anchorNameA: data['nickname_a'] as String? ?? 'A',
            anchorNameB: data['nickname_b'] as String? ?? 'B',
            avatarA: avatarA,
            avatarB: avatarB,
            scoreA: (data['score_a'] as num?)?.toInt() ?? 0,
            scoreB: (data['score_b'] as num?)?.toInt() ?? 0,
            duration: duration,
            remaining: remaining,
          );
          _pkTopA = _parsePKTopList(data['top_a']);
          _pkTopB = _parsePKTopList(data['top_b']);
        });
        // 迟到用户也连接PK LiveKit房间
        _requestPKTokenAndConnect();
      }
    } catch (e) {
      debugPrint('Check active PK error: $e');
    }
  }

  // ==================== PK LiveKit 音视频 ====================

  /// 连接PK LiveKit房间
  /// [canPublish] true=主播（可发布音视频），false=观众（仅订阅）
  Future<void> _connectPKRoom(String url, String token, {bool canPublish = true}) async {
    await _disconnectPKRoom();

    _pkRoom = Room();
    _pkRoomListener = _pkRoom!.createListener();
    _setupPKRoomEvents();

    try {
      await _pkRoom!.connect(
        url,
        token,
        roomOptions: const RoomOptions(
          defaultAudioPublishOptions: AudioPublishOptions(dtx: true),
          defaultVideoPublishOptions: VideoPublishOptions(
            videoEncoding: VideoEncoding(maxBitrate: 1500000, maxFramerate: 24),
          ),
          defaultCameraCaptureOptions: CameraCaptureOptions(
            params: VideoParametersPresets.h540_169,
          ),
          defaultAudioCaptureOptions: AudioCaptureOptions(
            noiseSuppression: true,
            echoCancellation: true,
          ),
        ),
      );

      // 主播端：开启麦克风和摄像头（PK音频，独立于RTMP推流）
      if (canPublish) {
        try {
          await _pkRoom!.localParticipant?.setMicrophoneEnabled(true);
        } catch (e) {
          debugPrint('PK: failed to enable microphone: $e');
        }
        try {
          await _pkRoom!.localParticipant?.setCameraEnabled(true);
        } catch (e) {
          debugPrint('PK: failed to enable camera: $e');
          _pkCamOn = false;
        }
      }

      // 静音RTMP播放器音频（避免听到自己主播两遍：RTMP+LiveKit）
      _videoController?.setVolume(0);
      _remoteStream?.getAudioTracks().forEach((t) => t.enabled = false);

      _rebuildPKParticipants();
    } catch (e) {
      debugPrint('PK connectToRoom error: $e');
      await _disconnectPKRoom();
    }
  }

  /// 请求PK Token并连接LiveKit（观众端 / 迟到的主播端）
  Future<void> _requestPKTokenAndConnect() async {
    if (_pkRoom != null) {
      debugPrint('[PK] _requestPKTokenAndConnect: already connected, skipping');
      return;
    }
    try {
      debugPrint('[PK] _requestPKTokenAndConnect: requesting token for livestream=${widget.livestreamId}');
      final resp = await LivestreamApi(ApiClient()).getPKToken(widget.livestreamId);
      if (!resp.success) {
        debugPrint('[PK] _requestPKTokenAndConnect: API failed: ${resp.message}');
        return;
      }
      final data = resp.data as Map<String, dynamic>? ?? {};
      final token = data['token'] as String? ?? '';
      final url = data['livekit_url'] as String? ?? '';
      debugPrint('[PK] _requestPKTokenAndConnect: token=${token.isNotEmpty ? "present" : "EMPTY"}, url=$url');
      if (token.isNotEmpty && url.isNotEmpty) {
        // 主播端用 publish 权限（但主播通常已通过WS获取token，这里是fallback）
        await _connectPKRoom(url, token, canPublish: widget.isAnchor);
        debugPrint('[PK] _requestPKTokenAndConnect: connected successfully');
      }
    } catch (e) {
      debugPrint('[PK] _requestPKTokenAndConnect error: $e');
    }
  }

  void _setupPKRoomEvents() {
    _pkRoomListener
      ?..on<ParticipantConnectedEvent>((event) {
        debugPrint('PK: participant connected: ${event.participant.identity}');
        _rebuildPKParticipants();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        debugPrint('PK: participant disconnected: ${event.participant.identity}');
        _rebuildPKParticipants();
      })
      ..on<TrackPublishedEvent>((event) => _rebuildPKParticipants())
      ..on<TrackUnpublishedEvent>((event) => _rebuildPKParticipants())
      ..on<TrackSubscribedEvent>((event) => _rebuildPKParticipants())
      ..on<TrackUnsubscribedEvent>((event) => _rebuildPKParticipants())
      ..on<TrackMutedEvent>((event) => _rebuildPKParticipants())
      ..on<TrackUnmutedEvent>((event) => _rebuildPKParticipants())
      ..on<ActiveSpeakersChangedEvent>((event) => _rebuildPKParticipants())
      ..on<RoomDisconnectedEvent>((event) {
        debugPrint('PK: room disconnected');
        if (mounted) setState(() => _pkParticipants = []);
      });
  }

  /// 从 PK LiveKit Room 参与者构建 CoHostInfo 列表
  /// 主播端: 包含 localParticipant + remoteParticipants
  /// 观众端: 仅 remoteParticipants（自己不发布，不应显示在分屏中）
  void _rebuildPKParticipants() {
    if (!mounted || _pkRoom == null || _pkData == null) return;
    final anchorIds = {_pkData!.userIdA, _pkData!.userIdB};
    debugPrint('[PK] rebuildParticipants: anchorIds=$anchorIds, '
        'pkData.avatarA="${_pkData!.avatarA}", pkData.avatarB="${_pkData!.avatarB}", '
        'isAnchor=${widget.isAnchor}, remoteCount=${_pkRoom!.remoteParticipants.length}');
    setState(() {
      final allParticipants = <Participant>[
        if (widget.isAnchor && _pkRoom!.localParticipant != null)
          _pkRoom!.localParticipant!,
        ..._pkRoom!.remoteParticipants.values,
      ];
      // 只保留PK双方主播，过滤掉观众（观众虽连接LiveKit但不应显示在分屏）
      final anchorParticipants = allParticipants.where((p) {
        final uid = _parseUserIdFromIdentity(p.identity);
        return anchorIds.contains(uid);
      }).toList();
      _pkParticipants = anchorParticipants.map((p) {
        final uid = _parseUserIdFromIdentity(p.identity);
        final isMe = uid == _myUserId;
        String nickname = p.name;
        String avatar = '';
        if (uid == _pkData!.userIdA) {
          if (nickname.isEmpty) nickname = _pkData!.anchorNameA;
          avatar = _pkData!.avatarA;
        } else if (uid == _pkData!.userIdB) {
          if (nickname.isEmpty) nickname = _pkData!.anchorNameB;
          avatar = _pkData!.avatarB;
        }
        if (nickname.isEmpty) {
          nickname = isMe ? (_myNickname.isNotEmpty ? _myNickname : 'Me') : 'User$uid';
        }
        if (avatar.isEmpty && isMe) {
          avatar = _myAvatar;
        }
        debugPrint('[PK] participant: uid=$uid, identity=${p.identity}, '
            'avatar="$avatar", hasVideo=${p.videoTrackPublications.isNotEmpty}');
        return CoHostInfo(
          userId: uid,
          nickname: nickname,
          avatarUrl: avatar,
          participant: p,
        );
      }).toList();
      debugPrint('[PK] pkParticipants.length=${_pkParticipants.length}');
    });
  }

  /// 断开PK LiveKit房间
  Future<void> _disconnectPKRoom() async {
    _pkRoomListener?.dispose();
    _pkRoomListener = null;
    await _pkRoom?.disconnect();
    _pkRoom?.dispose();
    _pkRoom = null;
    _pkMicOn = true;
    _pkCamOn = true;
    _pkSpeakerOn = true;
    // 恢复RTMP播放器音量
    _videoController?.setVolume(1.0);
    _remoteStream?.getAudioTracks().forEach((t) => t.enabled = true);
    if (mounted) setState(() => _pkParticipants = []);
  }

  /// PK麦克风切换（仅影响LiveKit房间，不影响RTMP推流）
  /// 关闭 → 对方直播间听不到，自己直播间仍然能听到
  Future<void> _togglePKMic(bool enabled) async {
    final participant = _pkRoom?.localParticipant;
    if (participant == null) return;
    try {
      if (enabled) {
        await participant.setMicrophoneEnabled(true);
        for (final pub in participant.audioTrackPublications) {
          final track = pub.track;
          if (track != null) try { track.mediaStreamTrack.enabled = true; } catch (_) {}
        }
      } else {
        for (final pub in participant.audioTrackPublications) {
          final track = pub.track;
          if (track != null) try { track.mediaStreamTrack.enabled = false; } catch (_) {}
        }
        await participant.setMicrophoneEnabled(false);
      }
    } catch (e) {
      debugPrint('PK toggleMic error: $e');
    }
  }

  /// PK摄像头切换（仅影响LiveKit房间）
  Future<void> _togglePKCamera(bool enabled) async {
    final participant = _pkRoom?.localParticipant;
    if (participant == null) return;
    try {
      if (enabled) {
        await participant.setCameraEnabled(true);
        for (final pub in participant.videoTrackPublications) {
          final track = pub.track;
          if (track != null) try { track.mediaStreamTrack.enabled = true; } catch (_) {}
        }
      } else {
        for (final pub in participant.videoTrackPublications) {
          final track = pub.track;
          if (track != null) try { track.mediaStreamTrack.enabled = false; } catch (_) {}
        }
        await participant.setCameraEnabled(false);
      }
    } catch (e) {
      debugPrint('PK toggleCamera error: $e');
    }
  }

  /// PK喇叭开关（控制是否听到对方主播的音频）
  /// 关闭 → 本地不播放对方音频，但不影响自己直播间观众
  void _togglePKSpeaker(bool enabled) {
    setState(() => _pkSpeakerOn = enabled);
    if (_pkRoom == null) return;
    for (final participant in _pkRoom!.remoteParticipants.values) {
      for (final pub in participant.audioTrackPublications) {
        final track = pub.track;
        if (track != null) {
          try { track.mediaStreamTrack.enabled = enabled; } catch (_) {}
        }
      }
    }
  }

  /// PK礼物贡献前三名（左右分栏，各自主播下方显示）
  /// 解析服务端推送的PK礼物排行列表
  List<Map<String, dynamic>> _parsePKTopList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
    }
    return [];
  }

  Widget _buildPKGiftTop3() {
    if (_pkData == null) return const SizedBox.shrink();

    const rankColors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];
    const avatarSize = 26.0;
    const overlap = 10.0;

    Widget buildRankAvatars(List<Map<String, dynamic>> topList) {
      if (topList.isEmpty) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined, size: 14, color: Colors.white24),
            const SizedBox(width: 4),
            const Text('--', style: TextStyle(color: Colors.white30, fontSize: 11)),
          ],
        );
      }
      final top3 = topList.take(3).toList();
      final stackWidth = avatarSize + (top3.length - 1) * (avatarSize - overlap);
      final topAmount = (top3[0]['total'] as num?)?.toInt() ?? 0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: stackWidth,
            height: avatarSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = top3.length - 1; i >= 0; i--)
                  Positioned(
                    left: i * (avatarSize - overlap),
                    top: 0,
                    child: _buildRankAvatar(
                      i,
                      top3[i]['avatar'] as String? ?? '',
                      top3[i]['nickname'] as String? ?? '?',
                      rankColors[i],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatGiftAmount(topAmount),
              style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }

    return Container(
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      child: Row(
        children: [
          // A方区域
          Expanded(
            child: Center(child: buildRankAvatars(_pkTopA)),
          ),
          Container(width: 1, height: 22, color: Colors.white10),
          // B方区域
          Expanded(
            child: Center(child: buildRankAvatars(_pkTopB)),
          ),
        ],
      ),
    );
  }

  /// PK礼物排名头像（带rank徽章的圆形头像）
  Widget _buildRankAvatar(int rank, String avatar, String nickname, Color borderColor) {
    final initial = nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';
    final fullAvatar = avatar.isNotEmpty ? EnvConfig.instance.getFileUrl(avatar) : '';
    const size = 26.0;
    final rankLabels = ['1', '2', '3'];

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 头像（外圈用border，内部用padding+ClipOval保证不裁切border）
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 3, offset: const Offset(0, 1)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(0.5),
              child: ClipOval(
                child: fullAvatar.isNotEmpty
                    ? Image.network(
                        fullAvatar,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: borderColor.withValues(alpha: 0.3),
                          child: Center(child: Text(initial, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600))),
                        ),
                      )
                    : Container(
                        color: borderColor.withValues(alpha: 0.3),
                        child: Center(child: Text(initial, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600))),
                      ),
              ),
            ),
          ),
          // 排名徽章（右下角）
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: borderColor,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1A1A1A), width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2),
                ],
              ),
              child: Center(
                child: Text(
                  rankLabels[rank],
                  style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold, height: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化礼物金额（>10000显示为1.0w）
  String _formatGiftAmount(int amount) {
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}w';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '$amount';
  }

  /// PK控制栏（主播：麦克风 + 摄像头 + 喇叭）
  Widget _buildPKControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // PK麦克风（仅影响对方直播间，自己直播间不受影响）
          _buildCtrlBtn(
            icon: _pkMicOn ? Icons.mic : Icons.mic_off,
            active: _pkMicOn,
            onTap: () {
              setState(() => _pkMicOn = !_pkMicOn);
              _togglePKMic(_pkMicOn);
            },
          ),
          const SizedBox(width: 20),
          // PK摄像头（仅影响PK分屏画面）
          _buildCtrlBtn(
            icon: _pkCamOn ? Icons.videocam : Icons.videocam_off,
            active: _pkCamOn,
            onTap: () {
              setState(() => _pkCamOn = !_pkCamOn);
              _togglePKCamera(_pkCamOn);
            },
          ),
          const SizedBox(width: 20),
          // PK喇叭（控制是否听到对方主播声音，不影响自己直播间）
          _buildCtrlBtn(
            icon: _pkSpeakerOn ? Icons.volume_up : Icons.volume_off,
            active: _pkSpeakerOn,
            onTap: () {
              _togglePKSpeaker(!_pkSpeakerOn);
            },
          ),
        ],
      ),
    );
  }

  /// 主播远程控制连麦用户麦克风（通过 WS 发送 mute 指令）
  void _muteCoHostUser(int userId, bool muted) {
    // 立即更新本地 UI（不等待远端 LiveKit 信令回传）
    setState(() {
      _anchorMuteOverrides[userId] = muted;
      // 同步更新 _coHostInfos 中对应用户的 isMutedOverride
      _coHostInfos = _coHostInfos.map((info) {
        if (info.userId == userId) {
          return CoHostInfo(
            userId: info.userId,
            nickname: info.nickname,
            avatarUrl: info.avatarUrl,
            participant: info.participant,
            isMutedOverride: muted,
          );
        }
        return info;
      }).toList();
    });
    WebSocketService().send({
      'type': 'livestream_cohost_mute',
      'data': {
        'to_user_id': userId,
        'livestream_id': widget.livestreamId,
        'muted': muted,
      },
    });
    if (mounted) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(muted ? (l?.mutedOther ?? 'Muted') : (l?.unmutedOther ?? 'Unmuted')),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 主播踢出指定连麦用户
  Future<void> _kickCoHostUser(int userId) async {
    final l = AppLocalizations.of(context);
    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l?.translate('kick_cohost_title') ?? '踢出连麦'),
        content: Text(l?.translate('kick_cohost_confirm') ?? '确定要将该用户踢出连麦吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l?.cancel ?? '取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l?.translate('kick') ?? '踢出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await _coHostService?.kickCoHost(userId) ?? false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? (l?.translate('kick_cohost_success') ?? '已踢出连麦用户')
              : (l?.translate('kick_cohost_failed') ?? '踢出失败')),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // ==================== 底部栏：TikTok 风格（输入框 + 图标按钮一排） ====================

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          // 输入框（灰色背景）- 禁言时显示灰色不可用
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isMuted ? null : _showDanmakuInput,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _isMuted
                      ? Colors.grey[900]!.withOpacity(0.5)
                      : Colors.grey[800]!.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  _isMuted ? (AppLocalizations.of(context)?.youAreSilenced ?? 'You are muted') : (AppLocalizations.of(context)?.saySomething ?? 'Say something...'),
                  style: TextStyle(
                    color: _isMuted ? Colors.redAccent.withOpacity(0.6) : Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 礼物
          _buildBottomIcon(
            icon: Icons.card_giftcard,
            color: Colors.orangeAccent,
            onTap: _showGiftPanel,
          ),
          const SizedBox(width: 6),
          // 点赞
          _buildBottomIcon(
            icon: Icons.favorite,
            color: Colors.redAccent,
            onTap: () async {
              _likeOverlayKey.currentState?.addLike();
              final provider = Provider.of<LivestreamProvider>(context, listen: false);
              final ok = await provider.likeLivestream(widget.livestreamId);
              if (ok && mounted) {
                setState(() => _likeCount++);
              }
            },
          ),
          const SizedBox(width: 6),
          // PK (anchor only)
          if (widget.isAnchor)
            _buildBottomIcon(
              icon: Icons.sports_mma,
              color: Colors.amber,
              onTap: _showPKOptionsMenu,
            ),
          if (widget.isAnchor) const SizedBox(width: 6),
          // 分享
          _buildBottomIcon(
            icon: Icons.share,
            color: Colors.white,
            onTap: _showShareSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  // ==================== 纯音频直播背景 ====================

  Widget _buildAudioOnlyBackground() {
    final coverUrl = _room?.coverUrl ?? '';
    final fullCoverUrl = coverUrl.isNotEmpty ? _getFullImageUrl(coverUrl) : '';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
        ),
      ),
      child: Stack(
        children: [
          // 封面图（有则显示模糊背景）
          if (fullCoverUrl.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: 0.3,
                child: Image.network(
                  fullCoverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          // 中央内容（PK或连麦时隐藏，因为分屏覆盖了中央区域）
          if (_pkData == null && !(_isCoHosting && _coHostInfos.isNotEmpty))
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 波纹动画圈
                  _AudioPulseWidget(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                      ),
                      child: const Icon(Icons.mic, color: Colors.white, size: 48),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context)?.audioLiveBroadcasting ?? 'Audio Live',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)?.cameraNotEnabled ?? 'Anchor camera is off',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==================== 通用圆形按钮 ====================

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 36,
    Color? bgColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor ?? Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }

  // ==================== 设置面板 ====================

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(AppLocalizations.of(context)?.anchorSettings ?? 'Anchor Settings', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                const Divider(color: Colors.white12),
                Builder(builder: (_) {
                  // 纯音频回退模式：无视频轨道 → 摄像头 switch disabled
                  final hasVideoTrack = _localStream != null &&
                      _localStream!.getVideoTracks().isNotEmpty;
                  return SwitchListTile(
                    dense: true,
                    title: Text(AppLocalizations.of(context)?.cameraLabel ?? 'Camera', style: const TextStyle(color: Colors.white)),
                    subtitle: !hasVideoTrack
                        ? Text(AppLocalizations.of(context)?.noCameraAvailable ?? 'No camera available', style: const TextStyle(color: Colors.white38, fontSize: 12))
                        : null,
                    secondary: Icon(
                      _isCameraOn ? Icons.videocam : Icons.videocam_off,
                      color: !hasVideoTrack
                          ? Colors.white24
                          : (_isCameraOn ? Colors.white70 : Colors.redAccent),
                      size: 20,
                    ),
                    value: _isCameraOn,
                    activeColor: Colors.redAccent,
                    onChanged: !hasVideoTrack ? null : (v) {
                      // 互斥保护：不能同时关闭摄像头和麦克风
                      if (!v && !_isMicOn) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)?.cameraMicBothOff ?? 'Camera and microphone cannot both be off')),
                        );
                        return;
                      }
                      setSheetState(() {});
                      setState(() => _isCameraOn = v);
                      _localStream?.getVideoTracks().forEach((t) => t.enabled = v);
                      // 通知所有 WebRTC 观众摄像头状态变化
                      for (final viewerUserId in _viewerPeerConnections.keys) {
                        WebSocketService().send({
                          'type': 'livestream_stream_signal',
                          'data': {
                            'to_user_id': viewerUserId,
                            'signal_type': 'camera_toggle',
                            'camera_on': v,
                            'livestream_id': widget.livestreamId,
                          },
                        });
                      }
                    },
                  );
                }),
                // 摄像头切换按钮（前后摄像头）
                Builder(builder: (_) {
                  final hasVideoTrack = _localStream != null &&
                      _localStream!.getVideoTracks().isNotEmpty;
                  final canSwitch = hasVideoTrack && _isCameraOn;
                  return ListTile(
                    dense: true,
                    enabled: canSwitch,
                    title: Text(
                      AppLocalizations.of(context)?.switchCamera ?? 'Switch Camera',
                      style: TextStyle(
                        color: canSwitch ? Colors.white : Colors.white38,
                      ),
                    ),
                    subtitle: !canSwitch
                        ? Text(
                            AppLocalizations.of(context)?.turnOnCameraFirst ?? 'Turn on camera first',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          )
                        : null,
                    leading: Icon(
                      Icons.flip_camera_ios,
                      color: canSwitch ? Colors.white70 : Colors.white24,
                      size: 20,
                    ),
                    onTap: canSwitch ? () async {
                      try {
                        // SRS推流模式：使用WebRTCPublisher的switchCamera
                        if (_srsPublisher != null) {
                          final needUpdate = await _srsPublisher!.switchCamera();
                          // Web端切换后需要更新renderer
                          if (needUpdate && _localRenderer != null) {
                            _localStream = _srsPublisher!.localStream;
                            _localRenderer!.srcObject = _localStream;
                            debugPrint('[主播界面] 已更新本地视频预览');
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)?.cameraSwitched ?? 'Camera switched'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: Colors.green[700],
                              ),
                            );
                          }
                        }
                        // WebRTC P2P模式：使用Helper.switchCamera
                        else if (_localStream != null) {
                          final videoTrack = _localStream!.getVideoTracks().firstOrNull;
                          if (videoTrack != null) {
                            // Web端需要特殊处理
                            if (kIsWeb) {
                              // Web端暂不支持Helper.switchCamera，显示提示
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppLocalizations.of(context)?.cameraSwitchNotSupported ?? 'Camera switch not supported in WebRTC P2P mode on web'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: Colors.orange[700],
                                  ),
                                );
                              }
                            } else {
                              // 移动端使用Helper.switchCamera
                              await Helper.switchCamera(videoTrack);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppLocalizations.of(context)?.cameraSwitched ?? 'Camera switched'),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor: Colors.green[700],
                                  ),
                                );
                              }
                            }
                          }
                        }
                      } catch (e) {
                        debugPrint('[摄像头切换] 失败: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)?.cameraSwitchFailed ?? 'Failed to switch camera: $e'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.red[700],
                            ),
                          );
                        }
                      }
                    } : null,
                  );
                }),
                SwitchListTile(
                  dense: true,
                  title: Text(AppLocalizations.of(context)?.microphoneLabel ?? 'Microphone', style: const TextStyle(color: Colors.white)),
                  secondary: Icon(
                    _isMicOn ? Icons.mic : Icons.mic_off,
                    color: _isMicOn ? Colors.white70 : Colors.redAccent,
                    size: 20,
                  ),
                  value: _isMicOn,
                  activeColor: Colors.redAccent,
                  onChanged: (v) {
                    // 互斥保护：不能同时关闭摄像头和麦克风
                    if (!v && !_isCameraOn) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)?.cameraMicBothOff ?? 'Camera and microphone cannot both be off')),
                      );
                      return;
                    }
                    setSheetState(() {});
                    setState(() => _isMicOn = v);
                    _localStream?.getAudioTracks().forEach((t) => t.enabled = v);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 弹幕输入（带Emoji） ====================

  static const _emojis = [
    '😀', '😂', '🥰', '😍', '😘', '🤗', '😭', '😡',
    '🥺', '😊', '🎉', '❤️', '🔥', '👍', '👏', '💪',
    '🙏', '😎', '🤩', '😴', '💯', '✨', '🌹', '🎁',
    '💖', '🥳', '🤣', '😱', '😈', '💕',
  ];

  void _showDanmakuInput() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _DanmakuInputSheet(
        controller: _danmakuController,
        onSend: (content) async {
          if (content.isEmpty) return;
          final provider = Provider.of<LivestreamProvider>(context, listen: false);
          final err = await provider.sendDanmakuWithRetry(widget.livestreamId, content: content);
          if (err == null) {
            _danmakuController.clear();
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
          } else {
            // 发送失败，显示错误提示
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(err),
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.red[700],
                ),
              );
            }
          }
        },
        emojis: _emojis,
      ),
    );
  }

  void _showGiftPanel() {
    // 主播不能给自己送礼
    if (widget.isAnchor) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.cannotGiftSelf ?? 'Cannot send gifts in your own livestream')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftPanel(
        livestreamId: widget.livestreamId,
        onGiftSent: (gift) {
          // 礼物事件由WebSocket广播后在弹幕中显示
        },
      ),
    );
  }

  void _switchQuality(String quality, String url) {
    if (quality == _currentQuality) return;
    setState(() => _currentQuality = quality);

    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
    setState(() {});

    final urls = _resolvePlayablePullUrls(fallbackPullUrl: url, preferredQuality: quality);
    if (urls.isNotEmpty) {
      _initVideoPlayer(urls.first, fallbackUrls: urls.skip(1).toList());
    }
  }

  void _showPaidSessionDialog() {
    final l = AppLocalizations.of(context);
    if (_paidSessionActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l?.alreadyInPaidSession ?? 'Already in paid session')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l?.paidSessionMenuTitle ?? 'Paid Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l?.requestPaidSession ?? 'Request 1-on-1 paid session with anchor'),
            const SizedBox(height: 8),
            Text(l?.paidSessionRate(_effectivePaidCallRate) ?? '$_effectivePaidCallRate gold beans/min', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(l?.connectionTypeVideo ?? 'Type: Video Call', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _requestPaidSession();
            },
            child: Text(l?.startConnection ?? 'Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPaidSession() async {
    final provider = Provider.of<LivestreamProvider>(context, listen: false);
    final session = await provider.requestPaidSession(widget.livestreamId, sessionType: 3, ratePerMinute: _effectivePaidCallRate);
    final l = AppLocalizations.of(context);
    if (session != null && mounted) {
      setState(() => _isPaidCallParticipant = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l?.requestPaidSessionSent ?? 'Paid session request sent')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? (l?.requestFailed ?? 'Request failed'))),
      );
    }
  }

  void _showPaidSessionRequest(int sid, String requesterName, int rate, int sessionType, int requesterId) {
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l?.paidSessionRequest ?? 'Paid Session Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l?.requestPaidSessionWith(requesterName) ?? '$requesterName requests paid session'),
            const SizedBox(height: 8),
            Text(l?.paidSessionRateDisplay(rate) ?? '$rate gold beans/min', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _rejectPaidSession(sid);
            },
            child: Text(l?.rejectButton ?? 'Reject', style: const TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _acceptPaidSession(sid, rate, sessionType: sessionType, viewerId: requesterId);
            },
            child: Text(l?.acceptButton ?? 'Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptPaidSession(int sid, int rate, {int sessionType = 3, int viewerId = 0}) async {
    if (_paidSessionService == null) return;
    // LiveKit manages local media automatically via Room
    final ok = await _paidSessionService!.acceptPaidSession(sid, viewerId, sessionType: sessionType, rate: rate);
    if (ok && mounted) {
      setState(() {
        _paidSessionId = sid;
        _paidSessionActive = true;
        _isPaidCallParticipant = true;
      });
      _paidSessionOverlayKey.currentState?.startTimer();
      _chatPanelKey.currentState?.addMessage(AppLocalizations.of(context)?.systemLabel ?? 'System', AppLocalizations.of(context)?.paidSessionEstablished ?? 'Paid session established', isSystem: true);
    }
  }

  Future<void> _rejectPaidSession(int sid) async {
    final provider = Provider.of<LivestreamProvider>(context, listen: false);
    await provider.rejectPaidSession(widget.livestreamId, sid);
  }

  Future<void> _endPaidSession() async {
    await _paidSessionService?.endPaidSession();
    if (mounted) {
      setState(() {
        _paidSessionId = null;
        _paidSessionActive = false;
        _isPaidCallParticipant = false;
        _isInPaidCall = false;
      });
      _chatPanelKey.currentState?.addMessage(AppLocalizations.of(context)?.systemLabel ?? 'System', AppLocalizations.of(context)?.paidSessionEnded ?? 'Paid session ended', isSystem: true);
    }
  }

  Future<void> _loadReplays() async {
    final api = LivestreamApi(ApiClient());
    try {
      final res = await api.getRecords(widget.livestreamId);
      if (res.isSuccess && mounted) {
        final records = (res.data as List? ?? [])
            .map((e) => LivestreamRecord.fromJson(e))
            .toList();
        if (records.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LivestreamReplayScreen(record: records.first),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.replayNotReady ?? 'Replay not yet available')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.replayLoadFailed('$e') ?? 'Failed to load replay: $e')),
        );
      }
    }
  }

  // ==================== 入场横幅 ====================

  void _addEntryBanner(String nickname) {
    final banner = _EntryBanner(nickname: nickname, createdAt: DateTime.now());
    setState(() => _entryBanners.add(banner));
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _entryBanners.remove(banner));
      }
    });
  }

  Widget _buildEntryBannerWidget(_EntryBanner banner) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -200.0, end: 0.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(value, 0),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xCCFFD700), Color(0x99FFA500)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context)?.enteredLivestream(banner.nickname) ?? '${banner.nickname} joined',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 礼物连刷特效 ====================

  void _trackGiftCombo(int senderId, String senderName, String senderAvatar, String giftName, int count) {
    // 查找该用户的现有 combo
    final existing = _giftCombos.indexWhere((c) => c.senderId == senderId);
    if (existing >= 0) {
      final combo = _giftCombos[existing];
      combo.totalCount += count;
      combo.giftName = giftName;
      combo.lastTime = DateTime.now();
      // 刷新过期计时
      combo.timer?.cancel();
      combo.timer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _giftCombos.remove(combo));
      });
    } else {
      final combo = _GiftCombo(
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        giftName: giftName,
        totalCount: count,
        lastTime: DateTime.now(),
      );
      // 5秒后自动消失
      combo.timer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _giftCombos.remove(combo));
      });
      _giftCombos.add(combo);
      // 最多同时显示3条连刷
      if (_giftCombos.length > 3) {
        _giftCombos.first.timer?.cancel();
        _giftCombos.removeAt(0);
      }
    }
  }

  Widget _buildGiftComboWidget(_GiftCombo combo) {
    // 只有连刷3个以上才显示
    if (combo.totalCount < 3) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(-20 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xCC6A1B9A), Color(0x99E91E63)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: combo.senderAvatar.isNotEmpty
                  ? NetworkImage(_getFullImageUrl(combo.senderAvatar))
                  : null,
              backgroundColor: Colors.grey[600],
              child: combo.senderAvatar.isEmpty
                  ? const Icon(Icons.person, size: 14, color: Colors.white60)
                  : null,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  combo.senderName,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  AppLocalizations.of(context)?.sentGiftCombo(combo.giftName) ?? 'Sent ${combo.giftName}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Text(
              'x${combo.totalCount}',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 右侧边栏（清晰度、聊天、弹幕、分享） ====================

  Widget _buildRightSidebar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 清晰度（有多清晰度时显示）
        if (_qualityUrls.length > 1)
          _buildSidebarIcon(
            icon: Icons.hd_outlined,
            label: _qualityLabels[_currentQuality] ?? (AppLocalizations.of(context)?.originalQuality ?? 'Original'),
            onTap: _showQualityPicker,
          ),
        if (_qualityUrls.length > 1) const SizedBox(height: 14),
        // 聊天面板开关
        _buildSidebarIcon(
          icon: _showChatPanel ? Icons.chat_bubble : Icons.chat_bubble_outline,
          label: AppLocalizations.of(context)?.chatLabel ?? 'Chat',
          isActive: _showChatPanel,
          onTap: () => setState(() => _showChatPanel = !_showChatPanel),
        ),
        const SizedBox(height: 14),
        // 弹幕开关
        _buildSidebarIcon(
          icon: _showDanmaku ? Icons.subtitles : Icons.subtitles_off_outlined,
          label: AppLocalizations.of(context)?.danmakuLabel ?? 'Danmaku',
          isActive: _showDanmaku,
          onTap: () => setState(() => _showDanmaku = !_showDanmaku),
        ),
        const SizedBox(height: 14),
        // 连麦/付费连线（观众模式）
        if (!widget.isAnchor)
          _buildSidebarIcon(
            icon: Icons.group_add,
            label: _isCoHosting ? (AppLocalizations.of(context)?.cohostActiveLabel ?? 'Co-hosting') : (AppLocalizations.of(context)?.cohostLabel ?? 'Co-host'),
            isActive: !_isCoHosting,
            onTap: _isCoHosting ? () {} : _showCohostMenu,
          ),
      ],
    );
  }

  Widget _buildSidebarIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isActive ? Colors.white : Colors.white38, size: 22),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white70 : Colors.white38,
              fontSize: 10,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> get _qualityLabels => {'origin': AppLocalizations.of(context)?.originalQuality ?? 'Original', '720': '720p', '480': '480p'};

  void _showQualityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(AppLocalizations.of(context)?.selectQuality ?? 'Select Quality', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            const Divider(color: Colors.white12, height: 1),
            ..._qualityUrls.entries.map((entry) {
              final label = _qualityLabels[entry.key] ?? entry.key;
              final selected = _currentQuality == entry.key;
              return ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.redAccent : Colors.white,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: selected ? const Icon(Icons.check, color: Colors.redAccent, size: 18) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _switchQuality(entry.key, entry.value);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ==================== 连麦/付费连线菜单 ====================

  void _showCohostMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(AppLocalizations.of(context)?.interactMenu ?? 'Interactive', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _pkData != null ? Colors.grey : Colors.cyan, shape: BoxShape.circle),
                child: const Icon(Icons.group_add, color: Colors.white, size: 22),
              ),
              title: Text(AppLocalizations.of(context)?.cohostLabel ?? 'Co-host', style: TextStyle(color: _pkData != null ? Colors.white38 : Colors.white)),
              subtitle: Text(
                _pkData != null
                    ? (AppLocalizations.of(context)?.pkInProgress ?? 'Cannot co-host during PK battle')
                    : (AppLocalizations.of(context)?.cohostSubtitle ?? 'Co-host with anchor, visible to all'),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              enabled: _pkData == null,
              onTap: _pkData != null ? null : () {
                Navigator.pop(ctx);
                _requestCohost();
              },
            ),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                child: const Icon(Icons.videocam, color: Colors.white, size: 22),
              ),
              title: Text(AppLocalizations.of(context)?.paidSessionMenuTitle ?? 'Paid Session', style: const TextStyle(color: Colors.white)),
              subtitle: Text(AppLocalizations.of(context)?.paidSessionMenuSubtitle(_effectivePaidCallRate) ?? '1-on-1 video session, $_effectivePaidCallRate gold beans/min', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showPaidSessionDialog();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ==================== 观众头像列表（右上角） ====================

  Widget _buildViewerAvatars() {
    final topViewers = _topViewers;
    // 在线人数：取服务端推送数量和本地追踪数量的较大值（虚拟观众只有WS事件无DB记录）
    final onlineLen = _onlineViewers.length;
    final serverCount = _viewerCount > 0 ? _viewerCount : (_room?.viewerCount ?? 0);
    final viewerNum = onlineLen > serverCount ? onlineLen : serverCount;
    return GestureDetector(
      onTap: _showViewerList,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 前3名头像奥运五环式叠加（第1名在最上层）
            if (topViewers.isNotEmpty)
              SizedBox(
                width: 24.0 + (topViewers.length - 1) * 16.0,
                height: 26,
                child: Stack(
                  children: List.generate(topViewers.length, (i) {
                    // 反向绘制：排名靠后的先画（底层），第1名最后画（最上层）
                    final drawIdx = topViewers.length - 1 - i;
                    final viewer = topViewers[drawIdx];
                    // 排名颜色：金/银/铜
                    final borderColors = [Colors.amber, Colors.grey[300]!, Colors.orange[700]!];
                    final borderColor = drawIdx < borderColors.length ? borderColors[drawIdx] : Colors.white38;
                    return Positioned(
                      left: drawIdx * 16.0,
                      top: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 1.5),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                        ),
                        child: CircleAvatar(
                          radius: 11,
                          backgroundImage: viewer.avatar.isNotEmpty
                              ? NetworkImage(_getFullImageUrl(viewer.avatar))
                              : null,
                          backgroundColor: Colors.grey[600],
                          child: viewer.avatar.isEmpty
                              ? const Icon(Icons.person, size: 11, color: Colors.white60)
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            if (topViewers.isNotEmpty) const SizedBox(width: 4),
            Text(
              _formatCount(viewerNum),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showViewerList() {
    // 排序：置顶 > 按礼物金额降序
    final sorted = _onlineViewers.values.toList()
      ..sort((a, b) {
        final aPinned = _pinnedViewers.contains(a.userId) ? 1 : 0;
        final bPinned = _pinnedViewers.contains(b.userId) ? 1 : 0;
        if (aPinned != bPinned) return bPinned - aPinned;
        return (_viewerGiftTotals[b.userId] ?? 0).compareTo(_viewerGiftTotals[a.userId] ?? 0);
      });
    final onlineLen = _onlineViewers.length;
    final serverCount = _viewerCount > 0 ? _viewerCount : (_room?.viewerCount ?? 0);
    final viewerNum = onlineLen > serverCount ? onlineLen : serverCount;
    final isOwner = widget.isAnchor;
    final isMod = _moderatorIds.contains(_myUserId);
    final canManage = isOwner || isMod;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(AppLocalizations.of(context)?.onlineViewers ?? 'Online Viewers', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(AppLocalizations.of(context)?.viewersOnlineCount(viewerNum) ?? '$viewerNum online', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              if (sorted.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(AppLocalizations.of(context)?.noOnlineViewers ?? 'No online viewers', style: const TextStyle(color: Colors.white38)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sorted.length,
                    itemBuilder: (_, i) {
                      final v = sorted[i];
                      final gifts = _viewerGiftTotals[v.userId] ?? 0;
                      final isViewerMod = _moderatorIds.contains(v.userId);
                      final isPinned = _pinnedViewers.contains(v.userId);
                      final isAnchorUser = v.userId == (_room?.userId ?? 0);

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundImage: v.avatar.isNotEmpty
                              ? NetworkImage(_getFullImageUrl(v.avatar))
                              : null,
                          backgroundColor: Colors.grey[700],
                          child: v.avatar.isEmpty
                              ? const Icon(Icons.person, size: 16, color: Colors.white60)
                              : null,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(v.nickname, style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis),
                            ),
                            if (isViewerMod) ...[
                              const SizedBox(width: 4),
                              const Text('\u{1F6E1}\u{FE0F}', style: TextStyle(fontSize: 12)),
                            ],
                            if (isPinned) ...[
                              const SizedBox(width: 4),
                              const Text('\u{1F4CC}', style: TextStyle(fontSize: 12)),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.diamond, color: gifts > 0 ? Colors.amber : Colors.white12, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              gifts > 0 ? _formatCount(gifts) : '0',
                              style: TextStyle(color: gifts > 0 ? Colors.amber : Colors.white24, fontSize: 13),
                            ),
                            // 管理按钮（不对主播自己显示）
                            if (canManage && !isAnchorUser) ...[
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                                color: Colors.grey[850],
                                onSelected: (action) {
                                  Navigator.pop(ctx);
                                  _handleViewerAction(action, v.userId, v.nickname);
                                },
                                itemBuilder: (_) => [
                                  // 主播专属操作
                                  if (isOwner) ...[
                                    PopupMenuItem(
                                      value: isPinned ? 'unpin' : 'pin',
                                      child: Row(
                                        children: [
                                          Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: Colors.amber, size: 18),
                                          const SizedBox(width: 8),
                                          Text(isPinned ? (AppLocalizations.of(context)?.unpinUser ?? 'Unpin') : (AppLocalizations.of(context)?.pinUser ?? 'Pin')),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: isViewerMod ? 'remove_mod' : 'add_mod',
                                      child: Row(
                                        children: [
                                          Icon(isViewerMod ? Icons.shield_outlined : Icons.shield, color: Colors.cyan, size: 18),
                                          const SizedBox(width: 8),
                                          Text(isViewerMod ? (AppLocalizations.of(context)?.removeModerator ?? 'Remove Mod') : (AppLocalizations.of(context)?.setModerator ?? 'Set as Mod')),
                                        ],
                                      ),
                                    ),
                                  ],
                                  // 主播+房管共享操作
                                  PopupMenuItem(
                                    value: 'mute',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.volume_off, color: Colors.orange, size: 18),
                                        const SizedBox(width: 8),
                                        Text(AppLocalizations.of(context)?.muteUserAction ?? 'Mute'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'kick',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 18),
                                        const SizedBox(width: 8),
                                        Text(AppLocalizations.of(context)?.kickUserAction ?? 'Kick'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _handleViewerAction(String action, int targetUserId, String nickname) {
    switch (action) {
      case 'pin':
        setState(() => _pinnedViewers.add(targetUserId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.pinnedUser(nickname) ?? 'Pinned $nickname')),
        );
        break;
      case 'unpin':
        setState(() => _pinnedViewers.remove(targetUserId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.unpinnedUser(nickname) ?? 'Unpinned $nickname')),
        );
        break;
      case 'add_mod':
        _addModerator(targetUserId, nickname);
        break;
      case 'remove_mod':
        _removeModerator(targetUserId, nickname);
        break;
      case 'mute':
        _showMuteDurationPicker(targetUserId, nickname);
        break;
      case 'kick':
        _kickUser(targetUserId, nickname);
        break;
    }
  }

  Future<void> _addModerator(int targetUserId, String nickname) async {
    final api = LivestreamApi(ApiClient());
    final res = await api.addModerator(widget.livestreamId, targetUserId);
    if (res.isSuccess && mounted) {
      setState(() => _moderatorIds.add(targetUserId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)?.setModerator ?? 'Set as Mod'}: $nickname')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? (AppLocalizations.of(context)?.operationFailed ?? 'Operation failed'))),
      );
    }
  }

  Future<void> _removeModerator(int targetUserId, String nickname) async {
    final api = LivestreamApi(ApiClient());
    final res = await api.removeModerator(widget.livestreamId, targetUserId);
    if (res.isSuccess && mounted) {
      setState(() => _moderatorIds.remove(targetUserId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)?.removeModerator ?? 'Remove Mod'}: $nickname')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? (AppLocalizations.of(context)?.operationFailed ?? 'Operation failed'))),
      );
    }
  }

  void _showMuteDurationPicker(int targetUserId, String nickname) {
    final durations = [
      {'label': '5 min', 'value': 5},
      {'label': '15 min', 'value': 15},
      {'label': '30 min', 'value': 30},
      {'label': '60 min', 'value': 60},
      {'label': '∞', 'value': 0},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${AppLocalizations.of(context)?.muteUserAction ?? 'Mute'} $nickname', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            const Divider(color: Colors.white12, height: 1),
            ...durations.map((d) => ListTile(
              title: Text(d['label'] as String, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _muteUser(targetUserId, d['value'] as int);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _muteUser(int targetUserId, int durationMinutes) async {
    final api = LivestreamApi(ApiClient());
    final res = await api.banUser(widget.livestreamId,
      userId: targetUserId,
      banType: 1,
      duration: durationMinutes,
    );
    if (res.isSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.muteUserAction ?? 'Muted')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? (AppLocalizations.of(context)?.operationFailed ?? 'Operation failed'))),
      );
    }
  }

  Future<void> _kickUser(int targetUserId, String nickname) async {
    final api = LivestreamApi(ApiClient());
    final res = await api.banUser(widget.livestreamId,
      userId: targetUserId,
      banType: 2,
    );
    if (res.isSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)?.kickUserAction ?? 'Kicked'}: $nickname')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? (AppLocalizations.of(context)?.operationFailed ?? 'Operation failed'))),
      );
    }
  }

  // ==================== 连麦交互 ====================

  void _showCohostRequestDialog(int userId, String nickname) {
    showDialog(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
        title: Text(l?.paidCallRequest ?? 'Co-host Request'),
        content: Text(l?.cohostRequest(nickname) ?? '$nickname requests co-host'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _coHostService?.rejectCoHost(userId);
            },
            child: Text(l?.rejectButton ?? 'Reject', style: const TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _acceptCohost(userId);
            },
            child: Text(l?.acceptButton ?? 'Accept'),
          ),
        ],
      );
      },
    );
  }

  Future<void> _acceptCohost(int userId) async {
    if (_coHostService == null) return;
    
    // 主播端：请求摄像头和麦克风权限
    try {
      if (!kIsWeb) {
        final cameraStatus = await Permission.camera.request();
        final micStatus = await Permission.microphone.request();
        
        if (!cameraStatus.isGranted || !micStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              //const SnackBar(content: Text('Camera/Microphone permission denied. Please enable in settings.')),
              SnackBar(content: Text('Camera/Microphone permission denied. Please enable in settings.')),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('[连麦] 主播权限请求失败: $e');
    }
    
    // LiveKit版本: 服务端会通过WS推送Token，CoHostService自动连接LiveKit Room
    final ok = await _coHostService!.acceptCoHost(userId);
    if (mounted) {
      if (ok) {
        _chatPanelKey.currentState?.addMessage(AppLocalizations.of(context)?.systemLabel ?? 'System', AppLocalizations.of(context)?.cohostEstablished ?? 'Co-host established', isSystem: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.operationFailed ?? 'Failed')),
        );
      }
    }
  }

  Future<void> _requestCohost() async {
    if (_coHostService == null) return;
    // PK进行中禁止连麦
    if (_pkData != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.pkInProgress ?? 'Cannot co-host during PK battle')),
        );
      }
      return;
    }
    // 检查当前连麦人数是否已满（最多6人）
    if (_coHostInfos.length >= 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Co-host slots full (max 6)')),
        );
      }
      return;
    }
    
    // 请求摄像头和麦克风权限
    try {
      if (!kIsWeb) {
        final cameraStatus = await Permission.camera.request();
        final micStatus = await Permission.microphone.request();
        
        if (!cameraStatus.isGranted || !micStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              //const SnackBar(content: Text('Camera/Microphone permission denied. Please enable in settings.')),
              SnackBar(content: Text('Camera/Microphone permission denied. Please enable in settings.')),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('[连麦] 权限请求失败: $e');
    }
    
    final ok = await _coHostService!.requestCoHost();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? (AppLocalizations.of(context)?.requestPaidSessionSent ?? 'Request sent, waiting for anchor') : (AppLocalizations.of(context)?.requestFailed ?? 'Request failed'))),
      );
    }
  }

  /// 从 LiveKit identity (格式: "user_{id}") 解析用户ID
  int _parseUserIdFromIdentity(String identity) {
    if (identity.startsWith('user_')) {
      return int.tryParse(identity.substring(5)) ?? 0;
    }
    return 0;
  }

  bool _hasPublishableTrack(Participant participant) {
    final hasAudio = participant.audioTrackPublications.any((pub) => !pub.muted && pub.track != null);
    final hasVideo = participant.videoTrackPublications.any((pub) => !pub.muted && pub.track != null);
    return hasAudio || hasVideo;
  }

  bool _shouldDisplayCohostParticipant(Participant participant, {required int uid, required int anchorId}) {
    if (uid <= 0) return false;
    // 只显示主播和已接受的连麦用户
    if (uid == anchorId) return true;
    if (_activeCoHostUserIds.contains(uid)) return true;
    // 不显示普通观众（即使他们有 LiveKit token 用于观看）
    return false;
  }


  /// 切换拉流地址（连麦混流开始/结束时调用）
  void _switchPullUrl(String newUrl) {
    debugPrint('[StreamSwitch] 切换拉流地址: $newUrl');
    // 销毁旧播放器
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
    // 用新URL重新初始化
    _initVideoPlayer(newUrl);
  }

  // ==================== 分享功能 ====================

  void _showShareSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(AppLocalizations.of(context)?.shareLivestream ?? 'Share Livestream', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _shareOption(Icons.person, AppLocalizations.of(context)?.friendsLabel ?? 'Friends', () => Navigator.pop(ctx, 'friend')),
                _shareOption(Icons.group, AppLocalizations.of(context)?.groupChatLabel ?? 'Group Chat', () => Navigator.pop(ctx, 'group')),
                _shareOption(Icons.article, AppLocalizations.of(context)?.momentsLabel ?? 'Moments', () => Navigator.pop(ctx, 'moment')),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );

    if (!mounted || result == null) return;

    // 等待底部面板退场动画完成，避免与后续弹窗冲突导致灰屏
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    switch (result) {
      case 'friend':
        _openShareSheet(initialTab: 0);
        break;
      case 'group':
        _openShareSheet(initialTab: 1);
        break;
      case 'moment':
        _shareToMoment();
        break;
    }
  }

  Widget _shareOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  void _openShareSheet({int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LivestreamShareSheet(
        livestreamId: widget.livestreamId,
        title: _room?.title ?? (AppLocalizations.of(context)?.livestreamRoom ?? 'Livestream'),
        coverUrl: _room?.coverUrl ?? '',
        anchorName: _room?.user?.nickname ?? (AppLocalizations.of(context)?.anchorLabel ?? 'Anchor'),
        initialTab: initialTab,
      ),
    );
  }

  void _shareToMoment() {
    final l = AppLocalizations.of(context);
    final title = _room?.title ?? (l?.livestreamRoom ?? 'Livestream');
    final coverUrl = _room?.coverUrl ?? '';
    final anchorName = _room?.user?.nickname ?? '';
    final controller = TextEditingController(text: l?.livestreamSharingText(title) ?? 'Live streaming "$title", come watch!');

    showDialog(
      context: context,
      builder: (ctx) {
        final dl = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(dl?.shareToMoments ?? 'Share to Moments'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 直播间预览卡片
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (coverUrl.isNotEmpty)
                      Image.network(
                        _getFullImageUrl(coverUrl),
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 100,
                          color: Colors.grey[300],
                          child: const Icon(Icons.live_tv, size: 40),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          const Icon(Icons.live_tv, size: 16, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: dl?.saySomething ?? 'Say something...',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(dl?.cancel ?? 'Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final momentApi = MomentApi(ApiClient());
                final extra = jsonEncode({
                  'type': 'livestream_share',
                  'livestream_id': widget.livestreamId,
                  'title': _room?.title ?? '',
                  'cover_url': coverUrl,
                  'anchor_name': anchorName,
                  'anchor_id': _room?.userId ?? 0,
                });
                final res = await momentApi.createMoment(
                  content: controller.text,
                  extra: extra,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res.success ? (l?.sharedToMoments ?? 'Shared to Moments') : '${l?.shareFailed ?? 'Share Failed'}: ${res.message}')),
                  );
                }
              },
              child: Text(dl?.publishButton ?? 'Publish'),
            ),
          ],
        );
      },
    );
  }

  String _formatCount(int count) {
    final unit = AppLocalizations.of(context)?.tenThousandUnit ?? 'k';
    if (unit == 'k') {
      // Western-style: 1k, 10k, 100k
      if (count >= 1000) {
        return '${(count / 1000).toStringAsFixed(1)}k';
      }
    } else {
      // CJK-style: 1万/萬
      if (count >= 10000) {
        return '${(count / 10000).toStringAsFixed(1)}$unit';
      }
      if (count >= 1000) {
        return '${(count / 1000).toStringAsFixed(1)}k';
      }
    }
    return count.toString();
  }
}

// ==================== 弹幕输入底部Sheet（含Emoji） ====================

class _DanmakuInputSheet extends StatefulWidget {
  final TextEditingController controller;
  final Future<void> Function(String content) onSend;
  final List<String> emojis;

  const _DanmakuInputSheet({
    required this.controller,
    required this.onSend,
    required this.emojis,
  });

  @override
  State<_DanmakuInputSheet> createState() => _DanmakuInputSheetState();
}

class _DanmakuInputSheetState extends State<_DanmakuInputSheet> {
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _insertEmoji(String emoji) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final pos = selection.isValid ? selection.baseOffset : text.length;
    final newText = text.substring(0, pos) + emoji + text.substring(pos);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      padding: EdgeInsets.only(
        bottom: _showEmojiPicker ? 0 : MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 输入行
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (text) => widget.onSend(text.trim()),
                      cursorColor: Colors.white,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)?.sendDanmakuHint ?? 'Send danmaku...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  // 表情切换按钮
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showEmojiPicker = !_showEmojiPicker;
                        if (_showEmojiPicker) {
                          _focusNode.unfocus();
                        } else {
                          _focusNode.requestFocus();
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                        color: Colors.white54,
                        size: 24,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onSend(widget.controller.text.trim()),
                    child: Text(AppLocalizations.of(context)?.sendButton ?? 'Send'),
                  ),
                ],
              ),
            ),
            // Emoji 网格
            if (_showEmojiPicker)
              Container(
                height: 200,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: widget.emojis.length,
                  itemBuilder: (ctx, i) => GestureDetector(
                    onTap: () => _insertEmoji(widget.emojis[i]),
                    child: Center(
                      child: Text(widget.emojis[i], style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== 入场横幅数据 ====================

class _EntryBanner {
  final String nickname;
  final DateTime createdAt;

  _EntryBanner({required this.nickname, required this.createdAt});
}

// ==================== 礼物连刷数据 ====================

class _GiftCombo {
  final int senderId;
  final String senderName;
  final String senderAvatar;
  String giftName;
  int totalCount;
  DateTime lastTime;
  Timer? timer;

  _GiftCombo({
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.giftName,
    required this.totalCount,
    required this.lastTime,
  });
}

// ==================== 在线观众信息 ====================

class _ViewerInfo {
  final int userId;
  final String nickname;
  final String avatar;

  _ViewerInfo({
    required this.userId,
    required this.nickname,
    this.avatar = '',
  });
}

/// 音频直播波纹动画组件
class _AudioPulseWidget extends StatefulWidget {
  final Widget child;
  const _AudioPulseWidget({required this.child});

  @override
  State<_AudioPulseWidget> createState() => _AudioPulseWidgetState();
}

class _AudioPulseWidgetState extends State<_AudioPulseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // 外圈波纹
            Container(
              width: 100 + 40 * _controller.value,
              height: 100 + 40 * _controller.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3 * (1 - _controller.value)),
                  width: 2,
                ),
              ),
            ),
            // 中圈波纹
            Container(
              width: 100 + 20 * _controller.value,
              height: 100 + 20 * _controller.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2 * (1 - _controller.value)),
                  width: 1.5,
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}
