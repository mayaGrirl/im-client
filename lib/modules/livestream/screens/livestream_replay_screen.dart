/// 直播回放播放页面
/// 使用Chewie播放器播放回放视频

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/modules/livestream/models/livestream.dart';

class LivestreamReplayScreen extends StatefulWidget {
  final LivestreamRecord record;

  const LivestreamReplayScreen({super.key, required this.record});

  @override
  State<LivestreamReplayScreen> createState() => _LivestreamReplayScreenState();
}

class _LivestreamReplayScreenState extends State<LivestreamReplayScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initPlayer();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _initPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.record.videoUrl),
      );
      await _videoController!.initialize();
      if (mounted) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          allowFullScreen: true,
          aspectRatio: _videoController!.value.aspectRatio,
          placeholder: widget.record.coverUrl.isNotEmpty
              ? Image.network(EnvConfig.instance.getFileUrl(widget.record.coverUrl), fit: BoxFit.cover)
              : null,
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white54, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    '回放加载失败',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            );
          },
        );
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '视频加载失败: $e';
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}h${m.toString().padLeft(2, '0')}m${s.toString().padLeft(2, '0')}s';
    }
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.record.title,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_formatDuration(widget.record.duration)} | ${widget.record.viewCount}次播放',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white54, size: 64),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.white54)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _initPlayer();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _chewieController != null
                  ? Center(child: Chewie(controller: _chewieController!))
                  : const Center(
                      child: Text('播放器初始化失败', style: TextStyle(color: Colors.white54)),
                    ),
    );
  }
}
