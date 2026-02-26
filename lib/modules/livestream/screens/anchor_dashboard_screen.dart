/// 主播数据看板
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/modules/livestream/models/livestream.dart';
import 'package:im_client/modules/livestream/providers/livestream_provider.dart';

class AnchorDashboardScreen extends StatefulWidget {
  const AnchorDashboardScreen({super.key});

  @override
  State<AnchorDashboardScreen> createState() => _AnchorDashboardScreenState();
}

class _AnchorDashboardScreenState extends State<AnchorDashboardScreen> {
  DashboardOverview? _overview;
  List<Map<String, dynamic>> _incomeData = [];
  List<Map<String, dynamic>> _topGivers = [];
  List<Map<String, dynamic>> _giftRankings = [];
  bool _loading = true;
  String _incomePeriod = 'weekly';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<LivestreamProvider>();
    final results = await Future.wait([
      provider.loadDashboardOverview(),
      provider.loadDashboardIncome(period: _incomePeriod),
      provider.loadDashboardTopGivers(),
      provider.loadDashboardGiftRankings(),
    ]);
    if (mounted) {
      setState(() {
        _overview = results[0] as DashboardOverview?;
        _incomeData = results[1] as List<Map<String, dynamic>>;
        _topGivers = results[2] as List<Map<String, dynamic>>;
        _giftRankings = results[3] as List<Map<String, dynamic>>;
        _loading = false;
      });
    }
  }

  Future<void> _loadIncome(String period) async {
    setState(() => _incomePeriod = period);
    final data = await context.read<LivestreamProvider>().loadDashboardIncome(period: period);
    if (mounted) setState(() => _incomeData = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据看板')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewCards(),
              const SizedBox(height: 24),
              _buildIncomeSection(),
              const SizedBox(height: 24),
              _buildTopGiversSection(),
              const SizedBox(height: 24),
              _buildGiftRankingsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    final o = _overview;
    if (o == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('概览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.2,
          children: [
            _statCard('总收入', '${o.totalIncome}', Icons.monetization_on, Colors.amber),
            _statCard('总观看', '${o.totalViewers}', Icons.visibility, Colors.blue),
            _statCard('直播场次', '${o.totalStreams}', Icons.live_tv, Colors.green),
            _statCard('粉丝数', '${o.followerCount}', Icons.people, Colors.pink),
            _statCard('总点赞', '${o.totalLikes}', Icons.thumb_up, Colors.red),
            _statCard('平均时长', '${o.avgDuration.toStringAsFixed(0)}s', Icons.timer, Colors.teal),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildIncomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('收入趋势', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            ToggleButtons(
              isSelected: [_incomePeriod == 'weekly', _incomePeriod == 'monthly'],
              onPressed: (i) => _loadIncome(i == 0 ? 'weekly' : 'monthly'),
              borderRadius: BorderRadius.circular(8),
              constraints: const BoxConstraints(minHeight: 30, minWidth: 48),
              textStyle: const TextStyle(fontSize: 12),
              children: const [
                Text('本周'),
                Text('本月'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_incomeData.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('暂无收入数据', style: TextStyle(color: Colors.grey)))
        else
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _incomeData.map((d) {
                final income = (d['income'] as num?)?.toDouble() ?? 0;
                final maxIncome = _incomeData.map((e) => (e['income'] as num?)?.toDouble() ?? 0).reduce((a, b) => a > b ? a : b);
                final ratio = maxIncome > 0 ? income / maxIncome : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${income.toInt()}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Container(
                          height: (ratio * 100).clamp(4, 100),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (d['date'] ?? '').toString().length >= 5 ? (d['date'] as String).substring(5) : '',
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTopGiversSection() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('top_gifters'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_topGivers.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text(l10n.translate('no_gift_data'), style: const TextStyle(color: Colors.grey)))
        else
          ...List.generate(_topGivers.length, (i) {
            final g = _topGivers[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: i < 3 ? [Colors.amber, Colors.grey, Colors.brown][i] : Colors.grey.shade300,
                child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: Text(g['nickname'] ?? '${l10n.translate('user_prefix')}${g['user_id']}'),
              trailing: Text(l10n.translate('gold_beans_value').replaceAll('{amount}', '${g['total_amount']}'), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            );
          }),
      ],
    );
  }

  Widget _buildGiftRankingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('礼物排行', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_giftRankings.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('暂无礼物数据', style: TextStyle(color: Colors.grey)))
        else
          ...List.generate(_giftRankings.length, (i) {
            final g = _giftRankings[i];
            return ListTile(
              leading: g['gift_icon'] != null && (g['gift_icon'] as String).isNotEmpty
                  ? Image.network(EnvConfig.instance.getFileUrl(g['gift_icon']), width: 32, height: 32, errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, color: Colors.amber))
                  : const Icon(Icons.card_giftcard, color: Colors.amber),
              title: Text(g['gift_name'] ?? '礼物${g['gift_id']}'),
              subtitle: Text('收到 ${g['total_count']} 次'),
              trailing: Text('${g['total_amount']} 金豆', style: const TextStyle(color: Colors.amber)),
            );
          }),
      ],
    );
  }
}
