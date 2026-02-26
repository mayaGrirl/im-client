/// WebRTC 服务 - 处理音视频通话
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/call_api.dart';
import 'package:im_client/services/websocket_service.dart';
import 'package:im_client/services/call_ringtone_service.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/utils/audio_manager.dart';

/// 通话状态枚举
enum CallState {
  idle, // 空闲
  outgoing, // 呼出中
  incoming, // 来电中
  connecting, // 连接中
  connected, // 已连接
  ended, // 已结束
}

/// WebRTC 服务
class WebRTCService extends ChangeNotifier {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  final CallApi _callApi = CallApi(ApiClient());
  final CallRingtoneService _ringtoneService = CallRingtoneService();

  // 当前用户ID（用于判断铃声设置）
  int? _currentUserId;

  // WebRTC 相关
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // 渲染器
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  // 通话状态
  CallState _callState = CallState.idle;
  CallState get callState => _callState;

  String? _currentCallId;
  String? get currentCallId => _currentCallId;

  int? _remoteUserId;
  int? get remoteUserId => _remoteUserId;

  String? _remoteUserName;
  String? get remoteUserName => _remoteUserName;

  String? _remoteUserAvatar;
  String? get remoteUserAvatar => _remoteUserAvatar;

  int _callType = CallType.voice;
  int get callType => _callType;

  bool get isVideo => _callType == CallType.video;

  // 通话时长
  int _callDuration = 0;
  int get callDuration => _callDuration;
  Timer? _durationTimer;

  // 音频/视频控制
  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  bool _isVideoEnabled = true;
  bool get isVideoEnabled => _isVideoEnabled;

  bool _isFrontCamera = true;
  bool get isFrontCamera => _isFrontCamera;

  // ICE 服务器配置
  List<Map<String, dynamic>> _iceServers = [
    {
      'urls': ['stun:stun.l.google.com:19302']
    }
  ];

  // ICE candidate 缓冲队列（remote description 设置前收到的 candidates）
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;

  // WebSocket 消息订阅
  StreamSubscription? _wsSubscription;

  // 是否已初始化
  bool _isInitialized = false;

  // 呼叫超时计时器（客户端备用，65秒，比服务端60秒多5秒容错）
  Timer? _callTimeoutTimer;
  static const int _callTimeoutSeconds = 65;

  /// 设置当前用户ID（用于铃声设置判断）
  void setCurrentUserId(int userId) {
    _currentUserId = userId;
  }

  /// 初始化服务
  Future<void> initialize() async {
    // 防止重复初始化
    if (_isInitialized) return;

    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();

      // 初始化铃声服务
      await _ringtoneService.init();

      // 获取ICE服务器配置
      await _loadIceServers();

      // Web 平台检测摄像头切换支持
      if (kIsWeb) {
        _canSwitchCamera = await _checkCameraSwitchSupport();
        debugPrint('[WebRTCService] Web 平台初始化: canSwitchCamera=$_canSwitchCamera');
      } else {
        debugPrint('[WebRTCService] 移动平台初始化');
      }

      // 监听WebSocket消息 - 取消旧订阅，创建新订阅
      await _wsSubscription?.cancel();
      _wsSubscription = WebSocketService().messageStream.listen(_handleWebSocketMessage);

      _isInitialized = true;
      debugPrint('[WebRTCService] 初始化完成');
    } catch (e) {
      debugPrint('[WebRTCService] 初始化失败: $e');
      rethrow;
    }
  }

  /// 重置服务状态（登出时调用）
  /// 重置初始化标志，以便重新登录时可以重新初始化
  Future<void> reset() async {
    debugPrint('[WebRTCService] 重置服务状态...');

    // 停止铃声
    await _ringtoneService.stopIncomingRingtone();
    await _ringtoneService.stopDialingTone();

    // 清理通话资源
    await _cleanup();

    // 取消WebSocket订阅
    await _wsSubscription?.cancel();
    _wsSubscription = null;

    // 重置初始化标志，允许重新初始化
    _isInitialized = false;

    // 重置用户ID
    _currentUserId = null;

    // 清除回调
    onIncomingCall = null;
    onCallConnected = null;
    onCallEnded = null;
    onIncomingCallCancelled = null;

    debugPrint('[WebRTCService] 服务状态已重置');
  }

  /// 加载ICE服务器配置
  Future<void> _loadIceServers() async {
    try {
      final response = await _callApi.getIceServers();
      if (response.success && response.data != null) {
        final servers = response.data['ice_servers'] as List?;
        if (servers != null && servers.isNotEmpty) {
          _iceServers = servers.map((s) {
            return IceServer.fromJson(s).toMap();
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('加载ICE服务器配置失败: $e');
    }
  }

  /// 处理WebSocket消息
  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    final data = message['data'] as Map<String, dynamic>?;

    debugPrint('[WebRTCService] 收到WebSocket消息: type=$type');

    if (data == null) return;

    // 处理通话控制消息
    if (type == 'call') {
      final action = data['action'] as String?;
      debugPrint('[WebRTCService] 通话控制消息: action=$action, callId=${data['call_id']}, currentState=$_callState');
      switch (action) {
        case 'incoming_call':
          _handleIncomingCall(data);
          break;
        case 'call_accepted':
          _handleCallAccepted(data);
          break;
        case 'call_rejected':
          _handleCallRejected(data);
          break;
        case 'call_ended':
          _handleRemoteHangup(data);
          break;
        case 'call_cancelled':
          _handleCallCancelled(data);
          break;
        case 'call_busy':
          _handleCallBusy(data);
          break;
        case 'call_missed':
          _handleCallMissed(data);
          break;
        case 'call_answered_elsewhere':
          _handleCallAnsweredElsewhere(data);
          break;
      }
      return;
    }

    // 处理WebRTC信令消息
    if (type == 'signal') {
      final signalType = data['signal_type'] as String?;
      final signalData = data['signal_data'] as String?;
      debugPrint('[WebRTCService] 收到信令: type=$signalType, callId=${data['call_id']}, currentState=$_callState, pcExists=${_peerConnection != null}, remoteDescSet=$_remoteDescriptionSet');
      if (signalData == null) return;

      try {
        final parsed = jsonDecode(signalData) as Map<String, dynamic>;
        switch (signalType) {
          case 'offer':
            _handleRemoteOffer(parsed);
            break;
          case 'answer':
            _handleCallAnswered(parsed);
            break;
          case 'candidate':
            _handleIceCandidate(parsed);
            break;
        }
      } catch (e) {
        debugPrint('[WebRTCService] 解析信令数据失败: $e');
      }
    }
  }

  /// 处理来电
  void _handleIncomingCall(Map<String, dynamic> data) {
    if (_callState != CallState.idle) {
      // 正在通话中，发送忙线
      final callId = data['call_id'] as String?;
      if (callId != null) {
        _callApi.busyCall(callId);
      }
      return;
    }

    _currentCallId = data['call_id'] as String?;
    _callType = data['call_type'] as int? ?? CallType.voice;

    // 服务端发送的caller对象
    final caller = data['caller'] as Map<String, dynamic>?;
    if (caller != null) {
      _remoteUserId = caller['id'] as int?;
      _remoteUserName = (caller['nickname'] as String?) ?? (caller['username'] as String?) ?? '';
      _remoteUserAvatar = caller['avatar'] as String? ?? '';
    }

    _callState = CallState.incoming;
    notifyListeners();

    // 播放来电铃声和震动
    if (_remoteUserId != null && _currentUserId != null) {
      _ringtoneService.playIncomingRingtone(_remoteUserId!, _currentUserId!);
    }

    // 触发来电回调
    if (_currentCallId != null && _remoteUserId != null) {
      onIncomingCall?.call(
        _currentCallId!,
        _remoteUserId!,
        _remoteUserName ?? '',
        _remoteUserAvatar ?? '',
        _callType,
      );
    }
  }

  /// 处理远程Offer（接听方收到）
  void _handleRemoteOffer(Map<String, dynamic> data) async {
    final sdp = data['sdp'] as String?;
    if (sdp == null) {
      debugPrint('[WebRTCService] Offer SDP 为空');
      return;
    }

    debugPrint('[WebRTCService] 收到 Offer: state=$_callState, pcExists=${_peerConnection != null}, remoteDescSet=$_remoteDescriptionSet');
    debugPrint('[WebRTCService] Offer SDP 包含视频: ${sdp.contains('m=video')}');
    debugPrint('[WebRTCService] Offer SDP 包含音频: ${sdp.contains('m=audio')}');

    // 如果 answerCall() 已执行但当时 offer 未到达（PeerConnection 已创建，
    // remote description 未设置），立即处理 offer 并发送 answer
    if (_callState == CallState.connecting &&
        _peerConnection != null &&
        !_remoteDescriptionSet) {
      debugPrint('[WebRTCService] Offer 延迟到达，answerCall 已执行，立即处理');
      try {
        final offer = RTCSessionDescription(sdp, 'offer');
        await _peerConnection!.setRemoteDescription(offer);
        _remoteDescriptionSet = true;
        await _flushPendingCandidates();

        // 创建 Answer - 确保即使对方没有视频也能发送视频
        final answerOptions = {
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': true, // 始终尝试接收视频
        };
        
        final answer = await _peerConnection!.createAnswer(answerOptions);
        await _peerConnection!.setLocalDescription(answer);

        debugPrint('[WebRTCService] Answer 已创建，准备发送');
        debugPrint('[WebRTCService] Answer SDP 包含视频: ${answer.sdp?.contains('m=video') ?? false}');
        debugPrint('[WebRTCService] Answer SDP 包含音频: ${answer.sdp?.contains('m=audio') ?? false}');

        // 发送 Answer 到对方
        if (_currentCallId != null && _remoteUserId != null) {
          await _callApi.sendSignal(
            callId: _currentCallId!,
            toUserId: _remoteUserId!,
            signalType: 'answer',
            signalData: jsonEncode({
              'sdp': answer.sdp,
              'type': answer.type,
            }),
          );
          debugPrint('[WebRTCService] Answer 已发送');
        }
      } catch (e) {
        debugPrint('[WebRTCService] 延迟处理 Offer 失败: $e');
      }
    } else {
      // 正常缓存，等待用户接听时使用
      debugPrint('[WebRTCService] 缓存 Offer，等待用户接听');
      _pendingRemoteSdp = sdp;
    }
  }

  String? _pendingRemoteSdp;

  /// 处理对方接听通话
  void _handleCallAccepted(Map<String, dynamic> data) {
    final callId = data['call_id'] as String?;
    if (callId == _currentCallId && _callState == CallState.outgoing) {
      // 停止去电等待音
      _ringtoneService.stopDialingTone();
      // 取消超时计时器
      _cancelCallTimeoutTimer();
      _callState = CallState.connecting;
      notifyListeners();
    }
  }

  /// 处理通话被取消（主叫方取消）
  void _handleCallCancelled(Map<String, dynamic> data) {
    final callId = data['call_id'] as String?;
    if (callId == _currentCallId || _callState == CallState.incoming) {
      _cancelCallTimeoutTimer();
      _callState = CallState.ended;
      notifyListeners();
      // 触发来电取消回调（用于关闭来电悬浮层）
      onIncomingCallCancelled?.call();
      onCallEnded?.call('对方已取消');
      _cleanup();
    }
  }

  /// 处理未接来电（超时无人接听）
  void _handleCallMissed(Map<String, dynamic> data) {
    final callId = data['call_id'] as String?;
    debugPrint('[WebRTCService] 收到call_missed: callId=$callId, currentCallId=$_currentCallId, callState=$_callState');
    if (callId == _currentCallId || _callState == CallState.outgoing) {
      _cancelCallTimeoutTimer();
      // 停止去电等待音
      _ringtoneService.stopDialingTone();
      _callState = CallState.ended;
      notifyListeners();
      onCallEnded?.call('对方无应答');
      _cleanup();
    }
  }

  /// 处理通话已在其他设备接听
  void _handleCallAnsweredElsewhere(Map<String, dynamic> data) {
    final callId = data['call_id'] as String?;
    debugPrint('[WebRTCService] 通话已在其他设备接听: callId=$callId, state=$_callState');
    // 只在来电等待状态时处理（已接听/连接中的设备不受影响）
    if (_callState == CallState.incoming && (callId == _currentCallId || callId == null)) {
      _cancelCallTimeoutTimer();
      _ringtoneService.stopIncomingRingtone();
      _callState = CallState.ended;
      notifyListeners();
      onCallEnded?.call('已在其他设备接听');
      _cleanup();
    }
  }

  /// 处理通话被接听（收到Answer SDP）
  void _handleCallAnswered(Map<String, dynamic> data) async {
    final sdp = data['sdp'] as String?;
    if (sdp != null && _peerConnection != null) {
      debugPrint('[WebRTCService] 收到 Answer');
      debugPrint('[WebRTCService] Answer SDP 包含视频: ${sdp.contains('m=video')}');
      debugPrint('[WebRTCService] Answer SDP 包含音频: ${sdp.contains('m=audio')}');
      
      final answer = RTCSessionDescription(sdp, 'answer');
      await _peerConnection!.setRemoteDescription(answer);
      _remoteDescriptionSet = true;
      await _flushPendingCandidates();
      // 仅在尚未到达 connected 状态时设置 connecting
      // （ICE 协商可能在 flush 过程中已完成，onConnectionState 已将状态设为 connected）
      if (_callState != CallState.connected) {
        _callState = CallState.connecting;
        notifyListeners();
      }
    }
  }

  /// 处理ICE候选
  void _handleIceCandidate(Map<String, dynamic> data) async {
    final candidate = data['candidate'] as String?;
    final sdpMid = data['sdp_mid'] as String?;
    final sdpMLineIndex = data['sdp_mline_index'] as int?;

    if (candidate != null) {
      final iceCandidate = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
      if (_peerConnection == null || !_remoteDescriptionSet) {
        // PeerConnection 未创建或 remote description 未设置，缓存 candidate
        _pendingCandidates.add(iceCandidate);
        debugPrint('[WebRTCService] 缓存 ICE candidate（PC=${_peerConnection != null}, remoteDesc=$_remoteDescriptionSet），当前缓存数: ${_pendingCandidates.length}');
      } else {
        await _peerConnection!.addCandidate(iceCandidate);
      }
    }
  }

  /// Flush 缓存的 ICE candidates（在 setRemoteDescription 之后调用）
  Future<void> _flushPendingCandidates() async {
    if (_pendingCandidates.isNotEmpty && _peerConnection != null) {
      debugPrint('[WebRTCService] Flush ${_pendingCandidates.length} 个缓存的 ICE candidates');
      for (final candidate in _pendingCandidates) {
        await _peerConnection!.addCandidate(candidate);
      }
      _pendingCandidates.clear();
    }
  }

  /// 处理远程挂断
  void _handleRemoteHangup(Map<String, dynamic> data) {
    final callId = data['call_id'] as String?;
    if (callId == _currentCallId) {
      endCall(isRemote: true);
    }
  }

  /// 处理通话被拒绝
  void _handleCallRejected(Map<String, dynamic> data) {
    final callId = data['call_id'] as String?;
    if (callId == _currentCallId) {
      _cancelCallTimeoutTimer();
      // 停止去电等待音
      _ringtoneService.stopDialingTone();
      _callState = CallState.ended;
      notifyListeners();
      onCallEnded?.call('对方已拒绝');
      _cleanup();
    }
  }

  /// 处理忙线
  void _handleCallBusy(Map<String, dynamic> data) {
    final callId = data['call_id'] as String?;
    if (callId == _currentCallId) {
      _cancelCallTimeoutTimer();
      // 停止去电等待音
      _ringtoneService.stopDialingTone();
      _callState = CallState.ended;
      notifyListeners();
      onCallEnded?.call('对方正忙');
      _cleanup();
    }
  }

  /// 发起通话
  Future<bool> startCall({
    required int targetUserId,
    required String targetUserName,
    required String targetUserAvatar,
    required int callType,
  }) async {
    if (_callState != CallState.idle) {
      onCallEnded?.call('当前正在通话中');
      return false;
    }

    try {
      _callType = callType;
      _remoteUserId = targetUserId;
      _remoteUserName = targetUserName;
      _remoteUserAvatar = targetUserAvatar;
      _callState = CallState.outgoing;
      notifyListeners();

      // 获取本地媒体流
      try {
        await _createLocalStream();
      } catch (e) {
        debugPrint('获取媒体流失败: $e');
        _callState = CallState.idle;
        notifyListeners();
        final errorMsg = isVideo ? '无法访问摄像头和麦克风，请检查权限' : '无法访问麦克风，请检查权限';
        onCallEnded?.call(errorMsg);
        await _cleanup();
        return false;
      }

      // 调用API发起通话
      final response = await _callApi.initiateCall(
        targetId: targetUserId,
        callType: callType,
      );

      if (!response.success) {
        _callState = CallState.idle;
        notifyListeners();
        onCallEnded?.call(response.message ?? '发起通话失败');
        await _cleanup();
        return false;
      }

      _currentCallId = response.data?['call_id'] as String?;

      // 播放去电等待音
      if (_currentUserId != null) {
        _ringtoneService.playDialingTone(targetUserId, _currentUserId!);
      }

      // 启动客户端超时计时器（备用）
      _startCallTimeoutTimer();

      // 创建PeerConnection
      await _createPeerConnection();

      // 创建Offer - 使用特定选项确保即使本地没有视频也能接收远程视频
      final offerOptions = {
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': isVideo, // 视频通话时接收视频，即使本地没有摄像头
      };
      
      final offer = await _peerConnection!.createOffer(offerOptions);
      await _peerConnection!.setLocalDescription(offer);
      
      debugPrint('[WebRTCService] Offer 已创建（offerToReceiveVideo: $isVideo）');
      debugPrint('[WebRTCService] Offer SDP 包含视频: ${offer.sdp?.contains('m=video') ?? false}');
      debugPrint('[WebRTCService] Offer SDP 包含音频: ${offer.sdp?.contains('m=audio') ?? false}');

      // 发送Offer到对方
      await _callApi.sendSignal(
        callId: _currentCallId!,
        toUserId: targetUserId,
        signalType: 'offer',
        signalData: jsonEncode({
          'sdp': offer.sdp,
          'type': offer.type,
        }),
      );
      
      debugPrint('[WebRTCService] Offer 已发送到服务器');

      return true;
    } catch (e) {
      debugPrint('发起通话失败: $e');
      _callState = CallState.idle;
      notifyListeners();
      onCallEnded?.call('发起通话失败: $e');
      await _cleanup();
      return false;
    }
  }

  /// 接听通话
  Future<bool> answerCall() async {
    if (_callState != CallState.incoming || _currentCallId == null) {
      return false;
    }

    // 停止来电铃声
    await _ringtoneService.stopIncomingRingtone();

    try {
      _callState = CallState.connecting;
      notifyListeners();

      // 获取本地媒体流
      await _createLocalStream();

      // 创建PeerConnection（必须在接听前创建，以便接收 offer）
      await _createPeerConnection();

      // 调用API接听
      final response = await _callApi.acceptCall(_currentCallId!);
      if (!response.success) {
        _callState = CallState.ended;
        notifyListeners();
        onCallEnded?.call(response.message ?? '接听失败');
        await _cleanup();
        return false;
      }

      // 检查是否已经收到 offer（通过 WebSocket）
      if (_pendingRemoteSdp != null) {
        debugPrint('[WebRTCService] 使用缓存的 offer');
        debugPrint('[WebRTCService] Offer SDP 包含视频: ${_pendingRemoteSdp!.contains('m=video')}');
        debugPrint('[WebRTCService] Offer SDP 包含音频: ${_pendingRemoteSdp!.contains('m=audio')}');
        
        final offer = RTCSessionDescription(_pendingRemoteSdp!, 'offer');
        await _peerConnection!.setRemoteDescription(offer);
        _remoteDescriptionSet = true;
        _pendingRemoteSdp = null; // 清除缓存

        // Flush 缓存的 ICE candidates
        await _flushPendingCandidates();

        // 创建Answer - 确保即使对方没有视频也能发送视频
        final answerOptions = {
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': true, // 始终尝试接收视频
        };
        
        final answer = await _peerConnection!.createAnswer(answerOptions);
        await _peerConnection!.setLocalDescription(answer);
        
        debugPrint('[WebRTCService] Answer 已创建');
        debugPrint('[WebRTCService] Answer SDP 包含视频: ${answer.sdp?.contains('m=video') ?? false}');
        debugPrint('[WebRTCService] Answer SDP 包含音频: ${answer.sdp?.contains('m=audio') ?? false}');

        // 发送Answer到对方
        await _callApi.sendSignal(
          callId: _currentCallId!,
          toUserId: _remoteUserId!,
          signalType: 'answer',
          signalData: jsonEncode({
            'sdp': answer.sdp,
            'type': answer.type,
          }),
        );
        
        debugPrint('[WebRTCService] Answer 已发送到服务器');
      } else {
        debugPrint('[WebRTCService] 等待 offer 通过 WebSocket 到达');
        // offer 将通过 WebSocket 到达，_handleRemoteOffer 会处理
      }

      return true;
    } catch (e) {
      debugPrint('接听通话失败: $e');
      _callState = CallState.ended;
      notifyListeners();
      onCallEnded?.call('接听失败');
      await _cleanup();
      return false;
    }
  }

  /// 拒绝通话
  Future<void> rejectCall() async {
    if (_currentCallId != null) {
      await _callApi.rejectCall(_currentCallId!);
    }
    _callState = CallState.idle;
    notifyListeners();
    await _cleanup();
  }

  /// 结束通话
  Future<void> endCall({bool isRemote = false, String? reason}) async {
    if (_currentCallId != null && !isRemote) {
      if (_callState == CallState.outgoing) {
        await _callApi.cancelCall(_currentCallId!);
      } else {
        await _callApi.endCall(_currentCallId!);
      }
    }

    _callState = CallState.ended;
    notifyListeners();

    // 无论是本地还是远程挂断，都需要通知UI关闭
    final endReason = reason ?? (isRemote ? '对方已挂断' : '通话已结束');
    onCallEnded?.call(endReason);

    await _cleanup();
  }

  /// 创建本地媒体流
  Future<void> _createLocalStream() async {
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': isVideo
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    };

    debugPrint('[WebRTCService] 创建本地媒体流: isVideo=$isVideo, constraints=$mediaConstraints');

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      debugPrint('[WebRTCService] 本地媒体流创建成功');
      
      // 打印轨道信息
      final audioTracks = _localStream!.getAudioTracks();
      final videoTracks = _localStream!.getVideoTracks();
      debugPrint('[WebRTCService] 音频轨道数: ${audioTracks.length}');
      debugPrint('[WebRTCService] 视频轨道数: ${videoTracks.length}');
      
      for (var i = 0; i < audioTracks.length; i++) {
        debugPrint('[WebRTCService] 音频轨道 $i: id=${audioTracks[i].id}, enabled=${audioTracks[i].enabled}');
      }
      for (var i = 0; i < videoTracks.length; i++) {
        debugPrint('[WebRTCService] 视频轨道 $i: id=${videoTracks[i].id}, enabled=${videoTracks[i].enabled}');
      }
    } catch (e) {
      // 视频通话时如果没有摄像头（如Web端无摄像头），降级为纯音频
      if (isVideo) {
        debugPrint('[WebRTCService] 获取摄像头失败，降级为纯音频: $e');
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });
        debugPrint('[WebRTCService] 已降级为纯音频模式');
      } else {
        rethrow;
      }
    }
    localRenderer.srcObject = _localStream;
    
    // 媒体流创建后立即初始化扬声器状态
    await _initSpeakerForCallType();
  }

  /// 创建PeerConnection
  Future<void> _createPeerConnection() async {
    final configuration = <String, dynamic>{
      'iceServers': _iceServers,
    };

    _peerConnection = await createPeerConnection(configuration);
    debugPrint('[WebRTCService] PeerConnection 已创建');

    // 添加本地流
    if (_localStream != null) {
      final tracks = _localStream!.getTracks();
      debugPrint('[WebRTCService] 准备添加 ${tracks.length} 个轨道到 PeerConnection');
      
      for (var track in tracks) {
        final sender = await _peerConnection!.addTrack(track, _localStream!);
        debugPrint('[WebRTCService] 已添加轨道: kind=${track.kind}, id=${track.id}, enabled=${track.enabled}');
      }
    } else {
      debugPrint('[WebRTCService] 警告：本地流为空，无法添加轨道');
    }

    // 监听远程流
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint('[WebRTCService] 收到远程轨道: kind=${event.track.kind}, streams=${event.streams.length}');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        debugPrint('[WebRTCService] 远程流已设置到渲染器');
        notifyListeners();
      }
    };

    // 监听ICE候选
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_currentCallId != null && _remoteUserId != null) {
        _callApi.sendSignal(
          callId: _currentCallId!,
          toUserId: _remoteUserId!,
          signalType: 'candidate',
          signalData: jsonEncode({
            'candidate': candidate.candidate,
            'sdp_mid': candidate.sdpMid,
            'sdp_mline_index': candidate.sdpMLineIndex,
          }),
        );
      }
    };

    // 监听连接状态
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('连接状态: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _callState = CallState.connected;
        _startDurationTimer();
        // 扬声器已在媒体流创建时初始化，这里确保状态正确（仅非 Web 平台）
        if (!kIsWeb) {
          _applySpeakerMode();
        }
        notifyListeners();
        onCallConnected?.call();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        endCall(isRemote: true);
      }
    };
  }

  /// 开始计时
  void _startDurationTimer() {
    _callDuration = 0;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDuration++;
      notifyListeners();
    });
  }

  /// 启动呼叫超时计时器（客户端备用）
  void _startCallTimeoutTimer() {
    _cancelCallTimeoutTimer();
    debugPrint('[WebRTCService] 启动呼叫超时计时器: ${_callTimeoutSeconds}秒');
    _callTimeoutTimer = Timer(Duration(seconds: _callTimeoutSeconds), () {
      debugPrint('[WebRTCService] 呼叫超时（客户端）');
      if (_callState == CallState.outgoing) {
        // 超时未接听，通知服务端取消通话
        if (_currentCallId != null) {
          _callApi.cancelCall(_currentCallId!);
        }
        _ringtoneService.stopDialingTone();
        _callState = CallState.ended;
        notifyListeners();
        onCallEnded?.call('对方无应答');
        _cleanup();
      }
    });
  }

  /// 取消呼叫超时计时器
  void _cancelCallTimeoutTimer() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
  }

  /// 切换静音
  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
    notifyListeners();
  }

  /// 切换扬声器
  Future<void> toggleSpeaker() async {
    // Web 平台不支持扬声器切换
    if (kIsWeb) {
      debugPrint('[WebRTCService] Web 平台不支持扬声器切换');
      return;
    }
    
    _isSpeakerOn = !_isSpeakerOn;
    await _applySpeakerMode();
    notifyListeners();
  }

  /// 设置扬声器模式
  Future<void> setSpeakerOn(bool on) async {
    // Web 平台不支持扬声器切换
    if (kIsWeb) {
      debugPrint('[WebRTCService] Web 平台不支持扬声器切换');
      return;
    }
    
    if (_isSpeakerOn == on) return;
    _isSpeakerOn = on;
    await _applySpeakerMode();
    notifyListeners();
  }

  /// 应用扬声器设置
  Future<void> _applySpeakerMode() async {
    // Web 平台不支持扬声器切换
    if (kIsWeb) {
      return;
    }
    
    try {
      // 使用增强的音频管理器来切换扬声器
      await AudioManager.setSpeakerphoneOn(_isSpeakerOn);
      // 添加短暂延迟确保音频路由切换完成
      await Future.delayed(const Duration(milliseconds: 100));
      debugPrint('[WebRTCService] 扬声器已${_isSpeakerOn ? "开启" : "关闭"}');
    } catch (e) {
      debugPrint('[WebRTCService] 切换扬声器失败: $e');
      // 如果切换失败，恢复状态
      _isSpeakerOn = !_isSpeakerOn;
    }
  }

  /// 根据通话类型初始化扬声器状态
  Future<void> _initSpeakerForCallType() async {
    // Web 平台不支持扬声器切换，跳过初始化
    if (kIsWeb) {
      return;
    }
    
    // 视频通话默认开启扬声器，语音通话默认关闭
    final shouldEnableSpeaker = _callType == CallType.video;
    if (_isSpeakerOn != shouldEnableSpeaker) {
      _isSpeakerOn = shouldEnableSpeaker;
      await _applySpeakerMode();
      notifyListeners();
    }
  }

  /// 切换视频
  void toggleVideo() {
    if (!isVideo) return;
    _isVideoEnabled = !_isVideoEnabled;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = _isVideoEnabled;
    });
    notifyListeners();
  }

  // 是否支持摄像头切换（Web 平台需要检测）
  bool _canSwitchCamera = true;
  bool get canSwitchCamera => _canSwitchCamera;

  /// 检测是否支持摄像头切换
  Future<bool> _checkCameraSwitchSupport() async {
    if (!kIsWeb) {
      return true; // 移动平台默认支持
    }

    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      final videoDevices = devices.where((d) => d.kind == 'videoinput').toList();
      final canSwitch = videoDevices.length > 1;
      debugPrint('[WebRTCService] 检测到 ${videoDevices.length} 个摄像头设备，支持切换: $canSwitch');
      return canSwitch;
    } catch (e) {
      debugPrint('[WebRTCService] 检测摄像头设备失败: $e');
      return false;
    }
  }

  /// 切换摄像头
  Future<void> switchCamera() async {
    if (!isVideo || _localStream == null) {
      debugPrint('[WebRTCService] 无法切换摄像头: isVideo=$isVideo, localStream=${_localStream != null}');
      return;
    }

    // Web 平台检查是否支持切换
    if (kIsWeb && !_canSwitchCamera) {
      debugPrint('[WebRTCService] 当前设备不支持摄像头切换（只有一个摄像头）');
      return;
    }

    try {
      if (kIsWeb) {
        // Web 平台：需要重新获取媒体流
        debugPrint('[WebRTCService] Web 平台切换摄像头开始');
        
        // 获取当前视频轨道
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isEmpty) {
          debugPrint('[WebRTCService] 没有视频轨道');
          return;
        }

        // 切换摄像头方向
        _isFrontCamera = !_isFrontCamera;
        final newFacingMode = _isFrontCamera ? 'user' : 'environment';
        debugPrint('[WebRTCService] 切换到: $newFacingMode');

        // 重新获取媒体流
        final mediaConstraints = <String, dynamic>{
          'audio': false, // 不重新获取音频
          'video': {
            'facingMode': newFacingMode,
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
          },
        };

        MediaStream? newStream;
        try {
          newStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
        } catch (e) {
          debugPrint('[WebRTCService] 获取新媒体流失败: $e');
          // 恢复原来的状态
          _isFrontCamera = !_isFrontCamera;
          return;
        }

        final newVideoTracks = newStream.getVideoTracks();
        if (newVideoTracks.isEmpty) {
          debugPrint('[WebRTCService] 新媒体流没有视频轨道');
          await newStream.dispose();
          _isFrontCamera = !_isFrontCamera;
          return;
        }

        final newVideoTrack = newVideoTracks.first;

        // 替换 PeerConnection 中的视频轨道
        if (_peerConnection != null) {
          try {
            final senders = await _peerConnection!.getSenders();
            bool replaced = false;
            for (var sender in senders) {
              if (sender.track?.kind == 'video') {
                await sender.replaceTrack(newVideoTrack);
                replaced = true;
                debugPrint('[WebRTCService] 已替换 PeerConnection 中的视频轨道');
                break;
              }
            }
            if (!replaced) {
              debugPrint('[WebRTCService] 未找到视频 sender');
            }
          } catch (e) {
            debugPrint('[WebRTCService] 替换视频轨道失败: $e');
            await newStream.dispose();
            _isFrontCamera = !_isFrontCamera;
            return;
          }
        }

        // 停止旧的视频轨道
        for (var track in videoTracks) {
          track.stop();
          _localStream!.removeTrack(track);
        }

        // 添加新的视频轨道
        _localStream!.addTrack(newVideoTrack);

        // 更新渲染器
        localRenderer.srcObject = _localStream;
        
        debugPrint('[WebRTCService] Web 平台摄像头切换完成');
      } else {
        // 移动平台：使用 Helper.switchCamera
        debugPrint('[WebRTCService] 移动平台切换摄像头');
        final videoTrack = _localStream!.getVideoTracks().first;
        await Helper.switchCamera(videoTrack);
        _isFrontCamera = !_isFrontCamera;
        debugPrint('[WebRTCService] 移动平台摄像头切换完成');
      }
      
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('[WebRTCService] 切换摄像头失败: $e');
      debugPrint('[WebRTCService] 堆栈: $stackTrace');
    }
  }

  /// 清理资源
  Future<void> _cleanup() async {
    // 停止所有铃声
    await _ringtoneService.stopAll();

    // 取消超时计时器
    _cancelCallTimeoutTimer();

    _durationTimer?.cancel();
    _durationTimer = null;
    _callDuration = 0;

    await _localStream?.dispose();
    _localStream = null;

    await _remoteStream?.dispose();
    _remoteStream = null;

    await _peerConnection?.close();
    _peerConnection = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    _currentCallId = null;
    _remoteUserId = null;
    _remoteUserName = null;
    _remoteUserAvatar = null;
    _pendingRemoteSdp = null;
    _pendingCandidates.clear();
    _remoteDescriptionSet = false;
    _isMuted = false;
    _isSpeakerOn = false;
    _isVideoEnabled = true;
    _isFrontCamera = true;

    _callState = CallState.idle;
    notifyListeners();
  }

  /// 释放资源
  @override
  void dispose() {
    _wsSubscription?.cancel();
    _cleanup();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }

  // 回调函数
  Function(String callId, int callerId, String callerName, String callerAvatar, int callType)?
      onIncomingCall;
  Function()? onCallConnected;
  Function(String reason)? onCallEnded;
  Function()? onIncomingCallCancelled; // 来电被取消（主叫方取消）

  /// 格式化通话时长
  String get formattedDuration {
    final minutes = _callDuration ~/ 60;
    final seconds = _callDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
