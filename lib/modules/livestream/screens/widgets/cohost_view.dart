/// 连麦分屏视图 �?抖音风格（优化版�?
/// 2�? 左右�?0%   3�? �?�?   4�? 2×2
/// 配合外部控制栏使用（showControls=false�?
/// 主播可点击对方格子中的静音按钮远程控制麦克风
/// 优化：活跃说话者高亮、更大的控制按钮、长按菜�?

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:im_client/config/env_config.dart';

class CoHostInfo {
  final int userId;
  final String nickname;
  final String avatarUrl;
  final Participant? participant;
  /// 主播侧的静音覆盖状态（用于立即更新UI，无需等待 LiveKit 信令回传�?
  final bool? isMutedOverride;
  /// 是否为活跃说话�?
  final bool isActiveSpeaker;

  CoHostInfo({
    required this.userId,
    required this.nickname,
    this.avatarUrl = '',
    this.participant,
    this.isMutedOverride,
    this.isActiveSpeaker = false,
  });

  bool get hasVideo {
    if (participant == null) return false;
    for (final pub in participant!.videoTrackPublications) {
      // 优先: LiveKit 信令状态（对远端参与者最准确�?
      if (pub.muted) continue;
      final track = pub.track;
      if (track == null) continue;
      // 其次: 底层 MediaStreamTrack（对本地参与者最准确�?
      try {
        if (track.mediaStreamTrack.enabled) return true;
      } catch (_) {
        return true; // track 存在且未 muted
      }
    }
    return false;
  }

  VideoTrack? get videoTrack {
    if (participant == null) return null;
    final pub = participant!.videoTrackPublications
        .where((p) => p.track != null)
        .firstOrNull;
    return pub?.track as VideoTrack?;
  }

  bool get isMuted {
    // 1. 主播侧覆盖（点击静音按钮后立即生效，无需等待远端回传�?
    if (isMutedOverride != null) return isMutedOverride!;
    if (participant == null) return true;
    final pub = participant!.audioTrackPublications.firstOrNull;
    if (pub == null) return true;
    // 2. LiveKit 信令状态（远端参与者通过 setMicrophoneEnabled 通知�?muted 状态）
    if (pub.muted) return true;
    // 3. 底层 MediaStreamTrack（本地参与者直接检查）
    final track = pub.track;
    if (track != null) {
      try {
        return !track.mediaStreamTrack.enabled;
      } catch (_) {}
    }
    return false;
  }
}

/// onMuteUser(userId, muted) �?主播控制连麦用户静音
typedef MuteUserCallback = void Function(int userId, bool muted);
/// onKickUser(userId) �?主播踢出连麦用户
typedef KickUserCallback = void Function(int userId);

class CoHostView extends StatelessWidget {
  final int localUserId;
  final List<CoHostInfo> allParticipants;
  final int activeSpeakerId;
  final bool showControls;
  final bool isMicOn;
  final bool isCameraOn;
  final bool isAnchor;
  final VoidCallback? onToggleMic;
  final VoidCallback? onToggleCamera;
  final VoidCallback? onEndCoHost;
  final ValueChanged<int>? onTapUser;
  final MuteUserCallback? onMuteUser;
  final KickUserCallback? onKickUser;

  const CoHostView({
    super.key,
    required this.localUserId,
    required this.allParticipants,
    required this.activeSpeakerId,
    this.showControls = false,
    this.isMicOn = true,
    this.isCameraOn = true,
    this.isAnchor = false,
    this.onToggleMic,
    this.onToggleCamera,
    this.onEndCoHost,
    this.onTapUser,
    this.onMuteUser,
    this.onKickUser,
  });

  @override
  Widget build(BuildContext context) {
    if (allParticipants.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: const Color(0xFF1A1A1A),
        child: _buildGrid(),
      ),
    );
  }

  Widget _buildGrid() {
    final count = allParticipants.length;

    if (count == 1) {
      return _buildCell(allParticipants[0]);
    }

    if (count == 2) {
      return Row(
        children: [
          Expanded(child: _buildCell(allParticipants[0])),
          const SizedBox(width: 2),
          Expanded(child: _buildCell(allParticipants[1])),
        ],
      );
    }

    if (count == 3) {
      return Column(
        children: [
          Expanded(child: _buildCell(allParticipants[0])),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildCell(allParticipants[1])),
                const SizedBox(width: 2),
                Expanded(child: _buildCell(allParticipants[2])),
              ],
            ),
          ),
        ],
      );
    }

    if (count == 4) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildCell(allParticipants[0])),
                const SizedBox(width: 2),
                Expanded(child: _buildCell(allParticipants[1])),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildCell(allParticipants[2])),
                const SizedBox(width: 2),
                Expanded(child: _buildCell(allParticipants[3])),
              ],
            ),
          ),
        ],
      );
    }

    // 5-6�?
    final topCount = count - 3;
    final topRow = allParticipants.sublist(0, topCount);
    final bottomRow = allParticipants.sublist(topCount);
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              for (int i = 0; i < topRow.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(child: _buildCell(topRow[i])),
              ],
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              for (int i = 0; i < bottomRow.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(child: _buildCell(bottomRow[i])),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCell(CoHostInfo p) {
    final isLocal = p.userId == localUserId;
    final canMute = isAnchor && !isLocal && onMuteUser != null;
    final canKick = isAnchor && !isLocal && onKickUser != null;
    debugPrint('[CoHost] _buildCell: userId=${p.userId}, hasVideo=${p.hasVideo}, '
        'videoTrack=${p.videoTrack != null}, participant=${p.participant != null}, '
        'avatarUrl="${p.avatarUrl}"');

    return GestureDetector(
      onTap: () => onTapUser?.call(p.userId),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景：视频或头像
          if (p.hasVideo && p.videoTrack != null)
            ClipRRect(
              child: VideoTrackRenderer(p.videoTrack!, fit: VideoViewFit.cover),
            )
          else
            _buildAvatarPanel(p),

          // 底部渐变遮罩 + 昵称
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99000000)],
                ),
              ),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      isLocal ? '${p.nickname}(Mine）' : p.nickname,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 主播控制按钮行（仅主播可见，且只对非自己的格子）
          if (canMute || canKick)
            Positioned(
              top: 6, left: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 静音/取消静音
                  if (canMute)
                    GestureDetector(
                      onTap: () => onMuteUser!(p.userId, !p.isMuted),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: p.isMuted ? const Color(0xCCFF3B30) : const Color(0x66000000),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          p.isMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  if (canMute && canKick) const SizedBox(width: 4),
                  // 踢出连麦
                  if (canKick)
                    GestureDetector(
                      onTap: () => onKickUser!(p.userId),
                      child: Container(
                        width: 28, height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xCCFF3B30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarPanel(CoHostInfo p) {
    final initial = p.nickname.isNotEmpty ? p.nickname[0].toUpperCase() : '?';
    final colorIdx = p.nickname.isNotEmpty ? p.nickname.codeUnitAt(0) % _gradients.length : 0;
    final fullAvatarUrl = p.avatarUrl.isNotEmpty ? EnvConfig.instance.getFileUrl(p.avatarUrl) : '';
    debugPrint('[CoHost] _buildAvatarPanel: userId=${p.userId}, raw="${p.avatarUrl}", fullUrl="$fullAvatarUrl"');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradients[colorIdx],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: fullAvatarUrl.isNotEmpty
                  ? Image.network(
                      fullAvatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, ___) {
                        debugPrint('[CoHost] Image.network error for "$fullAvatarUrl": $error');
                        return _defaultAvatar(initial, colorIdx);
                      },
                    )
                  : _defaultAvatar(initial, colorIdx),
            ),
            const SizedBox(height: 4),
            Text(
              p.nickname,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar(String initial, int colorIdx) {
    return Container(
      color: _gradients[colorIdx][1],
      child: Center(
        child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
      ),
    );
  }

  static const _gradients = [
    [Color(0xFF667EEA), Color(0xFF764BA2)],
    [Color(0xFFF093FB), Color(0xFFF5576C)],
    [Color(0xFF4FACFE), Color(0xFF00F2FE)],
    [Color(0xFF43E97B), Color(0xFF38F9D7)],
    [Color(0xFFFA709A), Color(0xFFFEE140)],
    [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
    [Color(0xFFFCCB90), Color(0xFFD57EEB)],
    [Color(0xFF30CFD0), Color(0xFF330867)],
  ];
}
