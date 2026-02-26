/// 消息列表Tab
/// 显示所有会话（聊天列表）

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/providers/chat_provider.dart';
import 'package:im_client/models/message.dart';
import 'package:im_client/screens/chat/chat_screen.dart';
import 'package:im_client/screens/friend/add_friend_screen.dart';
import 'package:im_client/screens/group/create_group_screen.dart';
import 'package:im_client/screens/scan/scan_screen.dart';
import 'package:im_client/screens/search/search_screen.dart';
import 'package:im_client/screens/contacts/system_notifications_screen.dart';
import '../../utils/image_proxy.dart';

/// 消息Tab页
class MessageTab extends StatefulWidget {
  const MessageTab({super.key});

  @override
  State<MessageTab> createState() => _MessageTabState();
}

class _MessageTabState extends State<MessageTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.messages),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              _showAddMenu(context);
            },
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.isLoading && chatProvider.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              await chatProvider.loadConversations();
              await chatProvider.loadSystemNotificationCount();
            },
            child: ListView(
              children: [
                // 系统通知（固定在顶部）
                _buildSystemNotificationItem(),
                const Divider(indent: 76, height: 1),
                // 会话列表
                if (chatProvider.conversations.isEmpty)
                  _buildEmptyState()
                else
                  ..._buildConversationItems(chatProvider.conversations),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noData,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('start_chat_hint'),
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建系统通知项（固定在消息列表顶部）
  Widget _buildSystemNotificationItem() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: AppColors.white,
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.notifications,
            color: Colors.white,
            size: 28,
          ),
        ),
        title: Text(
          l10n.translate('system_notifications'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Builder(
          builder: (context) {
            final unreadCount = context.watch<ChatProvider>().systemNotificationUnreadCount;
            return Text(
              unreadCount > 0
                  ? l10n.translate('unread_notifications').replaceAll('{count}', '$unreadCount')
                  : l10n.translate('no_new_notifications'),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        trailing: Builder(
          builder: (context) {
            final unreadCount = context.watch<ChatProvider>().systemNotificationUnreadCount;
            if (unreadCount <= 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            );
          },
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SystemNotificationsScreen()),
          ).then((_) => context.read<ChatProvider>().loadSystemNotificationCount());
        },
      ),
    );
  }

  /// 构建会话列表项
  List<Widget> _buildConversationItems(List<Conversation> conversations) {
    List<Widget> items = [];
    for (int i = 0; i < conversations.length; i++) {
      items.add(_buildConversationItem(conversations[i]));
      if (i < conversations.length - 1) {
        items.add(const Divider(indent: 76, height: 1));
      }
    }
    return items;
  }

  /// 构建会话列表（保留兼容）
  Widget _buildConversationList(List<Conversation> conversations) {
    return ListView.separated(
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const Divider(indent: 76, height: 1),
      itemBuilder: (context, index) {
        return _buildConversationItem(conversations[index]);
      },
    );
  }

  /// 构建单个会话项
  Widget _buildConversationItem(Conversation conversation) {
    return Dismissible(
      key: Key(conversation.conversId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmDialog(context);
      },
      onDismissed: (direction) async {
        final l10n = AppLocalizations.of(context)!;
        final chatProvider = context.read<ChatProvider>();
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        try {
          await chatProvider.deleteConversation(conversation.conversId);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(l10n.translate('conversation_deleted')),
              duration: const Duration(seconds: 1),
            ),
          );
        } catch (e) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(l10n.translate('delete_failed'))),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: conversation.isTop ? AppColors.background : AppColors.white,
          border: conversation.isTop
              ? const Border(left: BorderSide(color: AppColors.primary, width: 3))
              : null,
        ),
        child: ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              Builder(
                builder: (context) {
                  final avatarUrl = _getFullUrl(conversation.avatar);
                  return CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl.proxied)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            _getAvatarText(conversation),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  );
                },
              ),
              // 置顶图标 - 左上角
              if (conversation.isTop)
                Positioned(
                  left: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.push_pin,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              // 付费群标志 - 右下角
              if (conversation.isPaidGroup)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.monetization_on,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  conversation.name.isNotEmpty ? conversation.name : '${AppLocalizations.of(context)!.translate('user_prefix')}${conversation.targetId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (conversation.isMute)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.notifications_off, size: 16, color: AppColors.textHint),
                ),
              const SizedBox(width: 6),
              Text(
                _formatTime(conversation.lastMsgTime),
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _localizePreview(conversation.lastMsgPreview, AppLocalizations.of(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          trailing: conversation.unreadCount > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: conversation.isMute ? AppColors.textHint : AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                )
              : null,
          onTap: () {
            // 进入聊天页面
            _navigateToChat(conversation);
          },
          onLongPress: () {
            _showConversationMenu(context, conversation);
          },
        ),
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
    // 相对路径，添加服务器地址
    final baseUrl = EnvConfig.instance.baseUrl;
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }

  /// 获取头像文字
  String _getAvatarText(Conversation conversation) {
    final name = conversation.name;
    if (name.isNotEmpty) {
      return name[0];
    }
    final l10n = AppLocalizations.of(context)!;
    return conversation.isGroup ? l10n.translate('group_char') : l10n.translate('friend_char');
  }

  /// 将中文消息预览翻译为当前语言
  static const _previewKeyMap = {
    '[图片]': 'image_preview',
    '[语音]': 'voice_preview',
    '[视频]': 'video_preview',
    '[文件]': 'file_preview',
    '[位置]': 'location_preview',
    '[名片]': 'card_preview',
    '[消息]': 'message_preview',
    '[直播]': 'livestream_preview',
    '[红包]': 'red_packet_preview',
    '[表情]': 'sticker_preview',
    '[新消息]': 'new_message_preview',
    '[通话]': 'call_preview',
    '[合并转发]': 'forward_preview',
    '[聊天记录已被对方清空]': 'chat_cleared_by_other_preview',
    '[聊天记录]': 'chat_record_preview',
  };

  String _localizePreview(String preview, AppLocalizations? l10n) {
    if (l10n == null) return preview;
    // 1. 匹配中文方括号格式（历史存储的数据）
    final key = _previewKeyMap[preview];
    if (key != null) return l10n.translate(key);
    // 2. 匹配 l10n key 方括号格式（新存储的数据如 [chat_cleared_by_other]）
    final keyMatch = RegExp(r'^\[(\w+)\]$').firstMatch(preview);
    if (keyMatch != null) {
      final translated = l10n.translate(keyMatch.group(1)!);
      if (translated != keyMatch.group(1)) return translated;
    }
    // 3. 处理 "群通话已结束，时长 X:XX" 格式
    final callMatch = RegExp(r'群通话已结束，时长\s*(.+)').firstMatch(preview);
    if (callMatch != null) {
      return l10n.translate('group_call_ended_with_duration')
          .replaceAll('{duration}', callMatch.group(1)!);
    }
    return preview;
  }

  /// 格式化时间
  String _formatTime(DateTime? time) {
    if (time == null) return '';

    final now = DateTime.now();
    final diff = now.difference(time);
    final l10n = AppLocalizations.of(context)!;

    if (diff.inMinutes < 1) {
      return l10n.translate('just_now');
    } else if (diff.inHours < 1) {
      return l10n.translate('minutes_ago').replaceAll('{count}', diff.inMinutes.toString());
    } else if (diff.inDays < 1) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 2) {
      return l10n.translate('yesterday');
    } else if (diff.inDays < 7) {
      final weekdays = [
        l10n.translate('monday'),
        l10n.translate('tuesday'),
        l10n.translate('wednesday'),
        l10n.translate('thursday'),
        l10n.translate('friday'),
        l10n.translate('saturday'),
        l10n.translate('sunday'),
      ];
      return weekdays[time.weekday - 1];
    } else {
      return '${time.month}/${time.day}';
    }
  }

  /// 进入聊天页面
  void _navigateToChat(Conversation conversation) {
    // 清除未读数
    context.read<ChatProvider>().clearUnreadCount(conversation.conversId);
    // 导航到聊天页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(conversation: conversation),
      ),
    );
  }

  /// 显示删除确认对话框
  Future<bool?> _showDeleteConfirmDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('delete_conversation')),
          content: Text(l10n.translate('delete_conversation_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
  }

  /// 显示添加菜单
  void _showAddMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add),
                title: Text(l10n.translate('add_friend')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddFriendScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: Text(l10n.translate('create_group')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: Text(l10n.translate('scan')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScanScreen()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示会话操作菜单
  void _showConversationMenu(BuildContext context, Conversation conversation) {
    final l10n = AppLocalizations.of(context)!;
    // 在弹出菜单前获取 ChatProvider 引用，避免 context 失效问题
    final chatProvider = context.read<ChatProvider>();
    // 保存 ScaffoldMessenger 引用用于显示 SnackBar
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(conversation.isTop ? Icons.push_pin_outlined : Icons.push_pin),
                title: Text(conversation.isTop ? l10n.translate('cancel_top') : l10n.translate('top')),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  final newIsTop = !conversation.isTop;
                  try {
                    await chatProvider.toggleConversationTop(
                      conversation.conversId,
                      newIsTop,
                    );
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(newIsTop ? l10n.translate('topped') : l10n.translate('cancel_top_success')),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text(l10n.translate('operation_failed'))),
                    );
                  }
                },
              ),
              if (conversation.unreadCount > 0)
                ListTile(
                  leading: const Icon(Icons.mark_email_read),
                  title: Text(l10n.translate('mark_as_read')),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    try {
                      await chatProvider.clearUnreadCount(conversation.conversId);
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.translate('marked_as_read')),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text(l10n.translate('operation_failed'))),
                      );
                    }
                  },
                ),
              ListTile(
                leading: Icon(
                  conversation.isMute ? Icons.notifications : Icons.notifications_off,
                ),
                title: Text(conversation.isMute ? l10n.translate('cancel_mute') : l10n.translate('mute')),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  final newIsMute = !conversation.isMute;
                  try {
                    await chatProvider.toggleConversationMute(
                      conversation.conversId,
                      newIsMute,
                    );
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(newIsMute ? l10n.translate('muted') : l10n.translate('cancel_mute_success')),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text(l10n.translate('operation_failed'))),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: Text(l10n.translate('delete_conversation'), style: const TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  final confirmed = await _showDeleteConfirmDialog(context);
                  if (confirmed == true) {
                    try {
                      await chatProvider.deleteConversation(conversation.conversId);
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.translate('conversation_deleted')),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text(l10n.translate('delete_failed'))),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
