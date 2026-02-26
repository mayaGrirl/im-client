import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/system_api.dart';
import '../../api/api_client.dart';
import '../../models/system.dart';
import '../../models/user.dart';
import '../../models/message.dart';
import '../../constants/app_constants.dart';
import '../../config/env_config.dart';
import '../../providers/auth_provider.dart';
import '../../utils/conversation_utils.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_screen.dart';
import '../../utils/image_proxy.dart';

/// 标签管理页面
class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  final SystemApi _systemApi = SystemApi();
  List<FriendTag> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    try {
      final tags = await _systemApi.getAllTags();
      setState(() {
        _tags = tags;
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

  void _openTagDetail(FriendTag tag) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TagDetailScreen(tagName: tag.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('tags')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tags.isEmpty
              ? _buildEmptyState(l10n)
              : RefreshIndicator(
                  onRefresh: _loadTags,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _tags.length,
                    itemBuilder: (context, index) {
                      return _buildTagItem(_tags[index], l10n);
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
            Icons.label_outline,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.translate('no_tags'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('add_tags_hint'),
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagItem(FriendTag tag, AppLocalizations l10n) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.label,
          color: AppColors.primary,
        ),
      ),
      title: Text(tag.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.translate('people_count').replaceAll('{count}', '${tag.count}'),
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
      onTap: () => _openTagDetail(tag),
    );
  }
}

/// 标签详情页面（显示该标签下的好友）
class TagDetailScreen extends StatefulWidget {
  final String tagName;

  const TagDetailScreen({super.key, required this.tagName});

  @override
  State<TagDetailScreen> createState() => _TagDetailScreenState();
}

class _TagDetailScreenState extends State<TagDetailScreen> {
  List<Friend> _friends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().get('/tags/${Uri.encodeComponent(widget.tagName)}/friends');
      if (res.success && res.data != null) {
        final list = res.data as List? ?? [];
        setState(() {
          _friends = list.map((e) => Friend.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
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
        title: Text(widget.tagName),
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
            l10n.translate('no_friends_with_tag'),
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
