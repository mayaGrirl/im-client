/// 短视频管理页面
/// 3列网格, 置顶标识(pin图标), 长按弹出操作面板: 置顶/取消置顶 + 删除(需确认)
/// 顶部显示 "已置顶: X/3"

import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/modules/small_video/api/small_video_api.dart';
import 'package:im_client/modules/small_video/models/small_video.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';

class VideoManagementScreen extends StatefulWidget {
  final int userId;

  const VideoManagementScreen({super.key, required this.userId});

  @override
  State<VideoManagementScreen> createState() => _VideoManagementScreenState();
}

class _VideoManagementScreenState extends State<VideoManagementScreen> {
  final SmallVideoApi _api = SmallVideoApi(ApiClient());
  List<SmallVideo> _videos = [];
  bool _isLoading = true;
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  int get _pinnedCount => _videos.where((v) => v.isTop).length;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return EnvConfig.instance.getFileUrl(url);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.getMyVideos(page: 1);
      if (response.success && response.data != null) {
        final data = response.data;
        List list;
        if (data is Map && data['list'] != null) {
          list = data['list'] as List;
        } else if (data is List) {
          list = data;
        } else {
          list = [];
        }
        setState(() {
          _videos = list.map((e) => SmallVideo.fromJson(e)).toList();
          _page = 2;
          _hasMore = list.length >= 20;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    try {
      final response = await _api.getMyVideos(page: _page);
      if (response.success && response.data != null) {
        final data = response.data;
        List list;
        if (data is Map && data['list'] != null) {
          list = data['list'] as List;
        } else if (data is List) {
          list = data;
        } else {
          list = [];
        }
        setState(() {
          _videos.addAll(list.map((e) => SmallVideo.fromJson(e)));
          _page++;
          _hasMore = list.length >= 20;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _toggleTop(SmallVideo video) async {
    final l10n = AppLocalizations.of(context)!;

    // 如果要置顶且已经3个, 提示
    if (!video.isTop && _pinnedCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('sv_vm_pin_max'))),
      );
      return;
    }

    try {
      final response = await _api.toggleVideoTop(video.id);
      if (response.success) {
        final newTop = response.data is Map ? response.data['is_top'] == true : !video.isTop;
        setState(() {
          final idx = _videos.indexWhere((v) => v.id == video.id);
          if (idx >= 0) {
            _videos[idx] = video.copyWith(isTop: newTop);
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newTop
                  ? l10n.translate('sv_vm_pin_success')
                  : l10n.translate('sv_vm_unpin_success')),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _deleteVideo(SmallVideo video) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('sv_vm_delete')),
        content: Text(l10n.translate('sv_vm_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.translate('sv_vm_delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await _api.deleteVideo(video.id);
      if (response.success) {
        setState(() {
          _videos.removeWhere((v) => v.id == video.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.translate('sv_vm_delete_success')),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _showActionSheet(SmallVideo video) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                video.isTop ? Icons.push_pin_outlined : Icons.push_pin,
                color: video.isTop ? Colors.grey : Colors.blue,
              ),
              title: Text(video.isTop
                  ? l10n.translate('sv_vm_unpin')
                  : l10n.translate('sv_vm_pin')),
              onTap: () {
                Navigator.pop(context);
                _toggleTop(video);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(l10n.translate('sv_vm_delete'),
                  style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteVideo(video);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('sv_vm_title')),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${l10n.translate('sv_vm_pinned')}: $_pinnedCount/3',
                style: TextStyle(
                  fontSize: 14,
                  color: _pinnedCount >= 3 ? Colors.red : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading && _videos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? Center(child: Text(l10n.translate('sv_vm_no_videos')))
              : GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(1),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 1.5,
                    mainAxisSpacing: 1.5,
                  ),
                  itemCount: _videos.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _videos.length) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    return _buildVideoItem(_videos[index]);
                  },
                ),
    );
  }

  Widget _buildVideoItem(SmallVideo video) {
    final coverUrl = _getFullUrl(video.coverUrl);

    return GestureDetector(
      onLongPress: () => _showActionSheet(video),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 封面
          coverUrl.isNotEmpty
              ? Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child:
                        const Icon(Icons.video_library, color: Colors.grey),
                  ),
                )
              : Container(
                  color: Colors.grey[300],
                  child:
                      const Icon(Icons.video_library, color: Colors.grey),
                ),

          // 底部渐变
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 36,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black38],
                ),
              ),
            ),
          ),

          // 点赞数
          Positioned(
            bottom: 4,
            left: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, size: 14, color: Colors.white),
                const SizedBox(width: 3),
                Text(
                  _formatCount(video.likeCount),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // 置顶标识
          if (video.isTop)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Icon(Icons.push_pin,
                    size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
