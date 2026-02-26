/// 朋友圈API
import 'api_client.dart';

class MomentApi {
  final ApiClient _client;

  MomentApi(this._client);

  /// 发布朋友圈
  Future<ApiResponse> createMoment({
    String? content,
    List<String>? images,
    List<String>? videos,
    String? location,
    int visibility = 0,
    List<int>? visibleList,
    String? extra,
  }) {
    return _client.post('/moment/create', data: {
      if (content != null && content.isNotEmpty) 'content': content,
      if (images != null && images.isNotEmpty) 'images': images,
      if (videos != null && videos.isNotEmpty) 'videos': videos,
      if (location != null && location.isNotEmpty) 'location': location,
      'visibility': visibility,
      if (visibleList != null && visibleList.isNotEmpty) 'visible_list': visibleList,
      if (extra != null && extra.isNotEmpty) 'extra': extra,
    });
  }

  /// 获取朋友圈列表（好友动态）
  Future<ApiResponse> getMomentList({int page = 1, int pageSize = 20}) {
    return _client.get('/moment/list', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 获取指定用户的朋友圈
  Future<ApiResponse> getUserMoments({
    int? userId,
    int page = 1,
    int pageSize = 20,
  }) {
    return _client.get('/moment/mine', queryParameters: {
      if (userId != null) 'user_id': userId.toString(),
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 点赞/取消点赞
  Future<ApiResponse> toggleLike(int momentId) {
    return _client.post('/moment/$momentId/like');
  }

  /// 评论朋友圈
  Future<ApiResponse> comment({
    required int momentId,
    required String content,
    int? replyToId,
    int? replyUserId,
  }) {
    return _client.post('/moment/$momentId/comment', data: {
      'content': content,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (replyUserId != null) 'reply_user_id': replyUserId,
    });
  }

  /// 删除朋友圈
  Future<ApiResponse> deleteMoment(int momentId) {
    return _client.delete('/moment/$momentId');
  }

  /// 删除评论
  Future<ApiResponse> deleteComment(int commentId) {
    return _client.delete('/moment/comment/$commentId');
  }

  /// 获取朋友圈通知
  Future<ApiResponse> getNotifications({int page = 1, int pageSize = 20}) {
    return _client.get('/moment/notifications', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 标记通知已读
  Future<ApiResponse> markNotificationsRead() {
    return _client.post('/moment/notifications/read');
  }
}

/// 朋友圈动态模型
class Moment {
  final int id;
  final int userId;
  final MomentUser? user;
  final String content;
  final List<String> images;
  final List<String> videos;
  final String? location;
  final String? extra;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final List<MomentLike> likes;
  final List<MomentComment> comments;
  final DateTime createdAt;

  Moment({
    required this.id,
    required this.userId,
    this.user,
    required this.content,
    required this.images,
    required this.videos,
    this.location,
    this.extra,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    required this.likes,
    required this.comments,
    required this.createdAt,
  });

  factory Moment.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      return [];
    }

    return Moment(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      user: json['user'] != null ? MomentUser.fromJson(json['user']) : null,
      content: json['content'] ?? '',
      images: parseStringList(json['images']),
      videos: parseStringList(json['videos']),
      location: json['location'],
      extra: json['extra'],
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      likes: (json['likes'] as List?)
              ?.map((e) => MomentLike.fromJson(e))
              .toList() ??
          [],
      comments: (json['comments'] as List?)
              ?.map((e) => MomentComment.fromJson(e))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Moment copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLiked,
    List<MomentLike>? likes,
    List<MomentComment>? comments,
  }) {
    return Moment(
      id: id,
      userId: userId,
      user: user,
      content: content,
      images: images,
      videos: videos,
      location: location,
      extra: extra,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      createdAt: createdAt,
    );
  }
}

/// 朋友圈用户信息
class MomentUser {
  final int id;
  final String username;
  final String nickname;
  final String avatar;
  final String? bio; // 签名/个性签名

  MomentUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatar,
    this.bio,
  });

  factory MomentUser.fromJson(Map<String, dynamic> json) {
    return MomentUser(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      bio: json['bio'],
    );
  }
}

/// 点赞信息
class MomentLike {
  final int id;
  final int momentId;
  final int userId;
  final MomentUser? user;
  final DateTime createdAt;

  MomentLike({
    required this.id,
    required this.momentId,
    required this.userId,
    this.user,
    required this.createdAt,
  });

  factory MomentLike.fromJson(Map<String, dynamic> json) {
    return MomentLike(
      id: json['id'] ?? 0,
      momentId: json['moment_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      user: json['user'] != null ? MomentUser.fromJson(json['user']) : null,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

/// 评论信息
class MomentComment {
  final int id;
  final int momentId;
  final int userId;
  final MomentUser? user;
  final String content;
  final int? replyToId;
  final int? replyUserId;
  final MomentUser? replyUser;
  final DateTime createdAt;

  MomentComment({
    required this.id,
    required this.momentId,
    required this.userId,
    this.user,
    required this.content,
    this.replyToId,
    this.replyUserId,
    this.replyUser,
    required this.createdAt,
  });

  factory MomentComment.fromJson(Map<String, dynamic> json) {
    return MomentComment(
      id: json['id'] ?? 0,
      momentId: json['moment_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      user: json['user'] != null ? MomentUser.fromJson(json['user']) : null,
      content: json['content'] ?? '',
      replyToId: json['reply_to_id'],
      replyUserId: json['reply_user_id'],
      replyUser: json['reply_user'] != null
          ? MomentUser.fromJson(json['reply_user'])
          : null,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

/// 可见性类型
class MomentVisibility {
  static const int public = 0;    // 公开
  static const int private = 1;   // 私密
  static const int partial = 2;   // 部分可见
  static const int exclude = 3;   // 部分不可见

  static String getName(int visibility) {
    switch (visibility) {
      case public:
        return '公开';
      case private:
        return '私密';
      case partial:
        return '部分可见';
      case exclude:
        return '部分不可见';
      default:
        return '公开';
    }
  }
}
