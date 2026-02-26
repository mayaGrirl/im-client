/// 搜索页面
/// 搜索消息、联系人、群聊

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/models/user.dart';
import 'package:im_client/models/group.dart';
import 'package:im_client/models/message.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/providers/chat_provider.dart';
import 'package:im_client/screens/chat/chat_screen.dart';
import 'package:im_client/services/local_database_service.dart';
import 'package:im_client/utils/conversation_utils.dart';
import '../../utils/image_proxy.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _friendApi = FriendApi(ApiClient());
  final _groupApi = GroupApi(ApiClient());
  final _localDb = LocalDatabaseService();

  late TabController _tabController;

  List<Friend> _friendResults = [];
  List<Group> _groupResults = [];
  List<Message> _messageResults = [];

  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // 并行搜索
      final results = await Future.wait([
        _searchFriends(keyword),
        _searchGroups(keyword),
        _searchMessages(keyword),
      ]);

      setState(() {
        _friendResults = results[0] as List<Friend>;
        _groupResults = results[1] as List<Group>;
        _messageResults = results[2] as List<Message>;
      });
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('search_failed')}: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Friend>> _searchFriends(String keyword) async {
    try {
      final friends = await _friendApi.getFriendList();
      return friends.where((f) {
        final name = f.displayName.toLowerCase();
        final username = f.friend.username.toLowerCase();
        final kw = keyword.toLowerCase();
        return name.contains(kw) || username.contains(kw);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Group>> _searchGroups(String keyword) async {
    try {
      return await _groupApi.searchGroup(keyword);
    } catch (e) {
      return [];
    }
  }

  Future<List<Message>> _searchMessages(String keyword) async {
    try {
      return await _localDb.searchMessages(keyword);
    } catch (e) {
      return [];
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _friendResults = [];
      _groupResults = [];
      _messageResults = [];
      _hasSearched = false;
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
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.translate('search_hint'),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: _clearSearch,
                    )
                  : null,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.background,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            onChanged: (_) => setState(() {}),
          ),
        ),
        bottom: _hasSearched
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: '${l10n.contacts}(${_friendResults.length})'),
                  Tab(text: '${l10n.translate("groups")}(${_groupResults.length})'),
                  Tab(text: '${l10n.messages}(${_messageResults.length})'),
                ],
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return _buildSearchHint();
    }

    final totalResults =
        _friendResults.length + _groupResults.length + _messageResults.length;

    if (totalResults == 0) {
      return _buildEmptyResult();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildFriendResults(),
        _buildGroupResults(),
        _buildMessageResults(),
      ],
    );
  }

  Widget _buildSearchHint() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.translate('search_contacts_groups_messages'),
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResult() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.translate('no_results_found'),
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendResults() {
    final l10n = AppLocalizations.of(context)!;
    if (_friendResults.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('no_contacts_found'),
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      itemCount: _friendResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final friend = _friendResults[index];
        final avatarUrl = _getFullUrl(friend.friend.avatar);
        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl.proxied)
                : null,
            child: avatarUrl.isEmpty
                ? Text(
                    friend.displayName.isNotEmpty ? friend.displayName[0] : '?',
                    style: const TextStyle(color: AppColors.primary),
                  )
                : null,
          ),
          title: _highlightText(friend.displayName, _searchController.text),
          subtitle: Text(
            '@${friend.friend.username}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          onTap: () => _startChat(friend),
        );
      },
    );
  }

  Widget _buildGroupResults() {
    final l10n = AppLocalizations.of(context)!;
    if (_groupResults.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('no_groups_found'),
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      itemCount: _groupResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final group = _groupResults[index];
        final avatarUrl = _getFullUrl(group.avatar);
        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl.proxied)
                : null,
            child: avatarUrl.isEmpty
                ? const Icon(Icons.group, color: AppColors.primary)
                : null,
          ),
          title: _highlightText(group.name, _searchController.text),
          subtitle: Text(
            l10n.translate('people_count').replaceAll('{count}', '${group.memberCount}'),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          onTap: () => _openGroup(group),
        );
      },
    );
  }

  Widget _buildMessageResults() {
    final l10n = AppLocalizations.of(context)!;
    if (_messageResults.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('no_messages_found'),
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      itemCount: _messageResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final message = _messageResults[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
          ),
          title: Text(
            '${l10n.translate('conversation_prefix')} ${message.conversId}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: _highlightText(message.content, _searchController.text),
          trailing: Text(
            _formatTime(message.createdAt),
            style: TextStyle(color: AppColors.textHint, fontSize: 12),
          ),
          onTap: () => _openMessage(message),
        );
      },
    );
  }

  Widget _highlightText(String text, String keyword) {
    if (keyword.isEmpty) {
      return Text(text);
    }

    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    final index = lowerText.indexOf(lowerKeyword);

    if (index < 0) {
      return Text(text);
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.textPrimary),
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + keyword.length),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(index + keyword.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays < 1) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 365) {
      return '${time.month}/${time.day}';
    } else {
      return '${time.year}/${time.month}/${time.day}';
    }
  }

  void _startChat(Friend friend) {
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
      targetInfo: {
        'nickname': friend.displayName,
        'avatar': friend.friend.avatar,
      },
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(conversation: conversation),
      ),
    );
  }

  void _openGroup(Group group) async {
    // 检查是否已是群成员
    final myGroups = await _groupApi.getMyGroups();
    final isMember = myGroups.any((g) => g.id == group.id);

    if (isMember) {
      // 已是成员，直接打开聊天
      final conversation = Conversation(
        conversId: 'g_${group.id}',
        type: 2,
        targetId: group.id,
        targetInfo: {
          'id': group.id,
          'name': group.name,
          'avatar': group.avatar,
          // 付费群相关
          'is_paid': group.isPaid,
          'join_price': group.price,
          'join_price_type': group.priceType,
          // 群通话相关
          'allow_group_call': group.allowGroupCall,
          'allow_voice_call': group.allowVoiceCall,
          'allow_video_call': group.allowVideoCall,
        },
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(conversation: conversation),
          ),
        );
      }
    } else {
      // 不是成员，显示加群对话框
      _showJoinGroupDialog(group);
    }
  }

  void _showJoinGroupDialog(Group group) {
    final l10n = AppLocalizations.of(context)!;
    // 检查是否允许搜索加入
    if (!group.allowSearch) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('group_search_forbidden')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // 检查禁止加入和仅限邀请
    if (group.joinMode == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('group_join_forbidden')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (group.joinMode == 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('group_invite_only')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final messageController = TextEditingController();
    final groupAvatarUrl = _getFullUrl(group.avatar);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖动条
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // 群头像
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: groupAvatarUrl.isNotEmpty
                        ? NetworkImage(groupAvatarUrl.proxied)
                        : null,
                    child: groupAvatarUrl.isEmpty
                        ? const Icon(Icons.group, size: 40, color: AppColors.primary)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // 群名称
                Text(
                  group.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // 群信息标签
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildInfoChip(Icons.people, '${group.memberCount}人'),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      _getJoinModeIcon(group.joinMode),
                      _getJoinModeLabel(group.joinMode),
                    ),
                    if (group.isPaid) ...[
                      const SizedBox(width: 12),
                      _buildInfoChip(Icons.monetization_on, '¥${group.price}'),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // 付费群提示
                if (group.isPaid) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.payment, color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.translate('payment_required').replaceAll('{price}', '¥${group.price}'),
                            style: TextStyle(color: AppColors.warning, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 根据加群方式显示不同内容
                if (group.joinMode == 2) ...[
                  // 需要审核
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.translate('group_need_admin_verify'),
                            style: TextStyle(color: AppColors.warning, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: l10n.translate('enter_verify_message_optional'),
                      hintStyle: TextStyle(color: AppColors.textHint),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 3,
                  ),
                ] else ...[
                  // 自由加入
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.translate('group_free_join_hint'),
                            style: TextStyle(color: AppColors.success, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // 操作按钮
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _joinGroup(
                            group,
                            message: messageController.text,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          group.isPaid
                              ? l10n.translate('pay_to_join')
                              : (group.joinMode == 2 ? l10n.translate('send_application') : l10n.translate('join_now')),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  IconData _getJoinModeIcon(int joinMode) {
    switch (joinMode) {
      case 1:
        return Icons.lock_open;
      case 2:
        return Icons.verified_user;
      case 5:
        return Icons.help_outline;
      default:
        return Icons.lock;
    }
  }

  String _getJoinModeLabel(int joinMode) {
    final l10n = AppLocalizations.of(context)!;
    switch (joinMode) {
      case 1:
        return l10n.translate('free_join');
      case 2:
        return l10n.translate('need_verify');
      default:
        return l10n.unknown;
    }
  }

  Future<void> _joinGroup(Group group, {String? message}) async {
    final l10n = AppLocalizations.of(context)!;

    // 付费群需要确认支付
    if (group.isPaid) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.translate('confirm_payment')),
          content: Text(
            l10n.translate('payment_required').replaceAll('{price}', '¥${group.price}'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.translate('pay_to_join')),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      // 调用付费加入API
      final result = await _groupApi.payToJoinGroup(group.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success
              ? l10n.translate('payment_success')
              : result.displayMessage),
          backgroundColor: result.success ? AppColors.success : AppColors.error,
        ),
      );
      return;
    }

    // 普通群加入
    final result = await _groupApi.joinGroup(
      group.id,
      message: message,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.displayMessage),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
      ),
    );
  }

  void _openMessage(Message message) {
    final chatProvider = context.read<ChatProvider>();
    final conversation = chatProvider.conversations.firstWhere(
      (c) => c.conversId == message.conversId,
      orElse: () => Conversation(
        conversId: message.conversId ?? '',
        type: message.groupId != null ? 2 : 1,
        targetId: message.groupId ?? message.toUserId ?? 0,
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(conversation: conversation),
      ),
    );
  }
}
