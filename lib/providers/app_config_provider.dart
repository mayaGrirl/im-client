import 'package:flutter/material.dart';
import '../api/system_api.dart';

/// 应用配置提供者
/// 从服务端获取公开配置、功能开关、主题等
class AppConfigProvider extends ChangeNotifier {
  final SystemApi _api = SystemApi();

  bool _loaded = false;
  bool get loaded => _loaded;

  // 全部公开配置（按分组）
  Map<String, dynamic> _configs = {};

  // 功能开关
  Map<String, bool> _features = {};

  // 主题配置
  Color _primaryColor = const Color(0xFF07C160);
  Color _secondaryColor = const Color(0xFF576B95);
  Color _accentColor = const Color(0xFF13c2c2);
  String _themeMode = 'system';
  Color _chatBgColor = const Color(0xFFF5F5F5);
  String _chatBgImage = '';

  // App 信息
  String _appName = 'IM即时通讯';
  String _appLogo = '';

  // 联系方式
  String _contactEmail = '';
  String _contactPhone = '';
  String _contactWechat = '';
  String _contactQQ = '';
  String _contactWorkTime = '';

  // 消息配置
  int _messageMaxLength = 5000;
  int _messageRecallTime = 120;
  bool _messageReadReceipt = true;
  bool _messageTypingStatus = true;

  // 安全配置
  int _passwordMinLen = 6;

  // Getters
  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;
  Color get accentColor => _accentColor;
  String get themeMode => _themeMode;
  Color get chatBgColor => _chatBgColor;
  String get chatBgImage => _chatBgImage;
  String get appName => _appName;
  String get appLogo => _appLogo;
  String get contactEmail => _contactEmail;
  String get contactPhone => _contactPhone;
  String get contactWechat => _contactWechat;
  String get contactQQ => _contactQQ;
  String get contactWorkTime => _contactWorkTime;
  int get messageMaxLength => _messageMaxLength;
  int get messageRecallTime => _messageRecallTime;
  bool get messageReadReceipt => _messageReadReceipt;
  bool get messageTypingStatus => _messageTypingStatus;
  int get passwordMinLen => _passwordMinLen;

  /// 检查功能是否启用
  bool isFeatureEnabled(String key) {
    return _features[key] ?? true; // 默认启用
  }

  /// 获取指定分组的配置值
  dynamic getConfig(String group, String key, [dynamic defaultValue]) {
    final groupMap = _configs[group];
    if (groupMap is Map) {
      return groupMap[key] ?? defaultValue;
    }
    return defaultValue;
  }

  /// 初始化：从服务端加载配置
  Future<void> init() async {
    try {
      // 并行获取配置和功能开关
      final results = await Future.wait([
        _api.getPublicConfig(),
        _api.getFeatures(),
      ]);

      _configs = results[0] as Map<String, dynamic>;
      _features = (results[1] as Map).map(
        (k, v) => MapEntry(k.toString(), v == true || v == 'true'),
      );

      _parseConfigs();
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[AppConfig] 加载配置失败: $e');
      _loaded = true; // 即使失败也标记为已加载，使用默认值
      notifyListeners();
    }
  }

  /// 解析配置到本地字段
  void _parseConfigs() {
    // 主题配置
    final theme = _configs['theme'];
    if (theme is Map) {
      _primaryColor = _parseColor(theme['theme_primary_color'], _primaryColor);
      _secondaryColor = _parseColor(theme['theme_secondary_color'], _secondaryColor);
      _accentColor = _parseColor(theme['theme_accent_color'], _accentColor);
      _themeMode = theme['theme_mode']?.toString() ?? _themeMode;
      _chatBgColor = _parseColor(theme['theme_chat_bg_color'], _chatBgColor);
      _chatBgImage = theme['theme_chat_bg_image']?.toString() ?? '';
    }

    // App 信息
    final app = _configs['app'];
    if (app is Map) {
      _appName = app['app_name']?.toString() ?? _appName;
      _appLogo = app['app_logo']?.toString() ?? '';
    }

    // 联系方式
    final contact = _configs['contact'];
    if (contact is Map) {
      _contactEmail = contact['contact_email']?.toString() ?? '';
      _contactPhone = contact['contact_phone']?.toString() ?? '';
      _contactWechat = contact['contact_wechat']?.toString() ?? '';
      _contactQQ = contact['contact_qq']?.toString() ?? '';
      _contactWorkTime = contact['contact_work_time']?.toString() ?? '';
    }

    // 消息配置
    final message = _configs['message'];
    if (message is Map) {
      _messageMaxLength = _parseInt(message['message_max_length'], _messageMaxLength);
      _messageRecallTime = _parseInt(message['message_recall_time'], _messageRecallTime);
      _messageReadReceipt = _parseBool(message['message_read_receipt'], _messageReadReceipt);
      _messageTypingStatus = _parseBool(message['message_typing_status'], _messageTypingStatus);
    }

    // 安全配置
    final security = _configs['security'];
    if (security is Map) {
      _passwordMinLen = _parseInt(security['security_password_min_len'], _passwordMinLen);
    }
  }

  /// 解析颜色值
  Color _parseColor(dynamic value, Color defaultColor) {
    if (value == null) return defaultColor;
    final str = value.toString().trim();
    if (str.isEmpty) return defaultColor;
    try {
      if (str.startsWith('#')) {
        final hex = str.substring(1);
        if (hex.length == 6) {
          return Color(int.parse('FF$hex', radix: 16));
        } else if (hex.length == 8) {
          return Color(int.parse(hex, radix: 16));
        }
      }
    } catch (_) {}
    return defaultColor;
  }

  int _parseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  bool _parseBool(dynamic value, bool defaultValue) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    return value.toString() == 'true' || value.toString() == '1';
  }
}
