/// 通话铃声服务
/// 处理来电铃声、去电等待音和震动

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:im_client/services/settings_service.dart';
import 'package:im_client/services/chat_settings_service.dart';
import 'package:im_client/utils/conversation_utils.dart';

class CallRingtoneService {
  static final CallRingtoneService _instance = CallRingtoneService._internal();
  factory CallRingtoneService() => _instance;
  CallRingtoneService._internal();

  AudioPlayer? _ringtonePlayer; // 来电铃声
  AudioPlayer? _dialingPlayer; // 去电等待音
  Timer? _vibrationTimer;
  bool _initialized = false;
  bool _isRinging = false;
  bool _isDialing = false;

  bool _hasRingtone = false;
  bool _hasDialingTone = false;
  bool _usingCustomRingtone = false;

  // Web端iOS Safari音频解锁状态
  bool _webAudioUnlocked = false;

  /// 初始化
  Future<void> init() async {
    if (_initialized) return;

    try {
      _ringtonePlayer = AudioPlayer();
      _dialingPlayer = AudioPlayer();

      // 加载来电铃声
      await _loadRingtone();

      // 加载去电等待音（优先使用专用音，否则使用消息提示音）
      await _loadDialingTone();

      _initialized = true;
      debugPrint('[CallRingtoneService] 初始化成功, hasRingtone=$_hasRingtone, hasDialingTone=$_hasDialingTone, usingCustom=$_usingCustomRingtone');
    } catch (e) {
      debugPrint('[CallRingtoneService] 初始化失败: $e');
      _initialized = true; // 标记为已初始化，避免重复尝试
    }
  }

  /// Web端解锁音频播放（iOS Safari/Chrome需要用户交互后才能播放音频）
  /// 应在用户首次点击/触摸时调用此方法
  Future<void> unlockWebAudio() async {
    if (!kIsWeb || _webAudioUnlocked) return;

    debugPrint('[CallRingtoneService] 尝试解锁Web音频...');

    // 确保已初始化
    if (!_initialized) {
      await init();
    }

    try {
      // 通过播放静音音频来解锁Web音频上下文
      // iOS Safari/Chrome要求在用户交互时触发音频播放
      if (_ringtonePlayer != null && _hasRingtone) {
        await _ringtonePlayer!.setVolume(0.01); // 设置极低音量而非0，某些浏览器对0音量不解锁
        await _ringtonePlayer!.seek(Duration.zero);
        await _ringtonePlayer!.play();
        await Future.delayed(const Duration(milliseconds: 100));
        await _ringtonePlayer!.pause();
        await _ringtonePlayer!.setVolume(1.0);
        debugPrint('[CallRingtoneService] 来电铃声播放器已解锁');
      }

      if (_dialingPlayer != null && _hasDialingTone) {
        await _dialingPlayer!.setVolume(0.01);
        await _dialingPlayer!.seek(Duration.zero);
        await _dialingPlayer!.play();
        await Future.delayed(const Duration(milliseconds: 100));
        await _dialingPlayer!.pause();
        await _dialingPlayer!.setVolume(0.8);
        debugPrint('[CallRingtoneService] 去电等待音播放器已解锁');
      }

      _webAudioUnlocked = true;
      debugPrint('[CallRingtoneService] Web音频解锁成功');
    } catch (e) {
      debugPrint('[CallRingtoneService] Web音频解锁失败: $e');
      // 即使失败也标记为已尝试，避免重复尝试
      _webAudioUnlocked = true;
    }
  }

  /// 检查Web音频是否已解锁
  bool get isWebAudioUnlocked => _webAudioUnlocked || !kIsWeb;

  /// 加载去电等待音
  Future<void> _loadDialingTone() async {
    _hasDialingTone = false;

    // 尝试的音频文件列表（按优先级，匹配assets/sounds/中的实际文件）
    final audioFiles = [
      'dialing.wav',
      'ringtone.mp3',
      'message.mp3',
    ];

    for (final fileName in audioFiles) {
      try {
        await _dialingPlayer!.setAsset('assets/sounds/$fileName');
        await _dialingPlayer!.setLoopMode(LoopMode.one);
        _hasDialingTone = true;
        debugPrint('[CallRingtoneService] 已加载去电等待音: $fileName');
        return;
      } catch (e) {
        debugPrint('[CallRingtoneService] $fileName 加载失败，尝试下一个');
      }
    }

    debugPrint('[CallRingtoneService] 所有去电等待音都加载失败');
  }

  /// 加载来电铃声（优先使用用户自定义铃声）
  Future<void> _loadRingtone() async {
    _hasRingtone = false;
    _usingCustomRingtone = false;

    final settingsService = SettingsService();
    final customRingtone = settingsService.customRingtone;

    // 1. 优先尝试加载用户自定义铃声
    if (customRingtone != null && customRingtone.isNotEmpty) {
      try {
        if (customRingtone.startsWith('http://') || customRingtone.startsWith('https://')) {
          // 服务器URL
          await _ringtonePlayer!.setUrl(customRingtone);
          await _ringtonePlayer!.setLoopMode(LoopMode.one);
          _hasRingtone = true;
          _usingCustomRingtone = true;
          debugPrint('[CallRingtoneService] 已加载服务器自定义铃声: $customRingtone');
          return;
        } else if (!kIsWeb) {
          // 移动/桌面平台：从本地文件加载
          final file = File(customRingtone);
          if (await file.exists()) {
            await _ringtonePlayer!.setFilePath(customRingtone);
            await _ringtonePlayer!.setLoopMode(LoopMode.one);
            _hasRingtone = true;
            _usingCustomRingtone = true;
            debugPrint('[CallRingtoneService] 已加载本地自定义铃声: $customRingtone');
            return;
          } else {
            debugPrint('[CallRingtoneService] 自定义铃声文件不存在: $customRingtone');
          }
        }
      } catch (e) {
        debugPrint('[CallRingtoneService] 加载自定义铃声失败: $e');
      }
    }

    // 2. 尝试加载默认铃声文件（按优先级，匹配assets/sounds/中的实际文件）
    final audioFiles = [
      'ringtone.mp3',
      'message.mp3',
    ];
    for (final fileName in audioFiles) {
      try {
        await _ringtonePlayer!.setAsset('assets/sounds/$fileName');
        await _ringtonePlayer!.setLoopMode(LoopMode.one);
        _hasRingtone = true;
        debugPrint('[CallRingtoneService] 已加载来电铃声: $fileName');
        return;
      } catch (e) {
        debugPrint('[CallRingtoneService] $fileName 加载失败，尝试下一个');
      }
    }

    debugPrint('[CallRingtoneService] 所有来电铃声都加载失败');
    _hasRingtone = false;
  }

  /// 重新加载铃声（用于设置更改后）
  Future<void> reloadRingtone() async {
    if (_ringtonePlayer != null) {
      await _ringtonePlayer!.stop();
      await _loadRingtone();
      debugPrint('[CallRingtoneService] 铃声已重新加载');
    }
  }

  /// 检查是否应该播放铃声
  /// [targetUserId] 通话对方的用户ID
  /// [currentUserId] 当前用户ID
  Future<bool> shouldPlayRingtone(int targetUserId, int currentUserId) async {
    final settingsService = SettingsService();
    final chatSettingsService = ChatSettingsService();

    // 检查全局声音设置
    if (!settingsService.messageSound) {
      debugPrint('[CallRingtoneService] 全局声音已关闭');
      return false;
    }

    // 生成会话ID并检查会话免打扰设置
    final conversId = ConversationUtils.generateConversId(
      userId1: targetUserId,
      userId2: currentUserId,
    );

    final shouldPlay = await chatSettingsService.shouldPlaySound(conversId);
    debugPrint('[CallRingtoneService] conversId=$conversId, shouldPlay=$shouldPlay');
    return shouldPlay;
  }

  /// 检查是否应该震动
  Future<bool> shouldVibrate() async {
    final settingsService = SettingsService();
    return settingsService.messageVibrate;
  }

  /// 播放来电铃声（被呼叫方）
  /// [targetUserId] 主叫方用户ID
  /// [currentUserId] 当前用户ID（被呼叫方）
  Future<void> playIncomingRingtone(int targetUserId, int currentUserId) async {
    if (!_initialized) await init();
    if (_isRinging) return;

    // 检查是否应该播放铃声
    final shouldPlay = await shouldPlayRingtone(targetUserId, currentUserId);
    if (!shouldPlay) {
      debugPrint('[CallRingtoneService] 来电铃声被静音设置阻止');
      return;
    }

    _isRinging = true;

    try {
      // Web端检查音频是否已解锁（iOS Safari/Chrome需要用户交互后才能播放）
      if (kIsWeb) {
        if (!_webAudioUnlocked) {
          debugPrint('[CallRingtoneService] Web音频未解锁，来电铃声可能无法播放');
          debugPrint('[CallRingtoneService] 请提示用户点击屏幕以启用声音');
        }

        // 尝试播放，即使未解锁也试一下（某些情况下可能成功）
        if (_hasRingtone && _ringtonePlayer != null) {
          try {
            await _ringtonePlayer!.seek(Duration.zero);
            await _ringtonePlayer!.setVolume(1.0);
            await _ringtonePlayer!.play();
            debugPrint('[CallRingtoneService] Web端开始播放来电铃声');
          } catch (e) {
            debugPrint('[CallRingtoneService] Web端播放来电铃声失败: $e');
            debugPrint('[CallRingtoneService] iOS浏览器需要用户先点击屏幕才能播放音频');
          }
        }
        return;
      }

      // 非Web平台正常播放
      if (_hasRingtone && _ringtonePlayer != null) {
        await _ringtonePlayer!.seek(Duration.zero);
        await _ringtonePlayer!.setVolume(1.0);
        await _ringtonePlayer!.play();
        debugPrint('[CallRingtoneService] 开始播放来电铃声');
      } else {
        // 使用系统提示音作为备用
        _playSystemAlert();
      }

      // 检查是否应该震动
      final shouldVibrateNow = await shouldVibrate();
      if (shouldVibrateNow) {
        _startVibration();
      }
    } catch (e) {
      debugPrint('[CallRingtoneService] 播放来电铃声失败: $e');
      _isRinging = false;
    }
  }

  /// 播放去电等待音（主叫方）
  /// [targetUserId] 被呼叫方用户ID
  /// [currentUserId] 当前用户ID（主叫方）
  Future<void> playDialingTone(int targetUserId, int currentUserId) async {
    if (!_initialized) await init();
    if (_isDialing) return;

    // 去电等待音（回铃音）始终播放，不受消息免打扰设置影响
    _isDialing = true;

    try {
      if (_hasDialingTone && _dialingPlayer != null) {
        await _dialingPlayer!.seek(Duration.zero);
        await _dialingPlayer!.setVolume(0.8);
        await _dialingPlayer!.play();
        debugPrint('[CallRingtoneService] 开始播放去电等待音');
      }
    } catch (e) {
      debugPrint('[CallRingtoneService] 播放去电等待音失败: $e');
      _isDialing = false;
    }
  }

  /// 播放系统提示音（备用）
  Timer? _systemAlertTimer;

  void _playSystemAlert() {
    if (kIsWeb) return;

    _systemAlertTimer?.cancel();
    _systemAlertTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      SystemSound.play(SystemSoundType.alert);
    });
    // 立即播放一次
    SystemSound.play(SystemSoundType.alert);
  }

  void _stopSystemAlert() {
    _systemAlertTimer?.cancel();
    _systemAlertTimer = null;
  }

  /// 开始震动（循环震动）
  void _startVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _vibrate();
    });
    // 立即震动一次
    _vibrate();
  }

  /// 执行震动
  Future<void> _vibrate() async {
    if (kIsWeb) return;

    try {
      await HapticFeedback.vibrate();
    } catch (e) {
      debugPrint('[CallRingtoneService] 震动失败: $e');
    }
  }

  /// 停止来电铃声
  Future<void> stopIncomingRingtone() async {
    if (!_isRinging) return;

    _isRinging = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    _stopSystemAlert();

    try {
      await _ringtonePlayer?.stop();
      debugPrint('[CallRingtoneService] 停止来电铃声');
    } catch (e) {
      debugPrint('[CallRingtoneService] 停止来电铃声失败: $e');
    }
  }

  /// 停止去电等待音
  Future<void> stopDialingTone() async {
    if (!_isDialing) return;

    _isDialing = false;

    try {
      await _dialingPlayer?.stop();
      debugPrint('[CallRingtoneService] 停止去电等待音');
    } catch (e) {
      debugPrint('[CallRingtoneService] 停止去电等待音失败: $e');
    }
  }

  /// 停止所有铃声和震动
  Future<void> stopAll() async {
    await stopIncomingRingtone();
    await stopDialingTone();
  }

  /// 释放资源
  Future<void> dispose() async {
    await stopAll();
    _systemAlertTimer?.cancel();
    _systemAlertTimer = null;
    await _ringtonePlayer?.dispose();
    await _dialingPlayer?.dispose();
    _ringtonePlayer = null;
    _dialingPlayer = null;
    _initialized = false;
  }
}
