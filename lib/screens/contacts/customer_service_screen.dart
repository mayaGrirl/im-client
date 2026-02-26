import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/system_api.dart';
import '../../models/system.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../constants/app_constants.dart';
import '../../config/env_config.dart';
import '../../providers/auth_provider.dart';
import '../../utils/conversation_utils.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_screen.dart';
import '../../utils/image_proxy.dart';

/// 客服列表页面
class CustomerServiceScreen extends StatefulWidget {
  const CustomerServiceScreen({super.key});

  @override
  State<CustomerServiceScreen> createState() => _CustomerServiceScreenState();
}

class _CustomerServiceScreenState extends State<CustomerServiceScreen> {
  final SystemApi _systemApi = SystemApi();
  List<CustomerService> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomerServices();
  }

  Future<void> _loadCustomerServices() async {
    setState(() => _isLoading = true);
    try {
      final services = await _systemApi.getCustomerServices();
      setState(() {
        _services = services;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('load_failed'))),
        );
      }
    }
  }

  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    // 防止只有 / 的情况
    if (url == '/') return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final baseUrl = EnvConfig.instance.baseUrl;
    if (url.startsWith('/')) return '$baseUrl$url';
    return '$baseUrl/$url';
  }

  void _openChat(CustomerService service) {
    // 获取当前用户ID
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.userId;
    final l10n = AppLocalizations.of(context)!;

    // 使用工具类生成正确的conversId格式
    final conversId = ConversationUtils.generateConversId(
      userId1: currentUserId,
      userId2: service.userId,
    );

    // 创建客服的User对象用于targetInfo
    final serviceUser = User(
      id: service.userId,
      username: service.name,
      nickname: service.name,
      avatar: service.avatar,
      bio: service.description,
    );

    // 创建与客服的会话
    final conversation = Conversation(
      conversId: conversId,
      type: 1, // 私聊
      targetId: service.userId,
      lastMsgPreview: service.welcomeMsg.isNotEmpty ? service.welcomeMsg : l10n.translate('online_customer_service'),
      lastMsgTime: DateTime.now(),
      unreadCount: 0,
      isTop: false,
      isMute: false,
      targetInfo: serviceUser,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: conversation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('online_customer_service')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _services.isEmpty
              ? _buildEmptyState(l10n)
              : RefreshIndicator(
                  onRefresh: _loadCustomerServices,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _services.length,
                    itemBuilder: (context, index) {
                      return _buildServiceItem(_services[index], l10n);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.support_agent,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.translate('no_customer_service'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('please_try_later'),
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem(CustomerService service, AppLocalizations l10n) {
    final avatarUrl = _getFullUrl(service.avatar);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _openChat(service),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 头像
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
                    child: avatarUrl.isEmpty
                        ? const Icon(
                            Icons.support_agent,
                            color: AppColors.primary,
                            size: 28,
                          )
                        : null,
                  ),
                  // 在线状态
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: service.isOnline ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: service.isOnline
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            service.isOnline ? l10n.translate('online') : l10n.translate('offline'),
                            style: TextStyle(
                              color: service.isOnline ? Colors.green : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (service.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        service.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // 箭头
              const Icon(
                Icons.chat_bubble_outline,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
