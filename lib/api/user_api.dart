/// 用户API
/// 用户资料、等级、金豆等相关接口

import 'package:flutter/foundation.dart';
import 'package:im_client/api/api_client.dart';

class UserApi {
  final ApiClient _client;

  UserApi(this._client);

  // ==================== 验证码 ====================

  /// 发送验证码
  /// [target] 邮箱或手机号
  /// [type] 类型: 1注册 2登录 3绑定 4找回密码
  /// [countryCode] 国家区号（手机号时使用）
  Future<ApiResponse> sendVerifyCode(String target, int type, {String? countryCode}) {
    return _client.post('/auth/send-code', data: {
      'target': target,
      'type': type,
      if (countryCode != null) 'country_code': countryCode,
    });
  }

  // ==================== 账号绑定 ====================

  /// 绑定邮箱
  Future<ApiResponse> bindEmail(String email, String code) {
    return _client.post('/user/bind-email', data: {
      'email': email,
      'code': code,
    });
  }

  /// 绑定手机号
  /// [countryCode] 国家区号
  Future<ApiResponse> bindPhone(String phone, String code, {String? countryCode}) {
    return _client.post('/user/bind-phone', data: {
      'phone': phone,
      'code': code,
      if (countryCode != null) 'country_code': countryCode,
    });
  }

  /// 重置密码
  Future<ApiResponse> resetPassword(String target, String code, String newPassword) {
    return _client.post('/auth/reset-password', data: {
      'target': target,
      'code': code,
      'new_password': newPassword,
    });
  }

  /// 修改登录密码
  Future<ApiResponse> changePassword(String oldPassword, String newPassword) {
    return _client.post('/user/change-password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  /// 修改登录密码（带验证）
  /// [verifyType] 验证类型: 1邮箱验证码 2手机验证码 3支付密码
  Future<ApiResponse> changePasswordWithVerify({
    required String newPassword,
    required int verifyType,
    String? verifyCode,
    String? payPassword,
  }) {
    return _client.post('/user/change-password-verify', data: {
      'new_password': newPassword,
      'verify_type': verifyType,
      if (verifyCode != null) 'verify_code': verifyCode,
      if (payPassword != null) 'pay_password': payPassword,
    });
  }

  /// 设置/修改支付密码
  Future<ApiResponse> setPayPassword(String password, {String? oldPassword}) {
    final data = <String, dynamic>{'password': password};
    if (oldPassword != null) data['old_password'] = oldPassword;
    return _client.post('/wallet/pay-password', data: data);
  }

  /// 设置/修改支付密码（带验证）
  /// [verifyType] 验证类型: 0首次设置(无需验证) 1邮箱验证码 2手机验证码 3原支付密码
  Future<ApiResponse> setPayPasswordWithVerify({
    required String newPassword,
    required int verifyType,
    String? verifyCode,
    String? oldPayPassword,
  }) {
    return _client.post('/wallet/pay-password-verify', data: {
      'new_password': newPassword,
      'verify_type': verifyType,
      if (verifyCode != null) 'verify_code': verifyCode,
      if (oldPayPassword != null) 'old_pay_password': oldPayPassword,
    });
  }

  /// 发送手机验证码（绑定用）
  /// [countryCode] 国家区号
  Future<ApiResponse> sendPhoneCode(String phone, {String? countryCode}) {
    return _client.post('/auth/send-code', data: {
      'target': phone,
      'type': VerifyCodeType.bind,
      if (countryCode != null) 'country_code': countryCode,
    });
  }

  /// 发送邮箱验证码（绑定用）
  Future<ApiResponse> sendEmailCode(String email) {
    return _client.post('/auth/send-code', data: {
      'target': email,
      'type': VerifyCodeType.bind,
    });
  }

  /// 发送手机验证码（修改密码用）
  /// [countryCode] 国家区号
  Future<ApiResponse> sendPhoneCodeForPasswordChange(String phone, {String? countryCode}) {
    return _client.post('/auth/send-code', data: {
      'target': phone,
      'type': VerifyCodeType.changePassword,
      if (countryCode != null) 'country_code': countryCode,
    });
  }

  /// 发送邮箱验证码（修改密码用）
  Future<ApiResponse> sendEmailCodeForPasswordChange(String email) {
    return _client.post('/auth/send-code', data: {
      'target': email,
      'type': VerifyCodeType.changePassword,
    });
  }

  /// 验证身份（用于更换手机/邮箱前的身份验证）
  /// [verifyType] 1: 邮箱验证码, 2: 手机验证码, 3: 支付密码
  Future<ApiResponse> verifyIdentity({
    required int verifyType,
    String? verifyCode,
    String? payPassword,
  }) {
    return _client.post('/user/verify-identity', data: {
      'verify_type': verifyType,
      if (verifyCode != null) 'verify_code': verifyCode,
      if (payPassword != null) 'pay_password': payPassword,
    });
  }

  // ==================== 钱包 ====================

  /// 获取钱包信息
  Future<ApiResponse> getWalletInfo() {
    return _client.get('/wallet/info');
  }

  /// 获取钱包交易记录
  Future<ApiResponse> getWalletTransactions({int page = 1, int pageSize = 20, int? type}) {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (type != null) {
      params['type'] = type.toString();
    }
    return _client.get('/wallet/transactions', queryParameters: params);
  }

  // ==================== 用户资料 ====================

  /// 获取用户资料
  Future<ApiResponse> getProfile() {
    return _client.get('/user/profile');
  }

  /// 获取指定用户的资料（公开信息）
  Future<ApiResponse> getUserProfile(int userId) {
    return _client.get('/user/$userId');
  }

  /// 根据ID获取用户信息（公开信息）
  Future<Map<String, dynamic>?> getUserById(int userId) async {
    final response = await _client.get('/user/$userId');
    if (response.success && response.data != null) {
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    }
    return null;
  }

  /// 获取用户二维码
  Future<String?> getUserQrCode(int userId) async {
    try {
      final response = await _client.get('/user/$userId/qrcode');
      if (response.success && response.data != null) {
        // 可能返回的格式：
        // 1. { "qr_code_url": "..." }
        // 2. { "qrcode": "..." }
        // 3. 直接返回 URL 字符串
        if (response.data is Map) {
          final data = response.data as Map;
          return data['qr_code_url'] as String? ?? 
                 data['qrcode'] as String? ?? 
                 data['url'] as String?;
        } else if (response.data is String) {
          return response.data as String;
        }
      }
    } catch (e) {
      debugPrint('[UserApi] 获取用户二维码失败: $e');
    }
    return null;
  }

  /// 更新用户资料
  Future<ApiResponse> updateProfile({
    String? nickname,
    String? avatar,
    String? momentCover,
    String? videoCover,
    int? gender,
    String? birthday,
    String? bio,
    String? videoBio,
    String? region,
    String? address,
    int? qrcodeStyle,
  }) {
    final data = <String, dynamic>{};
    if (nickname != null) data['nickname'] = nickname;
    if (avatar != null) data['avatar'] = avatar;
    if (momentCover != null) data['moment_cover'] = momentCover;
    if (videoCover != null) data['video_cover'] = videoCover;
    if (gender != null) data['gender'] = gender;
    if (birthday != null) data['birthday'] = birthday;
    if (bio != null) data['bio'] = bio;
    if (videoBio != null) data['video_bio'] = videoBio;
    if (region != null) data['region'] = region;
    if (address != null) data['address'] = address;
    if (qrcodeStyle != null) data['qrcode_style'] = qrcodeStyle;
    return _client.put('/user/profile', data: data);
  }

  /// 获取我的二维码
  Future<ApiResponse> getMyQRCode() {
    return _client.get('/qrcode/mine');
  }

  /// 扫描二维码
  Future<ApiResponse> scanQRCode(String code) {
    return _client.get('/qrcode/scan/$code');
  }

  // ==================== 等级和积分 ====================

  /// 获取等级信息
  Future<ApiResponse> getLevelInfo() {
    return _client.get('/user/level');
  }

  /// 获取所有等级配置
  Future<ApiResponse> getAllLevels() {
    return _client.get('/levels');
  }

  // ==================== 签到 ====================

  /// 每日签到
  Future<ApiResponse> dailyCheckin() {
    return _client.post('/user/checkin');
  }

  /// 获取签到日历（本月）
  Future<ApiResponse> getCheckinCalendar() {
    return _client.get('/user/checkin/calendar');
  }

  // ==================== 金豆 ====================

  /// 获取金豆余额
  Future<ApiResponse> getGoldBeanBalance() {
    return _client.get('/user/gold-bean-balance');
  }

  /// 领取每日金豆
  Future<ApiResponse> claimDailyGoldBeans() {
    return _client.post('/user/claim-gold-beans');
  }

  /// 获取金豆记录
  Future<ApiResponse> getGoldBeanRecords({int page = 1, int pageSize = 20}) {
    return _client.get('/user/gold-bean-records', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  // ==================== 邀请 ====================

  /// 获取邀请信息
  Future<ApiResponse> getInviteInfo() {
    return _client.get('/user/invite-info');
  }

  // ==================== 金豆商城 ====================

  /// 获取商品列表
  Future<ApiResponse> getGoldBeanProducts() {
    return _client.get('/gold-bean/products');
  }

  /// 兑换商品
  Future<ApiResponse> exchangeProduct(int productId, {int quantity = 1}) {
    return _client.post('/gold-bean/exchange', data: {
      'product_id': productId,
      'quantity': quantity,
    });
  }

  /// 获取我的兑换记录
  Future<ApiResponse> getMyExchanges() {
    return _client.get('/gold-bean/my-exchanges');
  }

  // ==================== 用户设置 ====================

  /// 获取用户设置
  Future<ApiResponse> getUserSettings() {
    return _client.get('/user/settings');
  }

  /// 更新用户设置
  Future<ApiResponse> updateUserSettings({
    bool? notificationSound,
    bool? notificationVibrate,
    bool? showOnlineStatus,
    bool? allowStranger,
    String? language,
    String? customRingtone,
    String? customRingtoneName,
  }) {
    final data = <String, dynamic>{};
    if (notificationSound != null) data['notification_sound'] = notificationSound;
    if (notificationVibrate != null) data['notification_vibrate'] = notificationVibrate;
    if (showOnlineStatus != null) data['show_online_status'] = showOnlineStatus;
    if (allowStranger != null) data['allow_stranger'] = allowStranger;
    if (language != null) data['language'] = language;
    if (customRingtone != null) data['custom_ringtone'] = customRingtone;
    if (customRingtoneName != null) data['custom_ringtone_name'] = customRingtoneName;
    return _client.put('/user/settings', data: data);
  }

  /// 清除自定义铃声设置
  Future<ApiResponse> clearCustomRingtone() {
    return _client.put('/user/settings', data: {
      'custom_ringtone': '',
      'custom_ringtone_name': '',
    });
  }
}

/// 验证码类型
class VerifyCodeType {
  static const int register = 1;
  static const int login = 2;
  static const int bind = 3;
  static const int resetPassword = 4;
  static const int changePassword = 5;
}

/// 金豆记录类型
class GoldBeanRecordType {
  static const int dailyClaim = 1;     // 每日领取
  static const int inviteReward = 2;   // 邀请奖励
  static const int registerReward = 3; // 注册奖励
  static const int exchange = 4;       // 兑换消费
  static const int systemGift = 5;     // 系统赠送
  static const int levelReward = 6;    // 等级奖励
}
