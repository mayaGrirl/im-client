/// 树洞（匿名社区）API
import 'api_client.dart';

class TreeHoleApi {
  final ApiClient _client;

  TreeHoleApi(this._client);

  /// 发布树洞
  Future<ApiResponse> createTreeHole({
    required String content,
    List<String>? images,
    String? topic,
    List<String>? tags,
  }) {
    return _client.post('/tree-hole/create', data: {
      'content': content,
      if (images != null && images.isNotEmpty) 'images': images,
      if (topic != null && topic.isNotEmpty) 'topic': topic,
      if (tags != null && tags.isNotEmpty) 'tags': tags,
    });
  }

  /// 获取树洞列表
  Future<ApiResponse> getTreeHoleList({
    int page = 1,
    int pageSize = 20,
    String? topic,
    String? tag,
    String sort = 'latest', // latest, hot
  }) {
    return _client.get('/tree-hole/list', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
      if (topic != null && topic.isNotEmpty) 'topic': topic,
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      'sort': sort,
    });
  }

  /// 获取话题列表
  Future<ApiResponse> getTopics() {
    return _client.get('/tree-hole/topics');
  }

  /// 获取树洞详情
  Future<ApiResponse> getTreeHoleDetail(int id) {
    return _client.get('/tree-hole/$id');
  }

  /// 点赞/取消点赞
  Future<ApiResponse> toggleLike(int id) {
    return _client.post('/tree-hole/$id/like');
  }

  /// 评论树洞
  Future<ApiResponse> comment({
    required int treeHoleId,
    required String content,
    int? replyToId,
    String? replyAnonId,
  }) {
    return _client.post('/tree-hole/$treeHoleId/comment', data: {
      'content': content,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (replyAnonId != null) 'reply_anon_id': replyAnonId,
    });
  }

  /// 点赞评论
  Future<ApiResponse> toggleCommentLike(int commentId) {
    return _client.post('/tree-hole/comment/$commentId/like');
  }

  /// 删除树洞
  Future<ApiResponse> deleteTreeHole(int id) {
    return _client.delete('/tree-hole/$id');
  }

  /// 删除评论
  Future<ApiResponse> deleteComment(int commentId) {
    return _client.delete('/tree-hole/comment/$commentId');
  }

  /// 获取热门标签
  Future<ApiResponse> getHotTags({int limit = 20}) {
    return _client.get('/tree-hole/tags/hot', queryParameters: {'limit': limit.toString()});
  }

  /// 搜索标签
  Future<ApiResponse> searchTags(String keyword) {
    return _client.get('/tree-hole/tags/search', queryParameters: {'keyword': keyword});
  }
}

/// 树洞帖子模型
class TreeHolePost {
  final int id;
  final String anonymousId;
  final String content;
  final List<String> images;
  final String? topic;
  final List<String> tags;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final bool isHot;
  final bool isLiked;
  final List<TreeHoleComment> comments;
  final DateTime createdAt;

  TreeHolePost({
    required this.id,
    required this.anonymousId,
    required this.content,
    required this.images,
    this.topic,
    this.tags = const [],
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
    required this.isHot,
    required this.isLiked,
    required this.comments,
    required this.createdAt,
  });

  factory TreeHolePost.fromJson(Map<String, dynamic> json) {
    List<String> parseImages(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      return [];
    }

    return TreeHolePost(
      id: json['id'] ?? 0,
      anonymousId: json['anonymous_id'] ?? '',
      content: json['content'] ?? '',
      images: parseImages(json['images']),
      topic: json['topic'],
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      viewCount: json['view_count'] ?? 0,
      isHot: json['is_hot'] ?? false,
      isLiked: json['is_liked'] ?? false,
      comments: (json['comments'] as List?)
              ?.map((e) => TreeHoleComment.fromJson(e))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  TreeHolePost copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLiked,
    List<TreeHoleComment>? comments,
    List<String>? tags,
  }) {
    return TreeHolePost(
      id: id,
      anonymousId: anonymousId,
      content: content,
      images: images,
      topic: topic,
      tags: tags ?? this.tags,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      viewCount: viewCount,
      isHot: isHot,
      isLiked: isLiked ?? this.isLiked,
      comments: comments ?? this.comments,
      createdAt: createdAt,
    );
  }
}

/// 树洞评论模型
class TreeHoleComment {
  final int id;
  final String anonymousId;
  final String content;
  final int? replyToId;
  final String? replyAnonId;
  final bool isAuthor;
  final int likeCount;
  final bool isLiked;
  final DateTime createdAt;

  TreeHoleComment({
    required this.id,
    required this.anonymousId,
    required this.content,
    this.replyToId,
    this.replyAnonId,
    required this.isAuthor,
    required this.likeCount,
    required this.isLiked,
    required this.createdAt,
  });

  factory TreeHoleComment.fromJson(Map<String, dynamic> json) {
    return TreeHoleComment(
      id: json['id'] ?? 0,
      anonymousId: json['anonymous_id'] ?? '',
      content: json['content'] ?? '',
      replyToId: json['reply_to_id'],
      replyAnonId: json['reply_anon_id'],
      isAuthor: json['is_author'] ?? false,
      likeCount: json['like_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
