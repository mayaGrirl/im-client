/// 管理员权限设置页面
/// 群主配置管理员可以执行的操作

import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/models/group.dart';
import 'package:im_client/l10n/app_localizations.dart';

class GroupAdminPermissionsScreen extends StatefulWidget {
  final int groupId;

  const GroupAdminPermissionsScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupAdminPermissionsScreen> createState() =>
      _GroupAdminPermissionsScreenState();
}

class _GroupAdminPermissionsScreenState
    extends State<GroupAdminPermissionsScreen> {
  final GroupApi _groupApi = GroupApi(ApiClient());

  AdminPermissions? _permissions;
  bool _isLoading = true;
  String? _savingKey; // 正在保存的权限key

  // 本地状态
  bool _canKick = true;
  bool _canMute = true;
  bool _canInvite = true;
  bool _canEditInfo = true;
  bool _canEditNotice = true;
  bool _canClearHistory = false;
  bool _canViewMembers = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);
    final permissions = await _groupApi.getAdminPermissions(widget.groupId);
    print('[AdminPermissions] 加载权限: permissions=$permissions');
    if (permissions != null) {
      print('[AdminPermissions] canKick=${permissions.canKick}, canMute=${permissions.canMute}, canEditInfo=${permissions.canEditInfo}, canEditNotice=${permissions.canEditNotice}, canViewMembers=${permissions.canViewMembers}');
    }
    setState(() {
      _permissions = permissions;
      if (permissions != null) {
        _canKick = permissions.canKick;
        _canMute = permissions.canMute;
        _canInvite = permissions.canInvite;
        _canEditInfo = permissions.canEditInfo;
        _canEditNotice = permissions.canEditNotice;
        _canClearHistory = permissions.canClearHistory;
        _canViewMembers = permissions.canViewMembers;
      }
      _isLoading = false;
    });
  }

  /// 更新单个权限
  Future<void> _updatePermission(String key, bool value) async {
    setState(() => _savingKey = key);

    print('[AdminPermissions] Update permissions: key=$key, value=$value');

    final res = await _groupApi.updateAdminPermissions(
      widget.groupId,
      canKick: key == 'canKick' ? value : null,
      canMute: key == 'canMute' ? value : null,
      canInvite: key == 'canInvite' ? value : null,
      canEditInfo: key == 'canEditInfo' ? value : null,
      canEditNotice: key == 'canEditNotice' ? value : null,
      canClearHistory: key == 'canClearHistory' ? value : null,
      canViewMembers: key == 'canViewMembers' ? value : null,
    );

    print('[AdminPermissions] Update results: success=${res.success}, message=${res.message}');

    setState(() => _savingKey = null);

    if (!res.success) {
      // 恢复原值
      _revertValue(key);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? AppLocalizations.of(context)!.saveFailed)),
      );
    }
  }

  void _revertValue(String key) {
    setState(() {
      switch (key) {
        case 'canKick':
          _canKick = !_canKick;
          break;
        case 'canMute':
          _canMute = !_canMute;
          break;
        case 'canInvite':
          _canInvite = !_canInvite;
          break;
        case 'canEditInfo':
          _canEditInfo = !_canEditInfo;
          break;
        case 'canEditNotice':
          _canEditNotice = !_canEditNotice;
          break;
        case 'canClearHistory':
          _canClearHistory = !_canClearHistory;
          break;
        case 'canViewMembers':
          _canViewMembers = !_canViewMembers;
          break;
      }
    });
  }

  void _onPermissionChanged(String key, bool value) {
    // 先更新本地状态
    setState(() {
      switch (key) {
        case 'canKick':
          _canKick = value;
          break;
        case 'canMute':
          _canMute = value;
          break;
        case 'canInvite':
          _canInvite = value;
          break;
        case 'canEditInfo':
          _canEditInfo = value;
          break;
        case 'canEditNotice':
          _canEditNotice = value;
          break;
        case 'canClearHistory':
          _canClearHistory = value;
          break;
        case 'canViewMembers':
          _canViewMembers = value;
          break;
      }
    });
    // 然后保存到服务器
    _updatePermission(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminPermissions),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildHeader(l10n),
                const SizedBox(height: 12),
                _buildPermissionSection(l10n),
              ],
            ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.shield,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.adminPermissions,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.adminPermissionsConfig,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSection(AppLocalizations l10n) {
    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          _buildPermissionItem(
            key: 'canKick',
            title: l10n.kickMembers,
            subtitle: l10n.kickMembersDesc,
            icon: Icons.person_remove,
            iconColor: Colors.orange,
            value: _canKick,
          ),
          const Divider(height: 1, indent: 16),
          _buildPermissionItem(
            key: 'canMute',
            title: l10n.muteMembers,
            subtitle: l10n.muteMembersDesc,
            icon: Icons.volume_off,
            iconColor: Colors.red,
            value: _canMute,
          ),
          const Divider(height: 1, indent: 16),
          _buildPermissionItem(
            key: 'canInvite',
            title: l10n.inviteMembers,
            subtitle: l10n.inviteMembersDesc,
            icon: Icons.person_add,
            iconColor: Colors.green,
            value: _canInvite,
          ),
          const Divider(height: 1, indent: 16),
          _buildPermissionItem(
            key: 'canEditInfo',
            title: l10n.editGroupInfo,
            subtitle: l10n.editGroupInfoDesc,
            icon: Icons.edit,
            iconColor: Colors.blue,
            value: _canEditInfo,
          ),
          const Divider(height: 1, indent: 16),
          _buildPermissionItem(
            key: 'canEditNotice',
            title: l10n.editNotice,
            subtitle: l10n.editNoticeDesc,
            icon: Icons.announcement,
            iconColor: Colors.purple,
            value: _canEditNotice,
          ),
          const Divider(height: 1, indent: 16),
          _buildPermissionItem(
            key: 'canViewMembers',
            title: l10n.viewMemberList,
            subtitle: l10n.viewMemberListDesc,
            icon: Icons.people,
            iconColor: Colors.teal,
            value: _canViewMembers,
          ),
          const Divider(height: 1, indent: 16),
          _buildPermissionItem(
            key: 'canClearHistory',
            title: l10n.clearChatHistory,
            subtitle: l10n.clearChatHistoryDesc,
            icon: Icons.delete_sweep,
            iconColor: Colors.red,
            value: _canClearHistory,
            isWarning: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    bool isWarning = false,
  }) {
    final isSaving = _savingKey == key;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isWarning ? Colors.red : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textHint,
        ),
      ),
      trailing: isSaving
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: value,
              onChanged: (v) => _onPermissionChanged(key, v),
              activeColor: isWarning ? Colors.red : AppColors.primary,
            ),
    );
  }
}
