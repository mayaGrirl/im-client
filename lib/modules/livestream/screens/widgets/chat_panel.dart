/// 直播聊天面板 - TikTok风格的滚动聊天列表
import 'package:flutter/material.dart';
import 'package:im_client/config/env_config.dart';

class ChatMessage {
  final String nickname;
  final String content;
  final String? avatar;
  final Color color;
  final bool isSystem;

  ChatMessage({
    required this.nickname,
    required this.content,
    this.avatar,
    this.color = Colors.white,
    this.isSystem = false,
  });
}

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  @override
  State<ChatPanel> createState() => ChatPanelState();
}

class ChatPanelState extends State<ChatPanel> {
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  static const int _maxMessages = 200;

  void addMessage(String nickname, String content, {String? avatar, Color? color, bool isSystem = false}) {
    setState(() {
      _messages.add(ChatMessage(
        nickname: nickname,
        content: content,
        avatar: avatar,
        color: color ?? Colors.white,
        isSystem: isSystem,
      ));
      if (_messages.length > _maxMessages) {
        _messages.removeRange(0, _messages.length - _maxMessages);
      }
    });
    _scrollToBottom();
  }

  String _getFullImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return EnvConfig.instance.getFileUrl(url);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.7,
      height: 220,
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.white, Colors.white],
            stops: [0.0, 0.15, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final msg = _messages[index];
            if (msg.isSystem) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  msg.content,
                  style: TextStyle(
                    color: Colors.yellow.withOpacity(0.8),
                    fontSize: 12,
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头像
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 0.5),
                    ),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundImage: msg.avatar != null && msg.avatar!.isNotEmpty
                          ? NetworkImage(_getFullImageUrl(msg.avatar!))
                          : null,
                      backgroundColor: Colors.grey[700],
                      child: msg.avatar == null || msg.avatar!.isEmpty
                          ? const Icon(Icons.person, size: 13, color: Colors.white60)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 昵称 + 内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.nickname,
                          style: TextStyle(
                            color: msg.color.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          msg.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
