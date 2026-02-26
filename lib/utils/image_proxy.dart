/// 图片代理工具类
/// 用于处理外部图片URL的CORS问题
library;

import 'package:flutter/foundation.dart';

class ImageProxy {
  /// 需要代理的域名列表
  static const List<String> _proxyDomains = [
    'randomuser.me',
    'xsgames.co',
    'i.pravatar.cc',
    'ui-avatars.com',
    'avatar.iran.liara.run',
    'api.dicebear.com',  // DiceBear Avatars
    'picsum.photos',
    'loremflickr.com',
    'source.unsplash.com',
    'unsplash.com',
    'images.unsplash.com',
    'cdn.pixabay.com',
    'images.pexels.com',
  ];

  /// 检查URL是否需要代理
  static bool needsProxy(String? url) {
    if (url == null || url.isEmpty) return false;

    // 只在Web平台需要代理
    if (!kIsWeb) return false;

    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      // 检查是否是需要代理的域名
      for (final domain in _proxyDomains) {
        if (host == domain || host.endsWith('.$domain')) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('[ImageProxy] 解析URL失败: $url, error: $e');
    }

    return false;
  }

  /// 获取代理后的URL
  /// 
  /// [originalUrl] 原始图片URL
  /// [baseUrl] API基础URL，默认从环境变量读取
  static String getProxiedUrl(String originalUrl, {String? baseUrl}) {
    if (!needsProxy(originalUrl)) {
      return originalUrl;
    }

    // 获取API基础URL
    final apiBase = baseUrl ?? _getApiBaseUrl();
    
    // URL编码
    final encodedUrl = Uri.encodeComponent(originalUrl);
    
    // 返回代理URL
    return '$apiBase/api/proxy/image?url=$encodedUrl';
  }

  /// 批量转换URL列表
  static List<String> getProxiedUrls(List<String> urls, {String? baseUrl}) {
    return urls.map((url) => getProxiedUrl(url, baseUrl: baseUrl)).toList();
  }

  /// 获取API基础URL
  static String _getApiBaseUrl() {
    // 从环境变量读取
    const apiUrl = String.fromEnvironment('API_URL', defaultValue: '');
    if (apiUrl.isNotEmpty) {
      return apiUrl;
    }

    // 开发环境默认值
    if (kDebugMode) {
      return 'http://localhost:8080';
    }

    // 生产环境从当前域名推断
    if (kIsWeb) {
      final currentUrl = Uri.base;
      return '${currentUrl.scheme}://${currentUrl.host}${currentUrl.hasPort ? ':${currentUrl.port}' : ''}';
    }

    return '';
  }

  /// 预加载图片（可选）
  /// 用于提前加载图片到缓存
  static Future<void> precacheImage(String url, {String? baseUrl}) async {
    // 这里可以添加预加载逻辑
    // 例如使用 http 包提前请求图片
    debugPrint('[ImageProxy] 预加载图片: $url');
  }
}

/// 扩展方法：为String添加代理转换
extension ImageProxyExtension on String {
  /// 转换为代理URL（如果需要）
  String get proxied => ImageProxy.getProxiedUrl(this);

  /// 检查是否需要代理
  bool get needsProxy => ImageProxy.needsProxy(this);
}

/// 扩展方法：为String?添加代理转换
extension NullableImageProxyExtension on String? {
  /// 转换为代理URL（如果需要）
  String? get proxied {
    if (this == null) return null;
    return ImageProxy.getProxiedUrl(this!);
  }

  /// 检查是否需要代理
  bool get needsProxy => ImageProxy.needsProxy(this);
}
