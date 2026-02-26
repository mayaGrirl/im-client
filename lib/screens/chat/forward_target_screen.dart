/// 转发目标选择页面
/// 支持选择好友或群组作为转发目标

import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/conversation_api.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/models/message.dart';
import 'package:im_client/models/user.dart';
import 'package:im_client/models/group.dart';
import '../../utils/image_proxy.dart';

/// 转发目标选择页面
class ForwardTargetScreen extends StatefulWidget {
  final List<Message> messages;

  const ForwardTargetScreen({
    super.key,
    required this.messages,
  });

  @override
  State<ForwardTargetScreen> createState() => _ForwardTargetScreenState();
}

class _ForwardTargetScreenState extends State<ForwardTargetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendApi _friendApi = FriendApi(ApiClient());
  final GroupApi _groupApi = GroupApi(ApiClient());
  final ConversationApi _conversationApi = ConversationApi(ApiClient());

  List<Friend> _friends = [];
  List<Group> _groups = [];
  bool _isLoading = true;
  bool _isForwarding = false;

  // 选中的目标
  final Set<int> _selectedUserIds = {};
  final Set<int> _selectedGroupIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _friendApi.getFriendList(),
        _groupApi.getMyGroups(),
      ]);
      setState(() {
        _friends = results[0] as List<Friend>;
        _groups = results[1] as List<Group>;
      });
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('load_failed')}: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 获取完整URL（处理相对路径）
  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    // 防止只有 / 的情况
    if (url == '/') return '';
    // 统一将反斜杠替换为正斜杠（Windows路径兼容）
    url = url.replaceAll('\\', '/');
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
    final selectedCount = _selectedUserIds.length + _selectedGroupIds.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('select_forward_target')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.translate('contacts')),
            Tab(text: l10n.groupChat),
          ],
        ),
      ),
      body: Column(
        children: [
          // 已选择的目标预览
          if (selectedCount > 0) _buildSelectedPreview(l10n),
          // 列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFriendList(l10n),
                      _buildGroupList(l10n),
                    ],
                  ),
          ),
          // 底部确认按钮
          _buildBottomBar(selectedCount, l10n),
        ],
      ),
    );
  }

  /// 构建已选择目标预览
  Widget _buildSelectedPreview(AppLocalizations l10n) {
    final selectedItems = <Widget>[];

    // 添加选中的好友
    for (final userId in _selectedUserIds) {
      final friend = _friends.firstWhere(
        (f) => f.friendId == userId,
        orElse: () => _friends.first,
      );
      if (_friends.any((f) => f.friendId == userId)) {
        selectedItems.add(_buildSelectedChip(
          friend.displayName,
          friend.friend.avatar,
          () => _toggleUserSelection(userId),
        ));
      }
    }

    // 添加选中的群组
    for (final groupId in _selectedGroupIds) {
      final group = _groups.firstWhere(
        (g) => g.id == groupId,
        orElse: () => _groups.first,
      );
      if (_groups.any((g) => g.id == groupId)) {
        selectedItems.add(_buildSelectedChip(
          group.name,
          group.avatar,
          () => _toggleGroupSelection(groupId),
          isGroup: true,
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('selected_count').replaceAll('{count}', '${_selectedUserIds.length + _selectedGroupIds.length}'),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedItems,
          ),
        ],
      ),
    );
  }

  /// 构建已选择的标签
  Widget _buildSelectedChip(String name, String avatar, VoidCallback onRemove, {bool isGroup = false}) {
    final avatarUrl = _getFullUrl(avatar);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: isGroup
                ? AppColors.secondary.withOpacity(0.1)
                : AppColors.primary.withOpacity(0.1),
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
            child: avatarUrl.isEmpty
                ? Icon(
                    isGroup ? Icons.group : Icons.person,
                    size: 12,
                    color: isGroup ? AppColors.secondary : AppColors.primary,
                  )
                : null,
          ),
          const SizedBox(width: 4),
          Text(
            name.length > 6 ? '${name.substring(0, 6)}...' : name,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部按钮栏
  Widget _buildBottomBar(int selectedCount, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: selectedCount > 0 && !_isForwarding
                ? _onConfirmForward
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.divider,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _isForwarding
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    selectedCount > 0
                        ? l10n.translate('confirm_forward').replaceAll('{count}', '$selectedCount')
                        : l10n.translate('please_select_forward_target'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// 构建好友列表
  Widget _buildFriendList(AppLocalizations l10n) {
    if (_friends.isEmpty) {
      return Center(
        child: Text(l10n.translate('no_friends'), style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        final isSelected = _selectedUserIds.contains(friend.friendId);
        final avatarUrl = _getFullUrl(friend.friend.avatar);
        final displayName = friend.displayName;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl.proxied)
                : null,
            child: avatarUrl.isEmpty
                ? Text(
                    displayName.isNotEmpty ? displayName[0] : '?',
                    style: const TextStyle(color: AppColors.primary),
                  )
                : null,
          ),
          title: Text(displayName),
          trailing: _buildCheckbox(isSelected),
          onTap: () => _toggleUserSelection(friend.friendId),
        );
      },
    );
  }

  /// 构建群组列表
  Widget _buildGroupList(AppLocalizations l10n) {
    if (_groups.isEmpty) {
      return Center(
        child: Text(l10n.translate('no_groups'), style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        final isSelected = _selectedGroupIds.contains(group.id);
        final avatarUrl = _getFullUrl(group.avatar);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.secondary.withOpacity(0.1),
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl.proxied)
                : null,
            child: avatarUrl.isEmpty
                ? const Icon(Icons.group, color: AppColors.secondary)
                : null,
          ),
          title: Text(group.name),
          subtitle: Text(l10n.translate('people_count').replaceAll('{count}', '${group.memberCount}')),
          trailing: _buildCheckbox(isSelected),
          onTap: () => _toggleGroupSelection(group.id),
        );
      },
    );
  }

  /// 构建复选框
  Widget _buildCheckbox(bool isSelected) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.textHint,
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }

  void _toggleUserSelection(int userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  void _toggleGroupSelection(int groupId) {
    setState(() {
      if (_selectedGroupIds.contains(groupId)) {
        _selectedGroupIds.remove(groupId);
      } else {
        _selectedGroupIds.add(groupId);
      }
    });
  }

  /// 确认转发
  void _onConfirmForward() {
    final messageCount = widget.messages.length;

    // 单条消息直接转发（逐条转发）
    if (messageCount == 1) {
      _doForward(ForwardType.oneByOne);
      return;
    }

    // 多条消息显示转发方式选择
    _showForwardTypeDialog();
  }

  /// 显示转发类型选择对话框
  void _showForwardTypeDialog() {
    final l10n = AppLocalizations.of(context)!;
    final messageCount = widget.messages.length;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.translate('select_forward_method'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.list_alt, color: AppColors.primary),
              ),
              title: Text(l10n.translate('forward_one_by_one')),
              subtitle: Text(l10n.translate('forward_one_by_one_desc').replaceAll('{count}', '$messageCount')),
              onTap: () {
                Navigator.pop(context);
                _doForward(ForwardType.oneByOne);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder_copy, color: AppColors.secondary),
              ),
              title: Text(l10n.translate('forward_merge')),
              subtitle: Text(l10n.translate('forward_merged_desc').replaceAll('{count}', '$messageCount')),
              onTap: () {
                Navigator.pop(context);
                _showMergedTitleDialog();
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示合并转发标题输入对话框
  void _showMergedTitleDialog() {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: l10n.translate('chat_history'));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('set_title')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.translate('enter_chat_record_title'),
            border: const OutlineInputBorder(),
          ),
          maxLength: 30,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _doForward(ForwardType.merged, title: controller.text.trim());
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  /// 执行转发
  Future<void> _doForward(int forwardType, {String? title}) async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedUserIds.isEmpty && _selectedGroupIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('please_select_forward_target'))),
      );
      return;
    }

    setState(() => _isForwarding = true);

    try {
      // 发送完整消息内容（服务端只做中转，不查询消息）
      final result = await _conversationApi.forwardMessages(
        messages: widget.messages,
        toUserIds: _selectedUserIds.toList(),
        groupIds: _selectedGroupIds.toList(),
        forwardType: forwardType,
        title: title,
      );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('forward_success'))),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.displayMessage)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('forward_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isForwarding = false);
      }
    }
  }
}
