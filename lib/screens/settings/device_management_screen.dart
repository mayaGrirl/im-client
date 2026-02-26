/// 登录设备管理页面
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _devices = [];
  bool _isLoading = true;
  Map<String, dynamic>? _config;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiClient.get('/device/list'),
        _apiClient.get('/device/config'),
      ]);

      if (results[0].success) {
        setState(() {
          _devices = results[0].data as List<dynamic>? ?? [];
        });
      }
      if (results[1].success) {
        setState(() {
          _config = results[1].data as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('load_fail')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logoutDevice(String deviceId, String deviceName) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('confirm_logout_device')),
        content: Text(l10n.translate('logout_device_confirm').replaceAll('{name}', deviceName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await _apiClient.delete('/device/$deviceId');
        if (res.success) {
          setState(() {
            _devices.removeWhere((d) => d['device_id'] == deviceId);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('device_logged_out'))),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res.message ?? l10n.translate('operation_failed'))),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.translate('operation_failed')}: $e')),
          );
        }
      }
    }
  }

  Future<void> _logoutAllDevices() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('confirm_logout_all')),
        content: Text(l10n.translate('logout_all_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await _apiClient.post('/device/logout-all', data: {
          'except_current': true,
        });
        if (res.success) {
          _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('all_devices_logged_out'))),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.translate('operation_failed')}: $e')),
          );
        }
      }
    }
  }

  IconData _getDeviceIcon(String? deviceType) {
    switch (deviceType?.toLowerCase()) {
      case 'ios':
        return Icons.phone_iphone;
      case 'android':
        return Icons.phone_android;
      case 'web':
        return Icons.web;
      case 'desktop':
        return Icons.desktop_windows;
      default:
        return Icons.devices;
    }
  }

  String _formatTime(String? timeStr, AppLocalizations l10n) {
    if (timeStr == null) return '';
    try {
      final time = DateTime.parse(timeStr);
      final now = DateTime.now();
      final diff = now.difference(time);

      if (diff.inMinutes < 1) return l10n.translate('just_now');
      if (diff.inHours < 1) return l10n.translate('minutes_ago_format').replaceAll('{count}', diff.inMinutes.toString());
      if (diff.inDays < 1) return l10n.translate('hours_ago_format').replaceAll('{count}', diff.inHours.toString());
      if (diff.inDays < 7) return l10n.translate('days_ago_format').replaceAll('{count}', diff.inDays.toString());
      return l10n.translate('month_day_format').replaceAll('{month}', time.month.toString()).replaceAll('{day}', time.day.toString());
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.translate('device_management')),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_devices.length > 1)
            TextButton(
              onPressed: _logoutAllDevices,
              child: Text(l10n.translate('logout_all'), style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                children: [
                  // 配置信息
                  if (_config != null) _buildConfigInfo(l10n),

                  const SizedBox(height: 10),

                  // 当前设备
                  _buildSectionHeader(l10n.translate('current_device')),
                  ..._devices
                      .where((d) => d['is_current'] == true)
                      .map((d) => _buildDeviceItem(d, l10n, isCurrent: true)),

                  const SizedBox(height: 10),

                  // 其他设备
                  if (_devices.any((d) => d['is_current'] != true)) ...[
                    _buildSectionHeader(l10n.translate('other_devices')),
                    ..._devices
                        .where((d) => d['is_current'] != true)
                        .map((d) => _buildDeviceItem(d, l10n)),
                  ],

                  // 空状态
                  if (_devices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.devices, size: 64, color: AppColors.textHint),
                            const SizedBox(height: 16),
                            Text(l10n.translate('no_devices'), style: const TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // 登录历史入口
                  _buildLoginHistoryEntry(l10n),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildConfigInfo(AppLocalizations l10n) {
    final singleDevice = _config?['single_device_login'] == true;
    final maxDevices = _config?['max_device_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              singleDevice
                  ? l10n.translate('single_device_mode')
                  : maxDevices > 0
                      ? l10n.translate('max_device_mode').replaceAll('{count}', maxDevices.toString())
                      : l10n.translate('multi_device_mode'),
              style: TextStyle(color: AppColors.primary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDeviceItem(dynamic device, AppLocalizations l10n, {bool isCurrent = false}) {
    final deviceName = device['device_name'] ?? l10n.translate('unknown_device');
    final deviceType = device['device_type'] as String?;
    final deviceModel = device['device_model'] ?? '';
    final ip = device['ip'] ?? '';
    final location = device['location'] ?? '';
    final isOnline = device['is_online'] == true;
    final lastActiveAt = device['last_active_at'] as String?;
    final deviceId = device['device_id'] as String?;

    return Container(
      color: AppColors.white,
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.primary.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getDeviceIcon(deviceType),
            color: isCurrent ? AppColors.primary : Colors.grey,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                deviceName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.translate('current_tag'),
                  style: const TextStyle(color: Colors.green, fontSize: 11),
                ),
              ),
            if (!isCurrent && isOnline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.translate('online_tag'),
                  style: const TextStyle(color: AppColors.primary, fontSize: 11),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (deviceModel.isNotEmpty)
              Text(deviceModel, style: const TextStyle(fontSize: 12)),
            Text(
              '${location.isNotEmpty ? '$location · ' : ''}${ip.isNotEmpty ? ip : ''}${lastActiveAt != null ? ' · ${_formatTime(lastActiveAt, l10n)}' : ''}',
              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ),
        trailing: isCurrent
            ? null
            : IconButton(
                icon: const Icon(Icons.logout, color: Colors.red),
                onPressed: () => _logoutDevice(deviceId ?? '', deviceName),
              ),
        isThreeLine: deviceModel.isNotEmpty,
      ),
    );
  }

  Widget _buildLoginHistoryEntry(AppLocalizations l10n) {
    return Container(
      color: AppColors.white,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.history, color: Colors.orange),
        ),
        title: Text(l10n.translate('login_history')),
        subtitle: Text(l10n.translate('view_login_history'), style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginHistoryScreen()),
          );
        },
      ),
    );
  }
}

/// 登录历史页面
class LoginHistoryScreen extends StatefulWidget {
  const LoginHistoryScreen({super.key});

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _histories = [];
  bool _isLoading = true;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.get('/device/history', queryParameters: {
        'page': _page,
        'page_size': 20,
      });

      if (res.success) {
        final data = res.data as Map<String, dynamic>?;
        final list = data?['list'] as List<dynamic>? ?? [];

        setState(() {
          if (refresh) {
            _histories = list;
          } else {
            _histories.addAll(list);
          }
          _hasMore = list.length >= 20;
          _page++;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('load_fail')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getStatusText(int? status, AppLocalizations l10n) {
    switch (status) {
      case 1:
        return l10n.translate('status_success');
      case 2:
        return l10n.translate('status_failed');
      case 3:
        return l10n.translate('status_kicked');
      case 4:
        return l10n.translate('status_expired');
      default:
        return l10n.translate('status_unknown');
    }
  }

  Color _getStatusColor(int? status) {
    switch (status) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.red;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.translate('login_history')),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading && _histories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadHistory(refresh: true),
              child: ListView.builder(
                itemCount: _histories.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _histories.length) {
                    _loadHistory();
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final item = _histories[index];
                  final status = item['status'] as int?;

                  return Container(
                    color: AppColors.white,
                    margin: const EdgeInsets.only(bottom: 1),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(status).withOpacity(0.1),
                        child: Icon(
                          status == 1 ? Icons.check : Icons.close,
                          color: _getStatusColor(status),
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(item['device_name'] ?? l10n.translate('unknown_device')),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _getStatusText(status, l10n),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '${item['location'] ?? ''} · ${item['ip'] ?? ''}\n${item['created_at'] ?? ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
    );
  }
}
