/// 消息通知铃声服务
/// 处理收到消息时的铃声播放
/// 支持从用户设置获取自定义铃声URL

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:im_client/services/settings_service.dart';

class NotificationSoundService {
  static final NotificationSoundService _instance = NotificationSoundService._internal();
  factory NotificationSoundService() => _instance;
  NotificationSoundService._internal();

  AudioPlayer? _player;
  bool _initialized = false;
  bool _hasSound = false;
  bool _isPlaying = false;
  String? _serverSoundUrl; // 服务器配置的铃声URL

  /// 初始化音频播放器
  /// 优先从服务器获取配置的铃声，如果没有则使用本地默认铃声
  Future<void> init() async {
    if (_initialized) return;

    try {
      _player = AudioPlayer();

      // 1. 从用户设置获取铃声配置
      _loadUserSoundConfig();

      // 2. 根据配置加载铃声
      if (_serverSoundUrl != null && _serverSoundUrl!.isNotEmpty) {
        // 使用服务器配置的铃声
        await _loadServerSound();
      } else {
        // 使用本地默认铃声
        await _loadLocalSound();
      }

      // 监听播放状态
      _player!.playerStateStream.listen((state) {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
        }
      });

      _initialized = true;
      print('[NotificationSoundService] 初始化成功, hasSound=$_hasSound, serverUrl=$_serverSoundUrl');
    } catch (e) {
      print('[NotificationSoundService] 初始化失败: $e');
      _initialized = true; // 标记为已初始化，避免重复尝试
      _hasSound = false;
    }
  }

  /// 从用户设置获取铃声配置
  void _loadUserSoundConfig() {
    try {
      final settingsService = SettingsService();
      final customRingtone = settingsService.customRingtone;

      if (customRingtone != null && customRingtone.isNotEmpty) {
        _serverSoundUrl = customRingtone;
        print('[NotificationSoundService] 用户自定义铃声: $_serverSoundUrl');
      } else {
        _serverSoundUrl = null;
        print('[NotificationSoundService] 用户未设置自定义铃声，使用默认');
      }
    } catch (e) {
      print('[NotificationSoundService] 获取用户铃声配置失败: $e');
      _serverSoundUrl = null;
    }
  }

  /// 加载用户自定义铃声
  Future<void> _loadServerSound() async {
    try {
      String soundUrl = _serverSoundUrl!;

      if (soundUrl.startsWith('http://') || soundUrl.startsWith('https://')) {
        // HTTP URL（Web端上传的铃声）
        print('[NotificationSoundService] 加载网络铃声: $soundUrl');
        await _player!.setUrl(soundUrl);
      } else if (!kIsWeb) {
        // 本地文件路径（非Web端）
        print('[NotificationSoundService] 加载本地铃声文件: $soundUrl');
        await _player!.setFilePath(soundUrl);
      } else {
        // Web端但不是HTTP URL，无法加载
        print('[NotificationSoundService] Web端无法加载本地文件，使用默认铃声');
        await _loadLocalSound();
        return;
      }

      _hasSound = true;
      print('[NotificationSoundService] 自定义铃声加载成功');
    } catch (e) {
      print('[NotificationSoundService] 自定义铃声加载失败，回退到本地铃声: $e');
      // 自定义铃声加载失败，回退到本地铃声
      await _loadLocalSound();
    }
  }

  /// 加载本地默认铃声
  Future<void> _loadLocalSound() async {
    try {
      await _player!.setAsset('assets/sounds/message.mp3');
      _hasSound = true;
      print('[NotificationSoundService] 本地音效加载成功');
    } catch (e) {
      print('[NotificationSoundService] 本地音效不存在，将使用系统反馈: $e');
      _hasSound = false;
    }
  }

  /// 重新加载铃声配置（用于配置更新后刷新）
  Future<void> reloadSound() async {
    _initialized = false;
    _hasSound = false;
    _serverSoundUrl = null;
    await _player?.stop();
    await init();
  }

  /// 播放消息通知铃声
  Future<void> playMessageSound() async {
    if (!_initialized) {
      await init();
    }

    // 防止重复播放
    if (_isPlaying) {
      print('[NotificationSoundService] 正在播放中，跳过');
      return;
    }

    try {
      if (_hasSound && _player != null) {
        _isPlaying = true;

        // 停止之前的播放并重置位置
        await _player!.stop();
        await _player!.seek(Duration.zero);

        // 设置音量并播放
        await _player!.setVolume(0.8);
        await _player!.play();

        print('[NotificationSoundService] 播放铃声成功');
      } else {
        // 使用系统反馈作为备用
        await _playSystemFeedback();
      }
    } catch (e) {
      print('[NotificationSoundService] 播放失败: $e');
      _isPlaying = false;
      // 备用方案
      await _playSystemFeedback();
    }
  }

  /// 播放系统反馈（震动或系统音）
  Future<void> _playSystemFeedback() async {
    try {
      if (kIsWeb) {
        // Web平台暂不支持
        print('[NotificationSoundService] Web平台，跳过系统反馈');
      } else {
        // 移动平台：使用震动反馈
        await HapticFeedback.mediumImpact();
        await SystemSound.play(SystemSoundType.alert);
        print('[NotificationSoundService] 播放系统反馈');
      }
    } catch (e) {
      print('[NotificationSoundService] 系统反馈失败: $e');
    }
  }

  /// 仅播放震动反馈
  Future<void> playVibration() async {
    try {
      if (kIsWeb) {
        print('[NotificationSoundService] Web平台，跳过震动');
        return;
      }
      await HapticFeedback.mediumImpact();
      print('[NotificationSoundService] 播放震动反馈');
    } catch (e) {
      print('[NotificationSoundService] 震动失败: $e');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await _player?.stop();
    await _player?.dispose();
    _player = null;
    _initialized = false;
    _hasSound = false;
    _isPlaying = false;
    _serverSoundUrl = null;
  }
}
