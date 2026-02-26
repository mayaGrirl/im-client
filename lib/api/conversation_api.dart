/// 会话相关API
import 'api_client.dart';
import '../models/message.dart';

class ConversationApi {
  final ApiClient _client;

  ConversationApi(this._client);

  /// 获取会话列表
  Future<List<Conversation>> getConversationList() async {
    final response = await _client.get('/conversation/list');
    if (response.success && response.data != null) {
      final list = response.data as List;
      return list.map((json) => Conversation.fromJson(json)).toList();
    }
    return [];
  }

  /// 获取聊天记录
  Future<List<Message>> getMessageHistory({
    String? conversId,
    int? toUserId,
    int? groupId,
    String? beforeMsgId,
    DateTime? beforeTime,
    int limit = 20,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'page_size': limit > 0 ? limit : pageSize,
    };
    if (conversId != null) params['convers_id'] = conversId;
    if (toUserId != null) params['to_user_id'] = toUserId;
    if (groupId != null) params['group_id'] = groupId;
    if (beforeMsgId != null) params['before_msg_id'] = beforeMsgId;
    if (beforeTime != null) params['before_time'] = beforeTime.toIso8601String();

    final response = await _client.get('/message/history', queryParameters: params);
    if (response.success && response.data != null) {
      if (response.data is List) {
        final list = response.data as List;
        return list.map((json) => Message.fromJson(json)).toList();
      } else if (response.data is Map && response.data['list'] != null) {
        final list = response.data['list'] as List;
        return list.map((json) => Message.fromJson(json)).toList();
      }
    }
    return [];
  }

  /// 发送消息
  Future<ApiResult> sendMessage({
    required String msgId,
    String? conversId,
    int? toUserId,
    int? groupId,
    required int type,
    required String content,
    String? extra,
    String? replyMsgId,
    List<int>? atUserIds,
  }) async {
    final data = <String, dynamic>{
      'msg_id': msgId,
      'type': type,
      'content': content,
    };
    if (toUserId != null && toUserId > 0) data['to_user_id'] = toUserId;
    if (groupId != null && groupId > 0) data['group_id'] = groupId;
    if (extra != null) data['extra'] = extra;
    if (replyMsgId != null) data['reply_to'] = replyMsgId;
    if (atUserIds != null) data['at_user_ids'] = atUserIds;

    final response = await _client.post('/message/send', data: data);
    return response.toResult();
  }

  /// 撤回消息
  /// [msgId] 消息ID
  /// [toUserId] 私聊时的接收者ID
  /// [groupId] 群聊时的群组ID
  Future<bool> recallMessage(String msgId, {int? toUserId, int? groupId}) async {
    final params = <String, dynamic>{};
    if (toUserId != null) params['to_user_id'] = toUserId.toString();
    if (groupId != null) params['group_id'] = groupId.toString();

    final response = await _client.post(
      '/message/recall/$msgId',
      queryParameters: params,
    );
    return response.success;
  }

  /// 删除消息
  /// [msgIds] 要删除的消息ID列表
  Future<bool> deleteMessages(List<String> msgIds) async {
    final response = await _client.post('/message/delete', data: {
      'msg_ids': msgIds,
    });
    return response.success;
  }

  /// 清空会话消息
  /// [conversId] 会话ID
  /// [clearBoth] 是否清空双方的消息（服务端删除），false则只清空自己的
  Future<bool> clearConversation(String conversId, {bool clearBoth = false}) async {
    final response = await _client.post('/message/clear', data: {
      'convers_id': conversId,
      'clear_both': clearBoth,
    });
    return response.success;
  }

  /// 删除会话
  Future<bool> deleteConversation(String conversId) async {
    final response = await _client.delete('/conversation/$conversId');
    return response.success;
  }

  /// 设置会话免打扰
  Future<bool> setConversationMute(String conversId, bool mute) async {
    final response = await _client.put('/conversation/$conversId/mute', data: {
      'mute': mute,
    });
    return response.success;
  }

  /// 设置会话置顶
  Future<bool> setConversationTop(String conversId, bool top) async {
    final response = await _client.put('/conversation/$conversId/top', data: {
      'top': top,
    });
    return response.success;
  }

  /// 标记会话已读（清除服务端未读数）
  Future<bool> markConversationRead(String conversId) async {
    final response = await _client.post('/message/read/conversation/$conversId');
    return response.success;
  }

  /// 转发消息
  /// [messages] 要转发的消息列表（包含完整内容）
  /// [toUserIds] 转发目标用户ID列表
  /// [groupIds] 转发目标群组ID列表
  /// [forwardType] 转发类型: 1=逐条转发 2=合并转发
  /// [title] 合并转发的标题（仅合并转发时有效）
  Future<ApiResult> forwardMessages({
    required List<Message> messages,
    List<int>? toUserIds,
    List<int>? groupIds,
    required int forwardType,
    String? title,
  }) async {
    // 将消息转换为服务端需要的格式（包含完整内容）
    final messageData = messages.map((m) => {
      'msg_id': m.msgId,
      'from_user_id': m.fromUserId,
      'type': m.type,
      'content': m.content,
      'created_at': m.createdAt?.toIso8601String(),
      'from_user': m.fromUser != null ? {
        'id': m.fromUser!.id,
        'nickname': m.fromUser!.nickname,
        'avatar': m.fromUser!.avatar,
      } : null,
    }).toList();

    final response = await _client.post('/message/forward', data: {
      'messages': messageData,
      'to_user_ids': toUserIds ?? [],
      'group_ids': groupIds ?? [],
      'forward_type': forwardType,
      'title': title ?? '',
    });
    return response.toResult();
  }
}
