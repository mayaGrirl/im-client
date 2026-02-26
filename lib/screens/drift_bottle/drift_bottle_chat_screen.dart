/// 漂流瓶对话页面
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/drift_bottle_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/providers/auth_provider.dart';
import '../../utils/image_proxy.dart';

class DriftBottleChatScreen extends StatefulWidget {
  final DriftBottle bottle;

  const DriftBottleChatScreen({
    super.key,
    required this.bottle,
  });

  @override
  State<DriftBottleChatScreen> createState() => _DriftBottleChatScreenState();
}

class _DriftBottleChatScreenState extends State<DriftBottleChatScreen> {
  final DriftBottleApi _api = DriftBottleApi(ApiClient());
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<BottleReply> _replies = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    setState(() => _isLoading = true);

    try {
      final result = await _api.getBottleReplies(widget.bottle.id);
      if (result.success && result.data != null) {
        setState(() {
          _replies = (result.data as List)
              .map((e) => BottleReply.fromJson(e))
              .toList();
        });
        _scrollToBottom();
      }
    } catch (e) {
      // Load replies failed
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply() async {
    final l10n = AppLocalizations.of(context)!;
    final content = _inputController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final result = await _api.replyBottle(
        bottleId: widget.bottle.id,
        content: content,
      );

      if (result.success) {
        _inputController.clear();
        _loadReplies();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? l10n.translate('send_failed'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('send_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getFullUrl(String url) {
    if (url.isEmpty || url == '/') return '';
    if (url.startsWith('http')) return url;
    return '${EnvConfig.instance.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = widget.bottle.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.nickname ?? l10n.translate('anonymous_user')),
      ),
      body: Column(
        children: [
          // 原始瓶子内容
          _buildBottleContent(),
          const Divider(height: 1),
          // 对话列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _replies.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _replies.length,
                        itemBuilder: (context, index) {
                          return _buildReplyItem(_replies[index]);
                        },
                      ),
          ),
          // 输入框
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBottleContent() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFFFF8E1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_bar, size: 16, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                l10n.translate('bottle_content'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(widget.bottle.createdAt, l10n),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.bottle.content,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Text(
        l10n.translate('no_replies_yet'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _buildReplyItem(BottleReply reply) {
    final currentUserId = context.read<AuthProvider>().user?.id ?? 0;
    final isMe = reply.fromUserId == currentUserId;
    final avatarUrl = reply.fromUser != null
        ? _getFullUrl(reply.fromUser!.avatar)
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[200],
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
              child: avatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 20, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : Colors.grey[100],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    reply.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDetailTime(reply.createdAt),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: const Icon(Icons.person, size: 20, color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: l10n.translate('enter_message'),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSending ? null : _sendReply,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays < 1) {
      return l10n.translate('today');
    } else if (diff.inDays < 2) {
      return l10n.translate('yesterday');
    } else if (diff.inDays < 7) {
      return l10n.translate('days_ago').replaceAll('{days}', diff.inDays.toString());
    } else {
      return l10n.translate('date_format')
          .replaceAll('{month}', time.month.toString())
          .replaceAll('{day}', time.day.toString());
    }
  }

  String _formatDetailTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
