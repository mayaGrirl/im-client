/// URL Helper - 跨平台URL处理工具
/// 自动根据平台选择正确的实现

export 'url_helper_stub.dart' if (dart.library.html) 'url_helper_web.dart';
