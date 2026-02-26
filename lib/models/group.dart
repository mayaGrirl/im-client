/// 群组数据模型
/// 定义群组相关的数据结构

import 'package:im_client/models/user.dart';

/// 群组模型
class Group {
  final int id;
  final String groupNo;
  final String name;
  final String? description;
  final String avatar;
  final int ownerId;
  final int maxMembers;
  final int memberCount;
  final int type;
  final int joinMode; // 1自由加入 2需审核 3禁止加入 4仅邀请
  final String? notice;
  final bool muteAll;
  final DateTime? muteEndTime;
  final bool allowInvite;
  final bool allowSearch;
  final bool showMember;
  final int adminCount;
  final int maxAdmin;
  final bool allowAddFriend;
  final int qrcodeJoinMode; // 1直接 2审核
  final bool allowQrcodeJoin;
  final int autoClearDays; // 定时清除聊天记录天数: 0禁用, 1/3/7/10/30天
  final int status;
  final User? owner;
  final DateTime? createdAt;

  // 付费群相关字段
  final bool isPaid; // 是否付费群
  final double price; // 入群价格
  final int priceType; // 价格类型：1一次性 2包月 3包年
  final int allowTrialDays; // 试用天数(0为不允许试用)
  final double ownerShareRatio; // 群主分成比例(0-100)

  // 群通话相关字段
  final bool allowGroupCall; // 是否允许群通话(总开关)
  final bool allowVoiceCall; // 是否允许群语音通话
  final bool allowVideoCall; // 是否允许群视频通话
  final bool memberCanInitiateCall; // 成员是否可发起群通话
  final int maxCallParticipants; // 群通话最大参与人数

  Group({
    required this.id,
    required this.groupNo,
    required this.name,
    this.description,
    this.avatar = '',
    required this.ownerId,
    this.maxMembers = 500,
    this.memberCount = 0,
    this.type = 1,
    this.joinMode = 1,
    this.notice,
    this.muteAll = false,
    this.muteEndTime,
    this.allowInvite = true,
    this.allowSearch = true,
    this.showMember = true,
    this.adminCount = 0,
    this.maxAdmin = 10,
    this.allowAddFriend = true,
    this.qrcodeJoinMode = 1,
    this.allowQrcodeJoin = true,
    this.autoClearDays = 0,
    this.status = 1,
    this.owner,
    this.createdAt,
    // 付费群相关
    this.isPaid = false,
    this.price = 0,
    this.priceType = 1,
    this.allowTrialDays = 0,
    this.ownerShareRatio = 70,
    // 群通话相关
    this.allowGroupCall = true,
    this.allowVoiceCall = true,
    this.allowVideoCall = true,
    this.memberCanInitiateCall = false,
    this.maxCallParticipants = 9,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] ?? json['group_id'] ?? 0,
      groupNo: json['group_no'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      avatar: json['avatar'] ?? '',
      ownerId: json['owner_id'] ?? 0,
      maxMembers: json['max_members'] ?? 500,
      memberCount: json['member_count'] ?? 0,
      type: json['type'] ?? 1,
      joinMode: json['join_mode'] ?? 1,
      notice: json['notice'],
      muteAll: json['mute_all'] ?? false,
      muteEndTime: json['mute_end_time'] != null
          ? DateTime.parse(json['mute_end_time'])
          : null,
      allowInvite: json['allow_invite'] ?? true,
      allowSearch: json['allow_search'] ?? true,
      showMember: json['show_member'] ?? true,
      adminCount: json['admin_count'] ?? 0,
      maxAdmin: json['max_admin'] ?? 10,
      allowAddFriend: json['allow_add_friend'] ?? true,
      qrcodeJoinMode: json['qrcode_join_mode'] ?? 1,
      allowQrcodeJoin: json['allow_qrcode_join'] ?? true,
      autoClearDays: json['auto_clear_days'] ?? 0,
      status: json['status'] ?? 1,
      owner: json['owner'] != null ? User.fromJson(json['owner']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      // 付费群相关
      isPaid: json['is_paid'] ?? false,
      price: (json['join_price'] ?? json['price'] ?? 0).toDouble(),
      priceType: json['join_price_type'] ?? 1,
      allowTrialDays: json['allow_trial_days'] ?? 0,
      ownerShareRatio: (json['owner_share_ratio'] ?? 70).toDouble(),
      // 群通话相关
      allowGroupCall: json['allow_group_call'] ?? true,
      allowVoiceCall: json['allow_voice_call'] ?? true,
      allowVideoCall: json['allow_video_call'] ?? true,
      memberCanInitiateCall: json['member_can_initiate_call'] ?? false,
      maxCallParticipants: json['max_call_participants'] ?? 9,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_no': groupNo,
      'name': name,
      'description': description,
      'avatar': avatar,
      'owner_id': ownerId,
      'max_members': maxMembers,
      'member_count': memberCount,
      'type': type,
      'join_mode': joinMode,
      'notice': notice,
      'mute_all': muteAll,
      'mute_end_time': muteEndTime?.toIso8601String(),
      'allow_invite': allowInvite,
      'allow_search': allowSearch,
      'show_member': showMember,
      'admin_count': adminCount,
      'max_admin': maxAdmin,
      'allow_add_friend': allowAddFriend,
      'qrcode_join_mode': qrcodeJoinMode,
      'allow_qrcode_join': allowQrcodeJoin,
      'auto_clear_days': autoClearDays,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      // 付费群相关
      'is_paid': isPaid,
      'join_price': price,
      'join_price_type': priceType,
      'allow_trial_days': allowTrialDays,
      'owner_share_ratio': ownerShareRatio,
      // 群通话相关
      'allow_group_call': allowGroupCall,
      'allow_voice_call': allowVoiceCall,
      'allow_video_call': allowVideoCall,
      'member_can_initiate_call': memberCanInitiateCall,
      'max_call_participants': maxCallParticipants,
    };
  }

  /// 获取加入模式文字
  String get joinModeText {
    switch (joinMode) {
      case 1:
        return 'Free Join';
      case 2:
        return 'Requires Approval';
      case 3:
        return 'Forbidden';
      case 4:
        return 'Invite Only';
      default:
        return 'Unknown';
    }
  }

  /// 是否允许直接加入
  bool get canDirectJoin => joinMode == 1;

  /// 是否需要审核
  bool get needVerify => joinMode == 2;

  /// 是否禁止加入
  bool get isForbidden => joinMode == 3;

  /// 是否仅限邀请
  bool get isInviteOnly => joinMode == 4;

  /// 复制并修改
  Group copyWith({
    int? id,
    String? groupNo,
    String? name,
    String? description,
    String? avatar,
    int? ownerId,
    int? maxMembers,
    int? memberCount,
    int? type,
    int? joinMode,
    String? notice,
    bool? muteAll,
    DateTime? muteEndTime,
    bool? allowInvite,
    bool? allowSearch,
    bool? showMember,
    int? adminCount,
    int? maxAdmin,
    bool? allowAddFriend,
    int? qrcodeJoinMode,
    bool? allowQrcodeJoin,
    int? autoClearDays,
    int? status,
    User? owner,
    DateTime? createdAt,
    // 付费群相关
    bool? isPaid,
    double? price,
    int? priceType,
    int? allowTrialDays,
    double? ownerShareRatio,
    // 群通话相关
    bool? allowGroupCall,
    bool? allowVoiceCall,
    bool? allowVideoCall,
    bool? memberCanInitiateCall,
    int? maxCallParticipants,
  }) {
    return Group(
      id: id ?? this.id,
      groupNo: groupNo ?? this.groupNo,
      name: name ?? this.name,
      description: description ?? this.description,
      avatar: avatar ?? this.avatar,
      ownerId: ownerId ?? this.ownerId,
      maxMembers: maxMembers ?? this.maxMembers,
      memberCount: memberCount ?? this.memberCount,
      type: type ?? this.type,
      joinMode: joinMode ?? this.joinMode,
      notice: notice ?? this.notice,
      muteAll: muteAll ?? this.muteAll,
      muteEndTime: muteEndTime ?? this.muteEndTime,
      allowInvite: allowInvite ?? this.allowInvite,
      allowSearch: allowSearch ?? this.allowSearch,
      showMember: showMember ?? this.showMember,
      adminCount: adminCount ?? this.adminCount,
      maxAdmin: maxAdmin ?? this.maxAdmin,
      allowAddFriend: allowAddFriend ?? this.allowAddFriend,
      qrcodeJoinMode: qrcodeJoinMode ?? this.qrcodeJoinMode,
      allowQrcodeJoin: allowQrcodeJoin ?? this.allowQrcodeJoin,
      autoClearDays: autoClearDays ?? this.autoClearDays,
      status: status ?? this.status,
      owner: owner ?? this.owner,
      createdAt: createdAt ?? this.createdAt,
      // 付费群相关
      isPaid: isPaid ?? this.isPaid,
      price: price ?? this.price,
      priceType: priceType ?? this.priceType,
      allowTrialDays: allowTrialDays ?? this.allowTrialDays,
      ownerShareRatio: ownerShareRatio ?? this.ownerShareRatio,
      // 群通话相关
      allowGroupCall: allowGroupCall ?? this.allowGroupCall,
      allowVoiceCall: allowVoiceCall ?? this.allowVoiceCall,
      allowVideoCall: allowVideoCall ?? this.allowVideoCall,
      memberCanInitiateCall: memberCanInitiateCall ?? this.memberCanInitiateCall,
      maxCallParticipants: maxCallParticipants ?? this.maxCallParticipants,
    );
  }
}

/// 加入模式常量
class GroupJoinMode {
  static const int free = 1;      // 自由加入
  static const int verify = 2;    // 需要审核
  static const int forbid = 3;    // 禁止加入
  static const int invite = 4;    // 仅限邀请
  static const int question = 5;  // 问题验证
  static const int paid = 6;      // 付费加入
}

/// 付费群价格类型
class GroupPriceType {
  static const int once = 1;      // 一次性付费(永久)
  static const int monthly = 2;   // 包月
  static const int yearly = 3;    // 包年

  static String getName(int type) {
    switch (type) {
      case once:
        return '一次性';
      case monthly:
        return '包月';
      case yearly:
        return '包年';
      default:
        return '未知';
    }
  }
}

/// 群成员模型
class GroupMember {
  final int userId;
  final String username;
  final String nickname;
  final String avatar;
  final int role; // 0成员 1管理员 2群主
  final String? groupNickname;
  final bool isMute;
  final DateTime? muteEndTime;
  final bool isOnline;
  final String? chatBackground;
  final String? groupRemark;
  final DateTime? joinedAt;
  final bool canInitiateCall; // 是否有发起群通话权限

  GroupMember({
    required this.userId,
    required this.username,
    required this.nickname,
    this.avatar = '',
    this.role = 0,
    this.groupNickname,
    this.isMute = false,
    this.muteEndTime,
    this.isOnline = false,
    this.chatBackground,
    this.groupRemark,
    this.joinedAt,
    this.canInitiateCall = false,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'] ?? 0,
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      role: json['role'] ?? 0,
      groupNickname: json['group_nickname'],
      isMute: json['is_mute'] ?? false,
      muteEndTime: json['mute_end_time'] != null
          ? DateTime.parse(json['mute_end_time'])
          : null,
      isOnline: json['is_online'] ?? false,
      chatBackground: json['chat_background'],
      groupRemark: json['group_remark'],
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'])
          : null,
      canInitiateCall: json['can_initiate_call'] ?? false,
    );
  }

  /// 获取显示名称
  String get displayName {
    if (groupNickname != null && groupNickname!.isNotEmpty) {
      return groupNickname!;
    }
    return nickname.isNotEmpty ? nickname : username;
  }

  /// 是否是群主
  bool get isOwner => role == 2;

  /// 是否是管理员
  bool get isAdmin => role >= 1;

  /// 获取角色文字
  String get roleText {
    switch (role) {
      case 2:
        return 'Owner';
      case 1:
        return 'Admin';
      default:
        return 'Member';
    }
  }
}

/// 群组申请模型
class GroupRequest {
  final int id;
  final int groupId;
  final int userId;
  final String? message;
  final int status;
  final User? user;
  final DateTime? createdAt;

  GroupRequest({
    required this.id,
    required this.groupId,
    required this.userId,
    this.message,
    this.status = 0,
    this.user,
    this.createdAt,
  });

  factory GroupRequest.fromJson(Map<String, dynamic> json) {
    return GroupRequest(
      id: json['id'] ?? 0,
      groupId: json['group_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      message: json['message'],
      status: json['status'] ?? 0,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  /// 是否待处理
  bool get isPending => status == 0;
}

/// 我的群组（包含成员信息）
class MyGroup {
  final int groupId;
  final String groupNo;
  final String name;
  final String avatar;
  final int memberCount;
  final int role;
  final bool isMute;
  final bool isTop;

  MyGroup({
    required this.groupId,
    required this.groupNo,
    required this.name,
    this.avatar = '',
    this.memberCount = 0,
    this.role = 1,
    this.isMute = false,
    this.isTop = false,
  });

  factory MyGroup.fromJson(Map<String, dynamic> json) {
    return MyGroup(
      groupId: json['group_id'] ?? 0,
      groupNo: json['group_no'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      memberCount: json['member_count'] ?? 0,
      role: json['role'] ?? 1,
      isMute: json['is_mute'] ?? false,
      isTop: json['is_top'] ?? false,
    );
  }

  /// 是否是群主
  bool get isOwner => role == 2;

  /// 是否是管理员
  bool get isAdmin => role >= 1;
}

/// 管理员权限配置
class AdminPermissions {
  final bool canKick;
  final bool canMute;
  final bool canInvite;
  final bool canEditInfo;
  final bool canEditNotice;
  final bool canClearHistory;
  final bool canViewMembers;

  AdminPermissions({
    this.canKick = true,
    this.canMute = true,
    this.canInvite = true,
    this.canEditInfo = true,
    this.canEditNotice = true,
    this.canClearHistory = false,
    this.canViewMembers = true,
  });

  factory AdminPermissions.fromJson(Map<String, dynamic> json) {
    return AdminPermissions(
      canKick: json['can_kick'] ?? true,
      canMute: json['can_mute'] ?? true,
      canInvite: json['can_invite'] ?? true,
      canEditInfo: json['can_edit_info'] ?? true,
      canEditNotice: json['can_edit_notice'] ?? true,
      canClearHistory: json['can_clear_history'] ?? false,
      canViewMembers: json['can_view_members'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'can_kick': canKick,
      'can_mute': canMute,
      'can_invite': canInvite,
      'can_edit_info': canEditInfo,
      'can_edit_notice': canEditNotice,
      'can_clear_history': canClearHistory,
      'can_view_members': canViewMembers,
    };
  }
}

/// 我的群设置
class MyGroupSettings {
  final String? nickname;
  final bool isTop;
  final bool isNoDisturb;
  final bool showNickname;
  final String? chatBackground;
  final String? groupRemark;

  MyGroupSettings({
    this.nickname,
    this.isTop = false,
    this.isNoDisturb = false,
    this.showNickname = true,
    this.chatBackground,
    this.groupRemark,
  });

  factory MyGroupSettings.fromJson(Map<String, dynamic> json) {
    return MyGroupSettings(
      nickname: json['nickname'],
      isTop: json['is_top'] ?? false,
      isNoDisturb: json['is_no_disturb'] ?? false,
      showNickname: json['show_nickname'] ?? true,
      chatBackground: json['chat_background'],
      groupRemark: json['group_remark'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'is_top': isTop,
      'is_no_disturb': isNoDisturb,
      'show_nickname': showNickname,
      'chat_background': chatBackground,
      'group_remark': groupRemark,
    };
  }

  /// 复制并修改
  MyGroupSettings copyWith({
    String? nickname,
    bool? isTop,
    bool? isNoDisturb,
    bool? showNickname,
    String? chatBackground,
    String? groupRemark,
  }) {
    return MyGroupSettings(
      nickname: nickname ?? this.nickname,
      isTop: isTop ?? this.isTop,
      isNoDisturb: isNoDisturb ?? this.isNoDisturb,
      showNickname: showNickname ?? this.showNickname,
      chatBackground: chatBackground ?? this.chatBackground,
      groupRemark: groupRemark ?? this.groupRemark,
    );
  }
}

/// 进行中的群通话信息
class ActiveGroupCall {
  final int callId;
  final int callType; // 1语音 2视频
  final int initiatorId;
  final String initiatorName;
  final int currentCount;
  final DateTime? startedAt;

  ActiveGroupCall({
    required this.callId,
    required this.callType,
    required this.initiatorId,
    required this.initiatorName,
    this.currentCount = 0,
    this.startedAt,
  });

  bool get isVideo => callType == 2;
  bool get isVoice => callType == 1;

  ActiveGroupCall copyWith({int? currentCount}) {
    return ActiveGroupCall(
      callId: callId,
      callType: callType,
      initiatorId: initiatorId,
      initiatorName: initiatorName,
      currentCount: currentCount ?? this.currentCount,
      startedAt: startedAt,
    );
  }

  factory ActiveGroupCall.fromJson(Map<String, dynamic> json) {
    return ActiveGroupCall(
      callId: json['call_id'] ?? 0,
      callType: json['call_type'] ?? 1,
      initiatorId: json['initiator_id'] ?? 0,
      initiatorName: json['initiator_name'] ?? '',
      currentCount: json['current_count'] ?? 0,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString())
          : null,
    );
  }
}

/// 完整群信息（包含个人设置）
class GroupFullInfo {
  final Group group;
  final int myRole; // 0成员 1管理员 2群主
  final MyGroupSettings mySettings;
  final AdminPermissions adminPermissions;
  final ActiveGroupCall? activeCall; // 当前进行中的群通话

  GroupFullInfo({
    required this.group,
    required this.myRole,
    required this.mySettings,
    required this.adminPermissions,
    this.activeCall,
  });

  factory GroupFullInfo.fromJson(Map<String, dynamic> json) {
    return GroupFullInfo(
      group: Group.fromJson(json['group']),
      myRole: json['my_role'] ?? 0,
      mySettings: MyGroupSettings.fromJson(json['my_settings'] ?? {}),
      adminPermissions:
          AdminPermissions.fromJson(json['admin_permissions'] ?? {}),
      activeCall: json['active_call'] != null
          ? ActiveGroupCall.fromJson(json['active_call'])
          : null,
    );
  }

  /// 是否是群主
  bool get isOwner => myRole == 2;

  /// 是否是管理员
  bool get isAdmin => myRole >= 1;

  /// 是否可以编辑群信息
  bool get canEditInfo => isOwner || (isAdmin && adminPermissions.canEditInfo);

  /// 是否可以编辑公告
  bool get canEditNotice =>
      isOwner || (isAdmin && adminPermissions.canEditNotice);

  /// 是否可以踢人
  bool get canKick => isOwner || (isAdmin && adminPermissions.canKick);

  /// 是否可以禁言
  bool get canMute => isOwner || (isAdmin && adminPermissions.canMute);

  /// 是否可以邀请
  bool get canInvite => isOwner || (isAdmin && adminPermissions.canInvite);

  /// 是否可以清空消息
  bool get canClearHistory =>
      isOwner || (isAdmin && adminPermissions.canClearHistory);

  /// 是否可以查看成员列表
  bool get canViewMembers =>
      isOwner || (isAdmin && adminPermissions.canViewMembers);

  /// 复制并修改
  GroupFullInfo copyWith({
    Group? group,
    int? myRole,
    MyGroupSettings? mySettings,
    AdminPermissions? adminPermissions,
    ActiveGroupCall? activeCall,
  }) {
    return GroupFullInfo(
      group: group ?? this.group,
      myRole: myRole ?? this.myRole,
      mySettings: mySettings ?? this.mySettings,
      adminPermissions: adminPermissions ?? this.adminPermissions,
      activeCall: activeCall ?? this.activeCall,
    );
  }
}

/// 群二维码信息
class GroupQRCode {
  final String code;
  final DateTime? expireAt;
  final int groupId;
  final String groupName;
  final String? avatar;
  final int joinMode;

  GroupQRCode({
    required this.code,
    this.expireAt,
    required this.groupId,
    required this.groupName,
    this.avatar,
    this.joinMode = 1,
  });

  factory GroupQRCode.fromJson(Map<String, dynamic> json) {
    return GroupQRCode(
      code: json['code'] ?? '',
      expireAt: json['expire_at'] != null
          ? DateTime.parse(json['expire_at'])
          : null,
      groupId: json['group_id'] ?? 0,
      groupName: json['group_name'] ?? '',
      avatar: json['avatar'],
      joinMode: json['join_mode'] ?? 1,
    );
  }

  /// 是否已过期
  bool get isExpired {
    if (expireAt == null) return false;
    return DateTime.now().isAfter(expireAt!);
  }
}

/// 群通话类型
class GroupCallType {
  static const int voice = 1; // 语音通话
  static const int video = 2; // 视频通话
}

/// 群通话状态
class GroupCallStatus {
  static const int ongoing = 0;   // 进行中
  static const int ended = 1;     // 已结束
  static const int cancelled = 2; // 已取消
}

/// 群通话模型
class GroupCall {
  final int id;
  final int groupId;
  final int initiatorId;
  final int callType; // 1视频 2语音
  final int status; // 1进行中 2已结束
  final int participantCount;
  final int maxParticipants;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? roomId;
  final User? initiator;

  GroupCall({
    required this.id,
    required this.groupId,
    required this.initiatorId,
    this.callType = GroupCallType.voice,
    this.status = GroupCallStatus.ongoing,
    this.participantCount = 0,
    this.maxParticipants = 9,
    this.startedAt,
    this.endedAt,
    this.roomId,
    this.initiator,
  });

  // 安全类型转换
  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  factory GroupCall.fromJson(Map<String, dynamic> json) {
    return GroupCall(
      id: _toInt(json['id'] ?? json['call_id']),
      groupId: _toInt(json['group_id']),
      initiatorId: _toInt(json['initiator_id']),
      callType: _toInt(json['call_type']),
      status: _toInt(json['status']),
      participantCount: _toInt(json['participant_count'] ?? json['current_count']),
      maxParticipants: _toInt(json['max_participants']),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'])
          : null,
      roomId: json['room_id'],
      initiator: json['initiator'] != null
          ? User.fromJson(json['initiator'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'initiator_id': initiatorId,
      'call_type': callType,
      'status': status,
      'participant_count': participantCount,
      'max_participants': maxParticipants,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'room_id': roomId,
    };
  }

  /// 是否是视频通话
  bool get isVideo => callType == GroupCallType.video;

  /// 是否是语音通话
  bool get isVoice => callType == GroupCallType.voice;

  /// 是否进行中
  bool get isOngoing => status == GroupCallStatus.ongoing;

  /// 是否已结束
  bool get isEnded => status == GroupCallStatus.ended;

  /// 是否已满员
  bool get isFull => participantCount >= maxParticipants;

  /// 获取通话类型文字
  String get callTypeText => isVideo ? 'Video Call' : 'Voice Call';
}

/// 群通话参与者模型
class GroupCallParticipant {
  final int id;
  final int callId;
  final int userId;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final bool isMuted;
  final bool isVideoOff;
  final User? user;

  GroupCallParticipant({
    required this.id,
    required this.callId,
    required this.userId,
    this.joinedAt,
    this.leftAt,
    this.isMuted = false,
    this.isVideoOff = false,
    this.user,
  });

  // 安全类型转换
  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  factory GroupCallParticipant.fromJson(Map<String, dynamic> json) {
    return GroupCallParticipant(
      id: _toInt(json['id']),
      callId: _toInt(json['call_id']),
      userId: _toInt(json['user_id']),
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'])
          : null,
      leftAt: json['left_at'] != null
          ? DateTime.parse(json['left_at'])
          : null,
      isMuted: json['is_muted'] ?? false,
      isVideoOff: json['is_video_off'] ?? false,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'call_id': callId,
      'user_id': userId,
      'joined_at': joinedAt?.toIso8601String(),
      'left_at': leftAt?.toIso8601String(),
      'is_muted': isMuted,
      'is_video_off': isVideoOff,
    };
  }

  /// 是否还在通话中
  bool get isInCall => leftAt == null;
}

/// 付费群配置信息
class PaidGroupConfig {
  final int ownerShareRatio;         // 群主分成比例 (0-100)
  final int platformCommission;      // 平台抽佣比例 (0-100)
  final int userLevel;               // 用户等级
  final int maxGroups;               // 可创建群总数上限
  final int maxPaidGroups;           // 可创建付费群上限
  final int currentGroupCount;       // 已创建群总数
  final int currentPaidGroupCount;   // 已创建付费群数
  final bool canCreateGroup;         // 是否还能创建群
  final bool canCreatePaidGroup;     // 是否还能创建付费群

  PaidGroupConfig({
    required this.ownerShareRatio,
    required this.platformCommission,
    required this.userLevel,
    required this.maxGroups,
    required this.maxPaidGroups,
    required this.currentGroupCount,
    required this.currentPaidGroupCount,
    required this.canCreateGroup,
    required this.canCreatePaidGroup,
  });

  factory PaidGroupConfig.fromJson(Map<String, dynamic> json) {
    return PaidGroupConfig(
      ownerShareRatio: json['owner_share_ratio'] ?? 70,
      platformCommission: json['platform_commission'] ?? 30,
      userLevel: json['user_level'] ?? 1,
      maxGroups: json['max_groups'] ?? 3,
      maxPaidGroups: json['max_paid_groups'] ?? 0,
      currentGroupCount: json['current_group_count'] ?? 0,
      currentPaidGroupCount: json['current_paid_group_count'] ?? 0,
      canCreateGroup: json['can_create_group'] ?? true,
      canCreatePaidGroup: json['can_create_paid_group'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'owner_share_ratio': ownerShareRatio,
      'platform_commission': platformCommission,
      'user_level': userLevel,
      'max_groups': maxGroups,
      'max_paid_groups': maxPaidGroups,
      'current_group_count': currentGroupCount,
      'current_paid_group_count': currentPaidGroupCount,
      'can_create_group': canCreateGroup,
      'can_create_paid_group': canCreatePaidGroup,
    };
  }

  /// 格式化显示分成信息
  String get shareInfoDisplay => '群主获得 $ownerShareRatio%，平台抽佣 $platformCommission%';
}
