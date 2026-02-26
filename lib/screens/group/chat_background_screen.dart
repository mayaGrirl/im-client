/// 聊天背景选择页面
/// 支持选择预设背景、自定义颜色或本地图片
/// 背景仅保存在本地，只有自己可见

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/services/chat_settings_service.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ChatBackgroundScreen extends StatefulWidget {
  final String conversId; // 会话ID (g_groupId 或 p_userId1_userId2)
  final String? currentBackground;

  const ChatBackgroundScreen({
    super.key,
    required this.conversId,
    this.currentBackground,
  });

  @override
  State<ChatBackgroundScreen> createState() => _ChatBackgroundScreenState();
}

class _ChatBackgroundScreenState extends State<ChatBackgroundScreen> {
  final ChatSettingsService _chatSettingsService = ChatSettingsService();
  String? _selectedBackground;
  bool _isLoading = false;
  bool _isCustomImage = false; // 是否选择了自定义图片

  // 预设背景颜色列表
  static const List<String> _presetColors = [
    '#FFFFFF', // 白色（默认）
    '#F5F5F5', // 浅灰
    '#E8F5E9', // 浅绿
    '#E3F2FD', // 浅蓝
    '#FFF3E0', // 浅橙
    '#FCE4EC', // 浅粉
    '#F3E5F5', // 浅紫
    '#FFFDE7', // 浅黄
    '#EFEBE9', // 浅棕
    '#ECEFF1', // 蓝灰
    '#E0F7FA', // 青色
    '#FBE9E7', // 深橙浅
  ];

  // 预设渐变背景
  static const List<List<String>> _presetGradients = [
    ['#667eea', '#764ba2'], // 紫蓝
    ['#f093fb', '#f5576c'], // 粉红
    ['#4facfe', '#00f2fe'], // 蓝青
    ['#43e97b', '#38f9d7'], // 绿青
    ['#fa709a', '#fee140'], // 粉黄
    ['#a8edea', '#fed6e3'], // 青粉
    ['#d299c2', '#fef9d7'], // 紫黄
    ['#89f7fe', '#66a6ff'], // 蓝色
  ];

  @override
  void initState() {
    super.initState();
    _selectedBackground = widget.currentBackground;
    // 检查当前背景是否是本地图片
    if (_selectedBackground != null &&
        !_selectedBackground!.startsWith('#') &&
        !_selectedBackground!.startsWith('gradient:')) {
      _isCustomImage = true;
    }
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  /// 从相册选择图片
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      String savedPath;

      if (kIsWeb) {
        // Web平台：将图片转换为base64 data URI存储
        try {
          final bytes = await pickedFile.readAsBytes();
          final base64 = base64Encode(bytes);
          // 根据文件扩展名确定MIME类型
          final ext = path.extension(pickedFile.name).toLowerCase();
          String mimeType = 'image/jpeg';
          if (ext == '.png') mimeType = 'image/png';
          else if (ext == '.gif') mimeType = 'image/gif';
          else if (ext == '.webp') mimeType = 'image/webp';
          savedPath = 'data:$mimeType;base64,$base64';
        } catch (e) {
          print('[ChatBackgroundScreen] Web平台读取图片失败: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${AppLocalizations.of(context)!.selectImageFailed}: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      } else {
        // 移动/桌面平台：尝试复制到应用目录
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final bgDir = Directory('${appDir.path}/chat_backgrounds');
          if (!await bgDir.exists()) {
            await bgDir.create(recursive: true);
          }

          final fileName = 'bg_${widget.conversId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(pickedFile.path)}';
          savedPath = '${bgDir.path}/$fileName';

          await File(pickedFile.path).copy(savedPath);
        } catch (e) {
          // 如果无法访问应用目录，直接使用原始路径
          print('[ChatBackgroundScreen] 无法复制到应用目录，使用原始路径: $e');
          savedPath = pickedFile.path;
        }
      }

      setState(() {
        _selectedBackground = savedPath;
        _isCustomImage = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.selectImageFailed}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveBackground() async {
    if (_selectedBackground == widget.currentBackground) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);

    // 保存到本地设置（不是服务器）
    await _chatSettingsService.init();
    await _chatSettingsService.setBackgroundImage(
      widget.conversId,
      _selectedBackground,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.backgroundUpdated),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, _selectedBackground);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatBackground),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _saveBackground,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.save,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 预览区域
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: _getPreviewColor(),
              gradient: _getPreviewGradient(),
              image: _getPreviewImage(),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 模拟消息气泡
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Hello!',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Hi there!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 默认选项
          _buildSectionTitle(l10n.defaultBackground),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() {
              _selectedBackground = null;
              _isCustomImage = false;
            }),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedBackground == null && !_isCustomImage
                      ? AppColors.primary
                      : AppColors.divider,
                  width: _selectedBackground == null && !_isCustomImage ? 2 : 1,
                ),
              ),
              child: _selectedBackground == null && !_isCustomImage
                  ? Icon(Icons.check, color: AppColors.primary)
                  : const Icon(Icons.block, color: AppColors.textHint),
            ),
          ),

          const SizedBox(height: 24),

          // 纯色背景
          _buildSectionTitle(l10n.solidColor),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _presetColors.map((color) {
              final isSelected = _selectedBackground == color && !_isCustomImage;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedBackground = color;
                  _isCustomImage = false;
                }),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _parseColor(color),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: AppColors.primary)
                      : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // 渐变背景
          _buildSectionTitle(l10n.gradientBackground),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _presetGradients.map((gradient) {
              final gradientStr = 'gradient:${gradient[0]},${gradient[1]}';
              final isSelected = _selectedBackground == gradientStr;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedBackground = gradientStr;
                  _isCustomImage = false;
                }),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _parseColor(gradient[0]),
                        _parseColor(gradient[1]),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: isSelected ? 2 : 0,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // 自定义图片
          _buildSectionTitle(l10n.customImage),
          const SizedBox(height: 12),
          Row(
            children: [
              // 选择图片按钮
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate,
                    color: AppColors.textSecondary,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 显示当前选择的自定义图片
              if (_isCustomImage && _selectedBackground != null)
                GestureDetector(
                  onTap: () {}, // 已选中
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                      image: _getCustomImageDecoration(),
                    ),
                    child: Icon(Icons.check, color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.customImageHint,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    );
  }

  Color? _getPreviewColor() {
    if (_selectedBackground == null) {
      return Colors.white;
    }
    if (_selectedBackground!.startsWith('gradient:') || _isCustomImage) {
      return null;
    }
    if (_selectedBackground!.startsWith('#')) {
      return _parseColor(_selectedBackground!);
    }
    return Colors.white;
  }

  Gradient? _getPreviewGradient() {
    if (_selectedBackground == null || !_selectedBackground!.startsWith('gradient:')) {
      return null;
    }
    final colors = _selectedBackground!.replaceFirst('gradient:', '').split(',');
    if (colors.length != 2) return null;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _parseColor(colors[0]),
        _parseColor(colors[1]),
      ],
    );
  }

  /// 获取自定义图片的装饰（用于缩略图显示）
  DecorationImage? _getCustomImageDecoration() {
    if (_selectedBackground == null) return null;

    ImageProvider imageProvider;

    // Base64 data URI
    if (_selectedBackground!.startsWith('data:image')) {
      try {
        final base64String = _selectedBackground!.split(',').last;
        final bytes = base64Decode(base64String);
        imageProvider = MemoryImage(bytes);
      } catch (e) {
        return null;
      }
    } else if (kIsWeb) {
      imageProvider = NetworkImage(_selectedBackground!);
    } else {
      final file = File(_selectedBackground!);
      if (!file.existsSync()) return null;
      imageProvider = FileImage(file);
    }

    return DecorationImage(
      image: imageProvider,
      fit: BoxFit.cover,
    );
  }

  DecorationImage? _getPreviewImage() {
    if (!_isCustomImage || _selectedBackground == null) {
      return null;
    }

    ImageProvider imageProvider;

    // Base64 data URI (Web平台)
    if (_selectedBackground!.startsWith('data:image')) {
      try {
        final base64String = _selectedBackground!.split(',').last;
        final bytes = base64Decode(base64String);
        imageProvider = MemoryImage(bytes);
      } catch (e) {
        print('[ChatBackgroundScreen] 解析base64图片失败: $e');
        return null;
      }
    } else if (kIsWeb) {
      // Web平台的其他图片URL
      imageProvider = NetworkImage(_selectedBackground!);
    } else {
      // 移动/桌面平台：文件图片
      final file = File(_selectedBackground!);
      if (!file.existsSync()) {
        return null;
      }
      imageProvider = FileImage(file);
    }

    return DecorationImage(
      image: imageProvider,
      fit: BoxFit.cover,
    );
  }
}
