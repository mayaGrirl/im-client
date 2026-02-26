// Web Push Notification Service
// Handles push notification subscriptions and incoming push messages for Web platform

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:im_client/api/api_client.dart';

// Conditional import for web-specific code
import 'web_push_service_stub.dart'
    if (dart.library.html) 'web_push_service_web.dart' as platform;

/// 通知权限状态
enum NotificationPermissionStatus {
  granted,   // 已授权
  denied,    // 已拒绝
  notDetermined, // 未决定（默认状态）
  unsupported,   // 不支持
}

/// Web Push Service - manages push subscriptions and notifications
class WebPushService {
  static final WebPushService _instance = WebPushService._internal();
  factory WebPushService() => _instance;
  WebPushService._internal();

  final ApiClient _apiClient = ApiClient();
  bool _initialized = false;
  bool _permissionGranted = false;
  String? _subscriptionEndpoint;

  // Callbacks
  Function(String callId, int callerId, String callerName, String callerAvatar, int callType)?
      onIncomingCallNotification;
  Function(int callId, int groupId, String groupName, int initiatorId, String initiatorName, String initiatorAvatar, int callType)?
      onIncomingGroupCallNotification;
  Function(String action, Map<String, dynamic> data)? onNotificationClick;

  /// Check if Web Push is supported
  bool get isSupported => kIsWeb && platform.isWebPushSupported();

  /// Check if permission is granted
  bool get isPermissionGranted => _permissionGranted;

  /// Check if subscribed
  bool get isSubscribed => _subscriptionEndpoint != null;

  /// Get current notification permission status
  Future<NotificationPermissionStatus> getPermissionStatus() async {
    if (!kIsWeb) return NotificationPermissionStatus.unsupported;
    if (!platform.isWebPushSupported()) return NotificationPermissionStatus.unsupported;

    try {
      final status = await platform.getNotificationPermissionStatus();
      switch (status) {
        case 'granted':
          _permissionGranted = true;
          return NotificationPermissionStatus.granted;
        case 'denied':
          return NotificationPermissionStatus.denied;
        default:
          return NotificationPermissionStatus.notDetermined;
      }
    } catch (e) {
      debugPrint('[WebPushService] Get permission status failed: $e');
      return NotificationPermissionStatus.unsupported;
    }
  }

  /// Initialize the service
  Future<void> initialize() async {
    if (!kIsWeb || _initialized) return;

    try {
      // Check if Web Push is supported
      if (!platform.isWebPushSupported()) {
        debugPrint('[WebPushService] Web Push not supported');
        return;
      }

      // Listen for Service Worker messages
      platform.listenForSwMessages(_handleSwMessage);

      _initialized = true;
      debugPrint('[WebPushService] Initialized');
    } catch (e) {
      debugPrint('[WebPushService] Initialization failed: $e');
    }
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    if (!kIsWeb) return false;

    try {
      final permission = await platform.requestNotificationPermission();
      _permissionGranted = permission == 'granted';
      debugPrint('[WebPushService] Permission: $permission');
      return _permissionGranted;
    } catch (e) {
      debugPrint('[WebPushService] Request permission failed: $e');
      return false;
    }
  }

  /// Subscribe to push notifications
  /// Returns the subscription endpoint if successful
  Future<String?> subscribe(String vapidPublicKey) async {
    if (!kIsWeb || !_permissionGranted) {
      debugPrint('[WebPushService] Cannot subscribe: not web or permission not granted');
      return null;
    }

    try {
      final subscription = await platform.subscribeToPush(vapidPublicKey);
      if (subscription != null) {
        _subscriptionEndpoint = subscription['endpoint'];
        debugPrint('[WebPushService] Subscribed: $_subscriptionEndpoint');

        // Send subscription to server
        await _sendSubscriptionToServer(subscription);
        return _subscriptionEndpoint;
      }
    } catch (e) {
      debugPrint('[WebPushService] Subscribe failed: $e');
    }
    return null;
  }

  /// Unsubscribe from push notifications
  Future<bool> unsubscribe() async {
    if (!kIsWeb) return false;

    try {
      final success = await platform.unsubscribeFromPush();
      if (success) {
        // Notify server to remove subscription
        await _removeSubscriptionFromServer();
        _subscriptionEndpoint = null;
        debugPrint('[WebPushService] Unsubscribed');
      }
      return success;
    } catch (e) {
      debugPrint('[WebPushService] Unsubscribe failed: $e');
      return false;
    }
  }

  /// Get current subscription status
  Future<Map<String, dynamic>?> getSubscription() async {
    if (!kIsWeb) return null;
    return await platform.getExistingSubscription();
  }

  /// Cancel call notification (close the notification in SW)
  void cancelCallNotification(String callId) {
    if (!kIsWeb) return;
    platform.sendMessageToSw({
      'type': 'cancel_call_notification',
      'callId': callId,
    });
  }

  /// Cancel group call notification (close the notification in SW)
  void cancelGroupCallNotification(int callId) {
    if (!kIsWeb) return;
    platform.sendMessageToSw({
      'type': 'cancel_group_call_notification',
      'callId': callId,
    });
  }

  /// Handle messages from Service Worker
  void _handleSwMessage(Map<String, dynamic> message) {
    debugPrint('[WebPushService] SW message: $message');

    final type = message['type'] as String?;
    final data = message['data'] as Map<String, dynamic>? ?? {};

    switch (type) {
      case 'notification_click':
        final action = message['action'] as String? ?? '';
        onNotificationClick?.call(action, data);

        // Handle incoming call notification click (private call)
        if (data['type'] == 'incoming_call') {
          final callId = data['callId'] as String?;
          final callerId = data['callerId'] as int?;
          final callerName = data['callerName'] as String? ?? '';
          final callerAvatar = data['callerAvatar'] as String? ?? '';
          final callType = data['callType'] as int? ?? 0;

          if (callId != null && callerId != null) {
            onIncomingCallNotification?.call(
              callId, callerId, callerName, callerAvatar, callType
            );
          }
        }

        // Handle incoming group call notification click
        if (data['type'] == 'incoming_group_call') {
          final callId = data['callId'] as int?;
          final groupId = data['groupId'] as int?;
          final groupName = data['groupName'] as String? ?? '';
          final initiatorId = data['initiatorId'] as int?;
          final initiatorName = data['initiatorName'] as String? ?? '';
          final initiatorAvatar = data['initiatorAvatar'] as String? ?? '';
          final callType = data['callType'] as int? ?? 1;

          if (callId != null && groupId != null && initiatorId != null) {
            onIncomingGroupCallNotification?.call(
              callId, groupId, groupName, initiatorId, initiatorName, initiatorAvatar, callType
            );
          }
        }
        break;
      case 'notification_dismissed':
        // User dismissed the notification without action
        debugPrint('[WebPushService] Notification dismissed');
        break;
    }
  }

  /// Send subscription to server
  Future<void> _sendSubscriptionToServer(Map<String, dynamic> subscription) async {
    try {
      await _apiClient.post('/user/push-subscription', data: {
        'platform': 'web',
        'endpoint': subscription['endpoint'],
        'p256dh': subscription['keys']?['p256dh'],
        'auth': subscription['keys']?['auth'],
      });
      debugPrint('[WebPushService] Subscription sent to server');
    } catch (e) {
      debugPrint('[WebPushService] Failed to send subscription to server: $e');
    }
  }

  /// Remove subscription from server
  Future<void> _removeSubscriptionFromServer() async {
    try {
      await _apiClient.delete('/user/push-subscription');
      debugPrint('[WebPushService] Subscription removed from server');
    } catch (e) {
      debugPrint('[WebPushService] Failed to remove subscription from server: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    onIncomingCallNotification = null;
    onIncomingGroupCallNotification = null;
    onNotificationClick = null;
    _initialized = false;
  }
}
