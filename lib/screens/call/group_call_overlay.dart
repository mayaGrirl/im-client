// Group Call Overlay - Voice/Video chat room style panel
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/providers/group_call_provider.dart';
import 'package:im_client/services/group_call_service.dart';
import '../../utils/image_proxy.dart';

/// Static methods to show/hide overlay
class GroupCallOverlayManager {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  /// Show the group call overlay
  static void show(BuildContext context) {
    if (_isShowing) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => const GroupCallOverlay(),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isShowing = true;
  }

  /// Hide the group call overlay
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
  }

  /// Check if overlay is showing
  static bool get isShowing => _isShowing;
}

/// Group call overlay widget - Chat room style
class GroupCallOverlay extends StatefulWidget {
  const GroupCallOverlay({super.key});

  @override
  State<GroupCallOverlay> createState() => _GroupCallOverlayState();
}

class _GroupCallOverlayState extends State<GroupCallOverlay>
    with SingleTickerProviderStateMixin {
  // Expanded state: false = half screen, true = full screen
  bool _isExpanded = false;

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _heightAnimation = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    final provider = context.read<GroupCallProvider>();
    _eventSubscription = provider.eventStream.listen(_handleCallEvent);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _handleCallEvent(GroupCallEvent event) {
    if (event.type == GroupCallEventType.callEnded) {
      GroupCallOverlayManager.hide();
    }
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  String _getFullUrl(String url) {
    if (url.isEmpty || url == '/') return '';
    if (url.startsWith('http')) return url;
    return EnvConfig.instance.getFileUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Consumer<GroupCallProvider>(
      builder: (context, provider, child) {
        if (!provider.isInCall && provider.state != GroupCallState.initiating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            GroupCallOverlayManager.hide();
          });
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: _heightAnimation,
          builder: (context, child) {
            final panelHeight = screenSize.height * _heightAnimation.value;

            return Stack(
              children: [
                // Semi-transparent background (only when expanded)
                if (_isExpanded)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggleExpand,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                    ),
                  ),

                // Main panel
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: panelHeight,
                  child: Material(
                    elevation: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: provider.isVideo
                              ? [
                                  // 视频通话：深蓝紫渐变
                                  const Color(0xFF1a1a2e),
                                  const Color(0xFF1f1f3a),
                                  const Color(0xFF252547),
                                ]
                              : [
                                  // 语音通话：深灰紫渐变（类似Discord风格）
                                  const Color(0xFF1e1e2e),
                                  const Color(0xFF2a2a3d),
                                  const Color(0xFF36364a),
                                ],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            // Header with close button
                            _buildHeader(context, provider),
                            // Content area
                            Expanded(
                              child: _buildContent(context, provider),
                            ),
                            // Control bar
                            _buildControlBar(context, provider),
                            // Drag handle to expand/collapse
                            _buildDragHandle(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, GroupCallProvider provider) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back/Minimize button
          GestureDetector(
            onTap: _toggleExpand,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title and info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      provider.isVideo ? Icons.videocam : Icons.graphic_eq,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.groupName ?? l10n?.translate('group_call') ?? '群通话',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Live indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            provider.formattedDuration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${provider.participants.length + 1} ${l10n?.translate('participants') ?? '人在通话'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Leave button (always visible and prominent)
          GestureDetector(
            onTap: () => _showLeaveDialog(context, provider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.call_end, color: Colors.white, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    l10n?.translate('leave') ?? '离开',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, GroupCallProvider provider) {
    final participants = provider.participants;
    final l10n = AppLocalizations.of(context);

    if (provider.isVideo) {
      return _buildVideoContent(context, provider);
    }

    // Voice call - show avatar grid like voice chat room
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Main speaker area (self)
          if (_isExpanded) ...[
            _buildMainSpeaker(context, provider),
            const SizedBox(height: 20),
          ],

          // Participants grid
          Expanded(
            child: _buildParticipantsGrid(context, provider, participants),
          ),

          // Waiting text when no one joined
          if (participants.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Icon(
                    Icons.hourglass_empty,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n?.translate('waiting_for_others') ?? '等待其他成员加入...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoContent(BuildContext context, GroupCallProvider provider) {
    final participants = provider.participants;

    if (_isExpanded) {
      // Full screen - grid layout
      return Padding(
        padding: const EdgeInsets.all(8),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: participants.isEmpty ? 1 : 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3 / 4,
          ),
          itemCount: participants.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              // Self video
              return _buildVideoTile(
                context,
                provider,
                isLocal: true,
              );
            }
            return _buildVideoTile(
              context,
              provider,
              participant: participants[index - 1],
            );
          },
        ),
      );
    }

    // Half screen - local video preview
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (provider.localRenderer != null && !provider.isCameraOff)
                    RTCVideoView(
                      provider.localRenderer as RTCVideoRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  else
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Icon(Icons.videocam_off, color: Colors.white54, size: 48),
                      ),
                    ),

                  // Small participant previews
                  if (participants.isNotEmpty)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Row(
                        children: participants.take(3).map((p) {
                          final avatarUrl = _getFullUrl(p.avatar);
                          return Container(
                            margin: const EdgeInsets.only(left: 4),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey[700],
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl.proxied)
                                  : null,
                              child: avatarUrl.isEmpty
                                  ? const Icon(Icons.person, size: 20, color: Colors.white)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainSpeaker(BuildContext context, GroupCallProvider provider) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // Large avatar with speaking animation
        Stack(
          alignment: Alignment.center,
          children: [
            // Ripple effect when speaking
            if (!provider.isMuted)
              ...List.generate(3, (index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 1500 + index * 500),
                  builder: (context, value, child) {
                    return Container(
                      width: 100 + (value * 40),
                      height: 100 + (value * 40),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3 * (1 - value)),
                          width: 2,
                        ),
                      ),
                    );
                  },
                );
              }),
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: const Icon(Icons.person, size: 50, color: Colors.white),
            ),
            if (provider.isMuted)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic_off, size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n?.translate('you') ?? '我',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsGrid(
    BuildContext context,
    GroupCallProvider provider,
    List<GroupCallParticipantWithStream> participants,
  ) {
    final l10n = AppLocalizations.of(context);
    final allItems = [
      if (!_isExpanded) null, // Self avatar
      ...participants,
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];

        if (item == null) {
          // Self
          return _buildParticipantAvatar(
            context,
            nickname: l10n?.translate('you') ?? '我',
            avatarUrl: '',
            isMuted: provider.isMuted,
            isSelf: true,
          );
        }

        return _buildParticipantAvatar(
          context,
          nickname: item.nickname,
          avatarUrl: _getFullUrl(item.avatar),
          isMuted: item.isMuted,
        );
      },
    );
  }

  Widget _buildParticipantAvatar(
    BuildContext context, {
    required String nickname,
    required String avatarUrl,
    required bool isMuted,
    bool isSelf = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelf
                      ? const Color(0xFF7C4DFF) // 紫色高亮
                      : Colors.white.withValues(alpha: 0.3),
                  width: isSelf ? 3 : 2,
                ),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
                child: avatarUrl.isEmpty
                    ? Icon(
                        Icons.person,
                        size: 28,
                        color: Colors.white.withValues(alpha: 0.8),
                      )
                    : null,
              ),
            ),
            if (isMuted)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic_off, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          nickname,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 11,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVideoTile(
    BuildContext context,
    GroupCallProvider provider, {
    GroupCallParticipantWithStream? participant,
    bool isLocal = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final nickname = isLocal
        ? (l10n?.translate('you') ?? '我')
        : (participant?.nickname ?? '');
    final isMuted = isLocal ? provider.isMuted : (participant?.isMuted ?? false);
    final avatarUrl = isLocal ? '' : _getFullUrl(participant?.avatar ?? '');

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video or avatar
          if (isLocal && provider.localRenderer != null && !provider.isCameraOff)
            RTCVideoView(
              provider.localRenderer as RTCVideoRenderer,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else if (!isLocal && participant?.stream != null && participant?.renderer != null && !participant!.isVideoOff)
            RTCVideoView(
              participant.renderer!,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            Container(
              color: Colors.black54,
              child: Center(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey[700],
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
                  child: avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 30, color: Colors.white)
                      : null,
                ),
              ),
            ),

          // Name tag
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMuted)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.mic_off, size: 12, color: Colors.red),
                    ),
                  Text(
                    nickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(BuildContext context, GroupCallProvider provider) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          _buildControlButton(
            icon: provider.isMuted ? Icons.mic_off : Icons.mic,
            label: provider.isMuted
                ? (l10n?.translate('unmute') ?? '取消静音')
                : (l10n?.translate('mute') ?? '静音'),
            isActive: !provider.isMuted,
            activeColor: Colors.white,
            inactiveColor: Colors.red,
            onTap: provider.toggleMute,
          ),

          // Camera button (video call only)
          if (provider.isVideo)
            _buildControlButton(
              icon: provider.isCameraOff ? Icons.videocam_off : Icons.videocam,
              label: provider.isCameraOff
                  ? (l10n?.translate('camera_on') ?? '开启摄像头')
                  : (l10n?.translate('camera_off') ?? '关闭摄像头'),
              isActive: !provider.isCameraOff,
              activeColor: Colors.white,
              inactiveColor: Colors.red,
              onTap: provider.toggleCamera,
            ),

          // Speaker button
          _buildControlButton(
            icon: provider.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
            label: provider.isSpeakerOn
                ? (l10n?.translate('speaker') ?? '扬声器')
                : (l10n?.translate('earpiece') ?? '听筒'),
            isActive: provider.isSpeakerOn,
            activeColor: const Color(0xFF7C4DFF), // 紫色
            inactiveColor: Colors.white,
            onTap: provider.toggleSpeaker,
          ),

          // Switch camera (video call only)
          if (provider.isVideo)
            _buildControlButton(
              icon: Icons.flip_camera_ios,
              label: l10n?.translate('flip') ?? '翻转',
              isActive: true,
              activeColor: Colors.white,
              inactiveColor: Colors.white,
              onTap: provider.switchCamera,
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    final color = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      onTap: _toggleExpand,
      onVerticalDragUpdate: (details) {
        if (details.delta.dy < -5 && !_isExpanded) {
          _toggleExpand();
        } else if (details.delta.dy > 5 && _isExpanded) {
          _toggleExpand();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isExpanded ? '下滑收起' : '上滑展开',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLeaveDialog(
      BuildContext context, GroupCallProvider provider) async {
    final l10n = AppLocalizations.of(context);

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.call_end, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              l10n?.translate('leave_call') ?? '离开通话',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.translate('leave_call_confirm') ?? '确定要离开当前通话吗？',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.grey[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n?.translate('cancel') ?? '取消',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n?.translate('leave') ?? '离开',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

    if (result == true) {
      await provider.leaveCall();
      GroupCallOverlayManager.hide();
    }
  }
}

/// Incoming group call notification banner
class IncomingGroupCallBanner extends StatelessWidget {
  final int callId;
  final int groupId;
  final int callType;
  final String initiatorName;
  final String initiatorAvatar;
  final String groupName;
  final VoidCallback onJoin;
  final VoidCallback onDismiss;

  const IncomingGroupCallBanner({
    super.key,
    required this.callId,
    required this.groupId,
    required this.callType,
    required this.initiatorName,
    required this.initiatorAvatar,
    required this.groupName,
    required this.onJoin,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isVideo = callType == 2;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isVideo
                ? [const Color(0xFF1a1a2e), const Color(0xFF252547)]
                : [const Color(0xFF1e1e2e), const Color(0xFF36364a)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon with pulse animation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVideo ? Icons.videocam : Icons.call,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isVideo
                          ? (l10n?.translate('group_video_call_started') ??
                              '群视频通话')
                          : (l10n?.translate('group_voice_call_started') ??
                              '群语音通话'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$initiatorName · $groupName',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dismiss button
                  GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Join button
                  GestureDetector(
                    onTap: onJoin,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l10n?.translate('join') ?? '加入',
                        style: TextStyle(
                          color: isVideo
                              ? const Color(0xFF1a1a2e)
                              : const Color(0xFF1e1e2e),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
