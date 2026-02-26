/// 认证状态管理
/// 管理用户登录状态、Token、用户信息等

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/auth_api.dart';
import 'package:im_client/models/user.dart';
import 'package:im_client/services/storage_service.dart';
import 'package:im_client/services/websocket_service.dart';
import 'package:im_client/services/webrtc_service.dart';

/// 认证状态
enum AuthStatus {
  initial, // 初始状态
  authenticated, // 已认证
  unauthenticated, // 未认证
  loading, // 加载中
}

/// 认证Provider
class AuthProvider with ChangeNotifier {
  final AuthApi _authApi = AuthApi();
  final StorageService _storage = StorageService();
  final ApiClient _apiClient = ApiClient();
  final WebSocketService _wsService = WebSocketService();

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _token;
  String? _error;
  StreamSubscription<String>? _forceLogoutSubscription;
  /// 被踢出时的提示原因（供 UI 弹窗显示）
  String? _forceLogoutReason;

  /// 强制登出前的清理回调（用于清理直播推流等资源）
  Future<void> Function()? _onBeforeLogout;

  /// 获取认证状态
  AuthStatus get status => _status;

  /// 获取当前用户
  User? get user => _user;

  /// 获取Token
  String? get token => _token;

  /// 获取错误信息
  String? get error => _error;

  /// 是否已登录
  bool get isLoggedIn => _status == AuthStatus.authenticated && _user != null;

  /// 获取用户ID
  int get userId => _user?.id ?? 0;

  /// 获取被踢出原因（非null时表示刚被踢出，UI应弹窗提示后清除）
  String? get forceLogoutReason => _forceLogoutReason;

  /// 清除被踢出原因（UI 弹窗展示后调用）
  void clearForceLogoutReason() {
    _forceLogoutReason = null;
  }

  /// 注册强制登出前的清理回调（用于清理直播推流等资源）
  void registerLogoutCallback(Future<void> Function()? callback) {
    _onBeforeLogout = callback;
  }

  /// 初始化，检查登录状态
  Future<void> init() async {
    _status = AuthStatus.loading;
    // 不在此处 notifyListeners()，因为 init() 可能在 build 期间被调用
    // 状态变更将在 async 操作完成后统一通知

    // 注册 Token 过期回调，刷新失败时自动登出回到登录页
    _apiClient.onAuthExpired = _handleAuthExpired;

    // 初始化设备信息（用于全局 X-Device-Type / X-Device-ID 头部）
    await _apiClient.initDeviceInfo();

    // 监听 force_logout（其他设备登录导致当前设备被踢出）
    _forceLogoutSubscription?.cancel();
    _forceLogoutSubscription = _wsService.forceLogoutStream.listen((reason) async {
      debugPrint('[AuthProvider] 收到 force_logout: $reason');
      _forceLogoutReason = reason;
      try {
        await _localLogout();
      } catch (e) {
        debugPrint('[AuthProvider] _localLogout 异常: $e');
        // 确保即使异常也能回到登录页
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      }
    });

    try {
      // 从本地存储获取Token
      _token = await _storage.getToken();

      if (_token != null) {
        // 设置API客户端Token
        _apiClient.setToken(_token);

        // 尝试获取用户信息
        _user = await _storage.getUserInfo();

        if (_user != null) {
          _status = AuthStatus.authenticated;
          // 注意: WebSocket连接移到ChatProvider.init()中
          // 以确保ChatProvider先订阅消息流再连接WebSocket
        } else {
          // Token存在但用户信息不存在，需要重新登录
          _status = AuthStatus.unauthenticated;
          await _storage.clearLoginData();
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _error = e.toString();
    }

    notifyListeners();
  }

  /// 登录
  /// [countryCode] 国家区号（手机号登录时使用）
  Future<bool> login(String username, String password, {String? countryCode}) async {
    // 不改变status为loading，避免触发AuthWrapper重建导致页面闪烁
    // 登录页面有自己的loading状态显示
    _error = null;
    notifyListeners();

    try {
      final result = await _authApi.login(
        username: username,
        password: password,
        countryCode: countryCode,
      );

      if (result.success && result.token != null && result.user != null) {
        _token = result.token;
        _user = result.user;
        _status = AuthStatus.authenticated;

        // 保存到本地
        await _storage.setToken(_token!);
        await _storage.setUserId(_user!.id);
        await _storage.setUserInfo(_user!);

        // 设置API客户端Token
        _apiClient.setToken(_token);

        // 注意: WebSocket连接移到ChatProvider.init()中

        notifyListeners();
        return true;
      } else {
        _error = result.message ?? '登录失败';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = '登录异常: $e';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// 验证码登录
  /// [countryCode] 国家区号（手机号登录时使用）
  Future<bool> loginByCode(String target, String code, {String? countryCode}) async {
    // 不改变status为loading，避免触发AuthWrapper重建导致页面闪烁
    _error = null;
    notifyListeners();

    try {
      final result = await _authApi.loginByCode(
        target: target,
        code: code,
        countryCode: countryCode,
      );

      if (result.success && result.token != null && result.user != null) {
        _token = result.token;
        _user = result.user;
        _status = AuthStatus.authenticated;

        // 保存到本地
        await _storage.setToken(_token!);
        await _storage.setUserId(_user!.id);
        await _storage.setUserInfo(_user!);

        // 设置API客户端Token
        _apiClient.setToken(_token);

        // 注意: WebSocket连接移到ChatProvider.init()中

        notifyListeners();
        return true;
      } else {
        _error = result.message ?? '登录失败';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = '登录异常: $e';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// 发送验证码
  /// [target] 邮箱或手机号
  /// [type] 类型: 1注册 2登录 3绑定 4找回密码
  /// [countryCode] 国家区号（手机号时使用）
  Future<SendCodeResult> sendVerifyCode(String target, int type, {String? countryCode}) async {
    try {
      final result = await _authApi.sendVerifyCode(
        target: target,
        type: type,
        countryCode: countryCode,
      );
      return result;
    } catch (e) {
      return SendCodeResult(
        success: false,
        message: '发送验证码异常: $e',
      );
    }
  }

  /// 重置密码
  /// [countryCode] 国家区号（手机号时使用）
  Future<bool> resetPassword(String target, String code, String newPassword, {String? countryCode}) async {
    try {
      final success = await _authApi.resetPassword(
        target: target,
        code: code,
        newPassword: newPassword,
        countryCode: countryCode,
      );
      if (!success) {
        _error = '重置密码失败';
      }
      return success;
    } catch (e) {
      _error = '重置密码异常: $e';
      return false;
    }
  }

  /// 注册
  /// [countryCode] 国家区号（手机号时使用）
  Future<bool> register({
    required String username,
    required String password,
    String? nickname,
    String? email,
    String? phone,
    String? countryCode,
    String? inviteCode,
  }) async {
    // 不改变status为loading，避免触发AuthWrapper重建导致页面闪烁
    _error = null;
    notifyListeners();

    try {
      final result = await _authApi.register(
        username: username,
        password: password,
        nickname: nickname,
        email: email,
        phone: phone,
        countryCode: countryCode,
        inviteCode: inviteCode,
      );

      if (result.success && result.token != null && result.user != null) {
        _token = result.token;
        _user = result.user;
        _status = AuthStatus.authenticated;

        // 保存到本地
        await _storage.setToken(_token!);
        await _storage.setUserId(_user!.id);
        await _storage.setUserInfo(_user!);

        // 设置API客户端Token
        _apiClient.setToken(_token);

        // 注意: WebSocket连接移到ChatProvider.init()中

        notifyListeners();
        return true;
      } else {
        _error = result.message ?? '注册失败';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = '注册异常: $e';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Token过期处理（刷新失败时由 ApiClient 调用）
  bool _isHandlingExpiry = false;
  void _handleAuthExpired() {
    // 防止多个401同时触发多次登出
    if (_isHandlingExpiry || _status == AuthStatus.unauthenticated) return;
    _isHandlingExpiry = true;
    debugPrint('[AuthProvider] Token过期且刷新失败，自动登出');
    logout().then((_) => _isHandlingExpiry = false);
  }

  /// 本地登出（被踢出时使用，不调用服务端 API，避免踢掉新会话）
  Future<void> _localLogout() async {
    // 先执行清理回调（清理直播推流等资源）
    if (_onBeforeLogout != null) {
      try {
        debugPrint('[AuthProvider] 执行登出前清理回调...');
        await _onBeforeLogout!();
      } catch (e) {
        debugPrint('[AuthProvider] 登出前清理回调失败: $e');
      }
    }

    // 立即重置状态，防止 _handleAuthExpired 在异步间隙触发 logout() 调 API
    _token = null;
    _user = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    _apiClient.setToken(null);

    // 重置WebRTC服务
    try {
      await WebRTCService().reset();
    } catch (e) {
      debugPrint('重置WebRTC服务失败: $e');
    }

    // 断开WebSocket
    _wsService.disconnect();

    // 清除本地数据
    try {
      await _storage.clearLoginData();
    } catch (e) {
      debugPrint('清除本地数据失败: $e');
    }

    notifyListeners();
  }

  /// 退出登录
  Future<void> logout() async {
    // 先执行清理回调（清理直播推流等资源）
    if (_onBeforeLogout != null) {
      try {
        debugPrint('[AuthProvider] 执行登出前清理回调...');
        await _onBeforeLogout!();
      } catch (e) {
        debugPrint('[AuthProvider] 登出前清理回调失败: $e');
      }
    }

    // 先设置退出标志，避免收到 force_logout 提示
    _wsService.disconnect(isLogout: true);
    
    try {
      await _authApi.logout();
    } catch (e) {
      // 忽略退出登录API错误
    }

    // 重置WebRTC服务（重要：必须在断开WebSocket之前重置）
    try {
      await WebRTCService().reset();
    } catch (e) {
      debugPrint('重置WebRTC服务失败: $e');
    }

    // 清除本地数据
    await _storage.clearLoginData();

    // 清除API客户端Token
    _apiClient.setToken(null);

    // 重置状态
    _token = null;
    _user = null;
    _status = AuthStatus.unauthenticated;
    _error = null;

    notifyListeners();
  }

  /// 更新用户信息
  void updateUser(User user) {
    _user = user;
    _storage.setUserInfo(user);
    notifyListeners();
  }

  /// 刷新用户信息（从服务器获取最新数据）
  Future<void> refreshUser() async {
    if (_token == null) return;

    try {
      final response = await _apiClient.get('/user/profile');
      if (response.success && response.data != null) {
        _user = User.fromJson(response.data);
        await _storage.setUserInfo(_user!);
        notifyListeners();
      }
    } catch (e) {
      // 忽略刷新错误
    }
  }

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
