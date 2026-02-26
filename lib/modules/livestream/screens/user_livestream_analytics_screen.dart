/// 用户直播画像页面 �?抖音风格
/// 渐变头部 + 2列网格指标卡 + PK胜率环形�?+ 段位进度�?

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/modules/livestream/api/livestream_api.dart';
import 'package:im_client/l10n/app_localizations.dart';

class UserLivestreamAnalyticsScreen extends StatefulWidget {
  final int userId;

  const UserLivestreamAnalyticsScreen({super.key, required this.userId});

  @override
  State<UserLivestreamAnalyticsScreen> createState() =>
      _UserLivestreamAnalyticsScreenState();
}

class _UserLivestreamAnalyticsScreenState
    extends State<UserLivestreamAnalyticsScreen> {
  final LivestreamApi _api = LivestreamApi(ApiClient());
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final response = await _api.getUserLivestreamAnalytics(widget.userId);
      if (response.success && response.data != null) {
        setState(() {
          _data = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : {};
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return 0;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return 0.0;
  }

  String _formatDuration(double seconds) {
    final l10n = AppLocalizations.of(context)!;
    if (seconds >= 3600) {
      return '${(seconds / 3600).toStringAsFixed(1)}${l10n.translate('sv_la_hours')}';
    }
    return '${(seconds / 60).toStringAsFixed(0)}${l10n.translate('sv_la_minutes')}';
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? Center(child: Text(l10n.translate('sv_la_no_data')))
              : CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(l10n),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          children: [
                            _buildAnchorSection(l10n),
                            const SizedBox(height: 16),
                            _buildViewerSection(l10n),
                            const SizedBox(height: 16),
                            _buildPKSection(l10n),
                            const SizedBox(height: 16),
                            _buildPaidSection(l10n),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ==================== 渐变头部 ====================

  Widget _buildSliverAppBar(AppLocalizations l10n) {
    final anchor = _data!['anchor'];
    final totalStreams = anchor != null ? _toInt(anchor['total_streams']) : 0;
    final giftIncome = anchor != null ? _toInt(anchor['gift_income']) : 0;
    final qualityTier = anchor != null ? _toInt(anchor['quality_tier']) : 0;

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFFFF2D55),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(l10n.translate('sv_la_title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF2D55), Color(0xFFFF6B81), Color(0xFFFF8F9E)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildHeroStat(_formatCount(totalStreams), l10n.translate('sv_la_total_streams')),
                  Container(width: 1, height: 36, color: Colors.white24),
                  _buildHeroStat(_formatCount(giftIncome), l10n.translate('sv_la_gift_income')),
                  Container(width: 1, height: 36, color: Colors.white24),
                  _buildHeroStat('T$qualityTier', l10n.translate('sv_la_quality_tier')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  // ==================== 主播数据 ====================

  Widget _buildAnchorSection(AppLocalizations l10n) {
    final anchor = _data!['anchor'];
    if (anchor == null) return _buildEmptySection(l10n.translate('sv_la_anchor_section'), l10n);

    return _buildCard(
      icon: Icons.live_tv_rounded,
      iconColor: const Color(0xFFFF2D55),
      title: l10n.translate('sv_la_anchor_section'),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  Icons.visibility_rounded,
                  const Color(0xFF6C5CE7),
                  _toDouble(anchor['avg_heat_score']).toStringAsFixed(1),
                  l10n.translate('sv_la_avg_heat'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  Icons.people_rounded,
                  const Color(0xFF00B894),
                  _toDouble(anchor['avg_viewer_count']).toStringAsFixed(0),
                  l10n.translate('sv_la_avg_viewers'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  Icons.timer_rounded,
                  const Color(0xFF0984E3),
                  _formatDuration(_toDouble(anchor['avg_duration'])),
                  l10n.translate('sv_la_avg_duration'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  Icons.card_giftcard_rounded,
                  const Color(0xFFE17055),
                  _formatCount(_toInt(anchor['gift_income'])),
                  l10n.translate('sv_la_gift_income'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 观众数据 ====================

  Widget _buildViewerSection(AppLocalizations l10n) {
    final viewer = _data!['viewer'];
    if (viewer == null) return _buildEmptySection(l10n.translate('sv_la_viewer_section'), l10n);

    return _buildCard(
      icon: Icons.remove_red_eye_rounded,
      iconColor: const Color(0xFF6C5CE7),
      title: l10n.translate('sv_la_viewer_section'),
      child: Column(
        children: [
          _buildStatRow(
            Icons.meeting_room_rounded,
            l10n.translate('sv_la_watched_rooms'),
            '${_toInt(viewer['total_watched_rooms'])}',
            const Color(0xFF6C5CE7),
          ),
          _buildDivider(),
          _buildStatRow(
            Icons.access_time_rounded,
            l10n.translate('sv_la_watch_time'),
            _formatDuration(_toDouble(viewer['total_watch_time'])),
            const Color(0xFF0984E3),
          ),
          _buildDivider(),
          _buildStatRow(
            Icons.card_giftcard_rounded,
            l10n.translate('sv_la_gifts_sent'),
            '${_toInt(viewer['gifts_sent'])}',
            const Color(0xFFE17055),
          ),
          _buildDivider(),
          _buildStatRow(
            Icons.monetization_on_rounded,
            l10n.translate('sv_la_gifts_amount'),
            '${_formatCount(_toInt(viewer['gifts_amount']))} ${l10n.translate('sv_la_gold_beans')}',
            const Color(0xFFFDAC53),
          ),
        ],
      ),
    );
  }

  // ==================== PK战绩 ====================

  Widget _buildPKSection(AppLocalizations l10n) {
    final pk = _data!['pk'];
    if (pk == null) return _buildEmptySection(l10n.translate('sv_la_pk_section'), l10n);

    final wins = _toInt(pk['wins']);
    final losses = _toInt(pk['losses']);
    final draws = _toInt(pk['draws']);
    final total = _toInt(pk['total_pks']);
    final winRate = total > 0 ? wins / total : 0.0;
    final points = _toInt(pk['points']);
    final winStreak = _toInt(pk['win_streak']);

    return _buildCard(
      icon: Icons.flash_on_rounded,
      iconColor: const Color(0xFFFDAC53),
      title: l10n.translate('sv_la_pk_section'),
      child: Column(
        children: [
          // 胜率环形�?
          SizedBox(
            height: 130,
            child: Row(
              children: [
                // 环形�?
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CustomPaint(
                    painter: _PKRingPainter(
                      winRate: winRate,
                      wins: wins,
                      losses: losses,
                      draws: draws,
                      total: total,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(winRate * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          Text(l10n.translate('sv_la_wins'),
                              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // 胜负统计
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPKStatRow(l10n.translate('sv_la_total_pks'), '$total', Colors.grey[700]!),
                      const SizedBox(height: 8),
                      _buildPKStatRow(l10n.translate('sv_la_wins'), '$wins', const Color(0xFF00B894)),
                      const SizedBox(height: 8),
                      _buildPKStatRow(l10n.translate('sv_la_losses'), '$losses', const Color(0xFFFF2D55)),
                      const SizedBox(height: 8),
                      _buildPKStatRow(l10n.translate('sv_la_draws'), '$draws', const Color(0xFFFDAC53)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 积分和连�?
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text('$points',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100))),
                      const SizedBox(height: 2),
                      Text(l10n.translate('sv_la_points'),
                          style: const TextStyle(fontSize: 11, color: Color(0xFFE65100))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text('$winStreak',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32))),
                      const SizedBox(height: 2),
                      Text(l10n.translate('sv_la_win_streak'),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPKStatRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ==================== 付费通话 ====================

  Widget _buildPaidSection(AppLocalizations l10n) {
    final paid = _data!['paid_session'];
    if (paid == null) return _buildEmptySection(l10n.translate('sv_la_paid_section'), l10n);

    return _buildCard(
      icon: Icons.phone_in_talk_rounded,
      iconColor: const Color(0xFF00B894),
      title: l10n.translate('sv_la_paid_section'),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  Icons.headset_mic_rounded,
                  const Color(0xFFFF2D55),
                  '${_toInt(paid['anchor_session_count'])}',
                  l10n.translate('sv_la_anchor_sessions'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  Icons.account_balance_wallet_rounded,
                  const Color(0xFFFDAC53),
                  _formatCount(_toInt(paid['anchor_income'])),
                  l10n.translate('sv_la_anchor_income'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  Icons.phone_rounded,
                  const Color(0xFF6C5CE7),
                  '${_toInt(paid['viewer_session_count'])}',
                  l10n.translate('sv_la_viewer_sessions'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  Icons.payments_rounded,
                  const Color(0xFF0984E3),
                  _formatCount(_toInt(paid['viewer_spend'])),
                  l10n.translate('sv_la_viewer_spend'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 通用组件 ====================

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
      IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
      IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey[100]);
  }

  Widget _buildEmptySection(String title, AppLocalizations l10n) {
    return _buildCard(
      icon: Icons.info_outline_rounded,
      iconColor: Colors.grey,
      title: title,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(Icons.inbox_rounded, size: 36, color: Colors.grey[300]),
              const SizedBox(height: 8),
              Text(l10n.translate('sv_la_no_data'),
                  style: TextStyle(fontSize: 13, color: Colors.grey[400])),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== PK胜率环形图绘制器 ====================

class _PKRingPainter extends CustomPainter {
  final double winRate;
  final int wins;
  final int losses;
  final int draws;
  final int total;

  _PKRingPainter({
    required this.winRate,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;

    // 背景�?
    final bgPaint = Paint()
      ..color = const Color(0xFFF0F0F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (total == 0) return;

    const startAngle = -pi / 2;
    final winAngle = 2 * pi * (wins / total);
    final lossAngle = 2 * pi * (losses / total);
    final drawAngle = 2 * pi * (draws / total);

    // �?- 绿色
    if (wins > 0) {
      final winPaint = Paint()
        ..color = const Color(0xFF00B894)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        winAngle,
        false,
        winPaint,
      );
    }

    // �?- 红色
    if (losses > 0) {
      final lossPaint = Paint()
        ..color = const Color(0xFFFF2D55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + winAngle,
        lossAngle,
        false,
        lossPaint,
      );
    }

    // �?- 黄色
    if (draws > 0) {
      final drawPaint = Paint()
        ..color = const Color(0xFFFDAC53)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + winAngle + lossAngle,
        drawAngle,
        false,
        drawPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
