// Group Call Service - handles multi-party WebRTC calls
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/api/call_api.dart';
import 'package:im_client/services/websocket_service.dart';
import 'package:im_client/services/call_ringtone_service.dart';
import 'package:im_client/utils/audio_manager.dart';

/// Group call participant with stream
class GroupCallParticipantWithStream {
  final int userId;
  final String nickname;
  final String avatar;
  bool isMuted;
  bool isVideoOff;
  MediaStream? stream;
  RTCPeerConnection? peerConnection;
  RTCVideoRenderer? renderer;

  GroupCallParticipantWithStream({
    required this.userId,
    required this.nickname,
    required this.avatar,
    this.isMuted = false,
    this.isVideoOff = false,
    this.stream,
    this.peerConnection,
    this.renderer,
  });

  Future<void> initRenderer() async {
    renderer ??= RTCVideoRenderer();
    await renderer!.initialize();
  }

  Future<void> disposeRenderer() async {
    renderer?.srcObject = null;
    await renderer?.dispose();
    renderer = null;
  }
}

/// Group call event types
enum GroupCallEventType {
  participantJoined,
  participantLeft,
  participantMuted,
  participantUnmuted,
  participantVideoOn,
  participantVideoOff,
  callEnded,
  callError,
  connectionStateChanged,
}

/// Group call event
class GroupCallEvent {
  final GroupCallEventType type;
  final int? userId;
  final String? message;
  final dynamic data;

  GroupCallEvent({
    required this.type,
    this.userId,
    this.message,
    this.data,
  });
}

/// Group Call Service
class GroupCallService extends ChangeNotifier {
  static final GroupCallService _instance = GroupCallService._internal();
  factory GroupCallService() => _instance;
  GroupCallService._internal();

  final GroupApi _groupApi = GroupApi(ApiClient());
  final CallApi _callApi = CallApi(ApiClient());
  final CallRingtoneService _ringtoneService = CallRingtoneService();

  // Current user ID
  int? _currentUserId;

  // WebRTC related
  MediaStream? _localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();

  // Participant connections (mesh topology)
  final Map<int, GroupCallParticipantWithStream> _participants = {};
  Map<int, GroupCallParticipantWithStream> get participants => Map.unmodifiable(_participants);

  // Call state
  bool _isInCall = false;
  bool get isInCall => _isInCall;

  int? _currentCallId;
  int? get currentCallId => _currentCallId;

  int? _currentGroupId;
  int? get currentGroupId => _currentGroupId;

  int _callType = 1; // 1=voice, 2=video
  int get callType => _callType;
  bool get isVideo => _callType == 2;

  // Call duration
  int _callDuration = 0;
  int get callDuration => _callDuration;
  Timer? _durationTimer;

  // Audio/video control
  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isCameraOff = false;
  bool get isCameraOff => _isCameraOff;

  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  bool _isFrontCamera = true;
  bool get isFrontCamera => _isFrontCamera;

  // ICE servers
  List<Map<String, dynamic>> _iceServers = [
    {
      'urls': ['stun:stun.l.google.com:19302']
    }
  ];

  // WebSocket subscription
  StreamSubscription? _wsSubscription;

  // Event stream controller
  final StreamController<GroupCallEvent> _eventController = StreamController<GroupCallEvent>.broadcast();
  Stream<GroupCallEvent> get eventStream => _eventController.stream;

  // Initialization state
  bool _isInitialized = false;

  // Cleanup state to prevent reentrant cleanup
  bool _isCleaningUp = false;

  // Lock for participant operations to prevent race conditions
  final Set<int> _pendingParticipantOperations = {};

  // Pending signals buffer: signals received before peer connection is ready
  final Map<int, List<Map<String, dynamic>>> _pendingSignals = {};

  // Call start time for accurate duration calculation
  DateTime? _callStartTime;

  /// Set current user ID
  void setCurrentUserId(int userId) {
    _currentUserId = userId;
  }

  /// Initialize service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await localRenderer.initialize();
      await _ringtoneService.init();
      await _loadIceServers();

      // Listen to WebSocket messages
      await _wsSubscription?.cancel();
      _wsSubscription = WebSocketService().messageStream.listen(_handleWebSocketMessage);

      _isInitialized = true;
      debugPrint('[GroupCallService] Initialized');
    } catch (e) {
      debugPrint('[GroupCallService] Init failed: $e');
      rethrow;
    }
  }

  /// Reset service state
  Future<void> reset() async {
    debugPrint('[GroupCallService] Resetting...');
    await _cleanup();
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    _isInitialized = false;
    _currentUserId = null;
    debugPrint('[GroupCallService] Reset complete');
  }

  /// Load ICE server configuration
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
      debugPrint('[GroupCallService] Failed to load ICE servers: $e');
    }
  }

  /// 安全地将值转换为int
  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Handle WebSocket messages
  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    final data = message['data'] as Map<String, dynamic>?;
    // group_id is at message level, not inside data
    final msgGroupId = _toInt(message['group_id']);

    debugPrint('[GroupCallService] WebSocket message: type=$type, msgGroupId=$msgGroupId');

    if (data == null) {
      debugPrint('[GroupCallService] data is null, ignoring');
      return;
    }

    if (type == 'group_call') {
      final action = data['action'] as String?;
      final callId = _toInt(data['call_id']);
      // Also check for group_id inside data as fallback
      final groupId = _toInt(data['group_id']) ?? msgGroupId;

      debugPrint('[GroupCallService] group_call: action=$action, callId=$callId, groupId=$groupId');
      debugPrint('[GroupCallService] current: _currentCallId=$_currentCallId, _currentGroupId=$_currentGroupId, isInCall=$_isInCall');

      // For 'initiated', always process (to show notification)
      // For other actions, only process if we're in a call and it matches our call/group
      if (action != 'initiated') {
        if (!_isInCall) {
          debugPrint('[GroupCallService] Not in call, ignoring $action');
          return;
        }
        // Check by either call ID or group ID matching
        final callMatches = _currentCallId != null && callId == _currentCallId;
        final groupMatches = _currentGroupId != null && (groupId == _currentGroupId || msgGroupId == _currentGroupId);
        if (!callMatches && !groupMatches) {
          debugPrint('[GroupCallService] Call/Group mismatch (call: $callId vs $_currentCallId, group: $groupId/$msgGroupId vs $_currentGroupId), ignoring');
          return;
        }
        debugPrint('[GroupCallService] Message matches current call/group, processing');
      }

      switch (action) {
        case 'initiated':
          _handleCallInitiated(data);
          break;
        case 'joined':
          _handleParticipantJoined(data);
          break;
        case 'left':
          _handleParticipantLeft(data);
          break;
        case 'ended':
        case 'timeout_ended':
        case 'timeout_cancelled':
          _handleCallEnded(data);
          break;
        case 'state_changed':
          _handleStateChanged(data);
          break;
        default:
          debugPrint('[GroupCallService] Unknown action: $action');
      }
    } else if (type == 'group_call_signal') {
      _handleSignaling(data);
    }
  }

  /// Handle call initiated
  void _handleCallInitiated(Map<String, dynamic> data) {
    // Notification will be handled by the chat screen
    debugPrint('[GroupCallService] Call initiated: ${data['call_id']}');
  }

  /// Handle participant joined
  void _handleParticipantJoined(Map<String, dynamic> data) async {
    final userId = _toInt(data['user_id']);
    final user = data['user'] as Map<String, dynamic>?;

    debugPrint('[GroupCallService] _handleParticipantJoined: userId=$userId, _currentUserId=$_currentUserId');

    // 有人加入通话，无论是谁都先停止去电等待音
    debugPrint('[GroupCallService] Stopping dialing tone...');
    await _ringtoneService.stopDialingTone();

    if (userId == null) {
      debugPrint('[GroupCallService] userId is null, skipping participant add');
      return;
    }

    if (userId == _currentUserId) {
      debugPrint('[GroupCallService] This is current user joining, skipping participant add');
      return;
    }

    // Prevent race condition: check if already processing this participant
    if (_pendingParticipantOperations.contains(userId)) {
      debugPrint('[GroupCallService] Already processing participant $userId, skipping');
      return;
    }

    // Also skip if participant already exists
    if (_participants.containsKey(userId)) {
      debugPrint('[GroupCallService] Participant $userId already exists, skipping');
      return;
    }

    debugPrint('[GroupCallService] Adding participant: $userId');

    // Mark as processing to prevent parallel creation
    _pendingParticipantOperations.add(userId);

    try {
      // Create peer connection for new participant
      await _createPeerConnectionForParticipant(
        userId: userId,
        nickname: user?['nickname'] ?? 'User $userId',
        avatar: user?['avatar'] ?? '',
      );

      debugPrint('[GroupCallService] Participant added, total: ${_participants.length}');

      _eventController.add(GroupCallEvent(
        type: GroupCallEventType.participantJoined,
        userId: userId,
      ));
      notifyListeners();
    } catch (e) {
      debugPrint('[GroupCallService] Failed to add participant $userId: $e');
    } finally {
      _pendingParticipantOperations.remove(userId);
    }
  }

  /// Handle participant left
  void _handleParticipantLeft(Map<String, dynamic> data) async {
    final userId = _toInt(data['user_id']);
    final callEnded = data['ended'] as bool? ?? false;

    if (userId == null) return;

    debugPrint('[GroupCallService] Participant left: $userId, call ended: $callEnded, _isInCall=$_isInCall');

    // Clean up peer connection and pending signals
    _pendingSignals.remove(userId);
    final participant = _participants.remove(userId);
    if (participant != null) {
      await participant.peerConnection?.close();
      await participant.disposeRenderer();
    }

    _eventController.add(GroupCallEvent(
      type: GroupCallEventType.participantLeft,
      userId: userId,
    ));

    if (callEnded) {
      await _cleanup();
      _eventController.add(GroupCallEvent(
        type: GroupCallEventType.callEnded,
        data: data['duration'],
      ));
    }

    notifyListeners();
  }

  /// Handle call ended
  void _handleCallEnded(Map<String, dynamic> data) async {
    debugPrint('[GroupCallService] Call ended');

    final duration = data['duration'] as int?;

    await _cleanup();

    _eventController.add(GroupCallEvent(
      type: GroupCallEventType.callEnded,
      data: duration,
    ));
    notifyListeners();
  }

  /// Handle state changed (mute/camera)
  void _handleStateChanged(Map<String, dynamic> data) {
    final userId = _toInt(data['user_id']);
    final isMuted = data['is_muted'] as bool?;
    final isVideoOff = data['is_video_off'] as bool?;

    if (userId == null) return;

    final participant = _participants[userId];
    if (participant != null) {
      if (isMuted != null) {
        participant.isMuted = isMuted;
        _eventController.add(GroupCallEvent(
          type: isMuted ? GroupCallEventType.participantMuted : GroupCallEventType.participantUnmuted,
          userId: userId,
        ));
      }
      if (isVideoOff != null) {
        participant.isVideoOff = isVideoOff;
        _eventController.add(GroupCallEvent(
          type: isVideoOff ? GroupCallEventType.participantVideoOff : GroupCallEventType.participantVideoOn,
          userId: userId,
        ));
      }
      notifyListeners();
    }
  }

  /// Handle WebRTC signaling
  void _handleSignaling(Map<String, dynamic> data) async {
    final fromUserId = _toInt(data['from_user_id']);
    final signalType = data['signal_type'] as String?;
    final signalData = data['signal_data'] as String?;

    if (fromUserId == null || signalType == null || signalData == null) return;

    // If participant doesn't exist yet, buffer the signal for later processing
    if (!_participants.containsKey(fromUserId)) {
      debugPrint('[GroupCallService] Buffering $signalType from $fromUserId (participant not ready yet)');
      _pendingSignals.putIfAbsent(fromUserId, () => []);
      _pendingSignals[fromUserId]!.add(data);
      return;
    }

    try {
      final parsed = jsonDecode(signalData) as Map<String, dynamic>;
      final participant = _participants[fromUserId];

      switch (signalType) {
        case 'offer':
          await _handleOffer(fromUserId, parsed);
          break;
        case 'answer':
          if (participant?.peerConnection != null) {
            final answer = RTCSessionDescription(parsed['sdp'], 'answer');
            await participant!.peerConnection!.setRemoteDescription(answer);
          }
          break;
        case 'candidate':
          if (participant?.peerConnection != null) {
            final candidate = RTCIceCandidate(
              parsed['candidate'],
              parsed['sdp_mid'],
              parsed['sdp_mline_index'],
            );
            await participant!.peerConnection!.addCandidate(candidate);
          }
          break;
      }
    } catch (e) {
      debugPrint('[GroupCallService] Failed to handle signaling: $e');
    }
  }

  /// Handle incoming offer
  Future<void> _handleOffer(int fromUserId, Map<String, dynamic> data) async {
    final participant = _participants[fromUserId];
    if (participant?.peerConnection == null) return;

    final offer = RTCSessionDescription(data['sdp'], 'offer');
    await participant!.peerConnection!.setRemoteDescription(offer);

    final answer = await participant.peerConnection!.createAnswer();
    await participant.peerConnection!.setLocalDescription(answer);

    // Send answer back
    await _sendSignal(
      toUserId: fromUserId,
      signalType: 'answer',
      signalData: jsonEncode({
        'sdp': answer.sdp,
        'type': answer.type,
      }),
    );
  }

  /// Process buffered signals for a participant whose peer connection is now ready
  void _processPendingSignals(int userId) {
    final pending = _pendingSignals.remove(userId);
    if (pending != null && pending.isNotEmpty) {
      debugPrint('[GroupCallService] Processing ${pending.length} pending signals for $userId');
      for (final signal in pending) {
        _handleSignaling(signal);
      }
    }
  }

  /// Send WebRTC signal
  Future<void> _sendSignal({
    required int toUserId,
    required String signalType,
    required String signalData,
  }) async {
    if (_currentCallId == null || _currentGroupId == null) return;

    // Send via WebSocket
    WebSocketService().send({
      'type': 'group_call_signal',
      'data': {
        'call_id': _currentCallId,
        'group_id': _currentGroupId,
        'to_user_id': toUserId,
        'signal_type': signalType,
        'signal_data': signalData,
      },
    });
  }

  /// Initiate a group call
  /// 返回 (成功, 错误信息) - 成功时错误信息为null
  Future<(bool, String?)> initiateCall(int groupId, int callType) async {
    if (_isInCall) {
      debugPrint('[GroupCallService] Already in a call');
      return (false, '您已在通话中');
    }

    try {
      _callType = callType;
      _currentGroupId = groupId;

      // Initialize local stream
      await _createLocalStream();

      // Call API to initiate
      final (call, errorMsg) = await _groupApi.initiateGroupCall(groupId, callType: callType);
      if (call == null) {
        await _cleanup();
        return (false, errorMsg ?? '发起群通话失败');
      }

      _currentCallId = call.id;
      _isInCall = true;
      _startDurationTimer();

      // 播放去电等待音（发起者等待其他人加入）
      if (_currentUserId != null) {
        _ringtoneService.playDialingTone(groupId, _currentUserId!);
      }

      notifyListeners();

      debugPrint('[GroupCallService] Call initiated: ${call.id}');
      return (true, null);
    } catch (e) {
      debugPrint('[GroupCallService] Failed to initiate call: $e');
      await _cleanup();
      return (false, '发起群通话失败: $e');
    }
  }

  /// Join an existing group call
  Future<bool> joinCall(int groupId, int callId, int callType) async {
    if (_isInCall) {
      debugPrint('[GroupCallService] Already in a call');
      return false;
    }

    try {
      _callType = callType;
      _currentGroupId = groupId;
      _currentCallId = callId;

      // Initialize local stream
      await _createLocalStream();

      // Call API to join
      final result = await _groupApi.joinGroupCall(groupId, callId);
      if (!result.success) {
        await _cleanup();
        return false;
      }

      _isInCall = true;
      _startDurationTimer();

      // Get current participants and create connections
      final participants = await _groupApi.getGroupCallParticipants(groupId, callId);
      if (participants != null) {
        for (final p in participants) {
          if (p.userId != _currentUserId && p.isInCall) {
            await _createPeerConnectionForParticipant(
              userId: p.userId,
              nickname: p.user?.nickname ?? 'User ${p.userId}',
              avatar: p.user?.avatar ?? '',
              isInitiator: true,
            );
          }
        }
      }

      notifyListeners();
      debugPrint('[GroupCallService] Joined call: $callId');
      return true;
    } catch (e) {
      debugPrint('[GroupCallService] Failed to join call: $e');
      await _cleanup();
      return false;
    }
  }

  /// Leave the current call
  Future<void> leaveCall() async {
    if (!_isInCall || _currentGroupId == null || _currentCallId == null) return;

    try {
      await _groupApi.leaveGroupCall(_currentGroupId!, _currentCallId!);
    } catch (e) {
      debugPrint('[GroupCallService] Failed to leave call: $e');
    }

    await _cleanup();
    notifyListeners();
  }

  /// End the call (for initiator/admin)
  Future<void> endCall() async {
    if (!_isInCall || _currentGroupId == null || _currentCallId == null) return;

    try {
      await _groupApi.endGroupCall(_currentGroupId!, _currentCallId!);
    } catch (e) {
      debugPrint('[GroupCallService] Failed to end call: $e');
    }

    await _cleanup();
    notifyListeners();
  }

  /// Create local media stream
  Future<void> _createLocalStream() async {
    if (isVideo) {
      // 视频通话：先尝试获取音视频，失败则降级为纯音频
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 640},
            'height': {'ideal': 480},
          },
        });
      } catch (e) {
        debugPrint('[GroupCallService] 摄像头不可用，降级为纯音频: $e');
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });
        _isCameraOff = true;
      }
    } else {
      // 语音通话：只需音频
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
    }
    localRenderer.srcObject = _localStream;
    
    // 媒体流创建后立即初始化扬声器状态
    // 视频通话默认开启扬声器，语音通话默认关闭
    // Web 平台不支持扬声器切换
    if (!kIsWeb) {
      _isSpeakerOn = isVideo;
      try {
        await AudioManager.setSpeakerphoneOn(_isSpeakerOn);
        debugPrint('[GroupCallService] 扬声器初始化: ${_isSpeakerOn ? "开启" : "关闭"}');
      } catch (e) {
        debugPrint('[GroupCallService] 扬声器初始化失败: $e');
      }
    }
  }

  /// Create peer connection for a participant
  Future<void> _createPeerConnectionForParticipant({
    required int userId,
    required String nickname,
    required String avatar,
    bool isInitiator = false,
  }) async {
    // Double-check in case state changed during async operations
    if (_participants.containsKey(userId)) {
      debugPrint('[GroupCallService] Participant $userId already exists (double-check), skipping');
      return;
    }

    // Check if we're still in a call
    if (!_isInCall || _isCleaningUp) {
      debugPrint('[GroupCallService] Not in call or cleaning up, skipping peer connection creation');
      return;
    }

    final configuration = <String, dynamic>{
      'iceServers': _iceServers,
    };

    late final RTCPeerConnection pc;
    try {
      pc = await createPeerConnection(configuration);
    } catch (e) {
      debugPrint('[GroupCallService] Failed to create peer connection for $userId: $e');
      rethrow;
    }

    final participant = GroupCallParticipantWithStream(
      userId: userId,
      nickname: nickname,
      avatar: avatar,
      peerConnection: pc,
    );
    await participant.initRenderer();

    // Add local tracks
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        pc.addTrack(track, _localStream!);
      }
    }

    // Listen for remote tracks
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        participant.stream = event.streams[0];
        participant.renderer?.srcObject = event.streams[0];
        notifyListeners();
      }
    };

    // ICE candidates
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _sendSignal(
        toUserId: userId,
        signalType: 'candidate',
        signalData: jsonEncode({
          'candidate': candidate.candidate,
          'sdp_mid': candidate.sdpMid,
          'sdp_mline_index': candidate.sdpMLineIndex,
        }),
      );
    };

    // Connection state
    pc.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[GroupCallService] Connection state with $userId: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        // Only handle failed state, not disconnected (which can be temporary)
        debugPrint('[GroupCallService] Connection failed with $userId, removing participant');
        _handleParticipantLeft({'user_id': userId, 'ended': false});
      }
    };

    // Final check before adding to map (in case cleanup started during setup)
    if (_isCleaningUp) {
      debugPrint('[GroupCallService] Cleanup started during setup, disposing new connection');
      await pc.close();
      await participant.disposeRenderer();
      return;
    }

    _participants[userId] = participant;

    // Process any buffered signals for this participant
    _processPendingSignals(userId);

    // If we're the initiator, create and send offer
    if (isInitiator) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      await _sendSignal(
        toUserId: userId,
        signalType: 'offer',
        signalData: jsonEncode({
          'sdp': offer.sdp,
          'type': offer.type,
        }),
      );
    }
  }

  /// Toggle mute
  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });

    // Notify other participants
    _broadcastStateChange();
    notifyListeners();
  }

  /// Toggle camera
  void toggleCamera() {
    if (!isVideo) return;

    _isCameraOff = !_isCameraOff;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !_isCameraOff;
    });

    // Notify other participants
    _broadcastStateChange();
    notifyListeners();
  }

  /// Toggle speaker
  Future<void> toggleSpeaker() async {
    // Web 平台不支持扬声器切换
    if (kIsWeb) {
      debugPrint('[GroupCallService] Web 平台不支持扬声器切换');
      return;
    }
    
    _isSpeakerOn = !_isSpeakerOn;
    try {
      await AudioManager.setSpeakerphoneOn(_isSpeakerOn);
      // 添加短暂延迟确保音频路由切换完成
      await Future.delayed(const Duration(milliseconds: 100));
      debugPrint('[GroupCallService] 扬声器已${_isSpeakerOn ? "开启" : "关闭"}');
    } catch (e) {
      debugPrint('[GroupCallService] Failed to toggle speaker: $e');
      // 如果切换失败，恢复状态
      _isSpeakerOn = !_isSpeakerOn;
    }
    notifyListeners();
  }

  /// Switch camera
  Future<void> switchCamera() async {
    if (!isVideo || _localStream == null) return;

    try {
      if (kIsWeb) {
        // Web 平台：需要重新获取媒体流
        debugPrint('[GroupCallService] Web 平台切换摄像头');
        
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isEmpty) return;

        _isFrontCamera = !_isFrontCamera;
        final newFacingMode = _isFrontCamera ? 'user' : 'environment';

        final newStream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {
            'facingMode': newFacingMode,
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
          },
        });

        final newVideoTrack = newStream.getVideoTracks().first;

        // 替换所有 PeerConnection 中的视频轨道
        for (var participant in _participants.values) {
          if (participant.peerConnection != null) {
            final senders = await participant.peerConnection!.getSenders();
            for (var sender in senders) {
              if (sender.track?.kind == 'video') {
                await sender.replaceTrack(newVideoTrack);
              }
            }
          }
        }

        // 停止旧轨道并更新本地流
        for (var track in videoTracks) {
          track.stop();
          _localStream!.removeTrack(track);
        }
        _localStream!.addTrack(newVideoTrack);
        localRenderer.srcObject = _localStream;
        
        debugPrint('[GroupCallService] Web 平台摄像头切换完成');
      } else {
        // 移动平台：使用 Helper.switchCamera
        final videoTrack = _localStream!.getVideoTracks().first;
        await Helper.switchCamera(videoTrack);
        _isFrontCamera = !_isFrontCamera;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[GroupCallService] 切换摄像头失败: $e');
    }
  }

  /// Broadcast state change to other participants
  void _broadcastStateChange() {
    if (_currentGroupId == null || _currentCallId == null) return;

    WebSocketService().send({
      'type': 'group_call',
      'data': {
        'action': 'state_changed',
        'call_id': _currentCallId,
        'group_id': _currentGroupId,
        'user_id': _currentUserId,
        'is_muted': _isMuted,
        'is_video_off': _isCameraOff,
      },
    });
  }

  /// Start duration timer
  void _startDurationTimer() {
    _callDuration = 0;
    _callStartTime = DateTime.now();
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Use actual elapsed time for accuracy instead of incrementing
      if (_callStartTime != null) {
        _callDuration = DateTime.now().difference(_callStartTime!).inSeconds;
      } else {
        _callDuration++;
      }
      notifyListeners();
    });
  }

  /// Cleanup resources
  Future<void> _cleanup() async {
    // Prevent reentrant cleanup
    if (_isCleaningUp) {
      debugPrint('[GroupCallService] Cleanup already in progress, skipping');
      return;
    }
    _isCleaningUp = true;

    try {
      debugPrint('[GroupCallService] Starting cleanup...');

      // 停止所有铃声
      await _ringtoneService.stopAll();

      _durationTimer?.cancel();
      _durationTimer = null;
      _callDuration = 0;
      _callStartTime = null;

      // Clear pending operations and buffered signals
      _pendingParticipantOperations.clear();
      _pendingSignals.clear();

      // Dispose all participant connections
      for (final participant in _participants.values) {
        try {
          await participant.peerConnection?.close();
          await participant.disposeRenderer();
        } catch (e) {
          debugPrint('[GroupCallService] Error disposing participant ${participant.userId}: $e');
        }
      }
      _participants.clear();

      // Dispose local stream
      try {
        await _localStream?.dispose();
      } catch (e) {
        debugPrint('[GroupCallService] Error disposing local stream: $e');
      }
      _localStream = null;
      localRenderer.srcObject = null;

      _currentCallId = null;
      _currentGroupId = null;
      _isInCall = false;
      _isMuted = false;
      _isCameraOff = false;
      _isSpeakerOn = false;
      _isFrontCamera = true;

      debugPrint('[GroupCallService] Cleanup complete');
    } finally {
      _isCleaningUp = false;
    }
  }

  /// 播放来电铃声（收到群通话邀请时）
  Future<void> playIncomingRingtone(int groupId) async {
    if (_currentUserId != null) {
      await _ringtoneService.playIncomingRingtone(groupId, _currentUserId!);
    }
  }

  /// 停止来电铃声
  Future<void> stopIncomingRingtone() async {
    await _ringtoneService.stopIncomingRingtone();
  }

  /// 停止去电等待音
  Future<void> stopDialingTone() async {
    await _ringtoneService.stopDialingTone();
  }

  /// Get formatted duration
  String get formattedDuration {
    final minutes = _callDuration ~/ 60;
    final seconds = _callDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Dispose
  @override
  void dispose() {
    _wsSubscription?.cancel();
    _eventController.close();
    _cleanup();
    localRenderer.dispose();
    super.dispose();
  }
}
