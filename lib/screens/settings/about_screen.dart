/// 关于页面

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/providers/app_config_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:im_client/screens/settings/help_center_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.about),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 40),

          // Logo和版本
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chat_bubble,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.imMessenger,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${l10n.version} 1.0.0',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // 功能介绍
          _buildSection(
            context,
            children: [
              _buildMenuItem(
                icon: Icons.new_releases,
                title: l10n.featureIntro,
                onTap: () => _showFeatureIntro(context),
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.update,
                title: l10n.checkUpdate,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.alreadyLatest)),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 帮助与反馈
          _buildSection(
            context,
            children: [
              _buildMenuItem(
                icon: Icons.help_outline,
                title: l10n.helpCenter,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                  );
                },
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.feedback_outlined,
                title: l10n.feedback,
                onTap: () => _showFeedbackDialog(context),
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.star_outline,
                title: l10n.rateUs,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.translate('thanks_for_support'))),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 法律信息
          _buildSection(
            context,
            children: [
              _buildMenuItem(
                icon: Icons.article_outlined,
                title: l10n.userAgreement,
                onTap: () => _showAgreement(context, l10n.userAgreement),
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.privacy_tip_outlined,
                title: l10n.privacyPolicy,
                onTap: () => _showAgreement(context, l10n.privacyPolicy),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 联系我们
          Builder(
            builder: (context) {
              final config = context.watch<AppConfigProvider>();
              final hasContact = config.contactEmail.isNotEmpty ||
                  config.contactPhone.isNotEmpty ||
                  config.contactWechat.isNotEmpty ||
                  config.contactQQ.isNotEmpty;
              if (!hasContact) return const SizedBox.shrink();
              return _buildSection(
                context,
                children: [
                  if (config.contactPhone.isNotEmpty)
                    _buildMenuItem(
                      icon: Icons.phone,
                      title: '${l10n.translate("contact_phone")}: ${config.contactPhone}',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: config.contactPhone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.translate('copied'))),
                        );
                      },
                    ),
                  if (config.contactEmail.isNotEmpty) ...[
                    if (config.contactPhone.isNotEmpty) const Divider(indent: 56),
                    _buildMenuItem(
                      icon: Icons.email,
                      title: '${l10n.translate("contact_email")}: ${config.contactEmail}',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: config.contactEmail));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.translate('copied'))),
                        );
                      },
                    ),
                  ],
                  if (config.contactWorkTime.isNotEmpty) ...[
                    const Divider(indent: 56),
                    _buildMenuItem(
                      icon: Icons.access_time,
                      title: '${l10n.translate("work_time")}: ${config.contactWorkTime}',
                      onTap: null,
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 40),

          // 版权信息
          Center(
            child: Column(
              children: [
                Text(
                  'Copyright © 2024',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All Rights Reserved',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required List<Widget> children}) {
    return Container(
      color: AppColors.white,
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }

  void _showFeatureIntro(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.featureIntro),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _FeatureItem(
                icon: Icons.chat,
                title: l10n.translate('feature_instant_messaging'),
                desc: l10n.translate('feature_instant_messaging_desc'),
              ),
              const SizedBox(height: 16),
              _FeatureItem(
                icon: Icons.group,
                title: l10n.translate('feature_group_chat'),
                desc: l10n.translate('feature_group_chat_desc'),
              ),
              const SizedBox(height: 16),
              _FeatureItem(
                icon: Icons.video_call,
                title: l10n.translate('feature_video_call_title'),
                desc: l10n.translate('feature_video_call_desc'),
              ),
              const SizedBox(height: 16),
              _FeatureItem(
                icon: Icons.redeem,
                title: l10n.translate('feature_red_packet'),
                desc: l10n.translate('feature_red_packet_desc'),
              ),
              const SizedBox(height: 16),
              _FeatureItem(
                icon: Icons.location_on,
                title: l10n.translate('feature_location_share'),
                desc: l10n.translate('feature_location_share_desc'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.gotIt),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.feedback),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.translate('feedback_description'),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: l10n.translate('feedback_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.translate('please_input_feedback'))),
                );
                return;
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.translate('thanks_for_feedback'))),
              );
            },
            child: Text(l10n.submit),
          ),
        ],
      ),
    );
  }

  void _showAgreement(BuildContext context, String title) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            '''
$title

${l10n.translate('agreement_last_update')}

${l10n.translate('agreement_welcome')}

${l10n.translate('agreement_service_title')}
${l10n.translate('agreement_service_content')}

${l10n.translate('agreement_user_title')}
${l10n.translate('agreement_user_content')}

${l10n.translate('agreement_privacy_title')}
${l10n.translate('agreement_privacy_content')}

${l10n.translate('agreement_copyright_title')}
${l10n.translate('agreement_copyright_content')}

${l10n.translate('agreement_disclaimer_title')}
${l10n.translate('agreement_disclaimer_content')}

${l10n.translate('agreement_modification_title')}
${l10n.translate('agreement_modification_content')}

${l10n.translate('agreement_contact')}
            ''',
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
