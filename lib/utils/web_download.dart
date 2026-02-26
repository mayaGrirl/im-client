/// Web download conditional export
/// Automatically selects the correct implementation based on platform

export 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart';
