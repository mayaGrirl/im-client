// Web-specific implementation for livestream viewer
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Register a web video view with the given viewId and URL
void registerWebVideoView(String viewId, String url) {
  // Register a platform view factory for web video player
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) {
      final videoElement = html.VideoElement()
        ..src = url
        ..autoplay = true
        ..controls = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain';
      
      return videoElement;
    },
  );
}

/// Play web video with the given viewId
void playWebVideo(String viewId) {
  // Find the video element and play it
  final videoElement = html.document.querySelector('video') as html.VideoElement?;
  videoElement?.play();
}
