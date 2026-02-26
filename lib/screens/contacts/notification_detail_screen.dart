/// 系统通知详情页面
/// 显示通知的完整内容，根据类型提供不同的操作

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/system.dart';
import '../../constants/app_constants.dart';
import '../../l10n/app_localizations.dart';

/// 通知详情页面
class NotificationDetailScreen extends StatelessWidget {
  final SystemNotification notification;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.translate('notification_detail')),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 头部区域
            _buildHeader(context, l10n),
            const SizedBox(height: 12),
            // 内容区域
            _buildContent(context, l10n),
            // 额外信息区域
            if (_hasExtraInfo) ...[
              const SizedBox(height: 12),
              _buildExtraInfo(context, l10n),
            ],
            // 操作按钮区域
            if (_hasActions) ...[
              const SizedBox(height: 24),
              _buildActions(context, l10n),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// 构建头部区域
  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final iconColor = _getColorForType(notification.type);

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 图标
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(
              _getIconForType(notification.type),
              color: iconColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          // 标题
          Text(
            notification.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // 类型标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              notification.typeDisplayName,
              style: TextStyle(
                color: iconColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 时间
          Text(
            _formatFullTime(notification.createdAt, l10n),
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建内容区域
  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('notification_content'),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            notification.content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// 是否有额外信息
  bool get _hasExtraInfo {
    if (notification.extra == null || notification.extra!.isEmpty) {
      return false;
    }
    try {
      final extra = jsonDecode(notification.extra!);
      return extra is Map && extra.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 构建额外信息区域
  Widget _buildExtraInfo(BuildContext context, AppLocalizations l10n) {
    if (notification.extra == null || notification.extra!.isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      final extra = jsonDecode(notification.extra!) as Map<String, dynamic>;
      final items = _buildExtraItems(extra, l10n);

      if (items.isEmpty) return const SizedBox.shrink();

      return Container(
        color: AppColors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('detailed_info'),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  /// 构建额外信息项
  List<Widget> _buildExtraItems(Map<String, dynamic> extra, AppLocalizations l10n) {
    final List<Widget> items = [];
    final type = notification.type;
    final goldBeans = l10n.translate('gold_beans');
    final quantityUnit = l10n.translate('quantity_unit');

    // 根据通知类型显示不同的额外信息
    if (type.startsWith('gold_bean_')) {
      // 金豆相关
      if (extra['amount'] != null) {
        final amount = extra['amount'] as int;
        items.add(_buildInfoRow(
          l10n.translate('amount_change_label'),
          '${amount > 0 ? '+' : ''}$amount $goldBeans',
          valueColor: amount > 0 ? Colors.green : Colors.red,
        ));
      }
      if (extra['balance'] != null) {
        items.add(_buildInfoRow(l10n.translate('current_balance_label'), '${extra['balance']} $goldBeans'));
      }
      if (extra['remark'] != null && extra['remark'].toString().isNotEmpty) {
        items.add(_buildInfoRow(l10n.translate('remark'), _getLocalizedGoldBeanRemark(type, extra['remark'].toString(), l10n)));
      }
    } else if (type == 'red_packet_expired') {
      // 红包过期
      if (extra['refund_amount'] != null && extra['refund_amount'] > 0) {
        items.add(_buildInfoRow(l10n.translate('refund_amount'), '${extra['refund_amount']} $goldBeans'));
      }
      if (extra['total_amount'] != null) {
        items.add(_buildInfoRow(l10n.translate('red_packet_total'), '${extra['total_amount']} $goldBeans'));
      }
      if (extra['total_count'] != null) {
        items.add(_buildInfoRow(l10n.translate('red_packet_count'), '${extra['total_count']}$quantityUnit'));
      }
      if (extra['received_count'] != null) {
        items.add(_buildInfoRow(l10n.translate('received_count'), '${extra['received_count']}$quantityUnit'));
      }
    } else if (type.startsWith('group_')) {
      // 群相关
      if (extra['group_name'] != null) {
        items.add(_buildInfoRow(l10n.groupName, extra['group_name'].toString()));
      }
      if (extra['reject_reason'] != null &&
          extra['reject_reason'].toString().isNotEmpty) {
        items.add(_buildInfoRow(l10n.translate('reject_reason'), extra['reject_reason'].toString()));
      }
    } else if (type == 'level_upgrade') {
      // 等级升级
      if (extra['level'] != null) {
        items.add(_buildInfoRow(l10n.translate('current_level'), 'Lv.${extra['level']}'));
      }
      if (extra['level_name'] != null) {
        items.add(_buildInfoRow(l10n.translate('level_name'), extra['level_name'].toString()));
      }
    } else if (type == 'friend_deleted' ||
        type == 'friend_added' ||
        type == 'blacklist_added') {
      // 好友相关
      if (extra['nickname'] != null &&
          extra['nickname'].toString().isNotEmpty) {
        items.add(_buildInfoRow(l10n.translate('user_nickname'), extra['nickname'].toString()));
      } else if (extra['username'] != null) {
        items.add(_buildInfoRow(l10n.username, extra['username'].toString()));
      }
    }

    return items;
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 是否有操作按钮
  bool get _hasActions {
    final type = notification.type;
    // 某些类型的通知可以有操作按钮
    return type == 'group_join_approved' ||
        type == 'friend_added' ||
        type == 'activity_notice';
  }

  /// 构建操作按钮区域
  Widget _buildActions(BuildContext context, AppLocalizations l10n) {
    final type = notification.type;

    if (type == 'group_join_approved') {
      return _buildActionButton(
        context,
        icon: Icons.group,
        label: l10n.translate('enter_group_chat'),
        onPressed: () {
          // TODO: 导航到群聊
          Navigator.pop(context);
        },
      );
    } else if (type == 'friend_added') {
      return _buildActionButton(
        context,
        icon: Icons.chat,
        label: l10n.sendMessage,
        onPressed: () {
          // TODO: 导航到聊天
          Navigator.pop(context);
        },
      );
    } else if (type == 'activity_notice') {
      // 活动通知可能有链接
      try {
        if (notification.extra != null) {
          final extra = jsonDecode(notification.extra!) as Map<String, dynamic>;
          if (extra['url'] != null || extra['link'] != null) {
            return _buildActionButton(
              context,
              icon: Icons.open_in_new,
              label: l10n.translate('view_activity'),
              onPressed: () {
                // TODO: 打开活动链接
              },
            );
          }
        }
      } catch (e) {
        // ignore
      }
    }

    return const SizedBox.shrink();
  }

  /// 构建操作按钮
  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }

  /// 获取图标
  IconData _getIconForType(String type) {
    switch (type) {
      // 财务相关
      case 'withdraw_success':
      case 'withdraw_failed':
        return Icons.money_off;
      case 'recharge_success':
        return Icons.account_balance_wallet;
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
      // 金豆相关
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
      default:
        return Icons.notifications;
    }
  }

  /// 获取颜色
  Color _getColorForType(String type) {
    switch (type) {
      // 成功/正面
      case 'withdraw_success':
      case 'recharge_success':
      case 'transfer_received':
      case 'group_join_approved':
      case 'group_admin_added':
      case 'friend_added':
      case 'account_unfrozen':
      case 'level_upgrade':
        return Colors.green;
      // 失败/负面
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
        return Colors.blue;
      // 群相关
      case 'group_disbanded':
      case 'group_admin_removed':
        return Colors.grey;
      // 金豆相关
      case 'gold_bean_register':
      case 'gold_bean_invite':
      case 'gold_bean_daily':
      case 'gold_bean_gift':
      case 'gold_bean_level':
        return Colors.amber;
      case 'gold_bean_admin':
        return Colors.blueGrey;
      default:
        return AppColors.primary;
    }
  }

  /// 获取本地化的金豆备注
  String _getLocalizedGoldBeanRemark(String type, String remark, AppLocalizations l10n) {
    switch (type) {
      case 'gold_bean_daily':
        // 尝试从 remark 解析等级或连续天数
        final levelMatch = RegExp(r'[等级级别Level]+\s*(\d+)').firstMatch(remark);
        final daysMatch = RegExp(r'[连续連續consecutive]+\s*(\d+)').firstMatch(remark);
        if (daysMatch != null) {
          final days = daysMatch.group(1) ?? '1';
          return l10n.translate('remark_checkin_reward_days').replaceAll('{days}', days);
        } else if (levelMatch != null) {
          final level = levelMatch.group(1) ?? '1';
          return l10n.translate('remark_daily_claim_level').replaceAll('{level}', level);
        }
        return l10n.translate('daily_claim');

      case 'gold_bean_invite':
        // 尝试解析用户名和倍率
        final inviteMatch = RegExp(r'[邀请邀請Invite]+.*?(\w+).*?(\d+\.?\d*)[倍x]?').firstMatch(remark);
        if (inviteMatch != null) {
          final user = inviteMatch.group(1) ?? '';
          final multiplier = inviteMatch.group(2) ?? '1';
          return l10n.translate('remark_invite_user_reward')
              .replaceAll('{user}', user)
              .replaceAll('{multiplier}', multiplier);
        }
        return l10n.translate('invite_reward');

      case 'gold_bean_register':
        return l10n.translate('remark_new_user_reward');

      case 'gold_bean_exchange':
        // 尝试解析商品名和数量
        final exchangeMatch = RegExp(r'[：:]\s*(.+?)\s*[xX×]\s*(\d+)').firstMatch(remark);
        if (exchangeMatch != null) {
          final product = exchangeMatch.group(1) ?? '';
          final quantity = exchangeMatch.group(2) ?? '1';
          return l10n.translate('remark_exchange_product')
              .replaceAll('{product}', product)
              .replaceAll('{quantity}', quantity);
        }
        return l10n.translate('exchange_consume');

      case 'gold_bean_gift':
        return l10n.translate('remark_system_gift');

      case 'gold_bean_level':
        return l10n.translate('remark_level_reward');

      case 'gold_bean_admin':
        return l10n.translate('remark_admin_adjust');

      default:
        return remark;
    }
  }

  /// 格式化完整时间
  String _formatFullTime(DateTime? time, AppLocalizations l10n) {
    if (time == null) return '';
    final year = l10n.translate('date_year');
    final month = l10n.translate('date_month');
    final day = l10n.translate('date_day');
    return '${time.year}$year${time.month}$month${time.day}$day '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}
