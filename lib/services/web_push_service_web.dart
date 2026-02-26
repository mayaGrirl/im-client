/// Web-specific implementation for Web Push Service
/// Uses dart:html and dart:js_util for browser APIs

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Check if Web Push is supported
bool isWebPushSupported() {
  try {
    return js_util.hasProperty(html.window.navigator, 'serviceWorker') &&
           js_util.hasProperty(html.window, 'PushManager');
  } catch (e) {
    return false;
  }
}

/// Request notification permission
Future<String> requestNotificationPermission() async {
  try {
    final permission = await html.Notification.requestPermission();
    return permission;
  } catch (e) {
    debugPrint('[WebPushWeb] Permission error: $e');
    return 'denied';
  }
}

/// Get current notification permission status (without requesting)
Future<String> getNotificationPermissionStatus() async {
  try {
    // Access Notification.permission directly
    final permission = html.Notification.permission;
    return permission ?? 'default';
  } catch (e) {
    debugPrint('[WebPushWeb] Get permission status error: $e');
    return 'default';
  }
}

/// Subscribe to push notifications
Future<Map<String, dynamic>?> subscribeToPush(String vapidPublicKey) async {
  try {
    final registration = await html.window.navigator.serviceWorker?.ready;
    if (registration == null) {
      debugPrint('[WebPushWeb] No service worker registration');
      return null;
    }

    // Convert VAPID key to Uint8List
    final applicationServerKey = _urlBase64ToUint8Array(vapidPublicKey);

    // Get push manager
    final pushManager = js_util.getProperty(registration, 'pushManager');
    if (pushManager == null) {
      debugPrint('[WebPushWeb] No push manager');
      return null;
    }

    // Subscribe with options
    final options = js_util.jsify({
      'userVisibleOnly': true,
      'applicationServerKey': applicationServerKey,
    });

    final subscriptionPromise = js_util.callMethod(pushManager, 'subscribe', [options]);
    final subscription = await js_util.promiseToFuture(subscriptionPromise);

    if (subscription == null) {
      debugPrint('[WebPushWeb] Failed to subscribe');
      return null;
    }

    // Extract subscription data
    final endpoint = js_util.getProperty(subscription, 'endpoint') as String?;
    final keysObj = js_util.callMethod(subscription, 'toJSON', []);
    final keys = js_util.getProperty(keysObj, 'keys');

    return {
      'endpoint': endpoint,
      'keys': {
        'p256dh': keys != null ? js_util.getProperty(keys, 'p256dh') : null,
        'auth': keys != null ? js_util.getProperty(keys, 'auth') : null,
      },
    };
  } catch (e) {
    debugPrint('[WebPushWeb] Subscribe error: $e');
    return null;
  }
}

/// Unsubscribe from push notifications
Future<bool> unsubscribeFromPush() async {
  try {
    final registration = await html.window.navigator.serviceWorker?.ready;
    if (registration == null) return false;

    final pushManager = js_util.getProperty(registration, 'pushManager');
    if (pushManager == null) return false;

    final subscriptionPromise = js_util.callMethod(pushManager, 'getSubscription', []);
    final subscription = await js_util.promiseToFuture(subscriptionPromise);

    if (subscription != null) {
      final unsubPromise = js_util.callMethod(subscription, 'unsubscribe', []);
      final result = await js_util.promiseToFuture(unsubPromise);
      return result == true;
    }
    return true;
  } catch (e) {
    debugPrint('[WebPushWeb] Unsubscribe error: $e');
    return false;
  }
}

/// Get existing subscription
Future<Map<String, dynamic>?> getExistingSubscription() async {
  try {
    final registration = await html.window.navigator.serviceWorker?.ready;
    if (registration == null) return null;

    final pushManager = js_util.getProperty(registration, 'pushManager');
    if (pushManager == null) return null;

    final subscriptionPromise = js_util.callMethod(pushManager, 'getSubscription', []);
    final subscription = await js_util.promiseToFuture(subscriptionPromise);

    if (subscription == null) return null;

    final endpoint = js_util.getProperty(subscription, 'endpoint') as String?;
    final keysObj = js_util.callMethod(subscription, 'toJSON', []);
    final keys = js_util.getProperty(keysObj, 'keys');

    return {
      'endpoint': endpoint,
      'keys': {
        'p256dh': keys != null ? js_util.getProperty(keys, 'p256dh') : null,
        'auth': keys != null ? js_util.getProperty(keys, 'auth') : null,
      },
    };
  } catch (e) {
    debugPrint('[WebPushWeb] Get subscription error: $e');
    return null;
  }
}

/// Listen for messages from Service Worker
void listenForSwMessages(Function(Map<String, dynamic>) callback) {
  html.window.addEventListener('push_sw_message', (event) {
    try {
      final customEvent = event as html.CustomEvent;
      final detail = customEvent.detail;
      if (detail != null) {
        final data = _jsObjectToMap(detail);
        callback(data);
      }
    } catch (e) {
      debugPrint('[WebPushWeb] SW message error: $e');
    }
  });
}

/// Send message to Service Worker
void sendMessageToSw(Map<String, dynamic> message) {
  try {
    final controller = html.window.navigator.serviceWorker?.controller;
    if (controller != null) {
      controller.postMessage(js_util.jsify(message));
    }
  } catch (e) {
    debugPrint('[WebPushWeb] Send to SW error: $e');
  }
}

/// Convert URL-safe base64 to Uint8Array
Uint8List _urlBase64ToUint8Array(String base64String) {
  // Add padding if necessary
  var padding = '=' * ((4 - base64String.length % 4) % 4);
  var base64 = base64String.replaceAll('-', '+').replaceAll('_', '/') + padding;
  var rawData = base64Decode(base64);
  return rawData;
}

/// Convert JS object to Dart Map
Map<String, dynamic> _jsObjectToMap(dynamic jsObject) {
  if (jsObject == null) return {};

  try {
    final jsonStr = js_util.callMethod(html.window, 'JSON.stringify', [jsObject]);
    return jsonDecode(jsonStr as String) as Map<String, dynamic>;
  } catch (e) {
    // Fallback: manual conversion
    final result = <String, dynamic>{};
    final keys = js_util.callMethod(js_util.getProperty(html.window, 'Object'), 'keys', [jsObject]) as List;
    for (final key in keys) {
      result[key as String] = js_util.getProperty(jsObject, key);
    }
    return result;
  }
}
