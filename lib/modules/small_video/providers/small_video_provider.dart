/// 小视频状态管理

import 'package:flutter/foundation.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/modules/small_video/api/small_video_api.dart';
import 'package:im_client/modules/small_video/models/small_video.dart';

class SmallVideoProvider extends ChangeNotifier {
  static const int _pageSize = 20;
  final SmallVideoApi _api = SmallVideoApi(ApiClient());

  // Feed videos
  List<SmallVideo> _feedVideos = [];
  List<SmallVideo> _followingVideos = [];
  List<SmallVideo> _hotVideos = [];

  // Pagination
  int _feedPage = 1;
  int _followingPage = 1;
  int _hotPage = 1;
  bool _feedHasMore = true;
  bool _followingHasMore = true;
  bool _hotHasMore = true;

  // State - separate loading flags for each tab
  bool _isFeedLoading = false;
  bool _isFollowingLoading = false;
  bool _isHotLoading = false;
  String? _error;

  // Categories
  List<SmallVideoCategory> _categories = [];

  // Getters
  List<SmallVideo> get feedVideos => _feedVideos;
  List<SmallVideo> get followingVideos => _followingVideos;
  List<SmallVideo> get hotVideos => _hotVideos;
  bool get isLoading => _isFeedLoading || _isFollowingLoading || _isHotLoading;
  bool get isFeedLoading => _isFeedLoading;
  bool get isFollowingLoading => _isFollowingLoading;
  bool get isHotLoading => _isHotLoading;
  String? get error => _error;
  bool get feedHasMore => _feedHasMore;
  bool get followingHasMore => _followingHasMore;
  bool get hotHasMore => _hotHasMore;
  List<SmallVideoCategory> get categories => _categories;

  // ==================== Feed ====================

  /// 加载推荐视频流
  Future<void> loadFeed({bool refresh = false}) async {
    if (_isFeedLoading) return;
    if (refresh) {
      _feedPage = 1;
      _feedHasMore = true;
    }
    if (!_feedHasMore && !refresh) return;

    _isFeedLoading = true;
    _error = null;
    // 分页加载时不通知（避免PageView在滑动手势中重建导致滑动中断）
    // 只在首次加载（空列表）时通知以显示loading状态
    if (_feedVideos.isEmpty) {
      notifyListeners();
    }

    try {
      final response = await _api.getVideoFeed(page: _feedPage);
      if (response.success && response.data != null) {
        final list = _parseVideoList(response.data);
        if (refresh) {
          _feedVideos = list;
        } else {
          // 客户端去重：排除已存在的视频ID
          final existingIds = _feedVideos.map((v) => v.id).toSet();
          final newVideos = list.where((v) => !existingIds.contains(v.id)).toList();
          _feedVideos.addAll(newVideos);
        }
        _feedHasMore = list.length >= _pageSize;
        _feedPage++;
      } else {
        _error = response.message;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isFeedLoading = false;
    notifyListeners();
  }

  /// 加载更多推荐
  Future<void> loadMoreFeed() async {
    if (_feedHasMore) {
      await loadFeed();
    }
  }

  /// 加载关注视频
  Future<void> loadFollowingVideos({bool refresh = false}) async {
    if (_isFollowingLoading) return;
    if (refresh) {
      _followingPage = 1;
      _followingHasMore = true;
    }
    if (!_followingHasMore && !refresh) return;

    _isFollowingLoading = true;
    if (_followingVideos.isEmpty) {
      notifyListeners();
    }

    try {
      final response = await _api.getFollowingVideos(page: _followingPage);
      if (response.success && response.data != null) {
        final list = _parseVideoList(response.data);
        if (refresh) {
          _followingVideos = list;
        } else {
          _followingVideos.addAll(list);
        }
        _followingHasMore = list.length >= _pageSize;
        _followingPage++;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isFollowingLoading = false;
    notifyListeners();
  }

  /// 加载热门视频
  Future<void> loadHotVideos({bool refresh = false}) async {
    if (_isHotLoading) return;
    if (refresh) {
      _hotPage = 1;
      _hotHasMore = true;
    }
    if (!_hotHasMore && !refresh) return;

    _isHotLoading = true;
    if (_hotVideos.isEmpty) {
      notifyListeners();
    }

    try {
      final response = await _api.getHotVideos(page: _hotPage);
      if (response.success && response.data != null) {
        final list = _parseVideoList(response.data);
        if (refresh) {
          _hotVideos = list;
        } else {
          _hotVideos.addAll(list);
        }
        _hotHasMore = list.length >= _pageSize;
        _hotPage++;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isHotLoading = false;
    notifyListeners();
  }

  // ==================== 互动（乐观更新） ====================

  /// 切换点赞
  Future<void> toggleLike(int videoId) async {
    final index = _findVideoIndex(videoId);
    if (index == -1) return;

    final video = _getVideoAt(index);
    final wasLiked = video.isLiked;

    // 乐观更新
    _updateVideo(index, video.copyWith(
      isLiked: !wasLiked,
      likeCount: wasLiked ? video.likeCount - 1 : video.likeCount + 1,
    ));
    notifyListeners();

    try {
      final response = wasLiked
          ? await _api.unlikeVideo(videoId)
          : await _api.likeVideo(videoId);
      if (!response.success) {
        // 回滚
        _updateVideo(index, video);
        notifyListeners();
      }
    } catch (e) {
      _updateVideo(index, video);
      notifyListeners();
    }
  }

  /// 切换收藏
  Future<void> toggleCollect(int videoId) async {
    final index = _findVideoIndex(videoId);
    if (index == -1) return;

    final video = _getVideoAt(index);
    final wasCollected = video.isCollected;

    _updateVideo(index, video.copyWith(
      isCollected: !wasCollected,
      collectCount: wasCollected ? video.collectCount - 1 : video.collectCount + 1,
    ));
    notifyListeners();

    try {
      final response = wasCollected
          ? await _api.uncollectVideo(videoId)
          : await _api.collectVideo(videoId);
      if (!response.success) {
        _updateVideo(index, video);
        notifyListeners();
      }
    } catch (e) {
      _updateVideo(index, video);
      notifyListeners();
    }
  }

  /// 切换关注，返回错误消息（null表示成功）
  Future<String?> toggleFollow(int creatorId) async {
    // 更新所有列表中该创作者的视频
    bool wasFollowing = false;
    for (var i = 0; i < _feedVideos.length; i++) {
      if (_feedVideos[i].userId == creatorId) {
        wasFollowing = _feedVideos[i].isFollowing;
        _feedVideos[i] = _feedVideos[i].copyWith(isFollowing: !wasFollowing);
      }
    }
    for (var i = 0; i < _hotVideos.length; i++) {
      if (_hotVideos[i].userId == creatorId) {
        _hotVideos[i] = _hotVideos[i].copyWith(isFollowing: !wasFollowing);
      }
    }
    for (var i = 0; i < _followingVideos.length; i++) {
      if (_followingVideos[i].userId == creatorId) {
        _followingVideos[i] = _followingVideos[i].copyWith(isFollowing: !wasFollowing);
      }
    }
    notifyListeners();

    try {
      final response = wasFollowing
          ? await _api.unfollowCreator(creatorId)
          : await _api.followCreator(creatorId);
      if (!response.success) {
        // 回滚
        _rollbackFollow(creatorId, wasFollowing);
        return response.message ?? 'Operation failed';
      }
    } catch (e) {
      // 回滚
      _rollbackFollow(creatorId, wasFollowing);
      return e.toString();
    }
    return null;
  }

  /// 外部模块通知关注状态变化（不发API，仅同步本地列表）
  void updateFollowState(int creatorId, bool isFollowing) {
    bool changed = false;
    for (var i = 0; i < _feedVideos.length; i++) {
      if (_feedVideos[i].userId == creatorId && _feedVideos[i].isFollowing != isFollowing) {
        _feedVideos[i] = _feedVideos[i].copyWith(isFollowing: isFollowing);
        changed = true;
      }
    }
    for (var i = 0; i < _hotVideos.length; i++) {
      if (_hotVideos[i].userId == creatorId && _hotVideos[i].isFollowing != isFollowing) {
        _hotVideos[i] = _hotVideos[i].copyWith(isFollowing: isFollowing);
        changed = true;
      }
    }
    for (var i = 0; i < _followingVideos.length; i++) {
      if (_followingVideos[i].userId == creatorId && _followingVideos[i].isFollowing != isFollowing) {
        _followingVideos[i] = _followingVideos[i].copyWith(isFollowing: isFollowing);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void _rollbackFollow(int creatorId, bool wasFollowing) {
    for (var i = 0; i < _feedVideos.length; i++) {
      if (_feedVideos[i].userId == creatorId) {
        _feedVideos[i] = _feedVideos[i].copyWith(isFollowing: wasFollowing);
      }
    }
    for (var i = 0; i < _hotVideos.length; i++) {
      if (_hotVideos[i].userId == creatorId) {
        _hotVideos[i] = _hotVideos[i].copyWith(isFollowing: wasFollowing);
      }
    }
    for (var i = 0; i < _followingVideos.length; i++) {
      if (_followingVideos[i].userId == creatorId) {
        _followingVideos[i] = _followingVideos[i].copyWith(isFollowing: wasFollowing);
      }
    }
    notifyListeners();
  }

  /// 分享视频
  Future<void> shareVideo(int videoId, {String? platform}) async {
    final index = _findVideoIndex(videoId);
    if (index == -1) return;

    final video = _getVideoAt(index);

    // 乐观更新
    _updateVideo(index, video.copyWith(
      shareCount: video.shareCount + 1,
    ));
    notifyListeners();

    try {
      final response = await _api.shareVideo(videoId, platform: platform);
      if (!response.success) {
        _updateVideo(index, video);
        notifyListeners();
      }
    } catch (e) {
      _updateVideo(index, video);
      notifyListeners();
    }
  }

  /// 增加评论数
  void incrementCommentCount(int videoId) {
    final index = _findVideoIndex(videoId);
    if (index == -1) return;
    final video = _getVideoAt(index);
    _updateVideo(index, video.copyWith(commentCount: video.commentCount + 1));
    notifyListeners();
  }

  /// 同步评论数（用API返回的实际数量覆盖本地缓存）
  void syncCommentCount(int videoId, int actualCount) {
    final index = _findVideoIndex(videoId);
    if (index == -1) return;
    final video = _getVideoAt(index);
    if (video.commentCount != actualCount) {
      _updateVideo(index, video.copyWith(commentCount: actualCount));
      notifyListeners();
    }
  }

  // ==================== 发布 ====================

  /// 发布视频
  Future<bool> publishVideo({
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
    List<String>? tags,
    int visibility = 0,
    String? locationName,
    double? latitude,
    double? longitude,
    bool allowComment = true,
    bool allowDuet = true,
    bool allowStitch = true,
    bool allowLike = true,
    bool allowSave = true,
    bool isPaid = false,
    int price = 0,
    int previewDuration = 0,
    int coverTime = 0,
  }) async {
    try {
      final response = await _api.publishVideo(
        videoUrl: videoUrl,
        title: title,
        description: description,
        coverUrl: coverUrl,
        duration: duration,
        width: width,
        height: height,
        fileSize: fileSize,
        categoryId: categoryId,
        musicId: musicId,
        tags: tags,
        visibility: visibility,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        allowComment: allowComment,
        allowDuet: allowDuet,
        allowStitch: allowStitch,
        allowLike: allowLike,
        allowSave: allowSave,
        isPaid: isPaid,
        price: price,
        previewDuration: previewDuration,
        coverTime: coverTime,
      );
      if (response.success) {
        // 刷新feed
        await loadFeed(refresh: true);
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }
    return false;
  }

  // ==================== 观看记录 ====================

  /// 上报观看记录（异步，不阻塞UI）
  Future<void> recordView(int videoId, {int watchTime = 0, int dwellTime = 0, int progress = 0, bool isComplete = false}) async {
    try {
      await _api.recordView(videoId, watchTime: watchTime, dwellTime: dwellTime, progress: progress, isComplete: isComplete);
    } catch (_) {
      // 静默失败，不影响用户体验
    }
  }

  // ==================== 付费购买 ====================

  /// 购买付费视频
  Future<bool> purchaseVideo(int videoId) async {
    try {
      final response = await _api.purchaseVideo(videoId);
      if (response.success) {
        return true;
      }
      _error = response.message;
    } catch (e) {
      _error = e.toString();
    }
    return false;
  }

  // ==================== 搜索 ====================

  /// 搜索视频
  Future<List<SmallVideo>> searchVideos(String keyword, {int page = 1}) async {
    try {
      final response = await _api.searchVideos(keyword, page: page);
      if (response.success && response.data != null) {
        return _parseVideoList(response.data);
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  // ==================== 分类 ====================

  /// 加载分类
  Future<void> loadCategories() async {
    try {
      final response = await _api.getCategories();
      if (response.success && response.data != null) {
        final data = response.data;
        if (data is List) {
          _categories = data.map((e) => SmallVideoCategory.fromJson(e)).toList();
        }
        notifyListeners();
      }
    } catch (e) {
      // ignore
    }
  }

  // ==================== 辅助方法 ====================

  List<SmallVideo> _parseVideoList(dynamic data) {
    if (data is List) {
      return data.map((e) => SmallVideo.fromJson(e)).toList();
    }
    if (data is Map) {
      final list = data['list'];
      if (list is List) {
        return list.map((e) => SmallVideo.fromJson(e)).toList();
      }
    }
    return [];
  }

  int _findVideoIndex(int videoId) {
    var idx = _feedVideos.indexWhere((v) => v.id == videoId);
    if (idx != -1) return idx;
    idx = _followingVideos.indexWhere((v) => v.id == videoId);
    if (idx != -1) return idx + 100000; // offset to distinguish lists
    idx = _hotVideos.indexWhere((v) => v.id == videoId);
    if (idx != -1) return idx + 200000;
    return -1;
  }

  SmallVideo _getVideoAt(int index) {
    if (index < 100000) return _feedVideos[index];
    if (index < 200000) return _followingVideos[index - 100000];
    return _hotVideos[index - 200000];
  }

  void _updateVideo(int index, SmallVideo video) {
    if (index < 100000) {
      _feedVideos[index] = video;
    } else if (index < 200000) {
      _followingVideos[index - 100000] = video;
    } else {
      _hotVideos[index - 200000] = video;
    }
  }
}
