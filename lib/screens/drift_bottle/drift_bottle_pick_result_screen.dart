/// 捞到漂流瓶结果页面
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/drift_bottle_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import '../../utils/image_proxy.dart';

class DriftBottlePickResultScreen extends StatefulWidget {
  final DriftBottle bottle;

  const DriftBottlePickResultScreen({
    super.key,
    required this.bottle,
  });

  @override
  State<DriftBottlePickResultScreen> createState() =>
      _DriftBottlePickResultScreenState();
}

class _DriftBottlePickResultScreenState
    extends State<DriftBottlePickResultScreen>
    with SingleTickerProviderStateMixin {
  final DriftBottleApi _api = DriftBottleApi(ApiClient());
  final TextEditingController _replyController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _isReplying = false;
  bool _showReplyInput = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _throwBack() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await _api.throwBackBottle(widget.bottle.id);
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('bottle_thrown_back'))),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? l10n.translate('operation_failed'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('operation_failed')}: $e')),
        );
      }
    }
  }

  Future<void> _reply() async {
    final l10n = AppLocalizations.of(context)!;
    final content = _replyController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('please_enter_reply'))),
      );
      return;
    }

    setState(() => _isReplying = true);

    try {
      final result = await _api.replyBottle(
        bottleId: widget.bottle.id,
        content: content,
      );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.translate('reply_success')),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? l10n.translate('reply_failed'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('reply_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReplying = false);
      }
    }
  }

  String _getFullUrl(String url) {
    if (url.isEmpty || url == '/') return '';
    if (url.startsWith('http')) return url;
    return '${EnvConfig.instance.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF1E90FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.translate('picked_a_bottle')),
      ),
      body: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: _buildContent(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 瓶子卡片
          _buildBottleCard(),
          const SizedBox(height: 20),
          // 操作按钮
          if (_showReplyInput) _buildReplyInput() else _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildBottleCard() {
    final l10n = AppLocalizations.of(context)!;
    final bottle = widget.bottle;
    final user = bottle.user;
    final avatarUrl = user != null ? _getFullUrl(user.avatar) : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // 发送者信息
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _getGenderColor(bottle.gender).withOpacity(0.2),
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
                child: avatarUrl.isEmpty
                    ? Icon(
                        _getGenderIcon(bottle.gender),
                        color: _getGenderColor(bottle.gender),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.nickname ?? l10n.translate('anonymous_user'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatTime(bottle.createdAt, l10n),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // 性别标识
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getGenderColor(bottle.gender).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getGenderIcon(bottle.gender),
                      size: 14,
                      color: _getGenderColor(bottle.gender),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getGenderText(bottle.gender, l10n),
                      style: TextStyle(
                        color: _getGenderColor(bottle.gender),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          // 瓶子内容
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              bottle.content,
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 瓶子信息
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildInfoChip(Icons.remove_red_eye, l10n.translate('viewed_times').replaceAll('{count}', bottle.pickCount.toString())),
              const SizedBox(width: 16),
              _buildInfoChip(Icons.replay, l10n.translate('thrown_back_times').replaceAll('{count}', bottle.throwBackCount.toString())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        // 扔回
        Expanded(
          child: _buildActionButton(
            icon: Icons.replay,
            label: l10n.translate('throw_back_to_sea'),
            color: Colors.grey,
            onTap: _throwBack,
          ),
        ),
        const SizedBox(width: 16),
        // 回复
        Expanded(
          child: _buildActionButton(
            icon: Icons.chat,
            label: l10n.translate('reply_to_sender'),
            color: AppColors.primary,
            onTap: () => setState(() => _showReplyInput = true),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyInput() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _replyController,
            maxLines: 4,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: l10n.translate('write_to_sender'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showReplyInput = false),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isReplying ? null : _reply,
                  child: _isReplying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.send),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getGenderColor(int gender) {
    switch (gender) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getGenderIcon(int gender) {
    switch (gender) {
      case 1:
        return Icons.male;
      case 2:
        return Icons.female;
      default:
        return Icons.person;
    }
  }

  String _getGenderText(int gender, AppLocalizations l10n) {
    switch (gender) {
      case 1:
        return l10n.translate('boys');
      case 2:
        return l10n.translate('girls');
      default:
        return l10n.translate('unknown');
    }
  }

  String _formatTime(DateTime time, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return l10n.translate('just_now');
    } else if (diff.inHours < 1) {
      return l10n.translate('minutes_ago').replaceAll('{count}', diff.inMinutes.toString());
    } else if (diff.inDays < 1) {
      return l10n.translate('hours_ago').replaceAll('{count}', diff.inHours.toString());
    } else if (diff.inDays < 7) {
      return l10n.translate('days_ago').replaceAll('{days}', diff.inDays.toString());
    } else {
      return l10n.translate('date_format')
          .replaceAll('{month}', time.month.toString())
          .replaceAll('{day}', time.day.toString());
    }
  }
}
