/// 来电悬浮层 - 显示来电通知
import 'package:flutter/material.dart';
import 'package:im_client/api/call_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/services/webrtc_service.dart';
import 'package:im_client/services/notification_service.dart';
import 'package:im_client/screens/call/call_screen.dart';

/// 来电悬浮层
class IncomingCallOverlay extends StatefulWidget {
  final String callId;
  final int callerId;
  final String callerName;
  final String callerAvatar;
  final int callType;
  final VoidCallback onDismiss;

  const IncomingCallOverlay({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerAvatar,
    required this.callType,
    required this.onDismiss,
  });

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  final WebRTCService _webrtcService = WebRTCService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getFullUrl(String url) {
    if (url.isEmpty || url == '/') return '';
    if (url.startsWith('http')) return url;
    return EnvConfig.instance.getFileUrl(url);
  }

  Future<void> _acceptCall() async {
    widget.onDismiss();
    NotificationService().cancelCallNotification();
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          targetUserId: widget.callerId,
          targetUserName: widget.callerName,
          targetUserAvatar: widget.callerAvatar,
          callType: widget.callType,
          isIncoming: true,
          callId: widget.callId,
        ),
      ),
    );
  }

  Future<void> _rejectCall() async {
    await _webrtcService.rejectCall();
    widget.onDismiss();
    NotificationService().cancelCallNotification();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isVideo = widget.callType == CallType.video;
    final avatarUrl = _getFullUrl(widget.callerAvatar);

    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        elevation: 8,
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // 头像
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
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
                  const SizedBox(width: 12),
                  // 信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.callerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isVideo ? Icons.videocam : Icons.call,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isVideo ? (l10n?.videoCall ?? 'Video Call') : (l10n?.voiceCall ?? 'Voice Call'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 拒绝
                  _buildActionButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: l10n?.translate('reject_call') ?? 'Decline',
                    onTap: _rejectCall,
                  ),
                  // 接听
                  _buildActionButton(
                    icon: isVideo ? Icons.videocam : Icons.call,
                    color: Colors.green,
                    label: l10n?.translate('answer_call') ?? 'Answer',
                    onTap: _acceptCall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[700],
      child: const Icon(
        Icons.person,
        size: 28,
        color: Colors.white54,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// 来电管理器 - 在全局使用
class IncomingCallManager {
  static final IncomingCallManager _instance = IncomingCallManager._internal();
  factory IncomingCallManager() => _instance;
  IncomingCallManager._internal();

  OverlayEntry? _overlayEntry;
  final WebRTCService _webrtcService = WebRTCService();

  /// 初始化来电监听
  void initialize(BuildContext context) {
    _webrtcService.onIncomingCall = (callId, callerId, callerName, callerAvatar, callType) {
      showIncomingCall(
        context,
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        callType: callType,
      );
    };
  }

  /// 显示来电悬浮层
  void showIncomingCall(
    BuildContext context, {
    required String callId,
    required int callerId,
    required String callerName,
    required String callerAvatar,
    required int callType,
  }) {
    dismiss();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top,
        left: 0,
        right: 0,
        child: IncomingCallOverlay(
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          callerAvatar: callerAvatar,
          callType: callType,
          onDismiss: dismiss,
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// 隐藏来电悬浮层
  void dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
