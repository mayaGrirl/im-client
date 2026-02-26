/// 消息数据模型
/// 定义消息和会话相关的数据结构

import 'package:im_client/models/user.dart';

/// 消息模型
/// 消息存储在客户端本地数据库
/// 消息状态常量
class MessageStatus {
  static const int sending = 1;    // 发送中
  static const int sent = 2;       // 已发送
  static const int recalled = 3;   // 已撤回
  static const int failed = 4;     // 发送失败
}

class Message {
  final int? id;           // 本地数据库ID
  final String msgId;      // 消息唯一ID
  final String? conversId; // 会话ID
  final int fromUserId;    // 发送者ID
  final int? toUserId;     // 接收者ID（私聊）
  final int? groupId;      // 群组ID（群聊）
  final int type;          // 消息类型
  final String content;    // 消息内容
  final String? extra;     // 扩展数据
  final int status;        // 状态：1发送中 2已发送 3已撤回 4发送失败
  final String? replyMsgId; // 回复的消息ID
  final String? atUserIds; // @的用户ID列表
  final User? fromUser;    // 发送者信息
  final ReplyMessageInfo? replyMessage; // 被回复消息的信息
  final DateTime? createdAt; // 创建时间
  final bool isRead;       // 是否已读
  final bool isOffline;    // 是否是离线消息
  final String? failReason; // 发送失败原因

  Message({
    this.id,
    required this.msgId,
    this.conversId,
    required this.fromUserId,
    this.toUserId,
    this.groupId,
    required this.type,
    required this.content,
    this.extra,
    this.status = 1,
    this.replyMsgId,
    this.atUserIds,
    this.fromUser,
    this.replyMessage,
    this.createdAt,
    this.isRead = false,
    this.isOffline = false,
    this.failReason,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // 辅助函数：安全地转换为int
    int? toInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    // 辅助函数：安全地转换为Map<String, dynamic>
    Map<String, dynamic>? toMap(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    // 解析创建时间
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    // 安全解析嵌套的from_user对象
    User? fromUser;
    final fromUserMap = toMap(json['from_user']);
    if (fromUserMap != null) {
      fromUser = User.fromJson(fromUserMap);
    }

    // 安全解析嵌套的reply_message对象
    ReplyMessageInfo? replyMessage;
    final replyMessageMap = toMap(json['reply_message']);
    if (replyMessageMap != null) {
      replyMessage = ReplyMessageInfo.fromJson(replyMessageMap);
    }

    return Message(
      id: toInt(json['id']),
      msgId: json['msg_id']?.toString() ?? json['message_id']?.toString() ?? '',
      conversId: json['convers_id']?.toString(),
      fromUserId: toInt(json['from_user_id']) ?? 0,
      toUserId: toInt(json['to_user_id']),
      groupId: toInt(json['group_id']),
      type: toInt(json['type']) ?? toInt(json['content_type']) ?? 1,
      content: json['content']?.toString() ?? '',
      extra: json['extra']?.toString(),
      status: toInt(json['status']) ?? 2, // 默认为已发送（接收方收到的消息没有status字段）
      replyMsgId: json['reply_msg_id']?.toString() ?? json['reply_to']?.toString(),
      atUserIds: json['at_user_ids']?.toString() ?? json['at_users']?.toString(),
      fromUser: fromUser,
      replyMessage: replyMessage,
      createdAt: parseDateTime(json['created_at']),
      isRead: json['is_read'] == true,
      isOffline: json['offline'] == true,
      failReason: json['fail_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'msg_id': msgId,
      'convers_id': conversId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'group_id': groupId,
      'type': type,
      'content': content,
      'extra': extra,
      'status': status,
      'reply_msg_id': replyMsgId,
      'at_user_ids': atUserIds,
      'from_user': fromUser?.toJson(),
      'reply_message': replyMessage?.toJson(),
      'created_at': createdAt?.toIso8601String(),
      'is_read': isRead,
      'offline': isOffline,
      'fail_reason': failReason,
    };
  }

  /// 复制并修改消息
  Message copyWith({
    int? id,
    String? msgId,
    String? conversId,
    int? fromUserId,
    int? toUserId,
    int? groupId,
    int? type,
    String? content,
    String? extra,
    int? status,
    String? replyMsgId,
    String? atUserIds,
    User? fromUser,
    ReplyMessageInfo? replyMessage,
    DateTime? createdAt,
    bool? isRead,
    bool? isOffline,
    String? failReason,
  }) {
    return Message(
      id: id ?? this.id,
      msgId: msgId ?? this.msgId,
      conversId: conversId ?? this.conversId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      groupId: groupId ?? this.groupId,
      type: type ?? this.type,
      content: content ?? this.content,
      extra: extra ?? this.extra,
      status: status ?? this.status,
      replyMsgId: replyMsgId ?? this.replyMsgId,
      atUserIds: atUserIds ?? this.atUserIds,
      fromUser: fromUser ?? this.fromUser,
      replyMessage: replyMessage ?? this.replyMessage,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isOffline: isOffline ?? this.isOffline,
      failReason: failReason ?? this.failReason,
    );
  }

  /// 是否是文本消息
  bool get isText => type == 1;

  /// 是否是图片消息
  bool get isImage => type == 2;

  /// 是否是语音消息
  bool get isVoice => type == 3;

  /// 是否是视频消息
  bool get isVideo => type == 4;

  /// 是否是文件消息
  bool get isFile => type == 5;

  /// 是否是位置消息
  bool get isLocation => type == 6;

  /// 是否是名片消息
  bool get isCard => type == 7;

  /// 是否是合并转发消息
  bool get isForward => type == 8;

  /// 是否是系统消息
  bool get isSystem => type == 100;

  /// 是否已撤回
  bool get isRecalled => status == MessageStatus.recalled;

  /// 是否发送失败
  bool get isFailed => status == MessageStatus.failed;

  /// 是否发送中
  bool get isSending => status == MessageStatus.sending;

  /// 是否是群聊消息
  bool get isGroupMessage => (groupId ?? 0) > 0;
}

/// 会话模型
/// 会话信息存储在客户端本地数据库
class Conversation {
  final int? id;            // 本地数据库ID
  final String conversId;   // 会话ID
  final int? userId;        // 当前用户ID
  final int type;           // 1私聊 2群聊
  final int targetId;       // 对方用户ID或群组ID
  final String? lastMsgId;  // 最后一条消息ID
  final String lastMsgPreview; // 最后一条消息预览
  final DateTime? lastMsgTime; // 最后一条消息时间
  final int unreadCount;    // 未读数
  final bool isTop;         // 是否置顶
  final DateTime? topTime;  // 置顶时间（用于多个置顶项排序）
  final bool isMute;        // 是否免打扰
  final String? draft;      // 草稿
  final dynamic targetInfo; // User或Group对象

  Conversation({
    this.id,
    required this.conversId,
    this.userId,
    required this.type,
    required this.targetId,
    this.lastMsgId,
    this.lastMsgPreview = '',
    this.lastMsgTime,
    this.unreadCount = 0,
    this.isTop = false,
    this.topTime,
    this.isMute = false,
    this.draft,
    this.targetInfo,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // 安全解析targetInfo，确保是Map<String, dynamic>类型
    dynamic targetInfo = json['target_info'];
    if (targetInfo != null && targetInfo is Map && targetInfo is! Map<String, dynamic>) {
      targetInfo = Map<String, dynamic>.from(targetInfo);
    }

    // 解析置顶时间
    DateTime? topTime;
    if (json['top_time'] != null) {
      if (json['top_time'] is DateTime) {
        topTime = json['top_time'];
      } else if (json['top_time'] is String) {
        topTime = DateTime.tryParse(json['top_time']);
      }
    }

    return Conversation(
      id: json['id'],
      conversId: json['convers_id'] ?? '',
      userId: json['user_id'],
      type: json['type'] ?? 1,
      targetId: json['target_id'] ?? 0,
      lastMsgId: json['last_msg_id'],
      lastMsgPreview: json['last_msg_preview'] ?? '',
      lastMsgTime: json['last_msg_time'] != null
          ? (json['last_msg_time'] is DateTime
              ? json['last_msg_time']
              : DateTime.parse(json['last_msg_time']))
          : null,
      unreadCount: json['unread_count'] ?? 0,
      isTop: json['is_top'] == true || json['is_top'] == 1,
      topTime: topTime,
      isMute: json['is_mute'] == true || json['is_mute'] == 1,
      draft: json['draft'],
      targetInfo: targetInfo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'convers_id': conversId,
      'user_id': userId,
      'type': type,
      'target_id': targetId,
      'last_msg_id': lastMsgId,
      'last_msg_preview': lastMsgPreview,
      'last_msg_time': lastMsgTime?.toIso8601String(),
      'unread_count': unreadCount,
      'is_top': isTop,
      'top_time': topTime?.toIso8601String(),
      'is_mute': isMute,
      'draft': draft,
    };
  }

  /// 是否是私聊
  bool get isPrivate => type == 1;

  /// 是否是群聊
  bool get isGroup => type == 2;

  /// 获取头像
  String get avatar {
    if (targetInfo == null) return '';
    if (targetInfo is Map) {
      return targetInfo['avatar'] ?? '';
    }
    return '';
  }

  /// 获取名称（优先显示备注名）
  String get name {
    if (targetInfo == null) return '';
    if (targetInfo is Map) {
      // 优先级：display_name > remark > nickname > name > username
      return targetInfo['display_name'] ??
          targetInfo['remark'] ??
          targetInfo['nickname'] ??
          targetInfo['name'] ??
          targetInfo['username'] ??
          '';
    }
    return '';
  }

  /// 获取原始昵称（不受备注影响）
  String get nickname {
    if (targetInfo == null) return '';
    if (targetInfo is Map) {
      return targetInfo['nickname'] ?? targetInfo['name'] ?? '';
    }
    return '';
  }

  /// 获取备注名
  String? get remark {
    if (targetInfo == null) return null;
    if (targetInfo is Map) {
      final r = targetInfo['remark'];
      return (r != null && r.toString().isNotEmpty) ? r.toString() : null;
    }
    return null;
  }

  /// 是否是付费群（仅群聊时有效）
  bool get isPaidGroup {
    if (!isGroup) return false;
    if (targetInfo == null) return false;
    if (targetInfo is Map) {
      return targetInfo['is_paid'] == true;
    }
    return false;
  }

  /// 是否允许群语音通话（仅群聊时有效）
  bool get allowVoiceCall {
    if (!isGroup) return false;
    if (targetInfo == null) return false;
    if (targetInfo is Map) {
      return targetInfo['allow_group_call'] == true &&
             targetInfo['allow_voice_call'] == true;
    }
    return false;
  }

  /// 是否允许群视频通话（仅群聊时有效）
  bool get allowVideoCall {
    if (!isGroup) return false;
    if (targetInfo == null) return false;
    if (targetInfo is Map) {
      return targetInfo['allow_group_call'] == true &&
             targetInfo['allow_video_call'] == true;
    }
    return false;
  }

  /// 复制并修改
  Conversation copyWith({
    int? id,
    String? conversId,
    int? userId,
    int? type,
    int? targetId,
    String? lastMsgId,
    String? lastMsgPreview,
    DateTime? lastMsgTime,
    int? unreadCount,
    bool? isTop,
    DateTime? topTime,
    bool? isMute,
    String? draft,
    dynamic targetInfo,
    bool clearTopTime = false,
  }) {
    return Conversation(
      id: id ?? this.id,
      conversId: conversId ?? this.conversId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
      lastMsgId: lastMsgId ?? this.lastMsgId,
      lastMsgPreview: lastMsgPreview ?? this.lastMsgPreview,
      lastMsgTime: lastMsgTime ?? this.lastMsgTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isTop: isTop ?? this.isTop,
      topTime: clearTopTime ? null : (topTime ?? this.topTime),
      isMute: isMute ?? this.isMute,
      draft: draft ?? this.draft,
      targetInfo: targetInfo ?? this.targetInfo,
    );
  }
}

/// 被回复消息的信息
class ReplyMessageInfo {
  final String msgId;
  final int fromUserId;
  final int type;
  final String content;
  final User? fromUser;

  ReplyMessageInfo({
    required this.msgId,
    required this.fromUserId,
    required this.type,
    required this.content,
    this.fromUser,
  });

  factory ReplyMessageInfo.fromJson(Map<String, dynamic> json) {
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

    return ReplyMessageInfo(
      msgId: json['msg_id']?.toString() ?? '',
      fromUserId: json['from_user_id'] ?? 0,
      type: json['type'] ?? 1,
      content: json['content']?.toString() ?? '',
      fromUser: fromUser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'msg_id': msgId,
      'from_user_id': fromUserId,
      'type': type,
      'content': content,
      'from_user': fromUser?.toJson(),
    };
  }
}

/// 已读回执模型
class MessageRead {
  final int id;
  final String msgId;
  final int userId;
  final DateTime readAt;

  MessageRead({
    required this.id,
    required this.msgId,
    required this.userId,
    required this.readAt,
  });

  factory MessageRead.fromJson(Map<String, dynamic> json) {
    return MessageRead(
      id: json['id'] ?? 0,
      msgId: json['msg_id'] ?? '',
      userId: json['user_id'] ?? 0,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'])
          : DateTime.now(),
    );
  }
}
