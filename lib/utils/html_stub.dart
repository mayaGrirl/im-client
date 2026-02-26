/// HTML stub for non-web platforms
/// This file provides mock implementations for dart:html APIs
/// when compiling for non-web platforms

class Window {
  Navigator get navigator => Navigator();
}

class Navigator {
  String get userAgent => '';
  int? get maxTouchPoints => 0;
}

Window get window => Window();
