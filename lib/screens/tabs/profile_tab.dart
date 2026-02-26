/// 我的Tab
/// 个人信息和设置

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/user_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/models/user.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/providers/locale_provider.dart';
import 'package:im_client/screens/settings/language_settings_screen.dart';
import 'package:im_client/screens/settings/settings_screen.dart';
import 'package:im_client/screens/profile/my_qrcode_screen.dart';
import 'package:im_client/screens/profile/edit_profile_screen.dart';
import 'package:im_client/screens/profile/gold_beans_screen.dart';
import 'package:im_client/screens/profile/user_level_screen.dart';
import 'package:im_client/screens/profile/favorites_screen.dart';
import 'package:im_client/screens/profile/checkin_screen.dart';
import 'package:im_client/screens/wallet/wallet_screen.dart';
import 'package:im_client/utils/url_helper.dart' as url_helper;
import '../../utils/image_proxy.dart';

/// 我的Tab页
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final UserApi _userApi = UserApi(ApiClient());
  GoldBeanBalance? _goldBeanBalance;
  bool _isClaimingGoldBeans = false;

  @override
  void initState() {
    super.initState();
    _loadGoldBeanBalance();
  }

  /// 获取完整URL（处理相对路径）
  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    // 防止只有 / 的情况
    if (url == '/') return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final baseUrl = EnvConfig.instance.baseUrl;
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }

  Future<void> _loadGoldBeanBalance() async {
    try {
      final response = await _userApi.getGoldBeanBalance();
      if (response.success && response.data != null) {
        setState(() {
          _goldBeanBalance = GoldBeanBalance.fromJson(response.data);
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _claimDailyGoldBeans() async {
    if (_isClaimingGoldBeans || _goldBeanBalance?.canClaim != true) return;

    setState(() => _isClaimingGoldBeans = true);

    try {
      final response = await _userApi.claimDailyGoldBeans();
      if (response.success && mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? l10n.translate('claim_success')),
            backgroundColor: AppColors.success,
          ),
        );
        _loadGoldBeanBalance();
      } else if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? l10n.translate('claim_failed')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.translate('claim_failed')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClaimingGoldBeans = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadGoldBeanBalance();
        },
        child: ListView(
          children: [
            // 用户信息卡片
            _buildUserCard(context),
            const SizedBox(height: 10),
            // 等级和金豆
            _buildLevelAndGoldBeans(context),
            const SizedBox(height: 10),
            // 功能列表
            _buildMenuSection(context),
            const SizedBox(height: 10),
            // 设置
            _buildSettingsSection(context),
          ],
        ),
      ),
    );
  }

  /// 构建用户信息卡片
  Widget _buildUserCard(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        return Container(
          color: AppColors.white,
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                // 头像
                Builder(builder: (context) {
                  final avatarUrl = _getFullUrl(user?.avatar ?? '');
                  return CircleAvatar(
                    radius: 35,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl.proxied)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            (user?.displayName.isNotEmpty == true) ? user!.displayName[0] : 'U',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  );
                }),
                const SizedBox(width: 16),
                // 用户信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(builder: (context) {
                        final l10n = AppLocalizations.of(context)!;
                        return Row(
                          children: [
                            Text(
                              user?.displayName ?? l10n.translate('not_logged_in'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (user != null) ...[
                              const SizedBox(width: 8),
                              _buildLevelBadge(user.level, l10n),
                            ],
                          ],
                        );
                      }),
                      const SizedBox(height: 4),
                      Builder(builder: (context) {
                        final l10n = AppLocalizations.of(context)!;
                        return Text(
                          '${l10n.translate('account')}: ${user?.username ?? ''}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                // 二维码
                IconButton(
                  icon: const Icon(Icons.qr_code),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyQRCodeScreen()),
                    );
                  },
                ),
                // 进入编辑资料
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppColors.textHint),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建等级徽章（可点击）
  Widget _buildLevelBadge(int level, AppLocalizations l10n) {
    final levelName = _getLevelName(level, l10n);
    final color = _getLevelColor(level);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserLevelScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lv.$level $levelName',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right,
              size: 12,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  String _getLevelName(int level, AppLocalizations l10n) {
    final names = [
      '',
      l10n.translate('level_bronze'),
      l10n.translate('level_silver'),
      l10n.translate('level_gold'),
      l10n.translate('level_platinum'),
      l10n.translate('level_diamond'),
      l10n.translate('level_star'),
      l10n.translate('level_king'),
      l10n.translate('level_legend'),
      l10n.translate('level_glory'),
      l10n.translate('level_supreme')
    ];
    return level >= 0 && level < names.length ? names[level] : '';
  }

  Color _getLevelColor(int level) {
    if (level <= 1) return Colors.brown;
    if (level == 2) return Colors.blueGrey;
    if (level == 3) return Colors.amber;
    if (level == 4) return Colors.cyan;
    if (level == 5) return Colors.blue;
    if (level == 6) return Colors.purple;
    if (level == 7) return Colors.deepPurple;
    if (level == 8) return Colors.orange;
    if (level == 9) return Colors.red;
    return Colors.redAccent;
  }

  /// 构建等级和金豆区域
  Widget _buildLevelAndGoldBeans(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        return Container(
          color: AppColors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 金豆
              Expanded(
                child: _buildStatItem(
                  icon: Icons.monetization_on,
                  iconColor: Colors.amber,
                  label: l10n.translate('gold_beans'),
                  value: '${_goldBeanBalance?.balance ?? 0}',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GoldBeansScreen()),
                    ).then((_) {
                      // 返回时刷新数据
                      _loadGoldBeanBalance();
                    });
                  },
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.divider,
              ),
              // 每日领取
              Expanded(
                child: _buildStatItem(
                  icon: Icons.card_giftcard,
                  iconColor: Colors.orange,
                  label: l10n.translate('daily_claim'),
                  value: _goldBeanBalance?.canClaim == true
                      ? '+${_goldBeanBalance?.dailyAmount ?? 0}'
                      : l10n.translate('claimed'),
                  valueColor: _goldBeanBalance?.canClaim == true
                      ? Colors.green
                      : AppColors.textSecondary,
                  onTap: _goldBeanBalance?.canClaim == true
                      ? _claimDailyGoldBeans
                      : null,
                  isLoading: _isClaimingGoldBeans,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.divider,
              ),
              // 邀请
              Expanded(
                child: _buildStatItem(
                  icon: Icons.group_add,
                  iconColor: Colors.blue,
                  label: l10n.translate('invite_friends'),
                  value: '${user?.inviteCount ?? 0}${l10n.translate('person_count')}',
                  onTap: () {
                    _showInviteDialog(context, user?.inviteCode);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 4),
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, String? inviteCode) {
    final l10n = AppLocalizations.of(context)!;
    if (inviteCode == null || inviteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('no_invite_code'))),
      );
      return;
    }

    // 生成邀请链接（Web端使用当前域名，移动端使用配置的baseUrl）
    String inviteLink;
    if (kIsWeb) {
      // Web端：使用当前页面的origin
      final origin = url_helper.getCurrentOrigin();
      if (origin.isNotEmpty) {
        inviteLink = '$origin/#/?invite=$inviteCode';
      } else {
        inviteLink = '${EnvConfig.instance.baseUrl}?invite=$inviteCode';
      }
    } else {
      inviteLink = '${EnvConfig.instance.baseUrl}?invite=$inviteCode';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.translate('invite_friends')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.translate('invite_code_share_info')),
              const SizedBox(height: 16),
              // 邀请码
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      inviteCode,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: l10n.translate('copy_invite_code'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: inviteCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.translate('invite_code_copied')), duration: const Duration(seconds: 1)),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Web端显示复制链接按钮
              if (kIsWeb) ...[
                Text(
                  l10n.translate('or_copy_invite_link'),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          inviteLink,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.link, size: 16),
                        label: Text(l10n.translate('copy_link')),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: inviteLink));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.translate('invite_link_copied')), duration: const Duration(seconds: 1)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                l10n.translate('invite_reward_info'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.translate('close')),
            ),
          ],
        );
      },
    );
  }

  /// 构建功能菜单区域
  Widget _buildMenuSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.calendar_today,
            iconColor: Colors.orange,
            title: l10n.translate('daily_checkin'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CheckinScreen()),
              ).then((_) => _loadGoldBeanBalance());
            },
          ),
          const Divider(indent: 56),
          _buildMenuItem(
            icon: Icons.payment,
            iconColor: Colors.green,
            title: l10n.translate('wallet'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WalletScreen()),
              );
            },
          ),
          const Divider(indent: 56),
          _buildMenuItem(
            icon: Icons.favorite_outline,
            iconColor: Colors.red,
            title: l10n.favorites,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 构建设置区域
  Widget _buildSettingsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();

    return Column(
      children: [
        Container(
          color: AppColors.white,
          child: Column(
            children: [
              _buildMenuItem(
                icon: Icons.settings_outlined,
                iconColor: AppColors.textSecondary,
                title: l10n.settings,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.language,
                iconColor: Colors.blue,
                title: l10n.language,
                subtitle: localeProvider.currentLocaleName,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LanguageSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // 金豆商城（单独分区）
        Container(
          color: AppColors.white,
          child: _buildMenuItem(
            icon: Icons.store,
            iconColor: Colors.orange,
            title: l10n.translate('gold_bean_mall'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.translate('in_development'))),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // 退出登录
        Container(
          color: AppColors.white,
          child: _buildMenuItem(
            icon: Icons.logout,
            iconColor: AppColors.error,
            title: l10n.logout,
            showArrow: false,
            onTap: () {
              _showLogoutDialog(context, l10n);
            },
          ),
        ),
      ],
    );
  }

  /// 构建菜单项
  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    bool showArrow = true,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12))
          : null,
      trailing: showArrow
          ? const Icon(Icons.chevron_right, color: AppColors.textHint)
          : null,
      onTap: onTap,
    );
  }

  /// 显示退出登录对话框
  void _showLogoutDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.logout),
          content: Text(l10n.logoutConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<AuthProvider>().logout();
              },
              child: Text(
                l10n.logout,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
  }
}
