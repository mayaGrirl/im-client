/// 聊天页面
/// 显示与单个用户或群组的消息

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart' show Dio, Options, ResponseType;
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/conversation_api.dart';
import 'package:im_client/api/favorite_api.dart';
import 'package:im_client/api/emoji_api.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/api/upload_api.dart';
import 'package:im_client/api/user_api.dart';
import 'package:im_client/api/system_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/models/message.dart';
import 'package:im_client/models/group.dart';
import 'package:im_client/models/system.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/providers/app_config_provider.dart';
import 'package:im_client/providers/chat_provider.dart';
import 'package:im_client/providers/group_call_provider.dart';
import 'package:im_client/screens/call/group_call_overlay.dart';
import 'package:im_client/services/websocket_service.dart';
import 'package:im_client/services/local_message_service.dart';
import 'package:im_client/services/chat_settings_service.dart';
import 'package:im_client/services/settings_service.dart';
import 'package:im_client/services/voice_record_service.dart';
import 'package:im_client/widgets/emoji_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:im_client/widgets/forward_message_card.dart';
import 'package:im_client/screens/chat/forward_target_screen.dart';
import 'package:im_client/modules/small_video/api/small_video_api.dart';
import 'package:im_client/modules/small_video/models/small_video.dart';
import 'package:im_client/modules/small_video/screens/video_detail_screen.dart';
import 'package:im_client/modules/livestream/screens/livestream_viewer_screen.dart';
import 'package:im_client/screens/group/group_info_screen.dart';
import 'package:im_client/screens/group/group_requests_screen.dart';
import 'package:im_client/screens/call/call_screen.dart';
import 'package:im_client/api/call_api.dart';
import 'package:im_client/utils/web_download.dart' as web_download;
// 条件导入：移动端使用 image_gallery_saver
import 'package:im_client/utils/image_saver_stub.dart'
    if (dart.library.io) 'package:im_client/utils/image_saver_mobile.dart'
    if (dart.library.html) 'package:im_client/utils/image_saver_web.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../utils/image_proxy.dart';

/// 聊天页面
class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final String? targetMsgId; // 定位到的目标消息ID

  const ChatScreen({
    super.key,
    required this.conversation,
    this.targetMsgId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ConversationApi _conversationApi = ConversationApi(ApiClient());
  final FriendApi _friendApi = FriendApi(ApiClient());
  final UploadApi _uploadApi = UploadApi(ApiClient());
  final FavoriteApi _favoriteApi = FavoriteApi(ApiClient());
  final UserApi _userApi = UserApi(ApiClient());
  final WebSocketService _wsService = WebSocketService();
  final LocalMessageService _localMessageService = LocalMessageService();
  final ChatSettingsService _chatSettingsService = ChatSettingsService();
  final ImagePicker _imagePicker = ImagePicker();
  final VoiceRecordService _voiceRecordService = VoiceRecordService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Message> _messages = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isSending = false;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _clearSubscription;
  StreamSubscription? _recallSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _voiceDurationSubscription;
  StreamSubscription? _redPacketSubscription;
  StreamSubscription? _messageBlockedSubscription;

  // 聊天背景图、免打扰和置顶设置
  String? _backgroundImagePath;
  bool _isMuted = false;
  bool _isTop = false; // 是否置顶
  bool _showMemberNickname = true; // 群聊中是否显示成员昵称

  // 字体大小设置
  final SettingsService _settingsService = SettingsService();
  double _messageFontSize = 15.0;

  // 选择模式状态
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  // 回复消息状态
  Message? _replyingTo;

  // 语音录制状态
  bool _isRecording = false;
  int _recordDuration = 0;
  String? _playingVoiceMsgId; // 当前正在播放的语音消息ID

  // 显示名称（用于备注更新后刷新标题）
  String _displayName = '';

  // 高亮消息ID（用于定位搜索结果）
  String? _highlightedMsgId;

  // 群聊禁言状态
  final GroupApi _groupApi = GroupApi(ApiClient());
  bool _isGroupMuted = false;      // 是否被禁言（个人或全员）
  String _muteReason = '';         // 禁言原因文本

  // 群通话设置（动态更新）
  bool _isGroupPaid = false;      // 是否付费群（只有付费群才能使用通话功能）
  bool _allowGroupCall = false;
  bool _allowVoiceCall = false;
  bool _allowVideoCall = false;
  ActiveGroupCall? _activeGroupCall; // 当前进行中的群通话
  StreamSubscription? _groupSettingsSubscription;
  StreamSubscription? _groupCallUpdateSubscription;

  // 客服FAQ相关
  final SystemApi _systemApi = SystemApi();
  bool _isCustomerServiceChat = false;  // 是否是与客服的会话
  List<CustomerServiceFAQ> _faqs = [];  // 常见问题列表
  bool _showFAQs = true;                 // 是否显示FAQ面板
  int? _expandedFAQId;                   // 当前展开的FAQ ID

  late final ChatProvider _chatProvider;

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
    // 初始化显示名称
    _displayName = widget.conversation.name;
    // 初始化高亮消息ID
    _highlightedMsgId = widget.targetMsgId;
    // 初始化群通话设置（从conversation中获取初始值）
    _initGroupCallSettings();
    // 设置当前活动会话（用于判断未读数）
    _chatProvider.setActiveConversation(widget.conversation.conversId);
    _initAndLoadMessages();
    _loadChatSettings();
    _loadFontSizeSetting(); // 加载字体大小设置
    _loadGroupMuteStatus(); // 加载群聊禁言状态
    _checkCustomerServiceChat(); // 检查是否是客服会话
    _subscribeToMessages();
    _subscribeToClearNotification();
    _subscribeToRecallNotification();
    _subscribeToConnectionStatus();
    _subscribeToVoiceDuration();
    _subscribeToRedPacketNotification();
    _subscribeToMessageBlocked();
    _subscribeToGroupSettingsUpdate(); // 订阅群设置更新
    _subscribeToGroupCallUpdates(); // 订阅群通话状态更新
  }

  /// 初始化群通话设置
  void _initGroupCallSettings() {
    if (widget.conversation.isGroup) {
      _isGroupPaid = widget.conversation.targetInfo?['is_paid'] == true;
      _allowGroupCall = widget.conversation.targetInfo?['allow_group_call'] == true;
      _allowVoiceCall = widget.conversation.targetInfo?['allow_voice_call'] == true;
      _allowVideoCall = widget.conversation.targetInfo?['allow_video_call'] == true;
    }
  }

  /// 订阅群设置更新
  void _subscribeToGroupSettingsUpdate() {
    if (!widget.conversation.isGroup) return;

    _groupSettingsSubscription = _chatProvider.groupSettingsUpdateStream.listen((data) {
      final groupId = data['group_id'];
      if (groupId == widget.conversation.targetId) {
        // 群设置已更新，重新获取群组信息
        _refreshGroupCallSettings();
      }
    });
  }

  /// 刷新群通话设置
  Future<void> _refreshGroupCallSettings() async {
    if (!widget.conversation.isGroup) return;

    try {
      final groupInfo = await _groupApi.getGroupFullInfo(widget.conversation.targetId);
      if (groupInfo != null && mounted) {
        setState(() {
          _isGroupPaid = groupInfo.group.isPaid;
          _allowGroupCall = groupInfo.group.allowGroupCall;
          _allowVoiceCall = groupInfo.group.allowVoiceCall;
          _allowVideoCall = groupInfo.group.allowVideoCall;
          _activeGroupCall = groupInfo.activeCall;
        });
      }
    } catch (e) {
      debugPrint('刷新群通话设置失败: $e');
    }
  }

  /// 订阅群通话状态更新（通话发起/结束时更新横幅）
  void _subscribeToGroupCallUpdates() {
    if (!widget.conversation.isGroup) return;

    _groupCallUpdateSubscription = _wsService.messageStream.listen((message) {
      final type = message['type'];
      if (type != 'group_call') return;

      final data = message['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final groupId = data['group_id'];
      if (groupId != widget.conversation.targetId) return;

      final action = data['action'] as String?;
      if (!mounted) return;

      switch (action) {
        case 'initiated':
          // 新通话发起，设置活跃通话
          final callId = data['call_id'] is int
              ? data['call_id'] as int
              : (data['call_id'] as num?)?.toInt() ?? 0;
          final callType = data['call_type'] is int
              ? data['call_type'] as int
              : (data['call_type'] as num?)?.toInt() ?? 1;
          final initiatorName = data['initiator_name'] as String? ?? '';
          final initiatorId = data['from_user_id'] is int
              ? data['from_user_id'] as int
              : (data['from_user_id'] as num?)?.toInt() ?? 0;
          setState(() {
            _activeGroupCall = ActiveGroupCall(
              callId: callId,
              callType: callType,
              initiatorId: initiatorId,
              initiatorName: initiatorName,
              currentCount: 1,
              startedAt: DateTime.now(),
            );
          });
          break;
        case 'joined':
          // 有人加入，本地递增参与人数
          if (_activeGroupCall != null) {
            setState(() {
              _activeGroupCall = _activeGroupCall!.copyWith(
                currentCount: _activeGroupCall!.currentCount + 1,
              );
            });
          }
          break;
        case 'left':
          final callEnded = data['ended'] == true;
          if (callEnded) {
            setState(() {
              _activeGroupCall = null;
            });
          } else if (_activeGroupCall != null) {
            // 有人离开但通话继续，本地递减参与人数
            setState(() {
              _activeGroupCall = _activeGroupCall!.copyWith(
                currentCount: (_activeGroupCall!.currentCount - 1).clamp(0, 999),
              );
            });
          }
          break;
        case 'ended':
        case 'timeout_ended':
          setState(() {
            _activeGroupCall = null;
          });
          break;
        case 'timeout_cancelled':
          // 超时取消但通话继续
          break;
      }
    });
  }

  /// 订阅语音录制时长
  void _subscribeToVoiceDuration() {
    _voiceDurationSubscription = _voiceRecordService.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _recordDuration = duration;
        });
      }
    });
  }

  /// 加载聊天设置（背景图、免打扰状态、置顶状态）
  Future<void> _loadChatSettings() async {
    await _chatSettingsService.init();
    // 使用优先级逻辑：会话特定背景 > 全局背景
    final globalBg = SettingsService().globalChatBackground;
    final bgPath = await _chatSettingsService.getEffectiveBackgroundImage(
      widget.conversation.conversId,
      globalBg,
    );
    final muted = await _chatSettingsService.isMuted(widget.conversation.conversId);
    // 从本地获取置顶状态
    final conv = await _localMessageService.getConversation(widget.conversation.conversId);
    final isTop = conv?.isTop ?? widget.conversation.isTop;
    if (mounted) {
      setState(() {
        _backgroundImagePath = bgPath;
        _isMuted = muted;
        _isTop = isTop;
      });
    }
  }

  /// 加载字体大小设置
  void _loadFontSizeSetting() {
    // 使用基础字体大小乘以缩放比例，用于计算消息气泡宽度
    _messageFontSize = 15.0 * _settingsService.fontSize.scale;
    _settingsService.addListener(_onFontSizeChanged);
  }

  /// 字体大小设置变化回调
  void _onFontSizeChanged() {
    if (mounted) {
      setState(() {
        _messageFontSize = 15.0 * _settingsService.fontSize.scale;
      });
    }
  }

  /// 加载群聊禁言状态和显示设置
  Future<void> _loadGroupMuteStatus() async {
    // 只有群聊才需要检查禁言状态
    if (!widget.conversation.isGroup) return;

    try {
      final currentUserId = context.read<AuthProvider>().user?.id;
      if (currentUserId == null) {
        return;
      }

      final groupInfo = await _groupApi.getGroupFullInfo(widget.conversation.targetId);
      if (groupInfo == null || !mounted) return;

      final group = groupInfo.group;
      final myRole = groupInfo.myRole;
      final isAdminOrOwner = myRole >= 1; // 1=管理员 2=群主

      // 加载"显示群成员昵称"设置
      final showNickname = groupInfo.mySettings.showNickname;
      if (mounted) {
        setState(() {
          _showMemberNickname = showNickname;
          _activeGroupCall = groupInfo.activeCall;
        });
      }

      bool isMuted = false;
      String reason = '';

      // 管理员和群主不受禁言限制
      if (isAdminOrOwner) {
        if (mounted) {
          setState(() {
            _isGroupMuted = false;
            _muteReason = '';
          });
        }
        return;
      }

      // 检查个人禁言（优先级更高）
      final members = await _groupApi.getGroupMembers(widget.conversation.targetId);
      final myMember = members.where((m) => m.userId == currentUserId).firstOrNull;

      if (myMember != null && myMember.isMute) {
        // 检查个人禁言是否有结束时间且已过期
        if (myMember.muteEndTime != null && DateTime.now().isAfter(myMember.muteEndTime!)) {
          // 禁言已过期，不算禁言
        } else {
          isMuted = true;
          reason = AppLocalizations.of(context)?.translate('you_are_muted') ?? 'You have been muted.';
        }
      }

      // 如果没有个人禁言，再检查全员禁言
      if (!isMuted && group.muteAll) {
        // 检查全员禁言是否有结束时间且已过期
        if (group.muteEndTime != null && DateTime.now().isAfter(group.muteEndTime!)) {
          // 全员禁言已过期，不算禁言
        } else {
          isMuted = true;
          reason = AppLocalizations.of(context)?.translate('group_muted_all') ?? 'The group chat is currently muted for all members.';
        }
      }

      if (mounted) {
        setState(() {
          _isGroupMuted = isMuted;
          _muteReason = reason;
        });
      }
    } catch (e) {
      // 加载失败时默认不禁言（避免误杀）
      if (mounted) {
        setState(() {
          _isGroupMuted = false;
          _muteReason = '';
        });
      }
    }
  }

  /// 检查是否是客服会话并加载FAQ
  Future<void> _checkCustomerServiceChat() async {
    // 只有私聊才可能是客服会话
    if (widget.conversation.isGroup) {
      return;
    }

    try {
      // 获取客服列表
      final services = await _systemApi.getCustomerServices();

      // 检查对方是否是客服
      final isCustomerService = services.any((s) => s.userId == widget.conversation.targetId);

      if (isCustomerService && mounted) {
        // 加载FAQ列表
        final faqs = await _systemApi.getCustomerServiceFAQs();

        setState(() {
          _isCustomerServiceChat = true;
          _faqs = faqs;
          _showFAQs = faqs.isNotEmpty;
        });
      }
    } catch (e) {
      // 检查客服会话失败，忽略
    }
  }

  /// 处理FAQ点击（展开/收起答案）
  void _onFAQTap(CustomerServiceFAQ faq) {
    // 记录点击
    _systemApi.clickFAQ(faq.id);

    setState(() {
      if (_expandedFAQId == faq.id) {
        // 已展开，收起
        _expandedFAQId = null;
      } else {
        // 展开当前FAQ
        _expandedFAQId = faq.id;
      }
    });
  }

  /// 发起通话
  void _startCall(int callType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          targetUserId: widget.conversation.targetId,
          targetUserName: widget.conversation.name,
          targetUserAvatar: widget.conversation.avatar,
          callType: callType,
          isIncoming: false,
        ),
      ),
    );
  }

  /// 发起群通话
  Future<void> _startGroupCall(int callType) async {
    final l10n = AppLocalizations.of(context)!;

    final provider = context.read<GroupCallProvider>();

    // Check if already in a call
    if (provider.isBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('already_in_call')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final groupId = widget.conversation.targetId;
    final groupName = widget.conversation.name;

    final (success, errorMsg) = await provider.initiateCall(groupId, callType, groupName: groupName);

    if (success && mounted) {
      // Show floating overlay
      GroupCallOverlayManager.show(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('group_call_initiated')),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg ?? l10n.translate('group_call_failed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 显示用户资料
  Future<void> _showUserProfile() async {
    final targetInfo = widget.conversation.targetInfo;
    
    debugPrint('[ChatScreen] _showUserProfile called, targetInfo: $targetInfo');
    
    if (targetInfo == null) {
      debugPrint('[ChatScreen] targetInfo is null');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.loadFailed)),
        );
      }
      return;
    }

    // 从 targetInfo Map 中获取用户 ID
    int? userId;
    if (targetInfo is Map) {
      userId = targetInfo['id'] as int?;
      debugPrint('[ChatScreen] Extracted userId from Map: $userId');
    } else {
      debugPrint('[ChatScreen] targetInfo is not a Map, type: ${targetInfo.runtimeType}');
    }
    
    // 如果没有 id，尝试使用 targetId
    if (userId == null) {
      userId = widget.conversation.targetId;
      debugPrint('[ChatScreen] Using conversation.targetId: $userId');
    }
    
    if (userId == null || userId == 0) {
      debugPrint('[ChatScreen] Invalid userId: $userId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.loadFailed)),
        );
      }
      return;
    }

    // 先从 targetInfo 获取基本信息
    String displayName = '';
    String username = '';
    String avatar = '';
    String? bio;
    int? gender;
    String? region;
    
    if (targetInfo is Map) {
      displayName = targetInfo['nickname'] as String? ?? 
                   targetInfo['username'] as String? ?? '';
      username = targetInfo['username'] as String? ?? '';
      avatar = targetInfo['avatar'] as String? ?? '';
      bio = targetInfo['bio'] as String?;
      gender = targetInfo['gender'] as int?;
      region = targetInfo['region'] as String?;
    }

    // 显示加载对话框
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    // 尝试获取用户详细信息
    Map<String, dynamic>? userInfo;
    try {
      debugPrint('[ChatScreen] Calling getUserById with userId: $userId');
      userInfo = await _userApi.getUserById(userId);
      debugPrint('[ChatScreen] getUserById result: $userInfo');
    } catch (e) {
      debugPrint('[ChatScreen] Error calling getUserById: $e');
    }

    if (!mounted) return;
    Navigator.pop(context); // 关闭加载对话框

    // 如果 API 调用成功，使用 API 返回的信息补充
    if (userInfo != null) {
      displayName = userInfo['nickname'] as String? ?? displayName;
      username = userInfo['username'] as String? ?? username;
      avatar = userInfo['avatar'] as String? ?? avatar;
      bio = userInfo['bio'] as String? ?? bio;
      gender = userInfo['gender'] as int? ?? gender;
      region = userInfo['region'] as String? ?? region;
    }
    
    // 如果还是没有显示名称，使用默认值
    if (displayName.isEmpty) {
      displayName = AppLocalizations.of(context)!.unknownUser;
    }
    
    debugPrint('[ChatScreen] Showing profile: displayName=$displayName, username=$username, avatar=$avatar');

    // 导航到用户资料页面
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _UserProfileScreen(
            userId: userId!,
            displayName: displayName,
            username: username,
            avatar: avatar,
            bio: bio,
            gender: gender,
            region: region,
            isCustomerService: _isCustomerServiceChat,
            onAddFriend: () {
              Navigator.pop(context);
              _addFriend();
            },
          ),
        ),
      );
    }
  }

  /// 构建资料页操作按钮
  Widget _buildProfileAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  /// 添加好友
  void _addFriend() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await _friendApi.addFriend(
        userId: widget.conversation.targetId,
        message: l10n.translate('hello_intro').replaceAll('...', context.read<AuthProvider>().user?.nickname ?? l10n.translate('user_prefix')),
        source: 'chat',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success ? l10n.translate('friend_request_sent') : (result.message ?? l10n.translate('request_send_failed'))),
            backgroundColor: result.success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate("request_send_failed")}: $e')),
        );
      }
    }
  }

  /// 从相册选择聊天背景图
  Future<void> _pickBackgroundImage() async {
    try {
      // 显示选择对话框
      final action = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.chatBackground,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library, color: AppColors.primary),
                ),
                title: Text(AppLocalizations.of(context)!.selectFromAlbum),
                onTap: () => Navigator.pop(context, 'pick'),
              ),
              if (_backgroundImagePath != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: Text(AppLocalizations.of(context)!.translate('remove_background')),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );

      if (action == null) return;

      if (action == 'remove') {
        // 移除背景图
        await _chatSettingsService.clearBackgroundImage(widget.conversation.conversId);
        setState(() {
          _backgroundImagePath = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.translate('background_removed'))),
          );
        }
        return;
      }

      // 从相册选择图片
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        // 保存背景图路径
        await _chatSettingsService.setBackgroundImage(
          widget.conversation.conversId,
          pickedFile.path,
        );
        setState(() {
          _backgroundImagePath = pickedFile.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.translate('background_set'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.translate("set_background_failed")}: $e')),
        );
      }
    }
  }

  /// 切换消息免打扰状态
  Future<void> _toggleMuteStatus() async {
    final l10n = AppLocalizations.of(context)!;
    final newMuted = !_isMuted;
    // 乐观更新
    setState(() {
      _isMuted = newMuted;
    });

    try {
      await _chatSettingsService.toggleMuted(widget.conversation.conversId);
      // 同步更新会话列表
      await _chatProvider.toggleConversationMute(widget.conversation.conversId, newMuted);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newMuted ? l10n.translate('mute_enabled') : l10n.translate('notification_enabled')),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // 回滚
      setState(() {
        _isMuted = !newMuted;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('setting_failed'))),
        );
      }
    }
  }

  /// 切换置顶状态
  Future<void> _toggleTopStatus() async {
    final newTop = !_isTop;
    // 乐观更新
    setState(() {
      _isTop = newTop;
    });

    try {
      // 通过 ChatProvider 更新置顶状态（同时更新内存缓存和持久化存储）
      await _chatProvider.toggleConversationTop(widget.conversation.conversId, newTop);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newTop ? l10n.translate('pinned') : l10n.translate('unpinned')),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // 回滚
      setState(() {
        _isTop = !newTop;
      });
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('set_failed_please_retry'))),
        );
      }
    }
  }

  /// 显示修改备注对话框
  void _showEditRemarkDialog() async {
    // 先获取好友当前的备注信息
    final friendId = widget.conversation.targetId;
    final friend = await _friendApi.getFriendById(friendId);

    final remarkController = TextEditingController(text: friend?.remark ?? '');
    final phoneController = TextEditingController(text: friend?.remarkPhone ?? '');
    final emailController = TextEditingController(text: friend?.remarkEmail ?? '');
    final tagsController = TextEditingController(text: friend?.remarkTags ?? '');
    final descController = TextEditingController(text: friend?.remarkDesc ?? '');

    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题栏
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.translate('set_remark'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 备注名
                  _buildRemarkField(
                    controller: remarkController,
                    icon: Icons.person_outline,
                    label: l10n.translate('remark_name'),
                    hint: l10n.translate('remark_name_hint'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  // 电话
                  _buildRemarkField(
                    controller: phoneController,
                    icon: Icons.phone_outlined,
                    label: l10n.translate('remark_phone'),
                    hint: l10n.translate('remark_phone_hint'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  // 邮箱
                  _buildRemarkField(
                    controller: emailController,
                    icon: Icons.email_outlined,
                    label: l10n.translate('remark_email'),
                    hint: l10n.translate('remark_email_hint'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  // 标签
                  _buildRemarkField(
                    controller: tagsController,
                    icon: Icons.label_outline,
                    label: l10n.translate('tags'),
                    hint: l10n.translate('tags_hint'),
                  ),
                  const SizedBox(height: 16),
                  // 描述
                  _buildRemarkField(
                    controller: descController,
                    icon: Icons.notes_outlined,
                    label: l10n.translate('description'),
                    hint: l10n.translate('remark_desc_hint'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _updateFriendRemark(
                          remark: remarkController.text.trim(),
                          remarkPhone: phoneController.text.trim(),
                          remarkEmail: emailController.text.trim(),
                          remarkTags: tagsController.text.trim(),
                          remarkDesc: descController.text.trim(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(l10n.save, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建备注输入字段
  Widget _buildRemarkField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    bool autofocus = false,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        autofocus: autofocus,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  /// 更新好友备注
  Future<void> _updateFriendRemark({
    String? remark,
    String? remarkPhone,
    String? remarkEmail,
    String? remarkTags,
    String? remarkDesc,
  }) async {
    try {
      final friendId = widget.conversation.targetId;
      // 使用 ChatProvider 的方法，它会自动刷新好友列表和会话列表
      final result = await _chatProvider.updateFriendRemark(
        friendId,
        remark: remark,
        remarkPhone: remarkPhone,
        remarkEmail: remarkEmail,
        remarkTags: remarkTags,
        remarkDesc: remarkDesc,
      );
      if (result.success && mounted) {
        // 更新当前显示名称（备注名优先，否则使用原昵称）
        setState(() {
          if (remark != null && remark.isNotEmpty) {
            _displayName = remark;
          } else {
            // 如果清空了备注，使用原始昵称
            _displayName = widget.conversation.nickname.isNotEmpty
                ? widget.conversation.nickname
                : widget.conversation.name;
          }
        });
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('remark_changed_success')), duration: const Duration(seconds: 1)),
        );
      } else if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? l10n.translate('modify_failed'))),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('modify_failed')}: $e')),
        );
      }
    }
  }

  /// 订阅WebSocket连接状态，重连后刷新消息
  void _subscribeToConnectionStatus() {
    _connectionSubscription = _wsService.connectionStream.listen((isConnected) {
      if (isConnected && mounted) {
        // 重连后刷新消息列表，确保同步
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _refreshMessages();
          }
        });
      }
    });
  }

  /// 初始化并加载消息
  Future<void> _initAndLoadMessages() async {
    await _localMessageService.init();

    // 如果有目标消息，加载目标消息周围的消息
    if (widget.targetMsgId != null) {
      await _loadMessagesAroundTarget(widget.targetMsgId!);
    } else {
      await _loadMessages();
    }

    // 清除未读数（使用ChatProvider确保本地和服务器都清除）
    await _chatProvider.clearUnreadCount(widget.conversation.conversId);
  }

  /// 加载目标消息周围的消息（用于定位搜索结果）
  Future<void> _loadMessagesAroundTarget(String targetMsgId) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // 加载目标消息前后的消息
      final messages = await _localMessageService.getMessagesAroundTarget(
        widget.conversation.conversId,
        targetMsgId,
        count: 40, // 加载40条消息，确保目标消息在中间
      );

      // 检查是否还有更多历史消息（如果加载的消息数等于请求数，可能还有更多）
      final hasMoreMessages = messages.length >= 40;

      setState(() {
        _messages = messages;
        _hasMore = hasMoreMessages;
        _isLoading = false; // 立即设置为 false
      });

      // 如果没有找到消息，尝试加载最新消息
      if (messages.isEmpty) {
        await _loadMessages();
        return;
      }

      // 等待列表渲染完成后滚动到目标消息
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTargetMessage(targetMsgId);
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // 出错时尝试加载最新消息
      await _loadMessages();
    }
  }

  /// 滚动到目标消息
  void _scrollToTargetMessage(String targetMsgId) {
    // 找到目标消息在列表中的索引
    final targetIndex = _messages.indexWhere((m) => m.msgId == targetMsgId);
    if (targetIndex < 0) return;

    // 计算滚动位置（考虑到列表是反转的）
    // ListView.builder reverse: true 时，index 0 在底部
    // 所以我们需要计算从底部开始的位置
    final estimatedItemHeight = 80.0; // 估算每条消息的高度
    final scrollOffset = targetIndex * estimatedItemHeight;

    // 滚动到目标位置
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // 3秒后取消高亮效果
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _highlightedMsgId = null;
        });
      }
    });
  }

  /// 订阅清空会话通知
  void _subscribeToClearNotification() {
    _clearSubscription = _chatProvider.conversationClearedStream.listen((conversId) {
      // 如果是当前会话被清空，清空本地消息列表
      if (conversId == widget.conversation.conversId) {
        setState(() {
          _messages.clear();
        });
        // 私聊才显示SnackBar提示，群聊会有系统消息显示
        if (widget.conversation.isPrivate && mounted) {
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('chat_cleared_by_other'))),
            );
          }
        }
      }
    });
  }

  /// 订阅撤回消息通知
  void _subscribeToRecallNotification() {
    _recallSubscription = _chatProvider.recallStream.listen((event) {
      // 如果是自己撤回的，_recallMessage 已经处理过了，直接跳过
      if (event.isSelfRecall) {
        return;
      }

      // 检查是否属于当前会话
      if (event.conversId != null && event.conversId != widget.conversation.conversId) {
        return;
      }

      // 对方撤回的消息，从列表中移除
      final index = _messages.indexWhere((m) => m.msgId == event.msgId);

      if (index >= 0) {
        // 消息在列表中，删除并显示提示
        setState(() {
          _messages.removeAt(index);
        });

        // 从本地存储中删除（ChatProvider已经删除过，这里做双重保障）
        _localMessageService.deleteMessage(
          widget.conversation.conversId,
          event.msgId,
        );

        if (mounted) {
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            _insertChatTip(l10n.translate('other_recalled_message'));
          }
        }
      } else {
        // 消息不在列表中（可能未加载），也显示提示
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            _insertChatTip(l10n.translate('other_recalled_message'));
          }
        }
      }
    });
  }

  /// 订阅红包通知（领取/过期）
  void _subscribeToRedPacketNotification() {
    _redPacketSubscription = _chatProvider.redPacketStream.listen((event) {
      final action = event['action'] as String?;
      final conversId = event['convers_id'] as String?;

      // 检查是否属于当前会话
      if (conversId != null && conversId != widget.conversation.conversId) {
        return;
      }

      if (!mounted) return;

      final l10n = AppLocalizations.of(context);
      if (l10n == null) return;

      if (action == 'received') {
        // 红包被领取
        final receiver = event['receiver'] as Map<String, dynamic>?;
        final isMyPacketReceived = event['receiver']?['id'] != null;
        final amount = event['amount'];
        final isOwner = event['sender_id'] == null; // 如果没有sender_id，说明是发送者收到的通知

        if (isOwner && mounted) {
          // 发送者收到的通知
          final receiverName = receiver?['nickname'] ?? l10n.translate('user');
          final isFinished = event['is_empty'] == true;
          if (isFinished) {
            _insertChatTip(l10n.translate('red_packet_claimed_finished').replaceAll('{name}', receiverName));
          } else {
            _insertChatTip(l10n.translate('red_packet_claimed_by').replaceAll('{name}', receiverName));
          }
        }
      } else if (action == 'expired' && mounted) {
        // 红包过期
        final hasRefund = event['has_refund'] == true;
        final refundAmount = event['refund_amount'] ?? 0;
        final receivedCount = event['received_count'] ?? 0;
        final totalCount = event['total_count'] ?? 0;

        if (hasRefund) {
          _insertChatTip(l10n.translate('red_packet_expired_partial')
              .replaceAll('{received}', '$receivedCount')
              .replaceAll('{total}', '$totalCount')
              .replaceAll('{refund}', '$refundAmount'));
        } else if (event['sender_id'] == null) {
          // 自己发的红包全部被领完后过期
          _insertChatTip(l10n.translate('red_packet_expired_all').replaceAll('{total}', '$totalCount'));
        }
      }
    });
  }

  /// 订阅消息被阻止通知（黑名单）
  void _subscribeToMessageBlocked() {
    _messageBlockedSubscription = _chatProvider.messageBlockedStream.listen((event) {
      final targetId = event['target_id'];
      final l10n = AppLocalizations.of(context);
      final message = event['message'] as String? ?? l10n?.translate('message_send_failed') ?? 'Message send failed';

      // 检查是否属于当前会话
      if (widget.conversation.isPrivate && targetId != widget.conversation.targetId) {
        return;
      }

      if (!mounted) return;

      // 将最后一条发送中的消息标记为失败
      _markLastSendingMessageAsFailed(message);

      // 显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  /// 将最后一条发送的消息标记为发送失败
  void _markLastSendingMessageAsFailed(String reason) {
    if (_messages.isEmpty) return;

    final currentUserId = context.read<AuthProvider>().userId;

    // 找到最近自己发送的消息（列表是逆序的，index 0 是最新的）
    // 查找状态为 sending 或 sent 的消息
    final index = _messages.indexWhere((msg) =>
      msg.fromUserId == currentUserId &&
      (msg.status == MessageStatus.sending || msg.status == MessageStatus.sent)
    );

    if (index != -1) {
      final failedMsg = _messages[index].copyWith(
        status: MessageStatus.failed,
        failReason: reason,
      );
      setState(() {
        _messages[index] = failedMsg;
      });
      // 更新本地数据库中的消息状态
      _localMessageService.updateMessageStatus(
        widget.conversation.conversId,
        failedMsg.msgId,
        MessageStatus.failed,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _messageSubscription?.cancel();
    _clearSubscription?.cancel();
    _recallSubscription?.cancel();
    _connectionSubscription?.cancel();
    _voiceDurationSubscription?.cancel();
    _redPacketSubscription?.cancel();
    _messageBlockedSubscription?.cancel();
    _groupSettingsSubscription?.cancel();
    _groupCallUpdateSubscription?.cancel();
    _audioPlayer.dispose();
    _settingsService.removeListener(_onFontSizeChanged);
    // 如果正在录音，取消录音
    if (_isRecording) {
      _voiceRecordService.cancelRecording();
    }
    // 清除活动会话
    _chatProvider.setActiveConversation(null);
    super.dispose();
  }

  /// 滚动到底部（最新消息）
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0, // ListView reverse: true, 所以0是底部
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// 订阅ChatProvider的新消息流（消息保存由ChatProvider统一处理）
  void _subscribeToMessages() {
    _messageSubscription = _chatProvider.newMessageStream.listen((message) {
      // 检查消息是否属于当前会话
      if (_isMessageForCurrentConversation(message)) {
        setState(() {
          // 避免重复添加
          if (!_messages.any((m) => m.msgId == message.msgId)) {
            _messages.insert(0, message);
          }
        });
        // 发送已读回执
        _wsService.sendReadReceipt(message.msgId, message.fromUserId);
        // 自动保存图片到相册（如果设置开启）
        _autoSaveImageToAlbum(message);
      }
    });
  }

  /// 自动保存图片到相册（根据设置）
  Future<void> _autoSaveImageToAlbum(Message message) async {
    // 检查设置是否开启
    if (!_settingsService.saveToAlbum) return;
    // 只处理图片消息
    if (message.type != MessageType.image) return;
    // 只处理收到的消息（不是自己发的）
    final currentUserId = context.read<AuthProvider>().user?.id;
    if (message.fromUserId == currentUserId) return;
    // Web 平台不支持自动保存
    if (kIsWeb) return;

    try {
      final imageUrl = _getFullUrl(message.content);
      if (imageUrl.isEmpty) return;

      // 使用 Dio 下载图片
      final dio = Dio();
      final response = await dio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200 && response.data != null) {
        // 保存到相册
        final fileName = 'im_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await saveImageToGallery(
          response.data!,
          name: fileName,
        );
      }
    } catch (e) {
      // 自动保存图片失败，忽略
      print('[ChatScreen] Automatically saving pictures failed: $e');
    }
  }

  /// 检查消息是否属于当前会话
  bool _isMessageForCurrentConversation(Message message) {
    // 优先使用conversId匹配（最可靠）
    if (message.conversId != null && message.conversId!.isNotEmpty) {
      return message.conversId == widget.conversation.conversId;
    }

    // 回退到ID匹配
    if (widget.conversation.isPrivate) {
      return message.fromUserId == widget.conversation.targetId ||
          message.toUserId == widget.conversation.targetId;
    } else {
      return message.groupId == widget.conversation.targetId;
    }
  }

  /// 加载消息历史（从本地存储加载）
  /// [loadMore] - 是否加载更多（向上滚动时）
  /// [forceRefresh] - 是否强制刷新（忽略当前列表状态）
  Future<void> _loadMessages({bool loadMore = false, bool forceRefresh = false}) async {
    if (_isLoading) return;
    if (!loadMore && !forceRefresh && _messages.isNotEmpty) return;
    if (loadMore && !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final beforeMsgId = loadMore && _messages.isNotEmpty
          ? _messages.last.msgId
          : null;

      // 从本地存储加载消息
      final messages = await _localMessageService.getMessages(
        widget.conversation.conversId,
        limit: 20,
        beforeMsgId: beforeMsgId,
      );

      setState(() {
        if (loadMore) {
          // 加载更多：追加到末尾，避免重复
          final existingIds = _messages.map((m) => m.msgId).toSet();
          for (final msg in messages) {
            if (!existingIds.contains(msg.msgId)) {
              _messages.add(msg);
            }
          }
        } else {
          // 初始加载或强制刷新：保留实时新消息，合并本地存储的消息
          if (forceRefresh && _messages.isNotEmpty) {
            // 保留当前列表中可能是实时收到的新消息
            final existingIds = messages.map((m) => m.msgId).toSet();
            final realtimeMessages = _messages.where((m) => !existingIds.contains(m.msgId)).toList();
            _messages = [...realtimeMessages, ...messages];
            // 去重并按时间排序
            final seen = <String>{};
            _messages = _messages.where((m) => seen.add(m.msgId)).toList();
            _messages.sort((a, b) {
              final aTime = a.createdAt ?? DateTime.now();
              final bTime = b.createdAt ?? DateTime.now();
              return bTime.compareTo(aTime);
            });
          } else {
            _messages = messages;
          }
        }
        _hasMore = messages.length >= 20;
      });
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('load_message_failed'))),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 强制刷新消息列表（从本地存储同步）
  Future<void> _refreshMessages() async {
    await _loadMessages(forceRefresh: true);
  }

  /// 显示重发消息对话框
  void _showResendDialog(Message message) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('send_failed')),
        content: Text(message.failReason ?? l10n.translate('message_send_failed_resend')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resendMessage(message);
            },
            child: Text(l10n.translate('resend')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteFailedMessage(message);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  /// 重新发送失败的消息
  Future<void> _resendMessage(Message message) async {
    // 先从列表中移除
    setState(() {
      _messages.removeWhere((m) => m.msgId == message.msgId);
    });
    // 从本地数据库删除
    await _localMessageService.deleteMessage(widget.conversation.conversId, message.msgId);

    // 重新发送
    if (message.isText) {
      _messageController.text = message.content;
      await _sendMessage();
    } else if (message.isImage) {
      // 重发图片消息需要重新上传
      _resendMediaMessage(message);
    } else if (message.isVoice) {
      _resendMediaMessage(message);
    } else if (message.isFile) {
      _resendMediaMessage(message);
    }
  }

  /// 重发媒体消息（图片、语音、文件等）
  void _resendMediaMessage(Message message) {
    // 媒体消息重发较复杂，简化处理：提示用户重新选择文件
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.translate('please_resend_message'))),
    );
  }

  /// 删除发送失败的消息
  Future<void> _deleteFailedMessage(Message message) async {
    setState(() {
      _messages.removeWhere((m) => m.msgId == message.msgId);
    });
    await _localMessageService.deleteMessage(widget.conversation.conversId, message.msgId);
  }

  /// 发送消息
  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isSending = true);
    _messageController.clear();

    // 保存回复消息引用，然后清除状态
    final replyTo = _replyingTo;
    if (_replyingTo != null) {
      setState(() => _replyingTo = null);
    }

    // 将 msgId 移到 try 外面，以便在 catch 中也能访问
    final msgId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      final auth = context.read<AuthProvider>();

      // 创建本地消息
      final localMessage = Message(
        msgId: msgId,
        conversId: widget.conversation.conversId,
        fromUserId: auth.userId,
        toUserId: widget.conversation.isPrivate ? widget.conversation.targetId : null,
        groupId: widget.conversation.isGroup ? widget.conversation.targetId : null,
        type: MessageType.text,
        content: content,
        status: 1,
        replyMsgId: replyTo?.msgId,
        createdAt: DateTime.now(),
      );

      // 先显示在列表
      setState(() {
        _messages.insert(0, localMessage);
      });

      // 保存到本地存储（发送中状态）
      await _localMessageService.saveMessage(localMessage);

      // 发送到服务器（使用本地生成的msgId，确保撤回时ID一致）
      final result = await _conversationApi.sendMessage(
        msgId: msgId,
        conversId: widget.conversation.conversId,
        toUserId: widget.conversation.isPrivate ? widget.conversation.targetId : null,
        groupId: widget.conversation.isGroup ? widget.conversation.targetId : null,
        type: MessageType.text,
        content: content,
        replyMsgId: replyTo?.msgId,
      );

      if (result.success) {
        // 更新消息状态为已发送
        final sentMessage = Message(
          msgId: msgId,
          conversId: widget.conversation.conversId,
          fromUserId: auth.userId,
          toUserId: localMessage.toUserId,
          groupId: localMessage.groupId,
          type: MessageType.text,
          content: content,
          status: 2,
          replyMsgId: replyTo?.msgId,
          createdAt: localMessage.createdAt,
        );

        // 更新本地存储
        await _localMessageService.saveMessage(sentMessage);

        // 更新UI
        final index = _messages.indexWhere((m) => m.msgId == msgId);
        if (index >= 0) {
          setState(() {
            _messages[index] = sentMessage;
          });
        }

        // 更新会话
        _chatProvider.updateConversation(
          conversId: widget.conversation.conversId,
          lastMsgPreview: content,
          lastMsgTime: DateTime.now(),
        );
      } else {
        // 发送失败，更新消息状态
        final failedMessage = localMessage.copyWith(
          status: MessageStatus.failed,
          failReason: result.displayMessage,
        );

        // 更新内存中的消息
        final index = _messages.indexWhere((m) => m.msgId == msgId);
        if (index >= 0) {
          setState(() {
            _messages[index] = failedMessage;
          });
        }

        // 更新本地存储
        await _localMessageService.updateMessageStatus(
          widget.conversation.conversId,
          msgId,
          MessageStatus.failed,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.displayMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // 发送异常，也标记为失败
      final index = _messages.indexWhere((m) => m.msgId == msgId);
      if (index >= 0) {
        final failedMessage = _messages[index].copyWith(
          status: MessageStatus.failed,
          failReason: '${l10n.translate('send_failed')}: $e',
        );
        setState(() {
          _messages[index] = failedMessage;
        });
        await _localMessageService.updateMessageStatus(
          widget.conversation.conversId,
          msgId,
          MessageStatus.failed,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('send_failed')}: $e')),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();

    return Stack(
      children: [
        Scaffold(
          appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
          body: Container(
            decoration: _buildBackgroundDecoration(),
            child: Column(
              children: [
                // 客服FAQ面板
                if (_isCustomerServiceChat && _showFAQs && _faqs.isNotEmpty)
                  _buildFAQPanel(),
                // // 群通话进行中横幅（暂时注释）
                // if (widget.conversation.isGroup && _activeGroupCall != null)
                //   Consumer<GroupCallProvider>(
                //     builder: (context, groupCallProvider, child) {
                //       if (groupCallProvider.isInCall) return const SizedBox.shrink();
                //       return _buildActiveCallBanner(groupCallProvider);
                //     },
                //   ),
                // 消息列表
                Expanded(
                  child: _buildMessageList(auth.userId),
                ),
                // 选择模式显示操作栏，否则显示输入框
                _isSelectionMode ? _buildSelectionActionBar() : _buildInputArea(l10n),
              ],
            ),
          ),
        ),
        // Incoming group call banner is now handled globally in HomeScreen overlay
      ],
    );
  }

  /// 构建客服FAQ面板
  Widget _buildFAQPanel() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.help_outline, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('faq'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        l10n.translate('click_view_faq'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showFAQs = false),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.keyboard_arrow_down, size: 22, color: AppColors.textHint),
                  ),
                ),
              ],
            ),
          ),
          // FAQ列表（可展开的问答）
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _faqs.length,
              itemBuilder: (context, index) {
                final faq = _faqs[index];
                final isExpanded = _expandedFAQId == faq.id;
                return _buildFAQItem(faq, isExpanded);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建单个FAQ项
  Widget _buildFAQItem(CustomerServiceFAQ faq, bool isExpanded) {
    return Column(
      children: [
        // 问题行（可点击）
        InkWell(
          onTap: () => _onFAQTap(faq),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isExpanded
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Q',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isExpanded ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    faq.question,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isExpanded ? FontWeight.w600 : FontWeight.normal,
                      color: isExpanded ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20,
                  color: isExpanded ? AppColors.primary : AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
        // 答案区域（展开时显示）
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'A',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    faq.answer,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        // 分隔线
        if (!isExpanded)
          const Divider(height: 1, indent: 46),
      ],
    );
  }

  /// 构建背景装饰
  BoxDecoration? _buildBackgroundDecoration() {
    if (_backgroundImagePath == null || _backgroundImagePath!.isEmpty) {
      return null;
    }

    try {
      final bg = _backgroundImagePath!;

      // 1. 纯色背景 (如 #FFFFFF)
      if (bg.startsWith('#')) {
        return BoxDecoration(
          color: _parseHexColor(bg),
        );
      }

      // 2. 渐变背景 (如 gradient:#667eea,#764ba2)
      if (bg.startsWith('gradient:')) {
        final colors = bg.replaceFirst('gradient:', '').split(',');
        if (colors.length >= 2) {
          return BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors.map((c) => _parseHexColor(c.trim())).toList(),
            ),
          );
        }
      }

      // 3. Base64 data URI (Web平台)
      if (bg.startsWith('data:image')) {
        return BoxDecoration(
          image: DecorationImage(
            image: MemoryImage(_decodeBase64Image(bg)),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.1),
              BlendMode.darken,
            ),
          ),
        );
      }

      // 4. 图片文件路径
      ImageProvider imageProvider;

      if (kIsWeb) {
        // Web平台：使用网络图片
        imageProvider = NetworkImage(bg.proxied);
      } else {
        // 移动/桌面平台：使用文件图片
        final file = File(bg);
        if (!file.existsSync()) {
          return null;
        }
        imageProvider = FileImage(file);
      }

      return BoxDecoration(
        image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.1),
            BlendMode.darken,
          ),
          onError: (exception, stackTrace) {
            // 加载背景图失败，忽略
             print('[ChatScreen] Failed to load background image: $exception');
          },
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// 解析十六进制颜色
  Color _parseHexColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  /// 解码Base64图片
  Uint8List _decodeBase64Image(String dataUri) {
    // data:image/jpeg;base64,/9j/4AAQ...
    final base64String = dataUri.split(',').last;
    return base64Decode(base64String);
  }

  /// 构建普通AppBar
  AppBar _buildNormalAppBar() {
    final l10n = AppLocalizations.of(context)!;
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _displayName.isNotEmpty ? _displayName : l10n.translate('chat'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isMuted) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.notifications_off,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ],
      ),
      actions: [
        // 群聊：群通话按钮（仅付费群可用，使用动态变量，支持实时更新）
        if (widget.conversation.isGroup && _isGroupPaid && _allowGroupCall && _allowVoiceCall)
          IconButton(
            icon: const Icon(Icons.call_outlined),
            tooltip: l10n.translate('group_voice_call'),
            onPressed: () => _startGroupCall(1), // 1=语音
          ),
        if (widget.conversation.isGroup && _isGroupPaid && _allowGroupCall && _allowVideoCall)
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: l10n.translate('group_video_call'),
            onPressed: () => _startGroupCall(2), // 2=视频
          ),
        // 群聊：直接点击进入群设置
        if (widget.conversation.isGroup)
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupInfoScreen(
                    groupId: widget.conversation.targetId,
                  ),
                ),
              ).then((_) {
                // 从群设置返回后刷新设置（背景图、禁言状态、通话设置等）
                _loadChatSettings();
                _loadGroupMuteStatus();
                _refreshGroupCallSettings();
              });
            },
          ),
        // 私聊：通话按钮和菜单
        if (widget.conversation.isPrivate && !_isCustomerServiceChat) ...[
          // 语音通话按钮
          IconButton(
            icon: const Icon(Icons.call_outlined),
            tooltip: l10n.voiceCall,
            onPressed: () => _startCall(CallType.voice),
          ),
          // 视频通话按钮
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: l10n.videoCall,
            onPressed: () => _startCall(CallType.video),
          ),
        ],
        // 私聊：显示下拉菜单
        if (widget.conversation.isPrivate)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              switch (value) {
                case 'view_profile':
                  _showUserProfile();
                  break;
                case 'clear_self':
                  _clearConversation(clearBoth: false);
                  break;
                case 'clear_both':
                  _clearConversation(clearBoth: true);
                  break;
                case 'select':
                  _enterSelectionMode();
                  break;
                case 'background':
                  _pickBackgroundImage();
                  break;
                case 'mute':
                  _toggleMuteStatus();
                  break;
                case 'top':
                  _toggleTopStatus();
                  break;
                case 'edit_remark':
                  _showEditRemarkDialog();
                  break;
              }
            },
            itemBuilder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return [
              // 查看资料（客服会话也可以查看）
              PopupMenuItem(
                value: 'view_profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.viewProfile),
                  ],
                ),
              ),
              // 非客服会话才显示修改备注
              if (!_isCustomerServiceChat)
                PopupMenuItem(
                  value: 'edit_remark',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.translate('modify_remark')),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'select',
                child: Row(
                  children: [
                    const Icon(Icons.checklist, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.translate('multi_select')),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'background',
                child: Row(
                  children: [
                    const Icon(Icons.image, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.chatBackground),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'top',
                child: Row(
                  children: [
                    Icon(
                      _isTop ? Icons.push_pin_outlined : Icons.push_pin,
                      size: 20,
                      color: _isTop ? AppColors.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text(_isTop ? l10n.translate('unpin_chat') : l10n.pinChat),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'mute',
                child: Row(
                  children: [
                    Icon(
                      _isMuted ? Icons.notifications_off : Icons.notifications_active,
                      size: 20,
                      color: _isMuted ? Colors.grey : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(_isMuted ? l10n.translate('enable_notification') : l10n.translate('mute_notification')),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'clear_self',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.translate('clear_local_record')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_both',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep, size: 20, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(l10n.translate('clear_both_record'), style: const TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
          ];
          },
        ),
      ],
    );
  }

  /// 构建选择模式AppBar
  AppBar _buildSelectionAppBar() {
    final l10n = AppLocalizations.of(context)!;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      title: Text(l10n.translate('selected_count').replaceAll('{count}', '${_selectedMessageIds.length}')),
      actions: [
        TextButton(
          onPressed: _selectAll,
          child: Text(
            _selectedMessageIds.length == _messages.length ? l10n.translate('deselect_all') : l10n.translate('select_all'),
          ),
        ),
      ],
    );
  }

  /// 构建选择模式操作栏
  Widget _buildSelectionActionBar() {
    final l10n = AppLocalizations.of(context)!;
    final hasSelection = _selectedMessageIds.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.delete_outline,
              label: l10n.delete,
              color: hasSelection ? AppColors.error : AppColors.textHint,
              onPressed: hasSelection ? _deleteSelectedMessages : null,
            ),
            _buildActionButton(
              icon: Icons.forward,
              label: l10n.forward,
              color: hasSelection ? AppColors.primary : AppColors.textHint,
              onPressed: hasSelection ? _forwardSelectedMessages : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  /// 进入选择模式
  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.clear();
    });
  }

  /// 退出选择模式
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  /// 全选/取消全选
  void _selectAll() {
    setState(() {
      if (_selectedMessageIds.length == _messages.length) {
        _selectedMessageIds.clear();
      } else {
        _selectedMessageIds.clear();
        for (final msg in _messages) {
          _selectedMessageIds.add(msg.msgId);
        }
      }
    });
  }

  /// 切换消息选中状态
  void _toggleMessageSelection(String msgId) {
    setState(() {
      if (_selectedMessageIds.contains(msgId)) {
        _selectedMessageIds.remove(msgId);
      } else {
        _selectedMessageIds.add(msgId);
      }
    });
  }

  /// 批量删除选中的消息
  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_messages_title')),
        content: Text(l10n.translate('delete_messages_confirm').replaceAll('{count}', '${_selectedMessageIds.length}')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 批量删除本地消息
      await _localMessageService.deleteMessages(
        _selectedMessageIds.toList(),
        widget.conversation.conversId,
      );

      // 从UI列表中移除
      setState(() {
        _messages.removeWhere((m) => _selectedMessageIds.contains(m.msgId));
        _selectedMessageIds.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('messages_deleted'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('delete_failed')}: $e')),
        );
      }
    }
  }

  /// 转发选中的消息
  Future<void> _forwardSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    // 获取选中的消息（按时间排序）
    final selectedMessages = _messages
        .where((m) => _selectedMessageIds.contains(m.msgId))
        .toList()
      ..sort((a, b) => (a.createdAt ?? DateTime.now())
          .compareTo(b.createdAt ?? DateTime.now()));

    // 退出选择模式
    _exitSelectionMode();

    // 跳转到转发目标选择页面
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ForwardTargetScreen(messages: selectedMessages),
      ),
    );

    if (result == true && mounted) {
      final l10n = AppLocalizations.of(context)!;
      // 转发成功是临时UI反馈，不需要持久化
      _insertChatTip(l10n.forwardSuccess, persist: false);
    }
  }

  /// 转发单条消息
  Future<void> _forwardSingleMessage(Message message) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ForwardTargetScreen(messages: [message]),
      ),
    );

    if (result == true && mounted) {
      final l10n = AppLocalizations.of(context)!;
      // 转发成功是临时UI反馈，不需要持久化
      _insertChatTip(l10n.forwardSuccess, persist: false);
    }
  }

  /// 构建消息列表
  Widget _buildMessageList(int currentUserId) {
    if (_isLoading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.translate('no_messages'),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('start_chat'),
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshMessages,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification) {
            if (_scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 100) {
              _loadMessages(loadMore: true);
            }
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: _messages.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _messages.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _buildMessageItem(_messages[index], currentUserId);
          },
        ),
      ),
    );
  }

  /// 构建消息项
  Widget _buildMessageItem(Message message, int currentUserId) {
    final l10n = AppLocalizations.of(context)!;
    final isSelf = message.fromUserId == currentUserId;

    if (message.isSystem) {
      return _buildSystemMessage(message);
    }

    if (message.isRecalled) {
      return _buildRecalledMessage(message, isSelf);
    }

    final isSelected = _selectedMessageIds.contains(message.msgId);

    Widget messageContent = Row(
      mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isSelf) _buildAvatar(message),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // 群聊显示发送者名称（根据设置控制是否显示）
              if (widget.conversation.isGroup && !isSelf && _showMemberNickname)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Text(
                    message.fromUser?.displayName ?? '${l10n.translate('user_prefix')}${message.fromUserId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              // 回复引用
              if (message.replyMsgId != null && message.replyMsgId!.isNotEmpty)
                _buildReplyReference(message, isSelf),
              // 消息气泡
              _buildMessageBubble(message, isSelf),
              // 时间和状态
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 4),
                      // 发送失败时显示感叹号
                      if (message.isFailed)
                        GestureDetector(
                          onTap: () => _showResendDialog(message),
                          child: const Icon(
                            Icons.error,
                            size: 16,
                            color: Colors.red,
                          ),
                        )
                      else
                        Icon(
                          message.isSending
                              ? Icons.schedule
                              : message.status == MessageStatus.sent
                                  ? Icons.done
                                  : Icons.done_all,
                          size: 12,
                          color: AppColors.textHint,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (isSelf) _buildAvatar(message, isSelf: true),
      ],
    );

    // 检查是否是高亮消息（搜索定位）
    final isHighlighted = _highlightedMsgId == message.msgId;

    return GestureDetector(
      onTap: _isSelectionMode
          ? () => _toggleMessageSelection(message.msgId)
          : null,
      onLongPress: !_isSelectionMode
          ? () {
              // 长按进入选择模式并选中当前消息
              setState(() {
                _isSelectionMode = true;
                _selectedMessageIds.add(message.msgId);
              });
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: isHighlighted
            ? Colors.yellow.withOpacity(0.3)
            : isSelected
                ? AppColors.primary.withOpacity(0.1)
                : null,
        child: Row(
          children: [
            // 选择模式显示复选框
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleMessageSelection(message.msgId),
                  activeColor: AppColors.primary,
                  shape: const CircleBorder(),
                ),
              ),
            Expanded(child: messageContent),
          ],
        ),
      ),
    );
  }

  /// 构建头像
  Widget _buildAvatar(Message message, {bool isSelf = false}) {
    final avatar = isSelf
        ? context.read<AuthProvider>().user?.avatar ?? ''
        : message.fromUser?.avatar ?? '';
    final avatarUrl = _getFullUrl(avatar);
    final name = isSelf
        ? context.read<AuthProvider>().user?.displayName ?? 'U'
        : message.fromUser?.displayName ?? '?';

    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primary.withOpacity(0.1),
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
      child: avatarUrl.isEmpty
          ? Text(
              name[0],
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  /// 构建消息气泡
  Widget _buildMessageBubble(Message message, bool isSelf) {
    // 合并转发消息使用自己的卡片样式，不需要额外的气泡包装
    if (message.isForward) {
      return GestureDetector(
        onLongPress: () => _showMessageMenu(message),
        child: _buildMessageContent(message),
      );
    }

    // 气泡颜色，有背景图时增加透明度
    final hasBackground = _backgroundImagePath != null && _backgroundImagePath!.isNotEmpty;
    final bubbleColor = isSelf
        ? (hasBackground ? AppColors.bubbleSelf.withOpacity(0.95) : AppColors.bubbleSelf)
        : (hasBackground ? AppColors.bubbleOther.withOpacity(0.95) : AppColors.bubbleOther);

    return GestureDetector(
      onLongPress: () => _showMessageMenu(message),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isSelf ? 12 : 4),
            bottomRight: Radius.circular(isSelf ? 4 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(hasBackground ? 0.1 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        child: _buildMessageContent(message),
      ),
    );
  }

  /// 构建消息内容
  Widget _buildMessageContent(Message message) {
    final auth = context.read<AuthProvider>();
    final isSelf = message.fromUserId == auth.userId;

    switch (message.type) {
      case MessageType.text:
        return _buildTextMessage(message);
      case MessageType.image:
        return _buildImageMessage(message);
      case MessageType.voice:
        return _buildVoiceMessage(message);
      case MessageType.video:
        return _buildVideoMessage(message);
      case MessageType.file:
        return _buildFileMessage(message);
      case MessageType.location:
        return _buildLocationMessage(message);
      case MessageType.card:
        return _buildCardMessage(message);
      case MessageType.redPacket:
        return _buildRedPacketMessage(message, isSelf);
      case MessageType.forward:
        return ForwardMessageCard(message: message, isSelf: isSelf);
      case MessageType.call:
        return _buildCallMessage(message, isSelf);
      case MessageType.videoShare:
        return _buildVideoShareCard(message);
      case MessageType.livestreamShare:
        return _buildLivestreamShareCard(message);
      default:
        final l10n = AppLocalizations.of(context)!;
        return Text(
          l10n.translate('unsupported_message'),
          style: TextStyle(color: AppColors.textSecondary),
        );
    }
  }

  /// 构建文本消息（支持表情解析）
  Widget _buildTextMessage(Message message) {
    final l10n = AppLocalizations.of(context)!;
    final content = message.content;
    final textStyle = TextStyle(fontSize: _messageFontSize);

    // 检查是否包含表情标签 [emoji:URL]
    final emojiPattern = RegExp(r'\[emoji:(https?://[^\]]+)\]');
    if (!emojiPattern.hasMatch(content)) {
      // 普通文本
      return Text(content, style: textStyle);
    }

    // 解析表情和文本混合内容
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in emojiPattern.allMatches(content)) {
      // 添加表情前的文本
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: textStyle,
        ));
      }

      // 添加表情图片
      final emojiUrl = match.group(1)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Image.network(
            emojiUrl,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(l10n.translate('emoji_text')),
          ),
        ),
      ));

      lastEnd = match.end;
    }

    // 添加剩余文本
    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: textStyle,
      ));
    }

    // 如果整条消息只是一个表情，显示更大的图片
    if (spans.length == 1 && spans.first is WidgetSpan) {
      final match = emojiPattern.firstMatch(content);
      if (match != null && match.start == 0 && match.end == content.length) {
        final emojiUrl = match.group(1)!;
        return Image.network(
          emojiUrl,
          width: 100,
          height: 100,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(l10n.translate('emoji_text')),
        );
      }
    }

    return Text.rich(TextSpan(children: spans));
  }

  /// 构建图片消息
  Widget _buildImageMessage(Message message) {
    // 构建完整的图片URL
    final imageUrl = _getFullUrl(message.content);

    // 调试输出
    print('[DEBUG] Image message content: ${message.content}');
    print('[DEBUG] Full image URL: $imageUrl');
    print('[DEBUG] BaseUrl: ${EnvConfig.instance.baseUrl}');

    return GestureDetector(
      onTap: () => _showImageViewer(imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImageWidget(imageUrl),
      ),
    );
  }

  /// 构建图片组件（支持缓存和自动下载控制）
  Widget _buildImageWidget(String imageUrl) {
    final l10n = AppLocalizations.of(context)!;

    // Web 平台使用 Image.network，其他平台使用 CachedNetworkImage
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        width: 150,
        height: 150,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 150,
            height: 150,
            color: AppColors.background,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('[DEBUG] Image load error: $error, URL: $imageUrl');
          return Container(
            width: 150,
            height: 150,
            color: AppColors.background,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.grey),
                const SizedBox(height: 4),
                Text(l10n.translate('load_failed'), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          );
        },
      );
    }

    // 非 Web 平台使用 CachedNetworkImage 提供持久化缓存
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: 150,
      height: 150,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: 150,
        height: 150,
        color: AppColors.background,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) {
        return Container(
          width: 150,
          height: 150,
          color: AppColors.background,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image, color: Colors.grey),
              const SizedBox(height: 4),
              Text(l10n.translate('load_failed'), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        );
      },
    );
  }

  /// 获取完整URL（处理相对路径）
  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    // 防止只有 / 的情况
    if (url == '/') return '';
    // 统一将反斜杠替换为正斜杠（Windows路径兼容）
    url = url.replaceAll('\\', '/');
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    // 相对路径，添加服务器地址
    final baseUrl = EnvConfig.instance.baseUrl;
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }

  /// 显示图片查看器
  void _showImageViewer(String imageUrl) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // 图片
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 64),
                ),
              ),
            ),
            // 关闭按钮
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // 下载按钮
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () => _downloadFile(imageUrl, l10n.translate('image')),
                  icon: const Icon(Icons.download),
                  label: Text(l10n.translate('save_image')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建语音消息
  Widget _buildVoiceMessage(Message message) {
    // 解析语音内容（格式：url|duration）
    int duration = 0;
    try {
      final parts = message.content.split('|');
      if (parts.length >= 2) {
        duration = int.tryParse(parts[1]) ?? 0;
      } else if (message.extra != null) {
        duration = int.tryParse(message.extra!) ?? 0;
      }
    } catch (_) {}

    final isPlaying = _playingVoiceMsgId == message.msgId;
    final isSending = message.status == 1;
    final isFailed = message.status == -1;

    // 根据时长计算宽度（最小120，最大220）
    final width = 120.0 + (duration * 3).clamp(0, 100).toDouble();

    // 计算声波条数量（3-6条）
    final barCount = ((duration / 10) + 3).clamp(3, 6).toInt();

    return GestureDetector(
      onTap: isSending || isFailed ? null : () => _playVoice(message),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 播放/暂停图标或状态图标
            Icon(
              isSending
                  ? Icons.hourglass_empty
                  : isFailed
                      ? Icons.error_outline
                      : isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
              size: 20,
              color: isFailed
                  ? Colors.red
                  : isPlaying
                      ? AppColors.primary
                      : AppColors.textPrimary,
            ),
            const SizedBox(width: 6),
            // 声波动画
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                barCount,
                (index) => Container(
                  width: 3,
                  height: isPlaying ? (6.0 + (index % 3) * 4) : 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isFailed
                        ? Colors.red.withOpacity(0.5)
                        : isPlaying
                            ? AppColors.primary
                            : AppColors.textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const Spacer(),
            // 时长
            Text(
              '${duration}"',
              style: TextStyle(
                fontSize: 13,
                color: isFailed ? Colors.red : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建视频消息
  Widget _buildVideoMessage(Message message) {
    final l10n = AppLocalizations.of(context)!;
    // 解析视频信息
    Map<String, dynamic>? extra;
    String filename = l10n.translate('video');
    int duration = 0;
    int size = 0;
    try {
      if (message.extra != null) {
        extra = jsonDecode(message.extra!);
        filename = extra?['filename'] ?? l10n.translate('video');
        duration = extra?['duration'] ?? 0;
        size = extra?['size'] ?? 0;
      }
    } catch (_) {}

    final videoUrl = _getFullUrl(message.content);

    return GestureDetector(
      onTap: () => _playVideo(videoUrl, filename),
      onLongPress: () => _showVideoOptions(videoUrl, filename),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 视频图标
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_circle_outline, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 8),
            // 文件名
            Text(
              filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 4),
            // 时长和大小
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (duration > 0) ...[
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                ],
                if (size > 0)
                  Text(
                    _formatFileSize(size),
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // 提示文字
            Text(
              l10n.translate('click_play_long_download'),
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  /// 播放视频
  void _playVideo(String videoUrl, String filename) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoUrl: videoUrl,
          title: filename,
        ),
      ),
    );
  }

  /// 显示视频选项（下载）
  void _showVideoOptions(String videoUrl, String filename) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: Text(l10n.translate('play_video')),
              onTap: () {
                Navigator.pop(context);
                _playVideo(videoUrl, filename);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: Text(l10n.translate('download_video')),
              onTap: () {
                Navigator.pop(context);
                _downloadFileToLocal(videoUrl, filename);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l10n.cancel),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化时长
  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 构建文件消息
  Widget _buildFileMessage(Message message) {
    final l10n = AppLocalizations.of(context)!;
    // 解析文件信息
    Map<String, dynamic>? extra;
    String filename = l10n.translate('file');
    int size = 0;
    String extension = '';
    try {
      if (message.extra != null) {
        extra = jsonDecode(message.extra!);
        filename = extra?['filename'] ?? l10n.translate('file');
        size = extra?['size'] ?? 0;
        extension = extra?['extension'] ?? '';
      }
    } catch (_) {}

    final fileUrl = _getFullUrl(message.content);

    // 根据扩展名选择图标
    IconData fileIcon = Icons.insert_drive_file;
    Color iconColor = Colors.blue;
    if (['pdf'].contains(extension.toLowerCase())) {
      fileIcon = Icons.picture_as_pdf;
      iconColor = Colors.red;
    } else if (['doc', 'docx'].contains(extension.toLowerCase())) {
      fileIcon = Icons.description;
      iconColor = Colors.blue;
    } else if (['xls', 'xlsx'].contains(extension.toLowerCase())) {
      fileIcon = Icons.table_chart;
      iconColor = Colors.green;
    } else if (['ppt', 'pptx'].contains(extension.toLowerCase())) {
      fileIcon = Icons.slideshow;
      iconColor = Colors.orange;
    } else if (['zip', 'rar', '7z'].contains(extension.toLowerCase())) {
      fileIcon = Icons.folder_zip;
      iconColor = Colors.amber;
    } else if (['txt'].contains(extension.toLowerCase())) {
      fileIcon = Icons.text_snippet;
      iconColor = Colors.grey;
    }

    return GestureDetector(
      onTap: () => _downloadFile(fileUrl, filename),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            // 文件图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(fileIcon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 12),
            // 文件信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (size > 0)
                        Text(
                          _formatFileSize(size),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      const Spacer(),
                      Icon(Icons.download, size: 16, color: Colors.grey[600]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 下载文件
  Future<void> _downloadFile(String url, String filename) async {
    // 旧方法，现在调用新的下载方法
    await _downloadFileToLocal(url, filename);
  }

  /// 下载文件到本地存储
  Future<void> _downloadFileToLocal(String url, String filename) async {
    final l10n = AppLocalizations.of(context)!;

    // 调试输出
    print('[DEBUG] Downloading file: $url');
    print('[DEBUG] Filename: $filename');

    try {
      if (kIsWeb) {
        // Web平台：使用Blob下载
        _showLoading(l10n.translate('downloading'));
        try {
          // 使用Dio获取文件数据
          final dio = Dio();
          print('[DEBUG] Starting web download...');
          final response = await dio.get(
            url,
            options: Options(responseType: ResponseType.bytes),
          );
          print('[DEBUG] Download response status: ${response.statusCode}');
          print('[DEBUG] Downloaded bytes: ${response.data?.length ?? 0}');

          // 使用web download工具触发下载
          await web_download.downloadFileWeb(response.data, filename);
          _hideLoading();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('file_downloaded').replaceAll('{filename}', filename))),
            );
          }
        } catch (e) {
          print('[DEBUG] Web download error: $e');
          _hideLoading();
          // 备用方案：复制链接
          Clipboard.setData(ClipboardData(text: url));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${l10n.translate('download_failed_link_copied')} Error: $e')),
            );
          }
        }
        return;
      }

      // 移动端下载实现
      _showLoading(l10n.translate('downloading'));

      // 获取下载目录
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // 生成唯一文件名避免覆盖
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = filename.contains('.') ? filename.split('.').last : '';
      final baseName = filename.contains('.') ? filename.substring(0, filename.lastIndexOf('.')) : filename;
      final savePath = ext.isNotEmpty
          ? '${downloadDir.path}/${baseName}_$timestamp.$ext'
          : '${downloadDir.path}/${baseName}_$timestamp';

      // 使用Dio下载
      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          // 下载进度回调
          if (total != -1) {
              final progress = (received / total * 100).toStringAsFixed(0);
              print('Download progress: $progress%');
          }

        },
      );

      _hideLoading();

      if (mounted) {
        final savedFilename = '${baseName}_$timestamp${ext.isNotEmpty ? ".$ext" : ""}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('saved_to').replaceAll('{path}', savedFilename)),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: l10n.confirm,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      _hideLoading();
      _showError('${l10n.translate('download_failed')}: $e');
    }
  }

  /// 构建位置消息
  Widget _buildLocationMessage(Message message) {
    final l10n = AppLocalizations.of(context)!;
    Map<String, dynamic>? extra;
    try {
      if (message.extra != null) {
        extra = jsonDecode(message.extra!);
      }
    } catch (_) {}

    final address = extra?['address'] ?? l10n.translate('unknown_location');
    final lat = (extra?['latitude'] ?? 0.0).toDouble();
    final lng = (extra?['longitude'] ?? 0.0).toDouble();

    return GestureDetector(
      onTap: () => _openLocationInMap(lat, lng, address),
      onLongPress: () => _showLocationOptions(lat, lng, address),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 地图预览
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
              child: SizedBox(
                height: 120,
                child: _buildMapPreview(lat, lng),
              ),
            ),
            // 地址信息
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建地图预览
  Widget _buildMapPreview(double lat, double lng) {
    // 如果坐标无效，显示占位符
    if (lat == 0.0 && lng == 0.0) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.map, size: 40, color: Colors.grey),
        ),
      );
    }

    // 使用IgnorePointer让触摸事件穿透到父GestureDetector
    return IgnorePointer(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(lat, lng),
          initialZoom: 15.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none, // 禁用交互，只作为预览
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.im_client',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(lat, lng),
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 打开地图应用查看位置
  Future<void> _openLocationInMap(double lat, double lng, String address) async {
    // 优先使用高德地图(中国常用)，其次百度地图，最后Google Maps
    final encodedAddress = Uri.encodeComponent(address);

    // 尝试打开不同的地图应用
    final mapUrls = [
      // 高德地图
      'amap://viewMap?sourceApplication=im&poiname=$encodedAddress&lat=$lat&lon=$lng&dev=0',
      // 百度地图
      'baidumap://map/marker?location=$lat,$lng&title=$encodedAddress&coord_type=wgs84',
      // 腾讯地图
      'qqmap://map/marker?marker=coord:$lat,$lng;title:$encodedAddress',
      // Google Maps (Web fallback)
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    ];

    // Web平台直接打开Google Maps
    if (kIsWeb) {
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // 移动端尝试打开本地地图应用
    for (final urlStr in mapUrls) {
      final url = Uri.parse(urlStr);
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {
        continue;
      }
    }

    // 都失败则打开网页版地图
    final webUrl = Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng&zoom=16');
    if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('cannot_open_map'))),
        );
      }
    }
  }

  /// 显示位置选项
  void _showLocationOptions(double lat, double lng, String address) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map, color: Colors.blue),
              title: Text(l10n.translate('view_in_map')),
              onTap: () {
                Navigator.pop(context);
                _openLocationInMap(lat, lng, address);
              },
            ),
            ListTile(
              leading: const Icon(Icons.navigation, color: Colors.green),
              title: Text(l10n.translate('navigate_to')),
              onTap: () {
                Navigator.pop(context);
                _navigateToLocation(lat, lng, address);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.grey),
              title: Text(l10n.translate('copy_address')),
              onTap: () {
                Navigator.pop(context);
                final coordsText = l10n.translate('coordinates').replaceAll('{lat}', '$lat').replaceAll('{lng}', '$lng');
                Clipboard.setData(ClipboardData(text: '$address\n$coordsText'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.translate('address_copied'))),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l10n.cancel),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 导航到位置
  Future<void> _navigateToLocation(double lat, double lng, String address) async {
    final encodedAddress = Uri.encodeComponent(address);

    // 尝试打开导航
    final navUrls = [
      // 高德地图导航
      'amap://navi?sourceApplication=im&poiname=$encodedAddress&lat=$lat&lon=$lng&dev=0',
      // 百度地图导航
      'baidumap://map/direction?destination=name:$encodedAddress|latlng:$lat,$lng&coord_type=wgs84&mode=driving',
      // Google Maps导航
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    ];

    if (kIsWeb) {
      final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      return;
    }

    for (final urlStr in navUrls) {
      final url = Uri.parse(urlStr);
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {
        continue;
      }
    }

    // Fallback
    final webUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  /// 构建名片消息
  Widget _buildCardMessage(Message message) {
    Map<String, dynamic>? extra;
    try {
      if (message.extra != null) {
        extra = jsonDecode(message.extra!);
      }
    } catch (_) {}

    final cardType = extra?['card_type'] ?? 'user';
    final isGroupCard = cardType == 'group';

    if (isGroupCard) {
      return _buildGroupCardMessage(extra, message);
    } else {
      return _buildUserCardMessage(extra, message);
    }
  }

  /// 构建个人名片消息
  Widget _buildUserCardMessage(Map<String, dynamic>? extra, Message message) {
    final l10n = AppLocalizations.of(context)!;
    final nickname = extra?['nickname'] ?? message.content;
    final avatar = extra?['avatar'] ?? '';
    final bio = extra?['bio'] ?? '';
    final userId = extra?['user_id'];

    return GestureDetector(
      onTap: () async {
        if (userId != null) {
          // 显示用户信息对话框
          _showUserCardDialog(userId, nickname, avatar, bio);
        }
      },
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: avatar.isNotEmpty
                      ? NetworkImage(_getFullUrl(avatar))
                      : null,
                  child: avatar.isEmpty ? Text(nickname.isNotEmpty ? nickname[0] : '?') : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (bio.isNotEmpty)
                        Text(
                          bio,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  l10n.translate('personal_card'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建群名片消息
  Widget _buildGroupCardMessage(Map<String, dynamic>? extra, Message message) {
    final l10n = AppLocalizations.of(context)!;
    final groupName = extra?['group_name'] ?? extra?['name'] ?? message.content;
    final avatar = extra?['avatar'] ?? '';
    final memberCount = extra?['member_count'] ?? 0;
    final groupId = extra?['group_id'];
    final shareCode = extra?['share_code'];

    return GestureDetector(
      onTap: () async {
        if (groupId != null) {
          // 显示群信息对话框，提供加入选项
          _showGroupCardDialog(groupId, groupName, avatar, memberCount, shareCode);
        }
      },
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.green[50],
                  backgroundImage: avatar.isNotEmpty
                      ? NetworkImage(_getFullUrl(avatar))
                      : null,
                  child: avatar.isEmpty
                      ? Text(groupName.isNotEmpty ? groupName[0] : l10n.translate('group_char'),
                          style: const TextStyle(color: Colors.green))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        l10n.translate('people_count').replaceAll('{count}', '$memberCount'),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.group, size: 14, color: Colors.green[500]),
                const SizedBox(width: 4),
                Text(
                  l10n.translate('group_card'),
                  style: TextStyle(fontSize: 12, color: Colors.green[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 显示群名片对话框
  void _showGroupCardDialog(int groupId, String groupName, String avatar, int memberCount, String? shareCode) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('group_info_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.green[50],
                backgroundImage: avatar.isNotEmpty
                    ? NetworkImage(_getFullUrl(avatar))
                    : null,
                child: avatar.isEmpty
                    ? Text(groupName.isNotEmpty ? groupName[0] : l10n.translate('group_char'),
                        style: const TextStyle(fontSize: 24, color: Colors.green))
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                groupName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('people_count').replaceAll('{count}', '$memberCount'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // 通过分享码加入群组
                try {
                  final groupApi = GroupApi(ApiClient());
                  ApiResult result;
                  if (shareCode != null && shareCode.isNotEmpty) {
                    // 有分享码，使用分享码加入（支持仅限邀请的群）
                    result = await groupApi.joinGroupByShareCode(shareCode);
                  } else {
                    // 没有分享码，使用普通加入方式
                    result = await groupApi.joinGroup(groupId);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.displayMessage),
                        backgroundColor: result.success ? AppColors.success : AppColors.error,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${l10n.translate('join_failed')}: $e')),
                    );
                  }
                }
              },
              child: Text(l10n.translate('apply_join')),
            ),
          ],
        );
      },
    );
  }

  /// 显示用户名片对话框
  void _showUserCardDialog(int userId, String nickname, String avatar, String bio) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('user_info_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: avatar.isNotEmpty
                    ? NetworkImage(_getFullUrl(avatar))
                    : null,
                child: avatar.isEmpty
                    ? Text(nickname.isNotEmpty ? nickname[0] : '?',
                        style: const TextStyle(fontSize: 24, color: AppColors.primary))
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                nickname,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  bio,
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // 申请添加好友
                try {
                  final friendApi = FriendApi(ApiClient());
                  final result = await friendApi.addFriend(userId: userId);
                  if (result.success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.translate('friend_request_sent'))),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.message ?? l10n.translate('apply_failed'))),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${l10n.translate('apply_failed')}: $e')),
                  );
                }
              },
              child: Text(l10n.translate('add_friend')),
            ),
          ],
        );
      },
    );
  }

  /// 构建红包消息
  Widget _buildRedPacketMessage(Message message, bool isSelf) {
    final l10n = AppLocalizations.of(context)!;
    Map<String, dynamic>? extra;
    try {
      if (message.extra != null) {
        extra = jsonDecode(message.extra!);
      }
    } catch (_) {}

    final wish = extra?['wish'] ?? message.content;
    final redPacketId = extra?['red_packet_id'];
    final status = extra?['status'] ?? 0; // 0未领取 1已领取 2已领完 3已过期

    String statusText = '';
    Color statusColor = Colors.white;
    if (status == 1) {
      statusText = l10n.translate('claimed');
      statusColor = Colors.white70;
    } else if (status == 2) {
      statusText = l10n.translate('all_claimed');
      statusColor = Colors.white70;
    } else if (status == 3) {
      statusText = l10n.expired;
      statusColor = Colors.white70;
    }

    return GestureDetector(
      onTap: () {
        if (redPacketId != null) {
          _openRedPacket(redPacketId, isSelf);
        }
      },
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: status == 0
                ? [const Color(0xFFFA5151), const Color(0xFFE53935)]
                : [const Color(0xFFD4A14A), const Color(0xFFB8860B)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.redeem, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wish,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (statusText.isNotEmpty)
                          Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(
                l10n.translate('red_packet'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建通话消息
  Widget _buildCallMessage(Message message, bool isSelf) {
    final l10n = AppLocalizations.of(context)!;
    Map<String, dynamic>? extra;
    try {
      if (message.extra != null) {
        extra = jsonDecode(message.extra!);
      }
    } catch (_) {}

    final callType = extra?['call_type'] as int? ?? CallType.voice;
    final status = extra?['status'] as int? ?? CallStatus.ended;
    final duration = extra?['duration'] as int? ?? 0;

    // 确定图标和颜色
    IconData icon;
    Color iconColor;
    String statusText;

    if (status == CallStatus.connected || status == CallStatus.ended) {
      icon = callType == CallType.video ? Icons.videocam : Icons.call;
      iconColor = Colors.green;
      statusText = callType == CallType.video ? l10n.videoCall : l10n.voiceCall;
      if (duration > 0) {
        final mins = duration ~/ 60;
        final secs = duration % 60;
        statusText += ' ${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
      }
    } else if (status == CallStatus.rejected) {
      icon = Icons.call_end;
      iconColor = Colors.red;
      statusText = isSelf ? l10n.rejected : l10n.translate('other_rejected');
    } else if (status == CallStatus.cancelled) {
      icon = Icons.call_end;
      iconColor = Colors.orange;
      statusText = isSelf ? l10n.cancelled : l10n.translate('other_cancelled');
    } else if (status == CallStatus.missed) {
      icon = Icons.call_missed;
      iconColor = Colors.red;
      statusText = isSelf ? l10n.translate('you_missed_call') : l10n.missedCall;
    } else if (status == CallStatus.busy) {
      icon = Icons.phone_disabled;
      iconColor = Colors.orange;
      statusText = isSelf ? l10n.translate('busy') : l10n.otherBusy;
    } else {
      icon = callType == CallType.video ? Icons.videocam : Icons.call;
      iconColor = Colors.grey;
      statusText = l10n.callEnded;
    }

    return GestureDetector(
      onTap: () {
        // 点击通话消息可以发起新的通话
        if (!widget.conversation.isPrivate) return;
        _startCall(callType);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelf
              ? AppColors.primary.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建视频分享卡片
  Widget _buildVideoShareCard(Message message) {
    Map<String, dynamic>? extra;
    try {
      if (message.extra != null) {
        extra = jsonDecode(message.extra!);
      }
    } catch (_) {}

    final title = extra?['title'] ?? '';
    final coverUrl = extra?['cover_url'] ?? '';
    final authorName = extra?['author_name'] ?? '';
    final duration = extra?['duration'] ?? 0;
    final videoId = extra?['video_id'];

    final fullCoverUrl = _getFullUrl(coverUrl);

    String durationText = '';
    if (duration > 0) {
      final mins = (duration as int) ~/ 60;
      final secs = duration % 60;
      durationText = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }

    return GestureDetector(
      onTap: () {
        if (videoId != null) {
          _openSharedVideo(videoId is int ? videoId : int.tryParse(videoId.toString()) ?? 0);
        }
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cover image with play icon
            Stack(
              children: [
                if (fullCoverUrl.isNotEmpty)
                  Image.network(
                    fullCoverUrl,
                    width: 200,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 200,
                      height: 120,
                      color: Colors.grey[300],
                      child: const Icon(Icons.videocam, size: 40, color: Colors.white),
                    ),
                  )
                else
                  Container(
                    width: 200,
                    height: 120,
                    color: Colors.grey[300],
                    child: const Icon(Icons.videocam, size: 40, color: Colors.white),
                  ),
                // Play icon overlay
                const Positioned.fill(
                  child: Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      size: 40,
                      color: Colors.white70,
                    ),
                  ),
                ),
                // Duration
                if (durationText.isNotEmpty)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        durationText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Title + author
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.toString().isNotEmpty)
                    Text(
                      title.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  if (authorName.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.videocam_outlined, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              authorName.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivestreamShareCard(Message message) {
    Map<String, dynamic>? extra;
    try {
      if (message.extra != null) {
        extra = jsonDecode(message.extra!);
      }
    } catch (_) {}

    final title = extra?['title'] ?? '';
    final coverUrl = extra?['cover_url'] ?? '';
    final anchorName = extra?['anchor_name'] ?? '';
    final livestreamId = extra?['livestream_id'];

    final fullCoverUrl = _getFullUrl(coverUrl.toString());

    return GestureDetector(
      onTap: () {
        if (livestreamId != null) {
          final id = livestreamId is int
              ? livestreamId
              : int.tryParse(livestreamId.toString()) ?? 0;
          if (id > 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LivestreamViewerScreen(
                  livestreamId: id,
                  isAnchor: false,
                ),
              ),
            );
          }
        }
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cover image with LIVE badge
            Stack(
              children: [
                if (fullCoverUrl.isNotEmpty)
                  Image.network(
                    fullCoverUrl,
                    width: 200,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 200,
                      height: 120,
                      color: Colors.grey[300],
                      child: const Icon(Icons.live_tv, size: 40, color: Colors.white),
                    ),
                  )
                else
                  Container(
                    width: 200,
                    height: 120,
                    color: Colors.grey[300],
                    child: const Icon(Icons.live_tv, size: 40, color: Colors.white),
                  ),
                // LIVE badge
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 6, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          '直播',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Title + anchor name
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.toString().isNotEmpty)
                    Text(
                      title.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  if (anchorName.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.live_tv, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              anchorName.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 打开分享的视频
  Future<void> _openSharedVideo(int videoId) async {
    if (videoId <= 0) return;
    try {
      final api = SmallVideoApi(ApiClient());
      final response = await api.getVideo(videoId);
      if (response.success && response.data != null && mounted) {
        final video = SmallVideo.fromJson(response.data['video']);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoDetailScreen(videos: [video], initialIndex: 0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load video')),
        );
      }
    }
  }

  /// 打开红包
  Future<void> _openRedPacket(dynamic redPacketId, bool isSelf) async {
    final l10n = AppLocalizations.of(context)!;
    final apiClient = ApiClient();

    try {
      // 获取红包详情
      final detailRes = await apiClient.get('/red-packet/$redPacketId');
      if (!detailRes.success || detailRes.data == null) {
        _showError(l10n.translate('get_red_packet_failed'));
        return;
      }

      final redPacket = detailRes.data;
      final hasReceived = redPacket['has_received'] ?? false;
      final myAmount = redPacket['my_amount'] ?? 0;
      final status = redPacket['status'] ?? 0; // 0正常 1已过期 2已领完
      final totalCount = redPacket['total_count'] ?? 1;
      final remainCount = redPacket['remain_count'] ?? 0;
      final receivedCount = totalCount - remainCount;
      final records = (redPacket['records'] as List?) ?? [];
      final senderNickname = redPacket['user']?['nickname'] ?? '';
      final senderAvatar = _getFullUrl(redPacket['user']?['avatar'] ?? '');

      // 判断是否是自己发的红包
      final chatProvider = context.read<ChatProvider>();
      final isMyPacket = redPacket['user']?['id'] == chatProvider.currentUserId;

      if (!mounted) return;

      // 显示红包弹窗
      showDialog(
        context: context,
        builder: (ctx) {
          // 状态文字和颜色
          String statusText = '';
          Color statusColor = Colors.white70;
          bool canReceive = false;

          if (status == 1) {
            statusText = l10n.translate('expired');
          } else if (status == 2 || remainCount <= 0) {
            statusText = l10n.translate('all_claimed');
          } else if (isMyPacket) {
            statusText = l10n.translate('waiting_claim');
          } else if (hasReceived) {
            statusText = '';
          } else {
            canReceive = true;
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 300,
              constraints: const BoxConstraints(maxHeight: 500),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: (status == 0 && remainCount > 0)
                      ? [const Color(0xFFFA5151), const Color(0xFFE53935)]
                      : [const Color(0xFFD4A14A), const Color(0xFFB8860B)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 关闭按钮
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    ),
                  ),
                  // 头部
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          backgroundImage: senderAvatar.isNotEmpty
                              ? NetworkImage(senderAvatar.proxied) as ImageProvider
                              : null,
                          child: senderAvatar.isEmpty
                              ? Text(
                                  senderNickname.isNotEmpty ? senderNickname.substring(0, 1) : '?',
                                  style: const TextStyle(fontSize: 24, color: Colors.red),
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isMyPacket ? l10n.translate('your_red_packet') : l10n.translate('someones_red_packet').replaceAll('{name}', senderNickname),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          redPacket['wish'] ?? l10n.translate('red_packet_wish_default'),
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        if (statusText.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 金额显示或领取按钮
                  if (hasReceived && myAmount > 0) ...[
                    // 已领取，显示金额
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$myAmount',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(l10n.translate('gold_beans'), style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.translate('saved_to_wallet'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ] else if (canReceive && !isMyPacket) ...[
                    // 可以领取
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _receiveRedPacket(redPacketId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: const Color(0xFFB8860B),
                        minimumSize: const Size(80, 80),
                        shape: const CircleBorder(),
                        elevation: 4,
                      ),
                      child: Text(l10n.translate('open_char'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    ),
                  ] else if (isMyPacket) ...[
                    // 自己的红包，显示发放金额
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${redPacket['amount'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(l10n.translate('gold_beans'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.translate('total_packets').replaceAll('{count}', '$totalCount'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // 底部区域：领取记录
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('red_packet_claimed_status').replaceAll('{received}', '$receivedCount').replaceAll('{total}', '$totalCount'),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        if (records.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 150),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: records.length,
                              itemBuilder: (context, index) {
                                final record = records[index];
                                final user = record['user'] ?? {};
                                final nickname = user['nickname'] ?? l10n.translate('user_prefix');
                                final avatarUrl = _getFullUrl(user['avatar'] ?? '');
                                final amount = record['amount'] ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundImage: avatarUrl.isNotEmpty
                                            ? NetworkImage(avatarUrl.proxied) as ImageProvider
                                            : null,
                                        child: avatarUrl.isEmpty
                                            ? Text(nickname.isNotEmpty ? nickname.substring(0, 1) : '?',
                                                style: const TextStyle(fontSize: 12))
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(nickname, style: const TextStyle(fontSize: 14)),
                                      ),
                                      Text(
                                        l10n.translate('gold_beans_amount').replaceAll('{amount}', '$amount'),
                                        style: TextStyle(color: Colors.orange[700], fontSize: 14),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ] else if (receivedCount == 0) ...[
                          const SizedBox(height: 20),
                          Center(
                            child: Text(
                              l10n.translate('no_one_claimed'),
                              style: TextStyle(color: Colors.grey[400], fontSize: 14),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      _showError('${l10n.translate('open_red_packet_failed')}: $e');
    }
  }

  /// 领取红包
  Future<void> _receiveRedPacket(dynamic redPacketId) async {
    final l10n = AppLocalizations.of(context)!;
    _showLoading(l10n.translate('claiming'));

    try {
      final apiClient = ApiClient();
      final response = await apiClient.post('/red-packet/receive/$redPacketId');

      _hideLoading();

      if (response.success && response.data != null) {
        final amount = response.data['amount'] ?? 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.monetization_on, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text(l10n.translate('claim_success').replaceAll('{amount}', '$amount')),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _showError(response.message ?? l10n.translate('claim_failed'));
      }
    } catch (e) {
      _hideLoading();
      _showError('${l10n.translate('claim_failed')}: $e');
    }
  }

  /// 构建系统消息
  Widget _buildSystemMessage(Message message) {
    final l10n = AppLocalizations.of(context)!;
    String displayContent = message.content;

    // 检查是否是特殊系统消息
    if (message.extra != null && message.extra!.isNotEmpty) {
      try {
        final extra = jsonDecode(message.extra!);
        final actionType = extra['action_type'] as String?;

        if (actionType == 'group_join_request') {
          return _buildJoinRequestMessage(message, extra);
        }

        // 处理定时清除设置更新通知
        if (actionType == 'auto_clear_updated') {
          final autoClearDays = extra['auto_clear_days'] ?? 0;
          if (autoClearDays > 0) {
            displayContent = l10n.translate('auto_clear_notification')
                .replaceAll('{days}', autoClearDays.toString());
          } else {
            displayContent = l10n.translate('auto_clear_disabled_notification');
          }
        }

        // 处理成员加入通知
        if (actionType == 'member_join') {
          final nickname = extra['nickname'] ?? extra['username'] ?? '';
          if (nickname.isNotEmpty) {
            displayContent = l10n.translate('member_joined_group').replaceAll('{name}', nickname);
          }
        }

        // 处理清空群聊记录通知
        if (actionType == 'group_messages_cleared') {
          final operatorName = extra['operator_name'] ?? '';
          if (operatorName.isNotEmpty) {
            displayContent = l10n.translate('group_messages_cleared_by').replaceAll('{name}', operatorName);
          }
        }

        // 处理群主转让通知
        if (actionType == 'owner_transferred') {
          final oldOwnerName = extra['old_owner_name'] ?? '';
          final newOwnerName = extra['new_owner_name'] ?? '';
          if (oldOwnerName.isNotEmpty && newOwnerName.isNotEmpty) {
            displayContent = l10n.translate('owner_transferred_notification')
                .replaceAll('{old_owner}', oldOwnerName)
                .replaceAll('{new_owner}', newOwnerName);
          }
        }

        // 处理群通话开始通知
        if (actionType == 'group_call_started') {
          return _buildGroupCallStartedMessage(message, extra);
        }

        // 处理群通话加入通知
        if (actionType == 'group_call_joined') {
          final userName = extra['user_name'] ?? '';
          if (userName.isNotEmpty) {
            displayContent = l10n.translate('group_call_user_joined').replaceAll('{name}', userName);
          }
        }

        // 处理群通话离开通知
        if (actionType == 'group_call_left') {
          final userName = extra['user_name'] ?? '';
          if (userName.isNotEmpty) {
            displayContent = l10n.translate('group_call_user_left').replaceAll('{name}', userName);
          }
        }

        // 处理群通话结束通知
        if (actionType == 'group_call_ended') {
          final duration = extra['duration'] ?? 0;
          final durationStr = _formatCallDuration(duration);
          displayContent = l10n.translate('group_call_ended_with_duration').replaceAll('{duration}', durationStr);
        }
      } catch (e) {
        // 解析失败，显示普通系统消息
      }
    }

    // 内容检测：群通话发起消息（即使extra为空也显示加入按钮）
    final content = message.content;
    final isCallStartedMsg = content.contains('发起了群语音通话') ||
        content.contains('发起了群视频通话') ||
        content.contains('started a group voice call') ||
        content.contains('started a group video call');

    if (isCallStartedMsg && widget.conversation.isGroup && _activeGroupCall != null) {
      final call = _activeGroupCall!;
      return _buildGroupCallStartedMessage(message, {
        'initiator_name': content.split(' ').first,
        'call_type': call.callType,
        'call_id': call.callId,
      });
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          displayContent,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 格式化通话时长
  String _formatCallDuration(int seconds) {
    if (seconds < 0) seconds = 0;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 构建群通话开始通知消息
  /// 构建群通话进行中横幅（在聊天框顶部显示）
  Widget _buildActiveCallBanner(GroupCallProvider groupCallProvider) {
    final l10n = AppLocalizations.of(context)!;
    final call = _activeGroupCall!;
    final isVideo = call.isVideo;

    return GestureDetector(
      onTap: () => _joinGroupCall(call.callId, call.callType),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isVideo
                ? [const Color(0xFF1a1a2e), const Color(0xFF252547)]
                : [const Color(0xFF1e8c3e), const Color(0xFF2ea350)],
          ),
        ),
        child: Row(
          children: [
            Icon(
              isVideo ? Icons.videocam : Icons.call,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isVideo
                    ? '${l10n.translate('group_video_call_in_progress')} · ${call.currentCount}${l10n.translate('people_in_call')}'
                    : '${l10n.translate('group_voice_call_in_progress')} · ${call.currentCount}${l10n.translate('people_in_call')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                l10n.translate('join'),
                style: TextStyle(
                  color: isVideo ? const Color(0xFF1a1a2e) : const Color(0xFF1e8c3e),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCallStartedMessage(Message message, Map<String, dynamic> extra) {
    final l10n = AppLocalizations.of(context)!;
    final initiatorName = extra['initiator_name'] ?? '';
    final callType = extra['call_type'] ?? 1;
    final callId = extra['call_id'];
    final isVideo = callType == 2;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 40),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isVideo ? Colors.blue.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isVideo ? Colors.blue.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVideo ? Icons.videocam : Icons.call,
              color: isVideo ? Colors.blue : Colors.green,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isVideo
                        ? l10n.translate('group_video_call_started_by').replaceAll('{name}', initiatorName)
                        : l10n.translate('group_voice_call_started_by').replaceAll('{name}', initiatorName),
                    style: TextStyle(
                      fontSize: 12,
                      color: isVideo ? Colors.blue[700] : Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _joinGroupCall(callId, callType),
              style: TextButton.styleFrom(
                backgroundColor: isVideo ? Colors.blue : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.translate('join'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 加入群通话
  Future<void> _joinGroupCall(int? callId, int callType) async {
    if (callId == null) return;

    final provider = context.read<GroupCallProvider>();

    // Check if already in a call
    if (provider.isBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate('already_in_call')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final groupId = widget.conversation.targetId;
    final groupName = widget.conversation.name;

    final success = await provider.joinCall(groupId, callId, callType, groupName: groupName);
    if (success && mounted) {
      GroupCallOverlayManager.show(context);
    } else if (mounted) {
      // 加入失败，通话可能已结束，清除横幅
      setState(() {
        _activeGroupCall = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate('group_call_ended')),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// 构建入群申请通知消息
  Widget _buildJoinRequestMessage(Message message, Map<String, dynamic> extra) {
    final l10n = AppLocalizations.of(context)!;
    final nickname = extra['nickname'] ?? extra['username'] ?? l10n.translate('user_prefix');
    final avatarUrl = _getFullUrl(extra['avatar'] ?? '');
    final requestMessage = extra['message'] ?? '';

    return Center(
      child: GestureDetector(
        onTap: () => _handleJoinRequestTap(extra),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 40),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.translate('user_apply_join_group').replaceAll('{name}', nickname),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (requestMessage.isNotEmpty)
                      Text(
                        requestMessage,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      l10n.translate('click_view_detail'),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 处理入群申请消息点击
  void _handleJoinRequestTap(Map<String, dynamic> extra) {
    final l10n = AppLocalizations.of(context)!;
    final groupId = extra['group_id'];
    final groupName = extra['group_name'] ?? l10n.translate('group_chat');

    if (groupId != null && widget.conversation.isGroup) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupRequestsScreen(
            groupId: groupId is int ? groupId : int.tryParse(groupId.toString()) ?? 0,
            groupName: groupName.toString(),
          ),
        ),
      );
    }
  }

  /// 构建撤回消息
  Widget _buildRecalledMessage(Message message, bool isSelf) {
    final l10n = AppLocalizations.of(context)!;
    return _buildChatTip(isSelf ? l10n.translate('you_recalled_message') : l10n.translate('other_recalled_message'));
  }

  /// 构建聊天提示（灰色小字居中显示）
  Widget _buildChatTip(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 在聊天列表中插入提示消息
  /// [persist] - 是否持久化保存到本地存储（默认true）
  void _insertChatTip(String tip, {bool persist = true}) {
    final tipMessage = Message(
      msgId: 'tip_${DateTime.now().millisecondsSinceEpoch}',
      conversId: widget.conversation.conversId,
      fromUserId: 0,
      type: MessageType.system,
      content: tip,
      status: 2,
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages.insert(0, tipMessage);
    });

    // 持久化保存到本地存储
    if (persist) {
      _localMessageService.saveMessage(tipMessage);
    }
  }

  /// 显示消息菜单
  void _showMessageMenu(Message message) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();
    final isSelf = message.fromUserId == auth.userId;

    // 检查撤回时限（使用服务端配置的秒数）
    final recallSeconds = context.read<AppConfigProvider>().messageRecallTime;
    final canRecall = isSelf &&
        !message.isRecalled &&
        message.createdAt != null &&
        DateTime.now().difference(message.createdAt!).inSeconds < recallSeconds;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖动指示条
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                // 复制（仅文本消息）
              if (message.isText)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.copy, color: AppColors.primary),
                  ),
                  title: Text(l10n.translate('copy')),
                  onTap: () {
                    Navigator.pop(context);
                    _copyMessage(message);
                  },
                ),
              // 回复
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.reply, color: AppColors.secondary),
                ),
                title: Text(l10n.translate('reply')),
                onTap: () {
                  Navigator.pop(context);
                  _replyToMessage(message);
                },
              ),
              // 转发
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.forward, color: Colors.blue),
                ),
                title: Text(l10n.translate('forward')),
                onTap: () {
                  Navigator.pop(context);
                  _forwardSingleMessage(message);
                },
              ),
              // 收藏消息（非表情消息显示）
              if (!_hasEmoji(message))
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.favorite_outline, color: Colors.red),
                  ),
                  title: Text(l10n.translate('favorites')),
                  onTap: () {
                    Navigator.pop(context);
                    _addToFavorites(message);
                  },
                ),
              // 收藏表情（仅当消息包含表情时显示）
              if (_hasEmoji(message))
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.star_outline, color: Colors.amber),
                  ),
                  title: Text(l10n.translate('favorite_emoji')),
                  onTap: () {
                    Navigator.pop(context);
                    _collectEmojiFromMessage(message);
                  },
                ),
              // 多选
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.checklist, color: Colors.purple),
                ),
                title: Text(l10n.translate('multi_select')),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isSelectionMode = true;
                    _selectedMessageIds.add(message.msgId);
                  });
                },
              ),
              // 撤回（自己发送的消息，2分钟内）
              if (canRecall)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.undo, color: Colors.orange),
                  ),
                  title: Text(l10n.translate('recall')),
                  onTap: () {
                    Navigator.pop(context);
                    _recallMessage(message);
                  },
                ),
              // 删除
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete, color: AppColors.error),
                ),
                title: Text(l10n.delete, style: const TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 复制消息内容
  void _copyMessage(Message message) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.translate('copied_to_clipboard')),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 收藏消息
  Future<void> _addToFavorites(Message message) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final response = await _favoriteApi.addFavorite(
        messageId: message.msgId,
        contentType: message.type,
        content: message.content,
        fromUserId: message.fromUserId,
      );

      if (!mounted) return;

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('favorited')),
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? l10n.translate('favorite_failed')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.translate('favorite_failed')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// 检查消息是否包含表情
  bool _hasEmoji(Message message) {
    if (!message.isText) return false;
    final emojiPattern = RegExp(r'\[emoji:(https?://[^\]]+)\]');
    return emojiPattern.hasMatch(message.content);
  }

  /// 从消息中收藏表情
  Future<void> _collectEmojiFromMessage(Message message) async {
    final emojiPattern = RegExp(r'\[emoji:(https?://[^\]]+)\]');
    final matches = emojiPattern.allMatches(message.content).toList();

    final l10n = AppLocalizations.of(context)!;
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('no_emoji_found'))),
      );
      return;
    }

    // 如果只有一个表情，直接收藏
    if (matches.length == 1) {
      final url = matches.first.group(1)!;
      await _addEmojiToCollection(url, 'Emoji');
      return;
    }

    // 如果有多个表情，显示选择对话框
    final urls = matches.map((m) => m.group(1)!).toList();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('select_emoji_to_favorite')),
          content: SizedBox(
            width: 280,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: urls.map((url) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _addEmojiToCollection(url, 'Emoji');
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // 收藏所有表情
                for (final url in urls) {
                  await _addEmojiToCollection(url, 'Emoji', showTip: false);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.translate('emojis_favorited').replaceAll('{count}', '${urls.length}'))),
                  );
                }
              },
              child: Text(l10n.translate('favorite_all')),
            ),
          ],
        );
      },
    );
  }

  /// 添加表情到收藏
  Future<void> _addEmojiToCollection(String url, String name, {bool showTip = true}) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final emojiApi = EmojiApi();
      final success = await emojiApi.addEmoji(
        url: url,
        name: name,
        sourceMsgId: null,
      );
      if (success && showTip && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('added_to_emoji')), duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (showTip && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('favorite_failed')}: $e')),
        );
      }
    }
  }

  /// 回复消息
  void _replyToMessage(Message message) {
    setState(() {
      _replyingTo = message;
    });
    _focusNode.requestFocus();
  }

  /// 取消回复
  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  /// 撤回消息
  Future<void> _recallMessage(Message message) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // 传递目标用户ID或群组ID
      final success = await _conversationApi.recallMessage(
        message.msgId,
        toUserId: widget.conversation.isPrivate ? widget.conversation.targetId : null,
        groupId: widget.conversation.isGroup ? widget.conversation.targetId : null,
      );

      if (success) {
        // 直接从列表中移除该消息
        setState(() {
          _messages.removeWhere((m) => m.msgId == message.msgId);
        });

        // 从本地存储中删除
        await _localMessageService.deleteMessage(
          widget.conversation.conversId,
          message.msgId,
        );

        // 在聊天框中显示提示（WebSocket通知会发给自己，但消息已删除不会重复处理）
        if (mounted) {
          _insertChatTip(l10n.translate('you_recalled_message'));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('recall_failed')}: $e')),
        );
      }
    }
  }

  /// 删除消息（仅删除本地）
  Future<void> _deleteMessage(Message message) async {
    try {
      // 从本地存储删除
      await _localMessageService.deleteMessage(
        widget.conversation.conversId,
        message.msgId,
      );

      // 从UI列表中移除
      setState(() {
        _messages.removeWhere((m) => m.msgId == message.msgId);
      });

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('messages_deleted'))),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('delete_failed')}: $e')),
        );
      }
    }
  }

  /// 清空会话消息
  /// [clearBoth] - true: 清空双方记录（需要服务端配合），false: 只清空自己本地记录
  Future<void> _clearConversation({required bool clearBoth}) async {
    final l10n = AppLocalizations.of(context)!;
    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(clearBoth ? l10n.translate('clear_both_title') : l10n.translate('clear_local_title')),
        content: Text(
          clearBoth
              ? l10n.translate('clear_both_confirm')
              : l10n.translate('clear_local_confirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.translate('confirm_clear')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 清空本地存储
      await _localMessageService.clearConversationMessages(widget.conversation.conversId);

      // 如果要清空双方，还需调用服务端API
      if (clearBoth) {
        await _conversationApi.clearConversation(
          widget.conversation.conversId,
          clearBoth: true,
        );
      }

      // 清空UI列表
      setState(() {
        _messages.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(clearBoth ? l10n.translate('cleared_both') : l10n.translate('cleared_local'))),
        );

        // 清空后返回会话列表
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('clear_failed')}: $e')),
        );
      }
    }
  }

  /// 构建输入区域
  Widget _buildInputArea(AppLocalizations l10n) {
    // 群聊禁言时显示禁言提示
    if (_isGroupMuted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.volume_off,
                  size: 18,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 8),
                Text(
                  _muteReason.isNotEmpty ? _muteReason : l10n.translate('muted_status'),
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 客服会话时显示"常见问题"快捷入口
        if (_isCustomerServiceChat && !_showFAQs && _faqs.isNotEmpty)
          GestureDetector(
            onTap: () => setState(() => _showFAQs = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                border: Border(
                  top: BorderSide(color: AppColors.divider, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.help_outline, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    l10n.translate('click_view_faq'),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // 回复预览
        if (_replyingTo != null) _buildReplyPreview(),
        // 输入区域
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(
              top: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: _isRecording
                ? _buildRecordingArea()
                : Row(
              children: [
                // 语音按钮
                IconButton(
                  icon: const Icon(Icons.mic),
                  color: AppColors.textSecondary,
                  onPressed: _startVoiceRecord,
                ),
                // 输入框
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Color(0xFF191919), fontSize: 16),
                      decoration: InputDecoration(
                        hintText: _replyingTo != null ? l10n.translate('reply_message_hint') : l10n.inputMessage,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        counterText: '',
                      ),
                      maxLength: context.read<AppConfigProvider>().messageMaxLength,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                // 表情按钮
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  color: AppColors.textSecondary,
              onPressed: () {
                showEmojiPicker(context, (emoji) {
                  // 将表情插入到输入框光标位置
                  final text = _messageController.text;
                  final selection = _messageController.selection;

                  // 处理选择无效的情况（光标位置为-1时追加到末尾）
                  final start = selection.start >= 0 ? selection.start : text.length;
                  final end = selection.end >= 0 ? selection.end : text.length;

                  final newText = text.replaceRange(start, end, emoji);
                  _messageController.text = newText;
                  _messageController.selection = TextSelection.collapsed(
                    offset: start + emoji.length,
                  );

                  // 触发UI更新以显示发送按钮
                  setState(() {});
                });
              },
            ),
            // 更多按钮/发送按钮
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _messageController.text.trim().isNotEmpty
                  ? IconButton(
                      key: const ValueKey('send'),
                      icon: const Icon(Icons.send),
                      color: AppColors.primary,
                      onPressed: _isSending ? null : _sendMessage,
                    )
                  : IconButton(
                      key: const ValueKey('more'),
                      icon: const Icon(Icons.add_circle_outline),
                      color: AppColors.textSecondary,
                      onPressed: _showMorePanel,
                    ),
            ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建录音区域
  Widget _buildRecordingArea() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        // 取消按钮
        IconButton(
          icon: const Icon(Icons.close),
          color: Colors.red,
          onPressed: _cancelVoiceRecord,
          tooltip: l10n.cancel,
        ),
        // 录音指示器
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 录音动画点
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(value),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                  onEnd: () {},
                ),
                const SizedBox(width: 12),
                Text(
                  '${l10n.translate('recording')} ${_formatRecordDuration(_recordDuration)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 发送按钮
        IconButton(
          icon: const Icon(Icons.send),
          color: AppColors.primary,
          onPressed: _stopAndSendVoice,
          tooltip: l10n.translate('send_tooltip'),
        ),
      ],
    );
  }

  /// 构建回复预览
  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    String previewText = _replyingTo!.content;
    if (_replyingTo!.isImage) {
      previewText = l10n.translate('image_preview');
    } else if (_replyingTo!.isVoice) {
      previewText = l10n.translate('voice_preview');
    } else if (_replyingTo!.isVideo) {
      previewText = l10n.translate('video_preview');
    } else if (_replyingTo!.isFile) {
      previewText = l10n.translate('file_preview');
    } else if (_replyingTo!.isForward) {
      previewText = l10n.translate('chat_record_preview');
    }

    // 获取发送者名称
    final auth = context.read<AuthProvider>();
    final senderName = _replyingTo!.fromUserId == auth.userId
        ? l10n.translate('you_label')
        : (_replyingTo!.fromUser?.displayName ?? l10n.translate('other_party'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.translate('reply_to').replaceAll('{name}', senderName),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  previewText,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _cancelReply,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 18,
                color: AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建回复引用（显示在消息气泡上方）
  Widget _buildReplyReference(Message message, bool isSelf) {
    final l10n = AppLocalizations.of(context)!;
    // 优先使用消息中携带的回复信息
    if (message.replyMessage != null) {
      return _buildReplyReferenceWidget(
        message.replyMessage!.content,
        message.replyMessage!.type,
        message.replyMessage!.fromUserId,
        message.replyMessage!.fromUser?.displayName,
        message.replyMsgId!,
        isSelf,
      );
    }

    // 否则异步查找
    return FutureBuilder<Message?>(
      future: _findRepliedMessage(message.replyMsgId!),
      builder: (context, snapshot) {
        final repliedMsg = snapshot.data;

        if (repliedMsg == null) {
          return _buildReplyReferenceWidget(l10n.translate('message_deleted'), 1, 0, null, message.replyMsgId!, isSelf);
        }

        return _buildReplyReferenceWidget(
          repliedMsg.content,
          repliedMsg.type,
          repliedMsg.fromUserId,
          repliedMsg.fromUser?.displayName,
          message.replyMsgId!,
          isSelf,
        );
      },
    );
  }

  /// 构建回复引用组件
  Widget _buildReplyReferenceWidget(
    String content,
    int type,
    int fromUserId,
    String? fromUserName,
    String replyMsgId,
    bool isSelf,
  ) {
    final l10n = AppLocalizations.of(context)!;
    String previewText;
    switch (type) {
      case 2:
        previewText = l10n.translate('image_preview');
        break;
      case 3:
        previewText = l10n.translate('voice_preview');
        break;
      case 4:
        previewText = l10n.translate('video_preview');
        break;
      case 5:
        previewText = l10n.translate('file_preview');
        break;
      case 6:
        previewText = l10n.translate('location_preview');
        break;
      case 7:
        previewText = l10n.translate('card_preview');
        break;
      case 8:
        previewText = l10n.translate('chat_record_preview');
        break;
      case 13:
        previewText = l10n.translate('video_share_preview');
        break;
      default:
        previewText = content;
    }

    final auth = context.read<AuthProvider>();
    final senderName = fromUserId == 0
        ? ''
        : (fromUserId == auth.userId ? l10n.translate('you_label') : (fromUserName ?? l10n.translate('other_party')));

    return GestureDetector(
      onTap: () {
        final index = _messages.indexWhere((m) => m.msgId == replyMsgId);
        if (index >= 0 && _scrollController.hasClients) {
          _scrollController.animateTo(
            index * 80.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.55,
        ),
        decoration: BoxDecoration(
          color: isSelf ? Colors.black.withOpacity(0.05) : AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 2,
              height: 24,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (senderName.isNotEmpty)
                    Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  Text(
                    previewText,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 查找被回复的消息（先从内存列表查找，再从本地存储查找）
  Future<Message?> _findRepliedMessage(String replyMsgId) async {
    // 先从当前消息列表查找
    final index = _messages.indexWhere((m) => m.msgId == replyMsgId);
    if (index >= 0) {
      return _messages[index];
    }

    // 从本地存储查找
    return await _localMessageService.getMessage(
      widget.conversation.conversId,
      replyMsgId,
    );
  }

  /// 显示更多面板
  void _showMorePanel() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMoreItem(Icons.image, l10n.translate('image'), Colors.orange, () {
                        Navigator.pop(context);
                        _pickAndSendImage();
                      }),
                      _buildMoreItem(Icons.camera_alt, l10n.translate('take_photo'), Colors.blue, () {
                        Navigator.pop(context);
                        _takeAndSendPhoto();
                      }),
                      _buildMoreItem(Icons.videocam, l10n.translate('video'), Colors.purple, () {
                        Navigator.pop(context);
                        _pickAndSendVideo();
                      }),
                      _buildMoreItem(Icons.folder, l10n.translate('file'), Colors.teal, () {
                        Navigator.pop(context);
                        _pickAndSendFile();
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMoreItem(Icons.location_on, l10n.translate('location'), Colors.green, () {
                        Navigator.pop(context);
                        _sendLocation();
                      }),
                      _buildMoreItem(Icons.person, l10n.translate('card'), Colors.indigo, () {
                        Navigator.pop(context);
                        _sendContactCard();
                      }),
                      if (context.read<AppConfigProvider>().isFeatureEnabled('feature_red_packet'))
                      _buildMoreItem(Icons.redeem, l10n.translate('red_packet'), Colors.red, () {
                        Navigator.pop(context);
                        _sendRedPacket();
                      }),
                      // 通话按钮（仅私聊）
                      if (!widget.conversation.isGroup)
                        _buildMoreItem(Icons.call, l10n.translate('call'), Colors.cyan, () {
                          Navigator.pop(context);
                          _showCallOptions();
                        })
                      else
                        const SizedBox(width: 70),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 显示通话选项（语音/视频）
  void _showCallOptions() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Text(
                  l10n.translate('select_call_type'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCallOption(
                      icon: Icons.call,
                      label: l10n.translate('voice_call'),
                      color: Colors.green,
                      onTap: () {
                        Navigator.pop(context);
                        _startCall(CallType.voice);
                      },
                    ),
                    _buildCallOption(
                      icon: Icons.videocam,
                      label: l10n.translate('video_call'),
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _startCall(CallType.video);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建通话选项按钮
  Widget _buildCallOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建更多面板项
  Widget _buildMoreItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ========== 图片/视频/文件发送方法 ==========

  /// 选择并发送图片
  Future<void> _pickAndSendImage() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isEmpty) return;

      for (final image in images) {
        await _uploadAndSendImage(image);
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      _showError('${l10n.translate('select_image_failed')}: $e');
    }
  }

  /// 拍照并发送
  Future<void> _takeAndSendPhoto() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (photo == null) return;

      await _uploadAndSendImage(photo);
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      _showError('${l10n.translate('take_photo_failed')}: $e');
    }
  }

  /// 上传并发送图片
  Future<void> _uploadAndSendImage(XFile image) async {
    final l10n = AppLocalizations.of(context)!;
    _showLoading(l10n.translate('sending_image'));

    try {
      UploadResult? result;
      // 获取文件名（带扩展名）
      final filename = image.name.isNotEmpty ? image.name : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        result = await _uploadApi.uploadImage(bytes.toList(), filename: filename);
      } else {
        result = await _uploadApi.uploadImage(image.path, filename: filename);
      }

      _hideLoading();

      if (result != null && result.url.isNotEmpty) {
        // 构建图片消息额外信息
        final extra = jsonEncode({
          'width': result.width ?? 0,
          'height': result.height ?? 0,
          'size': result.size,
          'filename': result.filename,
        });

        await _sendMediaMessage(
          type: MessageType.image,
          content: result.url,
          extra: extra,
        );
      } else {
        _showError(l10n.translate('image_upload_failed'));
      }
    } catch (e) {
      _hideLoading();
      _showError('${l10n.translate('send_image_failed')}: $e');
    }
  }

  /// 选择并发送视频
  Future<void> _pickAndSendVideo() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video == null) return;

      _showLoading(l10n.translate('sending_video'));

      // 获取文件名（带扩展名）
      final filename = video.name.isNotEmpty ? video.name : 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      UploadResult? result;
      if (kIsWeb) {
        final bytes = await video.readAsBytes();
        result = await _uploadApi.uploadVideo(bytes.toList(), filename: filename);
      } else {
        result = await _uploadApi.uploadVideo(video.path, filename: filename);
      }

      _hideLoading();

      if (result != null && result.url.isNotEmpty) {
        final extra = jsonEncode({
          'duration': result.duration ?? 0,
          'size': result.size,
          'filename': result.filename,
        });

        await _sendMediaMessage(
          type: MessageType.video,
          content: result.url,
          extra: extra,
        );
      } else {
        _showError(l10n.translate('video_upload_failed'));
      }
    } catch (e) {
      _hideLoading();
      _showError('${l10n.translate('send_video_failed')}: $e');
    }
  }

  /// 选择并发送文件
  Future<void> _pickAndSendFile() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      // 检查是否为图片类型（图片请使用图片发送功能）
      final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif', 'tiff', 'svg'];
      final ext = (file.extension ?? '').toLowerCase();
      if (imageExtensions.contains(ext)) {
        _showError(l10n.translate('image_use_image_function'));
        return;
      }

      // 检查文件大小（50MB限制）
      if ((file.size) > 50 * 1024 * 1024) {
        _showError(l10n.translate('file_size_limit'));
        return;
      }

      _showLoading(l10n.translate('sending_file'));

      // 使用原始文件名
      final filename = file.name;

      UploadResult? uploadResult;
      if (kIsWeb) {
        if (file.bytes != null) {
          uploadResult = await _uploadApi.uploadFile(file.bytes!.toList(), filename: filename);
        }
      } else if (file.path != null) {
        uploadResult = await _uploadApi.uploadFile(file.path!, filename: filename);
      }

      _hideLoading();

      if (uploadResult != null && uploadResult.url.isNotEmpty) {
        final extra = jsonEncode({
          'filename': file.name,
          'size': file.size,
          'extension': file.extension ?? '',
        });

        await _sendMediaMessage(
          type: MessageType.file,
          content: uploadResult.url,
          extra: extra,
        );
      } else {
        _showError(l10n.translate('file_upload_failed'));
      }
    } catch (e) {
      _hideLoading();
      _showError('${l10n.translate('send_file_failed')}: $e');
    }
  }

  /// 发送位置
  Future<void> _sendLocation() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // Web 端：跳过权限检查，直接调用 getCurrentPosition
      // 因为 Geolocator.checkPermission() 在 web 端不可靠（浏览器可能不支持 Permissions API），
      // 而 getCurrentPosition 会自动触发浏览器的位置授权弹窗
      if (!kIsWeb) {
        // 原生平台检查位置服务是否开启
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _showError(l10n.translate('enable_location_service'));
          return;
        }

        // 原生平台检查位置权限
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            _showError(l10n.translate('location_permission_browser'));
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          _showError(l10n.translate('location_permission_denied'));
          return;
        }
      }

      _showLoading(l10n.translate('getting_location'));

      final position = await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? const LocationSettings(accuracy: LocationAccuracy.medium)
            : const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(
        Duration(seconds: kIsWeb ? 30 : 15),
        onTimeout: () {
          throw Exception(l10n.translate('get_location_timeout'));
        },
      );

      _hideLoading();

      // 清除之前的错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      // 显示位置确认对话框
      if (!mounted) return;
      _showLocationConfirmDialog(position);
    } catch (e) {
      _hideLoading();
      String errorMsg = l10n.translate('get_location_failed');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('denied') || errorStr.contains('permission')) {
        errorMsg = kIsWeb
            ? l10n.translate('location_permission_browser_denied')
            : l10n.translate('location_permission_browser_denied');
      } else if (errorStr.contains('timeout')) {
        errorMsg = l10n.translate('location_timeout_network');
      } else if (kIsWeb && (errorStr.contains('secure') || errorStr.contains('https'))) {
        errorMsg = l10n.translate('location_requires_https');
      }
      _showError(errorMsg);
    }
  }

  /// 显示位置确认对话框
  void _showLocationConfirmDialog(Position position) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('send_location_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 48, color: Colors.green),
              const SizedBox(height: 12),
              Text('${l10n.translate('latitude')}: ${position.latitude.toStringAsFixed(6)}'),
              Text('${l10n.translate('longitude')}: ${position.longitude.toStringAsFixed(6)}'),
              const SizedBox(height: 8),
              Text(
                l10n.translate('send_location_confirm'),
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final extra = jsonEncode({
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                  'address': l10n.translate('current_location'),
                });
                await _sendMediaMessage(
                  type: MessageType.location,
                  content: '${position.latitude},${position.longitude}',
                  extra: extra,
                );
              },
              child: Text(l10n.translate('send')),
            ),
          ],
        );
      },
    );
  }

  /// 发送名片
  Future<void> _sendContactCard() async {
    final l10n = AppLocalizations.of(context)!;
    // 显示选择类型对话框
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.translate('select_card_type'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person, color: AppColors.primary),
                title: Text(l10n.translate('personal_card')),
                subtitle: Text(l10n.translate('share_contact_desc')),
                onTap: () {
                  Navigator.pop(context);
                  _showFriendCardPicker();
                },
              ),
              ListTile(
                leading: const Icon(Icons.group, color: Colors.green),
                title: Text(l10n.translate('group_card')),
                subtitle: Text(l10n.translate('share_group_desc')),
                onTap: () {
                  Navigator.pop(context);
                  _showGroupCardPicker();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// 显示好友名片选择器
  Future<void> _showFriendCardPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final chatProvider = context.read<ChatProvider>();
    final friends = chatProvider.friends;

    if (friends.isEmpty) {
      _showError(l10n.translate('no_friends_to_share'));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.translate('select_friend_to_share'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: friend.friend.avatar.isNotEmpty
                            ? NetworkImage(EnvConfig.instance.getFileUrl(friend.friend.avatar))
                            : null,
                        child: friend.friend.avatar.isEmpty
                            ? Text(friend.displayName[0])
                            : null,
                      ),
                      title: Text(friend.displayName),
                      subtitle: Text(friend.friend.bio ?? ''),
                      onTap: () async {
                        Navigator.pop(context);
                        final extra = jsonEncode({
                          'card_type': 'user',
                          'user_id': friend.friendId,
                          'username': friend.friend.username,
                          'nickname': friend.displayName,
                          'avatar': friend.friend.avatar,
                          'bio': friend.friend.bio ?? '',
                        });
                        await _sendMediaMessage(
                          type: MessageType.card,
                          content: friend.displayName,
                          extra: extra,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示群名片选择器
  Future<void> _showGroupCardPicker() async {
    final l10n = AppLocalizations.of(context)!;
    // 获取群组列表
    try {
      final groupApi = GroupApi(ApiClient());
      final groups = await groupApi.getMyGroups();

      if (groups.isEmpty) {
        _showError(l10n.translate('no_groups_to_share'));
        return;
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.translate('select_group_to_share'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: group.avatar.isNotEmpty
                              ? NetworkImage(EnvConfig.instance.getFileUrl(group.avatar))
                              : null,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: group.avatar.isEmpty
                              ? Text(group.name.isNotEmpty ? group.name[0] : l10n.translate('group_char'))
                              : null,
                        ),
                        title: Text(group.name),
                        subtitle: Text(l10n.translate('people_count').replaceAll('{count}', '${group.memberCount}')),
                        onTap: () async {
                          Navigator.pop(context);
                          final extra = jsonEncode({
                            'card_type': 'group',
                            'group_id': group.id,
                            'group_name': group.name,
                            'avatar': group.avatar,
                            'member_count': group.memberCount,
                          });
                          await _sendMediaMessage(
                            type: MessageType.card,
                            content: group.name,
                            extra: extra,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      _showError('${l10n.translate('get_group_list_failed')}: $e');
    }
  }

  /// 发送红包
  Future<void> _sendRedPacket() async {
    final l10n = AppLocalizations.of(context)!;
    final amountController = TextEditingController();
    final countController = TextEditingController(text: '1');
    final wishController = TextEditingController(text: l10n.translate('red_packet_wish_default'));
    final passwordController = TextEditingController();
    final isGroup = widget.conversation.isGroup;
    bool isLucky = true; // 默认拼手气红包

    // 获取钱包余额
    int goldBeans = 0;
    bool hasPayPassword = false;
    try {
      final apiClient = ApiClient();
      final walletRes = await apiClient.get('/wallet/info');
      if (walletRes.success && walletRes.data != null) {
        goldBeans = walletRes.data['gold_beans'] ?? 0;
        hasPayPassword = walletRes.data['has_pay_password'] ?? false;
      }
    } catch (_) {}

    if (!mounted) return;

    // 检查是否设置了支付密码
    if (!hasPayPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('please_set_pay_password'))),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isGroup ? l10n.translate('send_group_red_packet') : l10n.translate('send_red_packet_title'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  // 显示当前余额
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_wallet, color: Colors.orange, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          l10n.translate('current_balance'),
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                        Text(
                          l10n.translate('gold_beans_count').replaceAll('{count}', '$goldBeans'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 群红包：红包类型选择和个数输入
                  if (isGroup) ...[
                    // 红包类型选择
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => isLucky = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isLucky ? Colors.red : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  l10n.translate('lucky_red_packet'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isLucky ? Colors.white : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => isLucky = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !isLucky ? Colors.red : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  l10n.translate('normal_red_packet'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: !isLucky ? Colors.white : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 红包个数输入
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: Colors.red, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            l10n.translate('red_packet_count'),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: countController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: '1',
                                hintStyle: const TextStyle(color: Colors.grey),
                                suffixText: l10n.translate('quantity_unit'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // 金豆金额输入
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.orange, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          isGroup ? l10n.translate('total_amount') : l10n.goldBeans,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '0',
                              hintStyle: const TextStyle(color: Colors.grey),
                              suffixText: l10n.goldBeans,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isGroup
                        ? (isLucky ? l10n.translate('lucky_random') : l10n.translate('normal_equal'))
                        : l10n.translate('yuan_to_beans_rate').replaceAll('{rate}', '1000'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  // 祝福语输入
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: wishController,
                      maxLength: 30,
                      decoration: InputDecoration(
                        hintText: l10n.translate('wish_hint'),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 支付密码输入
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: passwordController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: l10n.translate('pay_password_hint'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 发送按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amountStr = amountController.text.trim();
                        if (amountStr.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(l10n.translate('please_input_amount'))),
                          );
                          return;
                        }
                        final amount = int.tryParse(amountStr);
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(l10n.translate('please_input_valid_amount'))),
                          );
                          return;
                        }
                        if (amount > 200000) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(l10n.translate('red_packet_max_limit'))),
                          );
                          return;
                        }
                        if (amount > goldBeans) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(l10n.translate('balance_not_enough').replaceAll('{balance}', '$goldBeans'))),
                          );
                          return;
                        }

                        // 群红包验证红包个数
                        int count = 1;
                        if (isGroup) {
                          final countStr = countController.text.trim();
                          count = int.tryParse(countStr) ?? 1;
                          if (count <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(l10n.translate('count_must_positive'))),
                            );
                            return;
                          }
                          if (count > 100) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(l10n.translate('count_max_limit'))),
                            );
                            return;
                          }
                          // 每人至少1金豆
                          if (amount < count) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(l10n.translate('amount_not_enough').replaceAll('{count}', '$count'))),
                            );
                            return;
                          }
                        }

                        final password = passwordController.text.trim();
                        if (password.length != 6) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(l10n.translate('please_input_pay_password'))),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        await _createAndSendRedPacket(
                          amount: amount,
                          count: count,
                          wish: wishController.text.trim(),
                          payPassword: password,
                          type: widget.conversation.isPrivate ? 1 : (isLucky ? 3 : 2),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n.translate('put_money_in'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 创建并发送红包
  Future<void> _createAndSendRedPacket({
    required int amount,
    required int count,
    required String wish,
    required String payPassword,
    required int type, // 1私聊红包 2普通群红包 3拼手气红包
  }) async {
    final l10n = AppLocalizations.of(context)!;
    _showLoading(l10n.translate('sending_red_packet'));

    try {
      // 调用服务端创建红包API
      final apiClient = ApiClient();
      final response = await apiClient.post('/red-packet/create', data: {
        'amount': amount,
        'count': count, // 红包数量（几个人可以领取）
        'wish': wish,
        'type': type, // 1私聊红包 2普通群红包 3拼手气红包
        'to_user_id': widget.conversation.isPrivate ? widget.conversation.targetId : null,
        'group_id': widget.conversation.isGroup ? widget.conversation.targetId : null,
        'pay_password': payPassword,
      });

      _hideLoading();

      if (response.success && response.data != null) {
        final redPacketId = response.data['id'];
        final extra = jsonEncode({
          'red_packet_id': redPacketId,
          'amount': amount,
          'count': count, // 红包数量
          'wish': wish,
          'status': 0, // 0未领取
        });

        await _sendMediaMessage(
          type: MessageType.redPacket,
          content: wish,
          extra: extra,
        );
      } else {
        _showError(response.message ?? l10n.translate('create_red_packet_failed'));
      }
    } catch (e) {
      _hideLoading();
      _showError('${l10n.translate('send_red_packet_failed')}: $e');
    }
  }

  /// 发送媒体消息（图片/视频/文件/位置/名片/红包）
  Future<void> _sendMediaMessage({
    required int type,
    required String content,
    String? extra,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;
    if (currentUser == null) return;

    final msgId = DateTime.now().millisecondsSinceEpoch.toString();
    final conversId = widget.conversation.conversId;

    // 构建消息
    final message = Message(
      msgId: msgId,
      conversId: conversId,
      fromUserId: currentUser.id,
      toUserId: widget.conversation.isPrivate ? widget.conversation.targetId : null,
      groupId: widget.conversation.isGroup ? widget.conversation.targetId : null,
      type: type,
      content: content,
      extra: extra,
      status: 1,
      createdAt: DateTime.now(),
    );

    // 添加到本地列表
    setState(() {
      _messages.insert(0, message);
    });
    _scrollToBottom();

    // 保存到本地存储
    await _chatProvider.saveMessage(message);

    try {
      // 通过HTTP API发送消息（确保消息正确路由和离线存储）
      final result = await _conversationApi.sendMessage(
        msgId: msgId,
        toUserId: widget.conversation.isPrivate ? widget.conversation.targetId : null,
        groupId: widget.conversation.isGroup ? widget.conversation.targetId : null,
        type: type,
        content: content,
        extra: extra,
      );

      if (result.success) {
        // 更新消息状态为已发送
        final sentMessage = Message(
          msgId: msgId,
          conversId: conversId,
          fromUserId: currentUser.id,
          toUserId: message.toUserId,
          groupId: message.groupId,
          type: type,
          content: content,
          extra: extra,
          status: 2,
          createdAt: message.createdAt,
        );

        // 保存到本地存储
        await _localMessageService.saveMessage(sentMessage);

        // 更新UI
        final index = _messages.indexWhere((m) => m.msgId == msgId);
        if (index >= 0 && mounted) {
          setState(() {
            _messages[index] = sentMessage;
          });
        }

        // 更新会话
        _chatProvider.updateConversationLastMessage(
          conversId,
          _getMessagePreview(type, content, l10n),
          DateTime.now(),
        );
      } else {
        throw Exception(result.displayMessage);
      }
    } catch (e) {
      // 发送失败，更新消息状态
      final failedMessage = Message(
        msgId: msgId,
        conversId: conversId,
        fromUserId: currentUser.id,
        toUserId: message.toUserId,
        groupId: message.groupId,
        type: type,
        content: content,
        extra: extra,
        status: -1,
        createdAt: message.createdAt,
      );

      await _localMessageService.saveMessage(failedMessage);

      final index = _messages.indexWhere((m) => m.msgId == msgId);
      if (index >= 0 && mounted) {
        setState(() {
          _messages[index] = failedMessage;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.sendFailed}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 获取消息预览文本
  String _getMessagePreview(int type, String content, AppLocalizations l10n) {
    switch (type) {
      case MessageType.image:
        return l10n.translate('image_preview');
      case MessageType.video:
        return l10n.translate('video_preview');
      case MessageType.file:
        return l10n.translate('file_preview');
      case MessageType.location:
        return l10n.translate('location_preview');
      case MessageType.card:
        return '${l10n.translate('card_preview')} $content';
      case MessageType.redPacket:
        return '${l10n.translate('red_packet_message_prefix')} $content';
      case MessageType.videoShare:
        return l10n.translate('video_share_preview');
      case MessageType.livestreamShare:
        return l10n.translate('livestream_preview');
      default:
        return content;
    }
  }

  /// 显示加载提示
  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  /// 隐藏加载提示
  void _hideLoading() {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  /// 显示错误提示
  void _showError(String message) {
    if (mounted) {
      // 先清除之前的SnackBar，避免堆积
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  /// 格式化时间
  String _formatTime(DateTime? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // ========== 语音录制相关方法 ==========

  /// 开始语音录制
  Future<void> _startVoiceRecord() async {
    final success = await _voiceRecordService.startRecording();
    if (success) {
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });
    } else {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('cannot_start_recording'))),
        );
      }
    }
  }

  /// 停止录音并发送
  Future<void> _stopAndSendVoice() async {
    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
    });

    final result = await _voiceRecordService.stopRecording();
    if (result != null) {
      await _sendVoiceMessage(result.path, result.duration);
    } else {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('recording_too_short'))),
        );
      }
    }
  }

  /// 取消录音
  Future<void> _cancelVoiceRecord() async {
    if (!_isRecording) return;

    await _voiceRecordService.cancelRecording();
    setState(() {
      _isRecording = false;
      _recordDuration = 0;
    });
  }

  /// 格式化录音时长
  String _formatRecordDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  /// 发送语音消息
  Future<void> _sendVoiceMessage(String filePath, int duration) async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();
    final msgId = '${DateTime.now().millisecondsSinceEpoch}_${auth.userId}';

    // 先显示发送中的状态（使用占位内容）
    final localContent = 'uploading|$duration';
    final message = Message(
      msgId: msgId,
      conversId: widget.conversation.conversId,
      fromUserId: auth.userId!,
      toUserId: widget.conversation.isPrivate ? widget.conversation.targetId : null,
      groupId: widget.conversation.isGroup ? widget.conversation.targetId : null,
      type: MessageType.voice,
      content: localContent,
      status: 1, // 发送中
      createdAt: DateTime.now(),
    );

    // 先添加到本地列表
    setState(() {
      _messages.insert(0, message);
    });

    try {
      // 1. 获取音频字节数据
      List<int> bytes;
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      if (kIsWeb) {
        // Web平台：从Blob URL获取字节数据
        // 需要使用独立的Dio实例，因为ApiClient的dio有baseUrl会导致URL拼接错误
        final blobDio = Dio();
        final response = await blobDio.get<List<int>>(
          filePath,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.data == null) {
          throw Exception(l10n.translate('cannot_get_recording'));
        }
        bytes = response.data!;
      } else {
        // 移动平台：从文件读取字节
        final file = File(filePath);
        bytes = await file.readAsBytes();
      }

      // 2. 上传到服务器（路径不需要/api前缀，因为baseUrl已包含）
      final apiClient = ApiClient();
      final uploadResponse = await apiClient.uploadBytes(
        '/upload/audio',
        bytes,
        fileName,
        fieldName: 'file',
      );

      if (!uploadResponse.success || uploadResponse.data == null) {
        throw Exception(uploadResponse.message ?? l10n.uploadFailed);
      }

      // 获取上传后的URL
      final uploadedUrl = uploadResponse.data['url'] ?? uploadResponse.data['path'];
      if (uploadedUrl == null) {
        throw Exception(l10n.translate('upload_url_empty'));
      }

      // 构建语音消息内容（服务器URL + 时长）
      final voiceContent = '$uploadedUrl|$duration';

      // 2. 发送消息到服务器
      final result = await _conversationApi.sendMessage(
        msgId: msgId,
        toUserId: widget.conversation.isPrivate ? widget.conversation.targetId : null,
        groupId: widget.conversation.isGroup ? widget.conversation.targetId : null,
        type: MessageType.voice,
        content: voiceContent,
        replyMsgId: _replyingTo?.msgId,
      );

      if (result.success) {
        // 更新消息状态为已发送
        final sentMessage = Message(
          msgId: msgId,
          conversId: widget.conversation.conversId,
          fromUserId: auth.userId!,
          toUserId: message.toUserId,
          groupId: message.groupId,
          type: MessageType.voice,
          content: voiceContent,
          status: 2, // 已发送
          replyMsgId: message.replyMsgId,
          createdAt: message.createdAt,
        );

        // 保存到本地存储
        await _localMessageService.saveMessage(sentMessage);

        final index = _messages.indexWhere((m) => m.msgId == msgId);
        if (index >= 0) {
          setState(() {
            _messages[index] = sentMessage;
          });
        }

        // 更新会话
        _chatProvider.updateConversation(
          conversId: widget.conversation.conversId,
          lastMsgPreview: l10n.translate('voice_preview'),
          lastMsgTime: DateTime.now(),
        );
      } else {
        throw Exception(result.displayMessage);
      }
    } catch (e) {
      // 发送失败，创建失败消息并保存
      final failedMessage = Message(
        msgId: msgId,
        conversId: widget.conversation.conversId,
        fromUserId: auth.userId!,
        toUserId: message.toUserId,
        groupId: message.groupId,
        type: MessageType.voice,
        content: 'failed|$duration', // 使用简洁的失败标记
        status: -1, // 发送失败
        createdAt: message.createdAt,
      );

      // 保存到本地存储（同步content和status）
      await _localMessageService.saveMessage(failedMessage);

      // 更新UI显示失败状态
      final index = _messages.indexWhere((m) => m.msgId == msgId);
      if (index >= 0) {
        setState(() {
          _messages[index] = failedMessage;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('send_voice_failed')}: $e')),
        );
      }
    }
  }

  /// 播放语音消息
  Future<void> _playVoice(Message message) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // 解析语音内容（格式：url|duration）
      final parts = message.content.split('|');
      if (parts.isEmpty) return;

      var audioUrl = parts[0];

      // 检查是否是有效的语音URL
      if (audioUrl.isEmpty || audioUrl == 'uploading' || audioUrl == 'failed') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('voice_not_available'))),
          );
        }
        return;
      }

      // 如果正在播放同一条消息，停止播放
      if (_playingVoiceMsgId == message.msgId) {
        await _audioPlayer.stop();
        setState(() {
          _playingVoiceMsgId = null;
        });
        return;
      }

      // 停止之前的播放
      await _audioPlayer.stop();

      setState(() {
        _playingVoiceMsgId = message.msgId;
      });

      // 处理URL：如果是相对路径，拼接服务器地址
      if (!audioUrl.startsWith('http') && !audioUrl.startsWith('/')) {
        // 本地文件路径，尝试直接播放（仅移动端）
        if (!kIsWeb) {
          await _audioPlayer.setFilePath(audioUrl);
          await _audioPlayer.play();
          return;
        } else {
          // Web端不支持本地文件路径，显示错误
          setState(() {
            _playingVoiceMsgId = null;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('voice_file_unavailable'))),
            );
          }
          return;
        }
      }

      // 如果是相对路径（以/开头），拼接服务器地址
      if (audioUrl.startsWith('/')) {
        audioUrl = EnvConfig.instance.getFileUrl(audioUrl);
      }

      // 设置音频源并播放
      await _audioPlayer.setUrl(audioUrl);

      await _audioPlayer.play();

      // 监听播放完成
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) {
            setState(() {
              _playingVoiceMsgId = null;
            });
          }
        }
      });
    } catch (e) {
      setState(() {
        _playingVoiceMsgId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('play_failed')}: $e')),
        );
      }
    }
  }
}

/// 视频播放页面
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          final l10n = AppLocalizations.of(context)!;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  '${l10n.translate('video_playback_failed')}: $errorMessage',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadVideo(),
            tooltip: l10n.translate('download_video'),
          ),
        ],
      ),
      body: Center(
        child: _buildContent(l10n),
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    if (_isLoading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            l10n.translate('loading_video'),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            '${l10n.translate('play_failed')}: $_errorMessage',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _initializePlayer();
            },
            child: Text(l10n.translate('retry')),
          ),
        ],
      );
    }

    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    return Text(
      l10n.translate('cannot_play_video'),
      style: const TextStyle(color: Colors.white),
    );
  }

  Future<void> _downloadVideo() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('web_save_hint')),
            action: SnackBarAction(
              label: l10n.translate('copy_link'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.videoUrl));
              },
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('start_download'))),
      );

      // 获取下载目录
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // 生成唯一文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = widget.title.contains('.') ? widget.title.split('.').last : 'mp4';
      final baseName = widget.title.contains('.') ? widget.title.substring(0, widget.title.lastIndexOf('.')) : widget.title;
      final savePath = '${downloadDir.path}/${baseName}_$timestamp.$ext';

      // 使用Dio下载
      final dio = Dio();
      await dio.download(widget.videoUrl, savePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('saved_to').replaceAll('{path}', savePath)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('download_failed')}: $e')),
        );
      }
    }
  }
}


/// 用户资料页面
class _UserProfileScreen extends StatefulWidget {
  final int userId;
  final String displayName;
  final String username;
  final String avatar;
  final String? bio;
  final int? gender;
  final String? region;
  final bool isCustomerService;
  final VoidCallback onAddFriend;

  const _UserProfileScreen({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.avatar,
    this.bio,
    this.gender,
    this.region,
    required this.isCustomerService,
    required this.onAddFriend,
  });

  @override
  State<_UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<_UserProfileScreen> {
  bool _isFriend = true; // 从聊天页面进来的都是好友

  String _getFullUrl(String url) {
    if (url.isEmpty || url == '/') return '';
    if (url.startsWith('http')) return url;
    return EnvConfig.instance.getFileUrl(url);
  }

  void _startChat() {
    // 返回到聊天页面
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final avatarUrl = _getFullUrl(widget.avatar);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.viewProfile),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 顶部背景区域
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // 头像
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: avatarUrl.isNotEmpty 
                        ? NetworkImage(avatarUrl.proxied) 
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            widget.displayName.isNotEmpty 
                                ? widget.displayName[0] 
                                : '?',
                            style: const TextStyle(
                              fontSize: 36,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  // 昵称
                  Text(
                    widget.displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 客服标识
                  if (widget.isCustomerService)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.support_agent,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.translate('official_support'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 基本信息卡片
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 账号
                  if (widget.username.isNotEmpty)
                    _buildInfoItem(
                      icon: Icons.account_circle_outlined,
                      label: l10n.account,
                      value: widget.username,
                    ),
                  // 性别
                  if (widget.gender != null && widget.gender != 0)
                    _buildInfoItem(
                      icon: widget.gender == 1 ? Icons.male : Icons.female,
                      iconColor: widget.gender == 1 ? Colors.blue : Colors.pink,
                      label: l10n.gender,
                      value: widget.gender == 1 ? l10n.male : l10n.female,
                    ),
                  // 地区
                  if (widget.region != null && widget.region!.isNotEmpty)
                    _buildInfoItem(
                      icon: Icons.location_on_outlined,
                      label: l10n.region,
                      value: widget.region!,
                    ),
                  // 个人简介
                  if (widget.bio != null && widget.bio!.isNotEmpty)
                    _buildInfoItem(
                      icon: Icons.description_outlined,
                      label: l10n.bio,
                      value: widget.bio!,
                      isMultiLine: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 操作按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: _isFriend
                    ? ElevatedButton.icon(
                        onPressed: _startChat,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(l10n.translate('send_message_label')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: widget.onAddFriend,
                        icon: const Icon(Icons.person_add),
                        label: Text(l10n.addFriend),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    Color? iconColor,
    required String label,
    required String value,
    bool isMultiLine = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: iconColor ?? AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: isMultiLine ? null : 1,
                  overflow: isMultiLine ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
