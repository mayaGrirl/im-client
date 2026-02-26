/// 签到页面
/// 展示签到日历、连续签到天数、签到奖励
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/user_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final UserApi _userApi = UserApi(ApiClient());

  bool _isLoading = true;
  bool _isCheckinLoading = false;
  bool _checkedInToday = false;
  int _continuousDays = 0;
  int _totalDays = 0;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  List<CheckinRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadCheckinData();
  }

  Future<void> _loadCheckinData() async {
    setState(() => _isLoading = true);
    try {
      final response = await _userApi.getCheckinCalendar();
      if (response.success && response.data != null) {
        final data = response.data;
        setState(() {
          _year = data['year'] ?? DateTime.now().year;
          _month = data['month'] ?? DateTime.now().month;
          _checkedInToday = data['checked_in_today'] ?? false;
          _continuousDays = data['continuous_days'] ?? 0;
          _totalDays = data['total_days'] ?? 0;
          final recordsList = data['records'] as List? ?? [];
          _records = recordsList.map((e) => CheckinRecord.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Load checkin data error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _doCheckin() async {
    if (_checkedInToday || _isCheckinLoading) return;

    setState(() => _isCheckinLoading = true);
    try {
      final response = await _userApi.dailyCheckin();
      if (response.success && response.data != null) {
        final data = response.data;
        final goldBeanReward = data['gold_bean_reward'] ?? 0;
        final pointsReward = data['points_reward'] ?? 0;
        final continuousDays = data['continuous_days'] ?? 1;

        setState(() {
          _checkedInToday = true;
          _continuousDays = continuousDays;
          _totalDays++;
        });

        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          _showCheckinSuccessDialog(l10n, goldBeanReward, pointsReward, continuousDays);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message ?? 'Checkin failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isCheckinLoading = false);
    }
  }

  void _showCheckinSuccessDialog(AppLocalizations l10n, int goldBeans, int points, int days) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              l10n.translate('checkin_success'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('continuous_checkin_days').replaceAll('{days}', '$days'),
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRewardItem(Icons.monetization_on, '+$goldBeans', l10n.goldBeans, Colors.orange),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _buildRewardItem(Icons.stars, '+$points', l10n.translate('points'), Colors.blue),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(l10n.translate('daily_checkin')),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCheckinData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeaderCard(l10n),
                    const SizedBox(height: 16),
                    _buildCalendarCard(l10n),
                    const SizedBox(height: 16),
                    _buildRewardRulesCard(l10n),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(l10n.translate('continuous_days'), '$_continuousDays', l10n.translate('days_unit')),
                  Container(width: 1, height: 50, color: Colors.white24),
                  _buildStatItem(l10n.translate('total_checkin_days'), '$_totalDays', l10n.translate('days_unit')),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _checkedInToday ? null : _doCheckin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange,
                    disabledBackgroundColor: Colors.white.withOpacity(0.5),
                    disabledForegroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: _isCheckinLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _checkedInToday
                              ? l10n.translate('already_checked_in')
                              : l10n.translate('checkin_now'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarCard(AppLocalizations l10n) {
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final firstDayWeekday = DateTime(_year, _month, 1).weekday;
    final checkedDays = _records.map((r) => int.tryParse(r.checkinDate.split('-').last) ?? 0).toSet();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '$_year${l10n.translate('year')}$_month${l10n.translate('month')}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    l10n.translate('week_sun'),
                    l10n.translate('week_mon'),
                    l10n.translate('week_tue'),
                    l10n.translate('week_wed'),
                    l10n.translate('week_thu'),
                    l10n.translate('week_fri'),
                    l10n.translate('week_sat'),
                  ].map((day) => SizedBox(
                    width: 36,
                    child: Text(day, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  )).toList(),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                  itemCount: (firstDayWeekday % 7) + daysInMonth,
                  itemBuilder: (context, index) {
                    final dayOffset = firstDayWeekday % 7;
                    if (index < dayOffset) return const SizedBox();
                    final day = index - dayOffset + 1;
                    final isChecked = checkedDays.contains(day);
                    final isToday = day == DateTime.now().day && _month == DateTime.now().month && _year == DateTime.now().year;

                    return Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isChecked ? Colors.orange : (isToday ? Colors.orange.withOpacity(0.1) : null),
                        shape: BoxShape.circle,
                        border: isToday && !isChecked ? Border.all(color: Colors.orange, width: 1.5) : null,
                      ),
                      child: Center(
                        child: isChecked
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : Text(
                                '$day',
                                style: TextStyle(
                                  color: isToday ? Colors.orange : Colors.grey[800],
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardRulesCard(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.card_giftcard, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(l10n.translate('checkin_rewards'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildRewardRule(l10n.translate('day_1'), l10n.translate('reward_day_1'), Colors.grey),
                _buildRewardRule(l10n.translate('day_2'), l10n.translate('reward_day_2'), Colors.green),
                _buildRewardRule(l10n.translate('day_3'), l10n.translate('reward_day_3'), Colors.blue),
                _buildRewardRule(l10n.translate('day_4'), l10n.translate('reward_day_4'), Colors.purple),
                _buildRewardRule(l10n.translate('day_5'), l10n.translate('reward_day_5'), Colors.orange),
                _buildRewardRule(l10n.translate('day_6'), l10n.translate('reward_day_6'), Colors.pink),
                _buildRewardRule(l10n.translate('day_7'), l10n.translate('reward_day_7'), Colors.red),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.translate('checkin_tip'),
                    style: TextStyle(color: Colors.orange[700], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardRule(String day, String reward, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Center(child: Text(day.replaceAll(RegExp(r'[^0-9]'), ''), style: TextStyle(color: color, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Text(day, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(reward, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class CheckinRecord {
  final int id;
  final int userId;
  final String checkinDate;
  final int continuousDays;
  final int goldBeanReward;
  final int pointsReward;

  CheckinRecord({
    required this.id,
    required this.userId,
    required this.checkinDate,
    required this.continuousDays,
    required this.goldBeanReward,
    required this.pointsReward,
  });

  factory CheckinRecord.fromJson(Map<String, dynamic> json) {
    return CheckinRecord(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      checkinDate: json['checkin_date'] ?? '',
      continuousDays: json['continuous_days'] ?? 0,
      goldBeanReward: json['gold_bean_reward'] ?? 0,
      pointsReward: json['points_reward'] ?? 0,
    );
  }
}
