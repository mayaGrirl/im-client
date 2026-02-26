/// 本地存储服务
/// 处理Token、用户信息等持久化存储

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/models/user.dart';

/// 存储服务单例
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 确保已初始化
  Future<SharedPreferences> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  // ==================== Token ====================

  /// 保存Token
  Future<void> setToken(String token) async {
    final prefs = await _ensureInitialized();
    await prefs.setString(StorageKeys.token, token);
  }

  /// 获取Token
  Future<String?> getToken() async {
    final prefs = await _ensureInitialized();
    return prefs.getString(StorageKeys.token);
  }

  /// 删除Token
  Future<void> removeToken() async {
    final prefs = await _ensureInitialized();
    await prefs.remove(StorageKeys.token);
  }

  // ==================== 用户ID ====================

  /// 保存用户ID
  Future<void> setUserId(int userId) async {
    final prefs = await _ensureInitialized();
    await prefs.setInt(StorageKeys.userId, userId);
  }

  /// 获取用户ID
  Future<int?> getUserId() async {
    final prefs = await _ensureInitialized();
    return prefs.getInt(StorageKeys.userId);
  }

  // ==================== 用户信息 ====================

  /// 保存用户信息
  Future<void> setUserInfo(User user) async {
    final prefs = await _ensureInitialized();
    await prefs.setString(StorageKeys.userInfo, jsonEncode(user.toJson()));
  }

  /// 获取用户信息
  Future<User?> getUserInfo() async {
    final prefs = await _ensureInitialized();
    final jsonStr = prefs.getString(StorageKeys.userInfo);
    if (jsonStr != null) {
      try {
        return User.fromJson(jsonDecode(jsonStr));
      } catch (e) {
        // 解析失败
      }
    }
    return null;
  }

  /// 删除用户信息
  Future<void> removeUserInfo() async {
    final prefs = await _ensureInitialized();
    await prefs.remove(StorageKeys.userInfo);
  }

  // ==================== 设置 ====================

  /// 保存设置
  Future<void> setSettings(Map<String, dynamic> settings) async {
    final prefs = await _ensureInitialized();
    await prefs.setString(StorageKeys.settings, jsonEncode(settings));
  }

  /// 获取设置
  Future<Map<String, dynamic>?> getSettings() async {
    final prefs = await _ensureInitialized();
    final jsonStr = prefs.getString(StorageKeys.settings);
    if (jsonStr != null) {
      try {
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (e) {
        // 解析失败
      }
    }
    return null;
  }

  // ==================== 设备Token ====================

  /// 保存设备Token（用于推送）
  Future<void> setDeviceToken(String token) async {
    final prefs = await _ensureInitialized();
    await prefs.setString(StorageKeys.deviceToken, token);
  }

  /// 获取设备Token
  Future<String?> getDeviceToken() async {
    final prefs = await _ensureInitialized();
    return prefs.getString(StorageKeys.deviceToken);
  }

  // ==================== 通用方法 ====================

  /// 保存字符串
  Future<void> setString(String key, String value) async {
    final prefs = await _ensureInitialized();
    await prefs.setString(key, value);
  }

  /// 获取字符串
  Future<String?> getString(String key) async {
    final prefs = await _ensureInitialized();
    return prefs.getString(key);
  }

  /// 保存整数
  Future<void> setInt(String key, int value) async {
    final prefs = await _ensureInitialized();
    await prefs.setInt(key, value);
  }

  /// 获取整数
  Future<int?> getInt(String key) async {
    final prefs = await _ensureInitialized();
    return prefs.getInt(key);
  }

  /// 保存布尔值
  Future<void> setBool(String key, bool value) async {
    final prefs = await _ensureInitialized();
    await prefs.setBool(key, value);
  }

  /// 获取布尔值
  Future<bool?> getBool(String key) async {
    final prefs = await _ensureInitialized();
    return prefs.getBool(key);
  }

  /// 删除键
  Future<void> remove(String key) async {
    final prefs = await _ensureInitialized();
    await prefs.remove(key);
  }

  /// 清空所有数据
  Future<void> clear() async {
    final prefs = await _ensureInitialized();
    await prefs.clear();
  }

  /// 清除登录数据（退出登录时调用）
  Future<void> clearLoginData() async {
    await removeToken();
    await removeUserInfo();
    await remove(StorageKeys.userId);
  }
}
