/// 隐私设置页面

import 'package:flutter/material.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/services/settings_service.dart';
import 'package:im_client/screens/contacts/blacklist_screen.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/user_api.dart';
import 'package:im_client/l10n/app_localizations.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final UserApi _userApi = UserApi(ApiClient());
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _settingsService.addListener(_onSettingsChanged);
    _loadServerSettings();
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  /// 从服务器加载设置
  Future<void> _loadServerSettings() async {
    try {
      final response = await _userApi.getUserSettings();
      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        // 同步服务器设置到本地
        if (data['show_online_status'] != null) {
          await _settingsService.setShowOnlineStatus(data['show_online_status'] == true);
        }
        if (data['allow_stranger'] != null) {
          // allow_stranger 映射到 addFriendPermission: true->0(允许), false->2(禁止)
          await _settingsService.setAddFriendPermission(data['allow_stranger'] == true ? 0 : 2);
        }
      }
    } catch (e) {
      // 静默失败，使用本地设置
    }
  }

  /// 同步设置到服务器
  Future<void> _syncToServer() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await _userApi.updateUserSettings(
        showOnlineStatus: _settingsService.showOnlineStatus,
        allowStranger: _settingsService.addFriendPermission != 2, // 2=禁止, 其他=允许
      );
    } catch (e) {
      // 静默失败
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.privacy),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          // 添加好友权限
          _buildSection(
            title: l10n.translate('add_me_method'),
            children: [
              _buildRadioItem(
                title: l10n.allowAnyone,
                subtitle: l10n.translate('anyone_can_add_desc'),
                value: 0,
                groupValue: _settingsService.addFriendPermission,
                onChanged: (v) {
                  _settingsService.setAddFriendPermission(v!);
                  _syncToServer();
                },
              ),
              const Divider(indent: 16),
              _buildRadioItem(
                title: l10n.translate('verification_required'),
                subtitle: l10n.translate('need_my_verification_desc'),
                value: 1,
                groupValue: _settingsService.addFriendPermission,
                onChanged: (v) {
                  _settingsService.setAddFriendPermission(v!);
                  _syncToServer();
                },
              ),
              const Divider(indent: 16),
              _buildRadioItem(
                title: l10n.translate('reject_everyone'),
                subtitle: l10n.translate('no_one_can_add_desc'),
                value: 2,
                groupValue: _settingsService.addFriendPermission,
                onChanged: (v) {
                  _settingsService.setAddFriendPermission(v!);
                  _syncToServer();
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 在线状态
          _buildSection(
            title: l10n.onlineStatus,
            children: [
              _buildSwitchItem(
                icon: Icons.circle,
                iconColor: Colors.green,
                title: l10n.translate('show_online_status'),
                subtitle: l10n.translate('hide_online_status_desc'),
                value: _settingsService.showOnlineStatus,
                onChanged: (v) {
                  _settingsService.setShowOnlineStatus(v);
                  _syncToServer();
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 黑名单
          _buildSection(
            title: l10n.translate('other_section'),
            children: [
              _buildMenuItem(
                icon: Icons.block,
                title: l10n.blacklist,
                subtitle: l10n.translate('manage_blocked_users'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BlacklistScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSection({String? title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
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

  Widget _buildRadioItem({
    required String title,
    String? subtitle,
    required int value,
    required int groupValue,
    required ValueChanged<int?> onChanged,
  }) {
    return RadioListTile<int>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
          : null,
      activeColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    Color? iconColor,
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
          color: (iconColor ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
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

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
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
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}
