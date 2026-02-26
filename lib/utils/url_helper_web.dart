/// URL Helper - Web平台实现
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// 启动时的原始URL（在路由处理之前保存）
String? _startupUrl;

/// 捕获启动时的URL参数（必须在runApp之前调用）
/// 这是为了解决Flutter Web路由会在读取参数前重定向的问题
void captureStartupUrl() {
  _startupUrl = html.window.location.href;
  print('[url_helper_web] 捕获启动URL: $_startupUrl');
}

/// 从启动URL获取参数（用于在路由重定向后仍能读取原始参数）
String? getStartupUrlParam(String key) {
  if (_startupUrl == null) return null;

  try {
    print('[url_helper_web] 从启动URL解析参数: $_startupUrl');

    // 解析hash中的参数 (格式: .../#/?invite=xxx 或 .../#/login?invite=xxx)
    final hashIndex = _startupUrl!.indexOf('#');
    if (hashIndex != -1) {
      final hashPart = _startupUrl!.substring(hashIndex + 1);
      print('[url_helper_web] hash部分: $hashPart');

      if (hashPart.contains('?')) {
        final queryStart = hashPart.indexOf('?');
        final queryString = hashPart.substring(queryStart);
        final uri = Uri.parse('http://dummy/$queryString');
        if (uri.queryParameters.containsKey(key)) {
          final value = uri.queryParameters[key];
          print('[url_helper_web] 从启动URL找到参数 $key: $value');
          return value;
        }
      }
    }

    // 也尝试普通的查询参数
    final uri = Uri.parse(_startupUrl!);
    if (uri.queryParameters.containsKey(key)) {
      return uri.queryParameters[key];
    }

    print('[url_helper_web] 启动URL中未找到参数: $key');
    return null;
  } catch (e) {
    print('[url_helper_web] 解析启动URL参数错误: $e');
    return null;
  }
}

/// 获取当前页面URL
String getCurrentUrl() => html.window.location.href;

/// 获取URL中的查询参数
/// 支持多种格式：
/// 1. 普通参数: http://example.com?invite=xxx
/// 2. Hash路由参数: http://example.com/#/?invite=xxx
/// 3. Hash路由路径参数: http://example.com/#/login?invite=xxx
String? getUrlQueryParam(String key) {
  try {
    final href = html.window.location.href;
    print('[url_helper_web] href: $href');

    // 方法1: 直接从 location.search 获取（?key=value 部分）
    final search = html.window.location.search ?? '';
    if (search.isNotEmpty) {
      print('[url_helper_web] search: $search');
      final searchUri = Uri.parse('http://dummy/$search');
      if (searchUri.queryParameters.containsKey(key)) {
        print('[url_helper_web] 从search找到: ${searchUri.queryParameters[key]}');
        return searchUri.queryParameters[key];
      }
    }

    // 方法2: 从 hash 部分获取（Flutter Web 使用 hash 路由）
    final hash = html.window.location.hash ?? '';
    if (hash.isNotEmpty) {
      print('[url_helper_web] hash: $hash');
      // hash 格式可能是: #/?invite=xxx 或 #/login?invite=xxx
      // 移除开头的 #
      var hashContent = hash.startsWith('#') ? hash.substring(1) : hash;
      // 解析 hash 中的查询参数
      if (hashContent.contains('?')) {
        final queryStart = hashContent.indexOf('?');
        final queryString = hashContent.substring(queryStart);
        final hashUri = Uri.parse('http://dummy/$queryString');
        if (hashUri.queryParameters.containsKey(key)) {
          print('[url_helper_web] 从hash找到: ${hashUri.queryParameters[key]}');
          return hashUri.queryParameters[key];
        }
      }
    }

    // 方法3: 完整解析 URI
    final uri = Uri.parse(href);
    if (uri.queryParameters.containsKey(key)) {
      print('[url_helper_web] 从uri找到: ${uri.queryParameters[key]}');
      return uri.queryParameters[key];
    }

    print('[url_helper_web] 未找到参数: $key');
    return null;
  } catch (e) {
    print('[url_helper_web] 解析错误: $e');
    return null;
  }
}

/// 获取当前页面的origin（协议+域名+端口）
String getCurrentOrigin() {
  try {
    return html.window.location.origin;
  } catch (e) {
    return '';
  }
}
