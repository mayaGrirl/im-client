/// 群管理员列表页面
/// 显示群主和所有管理员

import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/models/group.dart';
import 'package:im_client/l10n/app_localizations.dart';
import '../../utils/image_proxy.dart';

class GroupAdminListScreen extends StatefulWidget {
  final int groupId;
  final bool isOwner;

  const GroupAdminListScreen({
    super.key,
    required this.groupId,
    this.isOwner = false,
  });

  @override
  State<GroupAdminListScreen> createState() => _GroupAdminListScreenState();
}

class _GroupAdminListScreenState extends State<GroupAdminListScreen> {
  final GroupApi _groupApi = GroupApi(ApiClient());

  List<GroupMember> _admins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);
    final admins = await _groupApi.getGroupAdmins(widget.groupId);
    setState(() {
      _admins = admins;
      _isLoading = false;
    });
  }

  /// 获取完整URL（处理相对路径）
  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    // 防止只有 / 的情况
    if (url == '/') return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final baseUrl = EnvConfig.instance.baseUrl;
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.administrators} (${_admins.length})'),
        actions: [
          if (widget.isOwner)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _addAdmin(l10n),
              tooltip: l10n.addAdmin,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAdmins,
              child: _admins.isEmpty
                  ? Center(child: Text(l10n.noAdmins))
                  : ListView.builder(
                      itemCount: _admins.length,
                      itemBuilder: (context, index) {
                        final admin = _admins[index];
                        return _buildAdminItem(admin, l10n);
                      },
                    ),
            ),
    );
  }

  Widget _buildAdminItem(GroupMember admin, AppLocalizations l10n) {
    final avatarUrl = _getFullUrl(admin.avatar);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.1),
        backgroundImage:
            avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
        child: avatarUrl.isEmpty
            ? Text(
                admin.displayName.isNotEmpty
                    ? admin.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: AppColors.primary),
              )
            : null,
      ),
      title: Row(
        children: [
          Text(admin.displayName),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: admin.isOwner ? Colors.orange : AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              admin.isOwner ? l10n.groupOwner : l10n.groupAdmin,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        '@${admin.username}',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textHint,
        ),
      ),
      trailing: widget.isOwner && !admin.isOwner
          ? IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => _removeAdmin(admin, l10n),
            )
          : null,
    );
  }

  void _addAdmin(AppLocalizations l10n) async {
    // 打开成员选择页面
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => _MemberSelectScreen(
          groupId: widget.groupId,
          excludeAdmins: true,
        ),
      ),
    );

    if (result != null) {
      final res = await _groupApi.setGroupAdmin(widget.groupId, result, true);
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminAdded)),
        );
        _loadAdmins();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? l10n.addFailed)),
        );
      }
    }
  }

  void _removeAdmin(GroupMember admin, AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelAdmin),
        content: Text('${l10n.cancelAdminConfirm} ${admin.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res =
          await _groupApi.setGroupAdmin(widget.groupId, admin.userId, false);
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${admin.displayName} ${l10n.adminCancelled}')),
        );
        _loadAdmins();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? l10n.operationFailed)),
        );
      }
    }
  }
}

/// 成员选择页面（内部使用）
class _MemberSelectScreen extends StatefulWidget {
  final int groupId;
  final bool excludeAdmins;

  const _MemberSelectScreen({
    required this.groupId,
    this.excludeAdmins = false,
  });

  @override
  State<_MemberSelectScreen> createState() => _MemberSelectScreenState();
}

class _MemberSelectScreenState extends State<_MemberSelectScreen> {
  final GroupApi _groupApi = GroupApi(ApiClient());

  List<GroupMember> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final members = await _groupApi.getGroupMembers(widget.groupId);
    setState(() {
      if (widget.excludeAdmins) {
        _members = members.where((m) => !m.isAdmin).toList();
      } else {
        _members = members;
      }
      _isLoading = false;
    });
  }

  /// 获取完整URL（处理相对路径）
  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    // 防止只有 / 的情况
    if (url == '/') return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final baseUrl = EnvConfig.instance.baseUrl;
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectMembers),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? Center(child: Text(l10n.noMembersToSelect))
              : ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final avatarUrl = _getFullUrl(member.avatar);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl.proxied)
                            : null,
                        child: avatarUrl.isEmpty
                            ? Text(member.displayName[0].toUpperCase())
                            : null,
                      ),
                      title: Text(member.displayName),
                      subtitle: Text('@${member.username}'),
                      onTap: () => Navigator.pop(context, member.userId),
                    );
                  },
                ),
    );
  }
}
