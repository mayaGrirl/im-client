/// 文件上传 API
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'api_client.dart';

class UploadApi {
  final ApiClient _client;

  UploadApi(this._client);

  /// 上传图片
  Future<UploadResult?> uploadImage(dynamic file, {String type = 'chat', String? filename}) async {
    return _uploadFile('/upload/image', file, type: type, filename: filename ?? 'image.jpg');
  }

  /// 上传视频
  Future<UploadResult?> uploadVideo(dynamic file, {String? filename}) async {
    return _uploadFile('/upload/video', file, type: 'chat', filename: filename ?? 'video.mp4');
  }

  /// 上传音频
  Future<UploadResult?> uploadAudio(dynamic file, {String? filename}) async {
    return _uploadFile('/upload/audio', file, type: 'chat', filename: filename ?? 'audio.m4a');
  }

  /// 上传通用文件
  Future<UploadResult?> uploadFile(dynamic file, {String? filename}) async {
    return _uploadFile('/upload/file', file, type: 'chat', filename: filename ?? 'file.dat');
  }

  /// 上传头像
  Future<UploadResult?> uploadAvatar(dynamic file, {String? filename}) async {
    return _uploadFile('/upload/avatar', file, type: 'avatar', filename: filename ?? 'avatar.jpg');
  }

  /// 通用上传方法
  Future<UploadResult?> _uploadFile(String path, dynamic file, {String type = 'chat', String? filename}) async {
    try {
      ApiResponse response;

      print('[UploadApi] Starting upload to $path, filename: $filename, type: $type');

      if (kIsWeb) {
        // Web 平台：使用字节上传
        if (file is List<int>) {
          print('[UploadApi] Web platform, uploading ${file.length} bytes');
          response = await _client.uploadBytes(
            path,
            file,
            filename ?? 'file.dat',
            extraData: {'type': type},
          );
        } else {
          print('[UploadApi] Error: Web platform requires List<int> bytes, got ${file.runtimeType}');
          return null;
        }
      } else {
        // 移动端：使用文件路径上传
        String filePath;
        if (file is File) {
          filePath = file.path;
        } else if (file is String) {
          filePath = file;
        } else {
          print('[UploadApi] Error: Invalid file type ${file.runtimeType}');
          return null;
        }
        print('[UploadApi] Mobile platform, uploading file: $filePath');
        response = await _client.upload(
          path,
          filePath,
          extraData: {'type': type},
        );
      }

      print('[UploadApi] Response: success=${response.success}, code=${response.code}, message=${response.message}');
      print('[UploadApi] Response data: ${response.data}');

      if (response.success && response.data != null) {
        final result = UploadResult.fromJson(response.data);
        print('[UploadApi] Upload successful, url: ${result.url}');
        return result;
      }
      print('[UploadApi] Upload failed: ${response.message}');
      return null;
    } catch (e, stackTrace) {
      print('[UploadApi] Upload error: $e');
      print('[UploadApi] Stack trace: $stackTrace');
      return null;
    }
  }
}

/// 上传结果
class UploadResult {
  final String url;
  final String filename;
  final int size;
  final String? md5;
  final int? width;
  final int? height;
  final int? duration;

  UploadResult({
    required this.url,
    required this.filename,
    required this.size,
    this.md5,
    this.width,
    this.height,
    this.duration,
  });

  factory UploadResult.fromJson(dynamic json) {
    if (json == null) {
      print('[UploadResult] Error: json is null');
      return UploadResult(url: '', filename: '', size: 0);
    }

    if (json is! Map<String, dynamic>) {
      print('[UploadResult] Error: json is not a Map, type: ${json.runtimeType}');
      return UploadResult(url: '', filename: '', size: 0);
    }

    final url = json['url']?.toString() ?? '';
    final filename = json['filename']?.toString() ?? '';
    final size = (json['size'] is int) ? json['size'] : int.tryParse(json['size']?.toString() ?? '0') ?? 0;

    print('[UploadResult] Parsing: url=$url, filename=$filename, size=$size');

    return UploadResult(
      url: url,
      filename: filename,
      size: size,
      md5: json['md5']?.toString(),
      width: json['width'] is int ? json['width'] : int.tryParse(json['width']?.toString() ?? ''),
      height: json['height'] is int ? json['height'] : int.tryParse(json['height']?.toString() ?? ''),
      duration: json['duration'] is int ? json['duration'] : int.tryParse(json['duration']?.toString() ?? ''),
    );
  }
}
