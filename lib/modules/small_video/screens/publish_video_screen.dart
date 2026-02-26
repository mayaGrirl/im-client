/// 发布小视频页面
/// 支持视频选择、封面截取/上传、标签、分类等

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import 'package:im_client/api/api_client.dart';
import 'package:im_client/modules/small_video/api/small_video_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/modules/small_video/models/small_video.dart';
import 'package:im_client/modules/small_video/providers/small_video_provider.dart';

class PublishVideoScreen extends StatefulWidget {
  const PublishVideoScreen({super.key});

  @override
  State<PublishVideoScreen> createState() => _PublishVideoScreenState();
}

class _PublishVideoScreenState extends State<PublishVideoScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController();
  final _priceController = TextEditingController();
  final _previewDurationController = TextEditingController();

  final SmallVideoApi _api = SmallVideoApi(ApiClient());

  XFile? _selectedVideo;
  Uint8List? _videoBytes;
  VideoPlayerController? _previewController;
  bool _isPreviewReady = false;

  // 封面相关
  XFile? _selectedCover;
  Uint8List? _coverBytes;
  int _coverFrameTime = 0; // 从视频截取封面的时间(秒)
  bool _hasCoverFromVideo = false;

  List<String> _tags = [];
  int _visibility = 0;
  bool _allowComment = true;
  bool _allowLike = true;
  bool _allowSave = true;
  bool _isPaid = false;

  int? _selectedCategoryId;
  List<SmallVideoCategory> _categories = [];

  bool _isPublishing = false;
  double _uploadProgress = 0;

  // 标签搜索
  List<SmallVideoTag> _suggestedTags = [];
  bool _isSearchingTags = false;
  bool _showTagSuggestions = false;
  Timer? _tagSearchDebounce;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _tagController.addListener(_onTagInputChanged);
  }

  void _onTagInputChanged() {
    final text = _tagController.text.trim();
    _tagSearchDebounce?.cancel();
    if (text.isEmpty) {
      setState(() {
        _suggestedTags = [];
        _showTagSuggestions = false;
      });
      return;
    }
    _tagSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchTags(text);
    });
  }

  Future<void> _searchTags(String keyword) async {
    setState(() => _isSearchingTags = true);
    try {
      final response = await _api.searchTags(keyword: keyword);
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
        if (mounted) {
          setState(() {
            _suggestedTags = list.map((e) => SmallVideoTag.fromJson(e)).toList();
            _showTagSuggestions = true;
          });
        }
      }
    } catch (e) {
      // ignore
    }
    if (mounted) setState(() => _isSearchingTags = false);
  }

  void _selectTag(String tagName) {
    if (tagName.isNotEmpty && !_tags.contains(tagName)) {
      setState(() {
        _tags.add(tagName);
        _tagController.clear();
        _suggestedTags = [];
        _showTagSuggestions = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _api.getCategories();
      if (response.success && response.data != null) {
        final data = response.data;
        if (data is List) {
          setState(() {
            _categories = data.map((e) => SmallVideoCategory.fromJson(e)).toList();
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _selectedVideo = video;
        _isPreviewReady = false;
        _selectedCover = null;
        _coverBytes = null;
        _hasCoverFromVideo = false;
        _coverFrameTime = 0;
      });
      _videoBytes = await video.readAsBytes();
      _initPreview(video);
    }
  }

  Future<void> _initPreview(XFile video) async {
    _previewController?.dispose();
    _previewController = VideoPlayerController.networkUrl(Uri.parse(video.path));
    try {
      await _previewController!.initialize();
      if (mounted) setState(() => _isPreviewReady = true);
    } catch (e) {
      // Preview init failed
    }
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedCover = image;
        _coverBytes = bytes;
        _hasCoverFromVideo = false;
        _coverFrameTime = 0;
      });
    }
  }

  void _selectCoverFromVideo() {
    if (_previewController == null || !_isPreviewReady) return;

    final totalDuration = _previewController!.value.duration;
    Duration selectedPosition = _previewController!.value.position;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // 拖拽手柄
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 标题
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Text(
                          '选择封面帧',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  // 视频预览
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _previewController!.value.aspectRatio,
                        child: VideoPlayer(_previewController!),
                      ),
                    ),
                  ),
                  // 时间指示
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      '${_formatDuration(selectedPosition)} / ${_formatDuration(totalDuration)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  // 滑动条
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.2),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      ),
                      child: Slider(
                        value: selectedPosition.inMilliseconds.toDouble().clamp(
                          0, totalDuration.inMilliseconds.toDouble(),
                        ),
                        min: 0,
                        max: totalDuration.inMilliseconds.toDouble().clamp(1, double.infinity),
                        onChanged: (value) {
                          final pos = Duration(milliseconds: value.toInt());
                          _previewController!.seekTo(pos);
                          _previewController!.pause();
                          setSheetState(() => selectedPosition = pos);
                        },
                      ),
                    ),
                  ),
                  // 使用此帧按钮
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          // 从视频中截取指定时间的帧作为封面
                          try {
                            final bytes = await vt.VideoThumbnail.thumbnailData(
                              video: _selectedVideo!.path,
                              imageFormat: vt.ImageFormat.JPEG,
                              maxHeight: 720,
                              quality: 85,
                              timeMs: selectedPosition.inMilliseconds,
                            );
                            setState(() {
                              _coverFrameTime = selectedPosition.inSeconds;
                              _hasCoverFromVideo = true;
                              _selectedCover = null;
                              _coverBytes = bytes;
                            });
                          } catch (_) {
                            // 截取失败，仅记录时间，由服务端 ffmpeg 兜底
                            setState(() {
                              _coverFrameTime = selectedPosition.inSeconds;
                              _hasCoverFromVideo = true;
                              _selectedCover = null;
                              _coverBytes = null;
                            });
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('使用此帧', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  Future<void> _publish() async {
    if (_selectedVideo == null || _videoBytes == null) return;

    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isPublishing = true;
      _uploadProgress = 0;
    });

    try {
      // 1. 上传视频文件（使用bytes，跨平台兼容）
      final videoFileName = _selectedVideo!.name.isNotEmpty
          ? _selectedVideo!.name
          : 'video.mp4';
      final videoUploadResponse = await ApiClient().uploadBytes(
        '/upload/video',
        _videoBytes!,
        videoFileName,
        fieldName: 'file',
        onProgress: (sent, total) {
          if (mounted) {
            setState(() {
              _uploadProgress = (sent / total) * 80;
            });
          }
        },
      );

      if (!videoUploadResponse.success) {
        _showError(videoUploadResponse.message ?? l10n.translate('failed'));
        return;
      }

      final videoUrl = videoUploadResponse.data?['url'] ?? '';
      String? coverUrl;

      // 2. 上传封面（可选，使用bytes）
      if (_coverBytes != null) {
        setState(() => _uploadProgress = 85);
        final coverFileName = _selectedCover != null && _selectedCover!.name.isNotEmpty
            ? _selectedCover!.name
            : 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final coverResponse = await ApiClient().uploadBytes(
          '/upload/image',
          _coverBytes!,
          coverFileName,
          fieldName: 'file',
        );
        if (coverResponse.success) {
          coverUrl = coverResponse.data?['url'];
        }
      }

      setState(() => _uploadProgress = 90);

      // 3. 发布视频
      if (!mounted) return;
      final provider = context.read<SmallVideoProvider>();
      final success = await provider.publishVideo(
        videoUrl: videoUrl,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        coverUrl: coverUrl,
        duration: _previewController?.value.duration.inSeconds,
        categoryId: _selectedCategoryId,
        tags: _tags.isNotEmpty ? _tags : null,
        visibility: _visibility,
        allowComment: _allowComment,
        allowLike: _allowLike,
        allowSave: _allowSave,
        isPaid: _isPaid,
        price: _isPaid ? (int.tryParse(_priceController.text) ?? 0) : 0,
        previewDuration: _isPaid ? (int.tryParse(_previewDurationController.text) ?? 0) : 0,
        coverTime: _hasCoverFromVideo ? _coverFrameTime : 0,
      );

      setState(() => _uploadProgress = 100);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('sv_publish_success')),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _isPublishing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  void dispose() {
    _tagSearchDebounce?.cancel();
    _tagController.removeListener(_onTagInputChanged);
    _titleController.dispose();
    _descController.dispose();
    _tagController.dispose();
    _priceController.dispose();
    _previewDurationController.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('sv_publish'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (_selectedVideo != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _isPublishing ? null : _publish,
                style: TextButton.styleFrom(
                  backgroundColor: _isPublishing ? Colors.grey[300] : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isPublishing
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.translate('sv_publish_btn'), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      body: _isPublishing
          ? _buildPublishingOverlay(l10n)
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // 视频选择/预览
                  _buildVideoSection(l10n),
                  const SizedBox(height: 12),

                  // 封面选择
                  if (_selectedVideo != null) ...[
                    _buildCoverSection(l10n),
                    const SizedBox(height: 12),
                  ],

                  // 视频信息卡片
                  if (_selectedVideo != null) ...[
                    _buildInfoCard(l10n, theme),
                    const SizedBox(height: 12),
                  ],

                  // 设置区域
                  if (_selectedVideo != null) ...[
                    _buildSettingsCard(l10n),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildVideoSection(AppLocalizations l10n) {
    if (_selectedVideo == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: _pickVideo,
          child: Container(
            height: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider, width: 1.5),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.video_library_outlined, size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.translate('sv_select_video'),
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'MP4, MOV, AVI, WEBM',
                    style: TextStyle(color: AppColors.textHint, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (_isPreviewReady && _previewController != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _previewController!.value.aspectRatio,
                  child: VideoPlayer(_previewController!),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
              ),
            // 重新选择视频
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  _previewController?.dispose();
                  setState(() {
                    _selectedVideo = null;
                    _videoBytes = null;
                    _isPreviewReady = false;
                    _selectedCover = null;
                    _coverBytes = null;
                    _hasCoverFromVideo = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
            // 时长
            if (_isPreviewReady && _previewController != null)
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatDuration(_previewController!.value.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            // 播放/暂停
            if (_isPreviewReady && _previewController != null)
              Positioned(
                bottom: 10,
                left: 10,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_previewController!.value.isPlaying) {
                        _previewController!.pause();
                      } else {
                        _previewController!.play();
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _previewController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverSection(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('sv_cover'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // 从视频截取
              Expanded(
                child: _buildCoverOption(
                  icon: Icons.content_cut_rounded,
                  label: l10n.translate('sv_cover_from_video'),
                  isSelected: _hasCoverFromVideo,
                  onTap: _selectCoverFromVideo,
                ),
              ),
              const SizedBox(width: 12),
              // 上传封面
              Expanded(
                child: _buildCoverOption(
                  icon: Icons.add_photo_alternate_outlined,
                  label: l10n.translate('sv_cover_upload'),
                  isSelected: _coverBytes != null,
                  onTap: _pickCover,
                ),
              ),
            ],
          ),
          // 封面预览
          if (_coverBytes != null || _hasCoverFromVideo) ...[
            const SizedBox(height: 12),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: _coverBytes != null
                  ? Image.memory(
                      _coverBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildCoverPlaceholder(),
                    )
                  : _hasCoverFromVideo
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_isPreviewReady && _previewController != null)
                              Center(
                                child: AspectRatio(
                                  aspectRatio: _previewController!.value.aspectRatio,
                                  child: VideoPlayer(_previewController!),
                                ),
                              ),
                            Container(
                              color: Colors.black26,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '${_formatDuration(Duration(seconds: _coverFrameTime))} 截取',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : _buildCoverPlaceholder(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoverOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Center(
      child: Icon(Icons.image_outlined, size: 40, color: AppColors.textHint),
    );
  }

  Widget _buildInfoCard(AppLocalizations l10n, ThemeData theme) {
    final inputText = _tagController.text.trim();
    final hasExactMatch = _suggestedTags.any((t) => t.name == inputText);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('sv_video_info'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // 标题
          TextField(
            controller: _titleController,
            maxLength: 200,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: l10n.translate('sv_title'),
              hintText: l10n.translate('sv_title'),
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              counterStyle: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),

          // 描述
          TextField(
            controller: _descController,
            maxLength: 1000,
            maxLines: 3,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: l10n.translate('sv_description'),
              hintText: l10n.translate('enter_video_description'),
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              counterStyle: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),

          // 标签
          TextField(
            controller: _tagController,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: l10n.translate('sv_tags'),
              hintText: l10n.translate('sv_search_tags'),
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: IconButton(
                icon: Icon(Icons.add_circle, color: AppColors.primary),
                onPressed: _addTag,
              ),
            ),
            onSubmitted: (_) => _addTag(),
          ),

          // 搜索建议列表
          if (_showTagSuggestions && inputText.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSearchingTags)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_suggestedTags.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          l10n.translate('sv_no_tags_found'),
                          style: TextStyle(color: AppColors.textHint, fontSize: 14),
                        ),
                      )
                    else
                      ..._suggestedTags.map((tag) => ListTile(
                        dense: true,
                        title: Text('#${tag.name}', style: const TextStyle(fontSize: 14)),
                        trailing: Text(
                          l10n.translate('sv_tag_video_count').replaceAll('{count}', '${tag.videoCount}'),
                          style: TextStyle(color: AppColors.textHint, fontSize: 12),
                        ),
                        onTap: () => _selectTag(tag.name),
                      )),
                    if (!hasExactMatch && inputText.isNotEmpty && !_isSearchingTags)
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
                        title: Text(
                          l10n.translate('sv_create_tag').replaceAll('{tag}', inputText),
                          style: TextStyle(color: AppColors.primary, fontSize: 14),
                        ),
                        onTap: () => _selectTag(inputText),
                      ),
                  ],
                ),
              ),
            ),

          if (_tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('#$tag', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _removeTag(tag),
                        child: Icon(Icons.close, size: 14, color: AppColors.primary),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),

          // 分类
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedCategoryId,
              decoration: InputDecoration(
                labelText: l10n.translate('sv_category'),
                filled: true,
                fillColor: const Color(0xFFF8F8F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: _categories.map((cat) => DropdownMenuItem(
                value: cat.id,
                child: Text(cat.name),
              )).toList(),
              onChanged: (value) => setState(() => _selectedCategoryId = value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsCard(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.translate('sv_settings'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),

          // 可见性
          ListTile(
            leading: Icon(Icons.visibility_outlined, color: AppColors.textSecondary, size: 22),
            title: Text(l10n.translate('sv_visibility'), style: const TextStyle(fontSize: 15)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<int>(
                value: _visibility,
                underline: const SizedBox(),
                isDense: true,
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                items: [
                  DropdownMenuItem(value: 0, child: Text(l10n.translate('sv_public'))),
                  DropdownMenuItem(value: 1, child: Text(l10n.translate('sv_friends_only'))),
                  DropdownMenuItem(value: 2, child: Text(l10n.translate('sv_private'))),
                ],
                onChanged: (v) => setState(() => _visibility = v ?? 0),
              ),
            ),
          ),

          _buildSwitchTile(
            icon: Icons.comment_outlined,
            title: l10n.translate('sv_allow_comment'),
            value: _allowComment,
            onChanged: (v) => setState(() => _allowComment = v),
          ),
          _buildSwitchTile(
            icon: Icons.thumb_up_outlined,
            title: l10n.translate('sv_allow_like'),
            value: _allowLike,
            onChanged: (v) => setState(() => _allowLike = v),
          ),
          _buildSwitchTile(
            icon: Icons.download_outlined,
            title: l10n.translate('sv_allow_save'),
            value: _allowSave,
            onChanged: (v) => setState(() => _allowSave = v),
          ),

          const Divider(indent: 16, endIndent: 16),

          _buildSwitchTile(
            icon: Icons.monetization_on_outlined,
            title: l10n.translate('sv_paid_content'),
            value: _isPaid,
            onChanged: (v) => setState(() => _isPaid = v),
          ),

          if (_isPaid)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: '${l10n.translate('sv_price')} (${l10n.translate('sv_gold_beans')})',
                        filled: true,
                        fillColor: const Color(0xFFF8F8F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _previewDurationController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: l10n.translate('sv_preview_duration'),
                        hintText: '5',
                        filled: true,
                        fillColor: const Color(0xFFF8F8F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
      dense: true,
    );
  }

  Widget _buildPublishingOverlay(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: _uploadProgress / 100,
                  strokeWidth: 5,
                  color: AppColors.primary,
                  backgroundColor: AppColors.divider,
                ),
              ),
              Text(
                '${_uploadProgress.toInt()}%',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            l10n.translate('sv_upload_progress').replaceAll('{progress}', _uploadProgress.toInt().toString()),
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
