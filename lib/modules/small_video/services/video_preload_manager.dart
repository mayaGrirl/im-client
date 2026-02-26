/// 视频预加载管理器
/// 模仿抖音的播放体验：3控制器池(prev/current/next)，预加载+秒开+智能丢弃
/// 增加超时控制、错误追踪和重试机制

import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:im_client/modules/small_video/models/small_video.dart';

/// 视频预加载管理器 - 单例
/// 维护3个控制器：上一个、当前、下一个
/// 滑动时复用控制器，实现秒级切换
class VideoPreloadManager {
  static final VideoPreloadManager _instance = VideoPreloadManager._();
  factory VideoPreloadManager() => _instance;
  VideoPreloadManager._();

  /// 控制器缓存 key=videoUrl
  final Map<String, VideoPlayerController> _controllers = {};

  /// 当前活跃的视频URL列表（最多保留3个）
  final List<String> _activeUrls = [];

  /// 初始化状态追踪
  final Map<String, bool> _initStatus = {};

  /// 初始化失败的URL（避免反复重试无效URL）
  final Map<String, int> _failedUrls = {};

  /// 最大缓存控制器数量
  static const int _maxControllers = 3;

  /// 初始化超时时间
  static const Duration _initTimeout = Duration(seconds: 10);

  /// 最大重试次数
  static const int _maxRetries = 2;

  /// 获取或创建控制器
  /// 如果已缓存则直接返回（秒开），否则创建新的
  VideoPlayerController? getController(String videoUrl) {
    return _controllers[videoUrl];
  }

  /// 是否已初始化
  bool isInitialized(String videoUrl) {
    return _initStatus[videoUrl] == true;
  }

  /// 是否初始化失败
  bool isFailed(String videoUrl) {
    return _initStatus[videoUrl] == false && (_failedUrls[videoUrl] ?? 0) >= _maxRetries;
  }

  /// 初始化控制器（如果尚未初始化），带超时保护
  Future<VideoPlayerController> initController(String videoUrl, {bool looping = true}) async {
    // 已有且已初始化则返回
    if (_controllers.containsKey(videoUrl)) {
      final ctrl = _controllers[videoUrl]!;
      if (ctrl.value.isInitialized) {
        _initStatus[videoUrl] = true;
        ctrl.setVolume(1.0);
        return ctrl;
      }
      // 如果存在但未初始化，带超时等待初始化
      try {
        await ctrl.initialize().timeout(_initTimeout);
        ctrl.setLooping(looping);
        ctrl.setVolume(1.0);
        _initStatus[videoUrl] = true;
        _failedUrls.remove(videoUrl);
      } on TimeoutException {
        _initStatus[videoUrl] = false;
        _failedUrls[videoUrl] = (_failedUrls[videoUrl] ?? 0) + 1;
        // 超时后释放控制器，避免资源泄露
        _disposeController(videoUrl);
        rethrow;
      } catch (_) {
        _initStatus[videoUrl] = false;
        _failedUrls[videoUrl] = (_failedUrls[videoUrl] ?? 0) + 1;
      }
      return ctrl;
    }

    // 已达到最大重试次数，不再尝试
    if ((_failedUrls[videoUrl] ?? 0) >= _maxRetries) {
      throw TimeoutException('Video failed after $_maxRetries retries: $videoUrl');
    }

    // 创建新控制器（token 已在 URL query param 中，无需自定义 header）
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _controllers[videoUrl] = controller;

    // 追踪活跃URL
    if (!_activeUrls.contains(videoUrl)) {
      _activeUrls.add(videoUrl);
    }

    // 淘汰超出限制的旧控制器
    _evictOldControllers();

    try {
      await controller.initialize().timeout(_initTimeout);
      controller.setLooping(looping);
      controller.setVolume(1.0);
      _initStatus[videoUrl] = true;
      _failedUrls.remove(videoUrl);
    } on TimeoutException {
      _initStatus[videoUrl] = false;
      _failedUrls[videoUrl] = (_failedUrls[videoUrl] ?? 0) + 1;
      // 超时后释放控制器
      _disposeController(videoUrl);
      rethrow;
    } catch (_) {
      _initStatus[videoUrl] = false;
      _failedUrls[videoUrl] = (_failedUrls[videoUrl] ?? 0) + 1;
    }

    return controller;
  }

  /// 重置某个URL的失败计数，允许重新加载
  void resetFailed(String videoUrl) {
    _failedUrls.remove(videoUrl);
    _initStatus.remove(videoUrl);
  }

  /// 预加载视频（只创建控制器并初始化，不播放）
  Future<void> preload(String videoUrl) async {
    if (_controllers.containsKey(videoUrl) && _initStatus[videoUrl] == true) {
      return; // 已预加载
    }
    // 不预加载已失败的URL
    if ((_failedUrls[videoUrl] ?? 0) >= _maxRetries) {
      return;
    }
    try {
      await initController(videoUrl);
    } catch (_) {
      // 预加载失败不影响当前播放
    }
  }

  /// 页面切换时调用 - 更新预加载策略
  /// currentIndex: 当前页面索引
  /// videos: 视频列表
  void onPageChanged(int currentIndex, List<SmallVideo> videos) {
    if (videos.isEmpty) return;

    // 收集需要保留的URL（prev + current + next）
    final keepUrls = <String>[];

    // 当前
    if (currentIndex >= 0 && currentIndex < videos.length) {
      keepUrls.add(videos[currentIndex].videoUrl);
    }

    // 下一个 - 优先预加载
    if (currentIndex + 1 < videos.length) {
      final nextUrl = videos[currentIndex + 1].videoUrl;
      keepUrls.add(nextUrl);
      // 异步预加载下一个视频
      preload(nextUrl);
    }

    // 上一个
    if (currentIndex - 1 >= 0) {
      final prevUrl = videos[currentIndex - 1].videoUrl;
      keepUrls.add(prevUrl);
    }

    // 更新活跃列表
    _activeUrls.clear();
    _activeUrls.addAll(keepUrls);

    // 丢弃距离超过1的视频控制器
    _evictOldControllers();
  }

  /// 暂停所有非当前视频
  void pauseAllExcept(String? currentUrl) {
    for (final entry in _controllers.entries) {
      if (entry.key != currentUrl) {
        try {
          if (entry.value.value.isInitialized && entry.value.value.isPlaying) {
            entry.value.pause();
          }
        } catch (_) {
          // 控制器可能已被释放，忽略
        }
      }
    }
  }

  /// 淘汰超出限制的旧控制器
  void _evictOldControllers() {
    // 获取不在活跃列表中的URL
    final toRemove = _controllers.keys
        .where((url) => !_activeUrls.contains(url))
        .toList();

    for (final url in toRemove) {
      _disposeController(url);
    }

    // 如果活跃列表仍超限，从头部淘汰
    while (_activeUrls.length > _maxControllers) {
      final url = _activeUrls.removeAt(0);
      _disposeController(url);
    }
  }

  /// 释放单个控制器
  void _disposeController(String url) {
    final controller = _controllers.remove(url);
    _initStatus.remove(url);
    _activeUrls.remove(url);
    try {
      controller?.dispose();
    } catch (_) {
      // 忽略释放异常
    }
  }

  /// 释放所有控制器
  void disposeAll() {
    for (final controller in _controllers.values) {
      try {
        controller.dispose();
      } catch (_) {}
    }
    _controllers.clear();
    _initStatus.clear();
    _activeUrls.clear();
    _failedUrls.clear();
  }

  /// 获取当前缓存的控制器数量（调试用）
  int get controllerCount => _controllers.length;
}
