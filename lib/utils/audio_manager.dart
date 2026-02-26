/// 音频管理工具类 - 平台特定实现
export 'audio_manager_stub.dart'
    if (dart.library.io) 'audio_manager_mobile.dart'
    if (dart.library.html) 'audio_manager_web.dart';
