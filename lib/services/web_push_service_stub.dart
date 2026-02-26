/// Stub implementation for non-web platforms
/// This file provides mock implementations when not running on web

bool isWebPushSupported() => false;

Future<String> requestNotificationPermission() async => 'denied';

Future<String> getNotificationPermissionStatus() async => 'denied';

Future<Map<String, dynamic>?> subscribeToPush(String vapidPublicKey) async => null;

Future<bool> unsubscribeFromPush() async => false;

Future<Map<String, dynamic>?> getExistingSubscription() async => null;

void listenForSwMessages(Function(Map<String, dynamic>) callback) {}

void sendMessageToSw(Map<String, dynamic> message) {}
