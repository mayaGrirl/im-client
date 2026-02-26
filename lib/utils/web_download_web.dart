/// Web download implementation for web platform
/// This file is only used when compiling for web

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadFileWeb(List<int> bytes, String filename) async {
  // Create a Blob from the bytes
  final blob = html.Blob([Uint8List.fromList(bytes)]);

  // Create a URL for the Blob
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Create an anchor element with download attribute
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';

  // Add to DOM, click, and remove
  html.document.body?.children.add(anchor);
  anchor.click();

  // Clean up
  html.document.body?.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}
