/// 直播间上下滑动切换页面
/// 类似TikTok的竖向PageView，每页一个LivestreamViewerScreen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:im_client/modules/livestream/models/livestream.dart';
import 'package:im_client/modules/livestream/providers/livestream_provider.dart';
import 'package:im_client/modules/livestream/screens/livestream_viewer_screen.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/l10n/app_localizations.dart';

class LivestreamSwipeScreen extends StatefulWidget {
  final List<LivestreamRoom> initialRooms;
  final int initialIndex;

  const LivestreamSwipeScreen({
    super.key,
    required this.initialRooms,
    this.initialIndex = 0,
  });

  @override
  State<LivestreamSwipeScreen> createState() => _LivestreamSwipeScreenState();
}

class _LivestreamSwipeScreenState extends State<LivestreamSwipeScreen> {
  late PageController _pageController;
  late List<LivestreamRoom> _rooms;
  late int _currentIndex;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _rooms = List.from(widget.initialRooms);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);

    // 接近末尾时加载更�?
    if (index >= _rooms.length - 2 && !_loadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    _loadingMore = true;
    try {
      final provider = Provider.of<LivestreamProvider>(context, listen: false);
      final currentUserId = Provider.of<AuthProvider>(context, listen: false).userId;
      await provider.loadMoreLives();
      if (!mounted) return;
      final newRooms = provider.liveList
          .where((room) => room.isLive && !room.isPrivate && room.userId != currentUserId)
          .toList();
      // 合并新的直播间（去重�?
      final existingIds = _rooms.map((r) => r.id).toSet();
      final additions = newRooms.where((r) => !existingIds.contains(r.id)).toList();
      if (additions.isNotEmpty && mounted) {
        setState(() {
          _rooms.addAll(additions);
        });
      }
    } finally {
      _loadingMore = false;
    }
  }

  void _onStreamEnded(int livestreamId) {
    if (!mounted) return;
    // 移除已结束的直播�?
    final endedIndex = _rooms.indexWhere((r) => r.id == livestreamId);

    if (_currentIndex < _rooms.length - 1) {
      // 有下一个，滑到下一�?
      _pageController.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_currentIndex > 0) {
      // 没有下一个，滑到上一�?
      _pageController.animateToPage(
        _currentIndex - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // 最后一间也结束了，退�?
      Navigator.pop(context);
      return;
    }

    // 延迟移除已结束的条目
    if (endedIndex >= 0) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _rooms.removeAt(endedIndex);
            if (_currentIndex >= _rooms.length) {
              _currentIndex = _rooms.length - 1;
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_rooms.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(l10n.translate('no_livestream'), style: const TextStyle(color: Colors.white54, fontSize: 16)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _rooms.length,
        onPageChanged: _onPageChanged,
        // 禁用页面缓存，避免预加载页面自动播放音频
        allowImplicitScrolling: false,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          return LivestreamViewerScreen(
            key: ValueKey('livestream_${room.id}'),
            livestreamId: room.id,
            isActive: index == _currentIndex,
            onStreamEnded: _onStreamEnded,
          );
        },
      ),
    );
  }
}
