/// 推送通知服务
/// 统一管理 Firebase Cloud Messaging + 本地通知
/// 支持 Android / iOS 平台，Web 端使用 Service Worker (push-sw.js)

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/services/storage_service.dart';

/// 通知动作 ID 常量
class NotificationActions {
  static const String acceptCall = 'accept_call';
  static const String rejectCall = 'reject_call';
}

/// FCM 后台消息处理（必须是顶级函数）
/// 当 App 在后台或被杀死时，收到 FCM 推送会调用此函数
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('[FCM] Background message: ${message.messageId}, data: ${message.data}');

  // 如果消息包含 notification 字段，系统会自动显示通知，无需额外处理
  // 如果是 data-only 消息，需要手动显示本地通知
  if (message.notification == null && message.data.isNotEmpty) {
    await _showBackgroundNotification(message.data);
  }
}

/// 后台显示本地通知（在 isolate 中运行，不能访问 NotificationService 单例）
Future<void> _showBackgroundNotification(Map<String, dynamic> data) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await plugin.initialize(settings: settings);

    final title = data['title'] as String? ?? 'IM';
    final body = data['body'] as String? ?? '';
    if (body.isEmpty) return;

    // 根据类型选择通知频道
    final type = data['type'] as String? ?? '';
    String channelId = 'im_messages';
    String channelName = '聊天消息';
    Importance importance = Importance.high;
    Priority priority = Priority.high;

    final bool isCall = type == 'incoming_call' || type == 'incoming_group_call';

    if (isCall) {
      channelId = 'im_calls';
      channelName = '来电通知';
      importance = Importance.max;
      priority = Priority.max;
    } else if (type == 'system' || type == 'friend_request' || type == 'group_invite') {
      channelId = 'im_system';
      channelName = '系统通知';
      importance = Importance.defaultImportance;
      priority = Priority.defaultPriority;
    }

    // 来电通知添加接听/拒绝操作按钮
    List<AndroidNotificationAction>? actions;
    if (isCall) {
      actions = [
        const AndroidNotificationAction(
          NotificationActions.rejectCall,
          '拒绝',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          NotificationActions.acceptCall,
          '接听',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ];
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: priority,
      showWhen: true,
      actions: actions,
      fullScreenIntent: isCall,
      ongoing: isCall,
      autoCancel: !isCall,
      category: isCall ? AndroidNotificationCategory.call : AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
    );

    await plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: jsonEncode(data),
    );
  } catch (e) {
    print('[FCM] Background notification display failed: $e');
  }
}

/// Android 通知频道定义
class NotificationChannels {
  /// 聊天消息
  static const AndroidNotificationChannel message = AndroidNotificationChannel(
    'im_messages',
    '聊天消息',
    description: '新消息通知',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// 来电通知
  static const AndroidNotificationChannel call = AndroidNotificationChannel(
    'im_calls',
    '来电通知',
    description: '语音/视频来电',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// 系统通知
  static const AndroidNotificationChannel system = AndroidNotificationChannel(
    'im_system',
    '系统通知',
    description: '好友申请、群邀请等系统消息',
    importance: Importance.defaultImportance,
    playSound: true,
  );
}

/// 推送通知服务
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _fcmToken;
  StreamSubscription? _tokenRefreshSub;
  StreamSubscription? _foregroundMessageSub;

  /// 通知点击事件流
  final _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  /// 来电通知操作事件流（接听/拒绝）
  final _callActionController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onCallAction =>
      _callActionController.stream;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _initialized;

  /// 初始化通知服务
  /// 在用户登录后调用
  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    try {
      // 1. 先初始化本地通知（不依赖 Firebase，确保即使 Firebase 未配置也能显示本地通知）
      await _initLocalNotifications();

      // 2. 创建 Android 通知频道
      await _createNotificationChannels();

      _initialized = true;
      print('[NotificationService] 本地通知初始化完成');
    } catch (e) {
      print('[NotificationService] 本地通知初始化失败: $e');
    }

    // 3. 初始化 Firebase（可选，缺少配置文件时不影响本地通知）
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      _fcm = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);

      // 请求通知权限
      await requestPermission();

      // 获取 FCM Token
      await _getToken();

      // 监听 Token 刷新
      _tokenRefreshSub = _fcm!.onTokenRefresh.listen(_onTokenRefresh);

      // 监听前台消息
      _foregroundMessageSub =
          FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // 监听通知点击（从后台/终止状态打开）
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      // 检查是否通过通知冷启动
      final initialMessage = await _fcm!.getInitialMessage();
      if (initialMessage != null) {
        _onMessageOpenedApp(initialMessage);
      }

      print('[NotificationService] Firebase FCM 初始化完成, token=$_fcmToken');
    } catch (e) {
      // Firebase 未配置时（缺少 google-services.json）会抛异常
      // 本地通知仍然可用，仅 FCM 推送不可用
      print('[NotificationService] Firebase初始化失败（本地通知仍可用）: $e');
    }
  }

  /// 初始化本地通知插件
  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  /// 创建 Android 通知频道
  Future<void> _createNotificationChannels() async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin
          .createNotificationChannel(NotificationChannels.message);
      await androidPlugin.createNotificationChannel(NotificationChannels.call);
      await androidPlugin
          .createNotificationChannel(NotificationChannels.system);
    }
  }

  /// 请求通知权限
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    // Firebase Messaging 权限（同时处理 Android 13+ 和 iOS）
    final settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: false,
      announcement: false,
      carPlay: false,
    );

    final granted = settings.authorizationStatus ==
        AuthorizationStatus.authorized;
    print('[NotificationService] 权限状态: ${settings.authorizationStatus}');
    return granted;
  }

  /// 获取 FCM Token
  Future<void> _getToken() async {
    try {
      _fcmToken = await _fcm!.getToken();
      if (_fcmToken != null) {
        await _uploadTokenToServer(_fcmToken!);
      }
    } catch (e) {
      print('[NotificationService] 获取FCM Token失败: $e');
    }
  }

  /// Token 刷新回调
  void _onTokenRefresh(String newToken) {
    print('[NotificationService] Token刷新: $newToken');
    _fcmToken = newToken;
    _uploadTokenToServer(newToken);
  }

  /// 上传 FCM Token 到服务器
  Future<void> _uploadTokenToServer(String token) async {
    try {
      final deviceType = _getDeviceType();
      final api = ApiClient();
      await api.post('/api/device-token', data: {
        'token': token,
        'device_type': deviceType,
      });
      // 本地缓存
      StorageService().setString('fcm_token', token);
      print('[NotificationService] Token已上传到服务器');
    } catch (e) {
      print('[NotificationService] Token上传失败: $e');
    }
  }

  /// 前台消息处理 — 显示本地通知
  void _onForegroundMessage(RemoteMessage message) {
    print('[NotificationService] 前台消息: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    // 如果消息包含 notification 字段，显示本地通知
    if (notification != null) {
      _showLocalNotification(
        title: notification.title ?? 'IM',
        body: notification.body ?? '',
        payload: jsonEncode(data),
        channelId: _getChannelId(data),
      );
    } else if (data.isNotEmpty) {
      // data-only 消息
      final title = data['title'] as String? ?? 'IM';
      final body = data['body'] as String? ?? '';
      if (body.isNotEmpty) {
        _showLocalNotification(
          title: title,
          body: body,
          payload: jsonEncode(data),
          channelId: _getChannelId(data),
        );
      }
    }
  }

  /// 通知点击（从后台恢复）
  void _onMessageOpenedApp(RemoteMessage message) {
    print('[NotificationService] 通知点击: ${message.data}');
    _notificationTapController.add(message.data);
  }

  /// 本地通知点击/操作回调
  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final actionId = response.actionId;

      // 处理来电操作按钮
      if (actionId == NotificationActions.acceptCall ||
          actionId == NotificationActions.rejectCall) {
        _callActionController.add({
          'action': actionId,
          ...data,
        });
        return;
      }

      // 普通通知点击
      _notificationTapController.add(data);
    } catch (_) {}
  }

  /// 显示本地通知
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'im_messages',
    int? number,
  }) async {
    // 选择频道
    String channelName = '聊天消息';
    String channelDesc = '新消息通知';
    Importance importance = Importance.high;
    final bool isCall = channelId == 'im_calls';

    if (isCall) {
      channelName = '来电通知';
      channelDesc = '语音/视频来电';
      importance = Importance.max;
    } else if (channelId == 'im_system') {
      channelName = '系统通知';
      channelDesc = '系统消息';
      importance = Importance.defaultImportance;
    }

    // 来电通知添加接听/拒绝操作按钮
    List<AndroidNotificationAction>? actions;
    if (isCall) {
      actions = [
        const AndroidNotificationAction(
          NotificationActions.rejectCall,
          '拒绝',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          NotificationActions.acceptCall,
          '接听',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ];
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: importance,
      priority: isCall ? Priority.max : Priority.high,
      showWhen: true,
      actions: actions,
      fullScreenIntent: isCall,
      ongoing: isCall,
      autoCancel: !isCall,
      category: isCall ? AndroidNotificationCategory.call : AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      number: number,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000, // 唯一ID
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// 显示聊天消息通知（供 ChatProvider 在后台时调用）
  /// [unreadCount] 用于在 App 图标上显示未读角标数字
  Future<void> showMessageNotification({
    required String title,
    required String body,
    String? conversId,
    int unreadCount = 0,
  }) async {
    if (kIsWeb || !_initialized) return;
    await _showLocalNotification(
      title: title,
      body: body,
      payload: conversId != null ? '{"convers_id":"$conversId"}' : null,
      channelId: 'im_messages',
      number: unreadCount > 0 ? unreadCount : null,
    );
  }

  /// 来电通知固定 ID（方便后续取消）
  static const int _callNotificationId = 9999;

  /// 显示来电系统通知（带接听/拒绝按钮，供 HomeScreen 在后台时调用）
  Future<void> showIncomingCallNotification({
    required String callId,
    required int callerId,
    required String callerName,
    required String callerAvatar,
    required int callType,
  }) async {
    if (kIsWeb || !_initialized) return;
    final isVideo = callType == 2;
    final typeLabel = isVideo ? '视频通话' : '语音通话';

    final payload = jsonEncode({
      'type': 'incoming_call',
      'call_id': callId,
      'caller_id': callerId,
      'caller_name': callerName,
      'caller_avatar': callerAvatar,
      'call_type': callType,
    });

    const actions = [
      AndroidNotificationAction(
        NotificationActions.rejectCall,
        '拒绝',
        showsUserInterface: false,
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        NotificationActions.acceptCall,
        '接听',
        showsUserInterface: true,
        cancelNotification: true,
      ),
    ];

    final androidDetails = AndroidNotificationDetails(
      'im_calls',
      '来电通知',
      channelDescription: '语音/视频来电',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      actions: actions,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      timeoutAfter: 60000, // 60秒后自动消失
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: _callNotificationId,
      title: callerName,
      body: '邀请你$typeLabel',
      notificationDetails: details,
      payload: payload,
    );
  }

  /// 取消来电通知（通话结束/取消时调用）
  Future<void> cancelCallNotification() async {
    await _localNotifications.cancel(id: _callNotificationId);
  }

  /// 根据消息数据选择通知频道
  String _getChannelId(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    if (type == 'incoming_call' || type == 'incoming_group_call') {
      return 'im_calls';
    }
    if (type == 'system' ||
        type == 'friend_request' ||
        type == 'group_invite') {
      return 'im_system';
    }
    return 'im_messages';
  }

  /// 获取设备类型
  String _getDeviceType() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// 注销（登出时调用）
  Future<void> logout() async {
    if (!_initialized) return;

    // 删除服务端的 token
    if (_fcmToken != null) {
      try {
        final api = ApiClient();
        await api.delete('/api/device-token', data: {
          'token': _fcmToken,
        });
      } catch (_) {}
    }

    // 删除本地缓存
    StorageService().remove('fcm_token');
    _fcmToken = null;
  }

  /// 释放资源
  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundMessageSub?.cancel();
    _notificationTapController.close();
    _callActionController.close();
    _initialized = false;
  }
}
