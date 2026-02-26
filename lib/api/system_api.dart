import 'api_client.dart';
import '../models/system.dart';

/// 系统相关API
class SystemApi {
  final ApiClient _client;

  SystemApi([ApiClient? client]) : _client = client ?? ApiClient();

  /// 获取系统通知列表
  Future<List<SystemNotification>> getNotifications({
    int page = 1,
    int pageSize = 20,
    int isRead = 0, // 0全部 1未读 2已读
  }) async {
    final res = await _client.get('/system/notifications', queryParameters: {
      'page': page,
      'page_size': pageSize,
      'is_read': isRead,
    });
    if (res.success && res.data != null) {
      final list = res.data['list'] as List? ?? [];
      return list.map((e) => SystemNotification.fromJson(e)).toList();
    }
    return [];
  }

  /// 获取未读通知数量
  Future<int> getUnreadCount() async {
    final res = await _client.get('/system/notifications/unread-count');
    if (res.success && res.data != null) {
      return res.data['count'] ?? 0;
    }
    return 0;
  }

  /// 标记通知为已读
  Future<bool> markAsRead(int notificationId) async {
    final res = await _client.put('/system/notifications/$notificationId/read');
    return res.success;
  }

  /// 标记所有通知为已读
  Future<bool> markAllAsRead() async {
    final res = await _client.put('/system/notifications/read-all');
    return res.success;
  }

  /// 删除通知
  Future<bool> deleteNotification(int notificationId) async {
    final res = await _client.delete('/system/notifications/$notificationId');
    return res.success;
  }

  /// 清空所有通知
  Future<bool> clearAllNotifications() async {
    final res = await _client.delete('/system/notifications/clear');
    return res.success;
  }

  /// 获取客服列表
  Future<List<CustomerService>> getCustomerServices() async {
    print('[SystemApi] 获取客服列表...');
    final res = await _client.get('/system/customer-services');
    print('[SystemApi] 客服列表响应: success=${res.success}, data=${res.data}');
    if (res.success && res.data != null) {
      final list = res.data as List? ?? [];
      print('[SystemApi] 解析到 ${list.length} 个客服');
      return list.map((e) => CustomerService.fromJson(e)).toList();
    }
    return [];
  }

  /// 获取客服常见问题列表
  Future<List<CustomerServiceFAQ>> getCustomerServiceFAQs() async {
    print('[SystemApi] 获取FAQ列表...');
    final res = await _client.get('/system/customer-service-faqs');
    print('[SystemApi] FAQ响应: success=${res.success}, data=${res.data}');
    if (res.success && res.data != null) {
      final list = res.data as List? ?? [];
      print('[SystemApi] 解析到 ${list.length} 个FAQ');
      return list.map((e) => CustomerServiceFAQ.fromJson(e)).toList();
    }
    return [];
  }

  /// 点击FAQ（增加点击计数）
  Future<void> clickFAQ(int faqId) async {
    await _client.post('/system/customer-service-faqs/$faqId/click');
  }

  /// 获取所有公开配置
  Future<Map<String, dynamic>> getPublicConfig() async {
    final res = await _client.get('/config');
    if (res.success && res.data != null) {
      return Map<String, dynamic>.from(res.data);
    }
    return {};
  }

  /// 获取功能开关
  Future<Map<String, bool>> getFeatures() async {
    final res = await _client.get('/config/features');
    if (res.success && res.data != null) {
      final map = Map<String, dynamic>.from(res.data);
      return map.map((k, v) => MapEntry(k, v == true || v == 'true'));
    }
    return {};
  }

  /// 获取分组配置
  Future<Map<String, dynamic>> getConfigByGroup(String group) async {
    final res = await _client.get('/config/$group');
    if (res.success && res.data != null) {
      return Map<String, dynamic>.from(res.data);
    }
    return {};
  }

  /// 检查更新
  Future<Map<String, dynamic>> checkUpdate(String platform, String currentVersion) async {
    final res = await _client.get('/config/check-update', queryParameters: {
      'platform': platform,
      'version': currentVersion,
    });
    if (res.success && res.data != null) {
      return Map<String, dynamic>.from(res.data);
    }
    return {};
  }

  /// 获取所有标签
  Future<List<FriendTag>> getAllTags() async {
    final res = await _client.get('/tags');
    if (res.success && res.data != null) {
      final list = res.data as List? ?? [];
      return list.map((e) => FriendTag.fromJson(e)).toList();
    }
    return [];
  }
}
