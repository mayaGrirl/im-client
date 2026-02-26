/// 系统通知模型
class SystemNotification {
  final int id;
  final int userId;
  final String type;
  final String? typeLabel; // 服务端返回的多语言类型标签
  final String title;
  final String content;
  final String? extra;
  final bool isRead;
  final DateTime? createdAt;

  SystemNotification({
    required this.id,
    required this.userId,
    required this.type,
    this.typeLabel,
    required this.title,
    required this.content,
    this.extra,
    required this.isRead,
    this.createdAt,
  });

  factory SystemNotification.fromJson(Map<String, dynamic> json) {
    return SystemNotification(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      type: json['type'] ?? '',
      typeLabel: json['type_label'], // 读取服务端的多语言标签
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      extra: json['extra'],
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  /// 获取通知类型的显示名称
  /// 优先使用服务端返回的多语言标签，否则使用本地回退
  String get typeDisplayName {
    // 优先使用服务端返回的多语言标签
    if (typeLabel != null && typeLabel!.isNotEmpty) {
      return typeLabel!;
    }
    // 回退到本地映射（兼容旧数据）
    switch (type) {
      // 财务相关 - 充值
      case 'recharge_success':
        return 'Recharge Success';
      case 'recharge_failed':
        return 'Recharge Rejected';
      // 财务相关 - 提现
      case 'withdraw_approved':
        return 'Withdrawal Approved';
      case 'withdraw_success':
        return 'Withdrawal Success';
      case 'withdraw_failed':
        return 'Withdrawal Rejected';
      case 'transfer_received':
        return 'Transfer Received';
      // 红包相关
      case 'red_packet_expired':
        return 'Red Packet Refund';
      // 群聊相关
      case 'group_join_approved':
        return 'Join Approved';
      case 'group_join_rejected':
        return 'Join Rejected';
      case 'group_kicked':
        return 'Removed from Group';
      case 'group_disbanded':
        return 'Group Disbanded';
      case 'group_admin_added':
        return 'Became Admin';
      case 'group_admin_removed':
        return 'Admin Removed';
      case 'group_owner_transfer':
        return 'Owner Changed';
      // 好友相关
      case 'friend_deleted':
        return 'Friend Deleted';
      case 'blacklist_added':
        return 'Blocked';
      case 'friend_added':
        return 'New Friend';
      // 系统相关
      case 'activity_notice':
        return 'Activity';
      case 'system_announce':
        return 'Announcement';
      // 账号相关
      case 'account_warning':
        return 'Warning';
      case 'account_login_alert':
        return 'Login Alert';
      case 'account_violation':
        return 'Violation';
      case 'account_frozen':
        return 'Account Frozen';
      case 'account_unfrozen':
        return 'Account Unfrozen';
      // 等级相关
      case 'level_upgrade':
        return 'Level Up';
      case 'level_downgrade':
        return 'Level Down';
      // 金豆相关通知
      case 'gold_bean_register':
        return 'Registration';
      case 'gold_bean_invite':
        return 'Invite Reward';
      case 'gold_bean_daily':
        return 'Daily Claim';
      case 'gold_bean_exchange':
        return 'Exchange';
      case 'gold_bean_gift':
        return 'System Gift';
      case 'gold_bean_level':
        return 'Level Reward';
      case 'gold_bean_admin':
        return 'Admin Adjust';
      case 'video_shared':
        return 'Video Shared';
      case 'livestream_shared':
        return 'Livestream Shared';
      // 直播付费相关
      case 'live_ticket_purchase':
        return 'Ticket Purchase';
      case 'live_anchor_income':
        return 'Livestream Income';
      case 'live_watch_charge':
        return 'Livestream Charge';
      case 'live_gift_sent':
        return 'Gift Sent';
      case 'live_gift_income':
        return 'Gift Income';
      case 'live_paid_call_charge':
        return 'Paid Call Charge';
      case 'live_paid_call_income':
        return 'Paid Call Income';
      default:
        return 'Notification';
    }
  }

  /// 获取通知类型的图标
  String get typeIcon {
    switch (type) {
      // 财务相关 - 充值
      case 'recharge_success':
        return 'account_balance_wallet';
      case 'recharge_failed':
        return 'money_off';
      // 财务相关 - 提现
      case 'withdraw_approved':
        return 'pending';
      case 'withdraw_success':
        return 'paid';
      case 'withdraw_failed':
        return 'money_off';
      case 'exchange_success':
        return 'swap_horiz';
      case 'transfer_received':
        return 'payments';
      // 红包相关
      case 'red_packet_expired':
        return 'redeem';
      // 群聊相关
      case 'group_join_approved':
        return 'group_add';
      case 'group_join_rejected':
      case 'group_kicked':
      case 'group_disbanded':
        return 'group_off';
      case 'group_admin_added':
        return 'admin_panel_settings';
      case 'group_admin_removed':
        return 'person_remove';
      case 'group_owner_transfer':
        return 'swap_horiz';
      // 好友相关
      case 'friend_added':
        return 'person_add';
      case 'friend_deleted':
        return 'person_remove';
      case 'blacklist_added':
        return 'block';
      // 系统相关
      case 'activity_notice':
        return 'celebration';
      case 'system_announce':
        return 'campaign';
      // 账号相关
      case 'account_warning':
        return 'warning';
      case 'account_login_alert':
        return 'login';
      case 'account_violation':
        return 'gavel';
      case 'account_frozen':
        return 'ac_unit';
      case 'account_unfrozen':
        return 'check_circle';
      // 等级相关
      case 'level_upgrade':
        return 'trending_up';
      case 'level_downgrade':
        return 'trending_down';
      // 金豆相关通知
      case 'gold_bean_register':
      case 'gold_bean_invite':
      case 'gold_bean_daily':
      case 'gold_bean_gift':
      case 'gold_bean_level':
        return 'monetization_on';
      case 'gold_bean_exchange':
        return 'shopping_cart';
      case 'gold_bean_admin':
        return 'admin_panel_settings';
      case 'video_shared':
        return 'video_library';
      case 'livestream_shared':
        return 'live_tv';
      // 直播付费相关
      case 'live_ticket_purchase':
        return 'confirmation_number';
      case 'live_anchor_income':
        return 'account_balance_wallet';
      case 'live_watch_charge':
        return 'live_tv';
      case 'live_gift_sent':
        return 'card_giftcard';
      case 'live_gift_income':
        return 'account_balance_wallet';
      case 'live_paid_call_charge':
        return 'phone_in_talk';
      case 'live_paid_call_income':
        return 'account_balance_wallet';
      default:
        return 'notifications';
    }
  }

  /// 是否是金豆相关通知
  bool get isGoldBeanNotify {
    return type.startsWith('gold_bean_');
  }
}

/// 客服模型
class CustomerService {
  final int id;
  final int userId;
  final String name;
  final String avatar;
  final String description;
  final String welcomeMsg;
  final bool isOnline;

  CustomerService({
    required this.id,
    required this.userId,
    required this.name,
    required this.avatar,
    required this.description,
    required this.welcomeMsg,
    required this.isOnline,
  });

  factory CustomerService.fromJson(Map<String, dynamic> json) {
    return CustomerService(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      description: json['description'] ?? '',
      welcomeMsg: json['welcome_msg'] ?? '',
      isOnline: json['is_online'] ?? false,
    );
  }
}

/// 客服常见问题模型
class CustomerServiceFAQ {
  final int id;
  final String question;
  final String answer;
  final String category;
  final int sortOrder;
  final bool isActive;
  final int clickCount;

  CustomerServiceFAQ({
    required this.id,
    required this.question,
    required this.answer,
    this.category = '',
    this.sortOrder = 0,
    this.isActive = true,
    this.clickCount = 0,
  });

  factory CustomerServiceFAQ.fromJson(Map<String, dynamic> json) {
    return CustomerServiceFAQ(
      id: json['id'] ?? 0,
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      category: json['category'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      clickCount: json['click_count'] ?? 0,
    );
  }
}

/// 标签模型
class FriendTag {
  final String name;
  final int count;

  FriendTag({
    required this.name,
    required this.count,
  });

  factory FriendTag.fromJson(Map<String, dynamic> json) {
    return FriendTag(
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}
