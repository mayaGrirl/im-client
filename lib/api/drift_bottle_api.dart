/// 漂流瓶API
import 'api_client.dart';

class DriftBottleApi {
  final ApiClient _client;

  DriftBottleApi(this._client);

  /// 获取配置和今日剩余次数
  Future<ApiResult> getConfig() async {
    final response = await _client.get('/drift-bottle/config');
    return response.toResult();
  }

  /// 扔瓶子
  Future<ApiResult> throwBottle({
    required int type, // 1文字 2语音 3图片
    required String content,
    int voiceDuration = 0,
    int targetGender = 0, // 0不限 1男 2女
    bool isAnonymous = true,
  }) async {
    final response = await _client.post('/drift-bottle/throw', data: {
      'type': type,
      'content': content,
      'voice_duration': voiceDuration,
      'target_gender': targetGender,
      'is_anonymous': isAnonymous,
    });
    return response.toResult();
  }

  /// 捞瓶子
  Future<ApiResult> pickBottle({int targetGender = 0}) async {
    final response = await _client.post('/drift-bottle/pick', data: {
      'target_gender': targetGender,
    });
    return response.toResult();
  }

  /// 扔回瓶子
  Future<ApiResult> throwBackBottle(int bottleId) async {
    final response = await _client.post('/drift-bottle/$bottleId/throw-back');
    return response.toResult();
  }

  /// 回复瓶子
  Future<ApiResult> replyBottle({
    required int bottleId,
    required String content,
    int type = 1,
  }) async {
    final response = await _client.post('/drift-bottle/$bottleId/reply', data: {
      'content': content,
      'type': type,
    });
    return response.toResult();
  }

  /// 获取我扔的瓶子
  Future<ApiResult> getMyBottles({int page = 1, int pageSize = 20}) async {
    final response = await _client.get('/drift-bottle/mine', queryParameters: {
      'page': page,
      'page_size': pageSize,
    });
    return response.toResult();
  }

  /// 获取漂流瓶对话列表
  Future<ApiResult> getBottleChats() async {
    final response = await _client.get('/drift-bottle/chats');
    return response.toResult();
  }

  /// 获取瓶子的回复/对话
  Future<ApiResult> getBottleReplies(int bottleId) async {
    final response = await _client.get('/drift-bottle/$bottleId/replies');
    return response.toResult();
  }

  /// 删除瓶子
  Future<ApiResult> deleteBottle(int bottleId) async {
    final response = await _client.delete('/drift-bottle/$bottleId');
    return response.toResult();
  }
}

/// 漂流瓶类型
class BottleType {
  static const int text = 1;
  static const int voice = 2;
  static const int image = 3;
}

/// 漂流瓶状态
class BottleStatus {
  static const int deleted = 0;
  static const int floating = 1;
  static const int picked = 2;
  static const int expired = 3;
  static const int violated = 4;

  static String getName(int status) {
    switch (status) {
      case deleted:
        return '已删除';
      case floating:
        return '漂流中';
      case picked:
        return '已捞取';
      case expired:
        return '已过期';
      case violated:
        return '违规';
      default:
        return '未知';
    }
  }
}

/// 漂流瓶模型
class DriftBottle {
  final int id;
  final int type;
  final String content;
  final int voiceDuration;
  final int gender;
  final bool isAnonymous;
  final int status;
  final int pickCount;
  final int throwBackCount;
  final DateTime? expireAt;
  final DateTime createdAt;
  final BottleUser? user;

  DriftBottle({
    required this.id,
    required this.type,
    required this.content,
    this.voiceDuration = 0,
    this.gender = 0,
    this.isAnonymous = true,
    required this.status,
    this.pickCount = 0,
    this.throwBackCount = 0,
    this.expireAt,
    required this.createdAt,
    this.user,
  });

  factory DriftBottle.fromJson(Map<String, dynamic> json) {
    return DriftBottle(
      id: json['id'] ?? 0,
      type: json['type'] ?? 1,
      content: json['content'] ?? '',
      voiceDuration: json['voice_duration'] ?? 0,
      gender: json['gender'] ?? 0,
      isAnonymous: json['is_anonymous'] ?? true,
      status: json['status'] ?? 1,
      pickCount: json['pick_count'] ?? 0,
      throwBackCount: json['throw_back_count'] ?? 0,
      expireAt: json['expire_at'] != null ? DateTime.parse(json['expire_at']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      user: json['user'] != null ? BottleUser.fromJson(json['user']) : null,
    );
  }

  bool get isText => type == BottleType.text;
  bool get isVoice => type == BottleType.voice;
  bool get isImage => type == BottleType.image;
}

/// 漂流瓶用户（可能是匿名的）
class BottleUser {
  final int id;
  final String nickname;
  final String avatar;
  final int gender;

  BottleUser({
    required this.id,
    required this.nickname,
    this.avatar = '',
    this.gender = 0,
  });

  factory BottleUser.fromJson(Map<String, dynamic> json) {
    return BottleUser(
      id: json['id'] ?? 0,
      nickname: json['nickname'] ?? '匿名用户',
      avatar: json['avatar'] ?? '',
      gender: json['gender'] ?? 0,
    );
  }

  bool get isAnonymous => id == 0;
}

/// 漂流瓶回复
class BottleReply {
  final int id;
  final int bottleId;
  final int fromUserId;
  final int toUserId;
  final String content;
  final int type;
  final bool isRead;
  final DateTime createdAt;
  final BottleUser? fromUser;

  BottleReply({
    required this.id,
    required this.bottleId,
    required this.fromUserId,
    required this.toUserId,
    required this.content,
    this.type = 1,
    this.isRead = false,
    required this.createdAt,
    this.fromUser,
  });

  factory BottleReply.fromJson(Map<String, dynamic> json) {
    return BottleReply(
      id: json['id'] ?? 0,
      bottleId: json['bottle_id'] ?? 0,
      fromUserId: json['from_user_id'] ?? 0,
      toUserId: json['to_user_id'] ?? 0,
      content: json['content'] ?? '',
      type: json['type'] ?? 1,
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      fromUser: json['from_user'] != null
          ? BottleUser.fromJson(json['from_user'])
          : null,
    );
  }
}

/// 漂流瓶配置
class BottleConfig {
  final int dailyThrowLimit;
  final int dailyPickLimit;
  final int todayThrowCount;
  final int todayPickCount;
  final int remainingThrows;
  final int remainingPicks;

  BottleConfig({
    required this.dailyThrowLimit,
    required this.dailyPickLimit,
    required this.todayThrowCount,
    required this.todayPickCount,
    required this.remainingThrows,
    required this.remainingPicks,
  });

  factory BottleConfig.fromJson(Map<String, dynamic> json) {
    return BottleConfig(
      dailyThrowLimit: json['daily_throw_limit'] ?? 3,
      dailyPickLimit: json['daily_pick_limit'] ?? 10,
      todayThrowCount: json['today_throw_count'] ?? 0,
      todayPickCount: json['today_pick_count'] ?? 0,
      remainingThrows: json['remaining_throws'] ?? 3,
      remainingPicks: json['remaining_picks'] ?? 10,
    );
  }
}
