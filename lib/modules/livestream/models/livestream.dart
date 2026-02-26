/// 直播模块数据模型
import 'dart:convert';

Map<String, String> _parseQualityUrls(dynamic value) {
  if (value == null || value == '') return {};
  try {
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return Map<String, String>.from(decoded.map((k, v) => MapEntry(k.toString(), v.toString())));
      }
    } else if (value is Map) {
      return Map<String, String>.from(value.map((k, v) => MapEntry(k.toString(), v.toString())));
    }
  } catch (_) {}
  return {};
}

/// 直播间
class LivestreamRoom {
  final int id;
  final String streamId;
  final String pushKey;
  final int userId;
  final String title;
  final String description;
  final String coverUrl;
  final int type;
  final int status;
  final int categoryId;
  final String tags;
  final String pullUrl;
  final Map<String, String> qualityUrls; // 多清晰度拉流URL
  final int viewerCount;
  final int likeCount;
  final int giftAmount;
  final int totalViewers;
  final int maxViewers;
  final int duration;
  final bool isPrivate;
  final bool needFollow;
  // 付费设置
  final bool isPaid;
  final int ticketPrice;
  final int ticketPriceType;
  final int anchorShareRatio;
  final bool allowPreview;
  final int previewDuration;
  final int paidViewerCount;
  final int ticketIncome;
  // 按分钟付费 & 付费通话
  final int roomType; // 0=免费 1=按分钟付费
  final bool allowCohost;
  final bool allowPaidCall;
  final int trialSeconds;
  final int pricePerMin;
  final bool isInPaidCall;
  final int paidCallRate; // 付费通话费率(金豆/分钟), 0=系统默认
  final int reserveCount; // 预约人数
  // 时间
  final String? startTime;
  final String? endTime;
  final String? scheduledAt;
  final String createdAt;
  // 关联
  final LivestreamUser? user;
  final LivestreamCategory? category;

  LivestreamRoom({
    required this.id,
    required this.streamId,
    this.pushKey = '',
    required this.userId,
    required this.title,
    this.description = '',
    this.coverUrl = '',
    this.type = 0,
    this.status = 0,
    this.categoryId = 0,
    this.tags = '',
    this.pullUrl = '',
    this.qualityUrls = const {},
    this.viewerCount = 0,
    this.likeCount = 0,
    this.giftAmount = 0,
    this.totalViewers = 0,
    this.maxViewers = 0,
    this.duration = 0,
    this.isPrivate = false,
    this.needFollow = false,
    this.isPaid = false,
    this.ticketPrice = 0,
    this.ticketPriceType = 1,
    this.anchorShareRatio = 70,
    this.allowPreview = false,
    this.previewDuration = 60,
    this.paidViewerCount = 0,
    this.ticketIncome = 0,
    this.roomType = 0,
    this.allowCohost = true,
    this.allowPaidCall = false,
    this.trialSeconds = 0,
    this.pricePerMin = 0,
    this.isInPaidCall = false,
    this.paidCallRate = 0,
    this.reserveCount = 0,
    this.startTime,
    this.endTime,
    this.scheduledAt,
    required this.createdAt,
    this.user,
    this.category,
  });

  factory LivestreamRoom.fromJson(Map<String, dynamic> json) {
    return LivestreamRoom(
      id: json['id'] ?? 0,
      streamId: json['stream_id'] ?? '',
      pushKey: json['push_key'] ?? '',
      userId: json['user_id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      coverUrl: json['cover_url'] ?? '',
      type: json['type'] ?? 0,
      status: json['status'] ?? 0,
      categoryId: json['category_id'] ?? 0,
      tags: json['tags'] ?? '',
      pullUrl: json['pull_url'] ?? '',
      qualityUrls: _parseQualityUrls(json['quality_urls']),
      viewerCount: json['viewer_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      giftAmount: json['gift_amount'] ?? 0,
      totalViewers: json['total_viewers'] ?? 0,
      maxViewers: json['max_viewers'] ?? 0,
      duration: json['duration'] ?? 0,
      isPrivate: json['is_private'] ?? false,
      needFollow: json['need_follow'] ?? false,
      isPaid: json['is_paid'] ?? false,
      ticketPrice: json['ticket_price'] ?? 0,
      ticketPriceType: json['ticket_price_type'] ?? 1,
      anchorShareRatio: json['anchor_share_ratio'] ?? 70,
      allowPreview: json['allow_preview'] ?? false,
      previewDuration: json['preview_duration'] ?? 60,
      paidViewerCount: json['paid_viewer_count'] ?? 0,
      ticketIncome: json['ticket_income'] ?? 0,
      roomType: json['room_type'] ?? 0,
      allowCohost: json['allow_cohost'] ?? true,
      allowPaidCall: json['allow_paid_call'] ?? false,
      trialSeconds: json['trial_seconds'] ?? 0,
      pricePerMin: json['price_per_min'] ?? 0,
      isInPaidCall: json['is_in_paid_call'] ?? false,
      paidCallRate: json['paid_call_rate'] ?? 0,
      reserveCount: json['reserve_count'] ?? 0,
      startTime: json['start_time'],
      endTime: json['end_time'],
      scheduledAt: json['scheduled_at'],
      createdAt: json['created_at'] ?? '',
      user: json['user'] != null ? LivestreamUser.fromJson(json['user']) : null,
      category: json['category'] != null ? LivestreamCategory.fromJson(json['category']) : null,
    );
  }

  bool get isLive => status == 1;
  bool get isEnded => status == 3;

  /// Backward-compatible anchor display name.
  ///
  /// Some pages still read `anchorNickname` directly from room data.
  /// Keep this getter to avoid compile/runtime breaks while APIs migrate to
  /// nested `user` payload.
  String get anchorNickname => user?.nickname ?? '';

  /// Backward-compatible anchor avatar URL.
  String get anchorAvatar => user?.avatar ?? '';

  String get statusText {
    switch (status) {
      case 0: return '待开始';
      case 1: return '直播中';
      case 2: return '暂停';
      case 3: return '已结束';
      case 4: return '已封禁';
      default: return '未知';
    }
  }

  String get typeText {
    switch (type) {
      case 0: return '普通直播';
      case 1: return '游戏直播';
      case 2: return '教育直播';
      case 3: return '带货直播';
      case 4: return '私密直播';
      default: return '未知';
    }
  }

  LivestreamRoom copyWith({
    int? id,
    String? streamId,
    String? pushKey,
    int? userId,
    String? title,
    String? description,
    String? coverUrl,
    int? type,
    int? status,
    int? categoryId,
    String? tags,
    String? pullUrl,
    Map<String, String>? qualityUrls,
    int? viewerCount,
    int? likeCount,
    int? giftAmount,
    int? totalViewers,
    int? maxViewers,
    int? duration,
    bool? isPrivate,
    bool? needFollow,
    bool? isPaid,
    int? ticketPrice,
    int? ticketPriceType,
    int? anchorShareRatio,
    bool? allowPreview,
    int? previewDuration,
    int? paidViewerCount,
    int? ticketIncome,
    int? roomType,
    bool? allowCohost,
    bool? allowPaidCall,
    int? trialSeconds,
    int? pricePerMin,
    bool? isInPaidCall,
    int? paidCallRate,
    int? reserveCount,
    String? startTime,
    String? endTime,
    String? scheduledAt,
    String? createdAt,
    LivestreamUser? user,
    LivestreamCategory? category,
  }) {
    return LivestreamRoom(
      id: id ?? this.id,
      streamId: streamId ?? this.streamId,
      pushKey: pushKey ?? this.pushKey,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      type: type ?? this.type,
      status: status ?? this.status,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? this.tags,
      pullUrl: pullUrl ?? this.pullUrl,
      qualityUrls: qualityUrls ?? this.qualityUrls,
      viewerCount: viewerCount ?? this.viewerCount,
      likeCount: likeCount ?? this.likeCount,
      giftAmount: giftAmount ?? this.giftAmount,
      totalViewers: totalViewers ?? this.totalViewers,
      maxViewers: maxViewers ?? this.maxViewers,
      duration: duration ?? this.duration,
      isPrivate: isPrivate ?? this.isPrivate,
      needFollow: needFollow ?? this.needFollow,
      isPaid: isPaid ?? this.isPaid,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      ticketPriceType: ticketPriceType ?? this.ticketPriceType,
      anchorShareRatio: anchorShareRatio ?? this.anchorShareRatio,
      allowPreview: allowPreview ?? this.allowPreview,
      previewDuration: previewDuration ?? this.previewDuration,
      paidViewerCount: paidViewerCount ?? this.paidViewerCount,
      ticketIncome: ticketIncome ?? this.ticketIncome,
      roomType: roomType ?? this.roomType,
      allowCohost: allowCohost ?? this.allowCohost,
      allowPaidCall: allowPaidCall ?? this.allowPaidCall,
      trialSeconds: trialSeconds ?? this.trialSeconds,
      pricePerMin: pricePerMin ?? this.pricePerMin,
      isInPaidCall: isInPaidCall ?? this.isInPaidCall,
      paidCallRate: paidCallRate ?? this.paidCallRate,
      reserveCount: reserveCount ?? this.reserveCount,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt ?? this.createdAt,
      user: user ?? this.user,
      category: category ?? this.category,
    );
  }
}

/// 直播分类
class LivestreamCategory {
  final int id;
  final String name;
  final String nameEn;
  final String icon;
  final int sortOrder;
  final bool isActive;

  LivestreamCategory({
    required this.id,
    required this.name,
    this.nameEn = '',
    this.icon = '',
    this.sortOrder = 0,
    this.isActive = true,
  });

  /// 根据语言环境返回分类名称
  String localizedName(String locale) {
    if (locale.startsWith('zh')) return name;
    return nameEn.isNotEmpty ? nameEn : name;
  }

  factory LivestreamCategory.fromJson(Map<String, dynamic> json) {
    return LivestreamCategory(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      nameEn: json['name_en'] ?? '',
      icon: json['icon'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }
}

/// 直播礼物
class LivestreamGift {
  final int id;
  final String name;
  final String nameI18n; // JSON: {"en": "...", "zh_cn": "..."}
  final String icon;
  final String animation;
  final int price;
  final int sortOrder;
  final bool isActive;
  final bool isSpecial;
  final String animationType;    // banner/center/fullscreen/combo
  final String effectUrl;        // Lottie/SVGA/GIF URL
  final String comboAnimation;   // Combo effect URL
  final int animationDuration;   // Duration in ms
  final int tier;                // 1=basic 2=premium 3=luxury
  final String category;         // Category label
  final int giftType;            // 0=normal 1=fullscreen 2=entrance
  final bool comboEnabled;       // Supports combo
  final String preview;          // Preview URL
  final bool isNFT;              // NFT限量礼物
  final int nftTotalSupply;      // NFT总发行量
  final int nftRarity;           // NFT稀有度: 1普通 2稀有 3史诗 4传说
  final int nftMintedCount;      // NFT已铸造数量

  LivestreamGift({
    required this.id,
    required this.name,
    this.nameI18n = '',
    required this.icon,
    this.animation = '',
    required this.price,
    this.sortOrder = 0,
    this.isActive = true,
    this.isSpecial = false,
    this.animationType = 'banner',
    this.effectUrl = '',
    this.comboAnimation = '',
    this.animationDuration = 3000,
    this.tier = 1,
    this.category = '',
    this.giftType = 0,
    this.comboEnabled = false,
    this.preview = '',
    this.isNFT = false,
    this.nftTotalSupply = 0,
    this.nftRarity = 1,
    this.nftMintedCount = 0,
  });

  factory LivestreamGift.fromJson(Map<String, dynamic> json) {
    return LivestreamGift(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      nameI18n: json['name_i18n'] ?? '',
      icon: json['icon'] ?? '',
      animation: json['animation'] ?? '',
      price: json['price'] ?? 0,
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      isSpecial: json['is_special'] ?? false,
      animationType: json['animation_type'] ?? 'banner',
      effectUrl: json['effect_url'] ?? '',
      comboAnimation: json['combo_animation'] ?? '',
      animationDuration: json['animation_duration'] ?? 3000,
      tier: json['tier'] ?? 1,
      category: json['category'] ?? '',
      giftType: json['gift_type'] ?? 0,
      comboEnabled: json['combo_enabled'] ?? false,
      preview: json['preview'] ?? '',
      isNFT: json['is_nft'] ?? false,
      nftTotalSupply: json['nft_total_supply'] ?? 0,
      nftRarity: json['nft_rarity'] ?? 1,
      nftMintedCount: json['nft_minted_count'] ?? 0,
    );
  }

  /// Returns the localized gift name based on language code.
  /// langCode should be like "en", "zh_cn", "zh_tw", "fr", "hi".
  String localizedName(String langCode) {
    if (nameI18n.isEmpty) return name;
    try {
      final map = Map<String, dynamic>.from(
        jsonDecode(nameI18n) as Map,
      );
      // Try exact match first (e.g., "zh_cn")
      if (map.containsKey(langCode) && (map[langCode] as String).isNotEmpty) {
        return map[langCode] as String;
      }
      // Try base language (e.g., "zh" from "zh_cn")
      if (langCode.contains('_')) {
        final base = langCode.split('_').first;
        if (map.containsKey(base) && (map[base] as String).isNotEmpty) {
          return map[base] as String;
        }
      }
      // Fallback to English
      if (map.containsKey('en') && (map['en'] as String).isNotEmpty) {
        return map['en'] as String;
      }
    } catch (_) {}
    return name;
  }

  bool get nftSoldOut => isNFT && nftMintedCount >= nftTotalSupply;

  String get rarityText {
    switch (nftRarity) {
      case 1: return '普通';
      case 2: return '稀有';
      case 3: return '史诗';
      case 4: return '传说';
      default: return '普通';
    }
  }
}

/// 礼物记录
class LivestreamGiftRecord {
  final int id;
  final int livestreamId;
  final int giftId;
  final int senderId;
  final int receiverId;
  final int count;
  final int amount;
  final String message;
  final String createdAt;
  final LivestreamGift? gift;
  final LivestreamUser? sender;

  LivestreamGiftRecord({
    required this.id,
    required this.livestreamId,
    required this.giftId,
    required this.senderId,
    required this.receiverId,
    this.count = 1,
    required this.amount,
    this.message = '',
    required this.createdAt,
    this.gift,
    this.sender,
  });

  factory LivestreamGiftRecord.fromJson(Map<String, dynamic> json) {
    return LivestreamGiftRecord(
      id: json['id'] ?? 0,
      livestreamId: json['livestream_id'] ?? 0,
      giftId: json['gift_id'] ?? 0,
      senderId: json['sender_id'] ?? 0,
      receiverId: json['receiver_id'] ?? 0,
      count: json['count'] ?? 1,
      amount: json['amount'] ?? 0,
      message: json['message'] ?? '',
      createdAt: json['created_at'] ?? '',
      gift: json['gift'] != null ? LivestreamGift.fromJson(json['gift']) : null,
      sender: json['sender'] != null ? LivestreamUser.fromJson(json['sender']) : null,
    );
  }
}

/// 弹幕
class LivestreamDanmaku {
  final int id;
  final int livestreamId;
  final int userId;
  final String content;
  final String color;
  final int position;
  final int timestamp;
  final String createdAt;
  final LivestreamUser? user;

  LivestreamDanmaku({
    required this.id,
    required this.livestreamId,
    required this.userId,
    required this.content,
    this.color = '#FFFFFF',
    this.position = 0,
    this.timestamp = 0,
    required this.createdAt,
    this.user,
  });

  factory LivestreamDanmaku.fromJson(Map<String, dynamic> json) {
    return LivestreamDanmaku(
      id: json['id'] ?? 0,
      livestreamId: json['livestream_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      content: json['content'] ?? '',
      color: json['color'] ?? '#FFFFFF',
      position: json['position'] ?? 0,
      timestamp: json['timestamp'] ?? 0,
      createdAt: json['created_at'] ?? '',
      user: json['user'] != null ? LivestreamUser.fromJson(json['user']) : null,
    );
  }
}

/// 观众
class LivestreamViewer {
  final int id;
  final int livestreamId;
  final int userId;
  final String joinTime;
  final String? leaveTime;
  final int duration;
  final String deviceType;

  LivestreamViewer({
    required this.id,
    required this.livestreamId,
    required this.userId,
    required this.joinTime,
    this.leaveTime,
    this.duration = 0,
    this.deviceType = '',
  });

  factory LivestreamViewer.fromJson(Map<String, dynamic> json) {
    return LivestreamViewer(
      id: json['id'] ?? 0,
      livestreamId: json['livestream_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      joinTime: json['join_time'] ?? '',
      leaveTime: json['leave_time'],
      duration: json['duration'] ?? 0,
      deviceType: json['device_type'] ?? '',
    );
  }
}

/// 简化用户信息
class LivestreamUser {
  final int id;
  final String nickname;
  final String avatar;
  final int gender;
  final int level;

  LivestreamUser({
    required this.id,
    required this.nickname,
    this.avatar = '',
    this.gender = 0,
    this.level = 0,
  });

  factory LivestreamUser.fromJson(Map<String, dynamic> json) {
    return LivestreamUser(
      id: json['id'] ?? 0,
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      gender: json['gender'] ?? 0,
      level: json['level'] ?? 0,
    );
  }
}

/// 直播回放
class LivestreamRecord {
  final int id;
  final int livestreamId;
  final String title;
  final String coverUrl;
  final String videoUrl;
  final int duration;
  final int viewCount;
  final bool isPublic;
  final String createdAt;

  LivestreamRecord({
    required this.id,
    required this.livestreamId,
    this.title = '',
    this.coverUrl = '',
    required this.videoUrl,
    this.duration = 0,
    this.viewCount = 0,
    this.isPublic = true,
    required this.createdAt,
  });

  factory LivestreamRecord.fromJson(Map<String, dynamic> json) {
    return LivestreamRecord(
      id: json['id'] ?? 0,
      livestreamId: json['livestream_id'] ?? 0,
      title: json['title'] ?? '',
      coverUrl: json['cover_url'] ?? '',
      videoUrl: json['video_url'] ?? '',
      duration: json['duration'] ?? 0,
      viewCount: json['view_count'] ?? 0,
      isPublic: json['is_public'] ?? true,
      createdAt: json['created_at'] ?? '',
    );
  }
}

/// 连麦信息
class LivestreamCoHost {
  final int id;
  final int livestreamId;
  final int userId;
  final int status; // 0=pending 1=accepted 2=rejected 3=ended
  final int position;
  final String? joinedAt;
  final String? leftAt;
  final String createdAt;
  final LivestreamUser? user;

  LivestreamCoHost({
    required this.id,
    required this.livestreamId,
    required this.userId,
    this.status = 0,
    this.position = 0,
    this.joinedAt,
    this.leftAt,
    required this.createdAt,
    this.user,
  });

  factory LivestreamCoHost.fromJson(Map<String, dynamic> json) {
    return LivestreamCoHost(
      id: json['id'] ?? 0,
      livestreamId: json['livestream_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      status: json['status'] ?? 0,
      position: json['position'] ?? 0,
      joinedAt: json['joined_at'],
      leftAt: json['left_at'],
      createdAt: json['created_at'] ?? '',
      user: json['user'] != null ? LivestreamUser.fromJson(json['user']) : null,
    );
  }

  bool get isPending => status == 0;
  bool get isAccepted => status == 1;
}

/// PK对战信息
class LivestreamPK {
  final int id;
  final int livestreamIdA;
  final int livestreamIdB;
  final int userIdA;
  final int userIdB;
  final int scoreA;
  final int scoreB;
  final int status; // 0=pending 1=active 2=ended
  final int duration;
  final int winnerId;
  final int result; // 0=draw 1=A wins 2=B wins
  final int loserId;
  final String? punishEndAt;
  final String nicknameA;
  final String nicknameB;
  final String avatarA;
  final String avatarB;
  final String? startedAt;
  final String? endedAt;
  final String createdAt;

  LivestreamPK({
    required this.id,
    this.livestreamIdA = 0,
    this.livestreamIdB = 0,
    this.userIdA = 0,
    this.userIdB = 0,
    this.scoreA = 0,
    this.scoreB = 0,
    this.status = 0,
    this.duration = 300,
    this.winnerId = 0,
    this.result = 0,
    this.loserId = 0,
    this.punishEndAt,
    this.nicknameA = '',
    this.nicknameB = '',
    this.avatarA = '',
    this.avatarB = '',
    this.startedAt,
    this.endedAt,
    required this.createdAt,
  });

  factory LivestreamPK.fromJson(Map<String, dynamic> json) {
    return LivestreamPK(
      id: json['id'] ?? 0,
      livestreamIdA: json['livestream_id_a'] ?? 0,
      livestreamIdB: json['livestream_id_b'] ?? 0,
      userIdA: json['user_id_a'] ?? 0,
      userIdB: json['user_id_b'] ?? 0,
      scoreA: json['score_a'] ?? 0,
      scoreB: json['score_b'] ?? 0,
      status: json['status'] ?? 0,
      duration: json['duration'] ?? 300,
      winnerId: json['winner_id'] ?? 0,
      result: json['result'] ?? 0,
      loserId: json['loser_id'] ?? 0,
      punishEndAt: json['punish_end_at'],
      nicknameA: json['nickname_a'] ?? '',
      nicknameB: json['nickname_b'] ?? '',
      avatarA: json['avatar_a'] ?? '',
      avatarB: json['avatar_b'] ?? '',
      startedAt: json['started_at'],
      endedAt: json['ended_at'],
      createdAt: json['created_at'] ?? '',
    );
  }

  bool get isPending => status == 0;
  bool get isActive => status == 1;
  bool get isEnded => status == 2;
  bool get isDraw => result == 0;
  bool get isWinnerA => result == 1;
  bool get isWinnerB => result == 2;
}

/// PK排行榜
class PKRanking {
  final int id;
  final int userId;
  final int totalPKs;
  final int wins;
  final int losses;
  final int draws;
  final int points;
  final int winStreak;
  final int maxWinStreak;
  final int seasonPoints;
  final int seasonWins;
  final String? nickname;
  final String? avatar;

  PKRanking({
    this.id = 0,
    this.userId = 0,
    this.totalPKs = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.points = 0,
    this.winStreak = 0,
    this.maxWinStreak = 0,
    this.seasonPoints = 0,
    this.seasonWins = 0,
    this.nickname,
    this.avatar,
  });

  factory PKRanking.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return PKRanking(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      totalPKs: json['total_pks'] ?? 0,
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      draws: json['draws'] ?? 0,
      points: json['points'] ?? 0,
      winStreak: json['win_streak'] ?? 0,
      maxWinStreak: json['max_win_streak'] ?? 0,
      seasonPoints: json['season_points'] ?? 0,
      seasonWins: json['season_wins'] ?? 0,
      nickname: user?['nickname'] ?? '',
      avatar: user?['avatar'] ?? '',
    );
  }

  double get winRate => totalPKs > 0 ? wins / totalPKs : 0;
}

/// 门票记录
class LivestreamTicket {
  final int id;
  final int livestreamId;
  final int userId;
  final int anchorId;
  final int amount;
  final int anchorIncome;
  final int platformFee;
  final int priceType;
  final String? expireAt;
  final int status;
  final String transactionId;
  final String createdAt;

  LivestreamTicket({
    required this.id,
    required this.livestreamId,
    required this.userId,
    required this.anchorId,
    required this.amount,
    required this.anchorIncome,
    required this.platformFee,
    this.priceType = 1,
    this.expireAt,
    this.status = 1,
    required this.transactionId,
    required this.createdAt,
  });

  factory LivestreamTicket.fromJson(Map<String, dynamic> json) {
    return LivestreamTicket(
      id: json['id'] ?? 0,
      livestreamId: json['livestream_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      anchorId: json['anchor_id'] ?? 0,
      amount: json['amount'] ?? 0,
      anchorIncome: json['anchor_income'] ?? 0,
      platformFee: json['platform_fee'] ?? 0,
      priceType: json['price_type'] ?? 1,
      expireAt: json['expire_at'],
      status: json['status'] ?? 1,
      transactionId: json['transaction_id'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  String get priceTypeText => priceType == 2 ? '包月制' : '单场制';
  String get statusText {
    switch (status) {
      case 0: return '已退款';
      case 1: return '有效';
      case 2: return '已过期';
      default: return '未知';
    }
  }
}

/// 付费连线会话
class LivestreamPaidSession {
  final int id;
  final int livestreamId;
  final int anchorId;
  final int viewerId;
  final int sessionType; // 1=chat 2=voice 3=video
  final int ratePerMinute;
  final int status; // 0=pending 1=active 2=ended
  final int totalMinutes;
  final int totalCost;
  final int anchorIncome;
  final int platformFee;
  final String? startedAt;
  final String? endedAt;
  final String createdAt;

  LivestreamPaidSession({
    required this.id,
    required this.livestreamId,
    required this.anchorId,
    required this.viewerId,
    this.sessionType = 1,
    this.ratePerMinute = 0,
    this.status = 0,
    this.totalMinutes = 0,
    this.totalCost = 0,
    this.anchorIncome = 0,
    this.platformFee = 0,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
  });

  factory LivestreamPaidSession.fromJson(Map<String, dynamic> json) {
    return LivestreamPaidSession(
      id: json['id'] ?? 0,
      livestreamId: json['livestream_id'] ?? 0,
      anchorId: json['anchor_id'] ?? 0,
      viewerId: json['viewer_id'] ?? 0,
      sessionType: json['session_type'] ?? 1,
      ratePerMinute: json['rate_per_minute'] ?? 0,
      status: json['status'] ?? 0,
      totalMinutes: json['total_minutes'] ?? 0,
      totalCost: json['total_cost'] ?? 0,
      anchorIncome: json['anchor_income'] ?? 0,
      platformFee: json['platform_fee'] ?? 0,
      startedAt: json['started_at'],
      endedAt: json['ended_at'],
      createdAt: json['created_at'] ?? '',
    );
  }

  bool get isPending => status == 0;
  bool get isActive => status == 1;
  bool get isEnded => status == 2;

  String get sessionTypeText {
    switch (sessionType) {
      case 1: return '文字聊天';
      case 2: return '语音通话';
      case 3: return '视频通话';
      default: return '未知';
    }
  }
}

/// NFT礼物实例
class LivestreamNFTGift {
  final int id;
  final int giftId;
  final int serialNumber;
  final int totalSupply;
  final int rarity;
  final int ownerId;
  final int originalOwnerId;
  final String mintTime;
  final int transferCount;
  final bool isTradeable;
  final String metadataJson;
  final LivestreamGift? gift;
  final LivestreamUser? owner;

  LivestreamNFTGift({
    required this.id,
    required this.giftId,
    required this.serialNumber,
    required this.totalSupply,
    this.rarity = 1,
    required this.ownerId,
    this.originalOwnerId = 0,
    required this.mintTime,
    this.transferCount = 0,
    this.isTradeable = true,
    this.metadataJson = '',
    this.gift,
    this.owner,
  });

  factory LivestreamNFTGift.fromJson(Map<String, dynamic> json) {
    return LivestreamNFTGift(
      id: json['id'] ?? 0,
      giftId: json['gift_id'] ?? 0,
      serialNumber: json['serial_number'] ?? 0,
      totalSupply: json['total_supply'] ?? 0,
      rarity: json['rarity'] ?? 1,
      ownerId: json['owner_id'] ?? 0,
      originalOwnerId: json['original_owner_id'] ?? 0,
      mintTime: json['mint_time'] ?? '',
      transferCount: json['transfer_count'] ?? 0,
      isTradeable: json['is_tradeable'] ?? true,
      metadataJson: json['metadata_json'] ?? '',
      gift: json['gift'] != null ? LivestreamGift.fromJson(json['gift']) : null,
      owner: json['owner'] != null ? LivestreamUser.fromJson(json['owner']) : null,
    );
  }

  String get rarityText {
    switch (rarity) {
      case 1: return '普通';
      case 2: return '稀有';
      case 3: return '史诗';
      case 4: return '传说';
      default: return '普通';
    }
  }
}

/// NFT转移记录
class LivestreamNFTTransfer {
  final int id;
  final int nftGiftId;
  final int fromUserId;
  final int toUserId;
  final int transferType; // 1=mint 2=gift 3=trade
  final int price;
  final String createdAt;
  final LivestreamUser? fromUser;
  final LivestreamUser? toUser;

  LivestreamNFTTransfer({
    required this.id,
    required this.nftGiftId,
    this.fromUserId = 0,
    required this.toUserId,
    required this.transferType,
    this.price = 0,
    required this.createdAt,
    this.fromUser,
    this.toUser,
  });

  factory LivestreamNFTTransfer.fromJson(Map<String, dynamic> json) {
    return LivestreamNFTTransfer(
      id: json['id'] ?? 0,
      nftGiftId: json['nft_gift_id'] ?? 0,
      fromUserId: json['from_user_id'] ?? 0,
      toUserId: json['to_user_id'] ?? 0,
      transferType: json['transfer_type'] ?? 1,
      price: json['price'] ?? 0,
      createdAt: json['created_at'] ?? '',
      fromUser: json['from_user'] != null ? LivestreamUser.fromJson(json['from_user']) : null,
      toUser: json['to_user'] != null ? LivestreamUser.fromJson(json['to_user']) : null,
    );
  }

  String get transferTypeText {
    switch (transferType) {
      case 1: return '铸造';
      case 2: return '赠送';
      case 3: return '交易';
      default: return '未知';
    }
  }
}

/// 看板概览
class DashboardOverview {
  final int totalStreams;
  final int totalViewers;
  final int totalIncome;
  final double avgDuration;
  final int followerCount;
  final int totalLikes;

  DashboardOverview({
    this.totalStreams = 0,
    this.totalViewers = 0,
    this.totalIncome = 0,
    this.avgDuration = 0,
    this.followerCount = 0,
    this.totalLikes = 0,
  });

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    return DashboardOverview(
      totalStreams: json['total_streams'] ?? 0,
      totalViewers: json['total_viewers'] ?? 0,
      totalIncome: json['total_income'] ?? 0,
      avgDuration: (json['avg_duration'] ?? 0).toDouble(),
      followerCount: json['follower_count'] ?? 0,
      totalLikes: json['total_likes'] ?? 0,
    );
  }
}
