/// 群成员列表页面
/// 显示所有群成员，支持踢人、禁言等操作

import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/api/user_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/models/group.dart';
import 'package:im_client/l10n/app_localizations.dart';
import '../../utils/image_proxy.dart';

class GroupMemberListScreen extends StatefulWidget {
  final int groupId;
  final bool isAdmin;
  final bool isOwner;
  final bool canKick;
  final bool canMute;
  final bool selectMode;
  final String? selectTitle;
  final bool allowAddFriend;
  final int? currentUserId;

  const GroupMemberListScreen({
    super.key,
    required this.groupId,
    this.isAdmin = false,
    this.isOwner = false,
    this.canKick = false,
    this.canMute = false,
    this.selectMode = false,
    this.selectTitle,
    this.allowAddFriend = true,
    this.currentUserId,
  });

  @override
  State<GroupMemberListScreen> createState() => _GroupMemberListScreenState();
}

class _GroupMemberListScreenState extends State<GroupMemberListScreen> {
  final GroupApi _groupApi = GroupApi(ApiClient());
  final FriendApi _friendApi = FriendApi(ApiClient());
  final UserApi _userApi = UserApi(ApiClient());
  final TextEditingController _searchController = TextEditingController();

  List<GroupMember> _members = [];
  List<GroupMember> _filteredMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final members = await _groupApi.getGroupMembers(widget.groupId);
    setState(() {
      _members = members;
      _filteredMembers = members;
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

  void _filterMembers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = _members;
      } else {
        _filteredMembers = _members.where((m) {
          return m.displayName.toLowerCase().contains(query.toLowerCase()) ||
              m.username.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectTitle ?? '${l10n.groupMembers} (${_members.length})'),
      ),
      body: Column(
        children: [
          // 搜索框
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.white,
            child: TextField(
              controller: _searchController,
              onChanged: _filterMembers,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ),
          // 成员列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadMembers,
                    child: ListView.builder(
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];
                        return _buildMemberItem(member, l10n);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberItem(GroupMember member, AppLocalizations l10n) {
    final avatarUrl = _getFullUrl(member.avatar);
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
            child: avatarUrl.isEmpty
                ? Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: AppColors.primary),
                  )
                : null,
          ),
          if (member.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Text(member.displayName),
          if (member.isOwner) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l10n.groupOwner,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ] else if (member.isAdmin) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l10n.groupAdmin,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          if (member.isMute) ...[
            const SizedBox(width: 6),
            const Icon(Icons.volume_off, size: 14, color: Colors.grey),
          ],
        ],
      ),
      subtitle: Text(
        '@${member.username}',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textHint,
        ),
      ),
      trailing: widget.selectMode
          ? const Icon(Icons.chevron_right, color: AppColors.textHint)
          : null,
      onTap: () {
        if (widget.selectMode) {
          // 选择模式：返回选中的用户ID
          final l10n = AppLocalizations.of(context)!;
          if (!member.isOwner) {
            Navigator.pop(context, member.userId);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.cannotSelectOwner)),
            );
          }
        } else if (member.userId == widget.currentUserId) {
          // 自己不能点击
          return;
        } else if (!widget.allowAddFriend && !widget.isAdmin && !widget.isOwner) {
          // 如果关闭了允许成员互加好友，且当前用户不是管理员/群主，则不能点击
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.ownerForbidAddFriend)),
          );
        } else {
          _showMemberActions(member);
        }
      },
    );
  }

  void _showMemberActions(GroupMember member) {
    // 点击自己不显示操作
    if (member.userId == widget.currentUserId) {
      return;
    }

    // 不能对群主操作（除非是查看资料）
    final actions = <Widget>[];

    final l10n = AppLocalizations.of(context)!;
    // 非管理员/群主用户，如果群主禁止成员互加好友，则不允许查看资料和添加好友
    if (!widget.allowAddFriend && !widget.isAdmin && !widget.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.ownerForbidAddFriend),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // 查看资料（管理员/群主总是可以看，普通成员需要allowAddFriend开启）
    actions.add(
      ListTile(
        leading: const Icon(Icons.person),
        title: Text(l10n.viewProfile),
        onTap: () {
          Navigator.pop(context);
          _showUserProfile(member);
        },
      ),
    );

    // 添加好友（只有开启了允许互加好友才显示，或者是管理员/群主）
    if (widget.allowAddFriend || widget.isAdmin || widget.isOwner) {
      actions.add(
        ListTile(
          leading: const Icon(Icons.person_add, color: AppColors.primary),
          title: Text(l10n.addFriend),
          onTap: () {
            Navigator.pop(context);
            _addFriend(member);
          },
        ),
      );
    }

    // 群主不能被操作（除了查看资料）
    if (member.isOwner) {
      if (actions.isEmpty) return;
      // 只显示查看资料
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMemberHeader(member),
              const Divider(height: 1),
              ...actions,
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      return;
    }

    // 管理员可以的操作
    if (widget.isAdmin && !member.isAdmin) {
      // 踢人
      if (widget.canKick) {
        actions.add(
          ListTile(
            leading: const Icon(Icons.person_remove, color: Colors.orange),
            title: Text(l10n.removeFromGroup, style: const TextStyle(color: Colors.orange)),
            onTap: () {
              Navigator.pop(context);
              _kickMember(member);
            },
          ),
        );
      }

      // 禁言
      if (widget.canMute) {
        actions.add(
          ListTile(
            leading: Icon(
              member.isMute ? Icons.volume_up : Icons.volume_off,
              color: member.isMute ? Colors.green : Colors.orange,
            ),
            title: Text(
              member.isMute ? l10n.unmute : l10n.mute,
              style: TextStyle(
                color: member.isMute ? Colors.green : Colors.orange,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _muteMember(member);
            },
          ),
        );
      }
    }

    // 群主特有操作
    if (widget.isOwner) {
      // 设置/取消管理员
      actions.add(
        ListTile(
          leading: Icon(
            member.isAdmin ? Icons.shield_outlined : Icons.shield,
            color: AppColors.primary,
          ),
          title: Text(member.isAdmin ? l10n.cancelAdmin : l10n.setAsAdmin),
          onTap: () {
            Navigator.pop(context);
            _toggleAdmin(member);
          },
        ),
      );

      // 踢人（群主可以踢管理员）
      if (!member.isAdmin || widget.isOwner) {
        actions.add(
          ListTile(
            leading: const Icon(Icons.person_remove, color: Colors.orange),
            title: Text(l10n.removeFromGroup, style: const TextStyle(color: Colors.orange)),
            onTap: () {
              Navigator.pop(context);
              _kickMember(member);
            },
          ),
        );
      }

      // 禁言
      actions.add(
        ListTile(
          leading: Icon(
            member.isMute ? Icons.volume_up : Icons.volume_off,
            color: member.isMute ? Colors.green : Colors.orange,
          ),
          title: Text(
            member.isMute ? l10n.unmute : l10n.mute,
            style: TextStyle(
              color: member.isMute ? Colors.green : Colors.orange,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            _muteMember(member);
          },
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMemberHeader(member),
            const Divider(height: 1),
            ...actions,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberHeader(GroupMember member) {
    final avatarUrl = _getFullUrl(member.avatar);
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl.proxied)
                : null,
            child: avatarUrl.isEmpty
                ? Text(member.displayName[0].toUpperCase())
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '@${member.username}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _kickMember(GroupMember member) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeFromGroup),
        content: Text(l10n.removeFromGroupConfirm.replaceAll('{name}', member.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm, style: const TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _groupApi.kickMember(widget.groupId, member.userId);
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.memberRemoved)),
        );
        _loadMembers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? l10n.operationFailed)),
        );
      }
    }
  }

  Future<void> _muteMember(GroupMember member) async {
    final l10n = AppLocalizations.of(context)!;
    if (member.isMute) {
      // 解除禁言
      final res = await _groupApi.muteMember(widget.groupId, member.userId, 0);
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.memberUnmuted)),
        );
        _loadMembers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? l10n.operationFailed)),
        );
      }
    } else {
      // 选择禁言时长
      final duration = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(l10n.muteFor.replaceAll('{name}', member.displayName)),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 10),
              child: Text(l10n.tenMinutes),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 60),
              child: Text(l10n.oneHour),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 720),
              child: Text(l10n.twelveHours),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 1440),
              child: Text(l10n.oneDay),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 10080),
              child: Text(l10n.sevenDays),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 43200),
              child: Text(l10n.thirtyDays),
            ),
          ],
        ),
      );

      if (duration != null) {
        final res =
            await _groupApi.muteMember(widget.groupId, member.userId, duration);
        if (res.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.memberMuted)),
          );
          _loadMembers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.message ?? l10n.operationFailed)),
          );
        }
      }
    }
  }

  Future<void> _toggleAdmin(GroupMember member) async {
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = member.isAdmin;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAdmin ? l10n.cancelAdmin : l10n.setAsAdmin),
        content: Text(isAdmin
            ? l10n.cancelAdminConfirm.replaceAll('{name}', member.displayName)
            : l10n.setAdminConfirm.replaceAll('{name}', member.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _groupApi.setGroupAdmin(
        widget.groupId,
        member.userId,
        !isAdmin,
      );
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAdmin ? l10n.adminCancelled : l10n.adminSet,
            ),
          ),
        );
        _loadMembers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? l10n.operationFailed)),
        );
      }
    }
  }

  /// 显示用户资料
  Future<void> _showUserProfile(GroupMember member) async {
    // 获取用户详细信息
    final userInfo = await _userApi.getUserById(member.userId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final avatarUrl = _getFullUrl(member.avatar);
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头像
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl.proxied)
                    : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        member.displayName.isNotEmpty
                            ? member.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 32,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
            const SizedBox(height: 12),
            // 昵称
            Text(
              member.displayName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            // 用户名
            Text(
              '@${member.username}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            // 详细信息
            if (userInfo != null) ...[
              if (userInfo['bio'] != null && (userInfo['bio'] as String).isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    userInfo['bio'] as String,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              // 性别和地区
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (userInfo['gender'] != null && userInfo['gender'] != 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: userInfo['gender'] == 1
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.pink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            userInfo['gender'] == 1 ? Icons.male : Icons.female,
                            size: 14,
                            color: userInfo['gender'] == 1 ? Colors.blue : Colors.pink,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            userInfo['gender'] == 1 ? AppLocalizations.of(context)!.male : AppLocalizations.of(context)!.female,
                            style: TextStyle(
                              fontSize: 12,
                              color: userInfo['gender'] == 1 ? Colors.blue : Colors.pink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (userInfo['region'] != null && (userInfo['region'] as String).isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            userInfo['region'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 20),
            // 操作按钮
            if (widget.allowAddFriend && member.userId != widget.currentUserId)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _addFriend(member);
                  },
                  icon: const Icon(Icons.person_add),
                  label: Text(AppLocalizations.of(context)!.addFriend),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
      },
    );
  }

  /// 添加好友
  Future<void> _addFriend(GroupMember member) async {
    final l10n = AppLocalizations.of(context)!;
    // 检查是否已经是好友
    final existingFriend = await _friendApi.getFriendById(member.userId);

    if (!mounted) return;

    if (existingFriend != null) {
      // 已经是好友
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.alreadyFriend),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // 发送好友请求
    final result = await _friendApi.addFriend(
      userId: member.userId,
      source: l10n.translate('group_chat'),
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.friendRequestSent),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? l10n.friendRequestFailed),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
