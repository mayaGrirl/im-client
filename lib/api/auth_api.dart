/// 认证相关API
/// 处理登录、注册、Token刷新等

import 'package:im_client/api/api_client.dart';
import 'package:im_client/models/user.dart';
import 'package:im_client/services/device_info_service.dart';

/// 认证API
class AuthApi {
  final ApiClient _client = ApiClient();

  /// 用户注册
  /// [username] 用户名
  /// [password] 密码
  /// [nickname] 昵称（可选）
  /// [phone] 手机号（可选）
  /// [countryCode] 国家区号（手机号时使用）
  /// [inviteCode] 邀请码（可选）
  Future<AuthResult> register({
    required String username,
    required String password,
    String? nickname,
    String? email,
    String? phone,
    String? countryCode,
    String? inviteCode,
  }) async {
    final response = await _client.post('/auth/register', data: {
      'username': username,
      'password': password,
      if (nickname != null) 'nickname': nickname,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (countryCode != null) 'country_code': countryCode,
      if (inviteCode != null && inviteCode.isNotEmpty) 'invite_code': inviteCode,
    });

    if (response.success && response.data != null) {
      final token = response.data['token'] as String;
      final userJson = response.data['user_info'] as Map<String, dynamic>;
      return AuthResult(
        success: true,
        token: token,
        user: User.fromJson(userJson),
        message: response.message,
      );
    }

    return AuthResult(
      success: false,
      message: response.message ?? '注册失败',
    );
  }

  /// 用户登录
  /// [username] 用户名/邮箱/手机号
  /// [password] 密码
  /// [countryCode] 国家区号（手机号登录时使用）
  Future<AuthResult> login({
    required String username,
    required String password,
    String? countryCode,
  }) async {
    // 获取设备信息
    final deviceInfo = await DeviceInfoService().getDeviceInfo();

    final response = await _client.post('/auth/login', data: {
      'username': username,
      'password': password,
      if (countryCode != null) 'country_code': countryCode,
      // 设备信息
      ...deviceInfo.toJson(),
    });

    if (response.success && response.data != null) {
      final token = response.data['token'] as String;
      final userJson = response.data['user_info'] as Map<String, dynamic>;
      return AuthResult(
        success: true,
        token: token,
        user: User.fromJson(userJson),
        message: response.message,
      );
    }

    return AuthResult(
      success: false,
      message: response.message ?? '登录失败',
    );
  }

  /// 刷新Token
  Future<String?> refreshToken() async {
    final response = await _client.post('/auth/refresh');

    if (response.success && response.data != null) {
      return response.data['token'] as String?;
    }

    return null;
  }

  /// 退出登录
  Future<bool> logout() async {
    // X-Device-Type 和 X-Device-ID 已由 ApiClient 全局拦截器自动附加
    final response = await _client.post('/auth/logout');
    return response.success;
  }

  /// 验证码登录
  /// [target] 邮箱或手机号
  /// [code] 验证码
  /// [countryCode] 国家区号（手机号登录时使用）
  Future<AuthResult> loginByCode({
    required String target,
    required String code,
    String? countryCode,
  }) async {
    // 获取设备信息
    final deviceInfo = await DeviceInfoService().getDeviceInfo();

    final response = await _client.post('/auth/login-by-code', data: {
      'target': target,
      'code': code,
      if (countryCode != null) 'country_code': countryCode,
      // 设备信息
      ...deviceInfo.toJson(),
    });

    if (response.success && response.data != null) {
      final token = response.data['token'] as String;
      final userJson = response.data['user_info'] as Map<String, dynamic>;
      return AuthResult(
        success: true,
        token: token,
        user: User.fromJson(userJson),
        message: response.message,
      );
    }

    return AuthResult(
      success: false,
      message: response.message ?? '登录失败',
    );
  }

  /// 发送验证码
  /// [target] 邮箱或手机号
  /// [type] 类型: 1注册 2登录 3绑定 4找回密码
  /// [countryCode] 国家区号（手机号时使用）
  Future<SendCodeResult> sendVerifyCode({
    required String target,
    required int type,
    String? countryCode,
  }) async {
    final response = await _client.post('/auth/send-code', data: {
      'target': target,
      'type': type,
      if (countryCode != null) 'country_code': countryCode,
    });

    return SendCodeResult(
      success: response.success,
      message: response.message,
      code: response.data?['data']?['code']?.toString() ?? response.data?['code']?.toString(), // 开发环境返回验证码
    );
  }

  /// 重置密码
  /// [countryCode] 国家区号（手机号时使用）
  Future<bool> resetPassword({
    required String target,
    required String code,
    required String newPassword,
    String? countryCode,
  }) async {
    final response = await _client.post('/auth/reset-password', data: {
      'target': target,
      'code': code,
      'new_password': newPassword,
      if (countryCode != null) 'country_code': countryCode,
    });
    return response.success;
  }
}

/// 发送验证码结果
class SendCodeResult {
  final bool success;
  final String? message;
  final String? code; // 开发环境返回的验证码

  SendCodeResult({
    required this.success,
    this.message,
    this.code,
  });
}

/// 认证结果
class AuthResult {
  final bool success;
  final String? token;
  final User? user;
  final String? message;

  AuthResult({
    required this.success,
    this.token,
    this.user,
    this.message,
  });
}
