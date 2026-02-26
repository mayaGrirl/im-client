/// 账号与安全页面
/// 管理密码、手机、邮箱等安全设置

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/user_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/models/country_code.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/screens/settings/device_management_screen.dart';
import 'package:im_client/widgets/country_code_picker.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final UserApi _userApi = UserApi(ApiClient());

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.accountSecurity),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          // 账号信息
          _buildSection(
            title: l10n.accountInfo,
            children: [
              _buildInfoItem(
                title: l10n.translate('account'),
                value: user?.username ?? '',
              ),
              const Divider(indent: 16),
              _buildInfoItem(
                title: l10n.translate('user_id'),
                value: '${user?.id ?? ''}',
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 密码管理
          _buildSection(
            title: l10n.passwordManagement,
            children: [
              _buildMenuItem(
                icon: Icons.lock_outline,
                title: l10n.changeLoginPassword,
                onTap: () => _showChangePasswordSheet(context),
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.payment,
                title: l10n.translate('payment_password'),
                subtitle: l10n.translate('payment_password_desc'),
                onTap: () => _showPaymentPasswordSheet(context),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 绑定信息
          _buildSection(
            title: l10n.securityBinding,
            children: [
              _buildMenuItem(
                icon: Icons.phone_android,
                title: l10n.phone,
                subtitle: user?.phone?.isNotEmpty == true
                    ? _maskPhone(user!.phone!)
                    : l10n.notBound,
                trailing: user?.phone?.isNotEmpty == true
                    ? Text(l10n.translate('change'), style: const TextStyle(color: Colors.blue, fontSize: 14))
                    : Text(l10n.translate('go_bind'), style: const TextStyle(color: Colors.blue, fontSize: 14)),
                onTap: () => _showBindPhoneSheet(context, user?.phone),
              ),
              const Divider(indent: 56),
              _buildMenuItem(
                icon: Icons.email_outlined,
                title: l10n.email,
                subtitle: user?.email?.isNotEmpty == true
                    ? _maskEmail(user!.email!)
                    : l10n.notBound,
                trailing: user?.email?.isNotEmpty == true
                    ? Text(l10n.translate('change'), style: const TextStyle(color: Colors.blue, fontSize: 14))
                    : Text(l10n.translate('go_bind'), style: const TextStyle(color: Colors.blue, fontSize: 14)),
                onTap: () => _showBindEmailSheet(context, user?.email),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 登录设备
          _buildSection(
            title: l10n.loginManagement,
            children: [
              _buildMenuItem(
                icon: Icons.devices,
                title: l10n.deviceManagement,
                subtitle: l10n.viewManageDevices,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DeviceManagementScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  String _maskPhone(String phone) {
    // 处理国际格式 +区号手机号
    if (phone.startsWith('+')) {
      // 尝试找到区号结束位置
      final phoneWithoutPlus = phone.substring(1);
      // 简单处理：保留前4位和后4位
      if (phoneWithoutPlus.length > 8) {
        return '+${phoneWithoutPlus.substring(0, 4)}****${phoneWithoutPlus.substring(phoneWithoutPlus.length - 4)}';
      }
      return phone;
    }
    // 普通格式
    if (phone.length < 7) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }

  String _maskEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex < 2) return email;
    final prefix = email.substring(0, 2);
    final domain = email.substring(atIndex);
    return '$prefix***$domain';
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          color: AppColors.white,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoItem({required String title, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
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
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }

  /// 底部弹出表单的通用包装
  void _showBottomSheet({
    required BuildContext context,
    required String title,
    required Widget Function(BuildContext context, StateSetter setState) builder,
    double? height,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: height ?? MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // 顶部拖拽条
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 标题栏
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // 内容区域
                Expanded(
                  child: builder(context, setState),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 修改登录密码
  void _showChangePasswordSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = context.read<AuthProvider>().user;
    final verifyCodeController = TextEditingController();
    final payPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool isSendingCode = false;
    int countdown = 0;
    int verifyType = 0;

    _showBottomSheet(
      context: context,
      title: l10n.changeLoginPassword,
      builder: (context, setState) {
        void startCountdown() {
          countdown = 60;
          Future.doWhile(() async {
            await Future.delayed(const Duration(seconds: 1));
            if (countdown > 0) {
              setState(() => countdown--);
              return true;
            }
            return false;
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('select_verify_method'),
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    if (user?.email?.isNotEmpty == true)
                      _buildVerifyTypeChip(
                        label: l10n.translate('email_verify'),
                        icon: Icons.email,
                        selected: verifyType == 1,
                        onTap: () => setState(() => verifyType = 1),
                      ),
                    if (user?.phone?.isNotEmpty == true)
                      _buildVerifyTypeChip(
                        label: l10n.translate('phone_verify'),
                        icon: Icons.phone,
                        selected: verifyType == 2,
                        onTap: () => setState(() => verifyType = 2),
                      ),
                    _buildVerifyTypeChip(
                      label: l10n.translate('payment_password'),
                      icon: Icons.payment,
                      selected: verifyType == 3,
                      onTap: () => setState(() => verifyType = 3),
                    ),
                  ],
                ),

                if (verifyType > 0) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // 验证码输入
                  if (verifyType == 1 || verifyType == 2) ...[
                    _buildInputField(
                      controller: verifyCodeController,
                      label: verifyType == 1 ? l10n.translate('email_code') : l10n.translate('phone_code'),
                      icon: Icons.verified,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      suffix: _buildSendCodeButton(
                        l10n: l10n,
                        countdown: countdown,
                        isLoading: isSendingCode,
                        onPressed: () async {
                          setState(() => isSendingCode = true);
                          try {
                            final target = verifyType == 1 ? user!.email! : user!.phone!;
                            final response = verifyType == 1
                                ? await _userApi.sendEmailCodeForPasswordChange(target)
                                : await _userApi.sendPhoneCodeForPasswordChange(target);
                            if (response.success) {
                              startCountdown();
                              _showMessage(l10n.translate('code_sent'));
                            } else {
                              _showMessage(response.message ?? l10n.sendFailed, isError: true);
                            }
                          } catch (e) {
                            _showMessage('${l10n.sendFailed}: $e', isError: true);
                          } finally {
                            setState(() => isSendingCode = false);
                          }
                        },
                      ),
                    ),
                  ],

                  // 支付密码输入
                  if (verifyType == 3)
                    _buildInputField(
                      controller: payPasswordController,
                      label: l10n.translate('payment_password'),
                      icon: Icons.payment,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),

                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: newPasswordController,
                    label: l10n.translate('new_password'),
                    icon: Icons.lock,
                    obscureText: true,
                    helperText: l10n.translate('password_at_least_6'),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: confirmPasswordController,
                    label: l10n.translate('confirm_new_password'),
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 32),
                  _buildSubmitButton(
                    text: l10n.translate('confirm_change'),
                    isLoading: isLoading,
                    onPressed: () async {
                      if (verifyType == 1 || verifyType == 2) {
                        if (verifyCodeController.text.length != 6) {
                          _showMessage(l10n.translate('enter_6_digit_code'), isError: true);
                          return;
                        }
                      }
                      if (verifyType == 3 && payPasswordController.text.length != 6) {
                        _showMessage(l10n.translate('enter_6_digit_password'), isError: true);
                        return;
                      }
                      if (newPasswordController.text.length < 6) {
                        _showMessage(l10n.translate('password_at_least_6'), isError: true);
                        return;
                      }
                      if (newPasswordController.text != confirmPasswordController.text) {
                        _showMessage(l10n.translate('password_not_match'), isError: true);
                        return;
                      }

                      setState(() => isLoading = true);
                      try {
                        final response = await _userApi.changePasswordWithVerify(
                          newPassword: newPasswordController.text,
                          verifyType: verifyType,
                          verifyCode: verifyType != 3 ? verifyCodeController.text : null,
                          payPassword: verifyType == 3 ? payPasswordController.text : null,
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          _showMessage(response.success ? l10n.translate('password_change_success') : (response.message ?? l10n.translate('change_failed')),
                              isError: !response.success);
                        }
                      } catch (e) {
                        _showMessage('${l10n.translate('change_failed')}: $e', isError: true);
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 设置/修改支付密码
  void _showPaymentPasswordSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final user = context.read<AuthProvider>().user;

    // 检查是否已设置支付密码
    bool hasPayPassword = false;
    try {
      final walletResponse = await _userApi.getWalletInfo();
      if (walletResponse.success && walletResponse.data != null) {
        hasPayPassword = walletResponse.data['has_pay_password'] == true;
      }
    } catch (e) {
      // 忽略
    }

    if (!mounted) return;

    final verifyCodeController = TextEditingController();
    final oldPayPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool isSendingCode = false;
    int countdown = 0;
    int verifyType = hasPayPassword ? 0 : -1; // -1 表示首次设置，不需要验证

    _showBottomSheet(
      context: context,
      title: hasPayPassword ? l10n.translate('change_pay_password') : l10n.translate('set_pay_password'),
      builder: (context, setState) {
        void startCountdown() {
          countdown = 60;
          Future.doWhile(() async {
            await Future.delayed(const Duration(seconds: 1));
            if (countdown > 0) {
              setState(() => countdown--);
              return true;
            }
            return false;
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasPayPassword) ...[
                Text(
                  l10n.translate('select_verify_method'),
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    if (user?.email?.isNotEmpty == true)
                      _buildVerifyTypeChip(
                        label: l10n.translate('email_verify'),
                        icon: Icons.email,
                        selected: verifyType == 1,
                        onTap: () => setState(() => verifyType = 1),
                      ),
                    if (user?.phone?.isNotEmpty == true)
                      _buildVerifyTypeChip(
                        label: l10n.translate('phone_verify'),
                        icon: Icons.phone,
                        selected: verifyType == 2,
                        onTap: () => setState(() => verifyType = 2),
                      ),
                    _buildVerifyTypeChip(
                      label: l10n.translate('original_pay_password'),
                      icon: Icons.password,
                      selected: verifyType == 3,
                      onTap: () => setState(() => verifyType = 3),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.translate('first_set_pay_password_hint'),
                          style: const TextStyle(color: Colors.blue, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (verifyType != 0) ...[
                const SizedBox(height: 24),
                if (hasPayPassword) const Divider(),
                if (hasPayPassword) const SizedBox(height: 16),

                // 验证码输入
                if (verifyType == 1 || verifyType == 2) ...[
                  _buildInputField(
                    controller: verifyCodeController,
                    label: verifyType == 1 ? l10n.translate('email_code') : l10n.translate('phone_code'),
                    icon: Icons.verified,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    suffix: _buildSendCodeButton(
                      l10n: l10n,
                      countdown: countdown,
                      isLoading: isSendingCode,
                      onPressed: () async {
                        setState(() => isSendingCode = true);
                        try {
                          final target = verifyType == 1 ? user!.email! : user!.phone!;
                          final response = verifyType == 1
                              ? await _userApi.sendEmailCodeForPasswordChange(target)
                              : await _userApi.sendPhoneCodeForPasswordChange(target);
                          if (response.success) {
                            startCountdown();
                            _showMessage(l10n.translate('code_sent'));
                          } else {
                            _showMessage(response.message ?? l10n.translate('send_failed'), isError: true);
                          }
                        } catch (e) {
                          _showMessage('${l10n.translate('send_failed')}: $e', isError: true);
                        } finally {
                          setState(() => isSendingCode = false);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 原支付密码输入
                if (verifyType == 3) ...[
                  _buildInputField(
                    controller: oldPayPasswordController,
                    label: l10n.translate('original_pay_password'),
                    icon: Icons.lock_outline,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  const SizedBox(height: 16),
                ],

                _buildInputField(
                  controller: newPasswordController,
                  label: l10n.translate('new_pay_password'),
                  icon: Icons.payment,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  helperText: l10n.translate('set_6_digit_password'),
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: confirmPasswordController,
                  label: l10n.translate('confirm_pay_password'),
                  icon: Icons.payment,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 32),
                _buildSubmitButton(
                  text: hasPayPassword ? l10n.translate('confirm_change') : l10n.translate('set_password'),
                  isLoading: isLoading,
                  onPressed: () async {
                    if ((verifyType == 1 || verifyType == 2) && verifyCodeController.text.length != 6) {
                      _showMessage(l10n.translate('enter_6_digit_code'), isError: true);
                      return;
                    }
                    if (verifyType == 3 && oldPayPasswordController.text.length != 6) {
                      _showMessage(l10n.translate('input_6_digit_original_pay'), isError: true);
                      return;
                    }
                    if (newPasswordController.text.length != 6 ||
                        !RegExp(r'^\d{6}$').hasMatch(newPasswordController.text)) {
                      _showMessage(l10n.translate('pay_password_must_6_digits'), isError: true);
                      return;
                    }
                    if (newPasswordController.text != confirmPasswordController.text) {
                      _showMessage(l10n.translate('password_not_match'), isError: true);
                      return;
                    }

                    setState(() => isLoading = true);
                    try {
                      final response = await _userApi.setPayPasswordWithVerify(
                        newPassword: newPasswordController.text,
                        verifyType: verifyType == -1 ? 0 : verifyType,
                        verifyCode: (verifyType == 1 || verifyType == 2) ? verifyCodeController.text : null,
                        oldPayPassword: verifyType == 3 ? oldPayPasswordController.text : null,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        _showMessage(response.success ? l10n.translate('pay_password_set_success') : (response.message ?? l10n.translate('set_failed')),
                            isError: !response.success);
                      }
                    } catch (e) {
                      _showMessage('${l10n.translate('set_failed')}: $e', isError: true);
                    } finally {
                      setState(() => isLoading = false);
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 绑定/更换手机号
  void _showBindPhoneSheet(BuildContext context, String? currentPhone) {
    final l10n = AppLocalizations.of(context)!;
    final user = context.read<AuthProvider>().user;
    final bool isUpdate = currentPhone?.isNotEmpty == true;

    final verifyCodeController = TextEditingController();
    final payPasswordController = TextEditingController();
    final phoneController = TextEditingController();
    bool isLoading = false;
    bool isSendingCode = false;
    int countdown = 0;
    int verifyType = 0;
    bool isVerified = !isUpdate;

    // 国家区号选择
    CountryCode selectedCountry = defaultCountryCodes.first; // 默认中国

    _showBottomSheet(
      context: context,
      title: isUpdate ? l10n.translate('change_phone') : l10n.translate('bind_phone'),
      builder: (context, setState) {
        void startCountdown() {
          countdown = 60;
          Future.doWhile(() async {
            await Future.delayed(const Duration(seconds: 1));
            if (countdown > 0) {
              setState(() => countdown--);
              return true;
            }
            return false;
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 更换时需要先验证身份
              if (isUpdate && !isVerified) ...[
                Text(
                  l10n.translate('verify_identity_first'),
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    if (user?.email?.isNotEmpty == true)
                      _buildVerifyTypeChip(
                        label: l10n.translate('email_verify'),
                        icon: Icons.email,
                        selected: verifyType == 1,
                        onTap: () => setState(() => verifyType = 1),
                      ),
                    _buildVerifyTypeChip(
                      label: l10n.translate('payment_password'),
                      icon: Icons.payment,
                      selected: verifyType == 2,
                      onTap: () => setState(() => verifyType = 2),
                    ),
                  ],
                ),

                if (verifyType > 0) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  if (verifyType == 1) ...[
                    _buildInputField(
                      controller: verifyCodeController,
                      label: l10n.translate('email_code'),
                      icon: Icons.verified,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      suffix: _buildSendCodeButton(
                        l10n: l10n,
                        countdown: countdown,
                        isLoading: isSendingCode,
                        onPressed: () async {
                          setState(() => isSendingCode = true);
                          try {
                            final response = await _userApi.sendEmailCodeForPasswordChange(user!.email!);
                            if (response.success) {
                              startCountdown();
                              _showMessage(l10n.translate('code_sent'));
                            } else {
                              _showMessage(response.message ?? l10n.translate('send_failed'), isError: true);
                            }
                          } catch (e) {
                            _showMessage('${l10n.translate('send_failed')}: $e', isError: true);
                          } finally {
                            setState(() => isSendingCode = false);
                          }
                        },
                      ),
                    ),
                  ],

                  if (verifyType == 2)
                    _buildInputField(
                      controller: payPasswordController,
                      label: l10n.translate('payment_password'),
                      icon: Icons.payment,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),

                  const SizedBox(height: 24),
                  _buildSubmitButton(
                    text: l10n.translate('verify_identity'),
                    isLoading: isLoading,
                    onPressed: () async {
                      if (verifyType == 1 && verifyCodeController.text.length != 6) {
                        _showMessage(l10n.translate('enter_6_digit_code'), isError: true);
                        return;
                      }
                      if (verifyType == 2 && payPasswordController.text.length != 6) {
                        _showMessage(l10n.translate('enter_6_digit_password'), isError: true);
                        return;
                      }

                      setState(() => isLoading = true);
                      try {
                        final response = await _userApi.verifyIdentity(
                          verifyType: verifyType == 1 ? 1 : 3,
                          verifyCode: verifyType == 1 ? verifyCodeController.text : null,
                          payPassword: verifyType == 2 ? payPasswordController.text : null,
                        );
                        if (response.success) {
                          setState(() => isVerified = true);
                        } else {
                          _showMessage(response.message ?? l10n.translate('verify_failed'), isError: true);
                        }
                      } catch (e) {
                        _showMessage('${l10n.translate('verify_failed')}: $e', isError: true);
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
                  ),
                ],
              ],

              // 验证通过后显示手机号输入
              if (isVerified) ...[
                if (isUpdate) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.translate('identity_verified'), style: const TextStyle(color: Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // 国家区号选择 + 手机号输入
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CountryCodePicker(
                      selectedCountry: selectedCountry,
                      onChanged: (country) => setState(() => selectedCountry = country),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInputField(
                        controller: phoneController,
                        label: isUpdate ? l10n.translate('new_phone') : l10n.phone,
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        helperText: '${l10n.translate('example')}: ${selectedCountry.example}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.translate('sms_hint'),
                          style: const TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSubmitButton(
                  text: isUpdate ? l10n.translate('confirm_change_action') : l10n.translate('confirm_bind'),
                  isLoading: isLoading,
                  onPressed: () async {
                    // 验证手机号格式
                    if (!selectedCountry.validatePhone(phoneController.text)) {
                      _showMessage(l10n.translate('input_correct_phone').replaceAll('{country}', selectedCountry.countryZh), isError: true);
                      return;
                    }

                    setState(() => isLoading = true);
                    try {
                      final response = await _userApi.bindPhone(
                        phoneController.text,
                        '000000',
                        countryCode: selectedCountry.code,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        _showMessage(
                          response.success
                              ? (isUpdate ? l10n.translate('phone_change_success') : l10n.translate('phone_bind_success'))
                              : (response.message ?? l10n.translate('operation_failed')),
                          isError: !response.success,
                        );
                        if (response.success) {
                          context.read<AuthProvider>().refreshUser();
                        }
                      }
                    } catch (e) {
                      _showMessage('${l10n.translate('operation_failed')}: $e', isError: true);
                    } finally {
                      setState(() => isLoading = false);
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 绑定/更换邮箱
  void _showBindEmailSheet(BuildContext context, String? currentEmail) {
    final l10n = AppLocalizations.of(context)!;
    final user = context.read<AuthProvider>().user;
    final bool isUpdate = currentEmail?.isNotEmpty == true;

    final verifyCodeController = TextEditingController();
    final payPasswordController = TextEditingController();
    final emailController = TextEditingController();
    final newEmailCodeController = TextEditingController();
    bool isLoading = false;
    bool isSendingCode = false;
    bool isSendingNewEmailCode = false;
    int countdown = 0;
    int newEmailCountdown = 0;
    int verifyType = 0;
    bool isVerified = !isUpdate;

    _showBottomSheet(
      context: context,
      title: isUpdate ? l10n.translate('change_email') : l10n.translate('bind_email'),
      builder: (context, setState) {
        void startCountdown() {
          countdown = 60;
          Future.doWhile(() async {
            await Future.delayed(const Duration(seconds: 1));
            if (countdown > 0) {
              setState(() => countdown--);
              return true;
            }
            return false;
          });
        }

        void startNewEmailCountdown() {
          newEmailCountdown = 60;
          Future.doWhile(() async {
            await Future.delayed(const Duration(seconds: 1));
            if (newEmailCountdown > 0) {
              setState(() => newEmailCountdown--);
              return true;
            }
            return false;
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 更换时需要先验证身份
              if (isUpdate && !isVerified) ...[
                Text(
                  l10n.translate('verify_identity_first'),
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    if (user?.phone?.isNotEmpty == true)
                      _buildVerifyTypeChip(
                        label: l10n.translate('phone_verify'),
                        icon: Icons.phone,
                        selected: verifyType == 1,
                        onTap: () => setState(() => verifyType = 1),
                      ),
                    _buildVerifyTypeChip(
                      label: l10n.translate('payment_password'),
                      icon: Icons.payment,
                      selected: verifyType == 2,
                      onTap: () => setState(() => verifyType = 2),
                    ),
                  ],
                ),

                if (verifyType > 0) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  if (verifyType == 1) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Text(l10n.translate('sms_not_available'), style: const TextStyle(color: Colors.orange, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(
                      controller: verifyCodeController,
                      label: l10n.translate('phone_code'),
                      icon: Icons.verified,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      helperText: l10n.translate('skip_with_000000'),
                    ),
                  ],

                  if (verifyType == 2)
                    _buildInputField(
                      controller: payPasswordController,
                      label: l10n.translate('payment_password'),
                      icon: Icons.payment,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),

                  const SizedBox(height: 24),
                  _buildSubmitButton(
                    text: l10n.translate('verify_identity'),
                    isLoading: isLoading,
                    onPressed: () async {
                      if (verifyType == 1 && verifyCodeController.text.length != 6) {
                        _showMessage(l10n.translate('enter_6_digit_code'), isError: true);
                        return;
                      }
                      if (verifyType == 2 && payPasswordController.text.length != 6) {
                        _showMessage(l10n.translate('enter_6_digit_password'), isError: true);
                        return;
                      }

                      setState(() => isLoading = true);
                      try {
                        // 手机验证码000000时跳过验证
                        if (verifyType == 1 && verifyCodeController.text == '000000') {
                          setState(() => isVerified = true);
                        } else {
                          final response = await _userApi.verifyIdentity(
                            verifyType: verifyType == 1 ? 2 : 3,
                            verifyCode: verifyType == 1 ? verifyCodeController.text : null,
                            payPassword: verifyType == 2 ? payPasswordController.text : null,
                          );
                          if (response.success) {
                            setState(() => isVerified = true);
                          } else {
                            _showMessage(response.message ?? l10n.translate('verify_failed'), isError: true);
                          }
                        }
                      } catch (e) {
                        _showMessage('${l10n.translate('verify_failed')}: $e', isError: true);
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
                  ),
                ],
              ],

              // 验证通过后显示邮箱输入
              if (isVerified) ...[
                if (isUpdate) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.translate('identity_verified'), style: const TextStyle(color: Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                _buildInputField(
                  controller: emailController,
                  label: isUpdate ? l10n.translate('new_email') : l10n.translate('email_address'),
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: newEmailCodeController,
                  label: isUpdate ? l10n.translate('new_email_code') : l10n.verifyCode,
                  icon: Icons.verified,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  suffix: _buildSendCodeButton(
                    l10n: l10n,
                    countdown: newEmailCountdown,
                    isLoading: isSendingNewEmailCode,
                    onPressed: () async {
                      if (emailController.text.isEmpty ||
                          !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text)) {
                        _showMessage(l10n.translate('input_correct_email'), isError: true);
                        return;
                      }
                      setState(() => isSendingNewEmailCode = true);
                      try {
                        final response = await _userApi.sendEmailCode(emailController.text);
                        if (response.success) {
                          startNewEmailCountdown();
                          _showMessage(l10n.translate('code_sent'));
                        } else {
                          _showMessage(response.message ?? l10n.translate('send_failed'), isError: true);
                        }
                      } catch (e) {
                        _showMessage('${l10n.translate('send_failed')}: $e', isError: true);
                      } finally {
                        setState(() => isSendingNewEmailCode = false);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),
                _buildSubmitButton(
                  text: isUpdate ? l10n.translate('confirm_change_action') : l10n.translate('confirm_bind'),
                  isLoading: isLoading,
                  onPressed: () async {
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text)) {
                      _showMessage(l10n.translate('input_correct_email'), isError: true);
                      return;
                    }
                    if (newEmailCodeController.text.length != 6) {
                      _showMessage(l10n.translate('enter_6_digit_code'), isError: true);
                      return;
                    }

                    setState(() => isLoading = true);
                    try {
                      final response = await _userApi.bindEmail(
                        emailController.text,
                        newEmailCodeController.text,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        _showMessage(
                          response.success
                              ? (isUpdate ? l10n.translate('email_change_success') : l10n.translate('email_bind_success'))
                              : (response.message ?? l10n.translate('operation_failed')),
                          isError: !response.success,
                        );
                        if (response.success) {
                          context.read<AuthProvider>().refreshUser();
                        }
                      }
                    } catch (e) {
                      _showMessage('${l10n.translate('operation_failed')}: $e', isError: true);
                    } finally {
                      setState(() => isLoading = false);
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 构建验证类型选择芯片
  Widget _buildVerifyTypeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建输入框
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    int? maxLength,
    String? helperText,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: suffix,
        helperText: helperText,
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  /// 构建发送验证码按钮
  Widget _buildSendCodeButton({
    required AppLocalizations l10n,
    required int countdown,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: countdown > 0 || isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              countdown > 0 ? '${countdown}s' : l10n.translate('get_code'),
              style: TextStyle(
                color: countdown > 0 ? AppColors.textSecondary : AppColors.primary,
              ),
            ),
    );
  }

  /// 构建提交按钮
  Widget _buildSubmitButton({
    required String text,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  /// 显示消息提示
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
