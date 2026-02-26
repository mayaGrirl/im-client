import '../models/message.dart';

/// 本地数据库服务
/// 负责管理客户端本地的消息存储
/// Web平台使用内存存储，原生平台使用SQLite
class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  // 内存存储（Web平台和原生平台的后备）
  final Map<String, Message> _messagesCache = {};
  final Map<String, Conversation> _conversationsCache = {};
  final List<Message> _messagesList = [];
  final List<Conversation> _conversationsList = [];

  // ============ 消息操作 ============

  /// 保存消息到本地
  Future<int> saveMessage(Message message) async {
    _messagesCache[message.msgId] = message;
    final index = _messagesList.indexWhere((m) => m.msgId == message.msgId);
    if (index >= 0) {
      _messagesList[index] = message;
    } else {
      _messagesList.add(message);
    }
    return 1;
  }

  /// 批量保存消息
  Future<void> saveMessages(List<Message> messages) async {
    for (final message in messages) {
      await saveMessage(message);
    }
  }

  /// 获取会话消息列表
  Future<List<Message>> getMessages({
    required String conversId,
    int limit = 20,
    DateTime? beforeTime,
  }) async {
    var messages = _messagesList
        .where((m) => m.conversId == conversId)
        .toList();

    if (beforeTime != null) {
      messages = messages
          .where((m) => m.createdAt != null && m.createdAt!.isBefore(beforeTime))
          .toList();
    }

    messages.sort((a, b) => (b.createdAt ?? DateTime.now())
        .compareTo(a.createdAt ?? DateTime.now()));

    return messages.take(limit).toList();
  }

  /// 获取单条消息
  Future<Message?> getMessage(String messageId) async {
    return _messagesCache[messageId];
  }

  /// 更新消息状态
  Future<int> updateMessageStatus(String messageId, int status) async {
    final message = _messagesCache[messageId];
    if (message != null) {
      final updated = Message(
        id: message.id,
        msgId: message.msgId,
        conversId: message.conversId,
        fromUserId: message.fromUserId,
        toUserId: message.toUserId,
        groupId: message.groupId,
        type: message.type,
        content: message.content,
        extra: message.extra,
        status: status,
        replyMsgId: message.replyMsgId,
        atUserIds: message.atUserIds,
        createdAt: message.createdAt,
        isRead: message.isRead,
      );
      _messagesCache[messageId] = updated;
      final index = _messagesList.indexWhere((m) => m.msgId == messageId);
      if (index >= 0) {
        _messagesList[index] = updated;
      }
      return 1;
    }
    return 0;
  }

  /// 标记消息为已读
  Future<int> markMessageAsRead(String messageId) async {
    final message = _messagesCache[messageId];
    if (message != null) {
      final updated = Message(
        id: message.id,
        msgId: message.msgId,
        conversId: message.conversId,
        fromUserId: message.fromUserId,
        toUserId: message.toUserId,
        groupId: message.groupId,
        type: message.type,
        content: message.content,
        extra: message.extra,
        status: message.status,
        replyMsgId: message.replyMsgId,
        atUserIds: message.atUserIds,
        createdAt: message.createdAt,
        isRead: true,
      );
      _messagesCache[messageId] = updated;
      return 1;
    }
    return 0;
  }

  /// 标记会话所有消息为已读
  Future<int> markConversationAsRead(String conversId) async {
    int count = 0;
    for (var i = 0; i < _messagesList.length; i++) {
      final m = _messagesList[i];
      if (m.conversId == conversId && !m.isRead) {
        _messagesList[i] = Message(
          id: m.id,
          msgId: m.msgId,
          conversId: m.conversId,
          fromUserId: m.fromUserId,
          toUserId: m.toUserId,
          groupId: m.groupId,
          type: m.type,
          content: m.content,
          extra: m.extra,
          status: m.status,
          replyMsgId: m.replyMsgId,
          atUserIds: m.atUserIds,
          createdAt: m.createdAt,
          isRead: true,
        );
        _messagesCache[m.msgId] = _messagesList[i];
        count++;
      }
    }
    return count;
  }

  /// 删除消息
  Future<int> deleteMessage(String messageId) async {
    _messagesCache.remove(messageId);
    _messagesList.removeWhere((m) => m.msgId == messageId);
    return 1;
  }

  /// 删除会话所有消息
  Future<int> deleteConversationMessages(String conversId) async {
    final toRemove = _messagesList.where((m) => m.conversId == conversId).toList();
    for (final m in toRemove) {
      _messagesCache.remove(m.msgId);
    }
    _messagesList.removeWhere((m) => m.conversId == conversId);
    return toRemove.length;
  }

  /// 搜索消息
  Future<List<Message>> searchMessages(String keyword, {int limit = 50}) async {
    return _messagesList
        .where((m) => m.content.toLowerCase().contains(keyword.toLowerCase()))
        .take(limit)
        .toList();
  }

  // ============ 会话操作 ============

  /// 保存或更新会话
  Future<int> saveConversation(Conversation conversation) async {
    _conversationsCache[conversation.conversId] = conversation;
    final index = _conversationsList.indexWhere((c) => c.conversId == conversation.conversId);
    if (index >= 0) {
      _conversationsList[index] = conversation;
    } else {
      _conversationsList.add(conversation);
    }
    return 1;
  }

  /// 获取会话列表
  Future<List<Conversation>> getConversations(int userId) async {
    final conversations = _conversationsList
        .where((c) => c.userId == userId || c.userId == null)
        .toList();

    // 按置顶和最后消息时间排序
    // 置顶会话按置顶时间倒序（最近置顶的在前面）
    // 非置顶会话按最后消息时间倒序
    conversations.sort((a, b) {
      if (a.isTop != b.isTop) {
        return a.isTop ? -1 : 1;
      }
      // 两个都置顶时，按置顶时间倒序（最近置顶的在前）
      if (a.isTop && b.isTop) {
        final aTopTime = a.topTime ?? DateTime(1970);
        final bTopTime = b.topTime ?? DateTime(1970);
        return bTopTime.compareTo(aTopTime);
      }
      // 非置顶按最后消息时间倒序
      final aTime = a.lastMsgTime ?? DateTime(1970);
      final bTime = b.lastMsgTime ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    return conversations;
  }

  /// 获取单个会话
  Future<Conversation?> getConversation(String conversId) async {
    return _conversationsCache[conversId];
  }

  /// 更新会话未读数
  Future<int> updateUnreadCount(String conversId, int count) async {
    final conversation = _conversationsCache[conversId];
    if (conversation != null) {
      final updated = conversation.copyWith(unreadCount: count);
      _conversationsCache[conversId] = updated;
      final index = _conversationsList.indexWhere((c) => c.conversId == conversId);
      if (index >= 0) {
        _conversationsList[index] = updated;
      }
      return 1;
    }
    return 0;
  }

  /// 增加会话未读数
  Future<int> incrementUnreadCount(String conversId) async {
    final conversation = _conversationsCache[conversId];
    if (conversation != null) {
      return await updateUnreadCount(conversId, conversation.unreadCount + 1);
    }
    return 0;
  }

  /// 清除会话未读数
  Future<int> clearUnreadCount(String conversId) async {
    return await updateUnreadCount(conversId, 0);
  }

  /// 置顶/取消置顶会话
  Future<int> toggleConversationTop(String conversId, bool isTop) async {
    print('[LocalDatabaseService] toggleConversationTop: conversId=$conversId, isTop=$isTop');
    final conversation = _conversationsCache[conversId];
    if (conversation != null) {
      final updated = isTop
          ? conversation.copyWith(isTop: true, topTime: DateTime.now())
          : conversation.copyWith(isTop: false, clearTopTime: true);
      _conversationsCache[conversId] = updated;
      final index = _conversationsList.indexWhere((c) => c.conversId == conversId);
      if (index >= 0) {
        _conversationsList[index] = updated;
      }
      print('[LocalDatabaseService] toggleConversationTop 成功: isTop=${updated.isTop}, topTime=${updated.topTime}');
      return 1;
    }
    print('[LocalDatabaseService] toggleConversationTop 失败: 会话不存在于缓存中');
    print('[LocalDatabaseService] 当前缓存的会话: ${_conversationsCache.keys.toList()}');
    return 0;
  }

  /// 设置/取消免打扰
  Future<int> toggleConversationMute(String conversId, bool isMute) async {
    final conversation = _conversationsCache[conversId];
    if (conversation != null) {
      final updated = conversation.copyWith(isMute: isMute);
      _conversationsCache[conversId] = updated;
      final index = _conversationsList.indexWhere((c) => c.conversId == conversId);
      if (index >= 0) {
        _conversationsList[index] = updated;
      }
      return 1;
    }
    return 0;
  }

  /// 删除会话
  Future<int> deleteConversation(String conversId) async {
    _conversationsCache.remove(conversId);
    _conversationsList.removeWhere((c) => c.conversId == conversId);
    await deleteConversationMessages(conversId);
    return 1;
  }

  /// 清空所有数据（退出登录时调用）
  Future<void> clearAllData() async {
    _messagesCache.clear();
    _conversationsCache.clear();
    _messagesList.clear();
    _conversationsList.clear();
  }

  /// 关闭数据库
  Future<void> close() async {
    // 内存存储不需要关闭
  }
}
