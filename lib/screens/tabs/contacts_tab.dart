/// 通讯录Tab
/// 显示好友、群组列表（与聊天列表分离）

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/providers/chat_provider.dart';
import 'package:im_client/models/user.dart';
import 'package:im_client/screens/chat/chat_screen.dart';
import 'package:im_client/screens/friend/add_friend_screen.dart';
import 'package:im_client/screens/group/group_list_screen.dart';
import 'package:im_client/screens/contacts/customer_service_screen.dart';
import 'package:im_client/screens/contacts/tags_screen.dart';
import 'package:im_client/screens/contacts/blacklist_screen.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/screens/call/call_screen.dart';
import 'package:im_client/api/call_api.dart';
import '../../utils/image_proxy.dart';

/// 通讯录Tab页
class ContactsTab extends StatefulWidget {
  final bool isVisible;
  const ContactsTab({super.key, this.isVisible = false});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _letterKeys = {};
  final FriendApi _friendApi = FriendApi(ApiClient());
  String _currentLetter = '';
  FriendStats? _friendStats;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadFriends();
      context.read<ChatProvider>().loadFriendRequests();
      _loadFriendStats();
    });
  }

  Future<void> _loadFriendStats() async {
    final stats = await _friendApi.getFriendStats();
    if (mounted && stats != null) {
      setState(() {
        _friendStats = stats;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ContactsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换到通讯录tab时自动刷新好友列表
    if (widget.isVisible && !oldWidget.isVisible) {
      _refreshContacts();
    }
  }

  Future<void> _refreshContacts() async {
    if (!mounted) return;
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.loadFriends();
    await chatProvider.loadFriendRequests();
    await _loadFriendStats();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.contacts),
            if (_friendStats != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _friendStats!.canAdd
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _friendStats!.displayText,
                  style: TextStyle(
                    fontSize: 12,
                    color: _friendStats!.canAdd ? AppColors.primary : Colors.orange,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () {
              _showAddFriendDialog(context);
            },
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final groupedFriends = chatProvider.groupedFriends;
          final letters = groupedFriends.keys.toList();

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refreshContacts,
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    // 功能入口
                    _buildFunctionSection(chatProvider),
                    const SizedBox(height: 10),
                    // 好友列表
                    _buildFriendList(chatProvider),
                  ],
                ),
              ),
              // 右侧字母索引
              if (letters.isNotEmpty)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: _buildIndexBar(letters),
                ),
              // 当前字母提示
              if (_currentLetter.isNotEmpty)
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _currentLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 构建功能入口区域
  Widget _buildFunctionSection(ChatProvider chatProvider) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // 主要功能入口
        Container(
          color: AppColors.white,
          child: Column(
            children: [
              // 客服（原系统通知位置）
              _buildFunctionItem(
                icon: Icons.support_agent,
                title: l10n.translate('customer_service'),
                iconColor: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomerServiceScreen()),
                  );
                },
              ),
              const Divider(indent: 56, height: 1),
              // 新的朋友
              _buildFunctionItem(
                icon: Icons.people_outline,
                title: l10n.newFriend,
                badge: chatProvider.unreadFriendRequestCount,
                iconColor: Colors.green,
                onTap: () {
                  _showFriendRequestsPage(context);
                },
              ),
              const Divider(indent: 56, height: 1),
              // 群聊
              _buildFunctionItem(
                icon: Icons.group_outlined,
                title: l10n.groupChat,
                iconColor: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GroupListScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        // 次要功能入口（标签、黑名单）
        Container(
          margin: const EdgeInsets.only(top: 10),
          color: AppColors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildCompactFunctionItem(
                  icon: Icons.label_outline,
                  title: l10n.translate('tags'),
                  iconColor: Colors.teal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TagsScreen()),
                    );
                  },
                ),
              ),
              Container(width: 1, height: 50, color: AppColors.divider),
              Expanded(
                child: _buildCompactFunctionItem(
                  icon: Icons.block_outlined,
                  title: l10n.translate('blacklist'),
                  iconColor: Colors.grey,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BlacklistScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建右侧字母索引条
  Widget _buildIndexBar(List<String> letters) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        _onIndexBarDrag(details, letters);
      },
      onVerticalDragEnd: (_) {
        setState(() => _currentLetter = '');
      },
      child: Container(
        width: 24,
        margin: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: letters.map((letter) {
            return GestureDetector(
              onTap: () => _scrollToLetter(letter),
              child: Container(
                height: 18,
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _currentLetter == letter
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 处理索引条拖动
  void _onIndexBarDrag(DragUpdateDetails details, List<String> letters) {
    if (letters.isEmpty) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    // 计算索引条的起始位置和高度
    final barTop = 60.0; // margin top
    final barHeight = letters.length * 18.0;
    final localY = details.localPosition.dy - barTop;

    if (localY < 0 || localY > barHeight) return;

    final index = (localY / 18).floor().clamp(0, letters.length - 1);
    final letter = letters[index];

    if (_currentLetter != letter) {
      setState(() => _currentLetter = letter);
      _scrollToLetter(letter);
    }
  }

  /// 滚动到指定字母
  void _scrollToLetter(String letter) {
    final key = _letterKeys[letter];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 构建紧凑型功能入口项（用于次要功能）
  Widget _buildCompactFunctionItem({
    required IconData icon,
    required String title,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建功能入口项
  Widget _buildFunctionItem({
    required IconData icon,
    required String title,
    int badge = 0,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    final color = iconColor ?? AppColors.primary;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
      onTap: onTap,
    );
  }

  /// 构建好友列表
  Widget _buildFriendList(ChatProvider chatProvider) {
    final l10n = AppLocalizations.of(context)!;
    final groupedFriends = chatProvider.groupedFriends;

    if (groupedFriends.isEmpty) {
      return Container(
        color: AppColors.white,
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.person_outline,
                size: 48,
                color: AppColors.textHint,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.translate('no_friends'),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 确保每个字母都有对应的 GlobalKey
    for (final letter in groupedFriends.keys) {
      _letterKeys.putIfAbsent(letter, () => GlobalKey());
    }

    return Container(
      color: AppColors.white,
      child: Column(
        children: groupedFriends.entries.expand((entry) {
          final letter = entry.key;
          final friends = entry.value;
          return [
            // 字母标题（带 GlobalKey 用于滚动定位）
            Container(
              key: _letterKeys[letter],
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.background,
              child: Text(
                letter,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            // 该字母下的好友
            ...friends.asMap().entries.map((friendEntry) {
              final index = friendEntry.key;
              final friend = friendEntry.value;
              return Column(
                children: [
                  _buildFriendItem(friend),
                  if (index < friends.length - 1) const Divider(indent: 76, height: 1),
                ],
              );
            }),
          ];
        }).toList(),
      ),
    );
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

  /// 构建好友项
  Widget _buildFriendItem(Friend friend) {
    final avatarUrl = _getFullUrl(friend.friend.avatar);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.1),
        backgroundImage: avatarUrl.isNotEmpty
            ? NetworkImage(avatarUrl.proxied)
            : null,
        child: avatarUrl.isEmpty
            ? Text(
                friend.displayName.isNotEmpty ? friend.displayName[0] : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Text(friend.displayName),
          const SizedBox(width: 8),
          if (friend.isOnline)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: friend.friend.bio != null && friend.friend.bio!.isNotEmpty
          ? Text(
              friend.friend.bio!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 12,
              ),
            )
          : null,
      onTap: () {
        _showFriendDetailSheet(context, friend);
      },
      onLongPress: () {
        _showFriendOptionsMenu(context, friend);
      },
    );
  }

  /// 显示好友详情底部弹窗
  void _showFriendDetailSheet(BuildContext context, Friend friend) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 头像和名称
              Builder(builder: (context) {
                final avatarUrl = _getFullUrl(friend.friend.avatar);
                return CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl.proxied)
                      : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          friend.displayName.isNotEmpty ? friend.displayName[0] : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        )
                      : null,
                );
              }),
              const SizedBox(height: 12),
              Text(
                friend.displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (friend.remark != null && friend.remark!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${AppLocalizations.of(context)!.translate('nickname_colon')}${friend.friend.nickname}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              // 备注信息区域
              if (friend.remarkPhone != null && friend.remarkPhone!.isNotEmpty ||
                  friend.remarkEmail != null && friend.remarkEmail!.isNotEmpty ||
                  friend.remarkTags != null && friend.remarkTags!.isNotEmpty ||
                  friend.remarkDesc != null && friend.remarkDesc!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (friend.remarkPhone != null && friend.remarkPhone!.isNotEmpty)
                        _buildInfoRow(Icons.phone, AppLocalizations.of(context)!.translate('phone_label'), friend.remarkPhone!),
                      if (friend.remarkEmail != null && friend.remarkEmail!.isNotEmpty)
                        _buildInfoRow(Icons.email, AppLocalizations.of(context)!.translate('email_label'), friend.remarkEmail!),
                      if (friend.remarkTags != null && friend.remarkTags!.isNotEmpty)
                        _buildInfoRow(Icons.label, AppLocalizations.of(context)!.translate('tags_label'), friend.remarkTags!),
                      if (friend.remarkDesc != null && friend.remarkDesc!.isNotEmpty)
                        _buildInfoRow(Icons.info, AppLocalizations.of(context)!.translate('remark_note'), friend.remarkDesc!),
                    ],
                  ),
                ),
              if (friend.friend.bio != null && friend.friend.bio!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    friend.friend.bio!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.chat,
                    label: AppLocalizations.of(context)!.translate('send_msg'),
                    onTap: () {
                      Navigator.pop(context);
                      _startChat(friend);
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.videocam,
                    label: AppLocalizations.of(context)!.videoCall,
                    onTap: () {
                      Navigator.pop(context);
                      _startCall(friend, CallType.video);
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.phone,
                    label: AppLocalizations.of(context)!.voiceCall,
                    onTap: () {
                      Navigator.pop(context);
                      _startCall(friend, CallType.voice);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// 构建备注信息行
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// 发起聊天
  void _startChat(Friend friend) async {
    final chatProvider = context.read<ChatProvider>();

    // 创建或获取会话
    final conversation = await chatProvider.getOrCreateConversation(
      targetId: friend.friendId,
      type: 1, // 私聊
      targetInfo: {
        'nickname': friend.displayName,
        'avatar': friend.friend.avatar,
      },
    );

    // 导航到聊天页面
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(conversation: conversation),
        ),
      );
    }
  }

  /// 发起通话
  void _startCall(Friend friend, int callType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          targetUserId: friend.friendId,
          targetUserName: friend.displayName,
          targetUserAvatar: _getFullUrl(friend.friend.avatar),
          callType: callType,
          isIncoming: false,
        ),
      ),
    );
  }

  /// 显示好友选项菜单
  void _showFriendOptionsMenu(BuildContext context, Friend friend) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(l10n.translate('set_remark')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRemarkDialog(context, friend);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.orange),
                title: Text(l10n.translate('add_to_blacklist'), style: const TextStyle(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToBlacklistDialog(context, friend);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: Text(l10n.translate('delete_friend'), style: const TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteFriendDialog(context, friend);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示加入黑名单确认对话框
  void _showAddToBlacklistDialog(BuildContext context, Friend friend) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(dialogL10n.translate('add_to_blacklist')),
          content: Text(dialogL10n.translate('add_to_blacklist_confirm').replaceAll('{name}', friend.displayName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(dialogL10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await context.read<ChatProvider>().addToBlacklist(friend.friendId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.success ? l10n.translate('added_to_blacklist') : (result.message ?? l10n.translate('operation_failed'))),
                      backgroundColor: result.success ? AppColors.success : AppColors.error,
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: Text(dialogL10n.confirm),
            ),
          ],
        );
      },
    );
  }

  /// 显示设置备注对话框
  void _showRemarkDialog(BuildContext context, Friend friend) {
    final remarkController = TextEditingController(text: friend.remark ?? '');
    final phoneController = TextEditingController(text: friend.remarkPhone ?? '');
    final emailController = TextEditingController(text: friend.remarkEmail ?? '');
    final tagsController = TextEditingController(text: friend.remarkTags ?? '');
    final descController = TextEditingController(text: friend.remarkDesc ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题栏
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Builder(builder: (context) {
                            final avatarUrl = _getFullUrl(friend.friend.avatar);
                            return CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl.proxied)
                                  : null,
                              child: avatarUrl.isEmpty
                                  ? Text(
                                      friend.displayName.isNotEmpty ? friend.displayName[0] : '?',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            );
                          }),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.translate('set_remark'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                friend.friend.nickname,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 备注名
                  _buildRemarkInputField(
                    controller: remarkController,
                    icon: Icons.person_outline,
                    label: AppLocalizations.of(context)!.translate('remark_name'),
                    hint: AppLocalizations.of(context)!.translate('remark_name_hint'),
                  ),
                  const SizedBox(height: 12),
                  // 电话
                  _buildRemarkInputField(
                    controller: phoneController,
                    icon: Icons.phone_outlined,
                    label: AppLocalizations.of(context)!.translate('phone_label'),
                    hint: AppLocalizations.of(context)!.translate('phone_hint'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  // 邮箱
                  _buildRemarkInputField(
                    controller: emailController,
                    icon: Icons.email_outlined,
                    label: AppLocalizations.of(context)!.translate('email_label'),
                    hint: AppLocalizations.of(context)!.translate('email_hint'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  // 标签
                  _buildRemarkInputField(
                    controller: tagsController,
                    icon: Icons.label_outline,
                    label: AppLocalizations.of(context)!.translate('tags_label'),
                    hint: AppLocalizations.of(context)!.translate('tags_hint'),
                  ),
                  const SizedBox(height: 12),
                  // 描述
                  _buildRemarkInputField(
                    controller: descController,
                    icon: Icons.notes_outlined,
                    label: AppLocalizations.of(context)!.translate('description'),
                    hint: AppLocalizations.of(context)!.translate('description_hint'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _updateFriendRemark(
                          context,
                          friend.friendId,
                          remark: remarkController.text.trim(),
                          remarkPhone: phoneController.text.trim(),
                          remarkEmail: emailController.text.trim(),
                          remarkTags: tagsController.text.trim(),
                          remarkDesc: descController.text.trim(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(AppLocalizations.of(context)!.save, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建备注输入字段
  Widget _buildRemarkInputField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  /// 更新好友备注
  Future<void> _updateFriendRemark(
    BuildContext context,
    int friendId, {
    String? remark,
    String? remarkPhone,
    String? remarkEmail,
    String? remarkTags,
    String? remarkDesc,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final chatProvider = context.read<ChatProvider>();
      final result = await chatProvider.updateFriendRemark(
        friendId,
        remark: remark,
        remarkPhone: remarkPhone,
        remarkEmail: remarkEmail,
        remarkTags: remarkTags,
        remarkDesc: remarkDesc,
      );
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('remark_updated')), duration: const Duration(seconds: 1)),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? l10n.translate('update_failed'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('update_failed')}: $e')),
        );
      }
    }
  }

  /// 显示删除好友确认对话框
  void _showDeleteFriendDialog(BuildContext context, Friend friend) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(dialogL10n.translate('delete_friend')),
          content: Text(dialogL10n.translate('delete_friend_confirm').replaceAll('{name}', friend.displayName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(dialogL10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await context.read<ChatProvider>().deleteFriend(friend.friendId);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.displayMessage),
                    backgroundColor: result.success ? AppColors.success : AppColors.error,
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: Text(dialogL10n.delete),
            ),
          ],
        );
      },
    );
  }

  /// 打开添加好友页面
  void _showAddFriendDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddFriendScreen()),
    );
  }

  /// 显示好友申请页面
  void _showFriendRequestsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FriendRequestsPage(),
      ),
    );
  }
}

/// 好友申请页面
class FriendRequestsPage extends StatelessWidget {
  const FriendRequestsPage({super.key});

  /// 获取完整URL（处理相对路径）
  static String _getFullUrl(String url) {
    if (url.isEmpty) return '';
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
        title: Text(l10n.newFriend),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final requests = chatProvider.friendRequests;

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.translate('no_friend_requests'),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: requests.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final request = requests[index];
              return _buildRequestItem(context, request, chatProvider);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestItem(BuildContext context, FriendRequest request, ChatProvider chatProvider) {
    final avatarUrl = _getFullUrl(request.fromUser?.avatar ?? '');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.1),
        backgroundImage: avatarUrl.isNotEmpty
            ? NetworkImage(avatarUrl.proxied)
            : null,
        child: avatarUrl.isEmpty
            ? Text(
                (request.fromUser?.displayName.isNotEmpty == true)
                    ? request.fromUser!.displayName[0]
                    : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(request.fromUser?.displayName ?? AppLocalizations.of(context)!.translate('unknown_user')),
      subtitle: Text(
        request.message ?? AppLocalizations.of(context)!.translate('request_add_friend'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
      trailing: request.isPending
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    final result = await chatProvider.handleFriendRequest(request.id, 2); // 2 = 拒绝
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.displayMessage),
                        backgroundColor: result.success ? null : AppColors.error,
                      ),
                    );
                  },
                  child: Text(AppLocalizations.of(context)!.reject),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final result = await chatProvider.handleFriendRequest(request.id, 1); // 1 = 同意
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.displayMessage),
                        backgroundColor: result.success ? AppColors.success : AppColors.error,
                      ),
                    );
                  },
                  child: Text(AppLocalizations.of(context)!.accept),
                ),
              ],
            )
          : Text(
              request.status == 1 ? AppLocalizations.of(context)!.translate('added') : AppLocalizations.of(context)!.translate('rejected'),
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 13,
              ),
            ),
    );
  }
}
