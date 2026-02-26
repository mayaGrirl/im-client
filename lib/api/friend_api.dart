/// 好友相关API
import 'api_client.dart';
import '../models/user.dart';

class FriendApi {
  final ApiClient _client;

  FriendApi(this._client);

  /// 获取好友列表
  Future<List<Friend>> getFriendList() async {
    final response = await _client.get('/friend/list');
    if (response.success && response.data != null) {
      final list = response.data as List;
      return list.map((json) => Friend.fromJson(json)).toList();
    }
    return [];
  }

  /// 获取好友统计（数量和上限）
  Future<FriendStats?> getFriendStats() async {
    final response = await _client.get('/friend/stats');
    if (response.success && response.data != null) {
      return FriendStats.fromJson(response.data);
    }
    return null;
  }

  /// 搜索用户
  Future<List<User>> searchUsers(String keyword) async {
    final response = await _client.get('/user/search', queryParameters: {'keyword': keyword});
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
      return list.map((json) => User.fromJson(json)).toList();
    }
    return [];
  }

  /// 发送好友申请
  Future<ApiResult> addFriend({
    required int userId,
    String? message,
    String? source,
  }) async {
    final response = await _client.post('/friend/add', data: {
      'friend_id': userId,
      'message': message,
      'source': source,
    });
    return response.toResult();
  }

  /// 获取好友申请列表
  Future<List<FriendRequest>> getFriendRequests() async {
    final response = await _client.get('/friend/requests');
    if (response.success && response.data != null) {
      final list = response.data as List;
      return list.map((json) => FriendRequest.fromJson(json)).toList();
    }
    return [];
  }

  /// 处理好友申请
  Future<ApiResult> handleFriendRequest({
    required int requestId,
    required int action, // 1: 同意, 2: 拒绝
  }) async {
    final response = await _client.post('/friend/handle', data: {
      'request_id': requestId,
      'action': action,
    });
    return response.toResult();
  }

  /// 删除好友
  Future<ApiResult> deleteFriend(int friendId) async {
    final response = await _client.delete('/friend/$friendId');
    return response.toResult();
  }

  /// 更新好友备注
  Future<ApiResult> updateRemark(
    int friendId, {
    String? remark,
    String? remarkPhone,
    String? remarkEmail,
    String? remarkTags,
    String? remarkDesc,
  }) async {
    final response = await _client.put('/friend/$friendId/remark', data: {
      'remark': remark ?? '',
      'remark_phone': remarkPhone ?? '',
      'remark_email': remarkEmail ?? '',
      'remark_tags': remarkTags ?? '',
      'remark_desc': remarkDesc ?? '',
    });
    return response.toResult();
  }

  /// 根据好友ID获取好友信息
  Future<Friend?> getFriendById(int friendId) async {
    final friends = await getFriendList();
    try {
      return friends.firstWhere((f) => f.friendId == friendId);
    } catch (e) {
      return null;
    }
  }

  /// 获取黑名单
  Future<List<User>> getBlacklist() async {
    final response = await _client.get('/friend/blacklist');
    if (response.success && response.data != null) {
      final list = response.data as List;
      return list.map((json) => User.fromJson(json)).toList();
    }
    return [];
  }

  /// 添加黑名单
  Future<ApiResult> addToBlacklist(int userId) async {
    final response = await _client.post('/friend/blacklist', data: {
      'blocked_id': userId,
    });
    return response.toResult();
  }

  /// 移除黑名单
  Future<ApiResult> removeFromBlacklist(int userId) async {
    final response = await _client.delete('/friend/blacklist/$userId');
    return response.toResult();
  }

  /// 获取好友分组
  Future<List<FriendGroup>> getFriendGroups() async {
    final response = await _client.get('/friend/groups');
    if (response.success && response.data != null) {
      final list = response.data as List;
      return list.map((json) => FriendGroup.fromJson(json)).toList();
    }
    return [];
  }

  /// 创建好友分组
  Future<ApiResult> createFriendGroup(String name) async {
    final response = await _client.post('/friend/groups', data: {'name': name});
    return response.toResult();
  }

  /// 更新好友分组
  Future<ApiResult> updateFriendGroup(int groupId, String name) async {
    final response = await _client.put('/friend/groups/$groupId', data: {'name': name});
    return response.toResult();
  }

  /// 删除好友分组
  Future<ApiResult> deleteFriendGroup(int groupId) async {
    final response = await _client.delete('/friend/groups/$groupId');
    return response.toResult();
  }

  /// 移动好友到分组
  Future<ApiResult> moveFriendToGroup(int friendId, int? groupId) async {
    final response = await _client.put('/friend/$friendId/group', data: {'group_id': groupId ?? 0});
    return response.toResult();
  }
}

/// 好友分组模型
class FriendGroup {
  final int id;
  final int userId;
  final String name;
  final int sortOrder;
  final int friendCount;

  FriendGroup({
    required this.id,
    required this.userId,
    required this.name,
    this.sortOrder = 0,
    this.friendCount = 0,
  });

  factory FriendGroup.fromJson(Map<String, dynamic> json) {
    return FriendGroup(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      friendCount: json['friend_count'] ?? 0,
    );
  }
}
