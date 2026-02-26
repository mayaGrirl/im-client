// Group Call Provider - State management for group calls
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/services/group_call_service.dart';
import 'package:im_client/services/websocket_service.dart';

/// Group call state
enum GroupCallState {
  idle,       // Not in a call
  initiating, // Initiating a call
  joining,    // Joining a call
  inCall,     // In an active call
  ending,     // Ending the call
}

/// Incoming call notification
class IncomingGroupCall {
  final int callId;
  final int groupId;
  final int callType;
  final int initiatorId;
  final String initiatorName;
  final String initiatorAvatar;
  final String groupName;
  final DateTime createdAt;

  IncomingGroupCall({
    required this.callId,
    required this.groupId,
    required this.callType,
    required this.initiatorId,
    required this.initiatorName,
    required this.initiatorAvatar,
    required this.groupName,
    required this.createdAt,
  });

  bool get isVideo => callType == 2;
  bool get isVoice => callType == 1;
}

/// Group Call Provider
class GroupCallProvider extends ChangeNotifier {
  final GroupCallService _service = GroupCallService();
  final GroupApi _groupApi = GroupApi(ApiClient());

  // State
  GroupCallState _state = GroupCallState.idle;
  GroupCallState get state => _state;

  // Current call info
  int? _currentCallId;
  int? get currentCallId => _currentCallId;

  int? _currentGroupId;
  int? get currentGroupId => _currentGroupId;

  int _callType = 1; // 1=voice, 2=video
  int get callType => _callType;
  bool get isVideo => _callType == 2;

  String? _groupName;
  String? get groupName => _groupName;

  // Participants
  List<GroupCallParticipantWithStream> _participants = [];
  List<GroupCallParticipantWithStream> get participants => _participants;

  // Controls
  bool get isMuted => _service.isMuted;
  bool get isCameraOff => _service.isCameraOff;
  bool get isSpeakerOn => _service.isSpeakerOn;

  // Duration
  int get callDuration => _service.callDuration;
  String get formattedDuration => _service.formattedDuration;

  // Incoming call notification
  IncomingGroupCall? _incomingCall;
  IncomingGroupCall? get incomingCall => _incomingCall;

  // Event stream
  final StreamController<GroupCallEvent> _eventController =
      StreamController<GroupCallEvent>.broadcast();
  Stream<GroupCallEvent> get eventStream => _eventController.stream;

  // WebSocket subscription
  StreamSubscription? _wsSubscription;
  StreamSubscription? _serviceSubscription;

  // Periodic refresh timer
  Timer? _refreshTimer;

  // Initialization
  bool _initialized = false;
  int? _currentUserId;

  /// Initialize provider
  Future<void> init(int userId) async {
    if (_initialized && _currentUserId == userId) return;

    _currentUserId = userId;

    await _service.initialize();
    _service.setCurrentUserId(userId);

    // Listen to service events
    _serviceSubscription?.cancel();
    _serviceSubscription = _service.eventStream.listen(_handleServiceEvent);

    // Listen to WebSocket for incoming calls
    _wsSubscription?.cancel();
    _wsSubscription = WebSocketService().messageStream.listen(_handleWebSocketMessage);

    // Listen to service changes
    _service.addListener(_onServiceChanged);

    _initialized = true;
    debugPrint('[GroupCallProvider] Initialized for user $userId');
  }

  /// Reset provider
  Future<void> reset() async {
    debugPrint('[GroupCallProvider] Resetting...');

    _stopPeriodicRefresh();

    _wsSubscription?.cancel();
    _wsSubscription = null;

    _serviceSubscription?.cancel();
    _serviceSubscription = null;

    _service.removeListener(_onServiceChanged);
    await _service.reset();

    _state = GroupCallState.idle;
    _currentCallId = null;
    _currentGroupId = null;
    _groupName = null;
    _incomingCall = null;
    _participants = [];
    _initialized = false;
    _refreshCompleter = null;
    _lastRefreshTime = null;
    _currentUserId = null;

    notifyListeners();
  }

  /// Handle service state changes
  void _onServiceChanged() {
    _participants = _service.participants.values.toList();

    // Sync state from service
    if (_service.isInCall && _state != GroupCallState.inCall) {
      _state = GroupCallState.inCall;
      _currentCallId = _service.currentCallId;
      _currentGroupId = _service.currentGroupId;
      _callType = _service.callType;
    } else if (!_service.isInCall && _state == GroupCallState.inCall) {
      _state = GroupCallState.idle;
      _currentCallId = null;
      _currentGroupId = null;
    }

    notifyListeners();
  }

  /// Handle service events
  void _handleServiceEvent(GroupCallEvent event) {
    _eventController.add(event);

    switch (event.type) {
      case GroupCallEventType.callEnded:
        _state = GroupCallState.idle;
        _currentCallId = null;
        _currentGroupId = null;
        _groupName = null;
        _participants = [];
        notifyListeners();
        break;
      case GroupCallEventType.participantJoined:
      case GroupCallEventType.participantLeft:
        _participants = _service.participants.values.toList();
        notifyListeners();
        break;
      default:
        break;
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

    if (type != 'group_call' || data == null) return;

    final action = data['action'] as String?;
    final callId = _toInt(data['call_id']);
    // Also check for group_id inside data as fallback
    final groupId = _toInt(data['group_id']) ?? msgGroupId;

    debugPrint('[GroupCallProvider] WebSocket group_call: action=$action, callId=$callId, groupId=$groupId (msgGroupId=$msgGroupId)');
    debugPrint('[GroupCallProvider] Current: _state=$_state, _currentCallId=$_currentCallId, _currentGroupId=$_currentGroupId');

    switch (action) {
      case 'initiated':
        _handleIncomingCall(data);
        break;
      case 'joined':
        // 如果在当前通话中（检查 callId 或 groupId 匹配），刷新参与者列表
        if (_state == GroupCallState.inCall || _state == GroupCallState.initiating) {
          final callMatches = _currentCallId != null && callId == _currentCallId;
          final groupMatches = _currentGroupId != null && groupId == _currentGroupId;
          if (callMatches || groupMatches) {
            debugPrint('[GroupCallProvider] Refreshing participants for joined event');
            _refreshParticipants();
          }
        }
        break;
      case 'left':
        // 检查通话是否已结束（最后一人离开时 ended=true）
        final callEndedByLeave = data['ended'] == true;

        if (_state == GroupCallState.inCall) {
          final callMatches = _currentCallId != null && callId == _currentCallId;
          final groupMatches = _currentGroupId != null && groupId == _currentGroupId;
          if (callMatches || groupMatches) {
            if (callEndedByLeave) {
              // 通话结束，清理状态
              debugPrint('[GroupCallProvider] Call ended by last participant leaving');
              _stopPeriodicRefresh();
              _service.stopDialingTone();
              _state = GroupCallState.idle;
              _currentCallId = null;
              _currentGroupId = null;
              _groupName = null;
              _participants = [];
            } else {
              debugPrint('[GroupCallProvider] Refreshing participants for left event');
              _refreshParticipants();
            }
          }
        }

        // 通话结束时，清除未接起用户的来电通知
        if (callEndedByLeave && _incomingCall != null) {
          final incomingMatches =
              (_incomingCall!.callId > 0 && callId == _incomingCall!.callId) ||
              (_incomingCall!.groupId > 0 && groupId == _incomingCall!.groupId);
          if (incomingMatches) {
            debugPrint('[GroupCallProvider] Call ended, dismissing incoming notification');
            _service.stopIncomingRingtone();
            _incomingCall = null;
          }
        }
        notifyListeners();
        break;
      case 'ended':
      case 'timeout_cancelled':
      case 'timeout_ended':
        // 通话结束（包括正常结束、超时取消、单人超时结束）
        final callMatches = _currentCallId != null && callId == _currentCallId;
        final groupMatches = _currentGroupId != null && groupId == _currentGroupId;
        // 也检查来电通知是否匹配（用户未加入但收到了来电通知）
        final incomingMatches = _incomingCall != null &&
            ((_incomingCall!.callId > 0 && callId == _incomingCall!.callId) ||
             (_incomingCall!.groupId > 0 && groupId == _incomingCall!.groupId));

        if (callMatches || groupMatches || _state == GroupCallState.inCall) {
          debugPrint('[GroupCallProvider] Call ended, cleaning up (in-call user)');
          _stopPeriodicRefresh();
          _service.stopDialingTone(); // 确保停止响铃
          _state = GroupCallState.idle;
          _currentCallId = null;
          _currentGroupId = null;
          _groupName = null;
          _participants = [];
        }
        // 同时清除来电通知（用户未加入但收到了来电通知的情况）
        if (incomingMatches || _incomingCall != null) {
          debugPrint('[GroupCallProvider] Clearing incoming call notification');
          _service.stopIncomingRingtone(); // 停止来电铃声
          _incomingCall = null;
        }
        notifyListeners();
        break;
    }
  }

  // 防抖：防止频繁刷新
  Completer<void>? _refreshCompleter;
  DateTime? _lastRefreshTime;

  /// 刷新参与者列表（带防抖）
  Future<void> _refreshParticipants() async {
    if (_currentGroupId == null || _currentCallId == null) return;
    if (_state != GroupCallState.inCall) return;

    // 防抖：如果正在刷新，等待当前刷新完成
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      debugPrint('[GroupCallProvider] Waiting for ongoing refresh to complete');
      try {
        await _refreshCompleter!.future;
      } catch (_) {}
      return;
    }

    // 防抖：距离上次刷新不足1秒，跳过
    final now = DateTime.now();
    if (_lastRefreshTime != null && now.difference(_lastRefreshTime!).inMilliseconds < 1000) {
      debugPrint('[GroupCallProvider] Skipping refresh: too soon');
      return;
    }

    _refreshCompleter = Completer<void>();
    _lastRefreshTime = now;

    try {
      // 从 API 获取最新参与者列表
      final apiParticipants = await _groupApi.getGroupCallParticipants(
        _currentGroupId!,
        _currentCallId!,
      );

      // 如果返回 null，表示通话不存在（404），停止刷新但不清空
      if (apiParticipants == null) {
        debugPrint('[GroupCallProvider] Call not found (404), using service participants');
        // 使用 service 的参与者列表作为备份
        if (_service.participants.isNotEmpty) {
          _participants = _service.participants.values.toList();
          notifyListeners();
        }
        return;
      }

      // 如果 API 返回空列表但 service 有参与者，使用 service 的数据
      if (apiParticipants.isEmpty && _service.participants.isNotEmpty) {
        debugPrint('[GroupCallProvider] API returned empty, using service participants');
        _participants = _service.participants.values.toList();
        notifyListeners();
        return;
      }

      // 转换 API 数据为 GroupCallParticipantWithStream，并合并 service 中的流数据
      final newParticipants = <GroupCallParticipantWithStream>[];
      for (final p in apiParticipants) {
        // 排除自己
        if (p.userId != _currentUserId && p.isInCall) {
          // 尝试从 service 获取现有的流数据
          final existingParticipant = _service.participants[p.userId];

          newParticipants.add(GroupCallParticipantWithStream(
            userId: p.userId,
            nickname: p.user?.nickname ?? 'User ${p.userId}',
            avatar: p.user?.avatar ?? '',
            isMuted: p.isMuted,
            isVideoOff: p.isVideoOff,
            stream: existingParticipant?.stream,
            peerConnection: existingParticipant?.peerConnection,
            renderer: existingParticipant?.renderer,
          ));
        }
      }

      // 只有当新列表不为空时才更新，或者 service 也没有参与者
      if (newParticipants.isNotEmpty || _service.participants.isEmpty) {
        _participants = newParticipants;
        debugPrint('[GroupCallProvider] Refreshed participants: ${_participants.length}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[GroupCallProvider] Failed to refresh participants: $e');
      // API 出错时不清空列表，保持现有参与者
      _refreshCompleter?.completeError(e);
      _refreshCompleter = null;
      return;
    }

    _refreshCompleter?.complete();
    _refreshCompleter = null;
  }

  /// Handle incoming call notification
  void _handleIncomingCall(Map<String, dynamic> data) {
    final initiatorId = _toInt(data['initiator_id']);

    // Don't notify if we initiated this call
    if (initiatorId == _currentUserId) return;

    // Don't notify if we're already in a call
    if (_state != GroupCallState.idle) return;

    final user = data['user'] as Map<String, dynamic>?;
    final groupId = _toInt(data['group_id']) ?? 0;

    _incomingCall = IncomingGroupCall(
      callId: _toInt(data['call_id']) ?? 0,
      groupId: groupId,
      callType: _toInt(data['call_type']) ?? 1,
      initiatorId: initiatorId ?? 0,
      initiatorName: user?['nickname'] ?? 'Unknown',
      initiatorAvatar: user?['avatar'] ?? '',
      groupName: data['group_name']?.toString() ?? '',
      createdAt: DateTime.now(),
    );

    // 播放来电铃声
    _service.playIncomingRingtone(groupId);

    notifyListeners();
    debugPrint('[GroupCallProvider] Incoming call: ${_incomingCall?.callId}');
  }

  /// Clear incoming call notification
  void clearIncomingCall() {
    // 停止来电铃声
    _service.stopIncomingRingtone();
    _incomingCall = null;
    notifyListeners();
  }

  /// Initiate a group call
  /// 返回 (成功, 错误信息) - 成功时错误信息为null
  Future<(bool, String?)> initiateCall(int groupId, int callType, {String? groupName}) async {
    if (_state != GroupCallState.idle) {
      debugPrint('[GroupCallProvider] Cannot initiate: state is $_state');
      return (false, '您已在通话中');
    }

    _state = GroupCallState.initiating;
    _callType = callType;
    _currentGroupId = groupId;
    _groupName = groupName;
    notifyListeners();

    final (success, errorMsg) = await _service.initiateCall(groupId, callType);

    if (success) {
      _state = GroupCallState.inCall;
      _currentCallId = _service.currentCallId;
      _startPeriodicRefresh();
    } else {
      _state = GroupCallState.idle;
      _currentGroupId = null;
      _groupName = null;
    }

    notifyListeners();
    return (success, errorMsg);
  }

  /// 启动定期刷新参与者（作为备份，主要依靠 WebSocket 更新）
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    // 增加刷新间隔到5秒，减少API调用
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_state == GroupCallState.inCall) {
        _refreshParticipants();
      }
    });
  }

  /// 停止定期刷新
  void _stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Join an existing group call
  Future<bool> joinCall(int groupId, int callId, int callType, {String? groupName}) async {
    if (_state != GroupCallState.idle) {
      debugPrint('[GroupCallProvider] Cannot join: state is $_state');
      return false;
    }

    // 停止来电铃声
    await _service.stopIncomingRingtone();

    _state = GroupCallState.joining;
    _callType = callType;
    _currentGroupId = groupId;
    _currentCallId = callId;
    _groupName = groupName;
    _incomingCall = null; // Clear notification
    notifyListeners();

    final success = await _service.joinCall(groupId, callId, callType);

    if (success) {
      _state = GroupCallState.inCall;
      _startPeriodicRefresh();
      // 立即刷新一次参与者列表
      await _refreshParticipants();
    } else {
      _state = GroupCallState.idle;
      _currentGroupId = null;
      _currentCallId = null;
      _groupName = null;
    }

    notifyListeners();
    return success;
  }

  /// Leave the current call
  Future<void> leaveCall() async {
    if (_state != GroupCallState.inCall) return;

    _state = GroupCallState.ending;
    _stopPeriodicRefresh();
    notifyListeners();

    await _service.leaveCall();

    _state = GroupCallState.idle;
    _currentCallId = null;
    _currentGroupId = null;
    _groupName = null;
    _participants = [];
    notifyListeners();
  }

  /// End the call (for initiator/admin)
  Future<void> endCall() async {
    if (_state != GroupCallState.inCall) return;

    _state = GroupCallState.ending;
    _stopPeriodicRefresh();
    notifyListeners();

    await _service.endCall();

    _state = GroupCallState.idle;
    _currentCallId = null;
    _currentGroupId = null;
    _groupName = null;
    _participants = [];
    notifyListeners();
  }

  /// Toggle mute
  void toggleMute() {
    _service.toggleMute();
    notifyListeners();
  }

  /// Toggle camera
  void toggleCamera() {
    _service.toggleCamera();
    notifyListeners();
  }

  /// Toggle speaker
  Future<void> toggleSpeaker() async {
    await _service.toggleSpeaker();
    notifyListeners();
  }

  /// Switch camera
  Future<void> switchCamera() async {
    await _service.switchCamera();
    notifyListeners();
  }

  /// Get local video renderer
  dynamic get localRenderer => _service.localRenderer;

  /// Check if in call
  bool get isInCall => _state == GroupCallState.inCall;

  /// Check if busy (in any call state)
  bool get isBusy => _state != GroupCallState.idle;

  @override
  void dispose() {
    _stopPeriodicRefresh();
    _wsSubscription?.cancel();
    _serviceSubscription?.cancel();
    _service.removeListener(_onServiceChanged);
    _eventController.close();
    super.dispose();
  }
}
