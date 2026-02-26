/// 漂流瓶对话列表页面
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/drift_bottle_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'drift_bottle_chat_screen.dart';
import '../../utils/image_proxy.dart';

class DriftBottleChatListScreen extends StatefulWidget {
  const DriftBottleChatListScreen({super.key});

  @override
  State<DriftBottleChatListScreen> createState() =>
      _DriftBottleChatListScreenState();
}

class _DriftBottleChatListScreenState extends State<DriftBottleChatListScreen> {
  final DriftBottleApi _api = DriftBottleApi(ApiClient());

  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);

    try {
      final result = await _api.getBottleChats();
      if (result.success && result.data != null) {
        setState(() {
          _chats = List<Map<String, dynamic>>.from(result.data);
        });
      }
    } catch (e) {
      // Load chats failed
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getFullUrl(String url) {
    if (url.isEmpty || url == '/') return '';
    if (url.startsWith('http')) return url;
    return '${EnvConfig.instance.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('drift_conversations')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadChats,
                  child: ListView.builder(
                    itemCount: _chats.length,
                    itemBuilder: (context, index) {
                      return _buildChatItem(_chats[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.translate('no_conversations'),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('conversation_hint'),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chatData) {
    final l10n = AppLocalizations.of(context)!;
    final bottle = DriftBottle.fromJson(chatData);
    final lastReply = chatData['last_reply'] as Map<String, dynamic>?;
    final unreadCount = chatData['unread_count'] as int? ?? 0;
    final user = bottle.user;
    final avatarUrl = user != null ? _getFullUrl(user.avatar) : '';

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: _getGenderColor(bottle.gender).withOpacity(0.2),
        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
        child: avatarUrl.isEmpty
            ? Icon(
                _getGenderIcon(bottle.gender),
                color: _getGenderColor(bottle.gender),
              )
            : null,
      ),
      title: Row(
        children: [
          Text(
            user?.nickname ?? l10n.translate('anonymous_user'),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        lastReply != null
            ? lastReply['content'] ?? bottle.content
            : bottle.content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
        ),
      ),
      trailing: Text(
        _formatTime(bottle.createdAt, l10n),
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 12,
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DriftBottleChatScreen(bottle: bottle),
          ),
        ).then((_) => _loadChats());
      },
    );
  }

  Color _getGenderColor(int gender) {
    switch (gender) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getGenderIcon(int gender) {
    switch (gender) {
      case 1:
        return Icons.male;
      case 2:
        return Icons.female;
      default:
        return Icons.person;
    }
  }

  String _formatTime(DateTime time, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return l10n.translate('just_now');
    } else if (diff.inHours < 1) {
      return l10n.translate('minutes_ago').replaceAll('{count}', diff.inMinutes.toString());
    } else if (diff.inDays < 1) {
      return l10n.translate('hours_ago').replaceAll('{count}', diff.inHours.toString());
    } else if (diff.inDays < 7) {
      return l10n.translate('days_ago').replaceAll('{days}', diff.inDays.toString());
    } else {
      return l10n.translate('date_format')
          .replaceAll('{month}', time.month.toString())
          .replaceAll('{day}', time.day.toString());
    }
  }
}
