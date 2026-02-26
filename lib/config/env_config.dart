import 'package:im_client/api/api_client.dart';

/// 环境配置
/// 管理不同环境的配置参数

enum Environment {
  dev,      // 开发环境
  staging,  // 测试环境
  prod,     // 生产环境
}

class EnvConfig {
  static EnvConfig? _instance;

  final Environment env;
  final String appName;
  final String baseUrl;
  final String wsUrl;
  final String apiPrefix;
  final int timeout;
  final bool enableLog;
  final bool enableDebug;

  // 文件上传配置
  final int maxUploadSize; // MB
  final String uploadPath;

  // 分页配置
  final int defaultPageSize;

  // 缓存配置
  final int cacheMaxAge; // 秒

  // WebRTC配置
  final String stunServer;
  final String? turnServer;
  final String? turnUser;
  final String? turnPass;

  // 传输加密配置 (AES-256-GCM)
  final bool encryptEnabled;
  final String encryptKey;

  EnvConfig._({
    required this.env,
    required this.appName,
    required this.baseUrl,
    required this.wsUrl,
    required this.apiPrefix,
    required this.timeout,
    required this.enableLog,
    required this.enableDebug,
    this.maxUploadSize = 50,
    this.uploadPath = '/upload',
    this.defaultPageSize = 20,
    this.cacheMaxAge = 3600,
    this.stunServer = 'stun:stun.l.google.com:19302',
    this.turnServer,
    this.turnUser,
    this.turnPass,
    this.encryptEnabled = false,
    this.encryptKey = '',
  });

  /// 获取当前环境配置实例
  static EnvConfig get instance {
    _instance ??= _dev();
    return _instance!;
  }

  /// 初始化环境配置
  static void init(Environment env) {
    switch (env) {
      case Environment.dev:
        _instance = _dev();
        break;
      case Environment.staging:
        _instance = _staging();
        break;
      case Environment.prod:
        _instance = _prod();
        break;
    }
  }

  /// 通过字符串初始化环境
  static void initFromString(String envName) {
    switch (envName.toLowerCase()) {
      case 'production':
      case 'prod':
        init(Environment.prod);
        break;
      case 'staging':
      case 'test':
        init(Environment.staging);
        break;
      default:
        init(Environment.dev);
    }
  }

  /// 开发环境配置
  /// 注意：如果客户端在不同设备上运行（如手机），需要将 localhost 改为服务器的局域网IP
  /// 例如：http://192.168.1.100:8080
  static EnvConfig _dev() {
    // TODO: 如果在不同设备上测试，请将 localhost 改为服务器的实际IP地址
    const serverHost = 'localhost'; // 改为你的服务器IP，如 '192.168.1.100'
    return EnvConfig._(
      env: Environment.dev,
      appName: 'IM即时通讯（local）',
      baseUrl: 'http://$serverHost:8080',
      wsUrl: 'ws://$serverHost:8080/ws',
      apiPrefix: '/api',
      timeout: 30000,
      enableLog: true,
      enableDebug: true,
      maxUploadSize: 50,
      uploadPath: '/upload',
      defaultPageSize: 20,
      cacheMaxAge: 300, // 开发环境缓存5分钟
      stunServer: 'stun:stun.l.google.com:19302',
      encryptEnabled: false, // 开发环境默认关闭加密
      encryptKey: '',
    );
  }

  /// 测试环境配置
  static EnvConfig _staging() {
    return EnvConfig._(
      env: Environment.staging,
      appName: 'IM即时通讯(测试)',
      baseUrl: 'https://ws.kaixin28.com',
      wsUrl: 'wss://ws.kaixin28.com/ws', // 确保使用标准 443 端口，不显式指定
      apiPrefix: '/api',
      timeout: 30000,
      enableLog: true,
      enableDebug: true, // 开启调试以查看详细日志
      maxUploadSize: 50,
      uploadPath: '/upload',
      defaultPageSize: 20,
      cacheMaxAge: 1800, // 测试环境缓存30分钟
      stunServer: 'stun:stun.l.google.com:19302',
      encryptEnabled: false,
      encryptKey: '',
    );
  }

  /// 生产环境配置
  static EnvConfig _prod() {
    return EnvConfig._(
      env: Environment.prod,
      appName: 'IM即时通讯',
      baseUrl: 'https://im.511cdn.com',
      wsUrl: 'wss://im.511cdn.com/ws',
      apiPrefix: '/api',
      timeout: 15000,
      enableLog: true,  // 临时开启日志以调试
      enableDebug: true, // 临时开启调试
      maxUploadSize: 50,
      uploadPath: '/upload',
      defaultPageSize: 20,
      cacheMaxAge: 3600, // 生产环境缓存1小时
      stunServer: 'stun:stun.l.google.com:19302',
      encryptEnabled: true,
      encryptKey: '', // TODO: Set production 64-char hex key here
    );
  }

  /// 是否是开发环境
  bool get isDev => env == Environment.dev;

  /// 是否是测试环境
  bool get isStaging => env == Environment.staging;

  /// 是否是生产环境
  bool get isProd => env == Environment.prod;

  /// 完整API地址
  String get fullApiUrl => '$baseUrl$apiPrefix';

  /// 完整上传地址
  String get fullUploadUrl => '$baseUrl$apiPrefix$uploadPath';

  /// 需要通过视频中继访问的外部CDN域名
  static const _relayDomains = [
    'videos.pexels.com',
    'images.pexels.com',
    'player.vimeo.com',
    'vod-progressive.akamaized.net',
    'cdn.pixabay.com',
    'pixabay.com',
    'vimeocdn.com',
    'vimeo.com',
    'skyfire.vimeocdn.com',
  ];

  /// 获取文件完整URL
  String getFileUrl(String path) {
    if (path.isEmpty) return '';
    // 防止只有 / 的情况导致访问根路径
    if (path == '/') return '';
    // 统一将反斜杠替换为正斜杠（Windows路径兼容）
    path = path.replaceAll('\\', '/');
    if (path.startsWith('http://') || path.startsWith('https://')) {
      // 只有外部视频CDN的视频文件才走中继（图片不走）
      if (_needsVideoRelay(path)) {
        final encoded = Uri.encodeComponent(path);
        // 通过 query param 传 token（Web <video> 元素无法设自定义 header）
        final token = ApiClient().token ?? '';
        return '$baseUrl/api/video/relay?url=$encoded&token=$token';
      }
      return path;
    }
    return '$baseUrl$path';
  }

  /// 视频文件扩展名
  static const _videoExtensions = ['.mp4', '.webm', '.mov', '.m3u8', '.ts', '.avi', '.mkv'];

  /// 检查URL是否需要通过视频中继（仅视频文件，不含图片）
  bool _needsVideoRelay(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    // 检查域名是否在CDN白名单中
    final host = uri.host.toLowerCase();
    bool domainMatch = false;
    for (final domain in _relayDomains) {
      if (host == domain || host.endsWith('.$domain')) {
        domainMatch = true;
        break;
      }
    }
    if (!domainMatch) return false;

    // 检查是否是视频文件（通过扩展名判断）
    final path = uri.path.toLowerCase();
    for (final ext in _videoExtensions) {
      if (path.endsWith(ext)) return true;
    }

    // 对于无扩展名的URL（如某些CDN流），通过路径关键词判断
    if (path.contains('video') || path.contains('/v/')) return true;

    return false;
  }

  /// 环境名称
  String get envName {
    switch (env) {
      case Environment.dev:
        return 'development';
      case Environment.staging:
        return 'staging';
      case Environment.prod:
        return 'production';
    }
  }

  @override
  String toString() {
    return 'EnvConfig{env: $envName, appName: $appName, baseUrl: $baseUrl, wsUrl: $wsUrl}';
  }

  /// 打印配置信息（仅开发环境）
  void printConfig() {
    if (enableDebug) {
      print('========== Environment Config ==========');
      print('Environment: $envName');
      print('App Name: $appName');
      print('Base URL: $baseUrl');
      print('WebSocket URL: $wsUrl');
      print('API Prefix: $apiPrefix');
      print('Timeout: ${timeout}ms');
      print('Debug: $enableDebug');
      print('Log: $enableLog');
      print('=========================================');
    }
  }
}
