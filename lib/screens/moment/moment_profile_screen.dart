/// 个人朋友圈页面（类似微信点击头像进入的相册页面）
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/moment_api.dart';
import 'package:im_client/api/user_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/modules/livestream/screens/livestream_viewer_screen.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class MomentProfileScreen extends StatefulWidget {
  final int userId;

  const MomentProfileScreen({super.key, required this.userId});

  @override
  State<MomentProfileScreen> createState() => _MomentProfileScreenState();
}

class _MomentProfileScreenState extends State<MomentProfileScreen> {
  final MomentApi _momentApi = MomentApi(ApiClient());
  final UserApi _userApi = UserApi(ApiClient());
  final ScrollController _scrollController = ScrollController();

  UserProfile? _userProfile;
  final List<Moment> _moments = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadMoments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await _userApi.getUserProfile(widget.userId);
      if (response.success && response.data != null) {
        setState(() {
          _userProfile = UserProfile.fromJson(response.data);
        });
      }
    } catch (e) {
      debugPrint('加载用户信息失败: $e');
    }
  }

  Future<void> _loadMoments({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    if (!_hasMore && !refresh) return;

    setState(() => _isLoading = true);

    try {
      final response = await _momentApi.getUserMoments(
        userId: widget.userId,
        page: _page,
        pageSize: _pageSize,
      );

      if (response.success && response.data != null) {
        final list = (response.data['list'] as List?)
                ?.map((e) => Moment.fromJson(e))
                .toList() ??
            [];

        setState(() {
          if (refresh) {
            _moments.clear();
          }
          _moments.addAll(list);
          _hasMore = list.length >= _pageSize;
          _page++;
        });
      }
    } catch (e) {
      debugPrint('加载朋友圈失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_hasMore && !_isLoading) {
      await _loadMoments();
    }
  }

  Future<void> _toggleLike(Moment moment, int index) async {
    try {
      final response = await _momentApi.toggleLike(moment.id);
      if (response.success) {
        final liked = response.data['liked'] == true;
        setState(() {
          _moments[index] = moment.copyWith(
            isLiked: liked,
            likeCount: liked ? moment.likeCount + 1 : moment.likeCount - 1,
          );
        });
      }
    } catch (e) {
      debugPrint('点赞失败: $e');
    }
  }

  Future<void> _deleteMoment(Moment moment, int index) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteMoment),
        content: Text(l10n.deleteMomentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await _momentApi.deleteMoment(moment.id);
        if (response.success) {
          setState(() {
            _moments.removeAt(index);
          });
        }
      } catch (e) {
        debugPrint('删除失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id;
    final isOwner = widget.userId == currentUserId;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 顶部个人信息
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.black87,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
            ),
          ),
          // 动态列表
          _moments.isEmpty && !_isLoading
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          isOwner ? AppLocalizations.of(context)!.noMomentsYet : AppLocalizations.of(context)!.theyNoMomentsYet,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _moments.length) {
                        return _buildLoadMoreIndicator();
                      }
                      return _buildMomentItem(_moments[index], index, isOwner);
                    },
                    childCount: _moments.length + (_hasMore ? 1 : 0),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey[700]!,
                Colors.grey[900]!,
              ],
            ),
          ),
        ),
        // 用户信息
        Positioned(
          right: 16,
          bottom: 60,
          left: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 左侧信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _userProfile?.nickname ?? AppLocalizations.of(context)!.loading,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                    if (_userProfile?.bio != null &&
                        _userProfile!.bio!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _userProfile!.bio!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 头像
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _userProfile?.avatar != null &&
                          _userProfile!.avatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: EnvConfig.instance
                              .getFileUrl(_userProfile!.avatar),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.person, size: 40),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.person, size: 40),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.person, size: 40),
                        ),
                ),
              ),
            ],
          ),
        ),
        // 动态数量
        Positioned(
          left: 16,
          bottom: 16,
          child: Text(
            AppLocalizations.of(context)!.postsCount.replaceAll('{count}', _moments.length.toString()),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMomentItem(Moment moment, int index, bool isOwner) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 文字内容
          if (moment.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                moment.content,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ),
          // 直播分享卡片
          if (_isLivestreamShare(moment)) _buildLivestreamShareCard(moment),
          // 图片（非直播分享时才显示）
          if (!_isLivestreamShare(moment) && moment.images.isNotEmpty) _buildImages(moment.images),
          // 视频
          if (moment.videos.isNotEmpty) _buildVideos(moment.videos),
          const SizedBox(height: 12),
          // 底部信息
          Row(
            children: [
              Text(
                _formatTime(moment.createdAt),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              if (moment.location != null && moment.location!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on,
                          size: 12, color: Colors.grey[500]),
                      Text(
                        moment.location!,
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              // 点赞数
              if (moment.likeCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        moment.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 14,
                        color: moment.isLiked ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${moment.likeCount}',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              // 评论数
              if (moment.commentCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.comment, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '${moment.commentCount}',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              // 操作按钮
              _buildActionMenu(moment, index, isOwner),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImages(List<String> images) {
    final count = images.length;
    double imageSize = count == 1 ? 200 : 100;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: images.asMap().entries.map((entry) {
          final idx = entry.key;
          final url = EnvConfig.instance.getFileUrl(entry.value);
          return GestureDetector(
            onTap: () => _showImageGallery(images, idx),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: url,
                width: imageSize,
                height: imageSize,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: imageSize,
                  height: imageSize,
                  color: Colors.grey[200],
                ),
                errorWidget: (_, __, ___) => Container(
                  width: imageSize,
                  height: imageSize,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVideos(List<String> videos) {
    if (videos.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
          ],
        ),
      ),
    );
  }

  // ==================== 直播分享卡片 ====================

  bool _isLivestreamShare(Moment moment) {
    if (moment.extra == null || moment.extra!.isEmpty) return false;
    try {
      final extra = jsonDecode(moment.extra!);
      return extra is Map && extra['type'] == 'livestream_share';
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic>? _parseLivestreamExtra(Moment moment) {
    if (moment.extra == null || moment.extra!.isEmpty) return null;
    try {
      final extra = jsonDecode(moment.extra!);
      if (extra is Map<String, dynamic> && extra['type'] == 'livestream_share') {
        return extra;
      }
    } catch (_) {}
    return null;
  }

  Widget _buildLivestreamShareCard(Moment moment) {
    final extra = _parseLivestreamExtra(moment);
    if (extra == null) return const SizedBox();

    final title = extra['title']?.toString() ?? '';
    final coverUrl = extra['cover_url']?.toString() ?? '';
    final anchorName = extra['anchor_name']?.toString() ?? '';
    final livestreamId = extra['livestream_id'];

    final fullCoverUrl = coverUrl.isNotEmpty
        ? (coverUrl.startsWith('http') ? coverUrl : EnvConfig.instance.getFileUrl(coverUrl))
        : '';

    return GestureDetector(
      onTap: () {
        if (livestreamId != null) {
          final id = livestreamId is int
              ? livestreamId
              : int.tryParse(livestreamId.toString()) ?? 0;
          if (id > 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LivestreamViewerScreen(
                  livestreamId: id,
                  isAnchor: false,
                ),
              ),
            );
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(4),
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            if (fullCoverUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: fullCoverUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.live_tv, size: 24, color: Colors.white),
                ),
              )
            else
              Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(Icons.live_tv, size: 24, color: Colors.white),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title.isNotEmpty ? title : (AppLocalizations.of(context)?.livestreamRoom ?? 'Livestream'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            anchorName,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionMenu(Moment moment, int index, bool isOwner) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.more_horiz, size: 16, color: Color(0xFF576B95)),
      ),
      onSelected: (value) {
        if (value == 'like') {
          _toggleLike(moment, index);
        } else if (value == 'delete') {
          _deleteMoment(moment, index);
        }
      },
      itemBuilder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return [
          PopupMenuItem(
            value: 'like',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  moment.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  moment.isLiked ? l10n.unlike : l10n.like,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          if (isOwner)
            PopupMenuItem(
              value: 'delete',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delete_outline, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(l10n.delete, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
        ];
      },
      color: const Color(0xFF4C4C4C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: _hasMore
            ? const CircularProgressIndicator()
            : Text(AppLocalizations.of(context)!.noMore, style: TextStyle(color: Colors.grey[500])),
      ),
    );
  }

  void _showImageGallery(List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (context, index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(
                    EnvConfig.instance.getFileUrl(images[index]),
                  ),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                );
              },
              itemCount: images.length,
              pageController: PageController(initialPage: initialIndex),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return l10n.justNow;
    } else if (diff.inMinutes < 60) {
      return l10n.minutesAgo(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return l10n.hoursAgo(diff.inHours);
    } else if (diff.inDays < 2) {
      return l10n.yesterday;
    } else if (diff.inDays < 7) {
      return l10n.daysAgo(diff.inDays);
    } else if (time.year == now.year) {
      return l10n.translate('date_format')
          .replaceAll('{month}', time.month.toString())
          .replaceAll('{day}', time.day.toString());
    } else {
      return l10n.fullDateFormat
          .replaceAll('{year}', time.year.toString())
          .replaceAll('{month}', time.month.toString())
          .replaceAll('{day}', time.day.toString());
    }
  }
}

/// 用户资料模型
class UserProfile {
  final int id;
  final String username;
  final String nickname;
  final String avatar;
  final String? bio; // 签名/个性签名
  final int? gender;

  UserProfile({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatar,
    this.bio,
    this.gender,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      bio: json['bio'],
      gender: json['gender'],
    );
  }
}
