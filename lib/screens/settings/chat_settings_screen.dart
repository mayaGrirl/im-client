/// 聊天设置页面
/// 管理聊天背景、字体大小等设置

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/services/settings_service.dart';
import 'package:im_client/services/local_message_service.dart';
import '../../utils/image_proxy.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _settingsService.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.translate('chat')),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          // 聊天背景
          _buildSection(
            title: l10n.chatAppearance,
            children: [
              _buildMenuItem(
                icon: Icons.wallpaper,
                title: l10n.chatBackground,
                subtitle: _settingsService.globalChatBackground != null ? l10n.translate('set') : l10n.translate('default_value'),
                onTap: _showBackgroundOptions,
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.text_fields,
                title: l10n.fontSize,
                trailing: _buildFontSizeSelector(),
                onTap: null,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 聊天功能
          _buildSection(
            title: l10n.chatFeatures,
            children: [
              _buildSwitchItem(
                icon: Icons.download,
                title: l10n.autoDownload,
                subtitle: l10n.autoDownloadDesc,
                value: _settingsService.autoDownloadMedia,
                onChanged: (v) => _settingsService.setAutoDownloadMedia(v),
              ),
              const Divider(indent: 56),
              _buildSwitchItem(
                icon: Icons.save_alt,
                title: l10n.saveToAlbum,
                subtitle: l10n.saveToAlbumDesc,
                value: _settingsService.saveToAlbum,
                onChanged: (v) => _settingsService.setSaveToAlbum(v),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 聊天记录
          _buildSection(
            title: l10n.chatRecord,
            children: [
              _buildMenuItem(
                icon: Icons.cloud_upload,
                title: l10n.translate('chat_record_backup'),
                subtitle: l10n.backupToCloud,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.translate('feature_developing'))),
                  );
                },
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.cloud_download,
                title: l10n.translate('chat_record_restore'),
                subtitle: l10n.restoreFromCloud,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.translate('feature_developing'))),
                  );
                },
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.delete_sweep,
                title: l10n.clearAllChatHistory,
                titleColor: Colors.red,
                onTap: _showClearAllChatsDialog,
              ),
            ],
          ),

          const SizedBox(height: 30),

          // 预览区域
          if (_settingsService.globalChatBackground != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.translate('bg_preview'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            _buildBackgroundPreview(),
          ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        Container(
          color: AppColors.white,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildFontSizeSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: FontSizeOption.values.map((option) {
        final isSelected = _settingsService.fontSize == option;
        return GestureDetector(
          onTap: () => _settingsService.setFontSize(option),
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              option.label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showBackgroundOptions() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: Text(l10n.selectFromAlbum),
              onTap: () {
                Navigator.pop(context);
                _pickBackgroundImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: Text(l10n.takePhoto),
              onTap: () {
                Navigator.pop(context);
                _takeBackgroundPhoto();
              },
            ),
            if (_settingsService.globalChatBackground != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(l10n.translate('remove_background')),
                onTap: () {
                  Navigator.pop(context);
                  _settingsService.setGlobalChatBackground(null);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l10n.cancel),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBackgroundImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null) {
        await _saveBackgroundImage(picked.path);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('select_image_failed')}: $e')),
        );
      }
    }
  }

  Future<void> _takeBackgroundPhoto() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (picked != null) {
        await _saveBackgroundImage(picked.path);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('take_photo_fail')}: $e')),
        );
      }
    }
  }

  Future<void> _saveBackgroundImage(String sourcePath) async {
    if (kIsWeb) {
      // Web平台直接使用路径
      await _settingsService.setGlobalChatBackground(sourcePath);
      return;
    }

    try {
      // 复制到应用目录
      final appDir = await getApplicationDocumentsDirectory();
      final bgDir = Directory('${appDir.path}/backgrounds');
      if (!await bgDir.exists()) {
        await bgDir.create(recursive: true);
      }

      final fileName = 'chat_bg_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destPath = '${bgDir.path}/$fileName';

      await File(sourcePath).copy(destPath);
      await _settingsService.setGlobalChatBackground(destPath);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('bg_image_set'))),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('set_failed')}: $e')),
        );
      }
    }
  }

  /// 构建背景预览（检查文件是否存在）
  Widget _buildBackgroundPreview() {
    final l10n = AppLocalizations.of(context)!;
    final bgPath = _settingsService.globalChatBackground;
    if (bgPath == null) return const SizedBox.shrink();

    // 检查文件是否存在（非Web平台）
    if (!kIsWeb) {
      final file = File(bgPath);
      if (!file.existsSync()) {
        // 文件不存在，显示错误状态并提供清除选项
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                Text(l10n.translate('bg_file_not_exist'), style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _settingsService.setGlobalChatBackground(null),
                  child: Text(l10n.translate('clear_setting')),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 文件存在，显示预览
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        image: DecorationImage(
          image: kIsWeb ? NetworkImage(bgPath.proxied) : FileImage(File(bgPath)),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => _settingsService.setGlobalChatBackground(null),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
              ),
            ),
          ),
        ],
      ),
    );
  }
  void _showClearAllChatsDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('clear_all_chat_record')),
        content: Text(l10n.translate('confirm_clear_all_chat')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // 清空本地消息存储
                await LocalMessageService().clearAll();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.translate('local_chat_cleared'))),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${l10n.translate('clear_failed')}: $e')),
                  );
                }
              }
            },
            child: Text(l10n.translate('clear'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
