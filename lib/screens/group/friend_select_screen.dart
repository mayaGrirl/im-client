/// 好友选择页面（用于邀请成员加入群聊）
/// 支持多选好友，排除已在群内的成员

import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/models/group.dart';
import 'package:im_client/models/user.dart';
import 'package:im_client/l10n/app_localizations.dart';
import '../../utils/image_proxy.dart';

class FriendSelectScreen extends StatefulWidget {
  final int groupId;
  final String? title;

  const FriendSelectScreen({
    super.key,
    required this.groupId,
    this.title,
  });

  @override
  State<FriendSelectScreen> createState() => _FriendSelectScreenState();
}

class _FriendSelectScreenState extends State<FriendSelectScreen> {
  final FriendApi _friendApi = FriendApi(ApiClient());
  final GroupApi _groupApi = GroupApi(ApiClient());
  final TextEditingController _searchController = TextEditingController();

  List<Friend> _friends = [];
  List<Friend> _filteredFriends = [];
  Set<int> _existingMemberIds = {};
  Set<int> _selectedIds = {};
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 并行加载好友列表和群成员列表
    final results = await Future.wait([
      _friendApi.getFriendList(),
      _groupApi.getGroupMembers(widget.groupId),
    ]);

    final friends = results[0] as List<Friend>;
    final members = results[1] as List<GroupMember>;

    setState(() {
      _friends = friends;
      _existingMemberIds = members.map((m) => m.userId).toSet();
      _filteredFriends = friends;
      _isLoading = false;
    });
  }

  void _filterFriends(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _friends;
      } else {
        _filteredFriends = _friends.where((f) {
          final displayName = f.remark?.isNotEmpty == true ? f.remark! : f.friend.nickname;
          return displayName.toLowerCase().contains(query.toLowerCase()) ||
              f.friend.username.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _toggleSelection(int friendId) {
    setState(() {
      if (_selectedIds.contains(friendId)) {
        _selectedIds.remove(friendId);
      } else {
        _selectedIds.add(friendId);
      }
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

  Future<void> _confirmInvite() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectFriends)),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await _groupApi.inviteMembers(
      widget.groupId,
      _selectedIds.toList(),
    );

    setState(() => _isSubmitting = false);

    if (result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.invitedFriends}: ${_selectedIds.length}'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? l10n.inviteFailed),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? l10n.inviteMembers),
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: _isSubmitting ? null : _confirmInvite,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Text(
                      '${l10n.confirm}(${_selectedIds.length})',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 搜索框
                Container(
                  padding: const EdgeInsets.all(12),
                  color: AppColors.white,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterFriends,
                    decoration: InputDecoration(
                      hintText: l10n.searchFriends,
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

                // 已选择提示
                if (_selectedIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppColors.primary.withOpacity(0.1),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          '${l10n.selectedPeople}: ${_selectedIds.length}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _selectedIds.clear()),
                          child: Text(
                            l10n.clearSelection,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 好友列表
                Expanded(
                  child: _filteredFriends.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_off,
                                size: 64,
                                color: AppColors.textHint,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? l10n.noFriends
                                    : l10n.noMatchingFriends,
                                style: TextStyle(color: AppColors.textHint),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredFriends.length,
                          itemBuilder: (context, index) {
                            final friend = _filteredFriends[index];
                            return _buildFriendItem(friend, l10n);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFriendItem(Friend friend, AppLocalizations l10n) {
    final isInGroup = _existingMemberIds.contains(friend.friendId);
    final isSelected = _selectedIds.contains(friend.friendId);
    final displayName = friend.remark?.isNotEmpty == true ? friend.remark! : friend.friend.nickname;
    final avatarUrl = _getFullUrl(friend.friend.avatar);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.1),
        backgroundImage:
            avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
        child: avatarUrl.isEmpty
            ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary),
              )
            : null,
      ),
      title: Text(
        displayName,
        style: TextStyle(
          color: isInGroup ? AppColors.textHint : null,
        ),
      ),
      subtitle: Text(
        '@${friend.friend.username}',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textHint,
        ),
      ),
      trailing: isInGroup
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l10n.alreadyInGroup,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            )
          : Checkbox(
              value: isSelected,
              onChanged: (v) => _toggleSelection(friend.friendId),
              activeColor: AppColors.primary,
            ),
      onTap: isInGroup ? null : () => _toggleSelection(friend.friendId),
    );
  }
}
