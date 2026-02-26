/// WebSocket服务
/// 处理实时消息连接和通信

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/utils/crypto_utils.dart';
import 'package:im_client/services/device_info_service.dart';

/// WebSocket服务单例
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 30;
  static const Duration _pingInterval = Duration(seconds: 30);

  String? _token;

  /// 是否已手动断开（避免手动 disconnect 后仍触发自动重连）
  bool _manuallyDisconnected = false;
  
  /// 是否正在主动退出登录（避免退出时收到 force_logout 提示）
  bool _isLoggingOut = false;

  /// 消息流控制器
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  /// 连接状态流控制器
  final _connectionController = StreamController<bool>.broadcast();

  /// 强制登出流控制器（收到 force_logout 时触发，通知上层执行登出）
  final _forceLogoutController = StreamController<String>.broadcast();

  /// 消息流
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// 连接状态流
  Stream<bool> get connectionStream => _connectionController.stream;

  /// 强制登出流（reason）
  Stream<String> get forceLogoutStream => _forceLogoutController.stream;

  /// 是否已连接
  bool get isConnected => _isConnected;

  /// 获取重连延迟（指数退避：3s, 3s, 6s, 12s, 最大30s）
  Duration _getReconnectDelay() {
    if (_reconnectAttempts <= 1) return const Duration(seconds: 3);
    final seconds = 3 * (1 << (_reconnectAttempts - 1));
    return Duration(seconds: seconds > 30 ? 30 : seconds);
  }

  /// 连接WebSocket
  Future<void> connect(String token) async {
    // 允许用新 token 强制重连
    if (_isConnecting) return;
    if (_isConnected && _token == token) return;

    // 如果已有旧连接，先清理
    await _closeExistingConnection();

    _token = token;
    _isConnecting = true;
    _manuallyDisconnected = false;

    try {
      // 获取细分设备类型和设备唯一ID
      final deviceInfo = await DeviceInfoService().getDeviceInfo();
      final deviceType = deviceInfo.deviceType;
      final deviceId = deviceInfo.deviceId;
      final wsUrl = '${EnvConfig.instance.wsUrl}?token=$token&device=$deviceType&device_id=$deviceId';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // 监听消息
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _connectionController.add(true);

      // 启动心跳
      _startPing();

      print('WebSocket连接成功');
    } catch (e) {
      _isConnecting = false;
      print('WebSocket连接失败: $e');
      _scheduleReconnect();
    }
  }

  /// 清理旧连接资源
  Future<void> _closeExistingConnection() async {
    _pingTimer?.cancel();
    try {
      await _subscription?.cancel();
    } catch (_) {}
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
  }

  /// 断开连接
  /// [isLogout] 是否为主动退出登录（true时不触发 force_logout 提示）
  void disconnect({bool isLogout = false}) {
    if (isLogout) {
      _isLoggingOut = true;
    }
    _manuallyDisconnected = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;

    _isConnected = false;
    _isConnecting = false;
    _reconnectAttempts = 0;
    _connectionController.add(false);

    print('WebSocket已断开');
    
    // 延迟重置退出标志，确保不会收到退出过程中的 force_logout
    if (isLogout) {
      Future.delayed(const Duration(seconds: 2), () {
        _isLoggingOut = false;
      });
    }
  }

  /// 发送消息
  void send(Map<String, dynamic> data) {
    if (!_isConnected || _channel == null) {
      print('WebSocket未连接，无法发送消息');
      return;
    }

    try {
      Map<String, dynamic> payload = data;
      if (CryptoUtils.isInitialized) {
        payload = CryptoUtils.encryptJson(data);
      }
      _channel!.sink.add(jsonEncode(payload));
    } catch (e) {
      print('发送消息失败: $e');
    }
  }

  /// 发送聊天消息
  void sendChatMessage({
    required int toUserId,
    int groupId = 0,
    required int type,
    required String content,
    String? extra,
    List<int>? atUsers,
  }) {
    send({
      'type': 'chat',
      'to_user_id': toUserId,
      'group_id': groupId,
      'data': {
        'type': type,
        'content': content,
        if (extra != null) 'extra': extra,
        if (atUsers != null) 'at_users': atUsers,
      },
    });
  }

  /// 发送已读回执
  void sendReadReceipt(String msgId, int toUserId) {
    send({
      'type': 'read',
      'to_user_id': toUserId,
      'data': {'msg_id': msgId},
    });
  }

  /// 发送正在输入状态
  void sendTyping(int toUserId) {
    send({
      'type': 'typing',
      'to_user_id': toUserId,
      'data': {},
    });
  }

  /// 处理接收到的消息
  void _onMessage(dynamic data) {
    try {
      final rawData = data as String;
      print('[WebSocketService._onMessage] 收到原始数据: $rawData');

      // 服务端可能批量发送多条消息，用换行符分隔
      final parts = rawData.split('\n');
      print('[WebSocketService._onMessage] 分割后消息数量: ${parts.length}');

      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;

        try {
          var message = jsonDecode(trimmed) as Map<String, dynamic>;
          // Decrypt if encrypted
          if (CryptoUtils.isInitialized && message.containsKey('_e')) {
            final decrypted = CryptoUtils.tryDecryptJson(message);
            if (decrypted != null) {
              message = decrypted;
            }
          }
          final type = message['type'];
          final fromUserId = message['from_user_id'];
          final toUserId = message['to_user_id'];
          print('[WebSocketService._onMessage] 解析成功: type=$type, from=$fromUserId, to=$toUserId');

          // 拦截 force_logout：阻止自动重连并通知上层登出
          if (type == 'force_logout') {
            // 如果是主动退出登录过程中收到的，忽略提示
            if (_isLoggingOut) {
              print('[WebSocketService] 主动退出登录中，忽略 force_logout 消息');
              _manuallyDisconnected = true;
              _reconnectTimer?.cancel();
              return;
            }
            
            // 提取 kick_type 和 reason
            final data = message['data'] is Map ? message['data'] : {};
            final kickType = data['kick_type'] ?? 'other_device';
            final reason = data['reason'] ?? '您的账号在其他设备登录';
            
            // 根据 kick_type 生成不同的提示消息
            String displayMessage;
            switch (kickType) {
              case 'other_device':
                displayMessage = '您的账号在其他设备登录';
                break;
              case 'admin_kick':
                displayMessage = '您的设备已被管理员登出';
                break;
              case 'token_expired':
                displayMessage = '登录已过期，请重新登录';
                break;
              case 'user_logout':
                // 主动退出不应该收到这个消息，但以防万一
                displayMessage = '您已退出登录';
                break;
              default:
                displayMessage = reason.toString();
            }
            
            print('[WebSocketService] 收到 force_logout: type=$kickType, message=$displayMessage');
            _manuallyDisconnected = true; // 阻止自动重连
            _reconnectTimer?.cancel();
            _forceLogoutController.add(displayMessage);
            return; // 不再传递给普通消息流
          }

          // 特别记录通话和信令相关消息
          if (type == 'call' || type == 'signal') {
            final data = message['data'];
            if (type == 'call') {
              final action = data is Map ? data['action'] : null;
              print('[WebSocketService] 广播通话消息: action=$action, callId=${data is Map ? data['call_id'] : null}');
            } else {
              final signalType = data is Map ? data['signal_type'] : null;
              print('[WebSocketService] 广播信令消息: signalType=$signalType, callId=${data is Map ? data['call_id'] : null}');
            }
          }

          _messageController.add(message);
          print('[WebSocketService._onMessage] 已添加到messageController');
        } catch (e) {
          print('[WebSocketService._onMessage] 解析单条消息失败: $e, 内容: $trimmed');
        }
      }
    } catch (e) {
      print('[WebSocketService._onMessage] 解析消息失败: $e');
    }
  }

  /// 处理错误
  void _onError(dynamic error) {
    print('WebSocket错误: $error');
    _handleDisconnect();
  }

  /// 处理连接关闭
  void _onDone() {
    print('WebSocket连接关闭');
    _handleDisconnect();
  }

  /// 处理断开连接
  void _handleDisconnect() {
    _pingTimer?.cancel();
    _isConnected = false;
    _isConnecting = false;
    _connectionController.add(false);
    if (!_manuallyDisconnected) {
      _scheduleReconnect();
    }
  }

  /// 安排重连（指数退避）
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('WebSocket重连次数已达上限($_maxReconnectAttempts)，停止重连');
      return;
    }

    if (_token == null) {
      print('无Token，无法重连');
      return;
    }

    _reconnectTimer?.cancel();
    final delay = _getReconnectDelay();
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      print('WebSocket尝试第$_reconnectAttempts次重连（延迟${delay.inSeconds}s）...');
      connect(_token!);
    });
  }

  /// 启动心跳
  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_isConnected) {
        send({'type': 'ping'});
      }
    });
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
    _forceLogoutController.close();
  }
}

/// WebSocket消息类型
class WsMessageType {
  static const String chat = 'chat';
  static const String read = 'read';
  static const String typing = 'typing';
  static const String online = 'online';
  static const String offline = 'offline';
  static const String notification = 'notification';
  static const String call = 'call';
  static const String signal = 'signal';
  static const String recall = 'recall';
  static const String forceLogout = 'force_logout';
}
