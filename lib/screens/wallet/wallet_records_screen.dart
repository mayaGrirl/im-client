/// 钱包记录页面（充值、提现、兑换、流水）
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/wallet_api.dart';
import 'package:im_client/l10n/app_localizations.dart';

class WalletRecordsScreen extends StatefulWidget {
  final int initialTab;

  const WalletRecordsScreen({super.key, this.initialTab = 0});

  @override
  State<WalletRecordsScreen> createState() => _WalletRecordsScreenState();
}

class _WalletRecordsScreenState extends State<WalletRecordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transactionRecords),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          isScrollable: true,
          tabs: [
            Tab(text: l10n.rechargeRecords),
            Tab(text: l10n.withdrawRecords),
            Tab(text: l10n.exchangeRecords),
            Tab(text: l10n.walletFlow),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _RechargeRecordsTab(),
          _WithdrawRecordsTab(),
          _ExchangeRecordsTab(),
          _WalletLogsTab(),
        ],
      ),
    );
  }
}

// ==================== 充值记录 ====================
class _RechargeRecordsTab extends StatefulWidget {
  const _RechargeRecordsTab();

  @override
  State<_RechargeRecordsTab> createState() => _RechargeRecordsTabState();
}

class _RechargeRecordsTabState extends State<_RechargeRecordsTab>
    with AutomaticKeepAliveClientMixin {
  final WalletApi _walletApi = WalletApi(ApiClient());
  final List<RechargeRecord> _records = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _records.clear();
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    setState(() => _isLoading = true);

    try {
      final response = await _walletApi.getRechargeRecords(page: _page);
      if (response.success && response.data != null) {
        final list = (response.data['list'] as List?)
                ?.map((e) => RechargeRecord.fromJson(e))
                .toList() ??
            [];
        setState(() {
          _records.addAll(list);
          _hasMore = list.length >= 20;
          _page++;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () => _loadRecords(refresh: true),
      child: _records.isEmpty && !_isLoading
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _records.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _records.length) {
                  if (_hasMore && !_isLoading) {
                    _loadRecords();
                  }
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return _buildRechargeItem(_records[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(l10n.translate('no_recharge_records'), style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildRechargeItem(RechargeRecord record) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(record.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  record.statusName,
                  style: TextStyle(
                    color: _getStatusColor(record.status),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '+¥${record.actualAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(l10n.translate('order_number'), record.orderNo),
          _buildInfoRow(l10n.translate('recharge_method'), record.methodName),
          _buildInfoRow(l10n.translate('recharge_amount'), '¥${record.amount.toStringAsFixed(2)}'),
          if (record.fee > 0) _buildInfoRow(l10n.translate('fee'), '¥${record.fee.toStringAsFixed(2)}'),
          _buildInfoRow(l10n.translate('created_time'), record.createdAt),
          if (record.adminRemark?.isNotEmpty == true)
            _buildInfoRow(l10n.translate('admin_remark'), record.adminRemark!),
          if (record.canCancel) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelRecharge(record),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: Text(l10n.cancel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.green;
      case 2:
        return Colors.red;
      case 3:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _cancelRecharge(RechargeRecord record) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('cancel_recharge')),
        content: Text(l10n.translate('confirm_cancel_recharge')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _walletApi.cancelRecharge(record.orderNo);
      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('cancel_success'))),
        );
        _loadRecords(refresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message ?? l10n.translate('cancel_failed'))),
        );
      }
    }
  }
}

// ==================== 提现记录 ====================
class _WithdrawRecordsTab extends StatefulWidget {
  const _WithdrawRecordsTab();

  @override
  State<_WithdrawRecordsTab> createState() => _WithdrawRecordsTabState();
}

class _WithdrawRecordsTabState extends State<_WithdrawRecordsTab>
    with AutomaticKeepAliveClientMixin {
  final WalletApi _walletApi = WalletApi(ApiClient());
  final List<WithdrawRecord> _records = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _records.clear();
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    setState(() => _isLoading = true);

    try {
      final response = await _walletApi.getWithdrawRecords(page: _page);
      if (response.success && response.data != null) {
        final list = (response.data['list'] as List?)
                ?.map((e) => WithdrawRecord.fromJson(e))
                .toList() ??
            [];
        setState(() {
          _records.addAll(list);
          _hasMore = list.length >= 20;
          _page++;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () => _loadRecords(refresh: true),
      child: _records.isEmpty && !_isLoading
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _records.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _records.length) {
                  if (_hasMore && !_isLoading) {
                    _loadRecords();
                  }
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return _buildWithdrawItem(_records[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(l10n.translate('no_withdraw_records'), style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildWithdrawItem(WithdrawRecord record) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(record.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  record.statusName,
                  style: TextStyle(
                    color: _getStatusColor(record.status),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '-¥${record.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFFFF9800),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(l10n.translate('order_number'), record.orderNo),
          _buildInfoRow(l10n.translate('withdraw_method'), record.methodName),
          _buildInfoRow(l10n.translate('fee'), '¥${record.fee.toStringAsFixed(2)}'),
          _buildInfoRow(l10n.translate('actual_amount'), '¥${record.actualAmount.toStringAsFixed(2)}'),
          _buildInfoRow(l10n.translate('created_time'), record.createdAt),
          if (record.adminRemark?.isNotEmpty == true)
            _buildInfoRow(l10n.translate('admin_remark'), record.adminRemark!),
          if (record.canCancel) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelWithdraw(record),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: Text(l10n.cancel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      case 4:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _cancelWithdraw(WithdrawRecord record) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('cancel_withdraw')),
        content: Text(l10n.translate('confirm_cancel_withdraw')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _walletApi.cancelWithdraw(record.orderNo);
      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('cancel_withdraw_success'))),
        );
        _loadRecords(refresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message ?? l10n.translate('cancel_failed'))),
        );
      }
    }
  }
}

// ==================== 兑换记录 ====================
class _ExchangeRecordsTab extends StatefulWidget {
  const _ExchangeRecordsTab();

  @override
  State<_ExchangeRecordsTab> createState() => _ExchangeRecordsTabState();
}

class _ExchangeRecordsTabState extends State<_ExchangeRecordsTab>
    with AutomaticKeepAliveClientMixin {
  final WalletApi _walletApi = WalletApi(ApiClient());
  final List<ExchangeRecord> _records = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _records.clear();
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    setState(() => _isLoading = true);

    try {
      final response = await _walletApi.getExchangeRecords(page: _page);
      if (response.success && response.data != null) {
        final list = (response.data['list'] as List?)
                ?.map((e) => ExchangeRecord.fromJson(e))
                .toList() ??
            [];
        setState(() {
          _records.addAll(list);
          _hasMore = list.length >= 20;
          _page++;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () => _loadRecords(refresh: true),
      child: _records.isEmpty && !_isLoading
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _records.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _records.length) {
                  if (_hasMore && !_isLoading) {
                    _loadRecords();
                  }
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return _buildExchangeItem(_records[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_horizontal_circle, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(l10n.translate('no_exchange_records'), style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildExchangeItem(ExchangeRecord record) {
    final l10n = AppLocalizations.of(context)!;
    final isYuanToBean = record.type == ExchangeType.yuanToBean;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.swap_horiz, color: Color(0xFF9C27B0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.typeName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  record.createdAt,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isYuanToBean
                    ? '-¥${record.yuanAmount.toStringAsFixed(2)}'
                    : '+¥${record.yuanAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isYuanToBean ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isYuanToBean
                    ? '+${record.beanAmount}${l10n.translate('beans_unit')}'
                    : '-${record.beanAmount}${l10n.translate('beans_unit')}',
                style: TextStyle(
                  color: isYuanToBean ? const Color(0xFFFFD700) : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== 钱包流水 ====================
class _WalletLogsTab extends StatefulWidget {
  const _WalletLogsTab();

  @override
  State<_WalletLogsTab> createState() => _WalletLogsTabState();
}

class _WalletLogsTabState extends State<_WalletLogsTab>
    with AutomaticKeepAliveClientMixin {
  final WalletApi _walletApi = WalletApi(ApiClient());
  final List<WalletLog> _logs = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _logs.clear();
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    setState(() => _isLoading = true);

    try {
      final response = await _walletApi.getWalletLogs(page: _page);
      if (response.success && response.data != null) {
        final list = (response.data['list'] as List?)
                ?.map((e) => WalletLog.fromJson(e))
                .toList() ??
            [];
        setState(() {
          _logs.addAll(list);
          _hasMore = list.length >= 20;
          _page++;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () => _loadLogs(refresh: true),
      child: _logs.isEmpty && !_isLoading
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _logs.length) {
                  if (_hasMore && !_isLoading) {
                    _loadLogs();
                  }
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return _buildLogItem(_logs[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(l10n.translate('no_wallet_logs'), style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildLogItem(WalletLog log) {
    final l10n = AppLocalizations.of(context)!;
    final hasAmount = log.amount != 0;
    final hasBeans = log.beanAmount != 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getLogTypeColor(log.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getLogTypeIcon(log.type),
              color: _getLogTypeColor(log.type),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.typeName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  log.createdAt,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                if (log.remark?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    log.remark!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasAmount)
                Text(
                  '${log.amount >= 0 ? '+' : ''}¥${log.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: log.amount >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (hasBeans)
                Text(
                  '${log.beanAmount >= 0 ? '+' : ''}${log.beanAmount}${l10n.translate('beans_unit')}',
                  style: TextStyle(
                    color: log.beanAmount >= 0 ? const Color(0xFFFFD700) : Colors.grey,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getLogTypeColor(int type) {
    switch (type) {
      case 1: // 充值
        return Colors.green;
      case 2: // 提现
        return Colors.orange;
      case 3: // 兑换入账
        return Colors.blue;
      case 4: // 兑换扣款
        return Colors.purple;
      case 5: // 手续费
        return Colors.red;
      case 6: // 退款
        return Colors.teal;
      case 7: // 奖励
        return Colors.amber;
      case 10: // 冻结
        return Colors.blueGrey;
      case 11: // 解冻
        return Colors.lightBlue;
      default:
        return Colors.grey;
    }
  }

  IconData _getLogTypeIcon(int type) {
    switch (type) {
      case 1:
        return Icons.add_circle_outline;
      case 2:
        return Icons.remove_circle_outline;
      case 3:
      case 4:
        return Icons.swap_horiz;
      case 5:
        return Icons.receipt;
      case 6:
        return Icons.replay;
      case 7:
        return Icons.card_giftcard;
      case 10:
        return Icons.lock;
      case 11:
        return Icons.lock_open;
      default:
        return Icons.monetization_on;
    }
  }
}
