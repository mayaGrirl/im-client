/// IM即时通讯客户端
/// 主入口文件

import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/providers/chat_provider.dart';
import 'package:im_client/providers/group_call_provider.dart';
import 'package:im_client/providers/locale_provider.dart';
import 'package:im_client/providers/app_config_provider.dart';
import 'package:im_client/modules/small_video/providers/small_video_provider.dart';
import 'package:im_client/modules/livestream/providers/livestream_provider.dart';
import 'package:im_client/screens/splash_screen.dart';
import 'package:im_client/screens/login_screen.dart';
import 'package:im_client/screens/home_screen.dart';
import 'package:im_client/services/storage_service.dart';
import 'package:im_client/services/local_message_service.dart';
import 'package:im_client/services/settings_service.dart';
import 'package:im_client/services/notification_service.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/utils/url_helper.dart' as url_helper;
import 'package:im_client/utils/startup_params.dart';
import 'package:im_client/utils/crypto_utils.dart';
import 'package:im_client/services/permission_service.dart';

void main() async {
  // ========== 在任何Flutter初始化之前捕获URL参数 ==========
  // 这必须在最开始执行，因为Flutter路由会修改URL
  if (kIsWeb) {
    url_helper.captureStartupUrl();
    // 保存邀请码到StartupParams
    final inviteCode = url_helper.getStartupUrlParam('invite') ??
        url_helper.getStartupUrlParam('code');
    StartupParams.instance.setInviteCode(inviteCode);
  }

  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化环境配置
  // 可通过命令行参数或编译配置切换环境：
  // flutter run --dart-define=ENV=dev
  // flutter run --dart-define=ENV=staging
  // flutter run --dart-define=ENV=prod
  const envName = String.fromEnvironment('ENV', defaultValue: 'dev');
  print('[Main] 环境变量 ENV=$envName');
  switch (envName) {
    case 'test':
    case 'staging':
      EnvConfig.init(Environment.staging);
      break;
    case 'prod':
    case 'production':
      EnvConfig.init(Environment.prod);
      break;
    default:
      EnvConfig.init(Environment.dev);
  }
  
  // 打印环境配置信息
  EnvConfig.instance.printConfig();

  // 初始化传输加密 (AES-256-GCM)
  final env = EnvConfig.instance;
  if (env.encryptEnabled && env.encryptKey.isNotEmpty) {
    try {
      CryptoUtils.init(env.encryptKey);
      print('Transport encryption: ENABLED');
    } catch (e) {
      print('Transport encryption init failed: $e');
    }
  }

  // 设置状态栏样式
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // 初始化本地存储
  await StorageService().init();

  // 初始化本地消息存储（使用Hive，支持Web平台）
  await LocalMessageService().init();

  // 初始化设置服务
  await SettingsService().init();

  // 初始化 Firebase（仅移动端，Web端使用Service Worker）
  // 需要先添加 google-services.json (Android) 和 GoogleService-Info.plist (iOS)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      // 注册后台消息处理
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      print('[Main] Firebase initialized');
    } catch (e) {
      print('[Main] Firebase init skipped (config not found): $e');
    }
  }

  // 初始化本地数据库（仅非Web平台）
  // 注意：sqflite 不支持 Web 平台，Web 端使用其他存储方案
  // if (!kIsWeb) {
  //   await LocalDatabaseService().database;
  // }

  runApp(const IMApp());
}

/// 应用主组件
class IMApp extends StatelessWidget {
  const IMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 应用配置（从服务端获取）
        // 注意：init() 必须延迟到 build 之后，否则 notifyListeners 会在 build 期间触发
        ChangeNotifierProvider(create: (_) {
          final p = AppConfigProvider();
          Future.microtask(() => p.init());
          return p;
        }),
        // 语言设置
        ChangeNotifierProvider(create: (_) {
          final p = LocaleProvider();
          Future.microtask(() => p.init());
          return p;
        }),
        // 认证状态
        ChangeNotifierProvider(create: (_) {
          final p = AuthProvider();
          Future.microtask(() => p.init());
          return p;
        }),
        // 聊天状态
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        // 群通话状态
        ChangeNotifierProvider(create: (_) => GroupCallProvider()),
        // 小视频状态
        ChangeNotifierProvider(create: (_) => SmallVideoProvider()),
        // 直播状态
        ChangeNotifierProvider(create: (_) => LivestreamProvider()),
        // 全局设置
        ChangeNotifierProvider.value(value: SettingsService()),
      ],
      child: Consumer3<LocaleProvider, SettingsService, AppConfigProvider>(
        builder: (context, localeProvider, settingsService, appConfig, _) {
          return MaterialApp(
            title: appConfig.loaded ? appConfig.appName : EnvConfig.instance.appName,
            debugShowCheckedModeBanner: EnvConfig.instance.isDev,
            theme: _buildTheme(appConfig),
            // 全局启用鼠标拖拽滚动（Web/桌面端模拟触摸滑动）
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
                PointerDeviceKind.trackpad,
              },
            ),
            // 国际化配置
            locale: localeProvider.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const AuthWrapper(),
            routes: _buildRoutes(),
            // 全局字体缩放
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              final scale = settingsService.fontSize.scale;
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }

  /// 构建主题
  ThemeData _buildTheme(AppConfigProvider appConfig) {
    final seedColor = appConfig.loaded ? appConfig.primaryColor : AppColors.primary;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppSizes.fontTitle,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.5,
        space: 0,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  /// 构建路由表
  Map<String, WidgetBuilder> _buildRoutes() {
    return {
      // Routes.splash 是 '/'，已由 home 属性处理
      Routes.login: (_) => const LoginScreen(),
      Routes.home: (_) => const HomeScreen(),
      // TODO: 添加更多路由
    };
  }
}

/// 认证包装器
/// 根据登录状态显示不同页面
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _chatInitialized = false;

  @override
  void initState() {
    super.initState();
    // 每次启动都检查并请求未授权的权限
    PermissionService.requestAllPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.initial:
          case AuthStatus.loading:
            return const SplashScreen();
          case AuthStatus.authenticated:
            // 初始化聊天Provider（包括WebSocket连接）
            if (!_chatInitialized && auth.user != null && auth.token != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final apiClient = ApiClient();
                context.read<ChatProvider>().init(
                  apiClient,
                  auth.user!.id,
                  token: auth.token,
                );
                // 初始化群通话Provider
                context.read<GroupCallProvider>().init(auth.user!.id);
                // 初始化推送通知（移动端FCM）
                NotificationService().init();
                setState(() {
                  _chatInitialized = true;
                });
              });
            }
            return const HomeScreen();
          case AuthStatus.unauthenticated:
            // 重置状态
            if (_chatInitialized) {
              // 清理ChatProvider状态，确保下次登录重新初始化（修复被踢后重连状态不同步）
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.read<ChatProvider>().clear();
                }
              });
              context.read<GroupCallProvider>().reset();
              NotificationService().logout();
              _chatInitialized = false;
            }
            // 如果是被踢出的（非主动退出），弹窗提示
            if (auth.forceLogoutReason != null) {
              final reasonKey = auth.forceLogoutReason!;
              auth.clearForceLogoutReason();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  final l10n = AppLocalizations.of(context);
                  
                  // 根据翻译键获取对应的翻译文本
                  String message;
                  switch (reasonKey) {
                    case 'logout_other_device':
                      message = l10n?.logoutOtherDevice ?? '您的账号在其他设备登录';
                      break;
                    case 'logout_admin_kick':
                      message = l10n?.logoutAdminKick ?? '您的设备已被管理员登出';
                      break;
                    case 'logout_token_expired':
                      message = l10n?.logoutTokenExpired ?? '登录已过期，请重新登录';
                      break;
                    case 'logout_user_logout':
                      message = l10n?.logoutUserLogout ?? '您已退出登录';
                      break;
                    case 'logout_max_devices':
                      message = l10n?.logoutMaxDevices ?? '已达到最大设备数限制';
                      break;
                    default:
                      // 如果是未知的键，直接显示（可能是服务端自定义消息）
                      message = reasonKey;
                  }
                  
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => AlertDialog(
                      title: Text(l10n?.forcedOfflineTitle ?? '下线通知'),
                      content: Text(message),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n?.confirm ?? '确定'),
                        ),
                      ],
                    ),
                  );
                }
              });
            }
            return const LoginScreen();
        }
      },
    );
  }
}
