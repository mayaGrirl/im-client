/// 小视频播放器页面
/// TikTok风格全屏竖屏视频播放器
/// 使用VideoPreloadManager实现秒开和预加载

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/modules/small_video/models/small_video.dart';
import 'package:im_client/modules/small_video/providers/small_video_provider.dart';
import 'package:im_client/modules/small_video/services/video_preload_manager.dart';
import 'package:im_client/modules/small_video/screens/video_comment_sheet.dart';
import 'package:im_client/modules/small_video/screens/video_share_sheet.dart';
import 'package:im_client/modules/small_video/screens/video_paywall.dart';
import 'package:im_client/modules/small_video/screens/creator_profile_screen.dart';
import 'package:im_client/modules/livestream/screens/livestream_viewer_screen.dart';

class SmallVideoPlayerPage extends StatefulWidget {
  final SmallVideo video;
  final bool isActive;

  const SmallVideoPlayerPage({
    super.key,
    required this.video,
    this.isActive = false,
  });

  @override
  State<SmallVideoPlayerPage> createState() => _SmallVideoPlayerPageState();
}

class _SmallVideoPlayerPageState extends State<SmallVideoPlayerPage>
    with SingleTickerProviderStateMixin {
  final VideoPreloadManager _preloadManager = VideoPreloadManager();
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPaused = false;
  bool _showPlayIcon = false;
  bool _previewEnded = false;
  bool _isDisposed = false;
  bool _hasError = false;
  bool _isEmbedVideo = false; // 是否为嵌入式视频（YouTube/抖音等页面链接）
  int _watchStartTime = 0;

  // 播放图标动画
  late AnimationController _playIconAnimController;
  late Animation<double> _playIconAnim;

  @override
  void initState() {
    super.initState();
    _playIconAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _playIconAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _playIconAnimController, curve: Curves.easeOut),
    );
    _initVideo();
  }

  /// 控制器是否仍可用（未被PreloadManager淘汰/释放）
  bool get _isControllerUsable {
    if (_isDisposed || _controller == null) return false;
    // 如果PreloadManager已淘汰该控制器，则不再可用
    return _preloadManager.getController(widget.video.videoUrl) == _controller;
  }

  @override
  void didUpdateWidget(SmallVideoPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDisposed) return;

    // 检查控制器是否被PreloadManager淘汰，需要重新获取
    final currentController = _preloadManager.getController(widget.video.videoUrl);
    if (_controller != null && currentController != _controller) {
      // 控制器已被淘汰，重新初始化
      _controller = null;
      _isInitialized = false;
      if (widget.isActive) {
        // 延迟到下一帧，避免 _initVideo 中的 setState() 在 build 期间被调用
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed && mounted) _initVideo();
        });
      }
      return;
    }

    if (widget.isActive && !oldWidget.isActive) {
      _preloadManager.pauseAllExcept(widget.video.videoUrl);
      if (_isControllerUsable) {
        // 延迟到下一帧，避免在 build 过程中触发 VideoPlayerController 通知导致 setState() during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed && mounted && _isControllerUsable) {
            _controller!.setVolume(1.0);
            _controller!.play();
          }
        });
      } else if (_controller == null && !_hasError) {
        // 延迟到下一帧，避免 _initVideo 中的 setState() 在 build 期间被调用
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed && mounted) _initVideo();
        });
      }
      _watchStartTime = DateTime.now().millisecondsSinceEpoch;
    } else if (!widget.isActive && oldWidget.isActive) {
      if (_isControllerUsable) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed && _isControllerUsable) {
            _controller!.pause();
          }
        });
      }
      _reportWatch();
    }
  }

  /// 判断是否为网页URL（非视频文件），需要嵌入式播放
  static bool _isWebPageUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    // 本地路径或相对路径，不是页面URL
    if (!lower.startsWith('http')) return false;
    // 有视频文件扩展名的肯定不是页面
    if (_hasVideoExtension(lower)) return false;
    // 已知可直接下载视频的CDN域名
    const videoCDNs = [
      'pexels.com', 'pixabay.com', 'mixkit.co', 'coverr.co',
      'player.vimeo.com', 'cdn.', 'assets.',
    ];
    for (final cdn in videoCDNs) {
      if (lower.contains(cdn)) return false;
    }
    // 本服务器上传的文件
    if (lower.contains('/uploads/')) return false;
    // 到这里：外部http(s)链接 + 无视频扩展名 + 非CDN → 视为页面URL
    return true;
  }

  static bool _hasVideoExtension(String url) {
    const exts = ['.mp4', '.webm', '.mov', '.avi', '.m3u8', '.flv', '.mkv', '.ts'];
    for (final ext in exts) {
      if (url.contains(ext)) return true;
    }
    return false;
  }

  Future<void> _initVideo() async {
    final url = widget.video.videoUrl;

    // 检测嵌入式视频（YouTube/抖音等页面链接）
    if (_isWebPageUrl(url)) {
      if (!_isDisposed && mounted) {
        setState(() {
          _isEmbedVideo = true;
          _isInitialized = true;
        });
      }
      return;
    }

    // 已知失败的URL直接显示错误状态
    if (_preloadManager.isFailed(url)) {
      if (!_isDisposed && mounted) {
        setState(() => _hasError = true);
      }
      return;
    }

    _controller = _preloadManager.getController(url);
    if (_controller != null && _preloadManager.isInitialized(url)) {
      if (!_isDisposed && mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        _setupPreviewListener();
        if (widget.isActive && _isControllerUsable) {
          _preloadManager.pauseAllExcept(url);
          _controller!.seekTo(Duration.zero);
          _controller!.setVolume(1.0);
          _controller!.play();
          _watchStartTime = DateTime.now().millisecondsSinceEpoch;
        }
      }
      return;
    }

    try {
      _controller = await _preloadManager.initController(url);
      _setupPreviewListener();

      if (!_isDisposed && mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        if (widget.isActive && _isControllerUsable) {
          _preloadManager.pauseAllExcept(url);
          _controller!.setVolume(1.0);
          _controller!.play();
          _watchStartTime = DateTime.now().millisecondsSinceEpoch;
        }
      }
    } on TimeoutException {
      if (!_isDisposed && mounted) {
        setState(() => _hasError = true);
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  /// 重试加载视频
  void _retryVideo() {
    final url = widget.video.videoUrl;
    _preloadManager.resetFailed(url);
    setState(() {
      _hasError = false;
      _isInitialized = false;
      _controller = null;
    });
    _initVideo();
  }

  void _setupPreviewListener() {
    if (widget.video.isPaid && widget.video.previewDuration > 0) {
      _controller?.addListener(_checkPreviewDuration);
    }
  }

  void _checkPreviewDuration() {
    if (_previewEnded || _isDisposed || !_isControllerUsable) return;
    try {
      final position = _controller?.value.position;
      if (position != null && position.inSeconds >= widget.video.previewDuration) {
        _controller?.pause();
        if (mounted) {
          setState(() => _previewEnded = true);
        }
      }
    } catch (_) {
      // 控制器可能已被释放
    }
  }

  void _reportWatch() {
    if (_watchStartTime == 0) return;
    // dwellTime = 页面停留时长(wall-clock)
    final dwellTime = (DateTime.now().millisecondsSinceEpoch - _watchStartTime) ~/ 1000;
    if (dwellTime <= 0) return;

    // watchTime = 视频实际播放位置(秒)，需要检查控制器可用性
    int videoDuration = 0;
    int watchTime = 0;
    if (_isControllerUsable) {
      try {
        videoDuration = _controller!.value.duration.inSeconds;
        watchTime = _controller!.value.position.inSeconds;
      } catch (_) {
        // 控制器可能已被释放，使用默认值
      }
    }
    final isComplete = videoDuration > 0 && watchTime >= videoDuration - 1;

    if (!_isDisposed && mounted) {
      context.read<SmallVideoProvider>().recordView(
        widget.video.id,
        watchTime: watchTime,
        dwellTime: dwellTime,
        progress: videoDuration > 0 ? (watchTime * 100 ~/ videoDuration) : 0,
        isComplete: isComplete,
      );
    }
    _watchStartTime = 0;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reportWatch();
    try {
      _controller?.removeListener(_checkPreviewDuration);
    } catch (_) {
      // 控制器可能已被PreloadManager释放
    }
    _controller = null;
    _playIconAnimController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_hasError) {
      _retryVideo();
      return;
    }
    if (_previewEnded) return;
    if (!_isControllerUsable || !_isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPaused = true;
        _showPlayIcon = true;
        _playIconAnimController.forward(from: 0);
      } else {
        _controller!.play();
        _isPaused = false;
        _showPlayIcon = true;
        _playIconAnimController.forward(from: 0);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _showPlayIcon = false);
        });
      }
    });
  }

  void _onDoubleTap() {
    if (!widget.video.allowLike) return;
    final provider = context.read<SmallVideoProvider>();
    if (!widget.video.isLiked) {
      provider.toggleLike(widget.video.id);
    }
    setState(() => _showPlayIcon = false);
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VideoCommentSheet(
        videoId: widget.video.id,
        videoUserId: widget.video.userId,
      ),
    );
  }

  void _showShareSheet(SmallVideo video) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VideoShareSheet(video: video),
    );
  }

  void _navigateToCreator() {
    final user = widget.video.user;
    if (user != null && user.isLive && user.currentLivestreamId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LivestreamViewerScreen(
            livestreamId: user.currentLivestreamId!,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CreatorProfileScreen(
            userId: widget.video.userId,
          ),
        ),
      );
    }
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}w';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return EnvConfig.instance.getFileUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayPause,
      onDoubleTap: _onDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景
          Container(color: Colors.black),

          // 封面图（视频未加载时显示）+ 加载/错误状态
          if (!_isInitialized || !_isControllerUsable)
            _buildCoverOrLoading(video),

          // 加载失败错误提示
          if (_hasError && !_isInitialized)
            _buildErrorOverlay(),

          // 嵌入式视频（YouTube/抖音等）→ 显示封面+播放按钮
          if (_isEmbedVideo)
            _buildEmbedOverlay(video),

          // 视频播放器
          if (!_isEmbedVideo && _isInitialized && _isControllerUsable)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),

          // 暂停/播放动画图标
          if (_showPlayIcon)
            Center(
              child: FadeTransition(
                opacity: _playIconAnim,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Icon(
                    _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // 付费内容遮罩
          if (_previewEnded)
            VideoPaywall(
              price: video.price,
              onUnlock: () async {
                final provider = context.read<SmallVideoProvider>();
                final success = await provider.purchaseVideo(video.id);
                if (success && mounted) {
                  setState(() {
                    _previewEnded = false;
                    _controller?.seekTo(Duration.zero);
                    _controller?.play();
                  });
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.error ?? 'Purchase failed')),
                  );
                }
              },
            ),

          // 右侧操作栏（使用Selector只监听当前视频的互动状态变化）
          Positioned(
            right: 8,
            bottom: 140,
            child: Selector<SmallVideoProvider, _VideoInteractionState>(
              selector: (_, provider) => _selectInteractionState(provider, video.id),
              builder: (context, state, _) {
                final latestVideo = state.video ?? video;
                return _buildActionBar(latestVideo, context.read<SmallVideoProvider>());
              },
            ),
          ),

          // 底部信息
          Positioned(
            left: 16,
            right: 72,
            bottom: 32,
            child: _buildBottomInfo(video),
          ),

          // 底部进度条
          if (!_isEmbedVideo && _isInitialized && _isControllerUsable)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 2,
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: false,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white10,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoverOrLoading(SmallVideo video) {
    final coverUrl = _getFullUrl(video.coverUrl);
    return Stack(
      fit: StackFit.expand,
      children: [
        // 封面图
        if (coverUrl.isNotEmpty)
          Image.network(
            coverUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          ),
        // 加载中动画（非错误状态时显示）
        if (!_hasError)
          const Center(
            child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
          ),
      ],
    );
  }

  /// 嵌入式视频覆盖层：封面 + 来源标识 + 播放按钮
  Widget _buildEmbedOverlay(SmallVideo video) {
    final coverUrl = _getFullUrl(video.coverUrl);
    // 识别平台名
    final url = video.videoUrl.toLowerCase();
    String platform = '视频';
    if (url.contains('youtube') || url.contains('youtu.be')) {
      platform = 'YouTube';
    } else if (url.contains('douyin.com')) {
      platform = '抖音';
    } else if (url.contains('tiktok.com')) {
      platform = 'TikTok';
    } else if (url.contains('kuaishou.com')) {
      platform = '快手';
    } else if (url.contains('xiaohongshu.com')) {
      platform = '小红书';
    } else if (url.contains('bilibili.com')) {
      platform = 'Bilibili';
    } else if (url.contains('dailymotion.com')) {
      platform = 'Dailymotion';
    } else if (url.contains('facebook.com')) {
      platform = 'Facebook';
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 封面图
        if (coverUrl.isNotEmpty)
          Image.network(
            coverUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          ),
        // 半透明遮罩
        Container(color: Colors.black38),
        // 播放按钮 + 平台标识
        Center(
          child: GestureDetector(
            onTap: () async {
              final uri = Uri.parse(video.videoUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 12, spreadRadius: 2),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 48, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '在 $platform 中播放',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorOverlay() {
    return Center(
      child: GestureDetector(
        onTap: _retryVideo,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 36, color: Colors.white70),
              SizedBox(height: 8),
              Text(
                '视频加载失败',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                '点击重试',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 精确选择当前视频的互动状态（仅互动数据变化时才触发重建）
  _VideoInteractionState _selectInteractionState(SmallVideoProvider provider, int videoId) {
    SmallVideo? v;
    for (final item in provider.feedVideos) {
      if (item.id == videoId) { v = item; break; }
    }
    if (v == null) {
      for (final item in provider.hotVideos) {
        if (item.id == videoId) { v = item; break; }
      }
    }
    if (v == null) {
      for (final item in provider.followingVideos) {
        if (item.id == videoId) { v = item; break; }
      }
    }
    return _VideoInteractionState(
      video: v,
      isLiked: v?.isLiked ?? false,
      likeCount: v?.likeCount ?? 0,
      isCollected: v?.isCollected ?? false,
      collectCount: v?.collectCount ?? 0,
      commentCount: v?.commentCount ?? 0,
      shareCount: v?.shareCount ?? 0,
      isFollowing: v?.isFollowing ?? false,
    );
  }

  Widget _buildActionBar(SmallVideo video, SmallVideoProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 头像+关注
        GestureDetector(
          onTap: _navigateToCreator,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: video.user?.avatar.isNotEmpty == true
                          ? NetworkImage(_getFullUrl(video.user!.avatar))
                          : null,
                      onBackgroundImageError: video.user?.avatar.isNotEmpty == true ? (_, __) {} : null,
                      child: video.user?.avatar.isEmpty != false
                          ? const Icon(Icons.person, color: Colors.white54, size: 22)
                          : null,
                    ),
                  ),
                  if (!video.isFollowing)
                    Positioned(
                      bottom: -6,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () async {
                            final error = await provider.toggleFollow(video.userId);
                            if (error != null && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error)),
                              );
                            }
                          },
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF4081), Color(0xFFFF6B6B)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.add, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  // LIVE badge
                  if (video.user?.isLive == true)
                    Positioned(
                      bottom: -4,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white, width: 0.5),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 点赞
        if (video.allowLike) ...[
          _ActionButton(
            icon: video.isLiked ? Icons.favorite : Icons.favorite_border,
            color: video.isLiked ? const Color(0xFFFF4081) : Colors.white,
            label: _formatCount(video.likeCount),
            onTap: () => provider.toggleLike(video.id),
          ),
          const SizedBox(height: 20),
        ],

        // 评论
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          color: Colors.white,
          label: _formatCount(video.commentCount),
          onTap: _showComments,
        ),
        const SizedBox(height: 20),

        // 收藏
        _ActionButton(
          icon: video.isCollected ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: video.isCollected ? const Color(0xFFFFC107) : Colors.white,
          label: _formatCount(video.collectCount),
          onTap: () => provider.toggleCollect(video.id),
        ),
        const SizedBox(height: 20),

        // 分享
        _ActionButton(
          icon: Icons.reply_rounded,
          color: Colors.white,
          label: _formatCount(video.shareCount),
          onTap: () => _showShareSheet(video),
          iconTransform: true,
        ),
      ],
    );
  }

  Widget _buildBottomInfo(SmallVideo video) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 用户名
        GestureDetector(
          onTap: _navigateToCreator,
          child: Text(
            '@${video.user?.nickname ?? video.user?.username ?? ''}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(blurRadius: 6, color: Colors.black45),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 标题/描述
        if (video.title.isNotEmpty || video.description.isNotEmpty)
          Text(
            video.title.isNotEmpty ? video.title : video.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
              shadows: [Shadow(blurRadius: 6, color: Colors.black45)],
            ),
          ),

        // 标签
        if (video.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: video.tags.take(3).map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${tag.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ),

        // 位置
        if (video.locationName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.white70),
                const SizedBox(width: 2),
                Text(
                  video.locationName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 视频互动状态（用于Selector精确比较，仅互动数据变化才重建）
class _VideoInteractionState {
  final SmallVideo? video;
  final bool isLiked;
  final int likeCount;
  final bool isCollected;
  final int collectCount;
  final int commentCount;
  final int shareCount;
  final bool isFollowing;

  const _VideoInteractionState({
    this.video,
    required this.isLiked,
    required this.likeCount,
    required this.isCollected,
    required this.collectCount,
    required this.commentCount,
    required this.shareCount,
    required this.isFollowing,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _VideoInteractionState &&
          isLiked == other.isLiked &&
          likeCount == other.likeCount &&
          isCollected == other.isCollected &&
          collectCount == other.collectCount &&
          commentCount == other.commentCount &&
          shareCount == other.shareCount &&
          isFollowing == other.isFollowing;

  @override
  int get hashCode => Object.hash(isLiked, likeCount, isCollected, collectCount, commentCount, shareCount, isFollowing);
}

/// 右侧操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool iconTransform;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.iconTransform = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform(
            alignment: Alignment.center,
            transform: iconTransform
                ? (Matrix4.identity()..scale(-1.0, 1.0, 1.0))
                : Matrix4.identity(),
            child: Icon(
              icon,
              size: 30,
              color: color,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black38)],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
            ),
          ),
        ],
      ),
    );
  }
}
