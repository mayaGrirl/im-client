/// 连麦服务 (LiveKit SFU 版本)
/// 管理 LiveKit Room 连接、音视频轨道、发言人检测
/// 替代原有的 P2P WebRTC mesh 方案

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:im_client/services/websocket_service.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/modules/livestream/api/livestream_api.dart';

class CoHostService extends ChangeNotifier {
  final int livestreamId;
  final int localUserId;
  final LivestreamApi _api = LivestreamApi(ApiClient());
  bool _isDisposed = false;

  // LiveKit Room
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;

  // 状态
  bool _isCoHosting = false;
  bool get isCoHosting => _isCoHosting;

  // LiveKit URL (从 token 消息中获取)
  String _livekitUrl = '';

  // 本地媒体状态（LiveKit 未连接时的 fallback 状态）
  bool _localMicEnabled = true;
  bool _localCameraEnabled = true;

  // 参与者列表
  LocalParticipant? get localParticipant => _room?.localParticipant;

  List<RemoteParticipant> get remoteParticipants =>
      _room?.remoteParticipants.values.toList() ?? [];

  /// 所有参与者（本地 + 远端）
  List<Participant> get participants {
    if (_room == null) return [];
    return [
      if (_room!.localParticipant != null) _room!.localParticipant!,
      ..._room!.remoteParticipants.values,
    ];
  }

  /// 活跃发言人（LiveKit 内置支持）
  Participant? get activeSpeaker {
    if (_room == null) return null;
    if (_room!.activeSpeakers.isNotEmpty) {
      return _room!.activeSpeakers.first;
    }
    return _room!.localParticipant;
  }

  /// 活跃发言人ID
  int get activeSpeakerId {
    final speaker = activeSpeaker;
    if (speaker == null) return localUserId;
    return _parseUserId(speaker.identity) ?? localUserId;
  }

  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  CoHostService({required this.livestreamId, required this.localUserId}) {
    _setupWebSocketListener();
  }

  void _setupWebSocketListener() {
    _wsSubscription = WebSocketService().messageStream.listen((message) {
      final type = message['type'] as String?;
      if (type == 'livestream_cohost_token') {
        final data = message['data'] as Map<String, dynamic>? ?? {};
        final lsId = (data['livestream_id'] as num?)?.toInt() ?? 0;
        if (lsId == livestreamId) {
          _handleToken(data);
        }
      }
    });
  }

  /// 收到服务端推送的 LiveKit Token
  Future<void> _handleToken(Map<String, dynamic> data) async {
    final token = data['token'] as String? ?? '';
    final url = data['livekit_url'] as String? ?? '';
    if (token.isEmpty || url.isEmpty) return;

    _livekitUrl = url;
    await connectToRoom(url, token);
  }

  /// 连接 LiveKit 房间
  Future<void> connectToRoom(String url, String token) async {
    // 如果已连接则跳过
    if (_room != null && _room!.connectionState == ConnectionState.connected) {
      return;
    }

    // 标记连麦已建立（信令层），即使 LiveKit 连接失败也保持
    _isCoHosting = true;
    notifyListeners();

    // 清理旧连接
    await _disconnectRoom();

    _room = Room();

    // 设置事件监听
    _roomListener = _room!.createListener();
    _setupRoomEvents();

    try {
      await _room!.connect(
        url,
        token,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          // 不在 connect 阶段自动采集，改为手动开启以分别处理音频/视频错误
          defaultAudioPublishOptions: AudioPublishOptions(
            dtx: true,
          ),
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

      debugPrint('CoHost: Room connected successfully');

      // 优先开启麦克风（音频连麦最重要）
      try {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        debugPrint('CoHost: Microphone enabled successfully');
      } catch (e) {
        debugPrint('CoHost: failed to enable microphone: $e');
      }

      // 尝试开启摄像头（可选，没有摄像头时不影响连麦）
      try {
        debugPrint('CoHost: Attempting to enable camera...');
        await _room!.localParticipant?.setCameraEnabled(true);
        debugPrint('CoHost: Camera enabled successfully');
        
        // 验证视频轨道是否真的发布了
        final videoPubs = _room!.localParticipant?.videoTrackPublications ?? [];
        debugPrint('CoHost: Video track publications count: ${videoPubs.length}');
        for (final pub in videoPubs) {
          debugPrint('CoHost: Video track - sid: ${pub.sid}, muted: ${pub.muted}, track: ${pub.track != null}');
        }
      } catch (e) {
        debugPrint('CoHost: failed to enable camera: $e');
        _localCameraEnabled = false;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('CoHost connectToRoom error: $e');
      await _disconnectRoom();
      // _isCoHosting 保持 true — 信令层连麦已建立，只是 LiveKit 不可用
      notifyListeners();
    }
  }

  void _setupRoomEvents() {
    _roomListener
      ?..on<ParticipantConnectedEvent>((event) {
        debugPrint('CoHost: participant connected: ${event.participant.identity}');
        notifyListeners();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        debugPrint('CoHost: participant disconnected: ${event.participant.identity}');
        notifyListeners();
      })
      ..on<TrackPublishedEvent>((event) {
        notifyListeners();
      })
      ..on<TrackUnpublishedEvent>((event) {
        notifyListeners();
      })
      ..on<TrackSubscribedEvent>((event) {
        notifyListeners();
      })
      ..on<TrackUnsubscribedEvent>((event) {
        notifyListeners();
      })
      ..on<TrackMutedEvent>((event) {
        debugPrint('CoHost: track muted by ${event.participant.identity}');
        notifyListeners();
      })
      ..on<TrackUnmutedEvent>((event) {
        debugPrint('CoHost: track unmuted by ${event.participant.identity}');
        notifyListeners();
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        notifyListeners();
      })
      ..on<RoomDisconnectedEvent>((event) {
        debugPrint('CoHost: room disconnected, reason: ${event.reason}');
        // 不立即设置 _isCoHosting = false，而是尝试重连
        _handleRoomDisconnected();
      });
  }

  /// 处理房间断开连接
  Future<void> _handleRoomDisconnected() async {
    if (_isDisposed) return;
    
    debugPrint('CoHost: attempting to reconnect...');
    
    // 等待 2 秒后尝试重连
    await Future.delayed(const Duration(seconds: 2));
    
    if (_isDisposed || !_isCoHosting) return;
    
    // 尝试通过 API 获取新的 token 重连
    try {
      final res = await _api.getCoHostToken(livestreamId);
      if (res.isSuccess) {
        final data = res.data as Map<String, dynamic>? ?? {};
        final token = data['token'] as String? ?? '';
        final url = data['livekit_url'] as String? ?? '';
        if (token.isNotEmpty && url.isNotEmpty) {
          debugPrint('CoHost: reconnecting with new token...');
          await connectToRoom(url, token);
          return;
        }
      }
    } catch (e) {
      debugPrint('CoHost: reconnect failed: $e');
    }
    
    // 重连失败，标记连麦已结束
    _isCoHosting = false;
    notifyListeners();
  }

  /// 手动设置活跃发言人
  void setActiveSpeaker(int userId) {
    notifyListeners();
  }

  // ── 连麦流程 ──

  /// 请求连麦（HTTP API）
  Future<bool> requestCoHost() async {
    try {
      final res = await _api.requestCoHost(livestreamId);
      return res.isSuccess;
    } catch (e) {
      debugPrint('Request cohost error: $e');
      return false;
    }
  }

  /// 接受连麦（主播侧，HTTP API → 服务端生成Token并通过WS发给双方）
  Future<bool> acceptCoHost(int userId) async {
    try {
      final res = await _api.acceptCoHost(livestreamId, userId: userId);
      if (!res.isSuccess) {
        debugPrint('Accept cohost API failed: ${res.message} (code=${res.code})');
        return false;
      }
      // Token 会通过 WS 'livestream_cohost_token' 发来，_handleToken 会自动连接
      return true;
    } catch (e) {
      debugPrint('Accept cohost error: $e');
      return false;
    }
  }

  /// 拒绝连麦（主播侧）
  Future<bool> rejectCoHost(int userId) async {
    try {
      final res = await _api.rejectCoHost(livestreamId, userId: userId);
      return res.isSuccess;
    } catch (e) {
      debugPrint('Reject cohost error: $e');
      return false;
    }
  }

  /// 连麦被接受（从信令层触发）
  /// 立即设置 _isCoHosting = true，然后异步尝试获取 Token 连接 LiveKit
  Future<void> onCoHostAccepted(int peerId) async {
    // 立即标记连麦状态（不等待 LiveKit 连接）
    if (!_isCoHosting) {
      _isCoHosting = true;
      notifyListeners();
    }

    // 如果已连接 LiveKit 房间，无需再获取 token
    if (_room != null && _room!.connectionState == ConnectionState.connected) {
      return;
    }

    // 尝试通过 API 获取 token（WS token 可能还在路上）
    try {
      final res = await _api.getCoHostToken(livestreamId);
      if (res.isSuccess) {
        final data = res.data as Map<String, dynamic>? ?? {};
        final token = data['token'] as String? ?? '';
        final url = data['livekit_url'] as String? ?? '';
        if (token.isNotEmpty && url.isNotEmpty) {
          await connectToRoom(url, token);
        }
      }
    } catch (e) {
      debugPrint('Get cohost token error: $e');
    }
  }

  /// 切换麦克风
  /// 静音: 先 mediaStreamTrack.enabled=false（立即静音），再 setMicrophoneEnabled 通知远端
  /// 取消静音: 先 setMicrophoneEnabled(true)（LiveKit 会 restartTrack 恢复音频轨道），
  ///           再确保新轨道 mediaStreamTrack.enabled=true
  Future<void> toggleMic(bool enabled) async {
    _localMicEnabled = enabled;
    final participant = _room?.localParticipant;
    if (participant != null) {
      if (enabled) {
        // UNMUTE: LiveKit 先恢复/重建轨道，再确保底层已启用
        try {
          await participant.setMicrophoneEnabled(true);
        } catch (e) {
          debugPrint('CoHost toggleMic setMicrophoneEnabled(true) error: $e');
        }
        for (final pub in participant.audioTrackPublications) {
          final track = pub.track;
          if (track != null) {
            try { track.mediaStreamTrack.enabled = true; } catch (_) {}
          }
        }
      } else {
        // MUTE: 先禁用底层轨道（立即生效），再通知 LiveKit 让远端看到静音指示
        for (final pub in participant.audioTrackPublications) {
          final track = pub.track;
          if (track != null) {
            try { track.mediaStreamTrack.enabled = false; } catch (_) {}
          }
        }
        try {
          await participant.setMicrophoneEnabled(false);
        } catch (e) {
          debugPrint('CoHost toggleMic setMicrophoneEnabled(false) error: $e');
        }
      }
    }
    notifyListeners();
  }

  /// 切换本地麦克风（兼容旧接口）
  void toggleLocalMic(bool enabled) {
    toggleMic(enabled);
  }

  /// 切换摄像头（与 toggleMic 同理）
  Future<void> toggleCamera(bool enabled) async {
    _localCameraEnabled = enabled;
    final participant = _room?.localParticipant;
    if (participant != null) {
      if (enabled) {
        // UNMUTE: LiveKit 先恢复轨道
        try {
          await participant.setCameraEnabled(true);
        } catch (e) {
          debugPrint('CoHost toggleCamera setCameraEnabled(true) error: $e');
        }
        for (final pub in participant.videoTrackPublications) {
          final track = pub.track;
          if (track != null) {
            try { track.mediaStreamTrack.enabled = true; } catch (_) {}
          }
        }
      } else {
        // MUTE: 先禁用底层，再通知 LiveKit
        for (final pub in participant.videoTrackPublications) {
          final track = pub.track;
          if (track != null) {
            try { track.mediaStreamTrack.enabled = false; } catch (_) {}
          }
        }
        try {
          await participant.setCameraEnabled(false);
        } catch (e) {
          debugPrint('CoHost toggleCamera setCameraEnabled(false) error: $e');
        }
      }
    }
    notifyListeners();
  }

  /// 获取麦克风状态
  bool get isMicEnabled {
    final pubs = _room?.localParticipant?.audioTrackPublications;
    if (pubs == null || pubs.isEmpty) return _localMicEnabled;
    final track = pubs.first.track;
    if (track != null) {
      try {
        return track.mediaStreamTrack.enabled;
      } catch (_) {}
    }
    return _localMicEnabled;
  }

  /// 获取摄像头状态
  bool get isCameraEnabled {
    final pubs = _room?.localParticipant?.videoTrackPublications;
    if (pubs == null || pubs.isEmpty) return _localCameraEnabled;
    final track = pubs.first.track;
    if (track != null) {
      try {
        return track.mediaStreamTrack.enabled;
      } catch (_) {}
    }
    return _localCameraEnabled;
  }

  /// 结束连麦（主动调用，通知服务端）
  Future<void> endCoHost() async {
    try {
      await _api.endCoHost(livestreamId);
    } catch (e) {
      debugPrint('End cohost error: $e');
    }
    await _cleanup();
  }

  /// 踢出指定连麦用户（主播专用）
  Future<bool> kickCoHost(int userId) async {
    try {
      final res = await _api.kickCoHost(livestreamId, userId: userId);
      return res.isSuccess;
    } catch (e) {
      debugPrint('Kick cohost error: $e');
      return false;
    }
  }

  /// 仅本地清理（收到对方断开通知时调用，不再通知服务端）
  Future<void> cleanupLocal() async {
    await _cleanup();
  }

  /// 远端用户离开（收到 livestream_cohost_end 通知）
  void onCoHostEnded(int userId) {
    if (remoteParticipants.isEmpty) {
      _isCoHosting = false;
    }
    notifyListeners();
  }

  Future<void> _disconnectRoom() async {
    _roomListener?.dispose();
    _roomListener = null;
    await _room?.disconnect();
    _room?.dispose();
    _room = null;
  }

  Future<void> _cleanup() async {
    await _disconnectRoom();
    _isCoHosting = false;
    _localMicEnabled = true;
    _localCameraEnabled = true;
    notifyListeners();
  }

  /// 从 LiveKit identity (格式: "user_{id}") 解析用户ID
  int? _parseUserId(String identity) {
    if (identity.startsWith('user_')) {
      return int.tryParse(identity.substring(5));
    }
    return null;
  }

  /// 根据用户ID获取参与者（用于UI）
  Participant? getParticipantByUserId(int userId) {
    final identity = 'user_$userId';
    if (_room?.localParticipant?.identity == identity) {
      return _room!.localParticipant;
    }
    return _room?.remoteParticipants.values
        .cast<Participant?>()
        .firstWhere((p) => p?.identity == identity, orElse: () => null);
  }

  // ── 兼容旧接口 ──

  @Deprecated('Use localParticipant instead')
  dynamic get localStream => null;

  @Deprecated('Use VideoTrackRenderer with localParticipant videoTrack')
  dynamic get localRenderer => null;

  @Deprecated('Use VideoTrackRenderer with RemoteParticipant videoTrack')
  dynamic getRemoteRenderer(int userId) => null;

  List<int> get coHostUserIds {
    return remoteParticipants
        .map((p) => _parseUserId(p.identity))
        .whereType<int>()
        .toList();
  }

  @Deprecated('LiveKit manages media internally')
  void setExistingLocalStream(dynamic stream, dynamic renderer) {}

  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _wsSubscription?.cancel();
    _disconnectRoom();
    super.dispose();
  }
}
