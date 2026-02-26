/// 收藏API
/// 消息收藏相关接口

import 'dart:convert';
import 'package:im_client/api/api_client.dart';

class FavoriteApi {
  final ApiClient _client;

  FavoriteApi(this._client);

  /// 添加收藏
  /// [messageId] 消息ID
  /// [contentType] 消息类型
  /// [content] 消息内容
  /// [fromUserId] 发送者ID
  /// [tags] 标签（可选）
  /// [note] 备注（可选）
  Future<ApiResponse> addFavorite({
    required String messageId,
    required int contentType,
    required String content,
    int? fromUserId,
    String? tags,
    String? note,
  }) {
    return _client.post('/message/favorite', data: {
      'message_id': messageId,
      'content_type': contentType,
      'content': content,
      if (fromUserId != null) 'from_user_id': fromUserId,
      if (tags != null) 'tags': tags,
      if (note != null) 'note': note,
    });
  }

  /// 获取收藏列表
  /// [page] 页码
  /// [pageSize] 每页数量
  /// [contentType] 内容类型筛选（可选）
  /// [keyword] 关键词搜索（可选）
  Future<ApiResponse> getFavorites({
    int page = 1,
    int pageSize = 20,
    int? contentType,
    String? keyword,
  }) {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (contentType != null) {
      params['content_type'] = contentType.toString();
    }
    if (keyword != null && keyword.isNotEmpty) {
      params['keyword'] = keyword;
    }
    return _client.get('/message/favorites', queryParameters: params);
  }

  /// 删除收藏
  Future<ApiResponse> deleteFavorite(int id) {
    return _client.delete('/message/favorite/$id');
  }
}

/// 收藏项模型
class FavoriteItem {
  final int id;
  final int userId;
  final String messageId;
  final int contentType;
  final String content;
  final String? extra;
  final String? tags;
  final String? note;
  final DateTime createdAt;

  // 从extra解析的数据
  final FavoriteExtraInfo? extraInfo;

  FavoriteItem({
    required this.id,
    required this.userId,
    required this.messageId,
    required this.contentType,
    required this.content,
    this.extra,
    this.tags,
    this.note,
    required this.createdAt,
    this.extraInfo,
  });

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    FavoriteExtraInfo? extraInfo;
    if (json['extra'] != null && json['extra'].toString().isNotEmpty) {
      try {
        dynamic extraData = json['extra'];
        // 如果是字符串，先解析为JSON
        if (extraData is String) {
          extraData = jsonDecode(extraData);
        }
        if (extraData is Map<String, dynamic>) {
          extraInfo = FavoriteExtraInfo.fromJson(extraData);
        }
      } catch (e) {
        // 解析extra失败，忽略
      }
    }

    return FavoriteItem(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      messageId: json['message_id'] ?? '',
      contentType: json['content_type'] ?? 1,
      content: json['content'] ?? '',
      extra: json['extra']?.toString(),
      tags: json['tags'],
      note: json['note'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      extraInfo: extraInfo,
    );
  }

  /// 获取内容类型名称
  String get contentTypeName {
    switch (contentType) {
      case 1:
        return '文本';
      case 2:
        return '图片';
      case 3:
        return '语音';
      case 4:
        return '视频';
      case 5:
        return '文件';
      case 6:
        return '位置';
      case 7:
        return '名片';
      case 8:
        return '聊天记录';
      default:
        return '消息';
    }
  }
}

/// 收藏额外信息
class FavoriteExtraInfo {
  final int? chatType;
  final int? groupId;
  final FavoriteFromUser? fromUser;

  FavoriteExtraInfo({
    this.chatType,
    this.groupId,
    this.fromUser,
  });

  factory FavoriteExtraInfo.fromJson(Map<String, dynamic> json) {
    return FavoriteExtraInfo(
      chatType: json['chat_type'],
      groupId: json['group_id'],
      fromUser: json['from_user'] != null
          ? FavoriteFromUser.fromJson(json['from_user'])
          : null,
    );
  }
}

/// 收藏消息发送者信息
class FavoriteFromUser {
  final int id;
  final String? nickname;
  final String? avatar;

  FavoriteFromUser({
    required this.id,
    this.nickname,
    this.avatar,
  });

  factory FavoriteFromUser.fromJson(Map<String, dynamic> json) {
    return FavoriteFromUser(
      id: json['id'] ?? json['ID'] ?? 0,
      nickname: json['nickname'] ?? json['Nickname'],
      avatar: json['avatar'] ?? json['Avatar'],
    );
  }
}
