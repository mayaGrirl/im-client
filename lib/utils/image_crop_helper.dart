/// 图片裁剪工具
/// 支持头像（1:1圆形）和背景图（16:9矩形）裁剪

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// 裁剪类型
enum CropType {
  /// 头像 - 1:1 正方形，圆形预览
  avatar,

  /// 背景图 - 16:9 矩形
  background,
}

class ImageCropHelper {
  ImageCropHelper._();

  /// 选择并裁剪图片
  /// [source] 图片来源（相机/相册）
  /// [cropType] 裁剪类型
  /// 返回裁剪后的文件路径，取消返回null
  static Future<String?> pickAndCrop(
    BuildContext context,
    ImageSource source,
    CropType cropType,
  ) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: cropType == CropType.avatar ? 800 : 1920,
      maxHeight: cropType == CropType.avatar ? 800 : 1080,
      imageQuality: 85,
    );

    if (pickedFile == null) return null;

    return cropImage(context, pickedFile.path, cropType);
  }

  /// 裁剪已有图片
  static Future<String?> cropImage(
    BuildContext context,
    String imagePath,
    CropType cropType,
  ) async {
    final List<CropAspectRatioPreset> presets;
    final CropAspectRatioPreset initialPreset;
    final CropStyle cropStyle;

    switch (cropType) {
      case CropType.avatar:
        cropStyle = CropStyle.circle;
        initialPreset = CropAspectRatioPreset.square;
        presets = [CropAspectRatioPreset.square];
        break;
      case CropType.background:
        cropStyle = CropStyle.rectangle;
        initialPreset = CropAspectRatioPreset.ratio16x9;
        presets = [
          CropAspectRatioPreset.ratio16x9,
          CropAspectRatioPreset.ratio3x2,
          CropAspectRatioPreset.ratio4x3,
        ];
        break;
    }

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      aspectRatio: cropType == CropType.avatar
          ? const CropAspectRatio(ratioX: 1, ratioY: 1)
          : const CropAspectRatio(ratioX: 16, ratioY: 9),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: cropType == CropType.avatar ? 'Crop Avatar' : 'Crop Image',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF07C160),
          statusBarColor: Colors.black,
          backgroundColor: Colors.black,
          cropStyle: cropStyle,
          initAspectRatio: initialPreset,
          lockAspectRatio: cropType == CropType.avatar,
          aspectRatioPresets: presets,
        ),
        IOSUiSettings(
          title: cropType == CropType.avatar ? 'Crop Avatar' : 'Crop Image',
          cropStyle: cropStyle,
          aspectRatioPresets: presets,
          aspectRatioLockEnabled: cropType == CropType.avatar,
          resetAspectRatioEnabled: cropType != CropType.avatar,
        ),
        WebUiSettings(
          context: context,
          size: const CropperSize(width: 400, height: 400),
        ),
      ],
    );

    return croppedFile?.path;
  }

  /// 显示图片来源选择底部弹窗并裁剪
  static Future<String?> showPickerAndCrop(
    BuildContext context,
    CropType cropType, {
    String? cameraLabel,
    String? galleryLabel,
    String? cancelLabel,
  }) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(cameraLabel ?? 'Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(galleryLabel ?? 'Select from Album'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(cancelLabel ?? 'Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );

    if (source == null) return null;
    return pickAndCrop(context, source, cropType);
  }
}
