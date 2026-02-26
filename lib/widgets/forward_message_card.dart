/// 合并转发消息卡片组件
/// 显示合并转发消息的预览，点击可查看详情

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/models/message.dart';
import '../utils/image_proxy.dart';

/// 合并转发消息数据
class ForwardMessageData {
  final int forwardType;
  final String title;
  final int messageCount;
  final String preview;
  final List<ForwardedMessageItem> messages;

  ForwardMessageData({
    required this.forwardType,
    required this.title,
    required this.messageCount,
    required this.preview,
    required this.messages,
  });

  factory ForwardMessageData.fromJson(Map<String, dynamic> json) {
    final messagesList = json['messages'] as List? ?? [];
    return ForwardMessageData(
      forwardType: json['forward_type'] ?? 2,
      title: json['title'] ?? 'Chat history',
      messageCount: json['message_count'] ?? messagesList.length,
      preview: json['preview'] ?? '',
      messages: messagesList
          .map((m) => ForwardedMessageItem.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 从消息的extra字段解析
  static ForwardMessageData? fromMessage(Message message) {
    if (message.extra == null || message.extra!.isEmpty) return null;
    try {
      final json = jsonDecode(message.extra!) as Map<String, dynamic>;
      return ForwardMessageData.fromJson(json);
    } catch (e) {
      return null;
    }
  }
}

/// 转发消息中的单条消息项
class ForwardedMessageItem {
  final String msgId;
  final int fromUserId;
  final Map<String, dynamic>? fromUser;
  final int type;
  final String content;
  final DateTime? createdAt;

  ForwardedMessageItem({
    required this.msgId,
    required this.fromUserId,
    this.fromUser,
    required this.type,
    required this.content,
    this.createdAt,
  });

  factory ForwardedMessageItem.fromJson(Map<String, dynamic> json) {
    return ForwardedMessageItem(
      msgId: json['msg_id']?.toString() ?? '',
      fromUserId: json['from_user_id'] ?? 0,
      fromUser: json['from_user'] as Map<String, dynamic>?,
      type: json['type'] ?? 1,
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  /// 获取发送者昵称
  String getSenderName(AppLocalizations l10n) {
    if (fromUser != null) {
      return fromUser!['nickname']?.toString() ??
          fromUser!['name']?.toString() ??
          '${l10n.translate('user')}$fromUserId';
    }
    return '${l10n.translate('user')}$fromUserId';
  }

  /// 获取内容显示文本
  String getDisplayContent(AppLocalizations l10n) {
    switch (type) {
      case MessageType.text:
        return content;
      case MessageType.image:
        return '[${l10n.translate('image')}]';
      case MessageType.voice:
        return '[${l10n.translate('voice')}]';
      case MessageType.video:
        return '[${l10n.translate('video')}]';
      case MessageType.file:
        return '[${l10n.translate('file')}]';
      case MessageType.location:
        return '[${l10n.translate('location')}]';
      case MessageType.card:
        return '[${l10n.translate('businessCard')}]';
      case MessageType.forward:
        return '[${l10n.translate('chatRecord')}]';
      default:
        return '[${l10n.translate('message')}]';
    }
  }
}

/// 合并转发消息卡片
class ForwardMessageCard extends StatelessWidget {
  final Message message;
  final bool isSelf;

  const ForwardMessageCard({
    super.key,
    required this.message,
    required this.isSelf,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final data = ForwardMessageData.fromMessage(message);
    if (data == null) {
      return Text(l10n.translate('cannotParseChatRecord'));
    }

    return GestureDetector(
      onTap: () => _showForwardDetail(context, data),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(
          color: isSelf ? Colors.white : AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Container(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title.isNotEmpty ? data.title : l10n.translate('chatRecord'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 预览内容
                  ...data.messages.take(3).map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${item.getSenderName(l10n)}: ${item.getDisplayContent(l10n)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
              ),
            ),
            // 底部
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(7),
                  bottomRight: Radius.circular(7),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 12,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.translate('chatRecord'),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l10n.translate('messageCountText').replaceAll('{count}', data.messageCount.toString()),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
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

  /// 显示转发消息详情
  void _showForwardDetail(BuildContext context, ForwardMessageData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForwardDetailScreen(data: data),
      ),
    );
  }
}

/// 合并转发详情页面
class ForwardDetailScreen extends StatelessWidget {
  final ForwardMessageData data;

  const ForwardDetailScreen({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(data.title.isNotEmpty ? data.title : l10n.translate('chatRecord')),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: data.messages.length,
        itemBuilder: (context, index) {
          final item = data.messages[index];
          return _buildMessageItem(context, item, l10n);
        },
      ),
    );
  }

  Widget _buildMessageItem(BuildContext context, ForwardedMessageItem item, AppLocalizations l10n) {
    final senderName = item.getSenderName(l10n);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: item.fromUser?['avatar'] != null &&
                    item.fromUser!['avatar'].toString().isNotEmpty
                ? NetworkImage(item.fromUser!['avatar'].toString().proxied)
                : null,
            child: item.fromUser?['avatar'] == null ||
                    item.fromUser!['avatar'].toString().isEmpty
                ? Text(
                    senderName.isNotEmpty ? senderName[0] : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 发送者和时间
                Row(
                  children: [
                    Text(
                      senderName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.createdAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(item.createdAt!),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // 消息内容
                _buildContent(item, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ForwardedMessageItem item, AppLocalizations l10n) {
    switch (item.type) {
      case MessageType.text:
        return Text(
          item.content,
          style: const TextStyle(fontSize: 14),
        );
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            item.content,
            width: 150,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 150,
              height: 100,
              color: AppColors.background,
              child: const Icon(Icons.broken_image),
            ),
          ),
        );
      case MessageType.voice:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow, size: 16),
              const SizedBox(width: 4),
              Text(item.getDisplayContent(l10n)),
            ],
          ),
        );
      case MessageType.file:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  item.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(item.getDisplayContent(l10n)),
        );
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (time.year == now.year) {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.year}/${time.month}/${time.day}';
    }
  }
}
