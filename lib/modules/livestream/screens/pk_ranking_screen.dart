/// PK排行榜页面 - 抖音风格
/// 领奖台Top3 + 排名列表 + 对战历史 + 个人战绩卡
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/modules/livestream/api/livestream_api.dart';
import 'package:im_client/modules/livestream/models/livestream.dart';
import 'package:im_client/providers/auth_provider.dart';
import '../../../utils/image_proxy.dart';

class PKRankingScreen extends StatefulWidget {
  const PKRankingScreen({super.key});

  @override
  State<PKRankingScreen> createState() => _PKRankingScreenState();
}

class _PKRankingScreenState extends State<PKRankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = LivestreamApi(ApiClient());

  final Map<String, List<PKRanking>> _rankings = {
    'points': [],
    'season': [],
    'streak': [],
  };
  final Map<String, bool> _loading = {
    'points': true,
    'season': true,
    'streak': true,
  };

  PKRanking? _myStats;
  int _currentUserId = 0;

  List<Map<String, dynamic>> _history = [];
  bool _historyLoading = true;
  int _historyPage = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentUserId = context.read<AuthProvider>().userId ?? 0;
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadRankings('points'),
      _loadRankings('season'),
      _loadRankings('streak'),
      _loadMyStats(),
      _loadHistory(),
    ]);
  }

  Future<void> _loadRankings(String type) async {
    final resp = await _api.getPKRankings(type: type, page: 1, pageSize: 50);
    if (mounted) {
      setState(() {
        _loading[type] = false;
        if (resp.success) {
          final list = resp.data?['list'] as List<dynamic>? ?? [];
          _rankings[type] =
              list.map((e) => PKRanking.fromJson(e as Map<String, dynamic>)).toList();
        }
      });
    }
  }

  Future<void> _loadMyStats() async {
    final resp = await _api.getMyPKStats();
    if (mounted && resp.success && resp.data != null) {
      setState(() => _myStats = PKRanking.fromJson(resp.data!));
    }
  }

  Future<void> _loadHistory() async {
    final resp = await _api.getPKHistory(page: _historyPage);
    if (mounted) {
      setState(() {
        _historyLoading = false;
        if (resp.success) {
          final list = resp.data?['list'] as List<dynamic>? ?? [];
          _history = list.map((e) => e as Map<String, dynamic>).toList();
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fullAvatar(String? url) {
    if (url == null || url.isEmpty) return '';
    // dicebear SVG 转 PNG（Flutter Image 不支持 SVG）
    if (url.contains('dicebear.com') && url.contains('/svg?')) {
      url = url.replaceFirst('/svg?', '/png?');
    }
    if (url.startsWith('http')) return url;
    return EnvConfig.instance.getFileUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(l10n),
          if (_myStats != null)
            SliverToBoxAdapter(child: _buildMyStatsCard(l10n)),
        ],
        body: Column(
          children: [
            _buildTabBar(l10n),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRankingTab('points', l10n),
                  _buildRankingTab('season', l10n),
                  _buildRankingTab('streak', l10n),
                  _buildHistoryTab(l10n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== AppBar ====================

  Widget _buildSliverAppBar(AppLocalizations? l10n) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFF0D0D14),
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(l10n?.pkRankings ?? 'PK Rankings',
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white70),
          onPressed: () => _showRulesDialog(l10n),
        ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1030), Color(0xFF0D0D14)],
          ),
        ),
      ),
    );
  }

  void _showRulesDialog(AppLocalizations? l10n) async {
    try {
      final resp = await _api.getPKRules();
      if (!mounted) return;

      final data = resp.data ?? {};
      final threshold = data['score_threshold'] ?? 100000;
      final winPts = data['win_points'] ?? 30;
      final losePts = data['lose_points'] ?? 10;
      final drawPts = data['draw_points'] ?? 20;
      final duration = data['duration'] ?? 180;
      final punish = data['punish_seconds'] ?? 60;

      String fmt(String template, dynamic value) =>
          template.replaceAll('{0}', value.toString());

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1A1030),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  l10n?.pkRules ?? 'PK Rules',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              _ruleItem(Icons.monetization_on, Colors.amber,
                  fmt(l10n?.pkRulesScoreThreshold ?? 'Gift value must reach {0} gold beans to earn points', threshold)),
              _ruleItem(Icons.emoji_events, Colors.greenAccent,
                  fmt(l10n?.pkRulesWinPoints ?? 'Win: +{0} points', winPts)),
              _ruleItem(Icons.sentiment_dissatisfied, Colors.redAccent,
                  fmt(l10n?.pkRulesLosePoints ?? 'Lose: +{0} points', losePts)),
              _ruleItem(Icons.handshake, Colors.orangeAccent,
                  fmt(l10n?.pkRulesDrawPoints ?? 'Draw: +{0} points', drawPts)),
              _ruleItem(Icons.timer, Colors.cyanAccent,
                  fmt(l10n?.pkRulesDuration ?? 'PK Duration: {0} seconds', duration)),
              _ruleItem(Icons.warning_amber, Colors.pinkAccent,
                  fmt(l10n?.pkRulesPunish ?? 'Loser punishment: {0} seconds', punish)),
              const Divider(color: Colors.white12, height: 24),
              _ruleItem(Icons.leaderboard, Colors.purpleAccent,
                  l10n?.pkRulesRankingDesc ?? 'Rankings show total points from all qualified PK battles'),
              _ruleItem(Icons.people, Colors.tealAccent,
                  l10n?.pkRulesIndependent ?? "Each player's gift value is evaluated independently"),
            ],
          ),
        ),
      );
    } catch (_) {
      // silently fail
    }
  }

  Widget _ruleItem(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ==================== 个人战绩卡 ====================

  Widget _buildMyStatsCard(AppLocalizations? l10n) {
    final s = _myStats!;
    final total = s.wins + s.losses + s.draws;
    final winRate = total > 0 ? s.wins / total : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B69), Color(0xFF1A1030)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.amber, size: 18),
              ),
              const SizedBox(width: 10),
              Text(l10n?.pkMyStats ?? 'My Stats',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              // Win rate badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD700).withOpacity(0.3),
                      const Color(0xFFFF8C00).withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(winRate * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              _buildMyStatCell(
                Icons.flash_on_rounded,
                const Color(0xFFFFD700),
                '${s.points}',
                l10n?.pkTotalPoints ?? 'Points',
              ),
              _buildMyStatDivider(),
              _buildMyStatCell(
                Icons.emoji_events_rounded,
                const Color(0xFF00E676),
                '${s.wins}',
                l10n?.pkWins ?? 'Wins',
              ),
              _buildMyStatDivider(),
              _buildMyStatCell(
                Icons.close_rounded,
                const Color(0xFFFF5252),
                '${s.losses}',
                l10n?.pkLosses ?? 'Losses',
              ),
              _buildMyStatDivider(),
              _buildMyStatCell(
                Icons.local_fire_department_rounded,
                const Color(0xFF40C4FF),
                '${s.maxWinStreak}',
                l10n?.pkStreak ?? 'Streak',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyStatCell(IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildMyStatDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withOpacity(0.08),
    );
  }

  // ==================== TabBar ====================

  Widget _buildTabBar(AppLocalizations? l10n) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E2E), width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFFFD700),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        tabs: [
          Tab(text: l10n?.pkTotalPoints ?? 'Points'),
          Tab(text: l10n?.pkSeasonRankings ?? 'Season'),
          Tab(text: l10n?.pkStreakRanking ?? 'Streak'),
          Tab(text: l10n?.pkHistoryTab ?? 'History'),
        ],
      ),
    );
  }

  // ==================== 排名Tab (含领奖台) ====================

  Widget _buildRankingTab(String type, AppLocalizations? l10n) {
    if (_loading[type] == true) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }

    final list = _rankings[type] ?? [];
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.leaderboard_rounded, size: 48, color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 12),
            Text(l10n?.noData ?? 'No data',
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadRankings(type),
      color: const Color(0xFFFFD700),
      child: CustomScrollView(
        slivers: [
          // 领奖台 Top 3
          if (list.length >= 3)
            SliverToBoxAdapter(child: _buildPodium(list, type)),
          // 排名列表 (从第4名开始)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final startIndex = list.length >= 3 ? 3 : 0;
                  final rank = startIndex + i + 1;
                  if (startIndex + i >= list.length) return null;
                  return _buildRankingItem(list[startIndex + i], rank, type);
                },
                childCount: list.length >= 3 ? list.length - 3 : list.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // ==================== 领奖台 ====================

  Widget _buildPodium(List<PKRanking> list, String type) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1030), Color(0xFF0D0D14)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          Expanded(child: _buildPodiumItem(list[1], 2, type, 90)),
          const SizedBox(width: 8),
          // 1st place
          Expanded(child: _buildPodiumItem(list[0], 1, type, 110)),
          const SizedBox(width: 8),
          // 3rd place
          Expanded(child: _buildPodiumItem(list[2], 3, type, 70)),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(PKRanking ranking, int rank, String type, double pedestalHeight) {
    final avatar = _fullAvatar(ranking.avatar);
    final value = _getRankingValue(ranking, type);
    final crownColors = {
      1: const Color(0xFFFFD700),
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32),
    };
    final color = crownColors[rank]!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown icon for 1st
        if (rank == 1)
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
            ).createShader(bounds),
            child: const Icon(Icons.emoji_events_rounded, size: 32, color: Colors.white),
          ),
        if (rank != 1) const SizedBox(height: 32),
        const SizedBox(height: 4),

        // Avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, spreadRadius: 1),
            ],
          ),
          child: CircleAvatar(
            radius: rank == 1 ? 32 : 26,
            backgroundColor: const Color(0xFF1E1E2E),
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar.proxied) : null,
            child: avatar.isEmpty
                ? Icon(Icons.person, size: rank == 1 ? 28 : 22, color: Colors.white38)
                : null,
          ),
        ),
        const SizedBox(height: 8),

        // Nickname
        Text(
          ranking.nickname ?? 'User',
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 4),

        // Value
        Text(
          value,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Pedestal
        Container(
          width: double.infinity,
          height: pedestalHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.25),
                color.withOpacity(0.05),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                color: color.withOpacity(0.6),
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getRankingValue(PKRanking ranking, String type) {
    switch (type) {
      case 'season':
        return '${ranking.seasonPoints}';
      case 'streak':
        return '${ranking.maxWinStreak}';
      default:
        return '${ranking.points}';
    }
  }

  String _getRankingSubtitle(PKRanking ranking, String type, AppLocalizations? l10n) {
    switch (type) {
      case 'season':
        return '${ranking.seasonWins}${l10n?.pkWin ?? 'W'}';
      case 'streak':
        return '${ranking.winStreak} ${l10n?.pkInProgress ?? 'current'}';
      default:
        return '${ranking.wins}W ${ranking.losses}L ${ranking.draws}D';
    }
  }

  // ==================== 排名列表项 ====================

  Widget _buildRankingItem(PKRanking ranking, int rank, String type) {
    final avatar = _fullAvatar(ranking.avatar);
    final value = _getRankingValue(ranking, type);
    final subtitle = _getRankingSubtitle(ranking, type, AppLocalizations.of(context));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF1E1E2E),
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar.proxied) : null,
            child: avatar.isEmpty
                ? const Icon(Icons.person, size: 18, color: Colors.white38)
                : null,
          ),
          const SizedBox(width: 12),
          // Name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ranking.nickname ?? 'User ${ranking.userId}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35), fontSize: 12)),
              ],
            ),
          ),
          // Value
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: const TextStyle(
                  color: Color(0xFFA29BFE), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 历史记录Tab ====================

  Widget _buildHistoryTab(AppLocalizations? l10n) {
    if (_historyLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 12),
            Text(l10n?.noData ?? 'No data',
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _historyPage = 1;
        _historyLoading = true;
        await _loadHistory();
      },
      color: const Color(0xFFFFD700),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _history.length,
        itemBuilder: (_, i) => _buildHistoryItem(_history[i], l10n),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> pk, AppLocalizations? l10n) {
    final userIdA = (pk['user_id_a'] as num?)?.toInt() ?? 0;
    final userIdB = (pk['user_id_b'] as num?)?.toInt() ?? 0;

    // 当前用户显示在左侧：如果当前用户是B，交换A/B数据
    final isSwapped = _currentUserId > 0 && userIdB == _currentUserId && userIdA != _currentUserId;
    final nicknameLeft = isSwapped ? (pk['nickname_b'] as String? ?? 'B') : (pk['nickname_a'] as String? ?? 'A');
    final nicknameRight = isSwapped ? (pk['nickname_a'] as String? ?? 'A') : (pk['nickname_b'] as String? ?? 'B');
    final avatarLeft = _fullAvatar(isSwapped ? pk['avatar_b'] as String? : pk['avatar_a'] as String?);
    final avatarRight = _fullAvatar(isSwapped ? pk['avatar_a'] as String? : pk['avatar_b'] as String?);
    final scoreLeft = (isSwapped ? (pk['score_b'] as num?) : (pk['score_a'] as num?))?.toInt() ?? 0;
    final scoreRight = (isSwapped ? (pk['score_a'] as num?) : (pk['score_b'] as num?))?.toInt() ?? 0;

    final myResult = (pk['my_result'] as num?)?.toInt() ?? 0;
    final endedAt = pk['ended_at'] as String? ?? '';

    // 左侧（当前用户侧）分数高亮：赢绿，输灰
    final leftScoreColor = myResult == 1 ? const Color(0xFF00E676) : Colors.white70;
    final rightScoreColor = myResult == 2 ? const Color(0xFF00E676) : Colors.white70;

    String resultLabel;
    Color resultColor;
    IconData resultIcon;
    switch (myResult) {
      case 1:
        resultLabel = l10n?.pkWin ?? 'WIN';
        resultColor = const Color(0xFF00E676);
        resultIcon = Icons.emoji_events_rounded;
        break;
      case 2:
        resultLabel = l10n?.pkLose ?? 'LOSE';
        resultColor = const Color(0xFFFF5252);
        resultIcon = Icons.close_rounded;
        break;
      default:
        resultLabel = l10n?.pkDraw ?? 'DRAW';
        resultColor = const Color(0xFFFFC107);
        resultIcon = Icons.handshake_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: resultColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // VS Row
          Row(
            children: [
              // Left player (current user when applicable)
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF1E1E2E),
                      backgroundImage: avatarLeft.isNotEmpty ? NetworkImage(avatarLeft.proxied) : null,
                      child: avatarLeft.isEmpty
                          ? const Icon(Icons.person, size: 16, color: Colors.white38)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(nicknameLeft,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),

              // Score + VS
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$scoreLeft',
                        style: TextStyle(
                            color: leftScoreColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('VS',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                    ),
                    Text('$scoreRight',
                        style: TextStyle(
                            color: rightScoreColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              // Right player (opponent)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(nicknameRight,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF1E1E2E),
                      backgroundImage: avatarRight.isNotEmpty ? NetworkImage(avatarRight.proxied) : null,
                      child: avatarRight.isEmpty
                          ? const Icon(Icons.person, size: 16, color: Colors.white38)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          // Bottom: result badge + time
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: resultColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(resultIcon, size: 14, color: resultColor),
                    const SizedBox(width: 4),
                    Text(resultLabel,
                        style: TextStyle(
                            color: resultColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Spacer(),
              if (endedAt.isNotEmpty)
                Text(
                  endedAt.length >= 16 ? endedAt.substring(0, 16) : endedAt,
                  style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
