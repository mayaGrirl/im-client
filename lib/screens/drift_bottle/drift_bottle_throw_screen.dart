/// 扔漂流瓶页面
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/drift_bottle_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';

class DriftBottleThrowScreen extends StatefulWidget {
  const DriftBottleThrowScreen({super.key});

  @override
  State<DriftBottleThrowScreen> createState() => _DriftBottleThrowScreenState();
}

class _DriftBottleThrowScreenState extends State<DriftBottleThrowScreen> {
  final DriftBottleApi _api = DriftBottleApi(ApiClient());
  final TextEditingController _contentController = TextEditingController();

  int _targetGender = 0; // 0不限 1男 2女
  bool _isAnonymous = true;
  bool _isThrowing = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _throwBottle() async {
    final l10n = AppLocalizations.of(context)!;
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('please_enter_content'))),
      );
      return;
    }

    if (content.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('content_too_long'))),
      );
      return;
    }

    setState(() => _isThrowing = true);

    try {
      final result = await _api.throwBottle(
        type: BottleType.text,
        content: content,
        targetGender: _targetGender,
        isAnonymous: _isAnonymous,
      );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.translate('bottle_success_hint')),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? l10n.translate('throw_bottle_failed'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('throw_bottle_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isThrowing = false);
      }
    }
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
        title: Text(l10n.translate('throw_bottle')),
        actions: [
          TextButton(
            onPressed: _isThrowing ? null : _throwBottle,
            child: _isThrowing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    l10n.translate('throw_out'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 内容输入区
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _contentController,
                      maxLines: 8,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: l10n.translate('write_and_throw'),
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        counterStyle: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 选项区
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // 希望谁捞到
                    _buildOptionRow(
                      icon: Icons.people,
                      label: l10n.translate('hope_who_picks_up'),
                      child: Row(
                        children: [
                          _buildGenderChip(0, l10n.noLimit),
                          const SizedBox(width: 8),
                          _buildGenderChip(1, l10n.translate('boys')),
                          const SizedBox(width: 8),
                          _buildGenderChip(2, l10n.translate('girls')),
                        ],
                      ),
                    ),
                    const Divider(height: 24),
                    // 匿名开关
                    _buildOptionRow(
                      icon: Icons.visibility_off,
                      label: l10n.translate('send_anonymously'),
                      child: Switch(
                        value: _isAnonymous,
                        onChanged: (value) => setState(() => _isAnonymous = value),
                        activeColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 提示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          l10n.translate('reminder'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ${l10n.translate('bottle_float_days')}\n'
                      '• ${l10n.translate('max_pick_up_times')}\n'
                      '• ${l10n.translate('picker_can_reply')}\n'
                      '• ${l10n.translate('be_civil')}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionRow({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey[700]),
        ),
        const Spacer(),
        child,
      ],
    );
  }

  Widget _buildGenderChip(int gender, String label) {
    final isSelected = _targetGender == gender;
    return GestureDetector(
      onTap: () => setState(() => _targetGender = gender),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
