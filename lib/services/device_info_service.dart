/// 设备信息服务
/// 获取设备的唯一标识、型号、系统版本等信息

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 设备信息
class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final String deviceModel;
  final String osVersion;
  final String appVersion;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.deviceModel,
    required this.osVersion,
    required this.appVersion,
  });

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'device_name': deviceName,
        'device_type': deviceType,
        'device_model': deviceModel,
        'os_version': osVersion,
        'app_version': appVersion,
      };
}

/// 设备信息服务
class DeviceInfoService {
  static final DeviceInfoService _instance = DeviceInfoService._internal();
  factory DeviceInfoService() => _instance;
  DeviceInfoService._internal();

  static const String _deviceIdKey = 'device_unique_id';
  DeviceInfo? _cachedInfo;

  /// 获取设备信息
  Future<DeviceInfo> getDeviceInfo() async {
    if (_cachedInfo != null) {
      return _cachedInfo!;
    }

    final deviceInfoPlugin = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();

    String deviceId;
    String deviceName;
    String deviceType;
    String deviceModel;
    String osVersion;

    // 获取或生成设备唯一ID
    deviceId = prefs.getString(_deviceIdKey) ?? '';
    if (deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    if (kIsWeb) {
      // Web平台 - 根据userAgent区分PC/移动端/平板
      final webInfo = await deviceInfoPlugin.webBrowserInfo;
      deviceName = webInfo.browserName.name;
      deviceModel = '${webInfo.browserName.name} ${webInfo.appVersion ?? ''}';
      osVersion = webInfo.platform ?? 'Unknown';
      // 通过platform和userAgent判断Web子类型
      final platform = (webInfo.platform ?? '').toLowerCase();
      final userAgent = (webInfo.userAgent ?? '').toLowerCase();
      if (userAgent.contains('ipad') || userAgent.contains('tablet') || userAgent.contains('android') && !userAgent.contains('mobile')) {
        deviceType = 'web_tablet';
      } else if (userAgent.contains('mobile') || userAgent.contains('iphone') || userAgent.contains('android')) {
        deviceType = 'web_h5';
      } else if (platform.contains('win') || platform.contains('mac') || platform.contains('linux')) {
        deviceType = 'web_pc';
      } else {
        deviceType = 'web_pc';
      }
    } else if (Platform.isAndroid) {
      // Android平台
      final androidInfo = await deviceInfoPlugin.androidInfo;
      deviceName = androidInfo.model;
      deviceType = 'android';
      deviceModel = '${androidInfo.brand} ${androidInfo.model}';
      osVersion = 'Android ${androidInfo.version.release}';
    } else if (Platform.isIOS) {
      // iOS平台 - 区分iPhone和iPad
      final iosInfo = await deviceInfoPlugin.iosInfo;
      deviceName = iosInfo.name;
      final model = iosInfo.utsname.machine.toLowerCase();
      deviceType = model.contains('ipad') ? 'ipad' : 'ios';
      deviceModel = iosInfo.utsname.machine;
      osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
    } else if (Platform.isMacOS) {
      // macOS平台
      final macInfo = await deviceInfoPlugin.macOsInfo;
      deviceName = macInfo.computerName;
      deviceType = 'macos';
      deviceModel = macInfo.model;
      osVersion = 'macOS ${macInfo.osRelease}';
    } else if (Platform.isWindows) {
      // Windows平台
      final windowsInfo = await deviceInfoPlugin.windowsInfo;
      deviceName = windowsInfo.computerName;
      deviceType = 'windows';
      deviceModel = windowsInfo.productName;
      osVersion = 'Windows ${windowsInfo.majorVersion}.${windowsInfo.minorVersion}';
    } else if (Platform.isLinux) {
      // Linux平台
      final linuxInfo = await deviceInfoPlugin.linuxInfo;
      deviceName = linuxInfo.prettyName;
      deviceType = 'linux';
      deviceModel = linuxInfo.name;
      osVersion = linuxInfo.versionId ?? 'Unknown';
    } else {
      // 其他平台
      deviceName = 'Unknown Device';
      deviceType = 'unknown';
      deviceModel = 'Unknown';
      osVersion = 'Unknown';
    }

    _cachedInfo = DeviceInfo(
      deviceId: deviceId,
      deviceName: deviceName,
      deviceType: deviceType,
      deviceModel: deviceModel,
      osVersion: osVersion,
      appVersion: packageInfo.version,
    );

    return _cachedInfo!;
  }

  /// 获取设备ID
  Future<String> getDeviceId() async {
    final info = await getDeviceInfo();
    return info.deviceId;
  }

  /// 清除缓存
  void clearCache() {
    _cachedInfo = null;
  }
}
