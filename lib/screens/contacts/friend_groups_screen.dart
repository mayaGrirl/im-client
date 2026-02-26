import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/friend_api.dart';
import '../../api/api_client.dart';
import '../../models/user.dart';
import '../../models/message.dart';
import '../../constants/app_constants.dart';
import '../../config/env_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../utils/conversation_utils.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_screen.dart';
import '../../utils/image_proxy.dart';

/// 好友分组管理页面
class FriendGroupsScreen extends StatefulWidget {
  const FriendGroupsScreen({super.key});

  @override
  State<FriendGroupsScreen> createState() => _FriendGroupsScreenState();
}

class _FriendGroupsScreenState extends State<FriendGroupsScreen> {
  final FriendApi _friendApi = FriendApi(ApiClient());
  List<FriendGroup> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final groups = await _friendApi.getFriendGroups();
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('load_failed'))),
        );
      }
    }
  }

  Future<void> _createGroup() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await _showNameDialog(title: l10n.translate('new_group'), initialValue: '');
    if (name == null || name.isEmpty) return;

    final res = await _friendApi.createFriendGroup(name);
    if (res.success) {
      _loadGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('create_success')), duration: const Duration(seconds: 1)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? l10n.translate('create_failed'))),
        );
      }
    }
  }

  Future<void> _renameGroup(FriendGroup group) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await _showNameDialog(
      title: l10n.translate('rename_group'),
      initialValue: group.name,
    );
    if (name == null || name.isEmpty || name == group.name) return;

    final res = await _friendApi.updateFriendGroup(group.id, name);
    if (res.success) {
      _loadGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('rename_success')), duration: const Duration(seconds: 1)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? l10n.translate('rename_failed'))),
        );
      }
    }
  }

  Future<void> _deleteGroup(FriendGroup group) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_group')),
        content: Text(l10n.translate('delete_group_confirm').replaceAll('{name}', group.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await _friendApi.deleteFriendGroup(group.id);
      if (res.success) {
        _loadGroups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.deleteSuccess), duration: const Duration(seconds: 1)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.message ?? l10n.translate('delete_failed'))),
          );
        }
      }
    }
  }

  Future<String?> _showNameDialog({
    required String title,
    required String initialValue,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initialValue);
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.translate('input_group_name_hint'),
            border: const OutlineInputBorder(),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _openGroupDetail(FriendGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendGroupDetailScreen(group: group),
      ),
    ).then((_) => _loadGroups());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.friendGroups),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createGroup,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? _buildEmptyState(l10n)
              : RefreshIndicator(
                  onRefresh: _loadGroups,
                  child: ListView.builder(
                    itemCount: _groups.length + 1, // +1 for default group
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildDefaultGroupItem(l10n);
                      }
                      return _buildGroupItem(_groups[index - 1], l10n);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return ListView(
      children: [
        _buildDefaultGroupItem(l10n),
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              const Icon(
                Icons.folder_outlined,
                size: 48,
                color: AppColors.textHint,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.translate('tap_to_create_group'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultGroupItem(AppLocalizations l10n) {
    final chatProvider = context.read<ChatProvider>();
    final friendsWithoutGroup = chatProvider.friends.where((f) => f.groupId == null || f.groupId == 0).length;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.people,
          color: AppColors.primary,
        ),
      ),
      title: Text(l10n.translate('my_friends')),
      subtitle: Text(l10n.translate('default_group')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.translate('people_count').replaceAll('{count}', '$friendsWithoutGroup'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textHint,
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FriendGroupDetailScreen(group: null),
          ),
        );
      },
    );
  }

  Widget _buildGroupItem(FriendGroup group, AppLocalizations l10n) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.folder,
          color: Colors.blue,
        ),
      ),
      title: Text(group.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.translate('people_count').replaceAll('{count}', '${group.friendCount}'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textHint,
          ),
        ],
      ),
      onTap: () => _openGroupDetail(group),
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(l10n.translate('rename')),
                  onTap: () {
                    Navigator.pop(context);
                    _renameGroup(group);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(l10n.translate('delete_group'), style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteGroup(group);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 好友分组详情页面
class FriendGroupDetailScreen extends StatefulWidget {
  final FriendGroup? group;

  const FriendGroupDetailScreen({super.key, required this.group});

  @override
  State<FriendGroupDetailScreen> createState() => _FriendGroupDetailScreenState();
}

class _FriendGroupDetailScreenState extends State<FriendGroupDetailScreen> {
  List<Friend> _friends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.loadFriends();

    setState(() {
      if (widget.group == null) {
        // 默认分组
        _friends = chatProvider.friends.where((f) => f.groupId == null || f.groupId == 0).toList();
      } else {
        _friends = chatProvider.friends.where((f) => f.groupId == widget.group!.id).toList();
      }
      _isLoading = false;
    });
  }

  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    // 防止只有 / 的情况
    if (url == '/') return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final baseUrl = EnvConfig.instance.baseUrl;
    if (url.startsWith('/')) return '$baseUrl$url';
    return '$baseUrl/$url';
  }

  void _openChat(Friend friend) {
    // 使用工具类生成正确的conversId格式
    final auth = context.read<AuthProvider>();
    final conversId = ConversationUtils.generateConversId(
      userId1: auth.userId,
      userId2: friend.friendId,
    );

    final conversation = Conversation(
      conversId: conversId,
      type: 1,
      targetId: friend.friendId,
      lastMsgPreview: '',
      lastMsgTime: DateTime.now(),
      unreadCount: 0,
      isTop: false,
      isMute: false,
      targetInfo: friend.friend,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: conversation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group?.name ?? l10n.translate('my_friends')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
              ? _buildEmptyState(l10n)
              : RefreshIndicator(
                  onRefresh: _loadFriends,
                  child: ListView.builder(
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      return _buildFriendItem(_friends[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_off,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.translate('no_friends_in_group'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendItem(Friend friend) {
    final avatarUrl = _getFullUrl(friend.friend.avatar);

    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
        child: avatarUrl.isEmpty
            ? Text(
                friend.displayName.isNotEmpty ? friend.displayName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary),
              )
            : null,
      ),
      title: Text(friend.displayName),
      subtitle: friend.friend.bio?.isNotEmpty == true
          ? Text(
              friend.friend.bio!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textHint, fontSize: 13),
            )
          : null,
      trailing: friend.isOnline
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(5),
              ),
            )
          : null,
      onTap: () => _openChat(friend),
    );
  }
}
