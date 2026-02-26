/// 聊天设置服务
/// 管理聊天背景图、消息免打扰等设置

import 'package:hive_flutter/hive_flutter.dart';

class ChatSettingsService {
  static final ChatSettingsService _instance = ChatSettingsService._internal();
  factory ChatSettingsService() => _instance;
  ChatSettingsService._internal();

  static const String _boxName = 'chat_settings';
  static const String _backgroundPrefix = 'bg_';
  static const String _mutePrefix = 'mute_';
  static const String _globalMuteKey = 'global_mute';

  Box? _box;
  bool _initialized = false;
  Future<void>? _initFuture;

  /// 初始化
  Future<void> init() async {
    if (_initialized && _box != null && _box!.isOpen) return;

    // 避免并发初始化
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    _initFuture = _doInit();
    await _initFuture;
    _initFuture = null;
  }

  Future<void> _doInit() async {
    try {
      // 如果 box 已经打开但被关闭了，重新打开
      if (_box != null && !_box!.isOpen) {
        _box = null;
        _initialized = false;
      }

      if (!_initialized || _box == null) {
        _box = await Hive.openBox(_boxName);
        _initialized = true;
        print('[ChatSettingsService] 初始化成功, box=${_box?.name}, isOpen=${_box?.isOpen}');
      }
    } catch (e) {
      print('[ChatSettingsService] 初始化失败: $e');
      _initialized = false;
      _box = null;
    }
  }

  /// 确保已初始化
  Future<void> _ensureInitialized() async {
    if (!_initialized || _box == null || !_box!.isOpen) {
      await init();
    }
  }

  // ========== 聊天背景图设置 ==========

  /// 获取会话的特定背景图路径（仅该会话设置的）
  Future<String?> getBackgroundImage(String conversId) async {
    await _ensureInitialized();
    return _box?.get('$_backgroundPrefix$conversId') as String?;
  }

  /// 获取有效的背景图路径（优先级：会话特定背景 > 全局背景）
  /// [globalBackground] 从 SettingsService.globalChatBackground 传入
  Future<String?> getEffectiveBackgroundImage(String conversId, String? globalBackground) async {
    await _ensureInitialized();
    // 优先使用会话特定背景
    final specificBackground = _box?.get('$_backgroundPrefix$conversId') as String?;
    if (specificBackground != null && specificBackground.isNotEmpty) {
      return specificBackground;
    }
    // 否则使用全局背景
    return globalBackground;
  }

  /// 设置会话的背景图路径
  Future<void> setBackgroundImage(String conversId, String? imagePath) async {
    await _ensureInitialized();
    if (imagePath == null || imagePath.isEmpty) {
      await _box?.delete('$_backgroundPrefix$conversId');
    } else {
      await _box?.put('$_backgroundPrefix$conversId', imagePath);
    }
    print('[ChatSettingsService] 设置背景图: conversId=$conversId, path=$imagePath');
  }

  /// 清除会话的背景图
  Future<void> clearBackgroundImage(String conversId) async {
    await setBackgroundImage(conversId, null);
  }

  /// 检查会话是否有特定背景（用于判断是否使用自己的设置）
  Future<bool> hasSpecificBackground(String conversId) async {
    await _ensureInitialized();
    final bg = _box?.get('$_backgroundPrefix$conversId') as String?;
    return bg != null && bg.isNotEmpty;
  }

  // ========== 消息免打扰设置 ==========

  /// 获取会话的免打扰状态
  /// 返回 true 表示开启免打扰（不响铃），false 表示关闭免打扰（响铃）
  Future<bool> isMuted(String conversId) async {
    await _ensureInitialized();
    final key = '$_mutePrefix$conversId';
    final value = _box?.get(key, defaultValue: false) as bool? ?? false;
    print('[ChatSettingsService] 读取免打扰状态: key=$key, value=$value, boxKeys=${_box?.keys.toList()}');
    return value;
  }

  /// 设置会话的免打扰状态
  Future<void> setMuted(String conversId, bool muted) async {
    await _ensureInitialized();
    final key = '$_mutePrefix$conversId';
    await _box?.put(key, muted);
    // 强制刷新确保数据持久化
    await _box?.flush();
    // 验证写入是否成功
    final savedValue = _box?.get(key);
    print('[ChatSettingsService] 设置免打扰: key=$key, muted=$muted, savedValue=$savedValue, boxKeys=${_box?.keys.where((k) => k.toString().startsWith(_mutePrefix)).toList()}');
  }

  /// 切换会话的免打扰状态
  Future<bool> toggleMuted(String conversId) async {
    final currentMuted = await isMuted(conversId);
    final newMuted = !currentMuted;
    await setMuted(conversId, newMuted);
    return newMuted;
  }

  // ========== 全局设置 ==========

  /// 获取全局免打扰状态
  Future<bool> isGlobalMuted() async {
    await _ensureInitialized();
    return _box?.get(_globalMuteKey, defaultValue: false) as bool? ?? false;
  }

  /// 设置全局免打扰状态
  Future<void> setGlobalMuted(bool muted) async {
    await _ensureInitialized();
    await _box?.put(_globalMuteKey, muted);
    print('[ChatSettingsService] 设置全局免打扰: muted=$muted');
  }

  /// 检查是否应该播放铃声
  /// 综合判断全局设置和会话设置
  Future<bool> shouldPlaySound(String conversId) async {
    // 全局免打扰开启时，不播放铃声
    if (await isGlobalMuted()) {
      return false;
    }
    // 会话免打扰开启时，不播放铃声
    if (await isMuted(conversId)) {
      return false;
    }
    return true;
  }
}
