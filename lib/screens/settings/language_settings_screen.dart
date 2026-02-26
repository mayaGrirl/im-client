/// 语言设置页面
/// 支持在登录前和登录后切换语言

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/providers/locale_provider.dart';

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.language),
      ),
      body: ListView(
        children: [
          _buildLanguageItem(
            context,
            locale: const Locale('zh', 'CN'),
            name: '简体中文',
            nativeName: 'Simplified Chinese',
            isSelected: localeProvider.locale.languageCode == 'zh' &&
                localeProvider.locale.countryCode == 'CN',
          ),
          const Divider(height: 1),
          _buildLanguageItem(
            context,
            locale: const Locale('zh', 'TW'),
            name: '繁體中文',
            nativeName: 'Traditional Chinese',
            isSelected: localeProvider.locale.languageCode == 'zh' &&
                localeProvider.locale.countryCode == 'TW',
          ),
          const Divider(height: 1),
          _buildLanguageItem(
            context,
            locale: const Locale('en', 'US'),
            name: 'English',
            nativeName: '英语',
            isSelected: localeProvider.locale.languageCode == 'en',
          ),
          const Divider(height: 1),
          _buildLanguageItem(
            context,
            locale: const Locale('fr', 'FR'),
            name: 'Français',
            nativeName: '法语',
            isSelected: localeProvider.locale.languageCode == 'fr',
          ),
          const Divider(height: 1),
          _buildLanguageItem(
            context,
            locale: const Locale('hi', 'IN'),
            name: 'हिन्दी',
            nativeName: 'Hindi / 印地语',
            isSelected: localeProvider.locale.languageCode == 'hi',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageItem(
    BuildContext context, {
    required Locale locale,
    required String name,
    required String nativeName,
    required bool isSelected,
  }) {
    return ListTile(
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        nativeName,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primary)
          : null,
      onTap: () {
        context.read<LocaleProvider>().setLocale(locale);
      },
    );
  }
}

/// 语言选择底部弹窗
/// 用于在登录页等地方快速切换语言
class LanguageBottomSheet extends StatelessWidget {
  const LanguageBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const LanguageBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)?.translate('select_language') ?? 'Select Language',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildLanguageOption(
            context,
            locale: const Locale('zh', 'CN'),
            flag: '🇨🇳',
            name: '简体中文',
            isSelected: localeProvider.locale.languageCode == 'zh' &&
                localeProvider.locale.countryCode == 'CN',
          ),
          _buildLanguageOption(
            context,
            locale: const Locale('zh', 'TW'),
            flag: '🇭🇰',
            name: '繁體中文',
            isSelected: localeProvider.locale.languageCode == 'zh' &&
                localeProvider.locale.countryCode == 'TW',
          ),
          _buildLanguageOption(
            context,
            locale: const Locale('en', 'US'),
            flag: '🇺🇸',
            name: 'English',
            isSelected: localeProvider.locale.languageCode == 'en',
          ),
          _buildLanguageOption(
            context,
            locale: const Locale('fr', 'FR'),
            flag: '🇫🇷',
            name: 'Français',
            isSelected: localeProvider.locale.languageCode == 'fr',
          ),
          _buildLanguageOption(
            context,
            locale: const Locale('hi', 'IN'),
            flag: '🇮🇳',
            name: 'हिन्दी',
            isSelected: localeProvider.locale.languageCode == 'hi',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context, {
    required Locale locale,
    required String flag,
    required String name,
    required bool isSelected,
  }) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : const Icon(Icons.circle_outlined, color: AppColors.divider),
      onTap: () {
        context.read<LocaleProvider>().setLocale(locale);
        Navigator.pop(context);
      },
    );
  }
}
