/// WebRTC推流到SRS服务
/// 用于Web端推流到SRS服务器，SRS自动转换为RTMP/FLV供观众拉流

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

class WebRTCPublisher {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  String? _streamId;
  String? _apiUrl;
  bool _isPublishing = false;
  String _currentFacingMode = 'user'; // 当前摄像头方向：'user'(前置) 或 'environment'(后置)

  bool get isPublishing => _isPublishing;
  MediaStream? get localStream => _localStream;

  /// 初始化并开始推流
  /// 
  /// [streamId] 直播流ID
  /// [apiUrl] SRS WebRTC API地址，例如：https://ws.kaixin28.com/rtc/v1/publish/
  /// [pushKey] 推流密钥（用于验证）
  /// [audioOnly] 是否仅音频（没有摄像头时使用）
  Future<bool> startPublish({
    required String streamId,
    required String apiUrl,
    String? pushKey,
    bool audioOnly = false,
  }) async {
    try {
      _streamId = streamId;
      _apiUrl = apiUrl;

      // 1. 获取本地媒体流（支持降级到纯音频）
      MediaStream? stream;
      bool isAudioOnly = audioOnly;
      
      if (!audioOnly) {
        // 先尝试获取音视频（优先前置摄像头）
        try {
          final constraints = {
            'audio': true,
            'video': {
              'facingMode': 'user', // 优先前置摄像头
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
              'frameRate': {'ideal': 25},
            },
          };
          debugPrint('[WebRTC推流] 尝试获取音视频流（前置摄像头）');
          stream = await navigator.mediaDevices.getUserMedia(constraints);
          _currentFacingMode = 'user';
          debugPrint('[WebRTC推流] ✅ 音视频流获取成功（前置摄像头）');
        } catch (e) {
          debugPrint('[WebRTC推流] ⚠️ 前置摄像头失败，尝试后置摄像头: $e');
          // 尝试后置摄像头
          try {
            final constraints = {
              'audio': true,
              'video': {
                'facingMode': 'environment', // 后置摄像头
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
                'frameRate': {'ideal': 25},
              },
            };
            stream = await navigator.mediaDevices.getUserMedia(constraints);
            _currentFacingMode = 'environment';
            debugPrint('[WebRTC推流] ✅ 音视频流获取成功（后置摄像头）');
          } catch (e2) {
            debugPrint('[WebRTC推流] ⚠️ 后置摄像头也失败，降级到纯音频: $e2');
            isAudioOnly = true;
          }
        }
      }
      
      // 如果音视频失败或本来就是纯音频模式，尝试获取纯音频
      if (stream == null) {
        try {
          final constraints = {
            'audio': true,
            'video': false,
          };
          debugPrint('[WebRTC推流] 尝试获取纯音频流');
          stream = await navigator.mediaDevices.getUserMedia(constraints);
          debugPrint('[WebRTC推流] ✅ 纯音频流获取成功');
        } catch (e) {
          debugPrint('[WebRTC推流] ❌ 纯音频流获取失败: $e');
          // 检查是否是权限问题
          if (e.toString().contains('NotAllowedError') || 
              e.toString().contains('Permission') ||
              e.toString().contains('denied')) {
            throw Exception('麦克风权限被拒绝，请在浏览器设置中允许麦克风访问');
          } else if (e.toString().contains('NotFoundError')) {
            throw Exception('未检测到麦克风设备，请连接麦克风后重试');
          } else {
            throw Exception('无法获取麦克风: ${e.toString()}');
          }
        }
      }
      
      _localStream = stream;
      debugPrint('[WebRTC推流] 媒体流获取成功(${isAudioOnly ? "仅音频" : "音视频"})');

      // 2. 创建PeerConnection
      final config = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _pc = await createPeerConnection(config);
      debugPrint('[WebRTC推流] PeerConnection创建成功');

      // 3. 添加本地流到PeerConnection
      _localStream!.getTracks().forEach((track) {
        _pc!.addTrack(track, _localStream!);
        debugPrint('[WebRTC推流] 添加轨道: ${track.kind}');
      });

      // 4. 创建Offer
      final offer = await _pc!.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });
      await _pc!.setLocalDescription(offer);
      debugPrint('[WebRTC推流] Offer创建成功');
      
      // 确保SDP包含BUNDLE（SRS要求）
      String sdp = offer.sdp ?? '';
      if (!sdp.contains('a=group:BUNDLE')) {
        debugPrint('[WebRTC推流] ⚠️ SDP缺少BUNDLE，尝试添加...');
        // 提取所有mid
        final midRegex = RegExp(r'a=mid:(\S+)');
        final mids = midRegex.allMatches(sdp).map((m) => m.group(1)).toList();
        if (mids.isNotEmpty) {
          // 在第一个m=行之前插入BUNDLE
          final firstMLine = sdp.indexOf('m=');
          if (firstMLine > 0) {
            final bundleLine = 'a=group:BUNDLE ${mids.join(' ')}\r\n';
            sdp = sdp.substring(0, firstMLine) + bundleLine + sdp.substring(firstMLine);
            // 更新offer
            final modifiedOffer = RTCSessionDescription(sdp, 'offer');
            await _pc!.setLocalDescription(modifiedOffer);
            debugPrint('[WebRTC推流] ✅ BUNDLE已添加: ${mids.join(' ')}');
          }
        }
      } else {
        debugPrint('[WebRTC推流] ✅ SDP已包含BUNDLE');
      }

      // 5. 发送Offer到SRS
      // 解析apiUrl获取host
      final uri = Uri.parse(apiUrl);
      final host = uri.host;
      
      // streamurl格式: webrtc://domain/app/stream?key=xxx
      String streamUrl = 'webrtc://$host/live/$streamId';
      if (pushKey != null && pushKey.isNotEmpty) {
        streamUrl += '?key=$pushKey';
      }
      debugPrint('[WebRTC推流] 推流地址: $streamUrl');
      debugPrint('[WebRTC推流] API地址: $apiUrl');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api': apiUrl,  // 使用完整的HTTPS URL
          'streamurl': streamUrl,
          'sdp': sdp,  // 使用修改后的SDP
          // 添加key参数到请求体（SRS会将其作为param传递给回调）
          if (pushKey != null && pushKey.isNotEmpty) 'key': pushKey,
        }),
      );

      debugPrint('[WebRTC推流] SRS响应状态码: ${response.statusCode}');
      debugPrint('[WebRTC推流] SRS响应内容: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('SRS API错误: ${response.statusCode} ${response.body}');
      }

      final result = jsonDecode(response.body);
      if (result['code'] != 0) {
        throw Exception('SRS返回错误: ${result['code']} ${result['msg'] ?? result['data']}');
      }

      debugPrint('[WebRTC推流] SRS响应成功');

      // 6. 设置远端SDP
      final answerSdp = result['sdp'] as String?;
      if (answerSdp == null || answerSdp.isEmpty) {
        throw Exception('SRS未返回SDP');
      }
      
      final answer = RTCSessionDescription(answerSdp, 'answer');
      await _pc!.setRemoteDescription(answer);
      debugPrint('[WebRTC推流] 远端SDP设置成功');

      // 7. 监听ICE连接状态
      _pc!.onIceConnectionState = (state) {
        debugPrint('[WebRTC推流] ICE连接状态: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          _isPublishing = true;
          debugPrint('[WebRTC推流] ✅ 推流成功！');
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
                   state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          _isPublishing = false;
          debugPrint('[WebRTC推流] ❌ 推流失败或断开');
        }
      };

      return true;
    } catch (e) {
      debugPrint('[WebRTC推流] ❌ 推流失败: $e');
      await stopPublish();
      return false;
    }
  }

  /// 停止推流
  Future<void> stopPublish() async {
    debugPrint('[WebRTC推流] 停止推流');
    
    _isPublishing = false;

    // 停止所有轨道
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    await _localStream?.dispose();
    _localStream = null;

    // 关闭PeerConnection
    await _pc?.close();
    _pc = null;

    _streamId = null;
    _apiUrl = null;
  }

  /// 切换摄像头（前后摄像头）
  /// 返回 true 表示切换成功，外部需要更新 RTCVideoRenderer
  Future<bool> switchCamera() async {
    if (_localStream == null || _pc == null) return false;

    try {
      // Web端需要重新获取媒体流来切换摄像头
      if (kIsWeb) {
        debugPrint('[WebRTC推流] Web端切换摄像头：重新获取媒体流');
        
        // 保存当前音频轨道状态
        final audioEnabled = _localStream!.getAudioTracks().firstOrNull?.enabled ?? true;
        
        // 停止当前视频轨道
        for (var track in _localStream!.getVideoTracks()) {
          track.stop();
        }
        
        // 切换facingMode
        final currentFacingMode = _currentFacingMode;
        final newFacingMode = currentFacingMode == 'user' ? 'environment' : 'user';
        
        // 获取新的媒体流
        final newStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': {
            'facingMode': newFacingMode,
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
          },
        });
        
        // 替换视频轨道
        final newVideoTrack = newStream.getVideoTracks().firstOrNull;
        final newAudioTrack = newStream.getAudioTracks().firstOrNull;
        
        if (newVideoTrack != null) {
          // 找到PeerConnection中的视频sender并替换轨道
          final senders = await _pc!.getSenders();
          for (var sender in senders) {
            if (sender.track?.kind == 'video') {
              await sender.replaceTrack(newVideoTrack);
              debugPrint('[WebRTC推流] 已替换视频轨道');
            } else if (sender.track?.kind == 'audio' && newAudioTrack != null) {
              await sender.replaceTrack(newAudioTrack);
              debugPrint('[WebRTC推流] 已替换音频轨道');
            }
          }
          
          // 停止旧流的所有轨道
          _localStream!.getTracks().forEach((track) => track.stop());
          
          // 完全替换本地流
          _localStream = newStream;
          
          // 恢复音频状态
          _localStream!.getAudioTracks().forEach((t) => t.enabled = audioEnabled);
          
          // 更新当前facingMode
          _currentFacingMode = newFacingMode;
          
          debugPrint('[WebRTC推流] Web端摄像头已切换: $currentFacingMode -> $newFacingMode');
          return true; // 返回true表示需要更新renderer
        }
      } else {
        // 移动端使用Helper.switchCamera
        final videoTrack = _localStream!.getVideoTracks().firstOrNull;
        if (videoTrack != null) {
          await Helper.switchCamera(videoTrack);
          debugPrint('[WebRTC推流] 移动端摄像头已切换');
          return false; // 移动端不需要更新renderer
        }
      }
    } catch (e) {
      debugPrint('[WebRTC推流] 切换摄像头失败: $e');
      rethrow;
    }
    return false;
  }

  /// 切换麦克风静音
  void toggleMute() {
    if (_localStream == null) return;

    final audioTrack = _localStream!.getAudioTracks().firstOrNull;
    if (audioTrack != null) {
      final enabled = audioTrack.enabled;
      audioTrack.enabled = !enabled;
      debugPrint('[WebRTC推流] 麦克风${enabled ? "静音" : "取消静音"}');
    }
  }

  /// 切换摄像头开关
  void toggleVideo() {
    if (_localStream == null) return;

    final videoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      final enabled = videoTrack.enabled;
      videoTrack.enabled = !enabled;
      debugPrint('[WebRTC推流] 摄像头${enabled ? "关闭" : "开启"}');
    }
  }

  /// 获取推流统计信息
  Future<Map<String, dynamic>?> getStats() async {
    if (_pc == null) return null;

    try {
      final stats = await _pc!.getStats();
      // 将List<StatsReport> 转换为Map
      final Map<String, dynamic> statsMap = {};
      for (var report in stats) {
        statsMap[report.id] = report.values;
      }
      return statsMap;
    } catch (e) {
      debugPrint('[WebRTC推流] 获取统计信息失败: $e');
      return null;
    }
  }

  /// 释放资源
  void dispose() {
    stopPublish();
  }
}
