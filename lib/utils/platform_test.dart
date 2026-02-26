/// 平台测试工具 - 用于验证条件导入是否正确工作
import 'package:flutter/foundation.dart';
import 'audio_manager.dart';

class PlatformTest {
  /// 测试 AudioManager 是否正确加载
  static Future<void> testAudioManager() async {
    debugPrint('=== 平台测试开始 ===');
    debugPrint('当前平台: ${kIsWeb ? "Web" : "移动"}');
    
    try {
      // 尝试调用 setSpeakerphoneOn
      await AudioManager.setSpeakerphoneOn(true);
      debugPrint('✓ AudioManager.setSpeakerphoneOn 调用成功（无异常）');
      
      // 尝试获取状态
      final isOn = await AudioManager.isSpeakerphoneOn();
      debugPrint('✓ AudioManager.isSpeakerphoneOn 返回: $isOn');
      
      if (kIsWeb) {
        debugPrint('✓ Web 平台：AudioManager 正确使用 Web 实现');
      } else {
        debugPrint('✓ 移动平台：AudioManager 正确使用移动实现');
      }
    } catch (e) {
      debugPrint('✗ AudioManager 测试失败: $e');
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('✗ 错误：条件导入未生效，仍在使用移动平台代码');
        debugPrint('✗ 解决方案：执行 flutter clean && flutter pub get && flutter build web');
      }
    }
    
    debugPrint('=== 平台测试结束 ===');
  }
}
