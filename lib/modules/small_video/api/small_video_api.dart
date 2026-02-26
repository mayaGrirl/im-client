/// 小视频API
import 'package:im_client/api/api_client.dart';

class SmallVideoApi {
  final ApiClient _client;

  SmallVideoApi(this._client);

  // ==================== 视频流 ====================

  /// 获取推荐视频流
  Future<ApiResponse> getVideoFeed({int page = 1, int pageSize = 20}) {
    return _client.get('/smallvideo/feed', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 获取关注的视频
  Future<ApiResponse> getFollowingVideos({int page = 1, int pageSize = 20}) {
    return _client.get('/smallvideo/following', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 获取热门视频
  Future<ApiResponse> getHotVideos({int page = 1, int pageSize = 20}) {
    return _client.get('/smallvideo/hot', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 搜索视频
  Future<ApiResponse> searchVideos(String keyword, {int page = 1, int pageSize = 20}) {
    return _client.get('/smallvideo/search', queryParameters: {
      'keyword': keyword,
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  // ==================== 视频详情 ====================

  /// 获取视频详情
  Future<ApiResponse> getVideo(int id) {
    return _client.get('/smallvideo/$id');
  }

  /// 获取我的视频（含私密/仅好友可见）
  Future<ApiResponse> getMyVideos({int page = 1, int pageSize = 20}) {
    return _client.get('/smallvideo/my', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 获取用户视频列表
  Future<ApiResponse> getUserVideos(int userId, {int page = 1, int pageSize = 20}) {
    return _client.get('/smallvideo/user/$userId', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  // ==================== 发布/删除 ====================

  /// 发布视频
  Future<ApiResponse> publishVideo({
    required String videoUrl,
    String? title,
    String? description,
    String? coverUrl,
    int? duration,
    int? width,
    int? height,
    int? fileSize,
    int? categoryId,
    int? musicId,
    int visibility = 0,
    String? locationName,
    double? latitude,
    double? longitude,
    List<String>? tags,
    bool allowComment = true,
    bool allowDuet = true,
    bool allowStitch = true,
    bool allowSave = true,
    bool allowLike = true,
    bool isPaid = false,
    int price = 0,
    int previewDuration = 0,
    int coverTime = 0,
  }) {
    return _client.post('/smallvideo', data: {
      'video_url': videoUrl,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (duration != null) 'duration': duration,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (fileSize != null) 'file_size': fileSize,
      if (categoryId != null) 'category_id': categoryId,
      if (musicId != null) 'music_id': musicId,
      'visibility': visibility,
      if (locationName != null) 'location_name': locationName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (tags != null) 'tags': tags,
      'allow_comment': allowComment,
      'allow_duet': allowDuet,
      'allow_stitch': allowStitch,
      'allow_save': allowSave,
      'allow_like': allowLike,
      'is_paid': isPaid,
      'price': price,
      'preview_duration': previewDuration,
      if (coverTime > 0) 'cover_time': coverTime,
    });
  }

  /// 删除视频
  Future<ApiResponse> deleteVideo(int id) {
    return _client.delete('/smallvideo/$id');
  }

  // ==================== 互动 ====================

  /// 点赞视频
  Future<ApiResponse> likeVideo(int id) {
    return _client.post('/smallvideo/$id/like');
  }

  /// 取消点赞
  Future<ApiResponse> unlikeVideo(int id) {
    return _client.delete('/smallvideo/$id/like');
  }

  /// 收藏视频
  Future<ApiResponse> collectVideo(int id, {int? folderId}) {
    return _client.post('/smallvideo/$id/collect', data: {
      if (folderId != null) 'folder_id': folderId,
    });
  }

  /// 取消收藏
  Future<ApiResponse> uncollectVideo(int id) {
    return _client.delete('/smallvideo/$id/collect');
  }

  /// 分享视频
  Future<ApiResponse> shareVideo(int id, {String? platform}) {
    return _client.post('/smallvideo/$id/share', data: {
      if (platform != null) 'platform': platform,
    });
  }

  /// 举报视频
  Future<ApiResponse> reportVideo(int id, {required String reason, String? description}) {
    return _client.post('/smallvideo/$id/report', data: {
      'reason': reason,
      if (description != null) 'description': description,
    });
  }

  /// 记录观看
  Future<ApiResponse> recordView(int id, {int? watchTime, int? dwellTime, int? progress, bool? isComplete}) {
    return _client.post('/smallvideo/$id/view', data: {
      if (watchTime != null) 'watch_time': watchTime,
      if (dwellTime != null && dwellTime > 0) 'dwell_time': dwellTime,
      if (progress != null) 'progress': progress,
      if (isComplete != null) 'is_complete': isComplete,
    });
  }

  // ==================== 评论 ====================

  /// 获取评论列表
  Future<ApiResponse> getComments(int videoId, {int page = 1, int pageSize = 20}) {
    return _client.get('/smallvideo/$videoId/comments', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 发表评论
  Future<ApiResponse> createComment(int videoId, {
    required String content,
    int? parentId,
    int? replyToUid,
  }) {
    return _client.post('/smallvideo/$videoId/comment', data: {
      'content': content,
      if (parentId != null) 'parent_id': parentId,
      if (replyToUid != null) 'reply_to_uid': replyToUid,
    });
  }

  /// 获取评论回复
  Future<ApiResponse> getReplies(int commentId, {int page = 1, int pageSize = 20}) {
    return _client.get('/smallvideo/comment/$commentId/replies', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 点赞评论
  Future<ApiResponse> likeComment(int commentId) {
    return _client.post('/smallvideo/comment/$commentId/like');
  }

  /// 取消点赞评论
  Future<ApiResponse> unlikeComment(int commentId) {
    return _client.delete('/smallvideo/comment/$commentId/like');
  }

  // ==================== 创作者 ====================

  /// 关注创作者
  Future<ApiResponse> followCreator(int creatorId) {
    return _client.post('/smallvideo/creator/$creatorId/follow');
  }

  /// 取消关注
  Future<ApiResponse> unfollowCreator(int creatorId) {
    return _client.delete('/smallvideo/creator/$creatorId/follow');
  }

  /// 获取创作者统计
  Future<ApiResponse> getCreatorStats(int creatorId) {
    return _client.get('/smallvideo/creator/$creatorId/stats');
  }

  // ==================== 置顶/画像 ====================

  /// 切换视频置顶
  Future<ApiResponse> toggleVideoTop(int id) {
    return _client.put('/smallvideo/$id/top');
  }

  /// 获取创作者画像
  Future<ApiResponse> getCreatorAnalytics(int creatorId) {
    return _client.get('/smallvideo/creator/$creatorId/analytics');
  }

  // ==================== 付费购买 ====================

  /// 购买付费视频
  Future<ApiResponse> purchaseVideo(int videoId) {
    return _client.post('/smallvideo/$videoId/purchase');
  }

  /// 检查是否已购买
  Future<ApiResponse> checkPurchased(int videoId) {
    return _client.get('/smallvideo/$videoId/purchased');
  }

  // ==================== 分类/标签 ====================

  /// 获取分类列表
  Future<ApiResponse> getCategories() {
    return _client.get('/smallvideo/categories');
  }

  /// 获取热门标签
  Future<ApiResponse> getHotTags({int page = 1, int pageSize = 20, String? lang}) {
    return _client.get('/smallvideo/tags/hot', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
      if (lang != null) 'lang': lang,
    });
  }

  /// 搜索标签
  Future<ApiResponse> searchTags({required String keyword, int page = 1, int pageSize = 20}) {
    return _client.get('/smallvideo/tags/search', queryParameters: {
      'keyword': keyword,
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 获取音乐列表
  Future<ApiResponse> getMusics({int page = 1, int pageSize = 20}) {
    return _client.get('/smallvideo/musics', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }
}
