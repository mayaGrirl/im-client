/// 应用常量配置
/// 
/// 此文件包含应用的静态常量，如：
/// - UI常量（颜色、尺寸）
/// - 业务常量（消息类型、角色）
/// - 本地存储键
/// - 路由名称
/// 
/// 注意：API配置和环境相关配置请使用 EnvConfig
/// 参见：lib/config/env_config.dart

import 'package:flutter/material.dart';

/// 应用颜色
class AppColors {
  /// 主题色
  static const Color primary = Color(0xFF07C160);

  /// 次要色
  static const Color secondary = Color(0xFF576B95);

  /// 背景色
  static const Color background = Color(0xFFEDEDED);

  /// 白色背景
  static const Color white = Colors.white;

  /// 分割线颜色
  static const Color divider = Color(0xFFE5E5E5);

  /// 边框颜色
  static const Color border = Color(0xFFDCDCDC);

  /// 文字颜色 - 主要
  static const Color textPrimary = Color(0xFF191919);

  /// 文字颜色 - 次要
  static const Color textSecondary = Color(0xFF888888);

  /// 文字颜色 - 提示
  static const Color textHint = Color(0xFFB2B2B2);

  /// 错误颜色
  static const Color error = Color(0xFFFA5151);

  /// 成功颜色
  static const Color success = Color(0xFF07C160);

  /// 警告颜色
  static const Color warning = Color(0xFFFFC300);

  /// 在线状态颜色
  static const Color online = Color(0xFF07C160);

  /// 离线状态颜色
  static const Color offline = Color(0xFFB2B2B2);

  /// 聊天气泡 - 自己
  static const Color bubbleSelf = Color(0xFF95EC69);

  /// 聊天气泡 - 他人
  static const Color bubbleOther = Colors.white;

  /// 卡片背景色
  static const Color cardBackground = Colors.white;
}

/// 应用尺寸
class AppSizes {
  /// 页面内边距
  static const double pagePadding = 16.0;

  /// 列表项间距
  static const double listItemSpacing = 12.0;

  /// 头像大小 - 小
  static const double avatarSmall = 32.0;

  /// 头像大小 - 中
  static const double avatarMedium = 48.0;

  /// 头像大小 - 大
  static const double avatarLarge = 64.0;

  /// 圆角半径 - 小
  static const double radiusSmall = 4.0;

  /// 圆角半径 - 中
  static const double radiusMedium = 8.0;

  /// 圆角半径 - 大
  static const double radiusLarge = 16.0;

  /// 字体大小 - 小
  static const double fontSmall = 12.0;

  /// 字体大小 - 中
  static const double fontMedium = 14.0;

  /// 字体大小 - 大
  static const double fontLarge = 16.0;

  /// 字体大小 - 标题
  static const double fontTitle = 18.0;
}

/// 消息类型
class MessageType {
  static const int text = 1; // 文本消息
  static const int image = 2; // 图片消息
  static const int voice = 3; // 语音消息
  static const int video = 4; // 视频消息
  static const int file = 5; // 文件消息
  static const int location = 6; // 位置消息
  static const int card = 7; // 名片消息
  static const int forward = 8; // 合并转发消息
  static const int call = 9; // 通话消息
  static const int redPacket = 11; // 红包消息
  static const int redPacketTaken = 12; // 红包领取通知
  static const int videoShare = 13; // 视频分享卡片
  static const int livestreamShare = 14; // 直播分享卡片
  static const int system = 100; // 系统消息
}

/// 转发类型
class ForwardType {
  static const int oneByOne = 1; // 逐条转发
  static const int merged = 2; // 合并转发
}

/// 会话类型
class ConversationType {
  static const int private = 1; // 私聊
  static const int group = 2; // 群聊
}

/// 好友申请状态
class FriendRequestStatus {
  static const int pending = 0; // 待处理
  static const int accepted = 1; // 已同意
  static const int rejected = 2; // 已拒绝
}

/// 群组角色
class GroupRole {
  static const int member = 1; // 普通成员
  static const int admin = 2; // 管理员
  static const int owner = 3; // 群主
}

// 注意: CallType 和 CallStatus 定义在 call_api.dart 中，避免重复定义

/// 本地存储键
class StorageKeys {
  static const String token = 'auth_token';
  static const String userId = 'user_id';
  static const String userInfo = 'user_info';
  static const String settings = 'app_settings';
  static const String deviceToken = 'device_token';
}

/// 路由名称
class Routes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String contacts = '/contacts';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String userDetail = '/user-detail';
  static const String groupDetail = '/group-detail';
  static const String createGroup = '/create-group';
  static const String moments = '/moments';
  static const String call = '/call';
}
