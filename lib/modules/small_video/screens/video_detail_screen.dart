/// 视频详情播放页（从网格/搜索结果跳入）
/// 复用 SmallVideoPlayerPage，支持从指定索引开始竖滑浏览

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:im_client/modules/small_video/models/small_video.dart';
import 'package:im_client/modules/small_video/screens/small_video_player_page.dart';
import 'package:im_client/modules/small_video/services/video_preload_manager.dart';

class VideoDetailScreen extends StatefulWidget {
  final List<SmallVideo> videos;
  final int initialIndex;

  const VideoDetailScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final VideoPreloadManager _preloadManager = VideoPreloadManager();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.videos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _preloadManager.disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.videos.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _preloadManager.onPageChanged(index, widget.videos);
            },
            itemBuilder: (context, index) {
              return SmallVideoPlayerPage(
                video: widget.videos[index],
                isActive: index == _currentIndex,
              );
            },
          ),
          // 返回按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white, size: 22),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
