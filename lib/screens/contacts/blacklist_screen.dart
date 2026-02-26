import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/friend_api.dart';
import '../../api/api_client.dart';
import '../../models/user.dart';
import '../../constants/app_constants.dart';
import '../../config/env_config.dart';
import '../../providers/chat_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/image_proxy.dart';

/// 黑名单页面
class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({super.key});

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  final FriendApi _friendApi = FriendApi(ApiClient());
  List<User> _blacklist = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlacklist();
  }

  Future<void> _loadBlacklist() async {
    setState(() => _isLoading = true);
    try {
      final users = await _friendApi.getBlacklist();
      setState(() {
        _blacklist = users;
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

  Future<void> _removeFromBlacklist(User user) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeFromBlacklist),
        content: Text(l10n.removeFromBlacklistConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 使用 ChatProvider 移除黑名单，会自动刷新好友列表
      final res = await context.read<ChatProvider>().removeFromBlacklist(user.id);
      if (res.success) {
        setState(() {
          _blacklist.removeWhere((u) => u.id == user.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.removedFromBlacklist), duration: const Duration(seconds: 1)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.message ?? l10n.failed)),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.blacklist),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blacklist.isEmpty
              ? _buildEmptyState(l10n)
              : RefreshIndicator(
                  onRefresh: _loadBlacklist,
                  child: ListView.builder(
                    itemCount: _blacklist.length,
                    itemBuilder: (context, index) {
                      return _buildBlacklistItem(_blacklist[index], l10n);
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
            Icons.block,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.blacklistEmpty,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.blacklistHint,
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlacklistItem(User user, AppLocalizations l10n) {
    final avatarUrl = _getFullUrl(user.avatar);

    return Dismissible(
      key: Key('blacklist_${user.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.green,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.remove_circle_outline, color: Colors.white),
            const SizedBox(height: 4),
            Text(l10n.translate('remove_action'), style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.removeFromBlacklist),
            content: Text(l10n.removeFromBlacklistConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        // 使用 ChatProvider 移除黑名单，会自动刷新好友列表
        await context.read<ChatProvider>().removeFromBlacklist(user.id);
        setState(() {
          _blacklist.removeWhere((u) => u.id == user.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.removedFromBlacklist), duration: const Duration(seconds: 1)),
          );
        }
      },
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.grey.withValues(alpha: 0.2),
          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
          child: avatarUrl.isEmpty
              ? Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.grey),
                )
              : null,
        ),
        title: Text(user.displayName),
        subtitle: user.bio?.isNotEmpty == true
            ? Text(
                user.bio!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textHint, fontSize: 13),
              )
            : null,
        trailing: TextButton(
          onPressed: () => _removeFromBlacklist(user),
          child: Text(l10n.translate('remove_action')),
        ),
        onLongPress: () => _showBlacklistMenu(user, l10n),
      ),
    );
  }

  void _showBlacklistMenu(User user, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.remove_circle_outline, color: Colors.green),
                title: Text(l10n.removeFromBlacklist, style: const TextStyle(color: Colors.green)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeFromBlacklist(user);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
