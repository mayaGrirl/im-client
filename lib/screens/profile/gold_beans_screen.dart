/// 金豆明细页面
/// 显示金豆余额和交易记录

import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/user_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';

class GoldBeansScreen extends StatefulWidget {
  const GoldBeansScreen({super.key});

  @override
  State<GoldBeansScreen> createState() => _GoldBeansScreenState();
}

class _GoldBeansScreenState extends State<GoldBeansScreen> {
  final UserApi _userApi = UserApi(ApiClient());

  int _goldBeans = 0;
  bool _canClaimToday = false;
  int _dailyGoldBeans = 0;

  List<GoldBeanRecord> _records = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int? _filterType;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadGoldBeanBalance();
    _loadRecords();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreRecords();
    }
  }

  Future<void> _loadGoldBeanBalance() async {
    try {
      final response = await _userApi.getGoldBeanBalance();
      if (response.success && response.data != null) {
        setState(() {
          _goldBeans = response.data['balance'] ?? 0;
          _canClaimToday = response.data['can_claim_today'] ?? false;
          _dailyGoldBeans = response.data['daily_gold_beans'] ?? 0;
        });
      }
    } catch (e) {
      // 忽略错误
    }
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _page = 1;
    });

    try {
      final response = await _userApi.getGoldBeanRecords(
        page: 1,
        pageSize: 20,
      );
      if (response.success && response.data != null) {
        final list = response.data['list'] as List? ?? [];
        setState(() {
          _records = list
              .map((e) => GoldBeanRecord.fromJson(e))
              .toList();
          // 如果有筛选类型，进行本地过滤
          if (_filterType != null) {
            _records = _records.where((r) => _matchesFilter(r)).toList();
          }
          _hasMore = list.length >= 20;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreRecords() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final response = await _userApi.getGoldBeanRecords(
        page: _page + 1,
        pageSize: 20,
      );
      if (response.success && response.data != null) {
        final list = response.data['list'] as List? ?? [];
        var newRecords = list.map((e) => GoldBeanRecord.fromJson(e)).toList();
        // 如果有筛选类型，进行本地过滤
        if (_filterType != null) {
          newRecords = newRecords.where((r) => _matchesFilter(r)).toList();
        }
        setState(() {
          _records.addAll(newRecords);
          _page++;
          _hasMore = list.length >= 20;
          _isLoadingMore = false;
        });
      } else {
        setState(() => _isLoadingMore = false);
      }
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 顶部卡片
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Text(
                          l10n.goldBeanBalance,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_goldBeans',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (_canClaimToday) ...[
                          const SizedBox(height: 12),
                          Text(
                            '${l10n.dailyClaimable} $_dailyGoldBeans ${l10n.goldBeans}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            title: Text(l10n.goldBeanRecords),
          ),
          // 筛选栏
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(null, l10n.all, l10n),
                    _buildFilterChip(1, l10n.dailyClaim, l10n),
                    _buildFilterChip(2, l10n.translate('invite_reward'), l10n),
                    _buildFilterChip(3, l10n.translate('register_reward'), l10n),
                    _buildFilterChip(4, l10n.translate('exchange_consume'), l10n),
                    _buildFilterChip(5, l10n.translate('system_gift'), l10n),
                    _buildFilterChip(6, l10n.translate('level_reward'), l10n),
                    _buildFilterChip(8, l10n.translate('send_red_packet'), l10n),
                    _buildFilterChip(9, l10n.translate('grab_red_packet'), l10n),
                    _buildFilterChip(-1, l10n.translate('livestream_payment'), l10n),
                    _buildFilterChip(-2, l10n.translate('livestream_income'), l10n),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          // 金豆记录列表
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _records.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.noGoldBeanRecords,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == _records.length) {
                            return _hasMore
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Center(
                                      child: Text(
                                        l10n.noMore,
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  );
                          }
                          return _buildRecordItem(_records[index], l10n);
                        },
                        childCount: _records.length + 1,
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int? type, String label, AppLocalizations l10n) {
    final isSelected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterType = selected ? type : null;
          });
          _loadRecords();
        },
        selectedColor: Colors.orange.withOpacity(0.2),
        checkmarkColor: Colors.orange,
        labelStyle: TextStyle(
          color: isSelected ? Colors.orange : Colors.grey[700],
          fontSize: 13,
        ),
      ),
    );
  }

  /// 过滤匹配：正数=精确匹配，-1=直播付费组，-2=直播收入组
  bool _matchesFilter(GoldBeanRecord record) {
    if (_filterType == null) return true;
    if (_filterType == -1) return [10, 11, 12, 13].contains(record.type); // 直播付费
    if (_filterType == -2) return record.type == 14; // 直播收入
    return record.type == _filterType;
  }

  Widget _buildRecordItem(GoldBeanRecord record, AppLocalizations l10n) {
    final isIncome = record.amount > 0;
    final iconData = _getTypeIcon(record.type);
    final iconColor = _getTypeColor(record.type);

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(iconData, color: iconColor, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _getTypeName(record.type, l10n),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              '${isIncome ? '+' : ''}${record.amount}',
              style: TextStyle(
                color: isIncome ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.createdAt,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '${l10n.balanceAfter}: ${record.balance}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (record.remark.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                _getLocalizedRemark(record, l10n),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        onTap: () => _showRecordDetail(record, l10n),
      ),
    );
  }

  String _getTypeName(int type, AppLocalizations l10n) {
    switch (type) {
      case 1:
        return l10n.dailyClaim;
      case 2:
        return l10n.translate('invite_reward');
      case 3:
        return l10n.translate('register_reward');
      case 4:
        return l10n.translate('exchange_consume');
      case 5:
        return l10n.translate('system_gift');
      case 6:
        return l10n.translate('level_reward');
      case 7:
        return l10n.translate('admin_adjust');
      case 8:
        return l10n.translate('send_red_packet');
      case 9:
        return l10n.translate('grab_red_packet');
      case 10:
        return l10n.translate('livestream_payment');
      case 11:
        return l10n.translate('paid_call_payment');
      case 12:
        return l10n.translate('livestream_gift');
      case 13:
        return l10n.translate('livestream_ticket');
      case 14:
        return l10n.translate('livestream_income');
      default:
        return l10n.unknown;
    }
  }

  IconData _getTypeIcon(int type) {
    switch (type) {
      case 1:
        return Icons.calendar_today; // 每日领取
      case 2:
        return Icons.person_add; // 邀请奖励
      case 3:
        return Icons.card_giftcard; // 注册奖励
      case 4:
        return Icons.shopping_cart; // 兑换消费
      case 5:
        return Icons.redeem; // 系统赠送
      case 6:
        return Icons.trending_up; // 等级奖励
      case 7:
        return Icons.admin_panel_settings; // 管理员调整
      case 8:
        return Icons.card_giftcard; // 发红包
      case 9:
        return Icons.redeem; // 抢红包
      case 10:
        return Icons.live_tv; // 直播付费观看
      case 11:
        return Icons.videocam; // 付费通话
      case 12:
        return Icons.card_giftcard; // 直播送礼
      case 13:
        return Icons.confirmation_number; // 购买门票
      case 14:
        return Icons.account_balance_wallet; // 主播收入
      default:
        return Icons.swap_horiz;
    }
  }

  Color _getTypeColor(int type) {
    switch (type) {
      case 1:
        return Colors.blue; // 每日领取
      case 2:
        return Colors.green; // 邀请奖励
      case 3:
        return Colors.orange; // 注册奖励
      case 4:
        return Colors.red; // 兑换消费
      case 5:
        return Colors.purple; // 系统赠送
      case 6:
        return Colors.amber; // 等级奖励
      case 7:
        return Colors.grey; // 管理员调整
      case 8:
        return Colors.red; // 发红包
      case 9:
        return Colors.red; // 抢红包
      case 10:
      case 11:
      case 12:
      case 13:
        return Colors.deepOrange; // 直播付费相关
      case 14:
        return Colors.green; // 主播收入
      default:
        return Colors.grey;
    }
  }

  /// 获取本地化的备注
  String _getLocalizedRemark(GoldBeanRecord record, AppLocalizations l10n) {
    final remark = record.remark;

    switch (record.type) {
      case 1: // 每日领取
        // 尝试从 remark 解析等级，格式如: "每日领取(等级3)" 或 "签到奖励(连续1天)"
        final levelMatch = RegExp(r'[等级级别Level]+\s*(\d+)').firstMatch(remark);
        final daysMatch = RegExp(r'[连续連續consecutive]+\s*(\d+)').firstMatch(remark);

        if (daysMatch != null) {
          final days = daysMatch.group(1) ?? '1';
          return l10n.translate('remark_checkin_reward_days').replaceAll('{days}', days);
        } else if (levelMatch != null) {
          final level = levelMatch.group(1) ?? '1';
          return l10n.translate('remark_daily_claim_level').replaceAll('{level}', level);
        }
        return l10n.dailyClaim;

      case 2: // 邀请奖励
        // 尝试解析用户名和倍率，格式如: "邀请用户 seven 注册奖励(1.5倍)"
        final inviteMatch = RegExp(r'[邀请邀請Invite]+.*?(\w+).*?(\d+\.?\d*)[倍x]?').firstMatch(remark);
        if (inviteMatch != null) {
          final user = inviteMatch.group(1) ?? '';
          final multiplier = inviteMatch.group(2) ?? '1';
          return l10n.translate('remark_invite_user_reward')
              .replaceAll('{user}', user)
              .replaceAll('{multiplier}', multiplier);
        }
        return l10n.translate('invite_reward');

      case 3: // 注册奖励
        return l10n.translate('remark_new_user_reward');

      case 4: // 兑换消费
        // 尝试解析商品名和数量，格式如: "兑换商品: XXX x2"
        final exchangeMatch = RegExp(r'[：:]\s*(.+?)\s*[xX×]\s*(\d+)').firstMatch(remark);
        if (exchangeMatch != null) {
          final product = exchangeMatch.group(1) ?? '';
          final quantity = exchangeMatch.group(2) ?? '1';
          return l10n.translate('remark_exchange_product')
              .replaceAll('{product}', product)
              .replaceAll('{quantity}', quantity);
        }
        return l10n.translate('exchange_consume');

      case 5: // 系统赠送
        return l10n.translate('remark_system_gift');

      case 6: // 等级奖励
        return l10n.translate('remark_level_reward');

      case 7: // 管理员调整
        return l10n.translate('remark_admin_adjust');

      case 8: // 发红包
        return l10n.translate('remark_send_red_packet');

      case 9: // 抢红包/领取红包
        return l10n.translate('remark_receive_red_packet');

      case 10: // 直播付费观看
        return l10n.translate('remark_live_watch');

      case 11: // 付费通话
        return l10n.translate('remark_paid_call');

      case 12: // 直播送礼
        return l10n.translate('remark_live_gift');

      case 13: // 购买门票
        return l10n.translate('remark_live_ticket');

      case 14: // 主播收入 — 根据 remark 前缀区分来源
        if (remark.startsWith('gift')) {
          return l10n.translate('remark_anchor_gift_income');
        } else if (remark.startsWith('ticket')) {
          return l10n.translate('remark_anchor_ticket_income');
        } else if (remark.startsWith('paid_call')) {
          return l10n.translate('remark_anchor_call_income');
        } else {
          return l10n.translate('remark_anchor_watch_income');
        }

      default:
        return remark; // 默认返回原始备注
    }
  }

  void _showRecordDetail(GoldBeanRecord record, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动条
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // 金额
            Text(
              '${record.amount > 0 ? '+' : ''}${record.amount}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: record.amount > 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getTypeName(record.type, l10n),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            // 详细信息
            _buildDetailRow(l10n.recordTime, record.createdAt),
            _buildDetailRow(l10n.amountChange, '${record.amount > 0 ? '+' : ''}${record.amount} ${l10n.goldBeans}'),
            _buildDetailRow(l10n.balanceAfter, '${record.balance} ${l10n.goldBeans}'),
            if (record.remark.isNotEmpty)
              _buildDetailRow(l10n.remark, _getLocalizedRemark(record, l10n)),
            if (record.relatedId > 0)
              _buildDetailRow(l10n.relatedUserId, '#${record.relatedId}'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 金豆记录模型
class GoldBeanRecord {
  final int id;
  final int userId;
  final int type;
  final int amount;
  final int balance;
  final int relatedId;
  final String remark;
  final String createdAt;

  GoldBeanRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.balance,
    required this.relatedId,
    required this.remark,
    required this.createdAt,
  });

  factory GoldBeanRecord.fromJson(Map<String, dynamic> json) {
    // 处理时间格式
    String createdAt = json['created_at'] ?? '';
    if (createdAt.isNotEmpty && createdAt.contains('T')) {
      // 转换ISO格式为可读格式
      try {
        final dt = DateTime.parse(createdAt);
        createdAt = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return GoldBeanRecord(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      type: json['type'] ?? 0,
      amount: (json['amount'] ?? 0).toInt(),
      balance: (json['balance'] ?? 0).toInt(),
      relatedId: json['related_id'] ?? 0,
      remark: json['remark'] ?? '',
      createdAt: createdAt,
    );
  }
}
