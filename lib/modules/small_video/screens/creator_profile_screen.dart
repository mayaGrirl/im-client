/// 创作者个人主页 — 抖音风格
/// 封面背景+左侧头像+右侧昵称、统计行、签名、IP标签、关注按钮+私信

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/modules/small_video/api/small_video_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/modules/small_video/models/small_video.dart';
import 'package:im_client/modules/small_video/screens/video_detail_screen.dart';
import 'package:im_client/modules/small_video/providers/small_video_provider.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/providers/chat_provider.dart';
import 'package:im_client/screens/chat/chat_screen.dart';
import 'package:im_client/screens/profile/edit_profile_screen.dart';
import 'package:im_client/modules/livestream/screens/livestream_viewer_screen.dart';
import 'package:im_client/modules/livestream/screens/user_livestream_analytics_screen.dart';
import 'package:im_client/modules/small_video/screens/user_video_analytics_screen.dart';
import 'package:im_client/modules/small_video/screens/video_management_screen.dart';
import '../../../utils/image_proxy.dart';

class CreatorProfileScreen extends StatefulWidget {
  final int userId;

  const CreatorProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  final SmallVideoApi _api = SmallVideoApi(ApiClient());
  final FriendApi _friendApi = FriendApi(ApiClient());

  Map<String, int> _stats = {};
  List<SmallVideo> _videos = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFriend = false;
  bool _isSelf = false;
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  // 用户资料
  String _nickname = '';
  String _avatar = '';
  String _bio = '';
  String _videoBio = '';
  String _videoCover = '';
  String _region = '';
  String _username = '';
  bool _isLive = false;
  int? _currentLivestreamId;

  /// 副行显示：优先用户名（bot_→user_），无则显示 ID
  String get _subTitle {
    String name = _username;
    if (name.isEmpty) return 'ID: ${widget.userId}';
    if (name.startsWith('bot_')) {
      name = 'user_${name.substring(4)}';
    }
    return name;
  }

  // 封面区域高度
  static const double _coverHeight = 260.0;
  // 头像大小
  static const double _avatarRadius = 40.0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreVideos();
    }
  }

  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return EnvConfig.instance.getFileUrl(url);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final currentUserId = context.read<AuthProvider>().userId;
      _isSelf = currentUserId == widget.userId;

      final statsFuture = _api.getCreatorStats(widget.userId);
      final videosFuture = _isSelf
          ? _api.getMyVideos(page: 1)
          : _api.getUserVideos(widget.userId, page: 1);

      final statsResponse = await statsFuture;
      final videosResponse = await videosFuture;

      if (statsResponse.success && statsResponse.data != null) {
        final data = statsResponse.data;
        if (data is Map) {
          _stats = {
            'followers': _toInt(data['followers']),
            'following': _toInt(data['following']),
            'videos': _toInt(data['videos']),
            'total_likes': _toInt(data['total_likes']),
          };
          _isFollowing = data['is_following'] == true;
          _isFriend = data['is_friend'] == true;
          if (data['is_self'] == true) _isSelf = true;

          final profile = data['user_profile'];
          if (profile is Map) {
            _nickname = profile['nickname']?.toString() ?? '';
            _avatar = profile['avatar']?.toString() ?? '';
            _bio = profile['bio']?.toString() ?? '';
            _videoBio = profile['video_bio']?.toString() ?? '';
            _videoCover = profile['video_cover']?.toString() ?? '';
            _region = profile['region']?.toString() ?? '';
            _username = profile['username']?.toString() ?? '';
            _isLive = profile['is_live'] == true;
            _currentLivestreamId = profile['current_livestream_id'] is int
                ? profile['current_livestream_id']
                : (profile['current_livestream_id'] is double
                    ? (profile['current_livestream_id'] as double).toInt()
                    : null);
          }
        }
      }

      if (videosResponse.success && videosResponse.data != null) {
        final data = videosResponse.data;
        List list;
        if (data is Map && data['list'] != null) {
          list = data['list'] as List;
        } else if (data is List) {
          list = data;
        } else {
          list = [];
        }
        _videos = list.map((e) => SmallVideo.fromJson(e)).toList();
        _page = 2;
        _hasMore = list.length >= 20;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), duration: const Duration(seconds: 2)),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final response = _isSelf
          ? await _api.getMyVideos(page: _page)
          : await _api.getUserVideos(widget.userId, page: _page);
      if (response.success && response.data != null) {
        final data = response.data;
        List list;
        if (data is Map && data['list'] != null) {
          list = data['list'] as List;
        } else if (data is List) {
          list = data;
        } else {
          list = [];
        }
        setState(() {
          _videos.addAll(list.map((e) => SmallVideo.fromJson(e)));
          _page++;
          _hasMore = list.length >= 20;
        });
      }
    } catch (e) {
      // ignore
    }

    setState(() => _isLoading = false);
  }

  Future<void> _toggleFollow() async {
    setState(() => _isFollowing = !_isFollowing);
    try {
      if (_isFollowing) {
        await _api.followCreator(widget.userId);
        _stats['followers'] = (_stats['followers'] ?? 0) + 1;
      } else {
        await _api.unfollowCreator(widget.userId);
        _stats['followers'] = (_stats['followers'] ?? 0) - 1;
      }
      Provider.of<SmallVideoProvider>(context, listen: false)
          .updateFollowState(widget.userId, _isFollowing);
      setState(() {});
    } catch (e) {
      setState(() => _isFollowing = !_isFollowing);
    }
  }

  Future<void> _sendMessage() async {
    if (_isFriend) {
      final chatProvider = context.read<ChatProvider>();
      final conversation = await chatProvider.getOrCreateConversation(
        targetId: widget.userId,
        type: 1,
        targetInfo: {
          'nickname': _nickname,
          'avatar': _avatar,
        },
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(conversation: conversation),
          ),
        );
      }
    } else {
      _showAddFriendDialog();
    }
  }

  void _showAddFriendDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('sv_add_friend')),
        content: Text(l10n.translate('sv_add_friend_first')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _friendApi.addFriend(userId: widget.userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.translate('sv_friend_request_sent'))),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: Text(l10n.translate('confirm')),
          ),
        ],
      ),
    );
  }

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    ).then((_) => _loadData());
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _isFollowing);
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      // 无标准 AppBar — 封面区域自带返回按钮
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context, _isFollowing),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'livestream_analytics':
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserLivestreamAnalyticsScreen(userId: widget.userId),
                  ));
                  break;
                case 'video_analytics':
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserVideoAnalyticsScreen(userId: widget.userId),
                  ));
                  break;
                case 'manage_videos':
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => VideoManagementScreen(userId: widget.userId),
                  )).then((_) => _loadData());
                  break;
              }
            },
            itemBuilder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return [
                PopupMenuItem(
                  value: 'livestream_analytics',
                  child: Row(
                    children: [
                      const Icon(Icons.live_tv, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.translate('sv_livestream_analytics')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'video_analytics',
                  child: Row(
                    children: [
                      const Icon(Icons.analytics, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.translate('sv_video_analytics')),
                    ],
                  ),
                ),
                if (_isSelf)
                  PopupMenuItem(
                    value: 'manage_videos',
                    child: Row(
                      children: [
                        const Icon(Icons.settings, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.translate('sv_manage_videos')),
                      ],
                    ),
                  ),
              ];
            },
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ---- 封面 + 头像/昵称区域 ----
          SliverToBoxAdapter(child: _buildCoverSection(l10n)),

          // ---- 统计 / 签名 / 按钮 ----
          SliverToBoxAdapter(child: _buildInfoSection(l10n)),

          // ---- 作品标签栏 ----
          SliverToBoxAdapter(child: _buildWorksTab(l10n)),

          // ---- 视频网格 ----
          if (_videos.isEmpty && !_isLoading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.video_library_outlined, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      l10n.translate('sv_no_videos'),
                      style: TextStyle(color: AppColors.textHint, fontSize: 15),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 1.5,
                  mainAxisSpacing: 1.5,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= _videos.length) return null;
                    return _buildVideoGridItem(_videos[index]);
                  },
                  childCount: _videos.length,
                ),
              ),
            ),

          // 加载更多
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    ),
    );
  }

  // ==================== 封面区域 ====================

  Widget _buildCoverSection(AppLocalizations l10n) {
    final coverUrl = _getFullUrl(_videoCover);
    final avatarUrl = _getFullUrl(_avatar);

    return SizedBox(
      height: _coverHeight,
      child: Stack(
        children: [
          // 封面图 / 默认深色渐变
          Positioned.fill(
            child: coverUrl.isNotEmpty
                ? Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildDefaultCover(),
                  )
                : _buildDefaultCover(),
          ),

          // 底部渐变遮罩（让文字可读）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _coverHeight * 0.6,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
          ),

          // 头像 + 昵称 + ID（左下角）
          Positioned(
            left: 16,
            bottom: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 头像
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: CircleAvatar(
                    radius: _avatarRadius,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
                    onBackgroundImageError: avatarUrl.isNotEmpty ? (_, __) {} : null,
                    child: avatarUrl.isEmpty
                        ? Icon(Icons.person, size: _avatarRadius, color: Colors.grey[500])
                        : null,
                  ),
                ),
                const SizedBox(width: 14),

                // 昵称（上）+ 用户名（下）
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _nickname.isNotEmpty ? _nickname : _subTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subTitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 默认封面 — 深色渐变（抖音无封面时的风格）
  Widget _buildDefaultCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2C3E50),
            Color(0xFF3498DB),
          ],
        ),
      ),
    );
  }

  // ==================== 信息区域 ====================

  Widget _buildInfoSection(AppLocalizations l10n) {
    final displayBio = _videoBio.isNotEmpty ? _videoBio : _bio;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计行：获赞 · 关注 · 粉丝
          Row(
            children: [
              _buildStatItem(
                _formatCount(_stats['total_likes'] ?? 0),
                l10n.translate('sv_total_likes'),
              ),
              const SizedBox(width: 20),
              _buildStatItem(
                _formatCount(_stats['following'] ?? 0),
                l10n.translate('sv_creator_following'),
              ),
              const SizedBox(width: 20),
              _buildStatItem(
                _formatCount(_stats['followers'] ?? 0),
                l10n.translate('sv_creator_followers'),
              ),
              const Spacer(),
            ],
          ),

          const SizedBox(height: 14),

          // 签名
          if (displayBio.isNotEmpty)
            Text(
              displayBio,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          if (displayBio.isEmpty)
            Text(
              l10n.translate('sv_no_bio'),
              style: TextStyle(fontSize: 14, color: AppColors.textHint),
            ),

          // IP / 地区
          if (_region.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'IP: $_region',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // LIVE NOW banner
          if (_isLive && _currentLivestreamId != null)
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LivestreamViewerScreen(
                    livestreamId: _currentLivestreamId!,
                  ),
                ));
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.deepOrange],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '\u6b63\u5728\u76f4\u64ad',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '\u70b9\u51fb\u8fdb\u5165 >',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // 操作按钮
          _isSelf ? _buildSelfActions(l10n) : _buildOtherActions(l10n),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSelfActions(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: _editProfile,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: BorderSide(color: Colors.grey[300]!),
          foregroundColor: AppColors.textPrimary,
        ),
        child: Text(
          l10n.translate('sv_edit_profile'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildOtherActions(AppLocalizations l10n) {
    return Row(
      children: [
        // 关注按钮 — 粉色/红色，占大部分宽度
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFollowing ? Colors.grey[200] : const Color(0xFFFE2C55),
                foregroundColor: _isFollowing ? AppColors.textPrimary : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: Text(
                _isFollowing
                    ? l10n.translate('sv_unfollow')
                    : '+ ${l10n.translate('sv_follow')}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 私信按钮 — 小方块图标
        SizedBox(
          width: 44,
          height: 44,
          child: OutlinedButton(
            onPressed: _sendMessage,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              side: BorderSide(color: Colors.grey[300]!),
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Icon(Icons.send, size: 18),
          ),
        ),
      ],
    );
  }

  // ==================== 作品标签栏 ====================

  Widget _buildWorksTab(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            '${l10n.translate('sv_creator_videos')} ${_formatCount(_stats['videos'] ?? 0)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  // ==================== 视频网格 ====================

  Widget _buildVideoGridItem(SmallVideo video) {
    final coverUrl = _getFullUrl(video.coverUrl);
    return GestureDetector(
      onTap: () {
        final index = _videos.indexOf(video);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoDetailScreen(
              videos: _videos,
              initialIndex: index >= 0 ? index : 0,
            ),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 封面
          coverUrl.isNotEmpty
              ? Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.video_library, color: Colors.grey),
                  ),
                )
              : Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.video_library, color: Colors.grey),
                ),

          // 底部渐变
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 36,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black38],
                ),
              ),
            ),
          ),

          // 点赞数（左下角，抖音风格用爱心）
          Positioned(
            bottom: 4,
            left: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, size: 14, color: Colors.white),
                const SizedBox(width: 3),
                Text(
                  _formatCount(video.likeCount),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // 付费标识
          if (video.isPaid)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  '\$',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // 私密标识
          if (_isSelf && video.visibility != 0)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Icon(
                  video.visibility == 2 ? Icons.lock_outline : Icons.people_outline,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
