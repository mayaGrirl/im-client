/// 发布朋友圈页面
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/moment_api.dart';
import 'package:im_client/api/upload_api.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 逆地理编码服务 - 将经纬度转换为地址（使用BigDataCloud免费API）
class _GeocodingService {
  static Dio? _dio;

  static Dio get dio {
    _dio ??= Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    return _dio!;
  }

  /// 通过经纬度获取地址信息
  /// [lang] 语言代码，默认为英文 'en'
  static Future<String?> getAddressFromCoordinates(double lat, double lon, {String lang = 'en'}) async {
    try {
      // Start reverse geocoding

      // 使用BigDataCloud免费API（支持CORS，无需API Key）
      final response = await dio.get(
        'https://api-bdc.net/data/reverse-geocode-client',
        queryParameters: {
          'latitude': lat.toString(),
          'longitude': lon.toString(),
          'localityLanguage': lang,
        },
      );

      // Geocoding response received

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        // Geocoding data received

        // 获取城市名
        String? cityName = data['city']?.toString();
        // 获取区域名
        String? localityName = data['locality']?.toString();

        // 如果没有city，尝试使用principalSubdivision
        if (cityName == null || cityName.isEmpty) {
          cityName = data['principalSubdivision']?.toString();
        }

        // 如果还是没有，使用国家名
        if (cityName == null || cityName.isEmpty) {
          cityName = data['countryName']?.toString();
        }

        if (cityName != null && cityName.isNotEmpty) {
          // 如果locality存在且不同于city，显示两者
          if (localityName != null && localityName.isNotEmpty && localityName != cityName) {
            return '$cityName · $localityName';
          }
          return cityName;
        }
      }
    } catch (e) {
      // Geocoding failed
    }
    return null;
  }
}

class MomentPublishScreen extends StatefulWidget {
  const MomentPublishScreen({super.key});

  @override
  State<MomentPublishScreen> createState() => _MomentPublishScreenState();
}

class _MomentPublishScreenState extends State<MomentPublishScreen> {
  final MomentApi _momentApi = MomentApi(ApiClient());
  final UploadApi _uploadApi = UploadApi(ApiClient());
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final List<_MediaItem> _mediaItems = [];
  bool _isVideo = false;
  String? _location;
  int _visibility = MomentVisibility.public;
  bool _isPublishing = false;
  double _uploadProgress = 0;
  String _uploadingText = '';

  static const int maxImages = 9;

  @override
  void dispose() {
    _contentController.dispose();
    for (var item in _mediaItems) {
      item.videoController?.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_isVideo || _mediaItems.length >= maxImages) return;

    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        final remaining = maxImages - _mediaItems.length;
        final toAdd = images.take(remaining).toList();

        for (final image in toAdd) {
          final bytes = kIsWeb ? await image.readAsBytes() : null;
          setState(() {
            _mediaItems.add(_MediaItem(
              xFile: image,
              bytes: bytes,
              isVideo: false,
            ));
          });
        }
      }
    } catch (e) {
      // Image selection failed
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('select_image_failed')}: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    if (_mediaItems.isNotEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('video_images_together'))),
      );
      return;
    }

    try {
      final video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        final bytes = kIsWeb ? await video.readAsBytes() : null;

        VideoPlayerController? videoController;
        if (!kIsWeb) {
          videoController = VideoPlayerController.file(File(video.path));
          await videoController.initialize();
        }

        setState(() {
          _isVideo = true;
          _mediaItems.add(_MediaItem(
            xFile: video,
            bytes: bytes,
            isVideo: true,
            videoController: videoController,
          ));
        });
      }
    } catch (e) {
      // Video selection failed
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('select_video_failed')}: $e')),
        );
      }
    }
  }

  void _removeMedia(int index) {
    final item = _mediaItems[index];
    item.videoController?.dispose();
    setState(() {
      _mediaItems.removeAt(index);
      if (_mediaItems.isEmpty) {
        _isVideo = false;
      }
    });
  }

  Future<void> _publish() async {
    final l10n = AppLocalizations.of(context)!;
    final content = _contentController.text.trim();
    if (content.isEmpty && _mediaItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('add_content_or_media'))),
      );
      return;
    }

    setState(() {
      _isPublishing = true;
      _uploadProgress = 0;
      _uploadingText = l10n.translate('preparing_upload');
    });

    try {
      final List<String> imageUrls = [];
      final List<String> videoUrls = [];
      final totalItems = _mediaItems.length;

      for (int i = 0; i < _mediaItems.length; i++) {
        final item = _mediaItems[i];
        setState(() {
          _uploadingText = item.isVideo
              ? l10n.translate('uploading_video')
              : l10n.translate('uploading_image').replaceAll('{current}', '${i + 1}').replaceAll('{total}', '$totalItems');
          _uploadProgress = i / totalItems;
        });

        UploadResult? result;
        if (kIsWeb) {
          if (item.isVideo) {
            result = await _uploadApi.uploadVideo(
              item.bytes!.toList(),
              filename: item.xFile.name,
            );
          } else {
            result = await _uploadApi.uploadImage(
              item.bytes!.toList(),
              type: 'moment',
              filename: item.xFile.name,
            );
          }
        } else {
          if (item.isVideo) {
            result = await _uploadApi.uploadVideo(
              File(item.xFile.path),
              filename: item.xFile.name,
            );
          } else {
            result = await _uploadApi.uploadImage(
              File(item.xFile.path),
              type: 'moment',
              filename: item.xFile.name,
            );
          }
        }

        if (result != null && result.url.isNotEmpty) {
          if (item.isVideo) {
            videoUrls.add(result.url);
          } else {
            imageUrls.add(result.url);
          }
        }
      }

      setState(() {
        _uploadingText = l10n.translate('publishing');
        _uploadProgress = 0.9;
      });

      final response = await _momentApi.createMoment(
        content: content,
        images: imageUrls,
        videos: videoUrls,
        location: _location,
        visibility: _visibility,
      );

      if (response.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('publish_success'))),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message ?? l10n.translate('publish_failed'))),
          );
        }
      }
    } catch (e) {
      // Publish failed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('publish_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  void _showVisibilityPicker() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.translate('who_can_see'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Divider(height: 1, color: Colors.grey[200]),
              _buildVisibilityOption(
                icon: Icons.public,
                iconColor: const Color(0xFF07C160),
                title: l10n.translate('public'),
                subtitle: l10n.translate('all_friends_visible'),
                isSelected: _visibility == MomentVisibility.public,
                onTap: () {
                  setState(() => _visibility = MomentVisibility.public);
                  Navigator.pop(context);
                },
              ),
              Divider(height: 1, indent: 56, color: Colors.grey[200]),
              _buildVisibilityOption(
                icon: Icons.lock_outline,
                iconColor: Colors.orange,
                title: l10n.translate('private'),
                subtitle: l10n.translate('only_me_visible'),
                isSelected: _visibility == MomentVisibility.private,
                onTap: () {
                  setState(() => _visibility = MomentVisibility.private);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF07C160), size: 22),
          ],
        ),
      ),
    );
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LocationPickerSheet(
        currentLocation: _location,
        onSelected: (location) {
          setState(() => _location = location);
          Navigator.pop(context);
        },
        onClear: () {
          setState(() => _location = null);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(AppLocalizations.of(context)!.translate('publish_to_moments'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: ElevatedButton(
              onPressed: _isPublishing ? null : _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF07C160),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF07C160).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
              ),
              child: _isPublishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(AppLocalizations.of(context)!.translate('publish'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // 主要内容区
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      // 文本输入
                      TextField(
                        controller: _contentController,
                        maxLines: null,
                        minLines: 5,
                        maxLength: 2000,
                        style: const TextStyle(fontSize: 17, height: 1.6),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.translate('whats_on_your_mind'),
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 17),
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        ),
                      ),
                      // 媒体区域
                      _buildMediaSection(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 选项区域
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      _buildOptionItem(
                        icon: Icons.location_on_outlined,
                        iconBgColor: const Color(0xFF07C160),
                        title: AppLocalizations.of(context)!.translate('location'),
                        value: _location,
                        onTap: _showLocationPicker,
                        onClear: _location != null ? () => setState(() => _location = null) : null,
                      ),
                      Divider(height: 1, indent: 56, color: Colors.grey[100]),
                      _buildOptionItem(
                        icon: _visibility == MomentVisibility.public
                            ? Icons.public
                            : Icons.lock_outline,
                        iconBgColor: Colors.blue,
                        title: AppLocalizations.of(context)!.translate('who_can_see'),
                        value: MomentVisibility.getName(_visibility),
                        onTap: _showVisibilityPicker,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          // 上传进度遮罩
          if (_isPublishing) _buildUploadOverlay(),
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    String? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconBgColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                value ?? title,
                style: TextStyle(
                  fontSize: 16,
                  color: value != null ? Colors.black87 : Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                ),
              )
            else
              Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_mediaItems.isNotEmpty) ...[
            // 媒体网格
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: _isVideo
                  ? _mediaItems.length
                  : (_mediaItems.length < maxImages ? _mediaItems.length + 1 : _mediaItems.length),
              itemBuilder: (context, index) {
                if (!_isVideo && index == _mediaItems.length && _mediaItems.length < maxImages) {
                  return _buildAddButton(onTap: _pickImages);
                }
                return _buildMediaItem(_mediaItems[index], index);
              },
            ),
            const SizedBox(height: 10),
            // 提示文字
            Text(
              _isVideo ? AppLocalizations.of(context)!.selectedVideo : '${_mediaItems.length}/$maxImages',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ] else ...[
            // 空状态 - 媒体选择入口
            Row(
              children: [
                _buildMediaEntryButton(
                  icon: Icons.photo_library_outlined,
                  label: AppLocalizations.of(context)!.translate('image'),
                  color: const Color(0xFF07C160),
                  onTap: _pickImages,
                ),
                const SizedBox(width: 12),
                _buildMediaEntryButton(
                  icon: Icons.videocam_outlined,
                  label: AppLocalizations.of(context)!.translate('video'),
                  color: Colors.blue,
                  onTap: _pickVideo,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaEntryButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.add, size: 36, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildMediaItem(_MediaItem item, int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: item.isVideo
              ? _buildVideoPreview(item)
              : kIsWeb
                  ? Image.memory(item.bytes!, fit: BoxFit.cover)
                  : Image.file(File(item.xFile.path), fit: BoxFit.cover),
        ),
        // 删除按钮
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeMedia(index),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
        // 视频播放图标
        if (item.isVideo)
          Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoPreview(_MediaItem item) {
    if (item.videoController != null && item.videoController!.value.isInitialized) {
      return VideoPlayer(item.videoController!);
    }
    return Container(color: Colors.grey[800]);
  }

  Widget _buildUploadOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _uploadProgress > 0 ? _uploadProgress : null,
                      strokeWidth: 3,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF07C160)),
                    ),
                    if (_uploadProgress > 0)
                      Text(
                        '${(_uploadProgress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF07C160),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _uploadingText,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 位置选择器
class _LocationPickerSheet extends StatefulWidget {
  final String? currentLocation;
  final Function(String) onSelected;
  final VoidCallback onClear;

  const _LocationPickerSheet({
    this.currentLocation,
    required this.onSelected,
    required this.onClear,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoadingLocation = false;
  String? _currentAddress;
  LatLng? _currentLatLng;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _locationError;

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      // 检查位置服务是否开启
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = AppLocalizations.of(context)!.locationServiceDisabled;
        });
        return;
      }

      // 检查权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
            _locationError = AppLocalizations.of(context)!.locationPermissionDenied;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = AppLocalizations.of(context)!.locationPermissionPermanentlyDenied;
        });
        _showPermissionDialog();
        return;
      }

      // 获取位置
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final lat = position.latitude;
      final lon = position.longitude;

      setState(() {
        _currentLatLng = LatLng(lat, lon);
        _currentAddress = '${AppLocalizations.of(context)!.currentLocation}（${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}）';
        _isLoadingLocation = false;
        _locationError = null;
      });

      // 异步获取地址名称
      _getAddressName(lat, lon);
    } catch (e) {
      // Get location failed
      setState(() {
        _isLoadingLocation = false;
        _locationError = AppLocalizations.of(context)!.getLocationFailed;
      });
    }
  }

  /// 获取当前语言代码用于地理编码
  String _getGeocodingLanguage() {
    final locale = Localizations.localeOf(context);
    // 支持的语言：en, zh, fr, hi 等
    // 默认使用英文，避免显示中文
    final langCode = locale.languageCode;
    // 如果是中文环境才使用中文，其他情况使用英文
    if (langCode == 'zh') {
      return 'zh';
    }
    return 'en'; // 默认英文
  }

  Future<void> _getAddressName(double lat, double lon) async {
    try {
      final lang = _getGeocodingLanguage();
      final placeName = await _GeocodingService.getAddressFromCoordinates(lat, lon, lang: lang);
      if (mounted) {
        setState(() {
          if (placeName != null) {
            _currentAddress = '$placeName（${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}）';
          } else {
            // 如果获取不到地名，显示坐标
            _currentAddress = '${AppLocalizations.of(context)!.currentLocation}（${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}）';
          }
        });
      }
    } catch (e) {
      // Get address name failed
    }
  }

  void _showPermissionDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.needLocationPermission),
        content: Text(l10n.enableLocationInSettings),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: Text(l10n.goToSettings),
          ),
        ],
      ),
    );
  }

  void _openMapPicker() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => _MapPickerScreen(
          initialLocation: _currentLatLng,
          onLocationSelected: (address) {
            Navigator.pop(context, address); // 返回地址并关闭地图
          },
        ),
      ),
    );
    // 如果有选择位置，则回调并关闭底部弹窗
    if (result != null) {
      widget.onSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 拖动指示器
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.yourLocation,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (widget.currentLocation != null)
                  TextButton(
                    onPressed: widget.onClear,
                    child: Text(AppLocalizations.of(context)!.dontShow, style: TextStyle(color: Colors.grey[600])),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchLocation,
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    widget.onSelected(value.trim());
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 内容区
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 当前定位
                _buildSectionTitle(AppLocalizations.of(context)!.positioning),
                if (_isLoadingLocation)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(AppLocalizations.of(context)!.gettingLocation, style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                else if (_currentAddress != null)
                  _buildLocationItem(
                    icon: Icons.my_location,
                    iconColor: Colors.blue,
                    title: AppLocalizations.of(context)!.myLocation,
                    subtitle: _currentAddress,
                    onTap: () => widget.onSelected(_currentAddress!),
                  )
                else
                  _buildLocationErrorItem(),

                // 地图选点
                _buildLocationItem(
                  icon: Icons.map_outlined,
                  iconColor: const Color(0xFF07C160),
                  title: AppLocalizations.of(context)!.mapPicker,
                  subtitle: AppLocalizations.of(context)!.selectLocationOnMap,
                  onTap: _openMapPicker,
                  showArrow: true,
                ),

                const SizedBox(height: 8),
                _buildSectionTitle(AppLocalizations.of(context)!.popularDomestic),
                // 国内城市
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: AppLocalizations.of(context)!.domesticCities.map((city) => _buildCityChip(city)).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionTitle(AppLocalizations.of(context)!.popularInternational),
                // 国际城市
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: AppLocalizations.of(context)!.internationalCities.map((city) => _buildCityChip(city)).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildLocationItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool showArrow = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (showArrow) Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationErrorItem() {
    return InkWell(
      onTap: _getCurrentLocation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_disabled, color: Colors.orange, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _locationError ?? AppLocalizations.of(context)!.cannotGetLocation,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.tapRetryGetLocation,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                AppLocalizations.of(context)!.retry,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityChip(String city) {
    final isSelected = widget.currentLocation == city;
    return GestureDetector(
      onTap: () => widget.onSelected(city),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF07C160).withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: const Color(0xFF07C160).withOpacity(0.3)) : null,
        ),
        child: Text(
          city,
          style: TextStyle(
            fontSize: 14,
            color: isSelected ? const Color(0xFF07C160) : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 地图选点页面
class _MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final Function(String) onLocationSelected;

  const _MapPickerScreen({
    this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  late MapController _mapController;
  LatLng _selectedLocation = const LatLng(39.9042, 116.4074); // 默认北京
  LatLng? _currentLocation; // 当前GPS位置
  String _selectedAddress = '';
  bool _isLoading = true;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
      _currentLocation = widget.initialLocation;
    }
    _updateAddress();
    // 自动获取当前位置
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      // 检查位置服务是否开启
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnableLocationService)),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.locationPermissionDenied)),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showMapPermissionDialog();
        }
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = newLocation;
        // 如果没有初始位置，则移动到当前位置
        if (widget.initialLocation == null) {
          _selectedLocation = newLocation;
          _mapController.move(newLocation, 15);
        }
        _isLocating = false;
      });
      _updateAddress();
    } catch (e) {
      // Get location failed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.getLocationFailed)),
        );
      }
      setState(() => _isLocating = false);
    }
  }

  void _showMapPermissionDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.needLocationPermission),
        content: Text(l10n.enableLocationInSettings),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: Text(l10n.goToSettings),
          ),
        ],
      ),
    );
  }

  void _moveToCurrentLocation() async {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15);
      setState(() => _selectedLocation = _currentLocation!);
      _updateAddress();
    } else {
      // 重新获取当前位置
      await _getCurrentLocation();
      if (_currentLocation != null) {
        _mapController.move(_currentLocation!, 15);
        setState(() => _selectedLocation = _currentLocation!);
        _updateAddress();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.cannotGetCurrentLocation)),
          );
        }
      }
    }
  }

  void _updateAddress() {
    final lat = _selectedLocation.latitude;
    final lon = _selectedLocation.longitude;

    setState(() {
      _selectedAddress = '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
      _isLoading = false;
    });

    // 异步获取地址名称
    _fetchAddressName(lat, lon);
  }

  /// 获取当前语言代码用于地理编码
  String _getGeocodingLanguage() {
    final locale = Localizations.localeOf(context);
    // 如果是中文环境才使用中文，其他情况使用英文
    if (locale.languageCode == 'zh') {
      return 'zh';
    }
    return 'en'; // 默认英文
  }

  Future<void> _fetchAddressName(double lat, double lon) async {
    try {
      final lang = _getGeocodingLanguage();
      final placeName = await _GeocodingService.getAddressFromCoordinates(lat, lon, lang: lang);
      if (mounted) {
        setState(() {
          if (placeName != null) {
            _selectedAddress = '$placeName（${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}）';
          } else {
            _selectedAddress = '${AppLocalizations.of(context)!.translate('location')}（${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}）';
          }
        });
      }
    } catch (e) {
      // Get address name failed
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
      _isLoading = true;
    });
    _updateAddress();
  }

  void _confirmLocation() {
    widget.onLocationSelected(_selectedAddress);
    // 不需要手动pop，因为onLocationSelected回调中已经处理了Navigator.pop
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectLocation),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: _confirmLocation,
            child: Text(
              l10n.confirm,
              style: const TextStyle(color: Color(0xFF07C160), fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.im_client',
              ),
              MarkerLayer(
                markers: [
                  // 选中位置标记
                  Marker(
                    point: _selectedLocation,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
                  // 当前位置标记（如果不同于选中位置）
                  if (_currentLocation != null && _currentLocation != _selectedLocation)
                    Marker(
                      point: _currentLocation!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          // 底部位置信息
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF07C160), size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.selectedLocation, style: const TextStyle(fontWeight: FontWeight.w500)),
                      const Spacer(),
                      if (_isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedAddress.isEmpty ? l10n.tapMapToSelect : _selectedAddress,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          // 定位按钮
          Positioned(
            right: 16,
            bottom: 120,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              onPressed: _isLocating ? null : _moveToCurrentLocation,
              child: _isLocating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, color: Color(0xFF07C160)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaItem {
  final XFile xFile;
  final Uint8List? bytes;
  final bool isVideo;
  final VideoPlayerController? videoController;

  _MediaItem({
    required this.xFile,
    this.bytes,
    required this.isVideo,
    this.videoController,
  });
}
