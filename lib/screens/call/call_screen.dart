/// 通话界面 - 语音/视频通话主屏幕
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:im_client/api/call_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/services/webrtc_service.dart';
import 'package:im_client/providers/auth_provider.dart';

class CallScreen extends StatefulWidget {
  final int targetUserId;
  final String targetUserName;
  final String targetUserAvatar;
  final int callType;
  final bool isIncoming;
  final String? callId;

  const CallScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    required this.targetUserAvatar,
    required this.callType,
    this.isIncoming = false,
    this.callId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  bool _isInitialized = false;
  String _statusText = '';
  bool _isEnding = false; // 防止重复结束通话

  @override
  void initState() {
    super.initState();
    // 使用 addPostFrameCallback 确保 context 完全就绪后再初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  Future<void> _init() async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      // l10n 未就绪，延迟重试
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _init();
      });
      return;
    }

    // 先设置回调，确保在任何操作之前回调已经就绪
    _webrtcService.onCallConnected = () {
      if (mounted) {
        final currentL10n = AppLocalizations.of(context);
        setState(() {
          _statusText = currentL10n?.translate('in_call') ?? '通话中';
        });
      }
    };

    _webrtcService.onCallEnded = (reason) {
      _handleCallEnded(reason);
    };

    _webrtcService.addListener(_updateState);

    // 设置当前用户ID（用于铃声设置判断）
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userId > 0) {
      _webrtcService.setCurrentUserId(authProvider.userId);
    }

    // 初始化WebRTC服务
    try {
      await _webrtcService.initialize();
    } catch (e) {
      // WebRTC init failed
      _handleCallEnded(l10n.translate('init_failed'));
      return;
    }

    if (!mounted) return;

    setState(() {
      _isInitialized = true;
    });

    if (widget.isIncoming) {
      _statusText = l10n.translate('incoming_call_status');
    } else {
      _statusText = l10n.translate('calling');
      // 发起呼叫
      _startCall();
    }
  }

  /// 处理通话结束
  void _handleCallEnded(String reason) {
    if (!mounted || _isEnding) return;
    _isEnding = true;

    // 使用 addPostFrameCallback 确保在当前帧结束后执行导航
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
        // 延迟显示SnackBar，确保导航完成
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(reason),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });
      }
    });
  }

  void _updateState() {
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      if (l10n == null) return;
      setState(() {
        switch (_webrtcService.callState) {
          case CallState.outgoing:
            _statusText = l10n.translate('calling');
            break;
          case CallState.incoming:
            _statusText = l10n.translate('incoming_call_status');
            break;
          case CallState.connecting:
            _statusText = l10n.translate('connecting_call');
            break;
          case CallState.connected:
            _statusText = l10n.translate('in_call');
            break;
          case CallState.ended:
            _statusText = l10n.translate('call_ended_status');
            break;
          default:
            break;
        }
      });
    }
  }

  Future<void> _startCall() async {
    await _webrtcService.startCall(
      targetUserId: widget.targetUserId,
      targetUserName: widget.targetUserName,
      targetUserAvatar: widget.targetUserAvatar,
      callType: widget.callType,
    );
  }

  Future<void> _answerCall() async {
    await _webrtcService.answerCall();
  }

  Future<void> _rejectCall() async {
    if (_isEnding) return;
    _isEnding = true;
    await _webrtcService.rejectCall();
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _endCall() async {
    if (_isEnding) return;
    // endCall 会触发 onCallEnded 回调，由回调处理导航
    await _webrtcService.endCall();
  }

  String _getFullUrl(String url) {
    if (url.isEmpty || url == '/') return '';
    if (url.startsWith('http')) return url;
    return EnvConfig.instance.getFileUrl(url);
  }

  @override
  void dispose() {
    _webrtcService.removeListener(_updateState);
    // 清除回调，防止页面销毁后还被调用
    _webrtcService.onCallConnected = null;
    _webrtcService.onCallEnded = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isVideo = widget.callType == CallType.video;
    final isConnected = _webrtcService.callState == CallState.connected;
    final isIncoming = widget.isIncoming && _webrtcService.callState == CallState.incoming;

    return Scaffold(
      backgroundColor: isVideo ? Colors.black : const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Stack(
          children: [
            // 视频背景（视频通话时显示远程视频）
            if (isVideo && isConnected)
              Positioned.fill(
                child: RTCVideoView(
                  _webrtcService.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),

            // 本地视频（小窗口）
            if (isVideo && isConnected && _webrtcService.isVideoEnabled)
              Positioned(
                top: 20,
                right: 20,
                width: 120,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(
                    _webrtcService.localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),

            // 主内容
            Column(
              children: [
                const Spacer(),
                // 用户头像和信息（语音通话或未连接时显示）
                if (!isVideo || !isConnected) ...[
                  _buildUserInfo(),
                  const SizedBox(height: 20),
                  Text(
                    _statusText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  if (isConnected) ...[
                    const SizedBox(height: 8),
                    Text(
                      _webrtcService.formattedDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
                const Spacer(),
                // 通话时长（视频通话时显示在底部）
                if (isVideo && isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _webrtcService.formattedDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
                // 控制按钮
                _buildControls(isIncoming, isConnected, isVideo),
                const SizedBox(height: 50),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    final avatarUrl = _getFullUrl(widget.targetUserAvatar);

    return Column(
      children: [
        // 头像
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 3),
          ),
          child: ClipOval(
            child: avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                  )
                : _buildDefaultAvatar(),
          ),
        ),
        const SizedBox(height: 20),
        // 用户名
        Text(
          widget.targetUserName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // 通话类型
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.callType == CallType.video
                  ? Icons.videocam
                  : Icons.call,
              color: Colors.white54,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              widget.callType == CallType.video
                  ? (AppLocalizations.of(context)?.videoCall ?? 'Video Call')
                  : (AppLocalizations.of(context)?.voiceCall ?? 'Voice Call'),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[700],
      child: const Icon(
        Icons.person,
        size: 60,
        color: Colors.white54,
      ),
    );
  }

  Widget _buildControls(bool isIncoming, bool isConnected, bool isVideo) {
    final l10n = AppLocalizations.of(context);

    if (isIncoming) {
      // 来电界面：接听/拒绝按钮
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.red,
            label: l10n?.translate('reject_call') ?? 'Decline',
            onTap: _rejectCall,
          ),
          _buildControlButton(
            icon: isVideo ? Icons.videocam : Icons.call,
            color: Colors.green,
            label: l10n?.translate('answer_call') ?? 'Answer',
            onTap: _answerCall,
          ),
        ],
      );
    }

    if (isConnected) {
      // 通话中界面
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _webrtcService.isMuted ? Icons.mic_off : Icons.mic,
                color: _webrtcService.isMuted ? Colors.red : Colors.white24,
                label: _webrtcService.isMuted ? (l10n?.translate('unmute') ?? 'Unmute') : (l10n?.translate('mute') ?? 'Mute'),
                onTap: () {
                  _webrtcService.toggleMute();
                  setState(() {});
                },
              ),
              // Web 平台不显示扬声器按钮（浏览器不支持）
              if (!kIsWeb)
                _buildControlButton(
                  icon: _webrtcService.isSpeakerOn
                      ? Icons.volume_up
                      : Icons.volume_down,
                  color: _webrtcService.isSpeakerOn ? AppColors.primary : Colors.white24,
                  label: l10n?.translate('speaker') ?? 'Speaker',
                  onTap: () async {
                    await _webrtcService.toggleSpeaker();
                    setState(() {});
                  },
                ),
              if (isVideo)
                _buildControlButton(
                  icon: _webrtcService.isVideoEnabled
                      ? Icons.videocam
                      : Icons.videocam_off,
                  color: _webrtcService.isVideoEnabled
                      ? Colors.white24
                      : Colors.red,
                  label: _webrtcService.isVideoEnabled ? (l10n?.translate('turn_off_video') ?? 'Video Off') : (l10n?.translate('turn_on_video') ?? 'Video On'),
                  onTap: () {
                    _webrtcService.toggleVideo();
                    setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 只在支持摄像头切换时显示按钮
              if (isVideo && _webrtcService.canSwitchCamera)
                _buildControlButton(
                  icon: Icons.cameraswitch,
                  color: Colors.white24,
                  label: l10n?.translate('switch_camera') ?? 'Switch',
                  onTap: () => _webrtcService.switchCamera(),
                ),
              _buildControlButton(
                icon: Icons.call_end,
                color: Colors.red,
                label: l10n?.translate('hang_up') ?? 'Hang Up',
                onTap: _endCall,
                large: true,
              ),
              if (isVideo && _webrtcService.canSwitchCamera) const SizedBox(width: 70),
            ],
          ),
        ],
      );
    }

    // 呼出中界面
    return _buildControlButton(
      icon: Icons.call_end,
      color: Colors.red,
      label: l10n?.translate('cancel_call') ?? 'Cancel',
      onTap: _endCall,
      large: true,
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool large = false,
  }) {
    final size = large ? 70.0 : 56.0;
    final iconSize = large ? 32.0 : 24.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
