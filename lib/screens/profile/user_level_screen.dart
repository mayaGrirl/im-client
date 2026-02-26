/// 用户等级页面
/// 展示等级列表、升级规则、降级规则
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api_client.dart';
import '../../api/user_api.dart';
import '../../constants/app_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';

class UserLevelScreen extends StatefulWidget {
  const UserLevelScreen({super.key});

  @override
  State<UserLevelScreen> createState() => _UserLevelScreenState();
}

class _UserLevelScreenState extends State<UserLevelScreen> {
  late UserApi _userApi;
  List<UserLevel> _levels = [];
  bool _isLoading = true;
  int _currentLevel = 1;
  int _currentPoints = 0;

  // 等级颜色配置
  static const List<Color> _levelColors = [
    Colors.grey,       // 0 - placeholder
    Colors.brown,      // 1 - 青铜
    Colors.blueGrey,   // 2 - 白银
    Colors.amber,      // 3 - 黄金
    Colors.cyan,       // 4 - 铂金
    Colors.blue,       // 5 - 钻石
    Colors.purple,     // 6 - 星耀
    Colors.deepPurple, // 7 - 王者
    Colors.orange,     // 8 - 传说
    Colors.red,        // 9 - 荣耀
    Colors.redAccent,  // 10 - 至尊
  ];

  // 等级图标
  static const List<IconData> _levelIcons = [
    Icons.stars,           // 0
    Icons.shield,          // 1 - 青铜
    Icons.shield_moon,     // 2 - 白银
    Icons.workspace_premium, // 3 - 黄金
    Icons.military_tech,   // 4 - 铂金
    Icons.diamond,         // 5 - 钻石
    Icons.auto_awesome,    // 6 - 星耀
    Icons.emoji_events,    // 7 - 王者
    Icons.whatshot,        // 8 - 传说
    Icons.bolt,            // 9 - 荣耀
    Icons.local_fire_department, // 10 - 至尊
  ];

  @override
  void initState() {
    super.initState();
    _userApi = UserApi(ApiClient());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 获取当前用户信息
      final auth = context.read<AuthProvider>();
      _currentLevel = auth.user?.level ?? 1;
      _currentPoints = auth.user?.points ?? 0;

      // 获取所有等级配置
      final res = await _userApi.getAllLevels();
      if (res.success && res.data != null) {
        final list = res.data as List;
        _levels = list.map((e) => UserLevel.fromJson(e)).toList();
      }
    } catch (e) {
      // Load level data failed
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _getLevelColor(int level) {
    if (level >= 0 && level < _levelColors.length) {
      return _levelColors[level];
    }
    return Colors.grey;
  }

  IconData _getLevelIcon(int level) {
    if (level >= 0 && level < _levelIcons.length) {
      return _levelIcons[level];
    }
    return Icons.stars;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(l10n.levelCenter),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // 当前等级卡片
                    _buildCurrentLevelCard(l10n),
                    const SizedBox(height: 16),
                    // 升级规则
                    _buildUpgradeRules(l10n),
                    const SizedBox(height: 16),
                    // 降级规则
                    _buildDegradeRules(l10n),
                    const SizedBox(height: 16),
                    // 等级列表
                    _buildLevelList(l10n),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  /// 当前等级卡片
  Widget _buildCurrentLevelCard(AppLocalizations l10n) {
    final currentLevelConfig = _levels.isNotEmpty && _currentLevel <= _levels.length
        ? _levels[_currentLevel - 1]
        : null;
    final nextLevelConfig = _levels.isNotEmpty && _currentLevel < _levels.length
        ? _levels[_currentLevel]
        : null;

    final color = _getLevelColor(_currentLevel);
    final icon = _getLevelIcon(_currentLevel);

    // 计算升级进度
    double progress = 1.0;
    int pointsToNext = 0;
    if (nextLevelConfig != null && currentLevelConfig != null) {
      final range = nextLevelConfig.minPoints - currentLevelConfig.minPoints;
      if (range > 0) {
        progress = (_currentPoints - currentLevelConfig.minPoints) / range;
        if (progress > 1) progress = 1;
        if (progress < 0) progress = 0;
      }
      pointsToNext = nextLevelConfig.minPoints - _currentPoints;
      if (pointsToNext < 0) pointsToNext = 0;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                // 等级图标
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 20),
                // 等级信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lv.$_currentLevel ${currentLevelConfig?.name ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.currentPoints}: $_currentPoints',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (nextLevelConfig != null) ...[
              const SizedBox(height: 20),
              // 进度条
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${l10n.distanceToNext} Lv.${_currentLevel + 1} ${nextLevelConfig.name}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${l10n.pointsNeeded.replaceAll('{points}', '$pointsToNext')}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.maxLevelReached,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 等级列表
  Widget _buildLevelList(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.leaderboard, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.privilegesOverview,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 等级列表
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _levels.length,
            itemBuilder: (context, index) {
              final level = _levels[index];
              return _buildLevelCard(level, l10n);
            },
          ),
        ],
      ),
    );
  }

  /// 等级卡片（完整显示所有特权）
  Widget _buildLevelCard(UserLevel level, AppLocalizations l10n) {
    final color = _getLevelColor(level.level);
    final icon = _getLevelIcon(level.level);
    final isCurrent = level.level == _currentLevel;
    final isUnlocked = level.level <= _currentLevel;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent ? color.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? color : Colors.grey.withOpacity(0.2),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // 头部：等级名称和图标
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUnlocked ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isUnlocked ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isUnlocked ? color : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Lv.${level.level} ${level.name}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isUnlocked ? color : Colors.grey,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                l10n.currentLevel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.translate('require_points').replaceAll('{points}', '${level.minPoints}'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isUnlocked ? Colors.grey[600] : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUnlocked)
                  Icon(Icons.check_circle, color: color, size: 24)
                else
                  Icon(Icons.lock_outline, color: Colors.grey[400], size: 24),
              ],
            ),
          ),
          // 特权列表
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildPrivilegeItem(
                        Icons.monetization_on,
                        l10n.translate('daily_gold_beans'),
                        '${level.dailyGoldBeans}',
                        isUnlocked,
                      ),
                    ),
                    Expanded(
                      child: _buildPrivilegeItem(
                        Icons.people,
                        l10n.translate('friend_limit'),
                        level.maxFriends == 0 ? l10n.translate('unlimited') : l10n.translate('people_count').replaceAll('{count}', '${level.maxFriends}'),
                        isUnlocked,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPrivilegeItem(
                        Icons.group_add,
                        l10n.translate('create_groups_limit'),
                        level.maxGroups == 0 ? l10n.translate('unlimited') : l10n.translate('groups_count').replaceAll('{count}', '${level.maxGroups}'),
                        isUnlocked,
                      ),
                    ),
                    Expanded(
                      child: _buildPrivilegeItem(
                        Icons.groups,
                        l10n.translate('group_member_limit'),
                        l10n.translate('people_count').replaceAll('{count}', '${level.maxGroupMembers}'),
                        isUnlocked,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPrivilegeItem(
                        Icons.card_giftcard,
                        l10n.translate('invite_reward_multiplier'),
                        l10n.translate('times_multiplier').replaceAll('{times}', '${level.inviteRewardMultiplier}'),
                        isUnlocked,
                      ),
                    ),
                    Expanded(
                      child: _buildPrivilegeItem(
                        Icons.edit_calendar,
                        l10n.translate('checkin_reward'),
                        l10n.translate('gold_beans_count').replaceAll('{count}', '${level.checkinBaseReward}'),
                        isUnlocked,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 特权描述
          if (level.privilegeDesc.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUnlocked ? color.withOpacity(0.05) : Colors.grey.withOpacity(0.03),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
              ),
              child: Text(
                level.privilegeDesc,
                style: TextStyle(
                  fontSize: 12,
                  color: isUnlocked ? color : Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 特权项
  Widget _buildPrivilegeItem(IconData icon, String label, String value, bool isUnlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isUnlocked ? AppColors.primary.withOpacity(0.05) : Colors.grey.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isUnlocked ? AppColors.primary : Colors.grey,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isUnlocked ? Colors.grey[600] : Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? AppColors.textPrimary : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 升级规则
  Widget _buildUpgradeRules(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.trending_up, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.howToUpgrade,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRuleItem(
                  Icons.calendar_today,
                  l10n.translate('daily_checkin'),
                  l10n.translate('daily_checkin_desc'),
                  l10n.translate('daily_checkin_reward'),
                  Colors.blue,
                ),
                _buildRuleItem(
                  Icons.person_add,
                  l10n.translate('invite_friends_title'),
                  l10n.translate('invite_friends_desc'),
                  l10n.translate('invite_friends_reward'),
                  Colors.green,
                ),
                _buildRuleItem(
                  Icons.message,
                  l10n.translate('daily_active'),
                  l10n.translate('daily_active_desc'),
                  l10n.translate('daily_active_reward'),
                  Colors.orange,
                ),
                _buildRuleItem(
                  Icons.event,
                  l10n.translate('join_events'),
                  l10n.translate('join_events_desc'),
                  l10n.translate('join_events_reward'),
                  Colors.purple,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.autoUpgradeInfo,
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 降级规则
  Widget _buildDegradeRules(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.trending_down, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.downgradeRules,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.inactivityWarning,
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 降级规则表格
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // 表头
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                l10n.translate('inactive_time'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                l10n.translate('downgrade_level'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildDegradeRow(l10n.translate('days_7'), l10n.translate('downgrade_1'), false),
                      _buildDegradeRow(l10n.translate('days_14'), l10n.translate('downgrade_2'), false),
                      _buildDegradeRow(l10n.translate('days_21'), l10n.translate('downgrade_3'), false),
                      _buildDegradeRow(l10n.translate('days_30'), l10n.translate('downgrade_5'), true),
                      _buildDegradeRow(l10n.translate('days_60'), l10n.translate('downgrade_8'), true, isLast: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.warmTips,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('downgrade_tips'),
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(IconData icon, String title, String desc, String reward, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        reward,
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDegradeRow(String days, String result, bool isSevere, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: isSevere ? Colors.red : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  days,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSevere ? Colors.red[700] : Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSevere ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                result,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: isSevere ? Colors.red[700] : Colors.orange[700],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
