import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/system_api.dart';
import '../../models/system.dart';
import '../../constants/app_constants.dart';
import '../../providers/chat_provider.dart';
import '../../l10n/app_localizations.dart';
import 'notification_detail_screen.dart';

/// 系统通知页面
class SystemNotificationsScreen extends StatefulWidget {
  const SystemNotificationsScreen({super.key});

  @override
  State<SystemNotificationsScreen> createState() => _SystemNotificationsScreenState();
}

class _SystemNotificationsScreenState extends State<SystemNotificationsScreen> {
  final SystemApi _systemApi = SystemApi();
  List<SystemNotification> _notifications = [];
  bool _isLoading = true;
  int _page = 1;
  bool _hasMore = true;
  StreamSubscription? _notifySubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _listenToNewNotifications();
  }

  @override
  void dispose() {
    _notifySubscription?.cancel();
    super.dispose();
  }

  /// 监听新通知
  void _listenToNewNotifications() {
    final chatProvider = context.read<ChatProvider>();
    _notifySubscription = chatProvider.systemNotifyStream.listen((data) {
      // 收到新通知时刷新列表
      if (data['action'] == 'new_notify') {
        _loadNotifications();
      }
    });
  }

  Future<void> _loadNotifications({bool loadMore = false}) async {
    if (loadMore && !_hasMore) return;

    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _page = 1;
      });
    }

    try {
      final notifications = await _systemApi.getNotifications(
        page: loadMore ? _page + 1 : 1,
        pageSize: 20,
      );

      setState(() {
        if (loadMore) {
          _notifications.addAll(notifications);
          _page++;
        } else {
          _notifications = notifications;
        }
        _hasMore = notifications.length >= 20;
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

  Future<void> _markAsRead(SystemNotification notification) async {
    if (notification.isRead) return;

    final success = await _systemApi.markAsRead(notification.id);
    if (success) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index >= 0) {
          _notifications[index] = SystemNotification(
            id: notification.id,
            userId: notification.userId,
            type: notification.type,
            typeLabel: notification.typeLabel,
            title: notification.title,
            content: notification.content,
            extra: notification.extra,
            isRead: true,
            createdAt: notification.createdAt,
          );
        }
      });
      context.read<ChatProvider>().loadSystemNotificationCount();
    }
  }

  /// 打开通知详情
  void _openNotificationDetail(SystemNotification notification) {
    // 先标记为已读
    _markAsRead(notification);

    // 导航到详情页
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(notification: notification),
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    final success = await _systemApi.markAllAsRead();
    if (success) {
      setState(() {
        _notifications = _notifications.map((n) => SystemNotification(
          id: n.id,
          userId: n.userId,
          type: n.type,
          typeLabel: n.typeLabel,
          title: n.title,
          content: n.content,
          extra: n.extra,
          isRead: true,
          createdAt: n.createdAt,
        )).toList();
      });
      context.read<ChatProvider>().loadSystemNotificationCount();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('marked_all_read')), duration: const Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _deleteNotification(SystemNotification notification) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_notification')),
        content: Text(l10n.translate('delete_notification_confirm')),
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
      final success = await _systemApi.deleteNotification(notification.id);
      if (success) {
        setState(() {
          _notifications.removeWhere((n) => n.id == notification.id);
        });
        context.read<ChatProvider>().loadSystemNotificationCount();
      }
    }
  }

  Future<void> _clearAll() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('clear_notifications')),
        content: Text(l10n.translate('clear_notifications_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.translate('clear')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _systemApi.clearAllNotifications();
      if (success) {
        setState(() {
          _notifications.clear();
        });
        context.read<ChatProvider>().loadSystemNotificationCount();
      }
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      // 财务相关 - 充值
      case 'recharge_success':
        return Icons.account_balance_wallet;
      case 'recharge_failed':
        return Icons.money_off;
      // 财务相关 - 提现
      case 'withdraw_approved':
        return Icons.pending_actions;
      case 'withdraw_success':
        return Icons.paid;
      case 'withdraw_failed':
        return Icons.money_off;
      case 'exchange_success':
        return Icons.swap_horiz;
      case 'transfer_received':
        return Icons.payments;
      // 红包相关
      case 'red_packet_expired':
        return Icons.redeem;
      // 群聊相关
      case 'group_join_approved':
        return Icons.group_add;
      case 'group_join_rejected':
      case 'group_kicked':
      case 'group_disbanded':
        return Icons.group_off;
      case 'group_admin_added':
        return Icons.admin_panel_settings;
      case 'group_admin_removed':
        return Icons.person_remove;
      case 'group_owner_transfer':
        return Icons.swap_horiz;
      // 好友相关
      case 'friend_added':
        return Icons.person_add;
      case 'friend_deleted':
        return Icons.person_remove;
      case 'blacklist_added':
        return Icons.block;
      // 系统相关
      case 'activity_notice':
        return Icons.celebration;
      case 'system_announce':
        return Icons.campaign;
      // 账号相关
      case 'account_warning':
        return Icons.warning;
      case 'account_login_alert':
        return Icons.login;
      case 'account_violation':
        return Icons.gavel;
      case 'account_frozen':
        return Icons.ac_unit;
      case 'account_unfrozen':
        return Icons.check_circle;
      // 等级相关
      case 'level_upgrade':
        return Icons.trending_up;
      // 金豆相关通知
      case 'gold_bean_register':
      case 'gold_bean_invite':
      case 'gold_bean_daily':
      case 'gold_bean_gift':
      case 'gold_bean_level':
        return Icons.monetization_on;
      case 'gold_bean_exchange':
        return Icons.shopping_cart;
      case 'gold_bean_admin':
        return Icons.admin_panel_settings;
      // 直播付费相关
      case 'live_ticket_purchase':
        return Icons.confirmation_number;
      case 'live_anchor_income':
        return Icons.account_balance_wallet;
      case 'live_watch_charge':
        return Icons.live_tv;
      case 'live_gift_sent':
        return Icons.card_giftcard;
      case 'live_gift_income':
        return Icons.account_balance_wallet;
      case 'live_paid_call_charge':
        return Icons.phone_in_talk;
      case 'live_paid_call_income':
        return Icons.account_balance_wallet;
      case 'video_shared':
        return Icons.video_library;
      case 'livestream_shared':
        return Icons.live_tv;
      // 预约直播相关
      case 'livestream_new_reservation':
        return Icons.person_add;
      case 'livestream_scheduled_cancelled':
        return Icons.event_busy;
      case 'livestream_scheduled_live':
        return Icons.play_circle_filled;
      case 'livestream_scheduled_reminder':
        return Icons.notifications_active;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      // 成功/正面
      case 'recharge_success':
      case 'withdraw_success':
      case 'exchange_success':
      case 'transfer_received':
      case 'group_join_approved':
      case 'group_admin_added':
      case 'friend_added':
      case 'account_unfrozen':
      case 'level_upgrade':
        return Colors.green;
      // 处理中/待处理
      case 'withdraw_approved':
        return Colors.blue;
      // 失败/负面
      case 'recharge_failed':
      case 'withdraw_failed':
      case 'group_kicked':
      case 'group_join_rejected':
      case 'friend_deleted':
      case 'blacklist_added':
      case 'account_warning':
      case 'account_violation':
      case 'account_frozen':
        return Colors.red;
      // 中性/警告
      case 'activity_notice':
      case 'red_packet_expired':
      case 'gold_bean_exchange':
        return Colors.orange;
      // 信息
      case 'system_announce':
      case 'group_owner_transfer':
      case 'account_login_alert':
        return Colors.blue;
      // 群相关
      case 'group_disbanded':
      case 'group_admin_removed':
        return Colors.grey;
      // 金豆相关通知
      case 'gold_bean_register':
      case 'gold_bean_invite':
      case 'gold_bean_daily':
      case 'gold_bean_gift':
      case 'gold_bean_level':
        return Colors.amber;
      case 'gold_bean_admin':
        return Colors.blueGrey;
      // 直播付费相关
      case 'live_ticket_purchase':
      case 'live_watch_charge':
      case 'live_gift_sent':
        return Colors.deepOrange;
      case 'live_paid_call_charge':
        return Colors.deepOrange;
      case 'live_anchor_income':
      case 'live_gift_income':
      case 'live_paid_call_income':
        return Colors.green;
      case 'video_shared':
      case 'livestream_shared':
        return Colors.teal;
      // 预约直播相关
      case 'livestream_new_reservation':
        return Colors.blue;
      case 'livestream_scheduled_live':
        return Colors.green;
      case 'livestream_scheduled_reminder':
        return Colors.orange;
      case 'livestream_scheduled_cancelled':
        return Colors.red;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('system_messages')),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(l10n.translate('mark_all_read')),
            ),
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') {
                  _clearAll();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(l10n.translate('clear_all_notifications'), style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState(l10n)
              : RefreshIndicator(
                  onRefresh: () => _loadNotifications(),
                  child: ListView.builder(
                    itemCount: _notifications.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _notifications.length) {
                        _loadNotifications(loadMore: true);
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _buildNotificationItem(_notifications[index], l10n);
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
            Icons.notifications_none,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.translate('no_system_messages'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(SystemNotification notification, AppLocalizations l10n) {
    final iconColor = _getColorForType(notification.type);

    return Dismissible(
      key: Key('notification_${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        _systemApi.deleteNotification(notification.id);
        setState(() {
          _notifications.removeWhere((n) => n.id == notification.id);
        });
      },
      child: InkWell(
        onTap: () => _openNotificationDetail(notification),
        onLongPress: () => _deleteNotification(notification),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead ? null : AppColors.primary.withValues(alpha: 0.05),
            border: const Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _getIconForType(notification.type),
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.content,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          notification.typeDisplayName,
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(notification.createdAt, l10n),
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 箭头图标
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 10),
                child: Icon(
                  Icons.chevron_right,
                  color: AppColors.textHint,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime? time, AppLocalizations l10n) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return l10n.translate('just_now');
    } else if (diff.inHours < 1) {
      return l10n.translate('minutes_ago').replaceAll('{count}', '${diff.inMinutes}');
    } else if (diff.inDays < 1) {
      return l10n.translate('hours_ago').replaceAll('{count}', '${diff.inHours}');
    } else if (diff.inDays < 7) {
      return l10n.translate('days_ago_format').replaceAll('{count}', '${diff.inDays}');
    } else {
      return '${time.month}/${time.day}';
    }
  }
}
