// Stub implementation for non-web platforms

/// Register a web video view (stub for non-web platforms)
void registerWebVideoView(String viewId, String url) {
  // No-op on non-web platforms
  throw UnsupportedError('registerWebVideoView is only supported on web');
}

/// Play web video (stub for non-web platforms)
void playWebVideo(String viewId) {
  // No-op on non-web platforms
  throw UnsupportedError('playWebVideo is only supported on web');
}
