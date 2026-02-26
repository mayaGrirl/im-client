/// 权限请求服务
/// 在 App 每次启动时检查并请求所有需要的权限

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// App 需要请求的所有运行时权限
  static List<Permission> get _requiredPermissions {
    final permissions = <Permission>[
      Permission.camera,
      Permission.microphone,
      Permission.location,
      Permission.notification,
    ];

    if (Platform.isAndroid) {
      permissions.addAll([
        // 媒体权限（Android 13+）
        Permission.photos,
        Permission.videos,
        // 蓝牙（WebRTC 蓝牙耳机）
        Permission.bluetoothConnect,
        // 旧版存储（Android 12 及以下）
        Permission.storage,
      ]);
    }

    if (Platform.isIOS) {
      permissions.add(Permission.photos);
    }

    return permissions;
  }

  /// 每次启动时请求所有未授权的权限
  /// 返回 true 表示处理完成（无论用户同意还是拒绝）
  static Future<bool> requestAllPermissions() async {
    if (kIsWeb) return true;

    try {
      // 逐个检查，只请求尚未授权的权限
      final toRequest = <Permission>[];
      for (final permission in _requiredPermissions) {
        final status = await permission.status;
        if (!status.isGranted && !status.isPermanentlyDenied) {
          toRequest.add(permission);
        }
      }

      if (toRequest.isNotEmpty) {
        print('[PermissionService] 请求权限: $toRequest');
        await toRequest.request();
      } else {
        print('[PermissionService] 所有权限已授权');
      }
    } catch (e) {
      print('[PermissionService] 请求权限异常: $e');
    }

    return true;
  }

  /// 获取所有权限的当前状态（用于调试或展示）
  static Future<Map<Permission, PermissionStatus>> checkAllPermissions() async {
    if (kIsWeb) return {};

    final statuses = <Permission, PermissionStatus>{};
    for (final permission in _requiredPermissions) {
      statuses[permission] = await permission.status;
    }
    return statuses;
  }
}
