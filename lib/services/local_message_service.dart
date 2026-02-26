/// 本地消息存储服务
/// 使用 Hive 存储消息到客户端本地
import 'package:hive_flutter/hive_flutter.dart';
import 'package:im_client/models/message.dart';

class LocalMessageService {
  static final LocalMessageService _instance = LocalMessageService._internal();
  factory LocalMessageService() => _instance;
  LocalMessageService._internal();

  static const String _messagesBoxName = 'messages';
  static const String _conversationsBoxName = 'conversations';

  Box<Map>? _messagesBox;
  Box<Map>? _conversationsBox;
  bool _initialized = false;

  /// 深度转换 Map，确保所有嵌套的 Map 都是 Map<String, dynamic>
  /// Hive 存储的数据是 LinkedHashMap<dynamic, dynamic>，需要递归转换
  Map<String, dynamic> _deepConvertMap(Map data) {
    return data.map((key, value) {
      final stringKey = key.toString();
      if (value is Map) {
        return MapEntry(stringKey, _deepConvertMap(value));
      } else if (value is List) {
        return MapEntry(stringKey, _deepConvertList(value));
      }
      return MapEntry(stringKey, value);
    });
  }

  /// 深度转换 List，处理列表中的 Map 元素
  List<dynamic> _deepConvertList(List data) {
    return data.map((item) {
      if (item is Map) {
        return _deepConvertMap(item);
      } else if (item is List) {
        return _deepConvertList(item);
      }
      return item;
    }).toList();
  }

  /// 初始化本地存储
  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();
    _messagesBox = await Hive.openBox<Map>(_messagesBoxName);
    _conversationsBox = await Hive.openBox<Map>(_conversationsBoxName);
    _initialized = true;
  }

  /// 保存消息到本地
  Future<void> saveMessage(Message message) async {
    if (_messagesBox == null) await init();

    final key = '${message.conversId}_${message.msgId}';
    await _messagesBox!.put(key, message.toJson());

    // 更新会话的最后消息
    await _updateConversationLastMessage(message);
  }

  /// 批量保存消息
  Future<void> saveMessages(List<Message> messages) async {
    if (_messagesBox == null) await init();

    final Map<String, Map<String, dynamic>> entries = {};
    for (final message in messages) {
      final key = '${message.conversId}_${message.msgId}';
      entries[key] = message.toJson();
    }
    await _messagesBox!.putAll(entries);
  }

  /// 获取会话的消息列表
  Future<List<Message>> getMessages(String conversId, {int limit = 50, String? beforeMsgId}) async {
    if (_messagesBox == null) await init();

    final prefix = '${conversId}_';
    final messages = <Message>[];

    // 获取所有该会话的消息
    for (final key in _messagesBox!.keys) {
      if (key.toString().startsWith(prefix)) {
        final data = _messagesBox!.get(key);
        if (data != null) {
          messages.add(Message.fromJson(_deepConvertMap(data)));
        }
      }
    }

    // 按时间倒序排序
    messages.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.now();
      final bTime = b.createdAt ?? DateTime.now();
      return bTime.compareTo(aTime);
    });

    // 如果指定了 beforeMsgId，从该消息之后开始取
    if (beforeMsgId != null) {
      final index = messages.indexWhere((m) => m.msgId == beforeMsgId);
      if (index >= 0) {
        return messages.skip(index + 1).take(limit).toList();
      }
    }

    return messages.take(limit).toList();
  }

  /// 获取单条消息
  Future<Message?> getMessage(String conversId, String msgId) async {
    if (_messagesBox == null) await init();

    final key = '${conversId}_$msgId';
    final data = _messagesBox!.get(key);
    if (data != null) {
      return Message.fromJson(_deepConvertMap(data));
    }
    return null;
  }

  /// 获取目标消息周围的消息列表（用于定位到特定消息）
  /// 返回目标消息前后各 count 条消息
  Future<List<Message>> getMessagesAroundTarget(String conversId, String targetMsgId, {int count = 20}) async {
    if (_messagesBox == null) await init();

    final prefix = '${conversId}_';
    final allMessages = <Message>[];

    // 获取所有该会话的消息
    for (final key in _messagesBox!.keys) {
      if (key.toString().startsWith(prefix)) {
        final data = _messagesBox!.get(key);
        if (data != null) {
          allMessages.add(Message.fromJson(_deepConvertMap(data)));
        }
      }
    }

    // 按时间倒序排序（新消息在前）
    allMessages.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.now();
      final bTime = b.createdAt ?? DateTime.now();
      return bTime.compareTo(aTime);
    });

    // 找到目标消息的位置
    final targetIndex = allMessages.indexWhere((m) => m.msgId == targetMsgId);
    if (targetIndex < 0) {
      // 如果找不到目标消息，返回最新的消息
      return allMessages.take(count).toList();
    }

    // 获取目标消息前后的消息
    final startIndex = (targetIndex - count ~/ 2).clamp(0, allMessages.length);
    final endIndex = (startIndex + count).clamp(0, allMessages.length);

    return allMessages.sublist(startIndex, endIndex);
  }

  /// 删除单条消息
  Future<void> deleteMessage(String conversId, String msgId) async {
    if (_messagesBox == null) await init();

    final key = '${conversId}_$msgId';
    await _messagesBox!.delete(key);
  }

  /// 删除多条消息
  Future<void> deleteMessages(List<String> msgIds, String conversId) async {
    if (_messagesBox == null) await init();

    for (final msgId in msgIds) {
      final key = '${conversId}_$msgId';
      await _messagesBox!.delete(key);
    }
  }

  /// 清空会话的所有消息（只清空本地）
  Future<void> clearConversationMessages(String conversId) async {
    if (_messagesBox == null) await init();

    final prefix = '${conversId}_';
    final keysToDelete = <dynamic>[];

    for (final key in _messagesBox!.keys) {
      if (key.toString().startsWith(prefix)) {
        keysToDelete.add(key);
      }
    }

    await _messagesBox!.deleteAll(keysToDelete);
  }

  /// 更新消息状态
  Future<void> updateMessageStatus(String conversId, String msgId, int status) async {
    if (_messagesBox == null) await init();

    final key = '${conversId}_$msgId';
    final data = _messagesBox!.get(key);
    if (data != null) {
      final map = _deepConvertMap(data);
      map['status'] = status;
      await _messagesBox!.put(key, map);
    }
  }

  /// 保存会话信息
  Future<void> saveConversation(Conversation conversation) async {
    if (_conversationsBox == null) await init();
    await _conversationsBox!.put(conversation.conversId, conversation.toJson());
  }

  /// 获取所有会话
  Future<List<Conversation>> getConversations() async {
    if (_conversationsBox == null) await init();

    final conversations = <Conversation>[];
    for (final data in _conversationsBox!.values) {
      conversations.add(Conversation.fromJson(_deepConvertMap(data)));
    }

    // 按置顶和时间排序
    // 置顶会话按置顶时间倒序（最近置顶的在前面）
    // 非置顶会话按最后消息时间倒序
    conversations.sort((a, b) {
      if (a.isTop && !b.isTop) return -1;
      if (!a.isTop && b.isTop) return 1;
      // 两个都置顶时，按置顶时间倒序（最近置顶的在前）
      if (a.isTop && b.isTop) {
        final aTopTime = a.topTime ?? DateTime(1970);
        final bTopTime = b.topTime ?? DateTime(1970);
        return bTopTime.compareTo(aTopTime);
      }
      // 非置顶按最后消息时间倒序
      final aTime = a.lastMsgTime ?? DateTime(2000);
      final bTime = b.lastMsgTime ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    return conversations;
  }

  /// 获取单个会话
  Future<Conversation?> getConversation(String conversId) async {
    if (_conversationsBox == null) await init();

    final data = _conversationsBox!.get(conversId);
    if (data != null) {
      return Conversation.fromJson(_deepConvertMap(data));
    }
    return null;
  }

  /// 置顶/取消置顶会话
  Future<void> toggleConversationTop(String conversId, bool isTop) async {
    if (_conversationsBox == null) await init();

    final data = _conversationsBox!.get(conversId);
    if (data != null) {
      final conversation = Conversation.fromJson(_deepConvertMap(data));
      final updated = isTop
          ? conversation.copyWith(isTop: true, topTime: DateTime.now())
          : conversation.copyWith(isTop: false, clearTopTime: true);
      await _conversationsBox!.put(conversId, updated.toJson());
    }
  }

  /// 设置会话免打扰
  Future<void> setConversationMute(String conversId, bool isMute) async {
    if (_conversationsBox == null) await init();

    final data = _conversationsBox!.get(conversId);
    if (data != null) {
      final conversation = Conversation.fromJson(_deepConvertMap(data));
      final updated = conversation.copyWith(isMute: isMute);
      await _conversationsBox!.put(conversId, updated.toJson());
    }
  }

  /// 删除会话（包括所有消息）
  Future<void> deleteConversation(String conversId) async {
    if (_conversationsBox == null) await init();

    // 删除会话记录
    await _conversationsBox!.delete(conversId);

    // 删除会话的所有消息
    await clearConversationMessages(conversId);
  }

  /// 更新会话未读数
  Future<void> updateUnreadCount(String conversId, int count) async {
    if (_conversationsBox == null) await init();

    final data = _conversationsBox!.get(conversId);
    if (data != null) {
      final map = _deepConvertMap(data);
      map['unread_count'] = count;
      await _conversationsBox!.put(conversId, map);
    }
  }

  /// 增加会话未读数
  Future<void> incrementUnreadCount(String conversId) async {
    if (_conversationsBox == null) await init();

    final data = _conversationsBox!.get(conversId);
    if (data != null) {
      final map = _deepConvertMap(data);
      map['unread_count'] = (map['unread_count'] ?? 0) + 1;
      await _conversationsBox!.put(conversId, map);
    }
  }

  /// 清空会话未读数
  Future<void> clearUnreadCount(String conversId) async {
    await updateUnreadCount(conversId, 0);
  }

  /// 更新会话最后消息
  Future<void> _updateConversationLastMessage(Message message) async {
    if (_conversationsBox == null) await init();

    final conversId = message.conversId;
    if (conversId == null) return;

    var data = _conversationsBox!.get(conversId);
    Map<String, dynamic> map;

    if (data != null) {
      map = _deepConvertMap(data);
    } else {
      // 创建新会话
      map = {
        'convers_id': conversId,
        'type': message.groupId != null && message.groupId! > 0 ? 2 : 1,
        'target_id': message.groupId ?? message.toUserId ?? message.fromUserId,
        'unread_count': 0,
        'is_top': false,
        'is_mute': false,
      };
    }

    // 更新最后消息信息
    map['last_msg_id'] = message.msgId;
    map['last_msg_time'] = message.createdAt?.toIso8601String();
    map['last_msg_preview'] = _getMessagePreview(message);

    await _conversationsBox!.put(conversId, map);
  }

  /// 获取消息预览文本
  String _getMessagePreview(Message message) {
    switch (message.type) {
      case 1:
        final content = message.content;
        return content.length > 30 ? '${content.substring(0, 30)}...' : content;
      case 2:
        return '[图片]';
      case 3:
        return '[语音]';
      case 4:
        return '[视频]';
      case 5:
        return '[文件]';
      case 6:
        return '[位置]';
      case 7:
        return '[名片]';
      case 8:
        return '[合并转发]';
      case 9:
        return '[通话]';
      case 11:
        return '[红包]';
      case 13:
        return '[视频]';
      case 14:
        return '[直播]';
      default:
        return '[消息]';
    }
  }

  /// 清空所有本地数据
  Future<void> clearAll() async {
    if (_messagesBox == null) await init();
    await _messagesBox!.clear();
    await _conversationsBox!.clear();
  }

  /// 获取会话消息数量
  Future<int> getMessageCount(String conversId) async {
    if (_messagesBox == null) await init();

    final prefix = '${conversId}_';
    int count = 0;
    for (final key in _messagesBox!.keys) {
      if (key.toString().startsWith(prefix)) {
        count++;
      }
    }
    return count;
  }

  // ============ 新增功能 ============

  /// 搜索消息
  /// 在本地存储中搜索包含关键词的消息
  Future<List<Message>> searchMessages(String keyword, {String? conversId, int limit = 50}) async {
    if (_messagesBox == null) await init();
    if (keyword.isEmpty) return [];

    final lowerKeyword = keyword.toLowerCase();
    final messages = <Message>[];

    for (final key in _messagesBox!.keys) {
      // 如果指定了会话ID，只搜索该会话
      if (conversId != null && !key.toString().startsWith('${conversId}_')) {
        continue;
      }

      final data = _messagesBox!.get(key);
      if (data != null) {
        final map = _deepConvertMap(data);
        final content = (map['content'] as String?)?.toLowerCase() ?? '';
        if (content.contains(lowerKeyword)) {
          messages.add(Message.fromJson(map));
        }
      }

      // 限制结果数量
      if (messages.length >= limit) break;
    }

    // 按时间倒序排序
    messages.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.now();
      final bTime = b.createdAt ?? DateTime.now();
      return bTime.compareTo(aTime);
    });

    return messages;
  }

  /// 获取最后同步的消息ID
  Future<String?> getLastSyncMsgId(String conversId) async {
    if (_conversationsBox == null) await init();

    final data = _conversationsBox!.get(conversId);
    if (data != null) {
      final map = _deepConvertMap(data);
      return map['last_sync_msg_id'] as String?;
    }
    return null;
  }

  /// 设置最后同步的消息ID
  Future<void> setLastSyncMsgId(String conversId, String msgId) async {
    if (_conversationsBox == null) await init();

    var data = _conversationsBox!.get(conversId);
    Map<String, dynamic> map;

    if (data != null) {
      map = _deepConvertMap(data);
    } else {
      map = {'convers_id': conversId};
    }

    map['last_sync_msg_id'] = msgId;
    await _conversationsBox!.put(conversId, map);
  }

  /// 导出消息（用于备份）
  /// 返回包含所有消息和会话的JSON数据
  Future<Map<String, dynamic>> exportMessages() async {
    if (_messagesBox == null) await init();

    final messages = <Map<String, dynamic>>[];
    final conversations = <Map<String, dynamic>>[];

    // 导出所有消息
    for (final key in _messagesBox!.keys) {
      final data = _messagesBox!.get(key);
      if (data != null) {
        messages.add(_deepConvertMap(data));
      }
    }

    // 导出所有会话
    for (final key in _conversationsBox!.keys) {
      final data = _conversationsBox!.get(key);
      if (data != null) {
        conversations.add(_deepConvertMap(data));
      }
    }

    return {
      'version': 1,
      'export_time': DateTime.now().toIso8601String(),
      'messages': messages,
      'conversations': conversations,
    };
  }

  /// 导入消息（用于恢复）
  /// 从备份数据恢复消息和会话
  Future<int> importMessages(Map<String, dynamic> exportData) async {
    if (_messagesBox == null) await init();

    int importedCount = 0;

    // 导入消息
    final messages = exportData['messages'] as List<dynamic>?;
    if (messages != null) {
      for (final msgData in messages) {
        final map = _deepConvertMap(msgData as Map);
        final conversId = map['convers_id'] as String?;
        final msgId = map['msg_id'] as String?;
        if (conversId != null && msgId != null) {
          final key = '${conversId}_$msgId';
          await _messagesBox!.put(key, map);
          importedCount++;
        }
      }
    }

    // 导入会话
    final conversations = exportData['conversations'] as List<dynamic>?;
    if (conversations != null) {
      for (final convData in conversations) {
        final map = _deepConvertMap(convData as Map);
        final conversId = map['convers_id'] as String?;
        if (conversId != null) {
          await _conversationsBox!.put(conversId, map);
        }
      }
    }

    return importedCount;
  }

  /// 获取指定会话的所有消息（用于导出单个会话）
  Future<List<Map<String, dynamic>>> getConversationMessagesRaw(String conversId) async {
    if (_messagesBox == null) await init();

    final prefix = '${conversId}_';
    final messages = <Map<String, dynamic>>[];

    for (final key in _messagesBox!.keys) {
      if (key.toString().startsWith(prefix)) {
        final data = _messagesBox!.get(key);
        if (data != null) {
          messages.add(_deepConvertMap(data));
        }
      }
    }

    return messages;
  }

  /// 根据消息ID获取消息（不需要conversId）
  Future<Message?> getMessageById(String msgId) async {
    if (_messagesBox == null) await init();

    for (final key in _messagesBox!.keys) {
      if (key.toString().endsWith('_$msgId')) {
        final data = _messagesBox!.get(key);
        if (data != null) {
          return Message.fromJson(_deepConvertMap(data));
        }
      }
    }
    return null;
  }

  /// 获取消息上下文（前后N条消息）
  Future<Map<String, List<Message>>> getMessageContext(String conversId, String msgId, {int before = 5, int after = 5}) async {
    if (_messagesBox == null) await init();

    // 获取所有该会话的消息
    final allMessages = await getMessages(conversId, limit: 10000);

    // 找到目标消息的位置
    final targetIndex = allMessages.indexWhere((m) => m.msgId == msgId);
    if (targetIndex < 0) {
      return {'before': [], 'after': []};
    }

    // 获取前面的消息（因为列表是倒序的，所以前面的消息在后面的索引）
    final beforeMessages = <Message>[];
    for (int i = targetIndex + 1; i < targetIndex + 1 + before && i < allMessages.length; i++) {
      beforeMessages.add(allMessages[i]);
    }

    // 获取后面的消息
    final afterMessages = <Message>[];
    for (int i = targetIndex - 1; i >= 0 && i > targetIndex - 1 - after; i--) {
      afterMessages.add(allMessages[i]);
    }

    return {
      'before': beforeMessages.reversed.toList(),
      'after': afterMessages,
    };
  }
}
