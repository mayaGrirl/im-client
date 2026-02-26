/// 语言设置Provider
/// 管理应用语言切换

import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/services/storage_service.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'app_locale';

  // 默认英文，初始化时会被系统语言或用户设置覆盖
  Locale _locale = const Locale('en', 'US');
  bool _isInitialized = false;

  Locale get locale => _locale;
  bool get isInitialized => _isInitialized;

  /// 支持的语言列表
  static const List<Locale> supportedLocales = [
    Locale('zh', 'CN'), // 简体中文
    Locale('zh', 'TW'), // 繁体中文
    Locale('en', 'US'), // 英文
    Locale('fr', 'FR'), // 法文
    Locale('hi', 'IN'), // 印地语
  ];

  /// 获取X-Language头部值
  String get languageHeader {
    final langCode = _locale.languageCode;
    final countryCode = _locale.countryCode ?? '';

    // 转换为服务端支持的格式
    switch ('${langCode}_$countryCode') {
      case 'zh_CN':
        return 'zh_cn';
      case 'zh_TW':
      case 'zh_HK':
        return 'zh_tw';
      case 'fr_FR':
      case 'fr_CA':
        return 'fr';
      case 'hi_IN':
        return 'hi';
      case 'en_US':
      case 'en_GB':
      default:
        return 'en';
    }
  }

  /// 初始化，按优先级：用户设置 > 系统/浏览器语言 > 默认英文
  Future<void> init() async {
    final storage = StorageService();

    // 1. 首先尝试读取用户保存的语言设置
    final savedLocaleCode = await storage.getString(_localeKey);
    if (savedLocaleCode != null && savedLocaleCode.isNotEmpty) {
      final parts = savedLocaleCode.split('_');
      if (parts.length >= 2) {
        _locale = Locale(parts[0], parts[1]);
      } else {
        _locale = Locale(parts[0]);
      }
      _updateApiClientLanguage();
      _isInitialized = true;
      notifyListeners();
      return;
    }

    // 2. 没有用户设置，尝试获取系统/浏览器语言
    final systemLocale = _getSystemLocale();
    if (systemLocale != null && _isSupported(systemLocale)) {
      _locale = _normalizeLocale(systemLocale);
    } else {
      // 3. 系统语言不支持或无法获取，使用默认英文
      _locale = const Locale('en', 'US');
    }

    _updateApiClientLanguage();
    _isInitialized = true;
    notifyListeners();
  }

  /// 更新ApiClient的语言设置
  void _updateApiClientLanguage() {
    ApiClient().setLanguage(languageHeader);
  }

  /// 获取系统/浏览器语言
  Locale? _getSystemLocale() {
    try {
      if (kIsWeb) {
        // Web平台：从window.navigator.language获取
        final locales = ui.PlatformDispatcher.instance.locales;
        if (locales.isNotEmpty) {
          return locales.first;
        }
      } else {
        // 移动端/桌面端：从Platform获取
        final localeName = Platform.localeName;
        if (localeName.isNotEmpty) {
          // localeName格式可能是 "zh_CN", "en_US", "zh-CN" 等
          final normalized = localeName.replaceAll('-', '_');
          final parts = normalized.split('_');
          if (parts.isNotEmpty) {
            return Locale(
              parts[0].toLowerCase(),
              parts.length > 1 ? parts[1].toUpperCase() : null,
            );
          }
        }
      }
    } catch (e) {
      // 获取失败，返回null
      debugPrint('获取系统语言失败: $e');
    }
    return null;
  }

  /// 检查语言是否支持
  bool _isSupported(Locale locale) {
    final langCode = locale.languageCode.toLowerCase();
    return supportedLocales.any((l) => l.languageCode == langCode);
  }

  /// 标准化语言设置
  Locale _normalizeLocale(Locale locale) {
    final langCode = locale.languageCode.toLowerCase();
    final countryCode = locale.countryCode?.toUpperCase() ?? '';

    switch (langCode) {
      case 'zh':
        // 中文根据地区区分简繁
        if (countryCode == 'TW' || countryCode == 'HK' || countryCode == 'MO') {
          return const Locale('zh', 'TW');
        }
        return const Locale('zh', 'CN');
      case 'fr':
        return const Locale('fr', 'FR');
      case 'hi':
        return const Locale('hi', 'IN');
      case 'en':
      default:
        return const Locale('en', 'US');
    }
  }

  /// 切换语言（用户主动切换，会保存设置）
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;

    _locale = locale;
    _updateApiClientLanguage();
    final storage = StorageService();
    await storage.setString(_localeKey, '${locale.languageCode}_${locale.countryCode}');
    notifyListeners();
  }

  /// 清除用户语言设置，恢复为系统语言
  Future<void> resetToSystemLocale() async {
    final storage = StorageService();
    await storage.remove(_localeKey);

    final systemLocale = _getSystemLocale();
    if (systemLocale != null && _isSupported(systemLocale)) {
      _locale = _normalizeLocale(systemLocale);
    } else {
      _locale = const Locale('en', 'US');
    }
    _updateApiClientLanguage();
    notifyListeners();
  }

  /// 切换到简体中文
  Future<void> setSimplifiedChinese() => setLocale(const Locale('zh', 'CN'));

  /// 切换到繁体中文
  Future<void> setTraditionalChinese() => setLocale(const Locale('zh', 'TW'));

  /// 切换到英语
  Future<void> setEnglish() => setLocale(const Locale('en', 'US'));

  /// 切换到法语
  Future<void> setFrench() => setLocale(const Locale('fr', 'FR'));

  /// 切换到印地语
  Future<void> setHindi() => setLocale(const Locale('hi', 'IN'));

  /// 获取语言显示名称
  String getLocaleName(Locale locale) {
    switch ('${locale.languageCode}_${locale.countryCode}') {
      case 'zh_CN':
        return '简体中文';
      case 'zh_TW':
        return '繁體中文';
      case 'en_US':
        return 'English';
      case 'fr_FR':
        return 'Français';
      case 'hi_IN':
        return 'हिन्दी';
      default:
        return locale.languageCode;
    }
  }

  /// 获取当前语言显示名称
  String get currentLocaleName => getLocaleName(_locale);
}
