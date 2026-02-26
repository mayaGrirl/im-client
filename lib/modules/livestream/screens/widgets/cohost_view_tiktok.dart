/// 连麦视图 - 抖音风格
/// 主播占据主屏幕，连麦用户显示在右侧浮窗列表
/// 支持点击放大连麦用户画面
/// 主播可控制连麦用户麦克风

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/modules/livestream/screens/widgets/cohost_view.dart' show CoHostInfo;

typedef MuteUserCallback = void Function(int userId, bool muted);
typedef KickUserCallback = void Function(int userId);
typedef EnlargeUserCallback = void Function(int? userId); // 使用 int? 而不是 0 表示退出
typedef ToggleCameraCallback = void Function(int userId, bool enabled);
typedef EndCoHostCallback = void Function();

/// 抖音风格连麦视图
/// 主播占据主屏幕，连麦用户显示在右侧浮窗
class CoHostViewTikTok extends StatefulWidget {
  final int localUserId;
  final List<CoHostInfo> allParticipants;
  final int activeSpeakerId;
  final bool isAnchor;
  final bool canSelfControl; // 当前用户是否为连麦嘉宾（仅嘉宾可显示自控按钮）
  final int? enlargedUserId; // 当前放大的用户ID（null 表示未放大）
  final MuteUserCallback? onMuteUser;
  final KickUserCallback? onKickUser;
  final EnlargeUserCallback? onEnlargeUser;
  final ToggleCameraCallback? onToggleCamera;
  final EndCoHostCallback? onEndCoHost;

  const CoHostViewTikTok({
    super.key,
    required this.localUserId,
    required this.allParticipants,
    required this.activeSpeakerId,
    required this.isAnchor,
    this.canSelfControl = false,
    this.enlargedUserId,
    this.onMuteUser,
    this.onKickUser,
    this.onEnlargeUser,
    this.onToggleCamera,
    this.onEndCoHost,
  });

  @override
  State<CoHostViewTikTok> createState() => _CoHostViewTikTokState();
}

class _CoHostViewTikTokState extends State<CoHostViewTikTok> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (widget.allParticipants.isEmpty) return const SizedBox.shrink();

    // 使用外部传入的 enlargedUserId（null 表示未放大）
    final enlargedUserId = widget.enlargedUserId;

    // 假设第一个参与者是主播
    final anchor = widget.allParticipants.first;

    // 其他参与者是连麦用户
    final coHosts = widget.allParticipants.length > 1
        ? widget.allParticipants.sublist(1)
        : <CoHostInfo>[];

    debugPrint('[CoHostViewTikTok] anchor: ${anchor.nickname}(${anchor.userId})');
    debugPrint('[CoHostViewTikTok] anchor.hasVideo: ${anchor.hasVideo}');
    debugPrint('[CoHostViewTikTok] coHosts: ${coHosts.map((c) => '${c.nickname}(${c.userId})').join(", ")}');
    debugPrint('[CoHostViewTikTok] isAnchor: ${widget.isAnchor}');
    debugPrint('[CoHostViewTikTok] enlargedUserId: $enlargedUserId');

    // 如果有放大的用户，显示放大视图
    if (enlargedUserId != null) {
      final enlargedUser = widget.allParticipants.firstWhere(
            (p) => p.userId == enlargedUserId,
        orElse: () => anchor,
      );
      return _buildEnlargedView(enlargedUser, anchor, coHosts);
    }

    // 正常视图：
    // 连麦模式下，主播的视频也通过 LiveKit 渲染（显示在主屏幕）
    // 连麦用户显示在右侧浮窗
    return Stack(
      children: [
        // 主播视频（连麦时通过 LiveKit 渲染）
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: anchor.hasVideo && anchor.videoTrack != null
                ? _VideoRenderer(
              key: ValueKey(anchor.videoTrack!.sid),
              track: anchor.videoTrack!,
              fit: VideoViewFit.cover,
            )
                : _buildAvatarBackground(anchor),
          ),
        ),

        // 主播信息标签（左下角）
        Positioned(
          left: 12,
          bottom: 120,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (anchor.isMuted)
                  const Icon(Icons.mic_off, color: Colors.red, size: 16),
                if (anchor.isMuted) const SizedBox(width: 4),
                Text(
                  anchor.nickname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (anchor.isActiveSpeaker) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // 右侧连麦用户列表
        if (coHosts.isNotEmpty)
          Positioned(
            top: 100,
            right: 12,
            bottom: 200,
            child: _buildCoHostList(coHosts),
          ),
      ],
    );
  }

  /// 主播主视图
  Widget _buildMainView(CoHostInfo anchor) {
    final isLocal = anchor.userId == widget.localUserId;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 视频或头像
          if (anchor.hasVideo && anchor.videoTrack != null)
            _VideoRenderer(
              key: ValueKey(anchor.videoTrack!.sid),
              track: anchor.videoTrack!,
              fit: VideoViewFit.cover,
            )
          else
            _buildAvatarBackground(anchor),

          // 底部主播信息
          Positioned(
            left: 12,
            bottom: 120,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (anchor.isMuted)
                    const Icon(Icons.mic_off, color: Colors.red, size: 16),
                  if (anchor.isMuted) const SizedBox(width: 4),
                  // 如果是自己，显示一个小图标
                  if (isLocal) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    anchor.nickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (anchor.isActiveSpeaker) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 右侧连麦用户列表
  /// ========== 关键：不使用 ListView，避免视频纹理频繁销毁 ==========
  /// ListView 会在滚动时销毁和重建 item，导致视频纹理被释放和重新创建
  /// 使用 Column 可以保持所有视频 renderer 始终存在
  Widget _buildCoHostList(List<CoHostInfo> coHosts) {
    return SizedBox(
      width: 100,
      child: SingleChildScrollView(
        child: Column(
          children: coHosts
              .map((coHost) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildCoHostItem(coHost),
          ))
              .toList(),
        ),
      ),
    );
  }

  /// 单个连麦用户浮窗
  Widget _buildCoHostItem(CoHostInfo coHost) {
    final isLocal = coHost.userId == widget.localUserId;

    // 权限检查：只有主播可以控制连麦用户（不是自己）
    final canControl = widget.isAnchor && !isLocal;

    // 连麦用户只能看到自己的控制按钮（麦克风、摄像头）
    final showSelfControl = !widget.isAnchor && widget.canSelfControl && isLocal;

    return GestureDetector(
      onTap: () {
        // 所有人都支持本地放大视图；仅主播拥有远程控制权限
        widget.onEnlargeUser?.call(coHost.userId);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: coHost.isActiveSpeaker
              ? Border.all(color: Colors.amber, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 视频或头像
              // ========== 关键：使用 videoTrack.sid 作为 key ==========
              // 这样当 track 被替换时，Flutter 会正确地重建 widget
              if (coHost.hasVideo && coHost.videoTrack != null)
                _VideoRenderer(
                  key: ValueKey(coHost.videoTrack!.sid),
                  track: coHost.videoTrack!,
                  fit: VideoViewFit.cover,
                )
              else
                _buildAvatarBackground(coHost),

              // 渐变遮罩
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 如果是自己，显示一个小图标
                      if (isLocal) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 3),
                      ],
                      Flexible(
                        child: Text(
                          coHost.nickname,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 静音图标（所有被静音的用户都显示）
              if (coHost.isMuted)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_off, color: Colors.white, size: 14),
                  ),
                ),

              // 主播控制按钮（麦克风 + 踢出） 只在主播端且不是自己时显示
              if (canControl)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 麦克风控制
                      GestureDetector(
                        onTap: () => widget.onMuteUser?.call(coHost.userId, !coHost.isMuted),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: coHost.isMuted
                                ? Colors.red.withOpacity(0.9)
                                : Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            coHost.isMuted ? Icons.mic_off : Icons.mic,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 踢出按钮
                      GestureDetector(
                        onTap: () => _confirmKick(coHost),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 连麦用户自己的控制按钮（麦克风、摄像头、退出）- 只在连麦用户端且是自己时显示
              if (showSelfControl)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 麦克风控制
                      GestureDetector(
                        onTap: () {
                          final newMuted = !coHost.isMuted;
                          widget.onMuteUser?.call(coHost.userId, newMuted);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: coHost.isMuted
                                ? Colors.red.withOpacity(0.9)
                                : Colors.green.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            coHost.isMuted ? Icons.mic_off : Icons.mic,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 摄像头控制
                      GestureDetector(
                        onTap: () {
                          final newEnabled = !coHost.hasVideo;
                          widget.onToggleCamera?.call(coHost.userId, newEnabled);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: coHost.hasVideo
                                ? Colors.green.withOpacity(0.9)
                                : Colors.red.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            coHost.hasVideo ? Icons.videocam : Icons.videocam_off,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 退出连麦按钮
                      GestureDetector(
                        onTap: () => _confirmEndCoHost(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.exit_to_app,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 活跃说话者指示器（未静音时显示）
              if (coHost.isActiveSpeaker && !coHost.isMuted)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 放大视图：被放大的用户占主屏，其他人（包括主播）在右侧浮窗
  Widget _buildEnlargedView(CoHostInfo enlargedUser, CoHostInfo anchor, List<CoHostInfo> coHosts) {
    final l = AppLocalizations.of(context);
    // 构建浮窗列表：
    // 1. 如果放大的是连麦用户，浮窗显示：主播 + 其他连麦用户
    // 2. 如果放大的是主播，浮窗显示：所有连麦用户
    List<CoHostInfo> floatingUsers = [];

    if (enlargedUser.userId == anchor.userId) {
      // 放大的是主播，浮窗显示所有连麦用户
      floatingUsers = coHosts;
    } else {
      // 放大的是连麦用户，浮窗显示主播 + 其他连麦用户
      // 去重：确保主播不会重复出现（如果主播也在 coHosts 中）
      floatingUsers = [
        anchor, // 主播
        ...coHosts.where((c) =>
        c.userId != enlargedUser.userId &&
            c.userId != anchor.userId
        ), // 其他连麦用户（排除放大的用户和主播）
      ];
    }

    return Stack(
      children: [
        // 放大的用户视频（全屏）
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              // 本地退出放大
              widget.onEnlargeUser?.call(null); // 使用 null 表示退出放大
            },
            child: Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (enlargedUser.hasVideo && enlargedUser.videoTrack != null)
                    _VideoRenderer(
                      key: ValueKey(enlargedUser.videoTrack!.sid),
                      track: enlargedUser.videoTrack!,
                      fit: VideoViewFit.cover,
                    )
                  else
                    _buildAvatarBackground(enlargedUser),

                  // 底部用户信息
                  Positioned(
                    left: 12,
                    bottom: 120,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (enlargedUser.isMuted)
                            const Icon(Icons.mic_off, color: Colors.red, size: 16),
                          if (enlargedUser.isMuted) const SizedBox(width: 4),
                          Text(
                            enlargedUser.nickname,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 退出放大提示
                  Positioned(
                    top: 60,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.touch_app, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              l?.cohostTapToExitEnlarge ?? 'Tap screen to exit fullscreen',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 右侧浮窗列表
        if (floatingUsers.isNotEmpty)
          Positioned(
            top: 100,
            right: 12,
            bottom: 200,
            child: _buildCoHostList(floatingUsers),
          ),
      ],
    );
  }

  /// 头像背景（当没有视频时显示）
  Widget _buildAvatarBackground(CoHostInfo user) {
    final fullAvatarUrl = user.avatarUrl.isNotEmpty
        ? EnvConfig.instance.getFileUrl(user.avatarUrl)
        : '';

    return Container(
      color: Colors.black87,
      child: Center(
        child: fullAvatarUrl.isNotEmpty
            ? CircleAvatar(
          radius: 40,
          child: ClipOval(
            child: Image.network(
              fullAvatarUrl,
              fit: BoxFit.cover,
              width: 80,
              height: 80,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('[CoHostViewTikTok] Failed to load avatar: $fullAvatarUrl');
                return _buildDefaultAvatar(user);
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildDefaultAvatar(user);
              },
            ),
          ),
        )
            : _buildDefaultAvatar(user),
      ),
    );
  }

  Widget _buildDefaultAvatar(CoHostInfo user) {
    return CircleAvatar(
      radius: 40,
      backgroundColor: Colors.grey[800],
      child: Text(
        user.nickname.isNotEmpty ? user.nickname[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 32, color: Colors.white),
      ),
    );
  }

  void _confirmKick(CoHostInfo coHost) {
    widget.onKickUser?.call(coHost.userId);
  }

  void _confirmEndCoHost() {
    widget.onEndCoHost?.call();
  }
}

/// 独立的视频渲染器 Widget，避免频繁重建
/// ========== 关键：支持 Track 更新/替换不黑屏 ==========
class _VideoRenderer extends StatefulWidget {
  final VideoTrack track;
  final VideoViewFit fit;

  const _VideoRenderer({
    Key? key,
    required this.track,
    this.fit = VideoViewFit.cover,
  }) : super(key: key);

  @override
  State<_VideoRenderer> createState() => _VideoRendererState();
}

class _VideoRendererState extends State<_VideoRenderer> {
  late VideoTrack _track;

  @override
  void initState() {
    super.initState();
    _track = widget.track;
    debugPrint('[_VideoRenderer] initState: track.sid=${_track.sid}');
  }

  @override
  void didUpdateWidget(_VideoRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ========== 关键：必须比较 sid，不比较对象引用 ==========
    // LiveKit 可能会替换 track 对象（网络重协商、切换摄像头等）
    // 如果 sid 不同，说明是新的轨道，需要更新
    if (oldWidget.track.sid != widget.track.sid) {
      debugPrint('[_VideoRenderer] Track 更新: ${oldWidget.track.sid} -> ${widget.track.sid}');
      setState(() {
        _track = widget.track;
      });
    }
  }

  @override
  void dispose() {
    debugPrint('[_VideoRenderer] dispose: track.sid=${_track.sid}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VideoTrackRenderer(
      _track,
      fit: widget.fit,
    );
  }
}
