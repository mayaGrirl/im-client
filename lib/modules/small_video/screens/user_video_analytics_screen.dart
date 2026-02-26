/// 用户短视频画像页面 — 抖音风格
/// 渐变头部 + 2列指标网格 + 分发层级可视化 + 兴趣标签权重条 + 参与度仪表盘

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/modules/small_video/api/small_video_api.dart';
import 'package:im_client/l10n/app_localizations.dart';

class UserVideoAnalyticsScreen extends StatefulWidget {
  final int userId;

  const UserVideoAnalyticsScreen({super.key, required this.userId});

  @override
  State<UserVideoAnalyticsScreen> createState() =>
      _UserVideoAnalyticsScreenState();
}

class _UserVideoAnalyticsScreenState extends State<UserVideoAnalyticsScreen> {
  final SmallVideoApi _api = SmallVideoApi(ApiClient());
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final response = await _api.getCreatorAnalytics(widget.userId);
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
                            _buildCreatorSection(l10n),
                            const SizedBox(height: 16),
                            _buildDistTierSection(l10n),
                            const SizedBox(height: 16),
                            _buildEngagementSection(l10n),
                            const SizedBox(height: 16),
                            _buildConsumerSection(l10n),
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
    final totalVideos = _toInt(_data!['total_videos']);
    final totalViews = _toInt(_data!['total_views']);
    final totalLikes = _toInt(_data!['total_likes']);

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF6C5CE7),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(l10n.translate('sv_va_title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE), Color(0xFFD4A5FF)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildHeroStat(_formatCount(totalVideos), l10n.translate('sv_va_total_videos')),
                  Container(width: 1, height: 36, color: Colors.white24),
                  _buildHeroStat(_formatCount(totalViews), l10n.translate('sv_va_total_views')),
                  Container(width: 1, height: 36, color: Colors.white24),
                  _buildHeroStat(_formatCount(totalLikes), l10n.translate('sv_va_total_likes')),
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

  // ==================== 创作者数据 ====================

  Widget _buildCreatorSection(AppLocalizations l10n) {
    return _buildCard(
      icon: Icons.movie_creation_rounded,
      iconColor: const Color(0xFF6C5CE7),
      title: l10n.translate('sv_va_creator_section'),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  Icons.comment_rounded,
                  const Color(0xFF0984E3),
                  _formatCount(_toInt(_data!['total_comments'])),
                  l10n.translate('sv_va_total_comments'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  Icons.share_rounded,
                  const Color(0xFF00B894),
                  _formatCount(_toInt(_data!['total_shares'])),
                  l10n.translate('sv_va_total_shares'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  Icons.bookmark_rounded,
                  const Color(0xFFFDAC53),
                  _formatCount(_toInt(_data!['total_collects'])),
                  l10n.translate('sv_va_total_collects'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  Icons.star_rounded,
                  const Color(0xFFE17055),
                  _toInt(_data!['best_video_id']) > 0
                      ? '#${_toInt(_data!['best_video_id'])}'
                      : '-',
                  l10n.translate('sv_va_best_video'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 分发层级 ====================

  Widget _buildDistTierSection(AppLocalizations l10n) {
    final breakdown = _data!['dist_tier_breakdown'];
    if (breakdown is! Map || breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final tierLabels = {
      'initial': l10n.translate('sv_va_dist_initial'),
      'second': l10n.translate('sv_va_dist_second'),
      'third': l10n.translate('sv_va_dist_third'),
      'full': l10n.translate('sv_va_dist_full'),
    };
    final tierColors = {
      'initial': const Color(0xFF95A5A6),
      'second': const Color(0xFF0984E3),
      'third': const Color(0xFFFDAC53),
      'full': const Color(0xFF00B894),
    };
    final tierIcons = {
      'initial': Icons.looks_one_rounded,
      'second': Icons.looks_two_rounded,
      'third': Icons.looks_3_rounded,
      'full': Icons.all_inclusive_rounded,
    };

    final total = breakdown.values.fold<int>(0, (sum, v) => sum + _toInt(v));
    if (total == 0) return const SizedBox.shrink();

    return _buildCard(
      icon: Icons.trending_up_rounded,
      iconColor: const Color(0xFFFDAC53),
      title: l10n.translate('sv_va_dist_breakdown'),
      child: Column(
        children: ['initial', 'second', 'third', 'full'].map((key) {
          final count = _toInt(breakdown[key]);
          final ratio = count / total;
          final color = tierColors[key]!;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(tierIcons[key], size: 18, color: color),
                    const SizedBox(width: 8),
                    Text(tierLabels[key] ?? key,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('$count',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                    Text(' (${(ratio * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: ratio.clamp(0.0, 1.0),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withValues(alpha: 0.7), color],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==================== 参与度仪表盘 ====================

  Widget _buildEngagementSection(AppLocalizations l10n) {
    final completion = _toDouble(_data!['avg_completion_rate']);
    final interact = _toDouble(_data!['avg_interact_rate']);
    final avgWatch = _toDouble(_data!['avg_watch_time']);
    final avgDwell = _toDouble(_data!['avg_dwell_time']);

    return _buildCard(
      icon: Icons.analytics_rounded,
      iconColor: const Color(0xFF00B894),
      title: l10n.translate('sv_va_engagement_section'),
      child: Column(
        children: [
          // 环形仪表盘行
          Row(
            children: [
              Expanded(
                child: _buildGaugeItem(
                  completion,
                  '${(completion * 100).toStringAsFixed(1)}%',
                  l10n.translate('sv_va_avg_completion'),
                  const Color(0xFF6C5CE7),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGaugeItem(
                  interact.clamp(0.0, 1.0),
                  '${(interact * 100).toStringAsFixed(2)}%',
                  l10n.translate('sv_va_avg_interact'),
                  const Color(0xFF00B894),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 时间指标
          Row(
            children: [
              Expanded(
                child: _buildTimeStat(
                  Icons.play_circle_outline_rounded,
                  '${avgWatch.toStringAsFixed(1)}s',
                  l10n.translate('sv_va_avg_watch_time'),
                  const Color(0xFF0984E3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeStat(
                  Icons.hourglass_bottom_rounded,
                  '${avgDwell.toStringAsFixed(1)}s',
                  l10n.translate('sv_va_avg_dwell_time'),
                  const Color(0xFFE17055),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeItem(
      double ratio, String value, String label, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CustomPaint(
            painter: _GaugePainter(ratio: ratio.clamp(0.0, 1.0), color: color),
            child: Center(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildTimeStat(
      IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0.02)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold, color: color)),
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

  // ==================== 消费画像 ====================

  Widget _buildConsumerSection(AppLocalizations l10n) {
    final interests = _data!['top_interests'];
    final interestList = interests is List
        ? interests.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    return _buildCard(
      icon: Icons.person_search_rounded,
      iconColor: const Color(0xFF0984E3),
      title: l10n.translate('sv_va_consumer_section'),
      child: Column(
        children: [
          // 消费统计
          Row(
            children: [
              Expanded(
                child: _buildCountStat(
                  Icons.play_arrow_rounded,
                  _formatCount(_toInt(_data!['total_watched'])),
                  l10n.translate('sv_va_watched_count'),
                  const Color(0xFF6C5CE7),
                ),
              ),
              Expanded(
                child: _buildCountStat(
                  Icons.favorite_rounded,
                  _formatCount(_toInt(_data!['total_likes_given'])),
                  l10n.translate('sv_va_likes_given'),
                  const Color(0xFFFF2D55),
                ),
              ),
              Expanded(
                child: _buildCountStat(
                  Icons.chat_bubble_rounded,
                  _formatCount(_toInt(_data!['total_comments_given'])),
                  l10n.translate('sv_va_comments_given'),
                  const Color(0xFF00B894),
                ),
              ),
            ],
          ),

          // 兴趣标签
          if (interestList.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(
                  color: const Color(0xFF0984E3),
                  borderRadius: BorderRadius.circular(2),
                )),
                const SizedBox(width: 8),
                Text(l10n.translate('sv_va_interests'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ...interestList.asMap().entries.map((entry) {
              return _buildInterestBar(entry.value, entry.key, interestList.length, l10n);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCountStat(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildInterestBar(
      Map<String, dynamic> interest, int index, int total, AppLocalizations l10n) {
    final weight = _toDouble(interest['weight']);
    final maxWeight = 100.0;
    final ratio = (weight / maxWeight).clamp(0.0, 1.0);
    final tagName = interest['tag_name']?.toString() ?? '#${interest['tag_id']}';

    // 渐变色列表
    final colors = [
      const Color(0xFFFF2D55),
      const Color(0xFF6C5CE7),
      const Color(0xFF0984E3),
      const Color(0xFF00B894),
      const Color(0xFFFDAC53),
      const Color(0xFFE17055),
    ];
    final color = colors[index % colors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text('${index + 1}',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(tagName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.6), color],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(weight.toStringAsFixed(0),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: color),
                textAlign: TextAlign.right),
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
            color: Colors.black.withValues(alpha: 0.04),
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
                    color: iconColor.withValues(alpha: 0.1),
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
        color: color.withValues(alpha: 0.06),
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
}

// ==================== 参与度环形仪表盘绘制器 ====================

class _GaugePainter extends CustomPainter {
  final double ratio;
  final Color color;

  _GaugePainter({required this.ratio, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;
    const startAngle = -pi / 2;

    // 背景环
    final bgPaint = Paint()
      ..color = const Color(0xFFF0F0F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // 进度环
    if (ratio > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * pi * ratio,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
