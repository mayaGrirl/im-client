/// 视频评论底部弹出面板

import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/modules/small_video/api/small_video_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/modules/small_video/models/small_video.dart';
import 'package:provider/provider.dart';
import 'package:im_client/modules/small_video/providers/small_video_provider.dart';

class VideoCommentSheet extends StatefulWidget {
  final int videoId;
  final int videoUserId;

  const VideoCommentSheet({
    super.key,
    required this.videoId,
    required this.videoUserId,
  });

  @override
  State<VideoCommentSheet> createState() => _VideoCommentSheetState();
}

class _VideoCommentSheetState extends State<VideoCommentSheet> {
  final SmallVideoApi _api = SmallVideoApi(ApiClient());
  final TextEditingController _inputController = TextEditingController();

  List<SmallVideoComment> _comments = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  int _totalCount = 0;
  String? _error;

  // 回复模式
  int? _replyToCommentId;
  int? _replyToUserId;
  String? _replyToName;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification &&
        notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
      _loadMore();
    }
    return false;
  }

  Future<void> _loadComments() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _api.getComments(widget.videoId, page: 1);
      if (response.success && response.data != null) {
        final data = response.data;
        List list;
        if (data is Map && data['list'] != null) {
          list = data['list'] as List;
          _totalCount = data['total'] is int ? data['total'] : (data['total'] as num?)?.toInt() ?? list.length;
        } else if (data is List) {
          list = data;
          _totalCount = list.length;
        } else {
          list = [];
          _totalCount = 0;
        }
        setState(() {
          _comments = list.map((e) => SmallVideoComment.fromJson(e)).toList();
          _page = 2;
          _hasMore = list.length >= 20;
        });
        // 同步实际评论数到Provider，修正本地缓存不一致
        if (mounted) {
          context.read<SmallVideoProvider>().syncCommentCount(widget.videoId, _totalCount);
        }
      } else {
        setState(() => _error = response.message ?? 'Failed to load comments');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final response = await _api.getComments(widget.videoId, page: _page);
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
          _comments.addAll(list.map((e) => SmallVideoComment.fromJson(e)));
          _page++;
          _hasMore = list.length >= 20;
        });
      }
    } catch (_) {
      // 加载更多失败时不阻塞，下次滚动会重试
    }

    setState(() => _isLoading = false);
  }

  Future<void> _sendComment() async {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;

    try {
      final response = await _api.createComment(
        widget.videoId,
        content: content,
        parentId: _replyToCommentId,
        replyToUid: _replyToUserId,
      );

      if (response.success) {
        _inputController.clear();
        _cancelReply();
        // 增加评论计数
        if (mounted) context.read<SmallVideoProvider>().incrementCommentCount(widget.videoId);
        _totalCount++;
        // 重新加载评论
        _page = 1;
        _loadComments();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message ?? '评论发送失败'), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络错误，请重试'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  void _setReplyTo(SmallVideoComment comment) {
    setState(() {
      _replyToCommentId = comment.parentId > 0 ? comment.parentId : comment.id;
      _replyToUserId = comment.userId;
      _replyToName = comment.user?.nickname ?? '';
    });
    // 聚焦输入框
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUserId = null;
      _replyToName = null;
    });
  }

  Future<void> _toggleCommentLike(SmallVideoComment comment) async {
    final index = _comments.indexWhere((c) => c.id == comment.id);
    if (index == -1) return;

    final wasLiked = comment.isLiked;
    setState(() {
      _comments[index] = comment.copyWith(
        isLiked: !wasLiked,
        likeCount: wasLiked ? comment.likeCount - 1 : comment.likeCount + 1,
      );
    });

    try {
      if (wasLiked) {
        await _api.unlikeComment(comment.id);
      } else {
        await _api.likeComment(comment.id);
      }
    } catch (e) {
      // 回滚
      setState(() => _comments[index] = comment);
    }
  }

  String _formatTime(DateTime time, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return l10n.translate('sv_just_now');
    if (diff.inHours < 1) return l10n.translate('sv_minutes_ago').replaceAll('{count}', '${diff.inMinutes}');
    if (diff.inDays < 1) return l10n.translate('sv_hours_ago').replaceAll('{count}', '${diff.inHours}');
    if (diff.inDays < 30) return l10n.translate('sv_days_ago').replaceAll('{count}', '${diff.inDays}');
    return '${time.month}/${time.day}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // 拖拽手柄
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${l10n.translate('sv_comments_title')} $_totalCount',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 评论列表
              Expanded(
                child: _error != null && _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 40, color: AppColors.textHint),
                            const SizedBox(height: 8),
                            Text(
                              l10n.translate('sv_no_comments'),
                              style: TextStyle(color: AppColors.textHint, fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _loadComments,
                              child: Text(
                                l10n.translate('sv_retry'),
                                style: TextStyle(color: AppColors.primary, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _comments.isEmpty && !_isLoading
                    ? Center(
                        child: Text(
                          l10n.translate('sv_no_comments'),
                          style: TextStyle(color: AppColors.textHint, fontSize: 15),
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: _onScrollNotification,
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _comments.length + (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _comments.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _buildCommentItem(_comments[index], l10n);
                          },
                        ),
                      ),
              ),

              // 回复提示
              if (_replyToName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Text(
                        l10n.translate('sv_replying_to').replaceAll('{name}', _replyToName!),
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _cancelReply,
                        child: Icon(Icons.close, size: 16, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ),

              // 输入框
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          decoration: InputDecoration(
                            hintText: l10n.translate('sv_write_comment'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          maxLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sendComment,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(SmallVideoComment comment, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像
          CircleAvatar(
            radius: 18,
            backgroundImage: comment.user?.avatar.isNotEmpty == true
                ? NetworkImage(comment.user!.avatar)
                : null,
            child: comment.user?.avatar.isEmpty != false
                ? const Icon(Icons.person, size: 18)
                : null,
          ),
          const SizedBox(width: 10),

          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 用户名
                Text(
                  comment.user?.nickname ?? '',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),

                // 回复对象
                if (comment.replyTo != null)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${l10n.translate('sv_reply')} @${comment.replyTo!.nickname} ',
                          style: TextStyle(color: AppColors.primary, fontSize: 13),
                        ),
                        TextSpan(
                          text: comment.content,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  )
                else
                  Text(comment.content, style: const TextStyle(fontSize: 14)),

                const SizedBox(height: 4),

                // 底部操作
                Row(
                  children: [
                    Text(
                      _formatTime(comment.createdAt, l10n),
                      style: TextStyle(color: AppColors.textHint, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _setReplyTo(comment),
                      child: Text(
                        l10n.translate('sv_reply'),
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),

                // 回复列表
                if (comment.replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: [
                        ...comment.replies.map((reply) =>
                          _buildReplyItem(reply, l10n),
                        ),
                        // 查看更多回复
                        if (comment.replyCount > comment.replies.length)
                          GestureDetector(
                            onTap: () => _loadMoreReplies(comment),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Text(
                                l10n.translate('sv_view_more_replies').replaceAll('{count}', '${comment.replyCount - comment.replies.length}'),
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 点赞
          GestureDetector(
            onTap: () => _toggleCommentLike(comment),
            child: Column(
              children: [
                Icon(
                  comment.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: comment.isLiked ? Colors.redAccent : AppColors.textHint,
                ),
                if (comment.likeCount > 0)
                  Text(
                    comment.likeCount.toString(),
                    style: TextStyle(color: AppColors.textHint, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMoreReplies(SmallVideoComment comment) async {
    try {
      final response = await _api.getReplies(comment.id, pageSize: 50);
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
        final allReplies = list.map((e) => SmallVideoComment.fromJson(e)).toList();
        final index = _comments.indexWhere((c) => c.id == comment.id);
        if (index != -1) {
          setState(() {
            _comments[index] = comment.copyWith(
              replies: allReplies,
              replyCount: allReplies.length,
            );
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Widget _buildReplyItem(SmallVideoComment reply, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundImage: reply.user?.avatar.isNotEmpty == true
                ? NetworkImage(reply.user!.avatar)
                : null,
            child: reply.user?.avatar.isEmpty != false
                ? const Icon(Icons.person, size: 12)
                : null,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reply.user?.nickname ?? '',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(reply.content, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
