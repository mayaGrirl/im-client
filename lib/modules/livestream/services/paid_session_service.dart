/// 付费通话服务 (LiveKit SFU 版本)
/// 管理 LiveKit Room 连接、计时计�?
/// 替代原有�?P2P WebRTC 方案
/// 
/// 注意：付费通话始终使用LiveKit (WebRTC SFU)，不�?stream_mode 配置影响

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:im_client/services/websocket_service.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/modules/livestream/api/livestream_api.dart';

class PaidSessionService extends ChangeNotifier {
  final int livestreamId;
  final int localUserId;
  final LivestreamApi _api = LivestreamApi(ApiClient());
  bool _isDisposed = false;

  // LiveKit Room
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;

  // 状�?
  bool _isActive = false;
  bool get isActive => _isActive;
  int _sessionId = 0;
  int get sessionId => _sessionId;
  int _remoteUserId = 0;
  int _sessionType = 3; // 2=voice, 3=video

  int get sessionType => _sessionType;

  // LiveKit URL
  String _livekitUrl = '';

  // 参与�?
  LocalParticipant? get localParticipant => _room?.localParticipant;
  List<RemoteParticipant> get remoteParticipants =>
      _room?.remoteParticipants.values.toList() ?? [];

  // 计时
  Timer? _timer;
  int _elapsedSeconds = 0;
  int get elapsedSeconds => _elapsedSeconds;
  int _ratePerMinute = 0;
  int get ratePerMinute => _ratePerMinute;
  int get currentCost => (_elapsedSeconds ~/ 60 + 1) * _ratePerMinute;

  // 观众余额(从服务器charge通知更新)
  int _viewerBalance = 0;
  int get viewerBalance => _viewerBalance;

  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  PaidSessionService({required this.livestreamId, required this.localUserId}) {
    _setupWebSocketListener();
  }

  void _setupWebSocketListener() {
    _wsSubscription = WebSocketService().messageStream.listen((message) {
      final type = message['type'] as String?;
      final data = message['data'] as Map<String, dynamic>? ?? {};

      switch (type) {
        case 'livestream_paid_call_token':
          final lsId = (data['livestream_id'] as num?)?.toInt() ?? 0;
          if (lsId == livestreamId) {
            _handleToken(data);
          }
          break;
        case 'livestream_paid_call_accept':
          final sid = (data['session_id'] as num?)?.toInt() ?? 0;
          if (sid == _sessionId) {
            onPaidCallAccepted(data);
          }
          break;
        case 'livestream_paid_call_reject':
          final sid = (data['session_id'] as num?)?.toInt() ?? 0;
          if (sid == _sessionId) {
            onPaidCallRejected();
          }
          break;
        case 'livestream_paid_call_end':
          final sid = (data['session_id'] as num?)?.toInt() ?? 0;
          if (sid == _sessionId) {
            onPaidCallEnded(data);
          }
          break;
        case 'livestream_paid_call_charge':
          final sid = (data['session_id'] as num?)?.toInt() ?? 0;
          if (sid == _sessionId) {
            onChargeUpdate(data);
          }
          break;
      }
    });
  }

  /// 处理 LiveKit token
  Future<void> _handleToken(Map<String, dynamic> data) async {
    final token = data['token'] as String? ?? '';
    _livekitUrl = data['livekit_url'] as String? ?? '';
    final sid = (data['session_id'] as num?)?.toInt() ?? 0;

    if (token.isEmpty || _livekitUrl.isEmpty) return;

    _sessionId = sid;
    await _connectRoom(token);
  }

  /// 连接 LiveKit Room
  Future<void> _connectRoom(String token) async {
    try {
      _room = Room();

      _roomListener = _room!.createListener();
      _roomListener!
        ..on<TrackSubscribedEvent>((event) {
          notifyListeners();
        })
        ..on<TrackUnsubscribedEvent>((event) {
          notifyListeners();
        })
        ..on<ParticipantConnectedEvent>((event) {
          notifyListeners();
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          // 对方断开 �?结束通话
          if (_room?.remoteParticipants.isEmpty ?? true) {
            endPaidCall();
          }
        })
        ..on<RoomDisconnectedEvent>((event) {
          _cleanup();
        });

      await _room!.connect(
        _livekitUrl,
        token,
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: const AudioPublishOptions(
            encoding: AudioEncoding.presetSpeech,
          ),
          defaultVideoPublishOptions: const VideoPublishOptions(
            videoEncoding: VideoEncoding(maxBitrate: 1500000, maxFramerate: 30),
          ),
        ),
      );

      // 开启本地音视频
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      if (_sessionType == 3) {
        await _room!.localParticipant?.setCameraEnabled(true);
      }

      _isActive = true;
      _startTimer();
      notifyListeners();
    } catch (e) {
      debugPrint('[PaidCall] connect LiveKit error: $e');
    }
  }

  /// 申请付费通话（观众侧�?
  Future<bool> requestPaidSession({int sessionType = 3, int ratePerMinute = 100}) async {
    try {
      final res = await _api.applyPaidCall(
        livestreamId,
        sessionType: sessionType,
        ratePerMinute: ratePerMinute,
      );
      if (res.isSuccess && res.data != null) {
        _sessionId = (res.data['id'] as num?)?.toInt() ?? 0;
        _sessionType = sessionType;
        _ratePerMinute = ratePerMinute;
        return true;
      }
    } catch (e) {
      debugPrint('Request paid call error: $e');
    }
    return false;
  }

  /// 接受付费通话（主播侧�?
  Future<bool> acceptPaidSession(int sid, int viewerId, {int sessionType = 3, int rate = 100}) async {
    try {
      final res = await _api.acceptPaidCall(livestreamId, sessionId: sid);
      if (!res.isSuccess) {
        debugPrint('Accept paid call API failed: ${res.message}');
        return false;
      }
      _sessionId = sid;
      _remoteUserId = viewerId;
      _sessionType = sessionType;
      _ratePerMinute = rate;
      // Token 将通过 WS 推送，_handleToken 会自动连�?
      return true;
    } catch (e) {
      debugPrint('Accept paid call error: $e');
    }
    return false;
  }

  /// 拒绝付费通话（主播侧�?
  Future<bool> rejectPaidSession(int sid) async {
    try {
      final res = await _api.rejectPaidCall(livestreamId, sessionId: sid);
      return res.isSuccess;
    } catch (e) {
      debugPrint('Reject paid call error: $e');
      return false;
    }
  }

  /// 付费通话被接受（观众侧回调）
  void onPaidCallAccepted(Map<String, dynamic> data) {
    _sessionType = (data['session_type'] as num?)?.toInt() ?? _sessionType;
    // Token 将通过 WS 推送，_handleToken 会自动连�?
    notifyListeners();
  }

  /// 付费通话被拒绝（观众侧回调）
  void onPaidCallRejected() {
    _sessionId = 0;
    notifyListeners();
  }

  /// 结束付费通话
  Future<void> endPaidCall() async {
    try {
      if (_sessionId > 0) {
        await _api.endPaidCall(livestreamId, sessionId: _sessionId);
      }
    } catch (e) {
      debugPrint('End paid call error: $e');
    }
    await _cleanup();
  }

  // Legacy compat
  Future<void> endPaidSession() => endPaidCall();

  /// 远端结束
  void onPaidCallEnded(Map<String, dynamic> data) {
    _cleanup();
  }

  // Legacy compat
  void onPaidSessionEnded() => _cleanup();

  /// 收到扣费通知
  void onChargeUpdate(Map<String, dynamic> data) {
    final totalMinutes = (data['total_minutes'] as num?)?.toInt() ?? 0;
    _viewerBalance = (data['viewer_balance'] as num?)?.toInt() ?? 0;
    _elapsedSeconds = totalMinutes * 60;
    notifyListeners();
  }

  /// 切换麦克�?
  Future<void> toggleMicrophone() async {
    if (_room?.localParticipant == null) return;
    final enabled = _room!.localParticipant!.isMicrophoneEnabled();
    await _room!.localParticipant!.setMicrophoneEnabled(!enabled);
    notifyListeners();
  }

  /// 切换摄像�?
  Future<void> toggleCamera() async {
    if (_room?.localParticipant == null) return;
    final enabled = _room!.localParticipant!.isCameraEnabled();
    await _room!.localParticipant!.setCameraEnabled(!enabled);
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _elapsedSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
  }

  Future<void> _cleanup() async {
    _timer?.cancel();
    _roomListener?.dispose();
    _roomListener = null;
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
    _isActive = false;
    _sessionId = 0;
    _remoteUserId = 0;
    _elapsedSeconds = 0;
    _viewerBalance = 0;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _wsSubscription?.cancel();
    super.dispose();
  }
}
