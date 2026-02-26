/// 新消息通知设置页面

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/services/settings_service.dart';
import 'package:im_client/services/call_ringtone_service.dart';
import 'package:im_client/services/notification_sound_service.dart';
import 'package:im_client/services/web_push_service.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/user_api.dart';
import 'package:im_client/api/upload_api.dart';
import 'package:im_client/api/call_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final UserApi _userApi = UserApi(ApiClient());
  final WebPushService _webPushService = WebPushService();

  // 铃声预览相关
  AudioPlayer? _previewPlayer;
  bool _isPlayingPreview = false;

  // Web Push状态
  NotificationPermissionStatus _webPushPermissionStatus = NotificationPermissionStatus.unsupported;
  bool _isWebPushSubscribed = false;
  bool _isWebPushLoading = false;

  @override
  void initState() {
    super.initState();
    _settingsService.addListener(_onSettingsChanged);
    _loadServerSettings();
    _loadWebPushStatus();
  }

  /// 加载Web Push状态
  Future<void> _loadWebPushStatus() async {
    if (!kIsWeb) return;

    setState(() => _isWebPushLoading = true);

    try {
      // 获取权限状态
      final status = await _webPushService.getPermissionStatus();

      // 检查是否已订阅
      final subscription = await _webPushService.getSubscription();
      final isSubscribed = subscription != null && subscription['endpoint'] != null;

      if (mounted) {
        setState(() {
          _webPushPermissionStatus = status;
          _isWebPushSubscribed = isSubscribed;
          _isWebPushLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[NotificationSettings] Load Web Push status failed: $e');
      if (mounted) {
        setState(() => _isWebPushLoading = false);
      }
    }
  }

  /// 请求Web Push权限并订阅
  Future<void> _enableWebPush() async {
    if (!kIsWeb) return;

    setState(() => _isWebPushLoading = true);

    try {
      // 请求权限
      final hasPermission = await _webPushService.requestPermission();
      if (!hasPermission) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('notification_permission_denied'))),
          );
          setState(() {
            _webPushPermissionStatus = NotificationPermissionStatus.denied;
            _isWebPushLoading = false;
          });
        }
        return;
      }

      // 从服务器获取VAPID公钥并订阅
      final response = await CallApi(ApiClient()).getVapidPublicKey();
      if (response.success && response.data != null) {
        final vapidKey = response.data['vapid_public_key'] as String?;
        if (vapidKey != null && vapidKey.isNotEmpty) {
          final endpoint = await _webPushService.subscribe(vapidKey);
          if (mounted) {
            if (endpoint != null) {
              final l10n = AppLocalizations.of(context)!;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.translate('web_push_enabled'))),
              );
              setState(() {
                _webPushPermissionStatus = NotificationPermissionStatus.granted;
                _isWebPushSubscribed = true;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[NotificationSettings] Enable Web Push failed: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('operation_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isWebPushLoading = false);
      }
    }
  }

  /// 禁用Web Push
  Future<void> _disableWebPush() async {
    if (!kIsWeb) return;

    setState(() => _isWebPushLoading = true);

    try {
      final success = await _webPushService.unsubscribe();
      if (mounted) {
        if (success) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('web_push_disabled'))),
          );
          setState(() {
            _isWebPushSubscribed = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[NotificationSettings] Disable Web Push failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isWebPushLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    _previewPlayer?.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  /// 从服务器加载通知设置
  Future<void> _loadServerSettings() async {
    try {
      final response = await _userApi.getUserSettings();
      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['notification_sound'] != null) {
          await _settingsService.setMessageSound(data['notification_sound'] == true);
        }
        if (data['notification_vibrate'] != null) {
          await _settingsService.setMessageVibrate(data['notification_vibrate'] == true);
        }
      }
    } catch (e) {
      // 静默失败
    }
  }

  /// 同步通知设置到服务器
  Future<void> _syncNotificationSettings() async {
    try {
      await _userApi.updateUserSettings(
        notificationSound: _settingsService.messageSound,
        notificationVibrate: _settingsService.messageVibrate,
      );
    } catch (e) {
      // 静默失败
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.translate('new_message_notification')),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          // 通知开关
          _buildSection(
            children: [
              _buildSwitchItem(
                icon: Icons.notifications,
                title: l10n.translate('receive_new_notification'),
                subtitle: l10n.translate('no_notification_desc'),
                value: _settingsService.messageNotification,
                onChanged: (v) => _settingsService.setMessageNotification(v),
              ),
            ],
          ),

          // Web端浏览器推送通知权限
          if (kIsWeb && _webPushService.isSupported) ...[
            const SizedBox(height: 10),
            _buildSection(
              title: l10n.translate('browser_notification'),
              children: [
                _buildWebPushPermissionItem(l10n),
              ],
            ),
          ],

          const SizedBox(height: 10),

          // 通知方式
          _buildSection(
            title: l10n.translate('notification_method'),
            children: [
              _buildSwitchItem(
                icon: Icons.volume_up,
                title: l10n.sound,
                value: _settingsService.messageSound,
                onChanged: _settingsService.messageNotification
                    ? (v) {
                        _settingsService.setMessageSound(v);
                        _syncNotificationSettings();
                      }
                    : null,
              ),
              const Divider(indent: 56),
              _buildSwitchItem(
                icon: Icons.vibration,
                title: l10n.vibrate,
                value: _settingsService.messageVibrate,
                onChanged: _settingsService.messageNotification
                    ? (v) {
                        _settingsService.setMessageVibrate(v);
                        _syncNotificationSettings();
                      }
                    : null,
              ),
            ],
          ),

          // TODO: 显示消息内容功能需要系统推送通知支持，暂时注释
          // const SizedBox(height: 10),
          // // 通知内容
          // _buildSection(
          //   title: l10n.translate('notification_content'),
          //   children: [
          //     _buildSwitchItem(
          //       icon: Icons.visibility,
          //       title: l10n.translate('show_message_content'),
          //       subtitle: l10n.translate('hide_content_desc'),
          //       value: _settingsService.showMessagePreview,
          //       onChanged: _settingsService.messageNotification
          //           ? (v) => _settingsService.setShowMessagePreview(v)
          //           : null,
          //     ),
          //   ],
          // ),

          const SizedBox(height: 10),

          // 来电铃声设置
          _buildSection(
            title: l10n.callRingtone,
            children: [
              _buildMenuItem(
                icon: Icons.ring_volume,
                title: l10n.customRingtone,
                subtitle: _getRingtoneSubtitle(l10n),
                onTap: _showRingtoneOptions,
              ),
              if (_settingsService.customRingtone != null) ...[
                const Divider(indent: 56),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isPlayingPreview ? Icons.stop : Icons.play_arrow,
                      color: Colors.blue,
                    ),
                  ),
                  title: Text(l10n.previewRingtone),
                  subtitle: Text(
                    _isPlayingPreview ? l10n.playingRingtone : l10n.translate('click_to_preview_ringtone'),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onTap: _toggleRingtonePreview,
                ),
              ],
            ],
          ),

          // 铃声格式提示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.translate('audio_format_hint'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 提示信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('notification_hint_1'),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.translate('notification_hint_2'),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.translate('notification_hint_3'),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSection({String? title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        Container(
          color: AppColors.white,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    final enabled = onChanged != null;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (enabled ? AppColors.primary : Colors.grey).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: enabled ? AppColors.primary : Colors.grey),
      ),
      title: Text(
        title,
        style: TextStyle(color: enabled ? null : AppColors.textSecondary),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }

  /// 构建Web Push权限设置项
  Widget _buildWebPushPermissionItem(AppLocalizations l10n) {
    // 获取权限状态文字和颜色
    String statusText;
    Color statusColor;
    bool canEnable = false;

    switch (_webPushPermissionStatus) {
      case NotificationPermissionStatus.granted:
        statusText = _isWebPushSubscribed
            ? l10n.translate('push_enabled')
            : l10n.translate('push_not_subscribed');
        statusColor = _isWebPushSubscribed ? Colors.green : Colors.orange;
        canEnable = !_isWebPushSubscribed;
        break;
      case NotificationPermissionStatus.denied:
        statusText = l10n.translate('push_permission_denied');
        statusColor = Colors.red;
        canEnable = false;
        break;
      case NotificationPermissionStatus.notDetermined:
        statusText = l10n.translate('push_not_enabled');
        statusColor = Colors.grey;
        canEnable = true;
        break;
      default:
        statusText = l10n.translate('push_not_supported');
        statusColor = Colors.grey;
        canEnable = false;
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _isWebPushLoading
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.notifications_active, color: AppColors.primary),
      ),
      title: Text(l10n.translate('browser_push_notification')),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(fontSize: 12, color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l10n.translate('browser_push_desc'),
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
      trailing: _isWebPushLoading
          ? null
          : (_isWebPushSubscribed
              ? TextButton(
                  onPressed: _disableWebPush,
                  child: Text(
                    l10n.translate('disable'),
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : (canEnable || _webPushPermissionStatus == NotificationPermissionStatus.granted)
                  ? TextButton(
                      onPressed: _enableWebPush,
                      child: Text(l10n.translate('enable')),
                    )
                  : (_webPushPermissionStatus == NotificationPermissionStatus.denied
                      ? TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.translate('open_browser_settings_hint')),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          },
                          child: Text(
                            l10n.translate('settings'),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : null)),
      isThreeLine: true,
    );
  }

  /// 显示铃声选项
  void _showRingtoneOptions() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(l10n.translate('select_from_files')),
              onTap: () {
                Navigator.pop(context);
                _selectRingtoneFile();
              },
            ),
            if (_settingsService.customRingtone != null)
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.orange),
                title: Text(l10n.translate('restore_default_ringtone')),
                onTap: () {
                  Navigator.pop(context);
                  _clearCustomRingtone();
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l10n.cancel),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 选择铃声文件
  Future<void> _selectRingtoneFile() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileName = file.name;

        // 检查文件大小（限制10MB）
        if ((file.size) > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('ringtone_file_too_large'))),
            );
          }
          return;
        }

        // 显示上传中提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('uploading_ringtone'))),
          );
        }

        // 上传到服务器
        final uploadApi = UploadApi(ApiClient());
        UploadResult? uploadResult;

        try {
          if (file.bytes != null) {
            print('[NotificationSettings] Uploading ringtone from bytes, size: ${file.bytes!.length}');
            uploadResult = await uploadApi.uploadAudio(file.bytes!, filename: fileName);
          } else if (file.path != null) {
            print('[NotificationSettings] Uploading ringtone from path: ${file.path}');
            uploadResult = await uploadApi.uploadAudio(file.path!, filename: fileName);
          } else {
            print('[NotificationSettings] No file bytes or path available');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.translate('select_file_fail'))),
              );
            }
            return;
          }
        } catch (uploadError) {
          print('[NotificationSettings] Upload error: $uploadError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${l10n.translate('upload_ringtone_fail')}: $uploadError')),
            );
          }
          return;
        }

        if (uploadResult == null || uploadResult.url.isEmpty) {
          print('[NotificationSettings] Upload result is null or URL is empty');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('upload_ringtone_fail'))),
            );
          }
          return;
        }

        // 获取完整URL
        final fullUrl = EnvConfig.instance.getFileUrl(uploadResult.url);

        // 保存服务器URL到设置
        await _settingsService.setCustomRingtone(fullUrl, fileName);

        // 重新加载铃声服务（来电铃声和消息通知铃声）
        await CallRingtoneService().reloadRingtone();
        await NotificationSoundService().reloadSound();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('custom_ringtone_set').replaceAll('{name}', fileName))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('select_file_fail')}: $e')),
        );
      }
    }
  }

  /// 获取铃声显示文字
  String _getRingtoneSubtitle(AppLocalizations l10n) {
    final name = _settingsService.customRingtoneName;
    final ringtone = _settingsService.customRingtone;
    if (name == null || ringtone == null) {
      return l10n.translate('default_ringtone');
    }
    return name;
  }

  /// 清除自定义铃声
  Future<void> _clearCustomRingtone() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _settingsService.clearCustomRingtone();

      // 重新加载铃声服务（来电铃声和消息通知铃声）
      await CallRingtoneService().reloadRingtone();
      await NotificationSoundService().reloadSound();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('restored_default_ringtone'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('operation_failed')}: $e')),
        );
      }
    }
  }

  /// 切换铃声预览
  void _toggleRingtonePreview() {
    if (_isPlayingPreview) {
      _stopRingtonePreview();
    } else {
      _playRingtonePreview();
    }
  }

  /// 播放铃声预览
  Future<void> _playRingtonePreview() async {
    final l10n = AppLocalizations.of(context)!;
    final ringtone = _settingsService.customRingtone;
    if (ringtone == null || ringtone.isEmpty) return;

    try {
      _previewPlayer ??= AudioPlayer();

      // 根据铃声来源加载
      if (ringtone.startsWith('http://') || ringtone.startsWith('https://')) {
        // 服务器URL
        await _previewPlayer!.setUrl(ringtone);
      } else if (!kIsWeb) {
        final file = File(ringtone);
        if (!await file.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('ringtone_file_not_exist'))),
            );
          }
          return;
        }
        await _previewPlayer!.setFilePath(ringtone);
      } else {
        // Web平台但不是URL，无法播放
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('please_reupload_ringtone'))),
          );
        }
        return;
      }

      await _previewPlayer!.play();

      setState(() {
        _isPlayingPreview = true;
      });

      // 监听播放完成
      _previewPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) {
            setState(() {
              _isPlayingPreview = false;
            });
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('play_failed')}: $e')),
        );
        setState(() {
          _isPlayingPreview = false;
        });
      }
    }
  }

  /// 停止铃声预览
  Future<void> _stopRingtonePreview() async {
    try {
      await _previewPlayer?.stop();
      if (mounted) {
        setState(() {
          _isPlayingPreview = false;
        });
      }
    } catch (e) {
      // 忽略停止错误
    }
  }
}
