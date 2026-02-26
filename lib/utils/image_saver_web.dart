/// 图片保存工具 - Web实现
/// 使用浏览器下载功能

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<Map<String, dynamic>> saveImageToGallery(
  List<int> bytes, {
  required String name,
  int quality = 100,
}) async {
  try {
    // 创建 Blob
    final blob = html.Blob([Uint8List.fromList(bytes)], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);

    // 创建下载链接
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '$name.png')
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);

    // 释放 URL
    html.Url.revokeObjectUrl(url);

    return {'isSuccess': true, 'filePath': name};
  } catch (e) {
    return {'isSuccess': false, 'error': e.toString()};
  }
}
