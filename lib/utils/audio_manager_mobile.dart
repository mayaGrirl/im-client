/// 音频管理工具类 - 移动平台实现（Android/iOS）
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class AudioManager {
  static const MethodChannel _channel = MethodChannel('com.im.im_client/audio_manager');

  /// 设置扬声器状态
  static Future<void> setSpeakerphoneOn(bool enabled) async {
    try {
      // 优先使用原生插件（仅 Android）
      if (Platform.isAndroid) {
        await _channel.invokeMethod('setSpeakerphoneOn', {'enabled': enabled});
      } else {
        // iOS 和其他平台使用 flutter_webrtc 的方法
        await Helper.setSpeakerphoneOn(enabled);
      }
    } catch (e) {
      print('[AudioManager] 设置扬声器失败: $e');
    }
  }

  /// 获取当前扬声器状态
  static Future<bool> isSpeakerphoneOn() async {
    try {
      final result = await _channel.invokeMethod('isSpeakerphoneOn');
      return result as bool? ?? false;
    } catch (e) {
      // 忽略错误，返回默认值
      return false;
    }
  }
}
