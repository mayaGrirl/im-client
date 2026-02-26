/// 用户数据模型
/// 定义用户相关的数据结构

/// 用户模型
class User {
  final int id;
  final String username;
  final String nickname;
  final String avatar;
  final String? momentCover; // 朋友圈封面
  final String? videoCover; // 小视频主页封面
  final String? phone;
  final String? email;
  final int gender; // 0未知 1男 2女
  final String? birthday;
  final String? bio;
  final String? videoBio;
  final String? region;
  final String? address;
  final int qrcodeStyle; // 二维码样式 1-3
  final int status;
  final DateTime? createdAt;

  // 等级和积分相关
  final int level;
  final int points;
  // 注意: goldBeans 已移至 UserWallet，使用钱包API获取
  final bool emailVerified;
  final bool phoneVerified;

  // 邀请相关
  final String? inviteCode;
  final int? inviterId;
  final int inviteCount;

  // 登录和领取时间
  final DateTime? lastLoginAt;
  final DateTime? lastClaimAt;

  // 直播状态
  final bool isLive;
  final int? currentLivestreamId;

  User({
    required this.id,
    required this.username,
    required this.nickname,
    this.avatar = '',
    this.momentCover,
    this.videoCover,
    this.phone,
    this.email,
    this.gender = 0,
    this.birthday,
    this.bio,
    this.videoBio,
    this.region,
    this.address,
    this.qrcodeStyle = 1,
    this.status = 1,
    this.createdAt,
    this.level = 1,
    this.points = 0,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.inviteCode,
    this.inviterId,
    this.inviteCount = 0,
    this.lastLoginAt,
    this.lastClaimAt,
    this.isLive = false,
    this.currentLivestreamId,
  });

  /// 从JSON创建用户对象
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      momentCover: json['moment_cover'],
      videoCover: json['video_cover'],
      phone: json['phone'],
      email: json['email'],
      gender: json['gender'] ?? 0,
      birthday: json['birthday'],
      bio: json['bio'],
      videoBio: json['video_bio'],
      region: json['region'],
      address: json['address'],
      qrcodeStyle: json['qrcode_style'] ?? 1,
      status: json['status'] ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      level: json['level'] ?? 1,
      points: json['points'] ?? 0,
      emailVerified: json['email_verified'] ?? false,
      phoneVerified: json['phone_verified'] ?? false,
      inviteCode: json['invite_code'],
      inviterId: json['inviter_id'],
      inviteCount: json['invite_count'] ?? 0,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'])
          : null,
      lastClaimAt: json['last_claim_at'] != null
          ? DateTime.parse(json['last_claim_at'])
          : null,
      isLive: json['is_live'] ?? false,
      currentLivestreamId: json['current_livestream_id'],
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'avatar': avatar,
      'moment_cover': momentCover,
      'video_cover': videoCover,
      'phone': phone,
      'email': email,
      'gender': gender,
      'birthday': birthday,
      'bio': bio,
      'video_bio': videoBio,
      'region': region,
      'address': address,
      'qrcode_style': qrcodeStyle,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'level': level,
      'points': points,
      'email_verified': emailVerified,
      'phone_verified': phoneVerified,
      'invite_code': inviteCode,
      'inviter_id': inviterId,
      'invite_count': inviteCount,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'last_claim_at': lastClaimAt?.toIso8601String(),
      'is_live': isLive,
      'current_livestream_id': currentLivestreamId,
    };
  }

  /// 获取显示名称
  String get displayName => nickname.isNotEmpty ? nickname : username;

  /// 获取性别文字
  String get genderText {
    switch (gender) {
      case 1:
        return 'Male';
      case 2:
        return 'Female';
      default:
        return 'Unknown';
    }
  }

  /// 复制并修改
  User copyWith({
    int? id,
    String? username,
    String? nickname,
    String? avatar,
    String? momentCover,
    String? videoCover,
    String? phone,
    String? email,
    int? gender,
    String? birthday,
    String? bio,
    String? videoBio,
    String? region,
    String? address,
    int? qrcodeStyle,
    int? status,
    DateTime? createdAt,
    int? level,
    int? points,
    bool? emailVerified,
    bool? phoneVerified,
    String? inviteCode,
    int? inviterId,
    int? inviteCount,
    DateTime? lastLoginAt,
    DateTime? lastClaimAt,
    bool? isLive,
    int? currentLivestreamId,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      momentCover: momentCover ?? this.momentCover,
      videoCover: videoCover ?? this.videoCover,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      bio: bio ?? this.bio,
      videoBio: videoBio ?? this.videoBio,
      region: region ?? this.region,
      address: address ?? this.address,
      qrcodeStyle: qrcodeStyle ?? this.qrcodeStyle,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      level: level ?? this.level,
      points: points ?? this.points,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      inviteCode: inviteCode ?? this.inviteCode,
      inviterId: inviterId ?? this.inviterId,
      inviteCount: inviteCount ?? this.inviteCount,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastClaimAt: lastClaimAt ?? this.lastClaimAt,
      isLive: isLive ?? this.isLive,
      currentLivestreamId: currentLivestreamId ?? this.currentLivestreamId,
    );
  }
}

/// 用户设置模型
class UserSettings {
  final bool notificationSound;
  final bool notificationVibrate;
  final bool showOnlineStatus;
  final bool allowStranger;
  final String language;

  UserSettings({
    this.notificationSound = true,
    this.notificationVibrate = true,
    this.showOnlineStatus = true,
    this.allowStranger = true,
    this.language = 'zh-CN',
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      notificationSound: json['notification_sound'] ?? true,
      notificationVibrate: json['notification_vibrate'] ?? true,
      showOnlineStatus: json['show_online_status'] ?? true,
      allowStranger: json['allow_stranger'] ?? true,
      language: json['language'] ?? 'zh-CN',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notification_sound': notificationSound,
      'notification_vibrate': notificationVibrate,
      'show_online_status': showOnlineStatus,
      'allow_stranger': allowStranger,
      'language': language,
    };
  }
}

/// 好友模型
class Friend {
  final int id;
  final int friendId;
  final User friend;
  final String? remark;
  final String? remarkPhone;
  final String? remarkEmail;
  final String? remarkTags;
  final String? remarkDesc;
  final int? groupId;
  final bool isOnline;
  final DateTime? createdAt;

  Friend({
    required this.id,
    required this.friendId,
    required this.friend,
    this.remark,
    this.remarkPhone,
    this.remarkEmail,
    this.remarkTags,
    this.remarkDesc,
    this.groupId,
    this.isOnline = false,
    this.createdAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    // 服务端返回平铺结构，需要构建 User 对象
    User friendUser;
    final friendData = json['friend'];
    if (friendData != null) {
      // 如果有嵌套的 friend 对象，安全转换类型
      if (friendData is Map<String, dynamic>) {
        friendUser = User.fromJson(friendData);
      } else if (friendData is Map) {
        friendUser = User.fromJson(Map<String, dynamic>.from(friendData));
      } else {
        // 从平铺结构构建 User 对象
        friendUser = User(
          id: json['friend_id'] ?? 0,
          username: json['username'] ?? '',
          nickname: json['nickname'] ?? '',
          avatar: json['avatar'] ?? '',
          bio: json['bio'],
        );
      }
    } else {
      // 从平铺结构构建 User 对象
      friendUser = User(
        id: json['friend_id'] ?? 0,
        username: json['username'] ?? '',
        nickname: json['nickname'] ?? '',
        avatar: json['avatar'] ?? '',
        bio: json['bio'],
      );
    }

    return Friend(
      id: json['id'] ?? 0,
      friendId: json['friend_id'] ?? 0,
      friend: friendUser,
      remark: json['remark'],
      remarkPhone: json['remark_phone'],
      remarkEmail: json['remark_email'],
      remarkTags: json['remark_tags'],
      remarkDesc: json['remark_desc'],
      groupId: json['group_id'],
      isOnline: json['is_online'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  /// 获取显示名称（优先显示备注名）
  String get displayName {
    if (remark != null && remark!.isNotEmpty) {
      return remark!;
    }
    return friend.displayName;
  }

  /// 复制并修改
  Friend copyWith({bool? isOnline}) {
    return Friend(
      id: id,
      friendId: friendId,
      friend: friend,
      remark: remark,
      remarkPhone: remarkPhone,
      remarkEmail: remarkEmail,
      remarkTags: remarkTags,
      remarkDesc: remarkDesc,
      groupId: groupId,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt,
    );
  }

  /// 获取标签列表
  List<String> get tagsList {
    if (remarkTags == null || remarkTags!.isEmpty) {
      return [];
    }
    return remarkTags!.split(',').where((t) => t.isNotEmpty).toList();
  }
}

/// 好友申请模型
class FriendRequest {
  final int id;
  final int fromUserId;
  final int toUserId;
  final User? fromUser;
  final String? message;
  final String? source;
  final int status;
  final DateTime? createdAt;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    this.fromUser,
    this.message,
    this.source,
    this.status = 0,
    this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    // 安全解析嵌套的from_user对象
    User? fromUser;
    final fromUserData = json['from_user'];
    if (fromUserData != null) {
      if (fromUserData is Map<String, dynamic>) {
        fromUser = User.fromJson(fromUserData);
      } else if (fromUserData is Map) {
        fromUser = User.fromJson(Map<String, dynamic>.from(fromUserData));
      }
    }

    return FriendRequest(
      id: json['id'] ?? 0,
      fromUserId: json['from_user_id'] ?? 0,
      toUserId: json['to_user_id'] ?? 0,
      fromUser: fromUser,
      message: json['message'],
      source: json['source'],
      status: json['status'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  /// 是否待处理
  bool get isPending => status == 0;
}

/// 好友统计模型
class FriendStats {
  final int currentCount;
  final int maxFriends;
  final bool canAdd;
  final int level;
  final String levelName;
  final int nextLevelMaxFriends;

  FriendStats({
    required this.currentCount,
    required this.maxFriends,
    required this.canAdd,
    required this.level,
    required this.levelName,
    this.nextLevelMaxFriends = 0,
  });

  factory FriendStats.fromJson(Map<String, dynamic> json) {
    return FriendStats(
      currentCount: json['current_count'] ?? 0,
      maxFriends: json['max_friends'] ?? 0,
      canAdd: json['can_add'] ?? true,
      level: json['level'] ?? 1,
      levelName: json['level_name'] ?? '',
      nextLevelMaxFriends: json['next_level_max_friends'] ?? 0,
    );
  }

  /// 是否有好友上限（0表示无限制）
  bool get hasLimit => maxFriends > 0;

  /// 获取显示文本
  String get displayText {
    if (!hasLimit) {
      return '$currentCount (Unlimited)';
    }
    return '$currentCount / $maxFriends';
  }
}

/// 用户等级模型
class UserLevel {
  final int level;
  final String name;
  final int minPoints;
  final int dailyGoldBeans;
  final int maxFriends;
  final int maxGroups;
  final int maxGroupMembers;
  final double inviteRewardMultiplier;
  final int checkinBaseReward;
  final String privilegeDesc;
  final String? iconUrl;

  UserLevel({
    required this.level,
    required this.name,
    required this.minPoints,
    required this.dailyGoldBeans,
    this.maxFriends = 100,
    this.maxGroups = 3,
    this.maxGroupMembers = 100,
    this.inviteRewardMultiplier = 1.0,
    this.checkinBaseReward = 5,
    this.privilegeDesc = '',
    this.iconUrl,
  });

  factory UserLevel.fromJson(Map<String, dynamic> json) {
    return UserLevel(
      level: json['level'] ?? 1,
      name: json['name'] ?? '',
      minPoints: json['min_points'] ?? 0,
      dailyGoldBeans: json['daily_gold_beans'] ?? 0,
      maxFriends: json['max_friends'] ?? 100,
      maxGroups: json['max_groups'] ?? 3,
      maxGroupMembers: json['max_group_members'] ?? 100,
      inviteRewardMultiplier: (json['invite_reward_multiplier'] ?? 1.0).toDouble(),
      checkinBaseReward: json['checkin_base_reward'] ?? 5,
      privilegeDesc: json['privilege_desc'] ?? '',
      iconUrl: json['icon_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'name': name,
      'min_points': minPoints,
      'daily_gold_beans': dailyGoldBeans,
      'max_friends': maxFriends,
      'max_groups': maxGroups,
      'max_group_members': maxGroupMembers,
      'invite_reward_multiplier': inviteRewardMultiplier,
      'checkin_base_reward': checkinBaseReward,
      'privilege_desc': privilegeDesc,
      'icon_url': iconUrl,
    };
  }
}

/// 等级信息响应
class LevelInfo {
  final int currentLevel;
  final String levelName;
  final int points;
  final int dailyGoldBeans;
  final int? nextLevel;
  final String? nextLevelName;
  final int? nextLevelPoints;
  final int? pointsToNext;
  final List<UserLevel> allLevels;

  LevelInfo({
    required this.currentLevel,
    required this.levelName,
    required this.points,
    required this.dailyGoldBeans,
    this.nextLevel,
    this.nextLevelName,
    this.nextLevelPoints,
    this.pointsToNext,
    required this.allLevels,
  });

  factory LevelInfo.fromJson(Map<String, dynamic> json) {
    return LevelInfo(
      currentLevel: json['current_level'] ?? 1,
      levelName: json['level_name'] ?? '',
      points: json['points'] ?? 0,
      dailyGoldBeans: json['daily_gold_beans'] ?? 0,
      nextLevel: json['next_level'],
      nextLevelName: json['next_level_name'],
      nextLevelPoints: json['next_level_points'],
      pointsToNext: json['points_to_next'],
      allLevels: (json['all_levels'] as List<dynamic>?)
              ?.map((e) => UserLevel.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// 金豆记录模型
class GoldBeanRecord {
  final int id;
  final int userId;
  final int type;
  final String? typeLabel; // 服务端返回的多语言类型标签
  final int amount;
  final int balance;
  final int? relatedId;
  final String? remark;
  final DateTime createdAt;

  GoldBeanRecord({
    required this.id,
    required this.userId,
    required this.type,
    this.typeLabel,
    required this.amount,
    required this.balance,
    this.relatedId,
    this.remark,
    required this.createdAt,
  });

  factory GoldBeanRecord.fromJson(Map<String, dynamic> json) {
    return GoldBeanRecord(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      type: json['type'] ?? 0,
      typeLabel: json['type_name'], // 读取服务端的多语言标签
      amount: json['amount'] ?? 0,
      balance: json['balance'] ?? 0,
      relatedId: json['related_id'],
      remark: json['remark'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  /// 获取类型名称
  /// 优先使用服务端返回的多语言标签，否则使用本地回退
  String get typeName {
    // 优先使用服务端返回的多语言标签
    if (typeLabel != null && typeLabel!.isNotEmpty) {
      return typeLabel!;
    }
    // 回退到本地映射（兼容旧数据，使用英文）
    switch (type) {
      case 1:
        return 'Daily Claim';
      case 2:
        return 'Invite Reward';
      case 3:
        return 'Registration';
      case 4:
        return 'Exchange';
      case 5:
        return 'System Gift';
      case 6:
        return 'Level Reward';
      case 7:
        return 'Admin Adjust';
      case 8:
        return 'Send Red Packet';
      case 9:
        return 'Grab Red Packet';
      default:
        return 'Unknown';
    }
  }

  /// 是否是收入
  bool get isIncome => amount > 0;
}

/// 金豆余额信息
class GoldBeanBalance {
  final int balance;
  final bool canClaim;
  final int dailyAmount;
  final String? lastClaimTime;

  GoldBeanBalance({
    required this.balance,
    required this.canClaim,
    required this.dailyAmount,
    this.lastClaimTime,
  });

  factory GoldBeanBalance.fromJson(Map<String, dynamic> json) {
    return GoldBeanBalance(
      balance: json['balance'] ?? 0,
      canClaim: json['can_claim_today'] ?? json['can_claim'] ?? false,
      dailyAmount: json['daily_gold_beans'] ?? json['daily_amount'] ?? 0,
      lastClaimTime: json['last_claim_time'],
    );
  }
}

/// 邀请信息
class InviteInfo {
  final String inviteCode;
  final int inviteCount;
  final int totalReward;
  final List<InvitedUser> invitees;

  InviteInfo({
    required this.inviteCode,
    required this.inviteCount,
    required this.totalReward,
    required this.invitees,
  });

  factory InviteInfo.fromJson(Map<String, dynamic> json) {
    return InviteInfo(
      inviteCode: json['invite_code'] ?? '',
      inviteCount: json['invite_count'] ?? 0,
      totalReward: json['total_reward'] ?? 0,
      invitees: (json['invitees'] as List<dynamic>?)
              ?.map((e) => InvitedUser.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// 被邀请用户
class InvitedUser {
  final int id;
  final String username;
  final String nickname;
  final String? avatar;
  final DateTime? createdAt;

  InvitedUser({
    required this.id,
    required this.username,
    required this.nickname,
    this.avatar,
    this.createdAt,
  });

  factory InvitedUser.fromJson(Map<String, dynamic> json) {
    return InvitedUser(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

/// 金豆商品
class GoldBeanProduct {
  final int id;
  final String name;
  final String description;
  final String? imageUrl;
  final int price;
  final int stock;
  final int status;

  GoldBeanProduct({
    required this.id,
    required this.name,
    this.description = '',
    this.imageUrl,
    required this.price,
    required this.stock,
    this.status = 1,
  });

  factory GoldBeanProduct.fromJson(Map<String, dynamic> json) {
    return GoldBeanProduct(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'],
      price: json['price'] ?? 0,
      stock: json['stock'] ?? 0,
      status: json['status'] ?? 1,
    );
  }

  /// 是否可购买
  bool get isAvailable => status == 1 && stock > 0;
}

/// 金豆兑换记录
class GoldBeanExchange {
  final int id;
  final int userId;
  final int productId;
  final String productName;
  final int quantity;
  final int totalPrice;
  final int status;
  final DateTime createdAt;

  GoldBeanExchange({
    required this.id,
    required this.userId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.totalPrice,
    this.status = 0,
    required this.createdAt,
  });

  factory GoldBeanExchange.fromJson(Map<String, dynamic> json) {
    return GoldBeanExchange(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      quantity: json['quantity'] ?? 1,
      totalPrice: json['total_price'] ?? 0,
      status: json['status'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  /// 获取状态名称
  String get statusName {
    switch (status) {
      case 0:
        return 'Pending';
      case 1:
        return 'Distributed';
      case 2:
        return 'Canceled';
      default:
        return 'Unknown';
    }
  }
}
