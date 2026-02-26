/// 语音录制服务
/// 处理语音消息的录制

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecordService {
  static final VoiceRecordService _instance = VoiceRecordService._internal();
  factory VoiceRecordService() => _instance;
  VoiceRecordService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;
  DateTime? _startTime;
  Timer? _durationTimer;
  int _recordDuration = 0; // 录音时长（秒）

  // 最大录音时长（秒）
  static const int maxDuration = 60;

  /// 是否正在录音
  bool get isRecording => _isRecording;

  /// 当前录音时长（秒）
  int get recordDuration => _recordDuration;

  /// 录音时长流
  final _durationController = StreamController<int>.broadcast();
  Stream<int> get durationStream => _durationController.stream;

  /// 检查并请求麦克风权限
  Future<bool> checkPermission() async {
    if (kIsWeb) {
      // Web 平台需要特殊处理
      return await _recorder.hasPermission();
    }

    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  /// 开始录音
  Future<bool> startRecording() async {
    try {
      // 检查权限
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        print('[VoiceRecordService] 没有麦克风权限');
        return false;
      }

      // 检查是否可以录音
      if (!await _recorder.hasPermission()) {
        print('[VoiceRecordService] 录音权限被拒绝');
        return false;
      }

      // 生成录音文件路径
      _currentPath = await _getRecordPath();
      if (_currentPath == null) {
        print('[VoiceRecordService] 无法获取录音路径');
        return false;
      }

      // 配置录音参数
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      // 开始录音
      await _recorder.start(config, path: _currentPath!);
      _isRecording = true;
      _startTime = DateTime.now();
      _recordDuration = 0;

      // 启动计时器
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordDuration++;
        _durationController.add(_recordDuration);

        // 达到最大时长自动停止
        if (_recordDuration >= maxDuration) {
          stopRecording();
        }
      });

      print('[VoiceRecordService] 开始录音: $_currentPath');
      return true;
    } catch (e) {
      print('[VoiceRecordService] 开始录音失败: $e');
      _isRecording = false;
      return false;
    }
  }

  /// 停止录音并返回录音文件路径和时长
  Future<VoiceRecordResult?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }

    try {
      // 停止计时器
      _durationTimer?.cancel();
      _durationTimer = null;

      // 停止录音
      final path = await _recorder.stop();
      _isRecording = false;

      final duration = _recordDuration;
      _recordDuration = 0;
      _durationController.add(0);

      if (path == null || path.isEmpty) {
        print('[VoiceRecordService] 录音文件路径为空');
        return null;
      }

      // 检查录音时长是否太短
      if (duration < 1) {
        print('[VoiceRecordService] 录音时长太短');
        // 删除文件（仅移动端）
        if (!kIsWeb) {
          try {
            await File(path).delete();
          } catch (_) {}
        }
        return null;
      }

      print('[VoiceRecordService] 录音完成: path=$path, duration=$duration');
      return VoiceRecordResult(path: path, duration: duration);
    } catch (e) {
      print('[VoiceRecordService] 停止录音失败: $e');
      _isRecording = false;
      return null;
    }
  }

  /// 取消录音
  Future<void> cancelRecording() async {
    if (!_isRecording) {
      return;
    }

    try {
      _durationTimer?.cancel();
      _durationTimer = null;

      final path = await _recorder.stop();
      _isRecording = false;
      _recordDuration = 0;
      _durationController.add(0);

      // 删除录音文件（仅移动端）
      if (path != null && path.isNotEmpty && !kIsWeb) {
        try {
          await File(path).delete();
          print('[VoiceRecordService] 录音已取消并删除');
        } catch (_) {}
      }
    } catch (e) {
      print('[VoiceRecordService] 取消录音失败: $e');
      _isRecording = false;
    }
  }

  /// 获取录音文件路径
  Future<String?> _getRecordPath() async {
    try {
      if (kIsWeb) {
        // Web 平台使用临时名称
        return 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      final dir = await getTemporaryDirectory();
      final voiceDir = Directory('${dir.path}/voice');
      if (!await voiceDir.exists()) {
        await voiceDir.create(recursive: true);
      }
      return '${voiceDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    } catch (e) {
      print('[VoiceRecordService] 获取录音路径失败: $e');
      return null;
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    _durationTimer?.cancel();
    await _recorder.dispose();
    await _durationController.close();
  }
}

/// 录音结果
class VoiceRecordResult {
  final String path;
  final int duration; // 秒

  VoiceRecordResult({required this.path, required this.duration});
}
