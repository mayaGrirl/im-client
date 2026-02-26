/// 登录页面
/// 用户登录和注册，支持密码登录和验证码登录

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/providers/app_config_provider.dart';
import 'package:im_client/providers/locale_provider.dart';
import 'package:im_client/screens/settings/language_settings_screen.dart';
import 'package:im_client/utils/startup_params.dart';

/// 登录页面
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  late TabController _tabController;

  bool _isLogin = true; // true=登录, false=注册
  bool _obscurePassword = true;
  bool _isLoading = false;
  int _loginMethod = 0; // 0=密码登录, 1=验证码登录

  // 验证码倒计时
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _loginMethod = _tabController.index;
        });
      }
    });

    // Web端：从URL读取邀请码（延迟到帧渲染后执行）
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _readInviteCodeFromUrl();
      });
    }
  }

  /// 从启动参数读取邀请码（仅Web端）
  void _readInviteCodeFromUrl() {
    // 从StartupParams获取启动时捕获的邀请码
    final inviteCode = StartupParams.instance.consumeInviteCode();
    debugPrint('[LoginScreen] Read startup parameter invitation code: $inviteCode');
    if (inviteCode != null && inviteCode.isNotEmpty && mounted) {
      _inviteCodeController.text = inviteCode;
      // 如果有邀请码，自动切换到注册模式
      setState(() {
        _isLogin = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _inviteCodeController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _tabController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// 发送验证码
  Future<void> _sendVerifyCode() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError(l10n.translate('email_required'));
      return;
    }
    if (!_isValidEmail(email)) {
      _showError(l10n.translate('email_invalid'));
      return;
    }

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final result = await auth.sendVerifyCode(email, 2); // 2=登录

    setState(() => _isLoading = false);

    if (result.success) {
      _startCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.code != null
                ? l10n.translate('code_sent_with_code').replaceAll('{code}', result.code!) // 开发环境显示验证码
                : l10n.translate('code_sent')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      _showError(result.message ?? l10n.translate('send_code_failed'));
    }
  }

  /// 开始倒计时
  void _startCountdown() {
    _countdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// 提交表单
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();

    bool success;
    if (_isLogin) {
      if (_loginMethod == 0) {
        // 密码登录
        success = await auth.login(
          _usernameController.text.trim(),
          _passwordController.text,
        );
      } else {
        // 验证码登录
        success = await auth.loginByCode(
          _emailController.text.trim(),
          _codeController.text.trim(),
        );
      }
    } else {
      success = await auth.register(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        nickname: _nicknameController.text.trim().isEmpty
            ? null
            : _nicknameController.text.trim(),
        inviteCode: _inviteCodeController.text.trim().isEmpty
            ? null
            : _inviteCodeController.text.trim(),
      );
    }

    setState(() => _isLoading = false);

    if (!success && mounted) {
      final l10n = AppLocalizations.of(context)!;
      _showError(auth.error ?? l10n.translate('operation_failed'));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  /// 切换登录/注册模式
  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
    });
  }

  /// 打开找回密码页面
  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 语言切换按钮
          TextButton.icon(
            onPressed: () => LanguageBottomSheet.show(context),
            icon: const Icon(Icons.language, size: 20),
            label: Text(
              localeProvider.currentLocaleName,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // Logo
                _buildLogo(),
                const SizedBox(height: 48),
                // 标题
                Text(
                  _isLogin
                      ? l10n.translate('welcome_back')
                      : l10n.translate('create_account'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? l10n.translate('login_subtitle')
                      : l10n.translate('register_subtitle'),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // 登录模式：显示Tab切换
                if (_isLogin) ...[
                  _buildLoginTabs(l10n),
                  const SizedBox(height: 24),
                  if (_loginMethod == 0) ...[
                    // 密码登录
                    _buildUsernameField(l10n),
                    const SizedBox(height: 16),
                    _buildPasswordField(l10n),
                    const SizedBox(height: 8),
                    _buildForgotPasswordButton(l10n),
                  ] else ...[
                    // 验证码登录
                    _buildEmailField(l10n),
                    const SizedBox(height: 16),
                    _buildCodeField(l10n),
                  ],
                ] else ...[
                  // 注册模式
                  _buildUsernameField(l10n),
                  const SizedBox(height: 16),
                  _buildNicknameField(l10n),
                  const SizedBox(height: 16),
                  _buildPasswordField(l10n),
                  const SizedBox(height: 16),
                  _buildInviteCodeField(l10n),
                ],

                const SizedBox(height: 24),
                // 提交按钮
                _buildSubmitButton(l10n),
                const SizedBox(height: 16),
                // 切换登录/注册
                _buildToggleButton(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建登录方式Tab
  Widget _buildLoginTabs(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: l10n.translate('password_login')),
          Tab(text: l10n.translate('code_login')),
        ],
      ),
    );
  }

  /// 构建Logo
  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.chat_bubble_rounded,
          size: 44,
          color: AppColors.primary,
        ),
      ),
    );
  }

  /// 构建用户名输入框
  Widget _buildUsernameField(AppLocalizations l10n) {
    return TextFormField(
      controller: _usernameController,
      decoration: InputDecoration(
        labelText: l10n.username,
        hintText: l10n.translate('input_username'),
        prefixIcon: const Icon(Icons.person_outline),
      ),
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return l10n.translate('username_required');
        }
        if (value.trim().length < 3) {
          return l10n.translate('username_min_length');
        }
        return null;
      },
    );
  }

  /// 构建昵称输入框
  Widget _buildNicknameField(AppLocalizations l10n) {
    return TextFormField(
      controller: _nicknameController,
      decoration: InputDecoration(
        labelText: '${l10n.nickname}（${l10n.translate('optional')}）',
        hintText: l10n.translate('input_nickname'),
        prefixIcon: const Icon(Icons.badge_outlined),
      ),
      textInputAction: TextInputAction.next,
    );
  }

  /// 构建密码输入框
  Widget _buildPasswordField(AppLocalizations l10n) {
    final minLen = context.read<AppConfigProvider>().passwordMinLen;
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: l10n.password,
        hintText: l10n.translate('input_password'),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
      ),
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return l10n.translate('password_required');
        }
        if (value.length < minLen) {
          return l10n.translate('password_min_length');
        }
        return null;
      },
    );
  }

  /// 构建邮箱输入框
  Widget _buildEmailField(AppLocalizations l10n) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: l10n.translate('email'),
        hintText: l10n.translate('input_email'),
        prefixIcon: const Icon(Icons.email_outlined),
      ),
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return l10n.translate('email_required');
        }
        if (!_isValidEmail(value.trim())) {
          return l10n.translate('email_invalid');
        }
        return null;
      },
    );
  }

  /// 构建验证码输入框
  Widget _buildCodeField(AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.translate('verify_code'),
              hintText: l10n.translate('input_code'),
              prefixIcon: const Icon(Icons.security),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.translate('code_required');
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: (_isLoading || _countdown > 0) ? null : _sendVerifyCode,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              _countdown > 0
                  ? '${_countdown}s'
                  : l10n.translate('send_code'),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建邀请码输入框
  Widget _buildInviteCodeField(AppLocalizations l10n) {
    return TextFormField(
      controller: _inviteCodeController,
      decoration: InputDecoration(
        labelText: '${l10n.translate('invite_code')}（${l10n.translate('optional')}）',
        hintText: l10n.translate('input_invite_code'),
        prefixIcon: const Icon(Icons.card_giftcard),
      ),
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
    );
  }

  /// 构建找回密码按钮
  Widget _buildForgotPasswordButton(AppLocalizations l10n) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _openForgotPassword,
        child: Text(
          l10n.translate('forgot_password'),
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// 构建提交按钮
  Widget _buildSubmitButton(AppLocalizations l10n) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                _isLogin ? l10n.login : l10n.register,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  /// 构建切换按钮
  Widget _buildToggleButton(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin
              ? l10n.translate('no_account')
              : l10n.translate('has_account'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        TextButton(
          onPressed: _toggleMode,
          child: Text(
            _isLogin
                ? l10n.translate('register_now')
                : l10n.translate('login_now'),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// 找回密码页面
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 1; // 1=输入邮箱, 2=输入验证码和新密码
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// 发送验证码
  Future<void> _sendVerifyCode() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty || !_isValidEmail(email)) {
      _showError(l10n.translate('email_invalid'));
      return;
    }

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final result = await auth.sendVerifyCode(email, 4); // 4=找回密码

    setState(() => _isLoading = false);

    if (result.success) {
      setState(() => _step = 2);
      _startCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.code != null
                ? l10n.translate('code_sent_with_code').replaceAll('{code}', result.code!)
                : l10n.translate('code_sent')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      _showError(result.message ?? l10n.translate('send_code_failed'));
    }
  }

  void _startCountdown() {
    _countdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  /// 重置密码
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(
      _emailController.text.trim(),
      _codeController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('password_reset_success')),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else {
      final l10n = AppLocalizations.of(context)!;
      _showError(auth.error ?? l10n.translate('password_reset_failed'));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('forgot_password')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 步骤指示器
                _buildStepIndicator(l10n),
                const SizedBox(height: 32),

                if (_step == 1) ...[
                  // 第一步：输入邮箱
                  Text(
                    l10n.translate('input_email_to_reset'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.translate('email'),
                      hintText: l10n.translate('input_email'),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.translate('email_required');
                      }
                      if (!_isValidEmail(value.trim())) {
                        return l10n.translate('email_invalid');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendVerifyCode,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(l10n.translate('send_code')),
                    ),
                  ),
                ] else ...[
                  // 第二步：输入验证码和新密码
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.translate('verify_code'),
                            hintText: l10n.translate('input_code'),
                            prefixIcon: const Icon(Icons.security),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.translate('code_required');
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed:
                              (_isLoading || _countdown > 0) ? null : _sendVerifyCode,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Text(
                            _countdown > 0
                                ? '${_countdown}s'
                                : l10n.translate('resend'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: l10n.translate('new_password'),
                      hintText: l10n.translate('input_new_password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      final minLen = context.read<AppConfigProvider>().passwordMinLen;
                      if (value == null || value.isEmpty) {
                        return l10n.translate('password_required');
                      }
                      if (value.length < minLen) {
                        return l10n.translate('password_min_length');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: l10n.translate('confirm_password'),
                      hintText: l10n.translate('input_confirm_password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscureConfirm = !_obscureConfirm);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.translate('confirm_password_required');
                      }
                      if (value != _passwordController.text) {
                        return l10n.translate('password_not_match');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(l10n.translate('reset_password')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(AppLocalizations l10n) {
    return Row(
      children: [
        _buildStepCircle(1, l10n.translate('verify_email')),
        Expanded(
          child: Container(
            height: 2,
            color: _step >= 2 ? AppColors.primary : AppColors.border,
          ),
        ),
        _buildStepCircle(2, l10n.translate('set_password')),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive = _step >= step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.border,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: isActive ? AppColors.white : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
