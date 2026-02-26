/// 设置页面
/// 包含所有应用设置项

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/providers/locale_provider.dart';
import 'package:im_client/services/settings_service.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/screens/settings/account_security_screen.dart';
import 'package:im_client/screens/settings/chat_settings_screen.dart';
import 'package:im_client/screens/settings/privacy_settings_screen.dart';
import 'package:im_client/screens/settings/notification_settings_screen.dart';
import 'package:im_client/screens/settings/language_settings_screen.dart';
import 'package:im_client/screens/settings/about_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:im_client/screens/settings/permission_settings_screen.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _cacheSize;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    // Web 平台不支持文件系统缓存计算
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _cacheSize = '0 B';
        });
      }
      return;
    }

    try {
      int totalSize = 0;

      // 1. 计算临时目录大小
      final tempDir = await getTemporaryDirectory();
      final tempSize = await _getDirectorySize(tempDir);
      totalSize += tempSize;

      // 2. 计算应用缓存目录大小（如果有）
      try {
        final appCacheDir = await getApplicationCacheDirectory();
        if (appCacheDir.path != tempDir.path) {
          final appCacheSize = await _getDirectorySize(appCacheDir);
          totalSize += appCacheSize;
        }
      } catch (_) {
        // 某些平台可能不支持
      }

      if (mounted) {
        setState(() {
          _cacheSize = _formatSize(totalSize);
        });
      }
    } catch (e) {
      debugPrint('[SettingsScreen] 计算缓存大小失败: $e');
      if (mounted) {
        setState(() {
          _cacheSize = '0 B';
        });
      }
    }
  }

  Future<int> _getDirectorySize(Directory dir) async {
    int size = 0;
    try {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              size += await entity.length();
            } catch (_) {
              // 忽略无法读取的文件
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[SettingsScreen] 计算目录大小失败: $e');
    }
    return size;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _clearCache() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('clear_cache')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('confirm_clear_cache')),
            const SizedBox(height: 12),
            Text(
              l10n.translate('cache_clear_includes'),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. 清除网络图片缓存 (CachedNetworkImage)
        await CachedNetworkImage.evictFromCache(''); // 这不会工作，需要用下面的方法
        try {
          // 清除所有缓存的网络图片
          await DefaultCacheManager().emptyCache();
          debugPrint('[SettingsScreen] 已清除网络图片缓存');
        } catch (e) {
          debugPrint('[SettingsScreen] 清除网络图片缓存失败: $e');
        }

        // 2. 清除临时目录
        if (!kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          if (await tempDir.exists()) {
            // 遍历删除文件，避免删除整个目录后某些系统无法重建
            await for (final entity in tempDir.list()) {
              try {
                await entity.delete(recursive: true);
              } catch (_) {
                // 忽略无法删除的文件
              }
            }
            debugPrint('[SettingsScreen] 已清除临时目录缓存');
          }

          // 3. 清除应用缓存目录
          try {
            final appCacheDir = await getApplicationCacheDirectory();
            if (appCacheDir.path != tempDir.path && await appCacheDir.exists()) {
              await for (final entity in appCacheDir.list()) {
                try {
                  await entity.delete(recursive: true);
                } catch (_) {
                  // 忽略无法删除的文件
                }
              }
              debugPrint('[SettingsScreen] 已清除应用缓存目录');
            }
          } catch (_) {
            // 某些平台可能不支持
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('cache_cleared'))),
          );
          _calculateCacheSize();
        }
      } catch (e) {
        debugPrint('[SettingsScreen] 清除缓存失败: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.translate('clear_failed')}: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          // 账号与安全
          _buildSection(
            children: [
              _buildMenuItem(
                icon: Icons.security,
                iconColor: Colors.blue,
                title: l10n.translate('account_security'),
                subtitle: l10n.translate('account_security_desc'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountSecurityScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 聊天设置
          _buildSection(
            children: [
              _buildMenuItem(
                icon: Icons.chat_bubble_outline,
                iconColor: Colors.green,
                title: l10n.translate('chat_settings'),
                subtitle: l10n.translate('chat_desc'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatSettingsScreen()),
                  );
                },
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.notifications_outlined,
                iconColor: Colors.orange,
                title: l10n.translate('notification'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                  );
                },
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.lock_outline,
                iconColor: Colors.purple,
                title: l10n.translate('privacy'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
                  );
                },
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.verified_user_outlined,
                iconColor: Colors.teal,
                title: l10n.translate('permissions'),
                subtitle: l10n.translate('permissions_desc'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PermissionSettingsScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 通用设置
          _buildSection(
            children: [
              _buildMenuItem(
                icon: Icons.language,
                iconColor: Colors.indigo,
                title: l10n.translate('language'),
                subtitle: localeProvider.currentLocaleName,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
                  );
                },
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.cleaning_services_outlined,
                iconColor: Colors.teal,
                title: l10n.translate('clear_cache'),
                subtitle: _cacheSize ?? l10n.translate('calculating'),
                onTap: _clearCache,
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.info_outline,
                iconColor: Colors.grey,
                title: l10n.translate('about'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 退出登录
          _buildSection(
            children: [
              _buildMenuItem(
                icon: Icons.logout,
                iconColor: Colors.red,
                title: l10n.logout,
                showArrow: false,
                titleColor: Colors.red,
                onTap: () => _showLogoutDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSection({required List<Widget> children}) {
    return Container(
      color: AppColors.white,
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    bool showArrow = true,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(color: titleColor),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            )
          : null,
      trailing: showArrow
          ? const Icon(Icons.chevron_right, color: AppColors.textHint)
          : null,
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logout),
        content: Text(l10n.translate('confirm_logout')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
