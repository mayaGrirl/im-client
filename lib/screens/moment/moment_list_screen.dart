/// 朋友圈列表页面（仿微信）
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/moment_api.dart';
import 'package:im_client/api/upload_api.dart';
import 'package:im_client/api/user_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/screens/moment/moment_publish_screen.dart';
import 'package:im_client/screens/moment/moment_profile_screen.dart';
import 'package:im_client/screens/moment/video_player_screen.dart';
import 'package:im_client/modules/livestream/screens/livestream_viewer_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:im_client/utils/image_crop_helper.dart';

class MomentListScreen extends StatefulWidget {
  const MomentListScreen({super.key});

  @override
  State<MomentListScreen> createState() => _MomentListScreenState();
}

class _MomentListScreenState extends State<MomentListScreen> {
  final MomentApi _momentApi = MomentApi(ApiClient());
  final ScrollController _scrollController = ScrollController();
  final List<Moment> _moments = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 20;

  // 通知相关
  int _unreadNotificationCount = 0;

  // 评论输入
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  int? _replyMomentId;
  MomentComment? _replyToComment;

  @override
  void initState() {
    super.initState();
    _loadMoments();
    _loadNotificationCount();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadNotificationCount() async {
    try {
      final response = await _momentApi.getNotifications(page: 1, pageSize: 1);
      if (response.success && response.data != null) {
        // 使用服务器返回的未读数量
        setState(() {
          _unreadNotificationCount = (response.data['unread_count'] as int?) ?? 0;
        });
      }
    } catch (e) {
      // Load notification count failed
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
      final response = await _momentApi.getMomentList(
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
      // Load moments failed
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
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) return;

    // 乐观更新UI
    final wasLiked = moment.isLiked;
    final newLikes = List<MomentLike>.from(moment.likes);

    if (wasLiked) {
      // 取消点赞，移除当前用户
      newLikes.removeWhere((like) => like.userId == currentUser.id);
    } else {
      // 点赞，添加当前用户
      newLikes.add(MomentLike(
        id: 0,
        momentId: moment.id,
        userId: currentUser.id,
        user: MomentUser(
          id: currentUser.id,
          username: currentUser.username,
          nickname: currentUser.nickname,
          avatar: currentUser.avatar,
        ),
        createdAt: DateTime.now(),
      ));
    }

    setState(() {
      _moments[index] = moment.copyWith(
        isLiked: !wasLiked,
        likeCount: wasLiked ? moment.likeCount - 1 : moment.likeCount + 1,
        likes: newLikes,
      );
    });

    try {
      final response = await _momentApi.toggleLike(moment.id);
      if (!response.success) {
        // 回滚
        setState(() {
          _moments[index] = moment;
        });
      }
    } catch (e) {
      // Like failed, rollback
      setState(() {
        _moments[index] = moment;
      });
    }
  }

  void _showCommentInput(Moment moment, {MomentComment? replyTo}) {
    setState(() {
      _replyMomentId = moment.id;
      _replyToComment = replyTo;
    });
    _commentFocusNode.requestFocus();
  }

  Future<void> _submitComment() async {
    if (_replyMomentId == null) return;
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) return;

    final momentIndex = _moments.indexWhere((m) => m.id == _replyMomentId);
    if (momentIndex == -1) return;

    try {
      final response = await _momentApi.comment(
        momentId: _replyMomentId!,
        content: content,
        replyToId: _replyToComment?.id,
        replyUserId: _replyToComment?.userId,
      );

      if (response.success && response.data != null) {
        // 构建新评论并添加到列表
        final newComment = MomentComment(
          id: response.data['id'] ?? 0,
          momentId: _replyMomentId!,
          userId: currentUser.id,
          user: MomentUser(
            id: currentUser.id,
            username: currentUser.username,
            nickname: currentUser.nickname,
            avatar: currentUser.avatar,
          ),
          content: content,
          replyToId: _replyToComment?.id,
          replyUserId: _replyToComment?.userId,
          replyUser: _replyToComment?.user,
          createdAt: DateTime.now(),
        );

        final moment = _moments[momentIndex];
        final newComments = List<MomentComment>.from(moment.comments)..add(newComment);

        setState(() {
          _moments[momentIndex] = moment.copyWith(
            commentCount: moment.commentCount + 1,
            comments: newComments,
          );
        });

        _commentController.clear();
        _replyMomentId = null;
        _replyToComment = null;
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      // Comment failed
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('comment_failed')}: $e')),
        );
      }
    }
  }

  Future<void> _deleteMoment(Moment moment, int index) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_moment')),
        content: Text(l10n.translate('delete_moment_confirm')),
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('delete_success'))),
            );
          }
        }
      } catch (e) {
        // Delete failed
      }
    }
  }

  void _navigateToPublish() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MomentPublishScreen()),
    );
    if (result == true) {
      _loadMoments(refresh: true);
    }
  }

  void _navigateToProfile(int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MomentProfileScreen(userId: userId),
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotificationSheet(
        momentApi: _momentApi,
        onTap: (notification) {
          Navigator.pop(context);
          // 跳转到对应的动态
          _scrollToMoment(notification['moment_id']);
        },
      ),
    );
    // 标记已读
    _momentApi.markNotificationsRead();
    setState(() {
      _unreadNotificationCount = 0;
    });
  }

  void _scrollToMoment(dynamic momentId) {
    if (momentId == null) return;

    final int targetId = momentId is int ? momentId : int.tryParse(momentId.toString()) ?? 0;
    if (targetId == 0) return;

    // 查找动态在列表中的索引
    final index = _moments.indexWhere((m) => m.id == targetId);

    if (index != -1) {
      // 计算滚动位置 (header高度 + 通知栏高度 + 每个item的估算高度)
      // header约280, 通知栏约65, 每个动态item估算约300
      final headerHeight = 280.0;
      final notificationHeight = _unreadNotificationCount > 0 ? 65.0 : 0.0;
      final estimatedItemHeight = 300.0;

      final targetOffset = headerHeight + notificationHeight + (index * estimatedItemHeight);

      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      // Moment not in current list
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('moment_may_be_deleted'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 顶部AppBar
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: Colors.black87,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeader(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    onPressed: _navigateToPublish,
                  ),
                ],
              ),
              // 通知提示
              if (_unreadNotificationCount > 0)
                SliverToBoxAdapter(
                  child: _buildNotificationBanner(),
                ),
              // 动态列表
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= _moments.length) {
                      return _buildLoadMoreIndicator();
                    }
                    return _buildMomentItem(_moments[index], index);
                  },
                  childCount: _moments.length + (_hasMore ? 1 : 0),
                ),
              ),
            ],
          ),
          // 评论输入框
          if (_replyMomentId != null) _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildNotificationBanner() {
    return GestureDetector(
      onTap: _showNotifications,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 1),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.notifications, color: Colors.blue),
                ),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.translate('new_likes_and_comments'),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final currentUser = context.read<AuthProvider>().user;
    final l10n = AppLocalizations.of(context)!;

    // 优先使用 momentCover，没有则使用头像作为背景
    final hasMomentCover = currentUser?.momentCover != null && currentUser!.momentCover!.isNotEmpty;
    final hasAvatar = currentUser?.avatar != null && currentUser!.avatar.isNotEmpty;
    final backgroundUrl = hasMomentCover
        ? EnvConfig.instance.getFileUrl(currentUser!.momentCover!)
        : (hasAvatar ? EnvConfig.instance.getFileUrl(currentUser!.avatar) : null);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景图（长按更换）
        GestureDetector(
          onLongPress: () => _showChangeCoverDialog(),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey[800]!,
                  Colors.grey[900]!,
                ],
              ),
            ),
            child: backgroundUrl != null
                ? Opacity(
                    opacity: hasMomentCover ? 1.0 : 0.3, // 有封面时不透明，用头像时半透明
                    child: Image.network(
                      backgroundUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  )
                : null,
          ),
        ),
        // 长按提示
        Positioned(
          left: 16,
          bottom: 16,
          child: Text(
            l10n.translate('long_press_change_cover'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ),
        // 用户信息
        Positioned(
          right: 16,
          bottom: 40,
          child: GestureDetector(
            onTap: () {
              if (currentUser != null) {
                _navigateToProfile(currentUser.id);
              }
            },
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentUser?.nickname ?? AppLocalizations.of(context)!.translate('not_logged_in'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    if (currentUser?.bio != null &&
                        currentUser!.bio!.isNotEmpty)
                      Text(
                        currentUser.bio!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: currentUser?.avatar != null &&
                            currentUser!.avatar.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: EnvConfig.instance
                                .getFileUrl(currentUser.avatar),
                            width: 70,
                            height: 70,
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
                            width: 70,
                            height: 70,
                            color: Colors.grey[300],
                            child: const Icon(Icons.person, size: 40),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 显示更换封面对话框
  void _showChangeCoverDialog() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.translate('choose_from_album')),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadCover();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.translate('take_photo')),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadCover(fromCamera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: Text(l10n.cancel),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  /// 选择并上传封面图片
  Future<void> _pickAndUploadCover({bool fromCamera = false}) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      // 裁剪图片（16:9矩形）
      final croppedPath = await ImageCropHelper.cropImage(
        context,
        image.path,
        CropType.background,
      );
      if (croppedPath == null) return; // 用户取消裁剪

      // 显示加载提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('uploading'))),
        );
      }

      // 上传裁剪后的图片
      final uploadApi = UploadApi(ApiClient());
      UploadResult? result;

      if (kIsWeb) {
        final bytes = await File(croppedPath).readAsBytes();
        result = await uploadApi.uploadImage(bytes.toList(), filename: image.name);
      } else {
        result = await uploadApi.uploadImage(croppedPath, filename: image.name);
      }

      if (result != null && result.url.isNotEmpty) {
        // 更新用户资料
        final userApi = UserApi(ApiClient());
        final response = await userApi.updateProfile(momentCover: result.url);

        if (response.success) {
          // 刷新用户信息
          if (mounted) {
            await context.read<AuthProvider>().refreshUser();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('cover_updated'))),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response.message ?? l10n.translate('update_failed'))),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('upload_failed'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('error')}: $e')),
        );
      }
    }
  }

  Widget _buildMomentItem(Moment moment, int index) {
    final currentUserId = context.read<AuthProvider>().user?.id;
    final isOwner = moment.userId == currentUserId;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像
          GestureDetector(
            onTap: () => _navigateToProfile(moment.userId),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: EnvConfig.instance
                    .getFileUrl(moment.user?.avatar ?? ''),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.person, size: 24),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.person, size: 24),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 昵称
                GestureDetector(
                  onTap: () => _navigateToProfile(moment.userId),
                  child: Text(
                    moment.user?.nickname ?? '${AppLocalizations.of(context)!.translate('user')}${moment.userId}',
                    style: const TextStyle(
                      color: Color(0xFF576B95),
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // 文字内容
                if (moment.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
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
                const SizedBox(height: 8),
                // 位置和时间
                Row(
                  children: [
                    Text(
                      _formatTime(moment.createdAt),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    if (moment.location != null && moment.location!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          moment.location!,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const Spacer(),
                    // 删除按钮（仅自己可见）
                    if (isOwner)
                      GestureDetector(
                        onTap: () => _deleteMoment(moment, index),
                        child: Text(
                          AppLocalizations.of(context)!.delete,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    // 操作按钮
                    _buildActionButton(moment, index),
                  ],
                ),
                // 点赞和评论区
                if (moment.likes.isNotEmpty || moment.comments.isNotEmpty)
                  _buildInteractionArea(moment, index),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImages(List<String> images) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final count = images.length;
          const gap = 4.0;

          // Determine columns based on image count
          final int cols;
          if (count == 1) {
            cols = 1;
          } else if (count == 2 || count == 4) {
            cols = 2;
          } else {
            cols = 3;
          }

          // Calculate cell size
          final double cellSize;
          if (count == 1) {
            cellSize = maxWidth * 0.65;
          } else {
            cellSize = (maxWidth - gap * (cols - 1)) / cols;
          }

          // Build rows
          final rows = <Widget>[];
          for (var i = 0; i < count; i += cols) {
            final rowChildren = <Widget>[];
            for (var j = i; j < i + cols && j < count; j++) {
              if (j > i) {
                rowChildren.add(const SizedBox(width: gap));
              }
              final url = EnvConfig.instance.getFileUrl(images[j]);
              final idx = j;
              rowChildren.add(
                GestureDetector(
                  onTap: () => _showImageGallery(images, idx),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: cellSize,
                      height: cellSize,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: cellSize,
                        height: cellSize,
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: cellSize,
                        height: cellSize,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
              );
            }
            if (i > 0) {
              rows.add(const SizedBox(height: gap));
            }
            rows.add(Row(
              mainAxisSize: MainAxisSize.min,
              children: rowChildren,
            ));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: rows,
          );
        },
      ),
    );
  }

  Widget _buildVideoCell(String videoPath, double size) {
    final videoUrl = EnvConfig.instance.getFileUrl(videoPath);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(videoUrl: videoUrl),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.grey[700]!, Colors.grey[900]!],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.play_circle_filled,
              size: 48,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideos(List<String> videos) {
    if (videos.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final count = videos.length;
          const gap = 4.0;

          // Single video: large cell like single image
          if (count == 1) {
            final size = maxWidth * 0.65;
            return _buildVideoCell(videos.first, size);
          }

          // Multiple videos: same grid logic as images
          final int cols;
          if (count == 2 || count == 4) {
            cols = 2;
          } else {
            cols = 3;
          }

          final cellSize = (maxWidth - gap * (cols - 1)) / cols;

          final rows = <Widget>[];
          for (var i = 0; i < count; i += cols) {
            final rowChildren = <Widget>[];
            for (var j = i; j < i + cols && j < count; j++) {
              if (j > i) {
                rowChildren.add(const SizedBox(width: gap));
              }
              rowChildren.add(_buildVideoCell(videos[j], cellSize));
            }
            if (i > 0) {
              rows.add(const SizedBox(height: gap));
            }
            rows.add(Row(
              mainAxisSize: MainAxisSize.min,
              children: rowChildren,
            ));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: rows,
          );
        },
      ),
    );
  }

  // ==================== 直播分享卡片 ====================

  /// 判断该动态是否为直播分享
  bool _isLivestreamShare(Moment moment) {
    if (moment.extra == null || moment.extra!.isEmpty) return false;
    try {
      final extra = jsonDecode(moment.extra!);
      return extra is Map && extra['type'] == 'livestream_share';
    } catch (_) {
      return false;
    }
  }

  /// 解析extra中的直播分享数据
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

  /// 构建直播分享卡片（仿微信链接卡片样式）
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
            // 封面缩略图
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
            // 标题+主播名
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
            // 箭头
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(Moment moment, int index) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.more_horiz, size: 16, color: Color(0xFF576B95)),
      ),
      onSelected: (value) {
        if (value == 'like') {
          _toggleLike(moment, index);
        } else if (value == 'comment') {
          _showCommentInput(moment);
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
                  moment.isLiked ? l10n.cancel : l10n.translate('like'),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'comment',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.comment, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(l10n.translate('comment'), style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ];
      },
      color: const Color(0xFF4C4C4C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }

  Widget _buildInteractionArea(Moment moment, int index) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 点赞列表
          if (moment.likes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.favorite, size: 14, color: Color(0xFF576B95)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Wrap(
                      children: moment.likes.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final like = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: GestureDetector(
                            onTap: () => _navigateToProfile(like.userId),
                            child: Text(
                              '${like.user?.nickname ?? '${AppLocalizations.of(context)!.translate('user')}${like.userId}'}${idx < moment.likes.length - 1 ? ',' : ''}',
                              style: const TextStyle(
                                color: Color(0xFF576B95),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          // 分隔线
          if (moment.likes.isNotEmpty && moment.comments.isNotEmpty)
            Divider(height: 1, color: Colors.grey[300]),
          // 评论列表
          if (moment.comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: moment.comments.map((comment) {
                  final isReply = comment.replyUser != null;
                  return GestureDetector(
                    onTap: () => _showCommentInput(moment, replyTo: comment),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87, height: 1.4),
                          children: [
                            TextSpan(
                              text: comment.user?.nickname ??
                                  '${AppLocalizations.of(context)!.translate('user')}${comment.userId}',
                              style:
                                  const TextStyle(color: Color(0xFF576B95)),
                            ),
                            if (isReply) ...[
                              TextSpan(
                                text: ' ${AppLocalizations.of(context)!.translate('reply_to').replaceAll('{name}', '').trim()} ',
                                style: const TextStyle(color: Colors.black87),
                              ),
                              TextSpan(
                                text: comment.replyUser?.nickname ??
                                    '${AppLocalizations.of(context)!.translate('user')}${comment.replyUserId}',
                                style:
                                    const TextStyle(color: Color(0xFF576B95)),
                              ),
                            ],
                            TextSpan(
                              text: '${isReply ? '' : ''}：${comment.content}',
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    final l10n = AppLocalizations.of(context)!;
    final isReply = _replyToComment != null;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 8,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                decoration: InputDecoration(
                  hintText: isReply
                      ? '${l10n.replyToUser(_replyToComment!.user?.nickname ?? '')}:'
                      : l10n.translate('comment'),
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitComment(),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _submitComment,
              child: Text(l10n.send),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                setState(() {
                  _replyMomentId = null;
                  _replyToComment = null;
                });
                FocusScope.of(context).unfocus();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: _hasMore
            ? const CircularProgressIndicator()
            : Text(
                AppLocalizations.of(context)!.translate('no_more'),
                style: TextStyle(color: Colors.grey[500]),
              ),
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
      return l10n.translate('just_now');
    } else if (diff.inMinutes < 60) {
      return l10n.translate('minutes_ago').replaceAll('{count}', diff.inMinutes.toString());
    } else if (diff.inHours < 24) {
      return l10n.translate('hours_ago').replaceAll('{count}', diff.inHours.toString());
    } else if (diff.inDays < 2) {
      return l10n.translate('yesterday');
    } else if (diff.inDays < 7) {
      return l10n.translate('days_ago').replaceAll('{days}', diff.inDays.toString());
    } else if (time.year == now.year) {
      return l10n.translate('date_format')
          .replaceAll('{month}', time.month.toString())
          .replaceAll('{day}', time.day.toString());
    } else {
      return l10n.translate('full_date_format')
          .replaceAll('{year}', time.year.toString())
          .replaceAll('{month}', time.month.toString())
          .replaceAll('{day}', time.day.toString());
    }
  }
}

/// 通知列表弹窗
class _NotificationSheet extends StatefulWidget {
  final MomentApi momentApi;
  final Function(dynamic) onTap;

  const _NotificationSheet({
    required this.momentApi,
    required this.onTap,
  });

  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final response = await widget.momentApi.getNotifications();
      if (response.success && response.data != null) {
        setState(() {
          _notifications = (response.data['list'] as List?) ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.translate('message_notifications'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.of(context)!.translate('no_notifications'), style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final l10n = AppLocalizations.of(context)!;
                          final notification = _notifications[index];
                          final type = notification['type'] ?? '';
                          final user = notification['from_user'];
                          final content = notification['content'] ?? '';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user != null && user['avatar'] != null
                                  ? CachedNetworkImageProvider(
                                      EnvConfig.instance.getFileUrl(user['avatar']))
                                  : null,
                              child: user == null || user['avatar'] == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(
                              user?['nickname'] ?? l10n.translate('user'),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              type == 'like' ? l10n.translate('liked_your_moment') : '${l10n.translate('commented_on_you')}: $content',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Icon(
                              type == 'like' ? Icons.favorite : Icons.comment,
                              color: type == 'like' ? Colors.red : Colors.blue,
                              size: 20,
                            ),
                            onTap: () => widget.onTap(notification),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
