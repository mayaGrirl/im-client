/// 音频管理工具类 - Web 平台实现
/// Web 浏览器不支持扬声器控制（安全限制）
class AudioManager {
  /// 设置扬声器状态（Web 平台不支持）
  static Future<void> setSpeakerphoneOn(bool enabled) async {
    // Web 平台不支持扬声器切换，直接返回
    print('[AudioManager] Web 平台不支持扬声器切换');
  }

  /// 获取当前扬声器状态（Web 平台始终返回 false）
  static Future<bool> isSpeakerphoneOn() async {
    return false;
  }
}
