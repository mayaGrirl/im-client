/// Web download stub for non-web platforms
/// This file is used when compiling for iOS, Android, etc.

Future<void> downloadFileWeb(List<int> bytes, String filename) async {
  // No-op on non-web platforms
  throw UnsupportedError('Web download is not supported on this platform');
}
