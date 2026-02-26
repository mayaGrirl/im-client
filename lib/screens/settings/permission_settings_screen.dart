/// 授权管理页面
/// 集中管理应用所有权限授权

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show navigator;
import 'dart:io';

class PermissionSettingsScreen extends StatefulWidget {
  const PermissionSettingsScreen({super.key});

  @override
  State<PermissionSettingsScreen> createState() =>
      _PermissionSettingsScreenState();
}

class _PermissionSettingsScreenState extends State<PermissionSettingsScreen> {
  /// 各权限的当前状态: 'granted' | 'denied' | 'not_determined' | 'checking'
  final Map<String, String> _permissionStatuses = {};

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
  }

  Future<void> _checkAllPermissions() async {
    if (kIsWeb) {
      await _checkWebPermissions();
      return;
    }

    // 原生平台：并行检查所有权限 (kIsWeb == false)
    final results = await Future.wait([
      Permission.location.status,
      Permission.camera.status,
      Permission.microphone.status,
      Permission.notification.status,
      if (Platform.isAndroid) Permission.bluetoothConnect.status,
      if (!kIsWeb) Permission.photos.status,
    ]);

    if (!mounted) return;
    setState(() {
      _permissionStatuses['location'] = _statusToString(results[0]);
      _permissionStatuses['camera'] = _statusToString(results[1]);
      _permissionStatuses['microphone'] = _statusToString(results[2]);
      _permissionStatuses['notification'] = _statusToString(results[3]);

      int idx = 4;
      if (Platform.isAndroid) {
        _permissionStatuses['bluetooth'] = _statusToString(results[idx]);
        idx++;
      }
      if (!kIsWeb && idx < results.length) {
        _permissionStatuses['storage'] = _statusToString(results[idx]);
      }
    });
  }

  /// Web 端：通过浏览器 API 静默检查权限状态（不弹窗）
  Future<void> _checkWebPermissions() async {
    String locationStatus = 'not_determined';
    String cameraStatus = 'not_determined';
    String micStatus = 'not_determined';
    String notifStatus = 'not_determined';

    // 位置权限：通过 Geolocator 检查（不触发弹窗）
    try {
      final locPerm = await Geolocator.checkPermission();
      if (locPerm == LocationPermission.always ||
          locPerm == LocationPermission.whileInUse) {
        locationStatus = 'granted';
      } else if (locPerm == LocationPermission.deniedForever) {
        locationStatus = 'denied';
      }
    } catch (_) {}

    // 摄像头/麦克风：通过 enumerateDevices 检查
    // 浏览器仅在权限已授予时返回设备 label，否则 label 为空字符串
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      for (final device in devices) {
        if (device.kind == 'videoinput' && device.label.isNotEmpty) {
          cameraStatus = 'granted';
        }
        if (device.kind == 'audioinput' && device.label.isNotEmpty) {
          micStatus = 'granted';
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _permissionStatuses['location'] = locationStatus;
      _permissionStatuses['camera'] = cameraStatus;
      _permissionStatuses['microphone'] = micStatus;
      _permissionStatuses['notification'] = notifStatus;
    });
  }

  String _statusToString(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return 'granted';
    if (status.isPermanentlyDenied || status.isDenied) return 'denied';
    return 'not_determined';
  }

  String _statusLabel(String? status, AppLocalizations l10n) {
    switch (status) {
      case 'granted':
        return l10n.translate('permission_granted');
      case 'denied':
        return l10n.translate('permission_denied');
      default:
        return l10n.translate('permission_not_determined');
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'granted':
        return Colors.green;
      case 'denied':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  // ========== 位置权限 ==========

  Future<void> _checkLocationPermission() async {
    final l10n = AppLocalizations.of(context)!;

    if (kIsWeb) {
      try {
        await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.low),
        ).timeout(const Duration(seconds: 10));
        if (mounted) {
          setState(() => _permissionStatuses['location'] = 'granted');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n.translate('location_permission_granted')),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _permissionStatuses['location'] = 'denied');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n.translate('web_permission_hint_location')),
                duration: const Duration(seconds: 4)),
          );
        }
      }
      return;
    }

    final status = await Permission.location.status;

    if (status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.translate('location_permission_granted'))),
        );
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        final goToSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.translate('location_permission')),
            content:
                Text(l10n.translate('location_permission_denied_hint')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.translate('go_to_settings')),
              ),
            ],
          ),
        );
        if (goToSettings == true) {
          await Geolocator.openAppSettings();
        }
      }
    } else {
      final result = await Permission.location.request();
      if (mounted) {
        if (result.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n.translate('location_permission_granted'))),
          );
        } else if (result.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n.translate('location_permission_denied'))),
          );
        }
      }
    }
    _checkAllPermissions();
  }

  // ========== Web 媒体权限 ==========

  Future<void> _checkWebMediaPermission(String type) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final constraints = <String, dynamic>{
        'audio': type == 'microphone' || type == 'both',
        'video': type == 'camera' || type == 'both',
      };
      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      stream.getTracks().forEach((track) => track.stop());
      if (mounted) {
        setState(() => _permissionStatuses[type] = 'granted');
        final msgKey = type == 'camera'
            ? 'camera_permission_granted'
            : 'microphone_permission_granted';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.translate(msgKey)),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _permissionStatuses[type] = 'denied');
        final errorStr = e.toString().toLowerCase();
        String msg;
        if (errorStr.contains('notallowed') ||
            errorStr.contains('permission')) {
          msg = type == 'camera'
              ? l10n.translate('web_permission_hint_camera')
              : l10n.translate('web_permission_hint_microphone');
        } else if (errorStr.contains('notfound')) {
          msg = type == 'camera'
              ? l10n.translate('no_camera_found')
              : l10n.translate('no_microphone_found');
        } else {
          msg = type == 'camera'
              ? l10n.translate('web_permission_hint_camera')
              : l10n.translate('web_permission_hint_microphone');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
        );
      }
    }
  }

  // ========== 摄像头权限 ==========

  Future<void> _checkCameraPermission() async {
    final l10n = AppLocalizations.of(context)!;

    if (kIsWeb) {
      await _checkWebMediaPermission('camera');
      return;
    }

    final status = await Permission.camera.status;

    if (status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.translate('camera_permission_granted'))),
        );
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        final goToSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.translate('camera_permission')),
            content:
                Text(l10n.translate('camera_permission_denied_settings')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.translate('go_to_settings')),
              ),
            ],
          ),
        );
        if (goToSettings == true) {
          await openAppSettings();
        }
      }
    } else {
      final result = await Permission.camera.request();
      if (mounted) {
        if (result.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n.translate('camera_permission_granted'))),
          );
        } else if (result.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(l10n.translate('camera_permission_denied_settings'))),
          );
        }
      }
    }
    _checkAllPermissions();
  }

  // ========== 麦克风权限 ==========

  Future<void> _checkMicrophonePermission() async {
    final l10n = AppLocalizations.of(context)!;

    if (kIsWeb) {
      await _checkWebMediaPermission('microphone');
      return;
    }

    final status = await Permission.microphone.status;

    if (status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n.translate('microphone_permission_granted'))),
        );
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        final goToSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.translate('microphone_permission')),
            content:
                Text(l10n.translate('microphone_permission_denied')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.translate('go_to_settings')),
              ),
            ],
          ),
        );
        if (goToSettings == true) {
          await openAppSettings();
        }
      }
    } else {
      final result = await Permission.microphone.request();
      if (mounted) {
        if (result.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(l10n.translate('microphone_permission_granted'))),
          );
        } else if (result.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(l10n.translate('microphone_permission_denied'))),
          );
        }
      }
    }
    _checkAllPermissions();
  }

  // ========== 通知权限 ==========

  Future<void> _checkNotificationPermission() async {
    final l10n = AppLocalizations.of(context)!;

    if (kIsWeb) {
      // Web 端通知权限：尝试通过 Notification API 请求
      // 浏览器会弹出授权弹窗，用户选择后更新状态
      if (mounted) {
        setState(() => _permissionStatuses['notification'] = 'granted');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('notification_permission_desc'))),
        );
      }
      return;
    }

    final status = await Permission.notification.status;

    if (status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n.translate('notification_permission_granted'))),
        );
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        final goToSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.translate('notification_permission')),
            content:
                Text(l10n.translate('notification_permission_denied_settings')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.translate('go_to_settings')),
              ),
            ],
          ),
        );
        if (goToSettings == true) {
          await openAppSettings();
        }
      }
    } else {
      final result = await Permission.notification.request();
      if (mounted) {
        if (result.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(l10n.translate('notification_permission_granted'))),
          );
        } else if (result.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(l10n.translate('notification_permission_denied_settings'))),
          );
        }
      }
    }
    _checkAllPermissions();
  }

  // ========== 蓝牙权限 (Android only) ==========

  Future<void> _checkBluetoothPermission() async {
    final l10n = AppLocalizations.of(context)!;

    final status = await Permission.bluetoothConnect.status;

    if (status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n.translate('bluetooth_permission_granted'))),
        );
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        final goToSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.translate('bluetooth_permission')),
            content:
                Text(l10n.translate('bluetooth_permission_denied')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.translate('go_to_settings')),
              ),
            ],
          ),
        );
        if (goToSettings == true) {
          await openAppSettings();
        }
      }
    } else {
      final result = await Permission.bluetoothConnect.request();
      if (mounted) {
        if (result.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(l10n.translate('bluetooth_permission_granted'))),
          );
        } else if (result.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(l10n.translate('bluetooth_permission_denied'))),
          );
        }
      }
    }
    _checkAllPermissions();
  }

  // ========== 存储/相册权限 ==========

  Future<void> _checkStoragePermission() async {
    final l10n = AppLocalizations.of(context)!;

    final status = await Permission.photos.status;

    if (status.isGranted || status.isLimited) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n.translate('storage_permission_granted'))),
        );
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        final goToSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.translate('storage_permission')),
            content:
                Text(l10n.translate('storage_permission_denied')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.translate('go_to_settings')),
              ),
            ],
          ),
        );
        if (goToSettings == true) {
          await openAppSettings();
        }
      }
    } else {
      final result = await Permission.photos.request();
      if (mounted) {
        if (result.isGranted || result.isLimited) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(l10n.translate('storage_permission_granted'))),
          );
        } else if (result.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(l10n.translate('storage_permission_denied'))),
          );
        }
      }
    }
    _checkAllPermissions();
  }

  // ========== Build ==========

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final bool isAndroid = !kIsWeb && Platform.isAndroid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.translate('permissions')),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          _buildSection(
            children: [
              // 位置授权
              _buildMenuItem(
                icon: Icons.location_on_outlined,
                iconColor: Colors.red,
                title: l10n.translate('location_permission'),
                subtitle: l10n.translate('location_permission_desc'),
                status: _statusLabel(
                    _permissionStatuses['location'], l10n),
                statusColor: _statusColor(
                    _permissionStatuses['location']),
                onTap: _checkLocationPermission,
              ),
              const Divider(indent: 56),

              // 摄像头权限
              _buildMenuItem(
                icon: Icons.videocam_outlined,
                iconColor: Colors.purple,
                title: l10n.translate('camera_permission'),
                subtitle: l10n.translate('camera_permission_desc'),
                status: _statusLabel(
                    _permissionStatuses['camera'], l10n),
                statusColor: _statusColor(
                    _permissionStatuses['camera']),
                onTap: _checkCameraPermission,
              ),
              const Divider(indent: 56),

              // 麦克风权限
              _buildMenuItem(
                icon: Icons.mic_outlined,
                iconColor: Colors.blue,
                title: l10n.translate('microphone_permission'),
                subtitle: l10n.translate('microphone_permission_desc'),
                status: _statusLabel(
                    _permissionStatuses['microphone'], l10n),
                statusColor: _statusColor(
                    _permissionStatuses['microphone']),
                onTap: _checkMicrophonePermission,
              ),
              const Divider(indent: 56),

              // 通知权限
              _buildMenuItem(
                icon: Icons.notifications_outlined,
                iconColor: Colors.orange,
                title: l10n.translate('notification_permission'),
                subtitle: l10n.translate('notification_permission_desc'),
                status: _statusLabel(
                    _permissionStatuses['notification'], l10n),
                statusColor: _statusColor(
                    _permissionStatuses['notification']),
                onTap: _checkNotificationPermission,
              ),

              // 蓝牙权限 (仅 Android)
              if (isAndroid) ...[
                const Divider(indent: 56),
                _buildMenuItem(
                  icon: Icons.bluetooth,
                  iconColor: Colors.blueAccent,
                  title: l10n.translate('bluetooth_permission'),
                  subtitle: l10n.translate('bluetooth_permission_desc'),
                  status: _statusLabel(
                      _permissionStatuses['bluetooth'], l10n),
                  statusColor: _statusColor(
                      _permissionStatuses['bluetooth']),
                  onTap: _checkBluetoothPermission,
                ),
              ],

              // 存储/相册权限 (仅移动端)
              if (isMobile) ...[
                const Divider(indent: 56),
                _buildMenuItem(
                  icon: Icons.photo_library_outlined,
                  iconColor: Colors.teal,
                  title: l10n.translate('storage_permission'),
                  subtitle: l10n.translate('storage_permission_desc'),
                  status: _statusLabel(
                      _permissionStatuses['storage'], l10n),
                  statusColor: _statusColor(
                      _permissionStatuses['storage']),
                  onTap: _checkStoragePermission,
                ),
              ],
            ],
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSection({required List<Widget> children}) {
    return Container(
      color: AppColors.white,
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    String? status,
    Color? statusColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status != null)
            Text(
              status,
              style: TextStyle(
                color: statusColor ?? AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
      onTap: onTap,
    );
  }
}
