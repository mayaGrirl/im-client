/// 钱包主页面
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/wallet_api.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/screens/wallet/recharge_screen.dart';
import 'package:im_client/screens/wallet/withdraw_screen.dart';
import 'package:im_client/screens/wallet/exchange_screen.dart';
import 'package:im_client/screens/wallet/wallet_records_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletApi _walletApi = WalletApi(ApiClient());
  WalletFullInfo? _walletInfo;
  bool _isLoading = true;
  bool _showBalance = true;

  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
  }

  Future<void> _loadWalletInfo() async {
    setState(() => _isLoading = true);
    try {
      final response = await _walletApi.getWalletFullInfo();
      if (response.success && response.data != null) {
        setState(() {
          _walletInfo = WalletFullInfo.fromJson(response.data);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message ?? l10n.getWalletInfoFailed)),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.getWalletInfoFailed}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(l10n.wallet),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWalletInfo,
            tooltip: l10n.refresh,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _navigateToRecords(),
            tooltip: l10n.transactionRecords,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWalletInfo,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildBalanceCard(l10n),
                    const SizedBox(height: 16),
                    _buildActionButtons(l10n),
                    const SizedBox(height: 16),
                    _buildQuickActions(l10n),
                    if (_walletInfo?.config.notice?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      _buildNotice(),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard(AppLocalizations l10n) {
    final wallet = _walletInfo?.wallet;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A73E8), Color(0xFF6C63FF)],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.availableBalance,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showBalance = !_showBalance),
                child: Icon(
                  _showBalance ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _showBalance ? '¥${wallet?.balance.toStringAsFixed(2) ?? '0.00'}' : '****',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          if ((wallet?.frozenBalance ?? 0) > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${l10n.frozen}: ¥${wallet?.frozenBalance.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 24),
                const SizedBox(width: 8),
                Text(
                  _showBalance ? '${wallet?.goldBeans ?? 0}' : '****',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.goldBeans,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  l10n.translate('yuan_to_beans_rate').replaceAll('{rate}', '${_walletInfo?.config.yuanToBeanRate.toInt() ?? 1000}'),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.add_circle_outline,
              label: l10n.recharge,
              color: const Color(0xFF4CAF50),
              onTap: _navigateToRecharge,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.remove_circle_outline,
              label: l10n.withdraw,
              color: const Color(0xFFFF9800),
              onTap: _navigateToWithdraw,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.swap_horiz,
              label: l10n.exchange,
              color: const Color(0xFF9C27B0),
              onTap: _navigateToExchange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildQuickActionItem(
              icon: Icons.receipt_long,
              title: l10n.rechargeRecords,
              onTap: () => _navigateToRecords(initialTab: 0),
            ),
            const Divider(height: 1, indent: 56),
            _buildQuickActionItem(
              icon: Icons.account_balance_wallet,
              title: l10n.withdrawRecords,
              onTap: () => _navigateToRecords(initialTab: 1),
            ),
            const Divider(height: 1, indent: 56),
            _buildQuickActionItem(
              icon: Icons.swap_horizontal_circle,
              title: l10n.exchangeRecords,
              onTap: () => _navigateToRecords(initialTab: 2),
            ),
            const Divider(height: 1, indent: 56),
            _buildQuickActionItem(
              icon: Icons.list_alt,
              title: l10n.walletFlow,
              onTap: () => _navigateToRecords(initialTab: 3),
            ),
            if (_walletInfo?.config.customerServiceWechat?.isNotEmpty == true ||
                _walletInfo?.config.customerServiceQQ?.isNotEmpty == true ||
                _walletInfo?.config.customerServicePhone?.isNotEmpty == true) ...[
              const Divider(height: 1, indent: 56),
              _buildQuickActionItem(
                icon: Icons.headset_mic,
                title: l10n.contactCustomerService,
                onTap: _showCustomerService,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildNotice() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFFFA000)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _walletInfo?.config.notice ?? '',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToRecharge() async {
    final l10n = AppLocalizations.of(context)!;
    if (!(_walletInfo?.config.rechargeEnabled ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.rechargeNotAvailable)),
      );
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RechargeScreen(config: _walletInfo!.config),
      ),
    );
    if (result == true) {
      _loadWalletInfo();
    }
  }

  void _navigateToWithdraw() async {
    final l10n = AppLocalizations.of(context)!;
    if (!(_walletInfo?.config.withdrawEnabled ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.withdrawNotAvailable)),
      );
      return;
    }
    if (!(_walletInfo?.hasPayPassword ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.setPayPasswordFirst)),
      );
      return;
    }
    if (_walletInfo?.hasPendingWithdraw ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pendingWithdrawOrder)),
      );
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WithdrawScreen(
          config: _walletInfo!.config,
          balance: _walletInfo!.wallet.balance,
        ),
      ),
    );
    if (result == true) {
      _loadWalletInfo();
    }
  }

  void _navigateToExchange() async {
    final l10n = AppLocalizations.of(context)!;
    if (!(_walletInfo?.config.exchangeEnabled ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exchangeNotAvailable)),
      );
      return;
    }
    if (!(_walletInfo?.hasPayPassword ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.setPayPasswordFirst)),
      );
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExchangeScreen(
          config: _walletInfo!.config,
          balance: _walletInfo!.wallet.balance,
          goldBeans: _walletInfo!.wallet.goldBeans,
        ),
      ),
    );
    if (result == true) {
      _loadWalletInfo();
    }
  }

  void _navigateToRecords({int initialTab = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalletRecordsScreen(initialTab: initialTab),
      ),
    );
  }

  void _showCustomerService() {
    final config = _walletInfo?.config;
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.contactCustomerService,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (config?.customerServiceWechat?.isNotEmpty == true)
              _buildContactItem(
                icon: Icons.chat,
                label: l10n.translate('wechat'),
                value: config!.customerServiceWechat!,
              ),
            if (config?.customerServiceQQ?.isNotEmpty == true)
              _buildContactItem(
                icon: Icons.message,
                label: 'QQ',
                value: config!.customerServiceQQ!,
              ),
            if (config?.customerServicePhone?.isNotEmpty == true)
              _buildContactItem(
                icon: Icons.phone,
                label: l10n.translate('phone_label'),
                value: config!.customerServicePhone!,
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.copiedToClipboard)),
              );
            },
            child: Text(l10n.copy),
          ),
        ],
      ),
    );
  }
}
