/// 聊天记录搜索页面
/// 支持搜索群聊中的历史消息

import 'package:flutter/material.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/models/message.dart';
import 'package:im_client/services/local_message_service.dart';
import 'package:im_client/screens/chat/chat_screen.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class ChatHistorySearchScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const ChatHistorySearchScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<ChatHistorySearchScreen> createState() => _ChatHistorySearchScreenState();
}

class _ChatHistorySearchScreenState extends State<ChatHistorySearchScreen> {
  final LocalMessageService _messageService = LocalMessageService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Message> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _currentKeyword = '';
  late String _conversId;

  @override
  void initState() {
    super.initState();
    // 设置会话ID
    _conversId = 'g_${widget.groupId}';
    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _currentKeyword = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _currentKeyword = keyword.trim();
    });

    // 从本地消息存储搜索消息（只搜索当前群聊）
    final results = await _messageService.searchMessages(
      keyword.trim(),
      conversId: _conversId,
      limit: 100,
    );

    // 过滤只保留文本消息 (type == 1)
    final filteredResults = results.where((m) => m.type == 1).toList();

    setState(() {
      _searchResults = filteredResults;
      _isSearching = false;
      _hasSearched = true;
    });
  }

  String _formatTime(DateTime? time, AppLocalizations l10n) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (diff.inDays == 1) {
      return '${l10n.yesterday} ${DateFormat('HH:mm').format(time)}';
    } else if (diff.inDays < 7) {
      final weekdays = [l10n.sunday, l10n.monday, l10n.tuesday, l10n.wednesday, l10n.thursday, l10n.friday, l10n.saturday];
      return '${weekdays[time.weekday % 7]} ${DateFormat('HH:mm').format(time)}';
    } else if (time.year == now.year) {
      return DateFormat(l10n.fullDateFormat).format(time);
    } else {
      return DateFormat(l10n.fullDateFormat).format(time);
    }
  }

  String _highlightKeyword(String text, String keyword) {
    // 返回原文本，高亮在Widget中实现
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 36,
          margin: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            onChanged: _search,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: l10n.searchChatHistory,
              hintStyle: TextStyle(color: AppColors.textHint),
              prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textHint),
              suffixIcon: _searchController.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _search('');
                      },
                      child: Icon(Icons.close, size: 18, color: AppColors.textHint),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: AppColors.textHint.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.enterKeywordToSearch,
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textHint.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '${l10n.noResultsFor}"$_currentKeyword"',
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 搜索结果统计
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.background,
          child: Text(
            '${l10n.foundMessages}: ${_searchResults.length}',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        // 搜索结果列表
        Expanded(
          child: ListView.separated(
            itemCount: _searchResults.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final message = _searchResults[index];
              return _buildMessageItem(message, l10n);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessageItem(Message message, AppLocalizations l10n) {
    return Container(
      color: AppColors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            (message.fromUser?.nickname?.isNotEmpty == true)
                ? message.fromUser!.nickname[0].toUpperCase()
                : '?',
            style: const TextStyle(color: AppColors.primary),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                message.fromUser?.nickname ?? l10n.unknownUser,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatTime(message.createdAt, l10n),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _buildHighlightedText(message.content, _currentKeyword),
        ),
        onTap: () {
          // 创建会话对象并跳转到聊天页面
          final conversation = Conversation(
            conversId: _conversId,
            type: 2, // 群聊
            targetId: widget.groupId,
            targetInfo: {
              'id': widget.groupId,
              'name': widget.groupName,
            },
          );

          // 关闭搜索页面，然后用替换方式打开聊天页面（定位到目标消息）
          Navigator.pop(context); // 关闭搜索页
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                conversation: conversation,
                targetMsgId: message.msgId,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHighlightedText(String text, String keyword) {
    if (keyword.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerKeyword, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(
            text: text.substring(start),
            style: TextStyle(color: AppColors.textSecondary),
          ));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: TextStyle(color: AppColors.textSecondary),
        ));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + keyword.length),
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ));

      start = index + keyword.length;
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 13),
        children: spans,
      ),
    );
  }
}
