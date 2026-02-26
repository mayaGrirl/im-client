/// 小视频数据模型

import 'package:im_client/config/env_config.dart';

/// 小视频
class SmallVideo {
  final int id;
  final String videoId;
  final int userId;
  final String title;
  final String description;
  final String videoUrl;
  final String coverUrl;
  final int duration;
  final int width;
  final int height;
  final int fileSize;
  final int status;
  final int visibility;
  final int categoryId;
  final int musicId;
  final String locationName;
  final double latitude;
  final double longitude;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int collectCount;
  final bool allowComment;
  final bool allowDuet;
  final bool allowStitch;
  final bool allowSave;
  final bool allowLike;
  final bool isPaid;
  final int price;
  final int previewDuration;
  final bool isAd;
  final bool isTop;
  final DateTime? publishedAt;
  final DateTime createdAt;

  // 关联
  final SmallVideoUser? user;
  final SmallVideoCategory? category;
  final List<SmallVideoTag> tags;

  // 用户交互状态（来自详情接口）
  final bool isLiked;
  final bool isCollected;
  final bool isFollowing;

  SmallVideo({
    required this.id,
    this.videoId = '',
    required this.userId,
    this.title = '',
    this.description = '',
    required this.videoUrl,
    this.coverUrl = '',
    this.duration = 0,
    this.width = 0,
    this.height = 0,
    this.fileSize = 0,
    this.status = 0,
    this.visibility = 0,
    this.categoryId = 0,
    this.musicId = 0,
    this.locationName = '',
    this.latitude = 0,
    this.longitude = 0,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.collectCount = 0,
    this.allowComment = true,
    this.allowDuet = true,
    this.allowStitch = true,
    this.allowSave = true,
    this.allowLike = true,
    this.isPaid = false,
    this.price = 0,
    this.previewDuration = 0,
    this.isAd = false,
    this.isTop = false,
    this.publishedAt,
    required this.createdAt,
    this.user,
    this.category,
    this.tags = const [],
    this.isLiked = false,
    this.isCollected = false,
    this.isFollowing = false,
  });

  factory SmallVideo.fromJson(Map<String, dynamic> json) {
    // 处理相对URL，补全为绝对URL（本地存储返回 /uploads/... 形式）
    final rawVideoUrl = json['video_url'] ?? '';
    final rawCoverUrl = json['cover_url'] ?? '';
    final videoUrl = EnvConfig.instance.getFileUrl(rawVideoUrl);
    final coverUrl = EnvConfig.instance.getFileUrl(rawCoverUrl);

    return SmallVideo(
      id: _toInt(json['id']),
      videoId: json['video_id'] ?? '',
      userId: _toInt(json['user_id']),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      videoUrl: videoUrl,
      coverUrl: coverUrl,
      duration: _toInt(json['duration']),
      width: _toInt(json['width']),
      height: _toInt(json['height']),
      fileSize: _toInt(json['file_size']),
      status: _toInt(json['status']),
      visibility: _toInt(json['visibility']),
      categoryId: _toInt(json['category_id']),
      musicId: _toInt(json['music_id']),
      locationName: json['location_name'] ?? '',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      viewCount: _toInt(json['view_count']),
      likeCount: _toInt(json['like_count']),
      commentCount: _toInt(json['comment_count']),
      shareCount: _toInt(json['share_count']),
      collectCount: _toInt(json['collect_count']),
      allowComment: json['allow_comment'] ?? true,
      allowDuet: json['allow_duet'] ?? true,
      allowStitch: json['allow_stitch'] ?? true,
      allowSave: json['allow_save'] ?? true,
      allowLike: json['allow_like'] ?? true,
      isPaid: json['is_paid'] ?? false,
      price: _toInt(json['price']),
      previewDuration: _toInt(json['preview_duration']),
      isAd: json['is_ad'] ?? false,
      isTop: json['is_top'] ?? false,
      publishedAt: _parseDateTime(json['published_at']),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      user: json['user'] != null ? SmallVideoUser.fromJson(json['user']) : null,
      category: json['category'] != null ? SmallVideoCategory.fromJson(json['category']) : null,
      tags: (json['tags'] as List?)?.map((e) => SmallVideoTag.fromJson(e)).toList() ?? [],
      isLiked: json['is_liked'] ?? false,
      isCollected: json['is_collected'] ?? false,
      isFollowing: json['is_following'] ?? false,
    );
  }

  SmallVideo copyWith({
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? collectCount,
    bool? isLiked,
    bool? isCollected,
    bool? isFollowing,
    bool? isTop,
  }) {
    return SmallVideo(
      id: id,
      videoId: videoId,
      userId: userId,
      title: title,
      description: description,
      videoUrl: videoUrl,
      coverUrl: coverUrl,
      duration: duration,
      width: width,
      height: height,
      fileSize: fileSize,
      status: status,
      visibility: visibility,
      categoryId: categoryId,
      musicId: musicId,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      viewCount: viewCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      collectCount: collectCount ?? this.collectCount,
      allowComment: allowComment,
      allowDuet: allowDuet,
      allowStitch: allowStitch,
      allowSave: allowSave,
      allowLike: allowLike,
      isPaid: isPaid,
      price: price,
      previewDuration: previewDuration,
      isAd: isAd,
      isTop: isTop ?? this.isTop,
      publishedAt: publishedAt,
      createdAt: createdAt,
      user: user,
      category: category,
      tags: tags,
      isLiked: isLiked ?? this.isLiked,
      isCollected: isCollected ?? this.isCollected,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

/// 小视频用户信息
class SmallVideoUser {
  final int id;
  final String username;
  final String nickname;
  final String avatar;
  final String? bio;
  final bool isLive;
  final int? currentLivestreamId;

  SmallVideoUser({
    required this.id,
    this.username = '',
    this.nickname = '',
    this.avatar = '',
    this.bio,
    this.isLive = false,
    this.currentLivestreamId,
  });

  factory SmallVideoUser.fromJson(Map<String, dynamic> json) {
    return SmallVideoUser(
      id: _toInt(json['id']),
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: EnvConfig.instance.getFileUrl(json['avatar'] ?? ''),
      bio: json['bio'],
      isLive: json['is_live'] ?? false,
      currentLivestreamId: json['current_livestream_id'],
    );
  }
}

/// 小视频评论
class SmallVideoComment {
  final int id;
  final int smallVideoId;
  final int userId;
  final String content;
  final int parentId;
  final int replyToId;
  final int replyToUid;
  final int likeCount;
  final int replyCount;
  final bool isTop;
  final bool isHot;
  final int status;
  final DateTime createdAt;
  final SmallVideoUser? user;
  final SmallVideoUser? replyTo;
  final List<SmallVideoComment> replies;
  final bool isLiked;

  SmallVideoComment({
    required this.id,
    required this.smallVideoId,
    required this.userId,
    required this.content,
    this.parentId = 0,
    this.replyToId = 0,
    this.replyToUid = 0,
    this.likeCount = 0,
    this.replyCount = 0,
    this.isTop = false,
    this.isHot = false,
    this.status = 1,
    required this.createdAt,
    this.user,
    this.replyTo,
    this.replies = const [],
    this.isLiked = false,
  });

  factory SmallVideoComment.fromJson(Map<String, dynamic> json) {
    return SmallVideoComment(
      id: _toInt(json['id']),
      smallVideoId: _toInt(json['small_video_id']),
      userId: _toInt(json['user_id']),
      content: json['content'] ?? '',
      parentId: _toInt(json['parent_id']),
      replyToId: _toInt(json['reply_to_id']),
      replyToUid: _toInt(json['reply_to_uid']),
      likeCount: _toInt(json['like_count']),
      replyCount: _toInt(json['reply_count']),
      isTop: json['is_top'] ?? false,
      isHot: json['is_hot'] ?? false,
      status: _toInt(json['status']),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      user: json['user'] != null ? SmallVideoUser.fromJson(json['user']) : null,
      replyTo: json['reply_to'] != null ? SmallVideoUser.fromJson(json['reply_to']) : null,
      replies: (json['replies'] as List?)?.map((e) => SmallVideoComment.fromJson(e)).toList() ?? [],
      isLiked: json['is_liked'] ?? false,
    );
  }

  SmallVideoComment copyWith({
    int? likeCount,
    bool? isLiked,
    List<SmallVideoComment>? replies,
    int? replyCount,
  }) {
    return SmallVideoComment(
      id: id,
      smallVideoId: smallVideoId,
      userId: userId,
      content: content,
      parentId: parentId,
      replyToId: replyToId,
      replyToUid: replyToUid,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      isTop: isTop,
      isHot: isHot,
      status: status,
      createdAt: createdAt,
      user: user,
      replyTo: replyTo,
      replies: replies ?? this.replies,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

/// 小视频分类
class SmallVideoCategory {
  final int id;
  final String name;
  final String nameEn;
  final String icon;
  final int sortOrder;
  final bool isActive;

  SmallVideoCategory({
    required this.id,
    required this.name,
    this.nameEn = '',
    this.icon = '',
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory SmallVideoCategory.fromJson(Map<String, dynamic> json) {
    return SmallVideoCategory(
      id: _toInt(json['id']),
      name: json['name'] ?? '',
      nameEn: json['name_en'] ?? '',
      icon: json['icon'] ?? '',
      sortOrder: _toInt(json['sort_order']),
      isActive: json['is_active'] ?? true,
    );
  }
}

/// 小视频标签
class SmallVideoTag {
  final int id;
  final String name;
  final String nameDefault;
  final String nameEn;
  final String nameZhTW;
  final String nameFr;
  final String nameHi;
  final String description;
  final String coverUrl;
  final int viewCount;
  final int videoCount;
  final bool isHot;
  final bool isOfficial;

  SmallVideoTag({
    required this.id,
    required this.name,
    this.nameDefault = '',
    this.nameEn = '',
    this.nameZhTW = '',
    this.nameFr = '',
    this.nameHi = '',
    this.description = '',
    this.coverUrl = '',
    this.viewCount = 0,
    this.videoCount = 0,
    this.isHot = false,
    this.isOfficial = false,
  });

  factory SmallVideoTag.fromJson(Map<String, dynamic> json) {
    return SmallVideoTag(
      id: _toInt(json['id']),
      name: json['name'] ?? '',
      nameDefault: json['name_default'] ?? json['name'] ?? '',
      nameEn: json['name_en'] ?? '',
      nameZhTW: json['name_zh_tw'] ?? '',
      nameFr: json['name_fr'] ?? '',
      nameHi: json['name_hi'] ?? '',
      description: json['description'] ?? '',
      coverUrl: json['cover_url'] ?? '',
      viewCount: _toInt(json['view_count']),
      videoCount: _toInt(json['video_count']),
      isHot: json['is_hot'] ?? false,
      isOfficial: json['is_official'] ?? false,
    );
  }
}

// ==================== 辅助方法 ====================

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
