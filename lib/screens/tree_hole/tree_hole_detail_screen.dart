/// 树洞详情页面
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/tree_hole_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:intl/intl.dart';

class TreeHoleDetailScreen extends StatefulWidget {
  final TreeHolePost post;

  const TreeHoleDetailScreen({super.key, required this.post});

  @override
  State<TreeHoleDetailScreen> createState() => _TreeHoleDetailScreenState();
}

class _TreeHoleDetailScreenState extends State<TreeHoleDetailScreen> {
  final TreeHoleApi _api = TreeHoleApi(ApiClient());
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  late TreeHolePost _post;
  bool _isLoading = true;
  bool _isSubmitting = false;
  TreeHoleComment? _replyTo;
  bool _hasChanges = false;

  // 服务器话题 -> i18n key 映射
  static const Map<String, String> _topicKeyMap = {
    '日常': 'topic_daily',
    '情感': 'topic_emotion',
    '工作': 'topic_work',
    '学习': 'topic_study',
    '吐槽': 'topic_vent',
    '求助': 'topic_help',
    '分享': 'topic_share',
    '深夜': 'topic_night',
    '职场': 'topic_career',
    '校园': 'topic_campus',
    '暗恋': 'topic_crush',
    '失恋': 'topic_heartbreak',
    '单身': 'topic_single',
    '脱单': 'topic_relationship',
    '焦虑': 'topic_anxiety',
    '压力': 'topic_pressure',
    '迷茫': 'topic_confused',
    '成长': 'topic_growth',
    '梦想': 'topic_dream',
    '回忆': 'topic_memory',
    '秘密': 'topic_secret',
    '家庭': 'topic_family',
    '友情': 'topic_friendship',
    '八卦': 'topic_gossip',
    '追星': 'topic_fandom',
    '游戏': 'topic_game',
    '美食': 'topic_food',
    '旅行': 'topic_travel',
    '健身': 'topic_fitness',
    '穿搭': 'topic_fashion',
    '音乐': 'topic_music',
    '电影': 'topic_movie',
    '读书': 'topic_reading',
    '其他': 'topic_other',
  };

  // 获取话题的本地化显示名称
  String _getTopicDisplayName(AppLocalizations l10n, String serverTopic) {
    final key = _topicKeyMap[serverTopic] ?? 'topic_other';
    return l10n.translate(key);
  }

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadDetail();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    try {
      final response = await _api.getTreeHoleDetail(_post.id);
      if (response.success && response.data != null) {
        setState(() {
          _post = TreeHolePost.fromJson(response.data as Map<String, dynamic>);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load details: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    try {
      final response = await _api.toggleLike(_post.id);
      if (response.success) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _post = _post.copyWith(
            isLiked: data['liked'] ?? !_post.isLiked,
            likeCount: data['like_count'] ?? _post.likeCount,
          );
          _hasChanges = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to like: $e');
    }
  }

  Future<void> _toggleCommentLike(int index) async {
    final comment = _post.comments[index];
    try {
      final response = await _api.toggleCommentLike(comment.id);
      if (response.success) {
        // 刷新详情获取最新状态
        _loadDetail();
        _hasChanges = true;
      }
    } catch (e) {
      debugPrint('Failed to like the comment: $e');
    }
  }

  Future<void> _submitComment() async {
    final l10n = AppLocalizations.of(context)!;
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await _api.comment(
        treeHoleId: _post.id,
        content: content,
        replyToId: _replyTo?.id,
        replyAnonId: _replyTo?.anonymousId,
      );

      if (response.success) {
        _commentController.clear();
        _replyTo = null;
        _commentFocusNode.unfocus();
        _loadDetail();
        _hasChanges = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.commentSuccess)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message ?? l10n.commentFailed)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.commentFailed}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _replyToComment(TreeHoleComment comment) {
    setState(() => _replyTo = comment);
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyTo = null);
  }

  void _showImageViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ImageViewerScreen(
          images: _post.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _deletePost() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirm),
        content: Text(l10n.deleteTreeHoleConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await _api.deleteTreeHole(_post.id);
        if (response.success && mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.deleteFailed}: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(l10n.postDetails),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _deletePost();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildPostContent(l10n),
                          const SizedBox(height: 8),
                          _buildCommentSection(l10n),
                        ],
                      ),
                    ),
                  ),
                  _buildCommentInput(l10n),
                ],
              ),
      ),
    );
  }

  Widget _buildPostContent(AppLocalizations l10n) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getAvatarColor(_post.anonymousId),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _post.anonymousId,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          if (_post.isHot) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.popular,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(_post.createdAt, l10n),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_post.topic != null && _post.topic!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#${_getTopicDisplayName(l10n, _post.topic!)}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 内容
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _post.content,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          ),
          // 标签
          if (_post.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _post.tags.map((tag) {
                  return Text(
                    '#$tag',
                    style: TextStyle(
                      color: Colors.teal[600],
                      fontSize: 14,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          // 图片
          if (_post.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildImages(),
            ),
          ],
          // 统计
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.remove_red_eye_outlined,
                    size: 18, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${_post.viewCount}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        _post.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 22,
                        color: _post.isLiked ? Colors.red : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_post.likeCount}',
                        style: TextStyle(
                          color:
                              _post.isLiked ? Colors.red : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Icon(Icons.chat_bubble_outline,
                    size: 20, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${_post.commentCount}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImages() {
    if (_post.images.length == 1) {
      return GestureDetector(
        onTap: () => _showImageViewer(0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: CachedNetworkImage(
              imageUrl: EnvConfig.instance.getFileUrl(_post.images[0]),
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _post.images.length == 4 ? 2 : 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _post.images.length > 9 ? 9 : _post.images.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _showImageViewer(index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: EnvConfig.instance.getFileUrl(_post.images[index]),
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[200]),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 20),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentSection(AppLocalizations l10n) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${l10n.comments} (${_post.comments.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          const Divider(height: 1),
          if (_post.comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      l10n.noComments,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _post.comments.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 60),
              itemBuilder: (context, index) =>
                  _buildCommentItem(_post.comments[index], index, l10n),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(TreeHoleComment comment, int index, AppLocalizations l10n) {
    return InkWell(
      onTap: () => _replyToComment(comment),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getAvatarColor(comment.anonymousId),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.anonymousId,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      if (comment.isAuthor) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.originalPoster,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (comment.replyAnonId != null &&
                      comment.replyAnonId!.isNotEmpty)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${l10n.replyTo} ',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          TextSpan(
                            text: comment.replyAnonId,
                            style: const TextStyle(color: Colors.blue),
                          ),
                          const TextSpan(text: ': '),
                          TextSpan(text: comment.content),
                        ],
                      ),
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    )
                  else
                    Text(
                      comment.content,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _formatTime(comment.createdAt, l10n),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _toggleCommentLike(index),
                        child: Row(
                          children: [
                            Icon(
                              comment.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 16,
                              color: comment.isLiked
                                  ? Colors.red
                                  : Colors.grey[500],
                            ),
                            if (comment.likeCount > 0) ...[
                              const SizedBox(width: 2),
                              Text(
                                '${comment.likeCount}',
                                style: TextStyle(
                                  color: comment.isLiked
                                      ? Colors.red
                                      : Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -1),
            blurRadius: 3,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    Text(
                      '${l10n.replyTo} ${_replyTo!.anonymousId}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        maxLines: 1,
                        decoration: InputDecoration(
                          hintText: _replyTo != null
                              ? '${l10n.replyTo} ${_replyTo!.anonymousId}...'
                              : '${l10n.anonymousComment}...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submitComment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              l10n.send,
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAvatarColor(String anonymousId) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];
    final index = anonymousId.hashCode.abs() % colors.length;
    return colors[index];
  }

  String _formatTime(DateTime time, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return l10n.justNow;
    } else if (diff.inMinutes < 60) {
      return l10n.minutesAgo(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return l10n.hoursAgo(diff.inHours);
    } else if (diff.inDays < 7) {
      return l10n.daysAgo(diff.inDays);
    } else {
      return DateFormat('MM-dd HH:mm').format(time);
    }
  }
}

/// 图片查看器
class _ImageViewerScreen extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const _ImageViewerScreen({
    required this.images,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(
                  EnvConfig.instance.getFileUrl(images[index]),
                ),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            itemCount: images.length,
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            pageController: PageController(initialPage: initialIndex),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
