/// 启动参数存储
/// 用于在应用启动时捕获URL参数（在路由处理之前）

class StartupParams {
  static final StartupParams _instance = StartupParams._internal();
  factory StartupParams() => _instance;
  StartupParams._internal();

  static StartupParams get instance => _instance;

  String? _inviteCode;

  /// 获取邀请码
  String? get inviteCode => _inviteCode;

  /// 设置邀请码（仅在启动时调用一次）
  void setInviteCode(String? code) {
    if (code != null && code.isNotEmpty) {
      _inviteCode = code;
      print('[StartupParams] 保存邀请码: $code');
    }
  }

  /// 消费邀请码（获取后清除，避免重复使用）
  String? consumeInviteCode() {
    final code = _inviteCode;
    _inviteCode = null;
    if (code != null) {
      print('[StartupParams] 消费邀请码: $code');
    }
    return code;
  }

  /// 清除所有参数
  void clear() {
    _inviteCode = null;
  }
}
