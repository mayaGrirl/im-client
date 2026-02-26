/// URL Helper - 非Web平台的存根实现

/// 捕获启动时的URL参数（非Web平台无需操作）
void captureStartupUrl() {}

/// 从启动URL获取参数（非Web平台返回null）
String? getStartupUrlParam(String key) => null;

/// 获取当前页面URL
String getCurrentUrl() => '';

/// 获取URL中的查询参数
String? getUrlQueryParam(String key) => null;

/// 获取当前页面的origin（协议+域名+端口）
String getCurrentOrigin() => '';
