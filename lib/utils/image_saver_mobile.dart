/// 图片保存工具 - 移动端实现
/// 使用 image_gallery_saver_plus 保存到相册

import 'dart:typed_data';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

Future<Map<String, dynamic>> saveImageToGallery(
  List<int> bytes, {
  required String name,
  int quality = 100,
}) async {
  final result = await ImageGallerySaverPlus.saveImage(
    Uint8List.fromList(bytes),
    quality: quality,
    name: name,
  );
  return Map<String, dynamic>.from(result);
}
