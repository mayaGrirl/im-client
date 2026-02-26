/// 发现Tab
/// 朋友圈等功能入口

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/moment_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/providers/app_config_provider.dart';
import 'package:im_client/screens/moment/moment_list_screen.dart';
import 'package:im_client/screens/tree_hole/tree_hole_list_screen.dart';
import 'package:im_client/screens/scan/scan_screen.dart';
import 'package:im_client/screens/drift_bottle/drift_bottle_screen.dart';
import 'package:im_client/screens/nearby/nearby_screen.dart';
import 'package:im_client/modules/livestream/screens/livestream_list_screen.dart';
import 'package:im_client/modules/small_video/screens/small_video_list_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 发现Tab页
class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  final MomentApi _momentApi = MomentApi(ApiClient());

  // 最新动态用户
  MomentUser? _latestMomentUser;
  int _unreadNotifications = 0;
  bool _hasNewMoment = false;

  @override
  void initState() {
    super.initState();
    _loadLatestMoment();
    _loadNotifications();
  }

  Future<void> _loadLatestMoment() async {
    try {
      final response = await _momentApi.getMomentList(page: 1, pageSize: 1);
      if (response.success && response.data != null) {
        final list = (response.data['list'] as List?) ?? [];
        if (list.isNotEmpty) {
          final moment = Moment.fromJson(list.first);
          setState(() {
            _latestMomentUser = moment.user;
            _hasNewMoment = true;
          });
        }
      }
    } catch (e) {
      debugPrint('加载最新动态失败: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final response = await _momentApi.getNotifications(page: 1, pageSize: 1);
      if (response.success && response.data != null) {
        setState(() {
          _unreadNotifications = (response.data['unread_count'] as int?) ?? 0;
        });
      }
    } catch (e) {
      debugPrint('加载通知数失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appConfig = context.watch<AppConfigProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.discover),
      ),
      body: ListView(
        children: [
          // 朋友圈
          if (appConfig.isFeatureEnabled('feature_moment'))
          ...[const SizedBox(height: 10),
          Container(
            color: AppColors.white,
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.orange),
              ),
              title: Text(l10n.moments),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 最新动态用户头像
                  if (_latestMomentUser != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: EnvConfig.instance.getFileUrl(_latestMomentUser!.avatar),
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 32,
                              height: 32,
                              color: Colors.grey[200],
                              child: const Icon(Icons.person, size: 16),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 32,
                              height: 32,
                              color: Colors.grey[200],
                              child: const Icon(Icons.person, size: 16),
                            ),
                          ),
                        ),
                        // 新动态小红点
                        if (_hasNewMoment || _unreadNotifications > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
                ],
              ),
              onTap: () {
                setState(() {
                  _hasNewMoment = false;
                });
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MomentListScreen()),
                ).then((_) {
                  // 返回时刷新
                  _loadLatestMoment();
                  _loadNotifications();
                });
              },
            ),
          ),],
          const SizedBox(height: 10),
          // 扫一扫（单独模块）
          Container(
            color: AppColors.white,
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code_scanner, color: Colors.blue),
              ),
              title: Text(l10n.scan),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanScreen()),
                );
              },
            ),
          ),
          // 直播、小视频
          if (appConfig.isFeatureEnabled('feature_livestream') || appConfig.isFeatureEnabled('feature_small_video'))
          ...[const SizedBox(height: 10),
          Container(
            color: AppColors.white,
            child: Column(
              children: [
                if (appConfig.isFeatureEnabled('feature_livestream'))
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.live_tv, color: Colors.red),
                  ),
                  title: Text(l10n.translate('livestream')),
                  subtitle: Text(l10n.translate('livestream_subtitle'), style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LivestreamListScreen()),
                    );
                  },
                ),
                if (appConfig.isFeatureEnabled('feature_livestream') && appConfig.isFeatureEnabled('feature_small_video'))
                const Divider(indent: 56),
                if (appConfig.isFeatureEnabled('feature_small_video'))
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.pink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.video_library, color: Colors.pink),
                  ),
                  title: Text(l10n.translate('small_video')),
                  subtitle: Text(l10n.translate('small_video_subtitle'), style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SmallVideoListScreen()),
                    );
                  },
                ),
              ],
            ),
          ),],
          // 树洞、漂流瓶
          if (appConfig.isFeatureEnabled('feature_tree_hole') || appConfig.isFeatureEnabled('feature_drift_bottle'))
          ...[const SizedBox(height: 10),
          Container(
            color: AppColors.white,
            child: Column(
              children: [
                if (appConfig.isFeatureEnabled('feature_tree_hole'))
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.eco, color: Colors.teal),
                  ),
                  title: Text(l10n.translate('tree_hole')),
                  subtitle: Text(l10n.translate('tree_hole_subtitle'), style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TreeHoleListScreen()),
                    );
                  },
                ),
                if (appConfig.isFeatureEnabled('feature_tree_hole') && appConfig.isFeatureEnabled('feature_drift_bottle'))
                const Divider(indent: 56),
                if (appConfig.isFeatureEnabled('feature_drift_bottle'))
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.waves, color: Colors.cyan),
                  ),
                  title: Text(l10n.translate('drift_bottle')),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DriftBottleScreen()),
                    );
                  },
                ),
              ],
            ),
          ),],
          // 附近的人
          if (appConfig.isFeatureEnabled('feature_nearby'))
          ...[const SizedBox(height: 10),
          Container(
            color: AppColors.white,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_on, color: Colors.green),
                  ),
                  title: Text(l10n.nearby),
                  subtitle: Text(l10n.translate('nearby_subtitle'), style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NearbyScreen()),
                    );
                  },
                ),
              ],
            ),
          ),],
        ],
      ),
    );
  }
}
