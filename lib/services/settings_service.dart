/// 全局设置服务
/// 管理用户的各种设置项

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/user_api.dart';

/// 字体大小枚举
enum FontSizeOption {
  small('小', 0.85),   // 缩小到85%
  medium('中', 1.0),   // 默认100%
  large('大', 1.2);    // 放大到120%

  final String label;
  final double scale; // 文字缩放比例
  const FontSizeOption(this.label, this.scale);
}

/// 设置服务单例
class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

  // 设置项
  String? _globalChatBackground;
  FontSizeOption _fontSize = FontSizeOption.medium;
  bool _messageNotification = true;
  bool _messageSound = true;
  bool _messageVibrate = true;
  bool _showMessagePreview = true;
  int _addFriendPermission = 0; // 0: 所有人, 1: 需验证, 2: 禁止
  bool _showOnlineStatus = true;
  bool _autoDownloadMedia = true;
  bool _saveToAlbum = false;
  String? _customRingtone; // 自定义来电铃声路径（服务器URL）
  String? _customRingtoneName; // 自定义来电铃声名称

  // Getters
  String? get globalChatBackground => _globalChatBackground;
  FontSizeOption get fontSize => _fontSize;
  bool get messageNotification => _messageNotification;
  bool get messageSound => _messageSound;
  bool get messageVibrate => _messageVibrate;
  bool get showMessagePreview => _showMessagePreview;
  int get addFriendPermission => _addFriendPermission;
  bool get showOnlineStatus => _showOnlineStatus;
  bool get autoDownloadMedia => _autoDownloadMedia;
  bool get saveToAlbum => _saveToAlbum;
  String? get customRingtone => _customRingtone;
  String? get customRingtoneName => _customRingtoneName;

  /// 初始化
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
    _initialized = true;
  }

  /// 从服务器加载用户设置（登录后调用）
  Future<void> loadFromServer() async {
    try {
      debugPrint('[SettingsService] 开始从服务器加载用户设置...');
      final userApi = UserApi(ApiClient());
      final response = await userApi.getUserSettings();
      debugPrint('[SettingsService] 服务器响应: success=${response.success}, data=${response.data}');

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        debugPrint('[SettingsService] 服务器返回的设置数据: $data');

        // 加载自定义铃声设置
        // 尝试多种可能的字段名（服务器可能使用不同的命名风格）
        final serverRingtone = data['custom_ringtone'] as String?
            ?? data['customRingtone'] as String?;
        final serverRingtoneName = data['custom_ringtone_name'] as String?
            ?? data['customRingtoneName'] as String?;

        debugPrint('[SettingsService] 解析到的铃声URL: $serverRingtone');
        debugPrint('[SettingsService] 解析到的铃声名称: $serverRingtoneName');

        if (serverRingtone != null && serverRingtone.isNotEmpty) {
          // 服务器有铃声设置，同步到本地
          _customRingtone = serverRingtone;
          _customRingtoneName = serverRingtoneName;
          await _prefs?.setString('custom_ringtone', serverRingtone);
          if (serverRingtoneName != null && serverRingtoneName.isNotEmpty) {
            await _prefs?.setString('custom_ringtone_name', serverRingtoneName);
          }
          notifyListeners();
          debugPrint('[SettingsService] 成功从服务器加载铃声设置: $serverRingtoneName');
        } else {
          debugPrint('[SettingsService] 服务器未返回自定义铃声设置');
        }

        // 可以在这里加载其他服务器端设置...
      } else {
        debugPrint('[SettingsService] 服务器响应失败或数据为空');
      }
    } catch (e, stackTrace) {
      debugPrint('[SettingsService] 从服务器加载设置失败: $e');
      debugPrint('[SettingsService] 堆栈跟踪: $stackTrace');
    }
  }

  /// 加载设置
  void _loadSettings() {
    _globalChatBackground = _prefs?.getString('global_chat_background');

    final fontSizeIndex = _prefs?.getInt('font_size') ?? 1;
    _fontSize = FontSizeOption.values[fontSizeIndex.clamp(0, 2)];

    _messageNotification = _prefs?.getBool('message_notification') ?? true;
    _messageSound = _prefs?.getBool('message_sound') ?? true;
    _messageVibrate = _prefs?.getBool('message_vibrate') ?? true;
    _showMessagePreview = _prefs?.getBool('show_message_preview') ?? true;
    _addFriendPermission = _prefs?.getInt('add_friend_permission') ?? 0;
    _showOnlineStatus = _prefs?.getBool('show_online_status') ?? true;
    _autoDownloadMedia = _prefs?.getBool('auto_download_media') ?? true;
    _saveToAlbum = _prefs?.getBool('save_to_album') ?? false;
    _customRingtone = _prefs?.getString('custom_ringtone');
    _customRingtoneName = _prefs?.getString('custom_ringtone_name');

    debugPrint('[SettingsService] 从本地加载铃声设置: ringtone=$_customRingtone, name=$_customRingtoneName');
  }

  /// 设置全局聊天背景
  Future<void> setGlobalChatBackground(String? path) async {
    _globalChatBackground = path;
    if (path == null) {
      await _prefs?.remove('global_chat_background');
    } else {
      await _prefs?.setString('global_chat_background', path);
    }
    notifyListeners();
  }

  /// 设置字体大小
  Future<void> setFontSize(FontSizeOption option) async {
    _fontSize = option;
    await _prefs?.setInt('font_size', option.index);
    notifyListeners();
  }

  /// 设置消息通知
  Future<void> setMessageNotification(bool value) async {
    _messageNotification = value;
    await _prefs?.setBool('message_notification', value);
    notifyListeners();
  }

  /// 设置消息声音
  Future<void> setMessageSound(bool value) async {
    _messageSound = value;
    await _prefs?.setBool('message_sound', value);
    notifyListeners();
  }

  /// 设置消息震动
  Future<void> setMessageVibrate(bool value) async {
    _messageVibrate = value;
    await _prefs?.setBool('message_vibrate', value);
    notifyListeners();
  }

  /// 设置显示消息预览
  Future<void> setShowMessagePreview(bool value) async {
    _showMessagePreview = value;
    await _prefs?.setBool('show_message_preview', value);
    notifyListeners();
  }

  /// 设置添加好友权限
  Future<void> setAddFriendPermission(int value) async {
    _addFriendPermission = value;
    await _prefs?.setInt('add_friend_permission', value);
    notifyListeners();
  }

  /// 设置显示在线状态
  Future<void> setShowOnlineStatus(bool value) async {
    _showOnlineStatus = value;
    await _prefs?.setBool('show_online_status', value);
    notifyListeners();
  }

  /// 设置自动下载媒体
  Future<void> setAutoDownloadMedia(bool value) async {
    _autoDownloadMedia = value;
    await _prefs?.setBool('auto_download_media', value);
    notifyListeners();
  }

  /// 设置保存到相册
  Future<void> setSaveToAlbum(bool value) async {
    _saveToAlbum = value;
    await _prefs?.setBool('save_to_album', value);
    notifyListeners();
  }

  /// 设置自定义来电铃声（同时保存到本地和服务器）
  Future<void> setCustomRingtone(String? url, String? name) async {
    _customRingtone = url;
    _customRingtoneName = name;
    if (url == null || url.isEmpty) {
      await _prefs?.remove('custom_ringtone');
      await _prefs?.remove('custom_ringtone_name');
    } else {
      await _prefs?.setString('custom_ringtone', url);
      if (name != null) {
        await _prefs?.setString('custom_ringtone_name', name);
      }
    }
    notifyListeners();

    // 同步到服务器
    try {
      final userApi = UserApi(ApiClient());
      if (url == null || url.isEmpty) {
        await userApi.clearCustomRingtone();
        debugPrint('[SettingsService] 已清除服务器铃声设置');
      } else {
        await userApi.updateUserSettings(
          customRingtone: url,
          customRingtoneName: name,
        );
        debugPrint('[SettingsService] 已同步铃声设置到服务器: $name');
      }
    } catch (e) {
      debugPrint('[SettingsService] 同步铃声设置到服务器失败: $e');
    }
  }

  /// 清除自定义来电铃声
  Future<void> clearCustomRingtone() async {
    await setCustomRingtone(null, null);
  }

  /// 清除所有设置
  Future<void> clearAll() async {
    await _prefs?.clear();
    _loadSettings();
    notifyListeners();
  }
}
