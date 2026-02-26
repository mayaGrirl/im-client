/// 小视频列表页面
/// TikTok风格竖滑视频流
/// 集成VideoPreloadManager实现预加载和丝滑切换

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/modules/small_video/providers/small_video_provider.dart';
import 'package:im_client/modules/small_video/models/small_video.dart';
import 'package:im_client/modules/small_video/services/video_preload_manager.dart';
import 'package:im_client/modules/small_video/screens/small_video_player_page.dart';
import 'package:im_client/modules/small_video/screens/publish_video_screen.dart';
import 'package:im_client/modules/small_video/screens/video_search_screen.dart';
import 'package:im_client/modules/small_video/screens/creator_profile_screen.dart';
import 'package:im_client/providers/auth_provider.dart';

class SmallVideoListScreen extends StatefulWidget {
  const SmallVideoListScreen({super.key});

  @override
  State<SmallVideoListScreen> createState() => _SmallVideoListScreenState();
}

class _SmallVideoListScreenState extends State<SmallVideoListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PageController _feedPageController = PageController();
  final PageController _followingPageController = PageController();
  final PageController _hotPageController = PageController();
  final VideoPreloadManager _preloadManager = VideoPreloadManager();

  int _feedCurrentIndex = 0;
  int _followingCurrentIndex = 0;
  int _hotCurrentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    // 沉浸式状态栏
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // 加载初始数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SmallVideoProvider>();
      provider.loadFeed(refresh: true);
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    final provider = context.read<SmallVideoProvider>();
    switch (_tabController.index) {
      case 1:
        if (provider.hotVideos.isEmpty) {
          provider.loadHotVideos(refresh: true);
        }
        break;
      case 2:
        if (provider.followingVideos.isEmpty) {
          provider.loadFollowingVideos(refresh: true);
        }
        break;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedPageController.dispose();
    _followingPageController.dispose();
    _hotPageController.dispose();
    _preloadManager.disposeAll();
    super.dispose();
  }

  void _onPageChanged(int index, List<SmallVideo> videos) {
    _preloadManager.onPageChanged(index, videos);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 视频内容
          TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildFeedTab(l10n),
              _buildHotTab(l10n),
              _buildFollowingTab(l10n),
            ],
          ),

          // 顶部渐变遮罩 + TabBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      // 返回按钮
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 22,
                      ),
                      // 搜索按钮
                      IconButton(
                        icon: const Icon(Icons.search_rounded, color: Colors.white, size: 26),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const VideoSearchScreen()),
                          );
                        },
                        splashRadius: 22,
                      ),
                      // Tab切换
                      Expanded(
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.white,
                          indicatorSize: TabBarIndicatorSize.label,
                          indicatorWeight: 2.5,
                          indicatorPadding: const EdgeInsets.only(bottom: 4),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white54,
                          labelStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                          dividerColor: Colors.transparent,
                          splashFactory: NoSplash.splashFactory,
                          overlayColor: WidgetStateProperty.all(Colors.transparent),
                          tabs: [
                            Tab(text: l10n.translate('sv_recommended')),
                            Tab(text: l10n.translate('sv_hot')),
                            Tab(text: l10n.translate('sv_following')),
                          ],
                        ),
                      ),
                      // 个人主页按钮
                      IconButton(
                        icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 26),
                        onPressed: () {
                          final userId = context.read<AuthProvider>().userId;
                          if (userId > 0) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CreatorProfileScreen(userId: userId),
                              ),
                            );
                          }
                        },
                        splashRadius: 22,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 发布按钮 - TikTok风格
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PublishVideoScreen()),
                );
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF07C160), Color(0xFF06AD56)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF07C160).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedTab(AppLocalizations l10n) {
    return Consumer<SmallVideoProvider>(
      builder: (context, provider, _) {
        if (provider.feedVideos.isEmpty && provider.isFeedLoading) {
          return _buildLoadingState();
        }

        if (provider.feedVideos.isEmpty) {
          return _buildEmptyState(
            icon: Icons.play_circle_outline_rounded,
            message: l10n.translate('sv_no_videos'),
            onRetry: () => provider.loadFeed(refresh: true),
            l10n: l10n,
          );
        }

        return _buildVideoPageView(
          provider.feedVideos,
          _feedPageController,
          _feedCurrentIndex,
          (index) {
            if (_feedCurrentIndex != index) {
              setState(() => _feedCurrentIndex = index);
            }
            _onPageChanged(index, provider.feedVideos);
            if (index >= provider.feedVideos.length - 3) {
              provider.loadMoreFeed();
            }
          },
        );
      },
    );
  }

  Widget _buildFollowingTab(AppLocalizations l10n) {
    return Consumer<SmallVideoProvider>(
      builder: (context, provider, _) {
        if (provider.followingVideos.isEmpty && provider.isFollowingLoading) {
          return _buildLoadingState();
        }

        if (provider.followingVideos.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline_rounded,
            message: l10n.translate('sv_no_videos'),
            onRetry: () => provider.loadFollowingVideos(refresh: true),
            l10n: l10n,
          );
        }

        return _buildVideoPageView(
          provider.followingVideos,
          _followingPageController,
          _followingCurrentIndex,
          (index) {
            if (_followingCurrentIndex != index) {
              setState(() => _followingCurrentIndex = index);
            }
            _onPageChanged(index, provider.followingVideos);
            if (index >= provider.followingVideos.length - 3) {
              provider.loadFollowingVideos();
            }
          },
        );
      },
    );
  }

  Widget _buildHotTab(AppLocalizations l10n) {
    return Consumer<SmallVideoProvider>(
      builder: (context, provider, _) {
        if (provider.hotVideos.isEmpty && provider.isHotLoading) {
          return _buildLoadingState();
        }

        if (provider.hotVideos.isEmpty) {
          return _buildEmptyState(
            icon: Icons.local_fire_department_outlined,
            message: l10n.translate('sv_no_videos'),
            onRetry: () => provider.loadHotVideos(refresh: true),
            l10n: l10n,
          );
        }

        return _buildVideoPageView(
          provider.hotVideos,
          _hotPageController,
          _hotCurrentIndex,
          (index) {
            if (_hotCurrentIndex != index) {
              setState(() => _hotCurrentIndex = index);
            }
            _onPageChanged(index, provider.hotVideos);
            if (index >= provider.hotVideos.length - 3) {
              provider.loadHotVideos();
            }
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.translate('loading'),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required VoidCallback onRetry,
    required AppLocalizations l10n,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: Colors.white30),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.translate('retry'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPageView(
    List<SmallVideo> videos,
    PageController controller,
    int currentIndex,
    ValueChanged<int> onPageChanged,
  ) {
    return PageView.builder(
      controller: controller,
      scrollDirection: Axis.vertical,
      itemCount: videos.length,
      onPageChanged: onPageChanged,
      itemBuilder: (context, index) {
        return SmallVideoPlayerPage(
          key: ValueKey(videos[index].id),
          video: videos[index],
          isActive: index == currentIndex && _tabController.index == _getTabForList(videos),
        );
      },
    );
  }

  int _getTabForList(List<SmallVideo> videos) {
    final provider = context.read<SmallVideoProvider>();
    if (identical(videos, provider.feedVideos)) return 0;
    if (identical(videos, provider.hotVideos)) return 1;
    return 2;
  }
}
