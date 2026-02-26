/// 会话ID工具类
/// 统一管理会话ID的生成和解析

class ConversationUtils {
  /// 生成会话ID
  /// 私聊格式: p_小ID_大ID
  /// 群聊格式: g_群ID
  static String generateConversId({
    int? userId1,
    int? userId2,
    int? groupId,
  }) {
    if (groupId != null && groupId > 0) {
      // 群聊会话
      return 'g_$groupId';
    } else if (userId1 != null && userId2 != null) {
      // 私聊会话：确保ID顺序一致
      final ids = [userId1, userId2]..sort();
      return 'p_${ids[0]}_${ids[1]}';
    }
    throw ArgumentError('必须提供 groupId 或 (userId1 和 userId2)');
  }

  /// 解析会话ID
  /// 返回会话信息 Map:
  /// - type: 1=私聊, 2=群聊
  /// - userId1: 私聊用户ID1 (较小的)
  /// - userId2: 私聊用户ID2 (较大的)
  /// - groupId: 群聊群组ID
  static Map<String, dynamic> parseConversId(String conversId) {
    if (conversId.startsWith('g_')) {
      // 群聊
      final groupId = int.tryParse(conversId.substring(2));
      return {
        'type': 2,
        'groupId': groupId,
        'userId1': null,
        'userId2': null,
      };
    } else if (conversId.startsWith('p_')) {
      // 私聊
      final parts = conversId.substring(2).split('_');
      if (parts.length == 2) {
        final userId1 = int.tryParse(parts[0]);
        final userId2 = int.tryParse(parts[1]);
        return {
          'type': 1,
          'groupId': null,
          'userId1': userId1,
          'userId2': userId2,
        };
      }
    }

    // 无法解析
    return {
      'type': 0,
      'groupId': null,
      'userId1': null,
      'userId2': null,
    };
  }

  /// 获取私聊对方的用户ID
  /// 传入会话ID和当前用户ID，返回对方的用户ID
  /// 如果是群聊或无法解析，返回 null
  static int? getTargetUserId(String conversId, int currentUserId) {
    final parsed = parseConversId(conversId);

    if (parsed['type'] == 1) {
      // 私聊
      final userId1 = parsed['userId1'] as int?;
      final userId2 = parsed['userId2'] as int?;

      if (userId1 == currentUserId) {
        return userId2;
      } else if (userId2 == currentUserId) {
        return userId1;
      }
    }

    return null;
  }

  /// 判断是否是群聊会话
  static bool isGroupConversation(String conversId) {
    return conversId.startsWith('g_');
  }

  /// 判断是否是私聊会话
  static bool isPrivateConversation(String conversId) {
    return conversId.startsWith('p_');
  }

  /// 从群聊会话ID获取群组ID
  static int? getGroupId(String conversId) {
    if (conversId.startsWith('g_')) {
      return int.tryParse(conversId.substring(2));
    }
    return null;
  }

  /// 判断用户是否是会话参与者
  static bool isParticipant(String conversId, int userId) {
    final parsed = parseConversId(conversId);

    if (parsed['type'] == 1) {
      // 私聊
      return parsed['userId1'] == userId || parsed['userId2'] == userId;
    }

    // 群聊需要额外检查群成员，这里只返回格式是否正确
    return parsed['type'] == 2;
  }

  /// 获取会话显示名称的前缀
  /// 私聊返回 "私聊"，群聊返回 "群聊"
  static String getConversationTypeLabel(String conversId) {
    if (isGroupConversation(conversId)) {
      return '群聊';
    } else if (isPrivateConversation(conversId)) {
      return '私聊';
    }
    return '未知';
  }
}
