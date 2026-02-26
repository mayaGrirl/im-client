/// 群组相关API
import 'api_client.dart';
import '../models/group.dart';

class GroupApi {
  final ApiClient _client;

  GroupApi(this._client);

  /// 创建群组
  Future<ApiResult> createGroup({
    required String name,
    String? description,
    String? avatar,
    List<int>? memberIds,
  }) async {
    final response = await _client.post('/group/create', data: {
      'name': name,
      'description': description,
      'avatar': avatar,
      'member_ids': memberIds,
    });
    return response.toResult();
  }

  /// 获取我的群组列表
  Future<List<Group>> getMyGroups() async {
    final response = await _client.get('/group/list');
    if (response.success && response.data != null) {
      final list = response.data as List;
      return list.map((json) => Group.fromJson(json)).toList();
    }
    return [];
  }

  /// 搜索群组
  Future<List<Group>> searchGroup(String keyword) async {
    final response = await _client.get('/group/search', queryParameters: {'keyword': keyword});
    if (response.success && response.data != null) {
      // 服务器返回分页格式: {list: [...], total: n, page: n, page_size: n}
      final data = response.data;
      List list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['list'] != null) {
        list = data['list'] as List;
      } else {
        return [];
      }
      return list.map((json) => Group.fromJson(json)).toList();
    }
    return [];
  }

  /// 获取群组信息
  Future<Group?> getGroupInfo(int groupId) async {
    final response = await _client.get('/group/$groupId');
    if (response.success && response.data != null) {
      return Group.fromJson(response.data);
    }
    return null;
  }

  /// 获取群成员列表
  Future<List<GroupMember>> getGroupMembers(int groupId) async {
    final response = await _client.get('/group/$groupId/members');
    if (response.success && response.data != null) {
      final list = response.data as List;
      return list.map((json) => GroupMember.fromJson(json)).toList();
    }
    return [];
  }

  /// 申请加入群组
  Future<ApiResult> joinGroup(int groupId, {String? message}) async {
    final response = await _client.post('/group/$groupId/join', data: {
      'message': message,
    });
    return response.toResult();
  }

  /// 退出群组
  Future<ApiResult> leaveGroup(int groupId) async {
    final response = await _client.post('/group/$groupId/leave');
    return response.toResult();
  }

  /// 更新群组信息
  Future<ApiResult> updateGroup(int groupId, {
    String? name,
    String? description,
    String? avatar,
    String? notice,
  }) async {
    // 只发送非 null 的字段
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (avatar != null) data['avatar'] = avatar;
    if (notice != null) data['notice'] = notice;

    print('[GroupApi] updateGroup: groupId=$groupId, data=$data');
    final response = await _client.put('/group/$groupId', data: data);
    print('[GroupApi] updateGroup response: success=${response.success}, message=${response.message}');
    return response.toResult();
  }

  /// 更新群设置
  Future<ApiResult> updateGroupSettings(int groupId, {
    int? joinMode,
    bool? allowInvite,
    bool? showMember,
  }) async {
    final response = await _client.put('/group/$groupId/settings', data: {
      'join_mode': joinMode,
      'allow_invite': allowInvite,
      'show_member': showMember,
    });
    return response.toResult();
  }

  // ============ 群分享相关 ============

  /// 创建分享链接
  Future<ShareLinkResult?> createShareLink(int groupId, {int expireDays = 7, int maxUses = 0}) async {
    final response = await _client.post('/group/$groupId/share-link', data: {
      'expire_days': expireDays,
      'max_uses': maxUses,
    });
    if (response.success && response.data != null) {
      return ShareLinkResult.fromJson(response.data);
    }
    return null;
  }

  /// 获取我的分享链接
  Future<List<ShareLinkResult>> getMyShareLinks(int groupId) async {
    final response = await _client.get('/group/$groupId/share-links');
    if (response.success && response.data != null) {
      final list = response.data as List;
      return list.map((json) => ShareLinkResult.fromJson(json)).toList();
    }
    return [];
  }

  /// 撤销分享链接
  Future<ApiResult> revokeShareLink(int groupId, int linkId) async {
    final response = await _client.delete('/group/$groupId/share-link/$linkId');
    return response.toResult();
  }

  /// 分享群组到聊天
  Future<ApiResult> shareGroupToChat(int groupId, {List<int>? toUserIds, int? toGroupId}) async {
    final response = await _client.post('/group/$groupId/share', data: {
      'to_user_ids': toUserIds,
      'to_group_id': toGroupId,
    });
    return response.toResult();
  }

  /// 通过分享码获取群信息
  Future<Group?> getGroupByShareCode(String code) async {
    final response = await _client.get('/group-share/$code');
    if (response.success && response.data != null) {
      return Group.fromJson(response.data);
    }
    return null;
  }

  /// 通过分享码加入群组
  Future<ApiResult> joinGroupByShareCode(String code, {String? message, String? answer}) async {
    final response = await _client.post('/group-share/$code/join', data: {
      'message': message,
      if (answer != null && answer.isNotEmpty) 'answer': answer,
    });
    return response.toResult();
  }

  // ============ 群设置扩展相关 ============

  /// 获取完整群信息（包含个人设置）
  Future<GroupFullInfo?> getGroupFullInfo(int groupId) async {
    final response = await _client.get('/group/$groupId/full-info');
    if (response.success && response.data != null) {
      return GroupFullInfo.fromJson(response.data);
    }
    return null;
  }

  /// 获取管理员权限配置
  Future<AdminPermissions?> getAdminPermissions(int groupId) async {
    final response = await _client.get('/group/$groupId/admin-permissions');
    print('[GroupApi] getAdminPermissions: success=${response.success}, data=${response.data}');
    if (response.success && response.data != null) {
      return AdminPermissions.fromJson(response.data);
    }
    return null;
  }

  /// 更新管理员权限配置
  Future<ApiResult> updateAdminPermissions(int groupId, {
    bool? canKick,
    bool? canMute,
    bool? canInvite,
    bool? canEditInfo,
    bool? canEditNotice,
    bool? canClearHistory,
    bool? canViewMembers,
  }) async {
    final response = await _client.put('/group/$groupId/admin-permissions', data: {
      'can_kick': canKick,
      'can_mute': canMute,
      'can_invite': canInvite,
      'can_edit_info': canEditInfo,
      'can_edit_notice': canEditNotice,
      'can_clear_history': canClearHistory,
      'can_view_members': canViewMembers,
    });
    return response.toResult();
  }

  /// 更新群备注名
  Future<ApiResult> updateGroupRemark(int groupId, String remark) async {
    final response = await _client.put('/group/$groupId/remark', data: {
      'remark': remark,
    });
    return response.toResult();
  }

  /// 清空群聊所有消息
  Future<ApiResult> clearGroupMessages(int groupId) async {
    final response = await _client.post('/group/$groupId/clear-all-messages');
    return response.toResult();
  }

  /// 更新群聊定时清除设置
  /// [autoClearDays] 自动清除天数: 0=禁用, 1/3/7/10/30=自动清除间隔天数
  Future<ApiResult> updateAutoClearSettings(int groupId, int autoClearDays) async {
    final response = await _client.put('/group/$groupId/auto-clear', data: {
      'auto_clear_days': autoClearDays,
    });
    return response.toResult();
  }

  /// 更新群人数上限
  Future<ApiResult> updateMaxMembers(int groupId, int maxMembers) async {
    final response = await _client.put('/group/$groupId/max-members', data: {
      'max_members': maxMembers,
    });
    return response.toResult();
  }

  /// 获取群二维码
  Future<GroupQRCode?> getGroupQRCode(int groupId) async {
    final response = await _client.get('/group/$groupId/qrcode');
    if (response.success && response.data != null) {
      return GroupQRCode.fromJson(response.data);
    }
    return null;
  }

  /// 更新加群设置
  Future<ApiResult> updateGroupJoinSettings(int groupId, {
    bool? allowAddFriend,
    int? qrcodeJoinMode,
    bool? allowQrcodeJoin,
  }) async {
    final response = await _client.put('/group/$groupId/join-settings', data: {
      'allow_add_friend': allowAddFriend,
      'qrcode_join_mode': qrcodeJoinMode,
      'allow_qrcode_join': allowQrcodeJoin,
    });
    return response.toResult();
  }

  /// 更新聊天背景
  Future<ApiResult> updateChatBackground(int groupId, String background) async {
    final response = await _client.put('/group/$groupId/chat-background', data: {
      'chat_background': background,
    });
    return response.toResult();
  }

  /// 获取管理员列表
  Future<List<GroupMember>> getGroupAdmins(int groupId) async {
    final response = await _client.get('/group/$groupId/admins');
    if (response.success && response.data != null) {
      final list = response.data as List;
      return list.map((json) => GroupMember.fromJson(json)).toList();
    }
    return [];
  }

  /// 更新我的群设置
  Future<ApiResult> updateMyGroupSettings(int groupId, {
    String? nickname,
    bool? isTop,
    bool? isNoDisturb,
    bool? showNickname,
  }) async {
    final response = await _client.put('/group/$groupId/my-settings', data: {
      'nickname': nickname,
      'is_top': isTop,
      'is_no_disturb': isNoDisturb,
      'show_nickname': showNickname,
    });
    return response.toResult();
  }

  /// 设置/取消管理员
  Future<ApiResult> setGroupAdmin(int groupId, int targetUserId, bool isAdmin) async {
    final response = await _client.post('/group/$groupId/admin', data: {
      'target_user_id': targetUserId,
      'is_admin': isAdmin,
    });
    return response.toResult();
  }

  /// 转让群主
  Future<ApiResult> transferGroup(int groupId, int newOwnerId) async {
    final response = await _client.post('/group/$groupId/transfer', data: {
      'new_owner_id': newOwnerId,
    });
    return response.toResult();
  }

  /// 解散群组
  Future<ApiResult> disbandGroup(int groupId) async {
    final response = await _client.post('/group/$groupId/disband');
    return response.toResult();
  }

  /// 禁言成员
  Future<ApiResult> muteMember(int groupId, int targetUserId, int duration) async {
    final response = await _client.post('/group/$groupId/mute', data: {
      'target_user_id': targetUserId,
      'duration': duration, // 分钟，0表示解除禁言
    });
    return response.toResult();
  }

  /// 全员禁言
  Future<ApiResult> setGroupMuteAll(int groupId, bool muteAll, {int duration = 0}) async {
    final response = await _client.post('/group/$groupId/mute-all', data: {
      'mute_all': muteAll,
      'duration': duration, // 分钟，0表示永久
    });
    return response.toResult();
  }

  /// 踢出成员
  Future<ApiResult> kickMember(int groupId, int targetUserId) async {
    final response = await _client.post('/group/$groupId/kick', data: {
      'target_user_id': targetUserId,
    });
    return response.toResult();
  }

  /// 邀请成员
  Future<ApiResult> inviteMembers(int groupId, List<int> userIds) async {
    final response = await _client.post('/group/$groupId/invite', data: {
      'user_ids': userIds,
    });
    return response.toResult();
  }

  /// 获取入群申请
  Future<List<GroupRequest>> getGroupRequests(int groupId) async {
    final response = await _client.get('/group/$groupId/requests');
    print('[GroupApi] getGroupRequests: success=${response.success}, data=${response.data}');
    if (response.success && response.data != null) {
      final list = response.data as List;
      for (final json in list) {
        print('[GroupApi] 原始JSON: $json');
        print('[GroupApi] user字段: ${json['user']}');
      }
      return list.map((json) => GroupRequest.fromJson(json)).toList();
    }
    return [];
  }

  /// 处理入群申请
  Future<ApiResult> handleGroupRequest(int groupId, int requestId, int action, {String? rejectReason}) async {
    final response = await _client.post('/group/$groupId/handle-request', data: {
      'request_id': requestId,
      'action': action, // 1同意 2拒绝
      if (rejectReason != null) 'reject_reason': rejectReason,
    });
    return response.toResult();
  }

  // ============ 付费群相关 ============

  /// 获取付费群配置（包括平台抽佣比例和用户群创建限制）
  Future<PaidGroupConfig?> getPaidGroupConfig() async {
    final response = await _client.get('/group/paid-config');
    if (response.success && response.data != null) {
      return PaidGroupConfig.fromJson(response.data);
    }
    return null;
  }

  /// 创建付费群
  /// 注意：分成比例由管理端设置，客户端不需要传入
  /// priceType: 价格类型 1=一次性(永久) 2=包月 3=包年
  /// allowTrialDays: 试用天数，0表示不允许试用
  Future<ApiResult> createPaidGroup({
    required String name,
    String? description,
    String? avatar,
    List<int>? memberIds,
    required double price,
    int priceType = 1,        // 默认一次性付费
    int allowTrialDays = 0,   // 默认不允许试用
  }) async {
    final response = await _client.post('/group/create', data: {
      'name': name,
      'description': description,
      'avatar': avatar,
      'member_ids': memberIds,
      'is_paid': true,
      'join_price': price,  // 保留小数精度
      'join_price_type': priceType,
      'allow_trial_days': allowTrialDays,
    });
    return response.toResult();
  }

  /// 更新付费群设置
  /// 注意：分成比例由管理端设置，客户端不能修改
  Future<ApiResult> updatePaidGroupSettings(int groupId, {
    bool? isPaid,
    double? price,
    int? priceType,        // 价格类型：1一次性 2包月 3包年
    int? allowTrialDays,   // 试用天数(0为不允许试用)
  }) async {
    final data = <String, dynamic>{};
    if (isPaid != null) data['is_paid'] = isPaid;
    if (price != null) data['join_price'] = price;  // 保留小数精度
    if (priceType != null) data['join_price_type'] = priceType;
    if (allowTrialDays != null) data['allow_trial_days'] = allowTrialDays;

    final response = await _client.put('/group/$groupId/paid-settings', data: data);
    return response.toResult();
  }

  /// 付费加入群组
  Future<ApiResult> payToJoinGroup(int groupId, {bool useTrial = false}) async {
    final response = await _client.post('/group/$groupId/pay-join', data: {
      'use_trial': useTrial,  // 是否使用试用
    });
    return response.toResult();
  }

  /// 获取付费群加入信息（价格、试用等）
  Future<Map<String, dynamic>?> getPaidGroupJoinInfo(int groupId) async {
    final response = await _client.get('/group/$groupId/join-info');
    if (response.success && response.data != null) {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }

  // ============ 群通话相关 ============

  /// 发起群通话
  /// callType: 1=语音, 2=视频
  /// 返回 (GroupCall?, errorMessage) - 成功时返回GroupCall，失败时返回错误信息
  Future<(GroupCall?, String?)> initiateGroupCall(int groupId, {int callType = 1}) async {
    final response = await _client.post('/group/$groupId/call', data: {
      'call_type': callType,
    });
    if (response.success && response.data != null) {
      return (GroupCall.fromJson(response.data), null);
    }
    return (null, response.message);
  }

  /// 加入群通话
  Future<ApiResult> joinGroupCall(int groupId, int callId) async {
    final response = await _client.post('/group/$groupId/call/$callId/join');
    return response.toResult();
  }

  /// 离开群通话
  Future<ApiResult> leaveGroupCall(int groupId, int callId) async {
    final response = await _client.post('/group/$groupId/call/$callId/leave');
    return response.toResult();
  }

  /// 结束群通话
  Future<ApiResult> endGroupCall(int groupId, int callId) async {
    final response = await _client.post('/group/$groupId/call/$callId/end');
    return response.toResult();
  }

  /// 获取当前进行中的群通话
  Future<GroupCall?> getCurrentGroupCall(int groupId) async {
    final response = await _client.get('/group/$groupId/call/current');
    if (response.success && response.data != null) {
      return GroupCall.fromJson(response.data);
    }
    return null;
  }

  /// 获取群通话参与者列表
  /// 返回 null 表示通话不存在（404），返回空列表表示无参与者
  Future<List<GroupCallParticipant>?> getGroupCallParticipants(int groupId, int callId) async {
    final response = await _client.get('/group/$groupId/call/$callId/participants');
    if (response.success && response.data != null) {
      final list = response.data as List;
      return list.map((json) => GroupCallParticipant.fromJson(json)).toList();
    }
    // 404 表示通话不存在，返回 null
    if (response.code == 404) {
      return null;
    }
    // 其他错误返回空列表
    return [];
  }

  /// 授予成员发起通话权限
  Future<ApiResult> grantCallPermission(int groupId, int targetUserId, bool canInitiateCall) async {
    final response = await _client.post('/group/$groupId/call-permission', data: {
      'target_user_id': targetUserId,
      'can_initiate_call': canInitiateCall,
    });
    return response.toResult();
  }

  /// 更新群通话设置
  Future<ApiResult> updateGroupCallSettings(int groupId, {
    bool? allowGroupCall,
    bool? allowVoiceCall,
    bool? allowVideoCall,
    bool? memberCanInitiateCall,
    int? maxCallParticipants,
  }) async {
    final data = <String, dynamic>{};
    if (allowGroupCall != null) data['allow_group_call'] = allowGroupCall;
    if (allowVoiceCall != null) data['allow_voice_call'] = allowVoiceCall;
    if (allowVideoCall != null) data['allow_video_call'] = allowVideoCall;
    if (memberCanInitiateCall != null) data['member_can_initiate_call'] = memberCanInitiateCall;
    if (maxCallParticipants != null) data['max_call_participants'] = maxCallParticipants;

    final response = await _client.put('/group/$groupId/call-settings', data: data);
    return response.toResult();
  }

  /// 获取群通话历史记录
  Future<List<GroupCall>> getGroupCallHistory(int groupId, {int page = 1, int pageSize = 20}) async {
    final response = await _client.get('/group/$groupId/call/history', queryParameters: {
      'page': page,
      'page_size': pageSize,
    });
    if (response.success && response.data != null) {
      final data = response.data;
      List list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['list'] != null) {
        list = data['list'] as List;
      } else {
        return [];
      }
      return list.map((json) => GroupCall.fromJson(json)).toList();
    }
    return [];
  }
}

/// 分享链接结果
class ShareLinkResult {
  final int? id;
  final String shareCode;
  final DateTime? expireAt;
  final int maxUses;
  final int usedCount;
  final bool isValid;
  final DateTime? createdAt;

  ShareLinkResult({
    this.id,
    required this.shareCode,
    this.expireAt,
    this.maxUses = 0,
    this.usedCount = 0,
    this.isValid = true,
    this.createdAt,
  });

  factory ShareLinkResult.fromJson(Map<String, dynamic> json) {
    return ShareLinkResult(
      id: json['id'],
      shareCode: json['share_code'] ?? json['code'] ?? '',
      expireAt: json['expire_at'] != null ? DateTime.parse(json['expire_at']) : null,
      maxUses: json['max_uses'] ?? 0,
      usedCount: json['used_count'] ?? 0,
      isValid: json['is_valid'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}
