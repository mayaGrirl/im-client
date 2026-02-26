/// 音频管理工具类 - 抽象接口
class AudioManager {
  /// 设置扬声器状态
  static Future<void> setSpeakerphoneOn(bool enabled) async {
    throw UnsupportedError('AudioManager is not supported on this platform');
  }

  /// 获取当前扬声器状态
  static Future<bool> isSpeakerphoneOn() async {
    throw UnsupportedError('AudioManager is not supported on this platform');
  }
}
