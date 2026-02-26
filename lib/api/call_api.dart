/// 通话 API
import 'package:im_client/api/api_client.dart';

/// 通话类型
class CallType {
  static const int voice = 1; // 语音通话
  static const int video = 2; // 视频通话
}

/// 通话状态
class CallStatus {
  static const int calling = 0; // 呼叫中
  static const int connected = 1; // 已接通
  static const int rejected = 2; // 已拒绝
  static const int cancelled = 3; // 已取消
  static const int missed = 4; // 未接听
  static const int busy = 5; // 忙线
  static const int ended = 6; // 已结束

  static String getText(int status) {
    switch (status) {
      case calling:
        return '呼叫中';
      case connected:
        return '已接通';
      case rejected:
        return '已拒绝';
      case cancelled:
        return '已取消';
      case missed:
        return '未接听';
      case busy:
        return '忙线';
      case ended:
        return '已结束';
      default:
        return '未知';
    }
  }
}

/// 通话记录
class CallRecord {
  final String callId;
  final int callerId;
  final int calleeId;
  final int? groupId;
  final int callType;
  final int status;
  final DateTime? startTime;
  final DateTime? connectTime;
  final DateTime? endTime;
  final int duration;
  final CallUser? caller;
  final CallUser? callee;

  CallRecord({
    required this.callId,
    required this.callerId,
    required this.calleeId,
    this.groupId,
    required this.callType,
    required this.status,
    this.startTime,
    this.connectTime,
    this.endTime,
    required this.duration,
    this.caller,
    this.callee,
  });

  factory CallRecord.fromJson(Map<String, dynamic> json) {
    return CallRecord(
      callId: json['call_id'] as String? ?? '',
      callerId: json['caller_id'] as int? ?? 0,
      calleeId: json['callee_id'] as int? ?? 0,
      groupId: json['group_id'] as int?,
      callType: json['call_type'] as int? ?? 1,
      status: json['status'] as int? ?? 0,
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'])
          : null,
      connectTime: json['connect_time'] != null
          ? DateTime.parse(json['connect_time'])
          : null,
      endTime:
          json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      duration: json['duration'] as int? ?? 0,
      caller:
          json['caller'] != null ? CallUser.fromJson(json['caller']) : null,
      callee:
          json['callee'] != null ? CallUser.fromJson(json['callee']) : null,
    );
  }

  bool get isVoice => callType == CallType.voice;
  bool get isVideo => callType == CallType.video;
  bool get isOutgoing => callerId != calleeId;

  String get formattedDuration {
    if (duration <= 0) return '00:00';
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get statusText => CallStatus.getText(status);
}

/// 通话用户信息
class CallUser {
  final int id;
  final String nickname;
  final String avatar;

  CallUser({
    required this.id,
    required this.nickname,
    required this.avatar,
  });

  factory CallUser.fromJson(Map<String, dynamic> json) {
    return CallUser(
      id: json['id'] as int? ?? 0,
      nickname: json['nickname'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
    );
  }
}

/// ICE服务器配置
class IceServer {
  final List<String> urls;
  final String? username;
  final String? credential;

  IceServer({
    required this.urls,
    this.username,
    this.credential,
  });

  factory IceServer.fromJson(Map<String, dynamic> json) {
    return IceServer(
      urls: (json['urls'] as List?)?.map((e) => e.toString()).toList() ?? [],
      username: json['username'] as String?,
      credential: json['credential'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'urls': urls};
    if (username != null) map['username'] = username;
    if (credential != null) map['credential'] = credential;
    return map;
  }
}

/// 通话 API 客户端
class CallApi {
  final ApiClient _client;

  CallApi(this._client);

  /// 发起通话
  Future<ApiResponse> initiateCall({
    required int targetId,
    required int callType,
    int? groupId,
  }) async {
    return _client.post('/call/initiate', data: {
      'to_user_id': targetId,
      'call_type': callType,
      if (groupId != null) 'group_id': groupId,
    });
  }

  /// 接听通话
  Future<ApiResponse> acceptCall(String callId) async {
    return _client.post('/call/accept/$callId');
  }

  /// 拒绝通话
  Future<ApiResponse> rejectCall(String callId) async {
    return _client.post('/call/reject/$callId');
  }

  /// 结束通话
  Future<ApiResponse> endCall(String callId) async {
    return _client.post('/call/end/$callId');
  }

  /// 取消通话
  Future<ApiResponse> cancelCall(String callId) async {
    return _client.post('/call/cancel/$callId');
  }

  /// 忙线
  Future<ApiResponse> busyCall(String callId) async {
    return _client.post('/call/busy/$callId');
  }

  /// 发送WebRTC信令
  Future<ApiResponse> sendSignal({
    required String callId,
    required int toUserId,
    required String signalType,
    required String signalData,
  }) async {
    return _client.post('/call/signal', data: {
      'call_id': callId,
      'to_user_id': toUserId,
      'signal_type': signalType,
      'signal_data': signalData,
    });
  }

  /// 获取通话记录
  Future<ApiResponse> getCallHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    return _client.get('/call/history', queryParameters: {
      'page': page,
      'page_size': pageSize,
    });
  }

  /// 获取进行中的通话
  Future<ApiResponse> getOngoingCall() async {
    return _client.get('/call/ongoing');
  }

  /// 获取ICE服务器配置
  Future<ApiResponse> getIceServers() async {
    return _client.get('/call/ice-servers');
  }

  /// 获取通话详情
  Future<ApiResponse> getCallDetail(String callId) async {
    return _client.get('/call/$callId');
  }

  /// 删除通话记录
  Future<ApiResponse> deleteCallRecord(String callId) async {
    return _client.delete('/call/$callId');
  }

  /// 获取VAPID公钥（用于Web Push订阅）
  Future<ApiResponse> getVapidPublicKey() async {
    return _client.get('/config/vapid-key');
  }
}
