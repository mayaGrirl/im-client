/// 兑换页面（余额↔金豆）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/wallet_api.dart';
import 'package:im_client/l10n/app_localizations.dart';

class ExchangeScreen extends StatefulWidget {
  final WalletConfig config;
  final double balance;
  final int goldBeans;

  const ExchangeScreen({
    super.key,
    required this.config,
    required this.balance,
    required this.goldBeans,
  });

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> with SingleTickerProviderStateMixin {
  final WalletApi _walletApi = WalletApi(ApiClient());
  late TabController _tabController;
  final TextEditingController _yuanController = TextEditingController();
  final TextEditingController _beanController = TextEditingController();
  final TextEditingController _payPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _yuanController.clear();
        _beanController.clear();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _yuanController.dispose();
    _beanController.dispose();
    _payPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(l10n.exchange),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: [
            Tab(text: l10n.balanceToGoldBeans),
            Tab(text: l10n.goldBeansToBalance),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildYuanToBeanTab(l10n),
          _buildBeanToYuanTab(l10n),
        ],
      ),
    );
  }

  Widget _buildYuanToBeanTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBalanceCard(
            label: l10n.availableBalance,
            value: '¥${widget.balance.toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet,
            color: const Color(0xFF1A73E8),
          ),
          const SizedBox(height: 20),
          _buildExchangeCard(
            title: l10n.exchangeAmount,
            controller: _yuanController,
            prefix: '¥',
            hint: l10n.pleaseEnterAmount,
            isDecimal: true,
            onChanged: (value) {
              final yuan = double.tryParse(value) ?? 0;
              final beans = (yuan * widget.config.yuanToBeanRate).toInt();
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          _buildArrow(),
          const SizedBox(height: 16),
          _buildResultCard(
            label: l10n.goldBeansObtainable,
            value: _calculateBeansFromYuan(),
            icon: Icons.monetization_on,
            color: const Color(0xFFFFD700),
          ),
          const SizedBox(height: 20),
          _buildPasswordInput(l10n),
          const SizedBox(height: 20),
          _buildRateInfo(l10n),
          const SizedBox(height: 32),
          _buildSubmitButton(l10n, isYuanToBean: true),
        ],
      ),
    );
  }

  Widget _buildBeanToYuanTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBalanceCard(
            label: l10n.translate('available_gold_beans'),
            value: '${widget.goldBeans}',
            icon: Icons.monetization_on,
            color: const Color(0xFFFFD700),
          ),
          const SizedBox(height: 20),
          _buildExchangeCard(
            title: l10n.goldBeansQuantity,
            controller: _beanController,
            prefix: '',
            hint: l10n.pleaseEnterGoldBeans,
            isDecimal: false,
            onChanged: (value) {
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          _buildArrow(),
          const SizedBox(height: 16),
          _buildResultCard(
            label: l10n.amountObtainable,
            value: '¥${_calculateYuanFromBeans()}',
            icon: Icons.account_balance_wallet,
            color: const Color(0xFF1A73E8),
          ),
          const SizedBox(height: 20),
          _buildPasswordInput(l10n),
          const SizedBox(height: 20),
          _buildRateInfo(l10n),
          const SizedBox(height: 32),
          _buildSubmitButton(l10n, isYuanToBean: false),
        ],
      ),
    );
  }

  Widget _buildBalanceCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeCard({
    required String title,
    required TextEditingController controller,
    required String prefix,
    required String hint,
    required bool isDecimal,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: isDecimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            inputFormatters: isDecimal
                ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
                : [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: prefix.isNotEmpty ? '$prefix ' : null,
              prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildArrow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.arrow_downward,
        color: Color(0xFF9C27B0),
        size: 24,
      ),
    );
  }

  Widget _buildResultCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordInput(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.payPassword,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _payPasswordController,
            obscureText: !_showPassword,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: l10n.translate('enter_pay_password'),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: IconButton(
                icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateInfo(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.swap_horiz, color: Color(0xFF9C27B0)),
          const SizedBox(width: 8),
          Text(
            l10n.translate('exchange_rate_format').replaceAll('{rate}', '${widget.config.yuanToBeanRate.toInt()}'),
            style: const TextStyle(
              color: Color(0xFF9C27B0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(AppLocalizations l10n, {required bool isYuanToBean}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : () => _submitExchange(isYuanToBean),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9C27B0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                isYuanToBean ? l10n.translate('exchange_to_gold_beans') : l10n.translate('exchange_to_balance'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
      ),
    );
  }

  String _calculateBeansFromYuan() {
    final yuan = double.tryParse(_yuanController.text) ?? 0;
    final beans = (yuan * widget.config.yuanToBeanRate).toInt();
    return '$beans';
  }

  String _calculateYuanFromBeans() {
    final beans = int.tryParse(_beanController.text) ?? 0;
    final yuan = beans / widget.config.beanToYuanRate;
    return yuan.toStringAsFixed(2);
  }

  Future<void> _submitExchange(bool isYuanToBean) async {
    final l10n = AppLocalizations.of(context)!;
    if (_payPasswordController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('enter_pay_password'))),
      );
      return;
    }

    if (isYuanToBean) {
      final yuan = double.tryParse(_yuanController.text) ?? 0;
      if (yuan <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('please_enter_exchange_amount'))),
        );
        return;
      }
      if (yuan > widget.balance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('insufficient_balance'))),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        final response = await _walletApi.exchangeYuanToBean(
          yuanAmount: yuan,
          payPassword: _payPasswordController.text,
        );

        if (response.success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('exchange_success_beans').replaceAll('{amount}', '${response.data['bean_amount']}'))),
            );
            Navigator.pop(context, true);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response.message ?? l10n.translate('exchange_failed'))),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.translate('exchange_failed')}: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    } else {
      final beans = int.tryParse(_beanController.text) ?? 0;
      if (beans <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('please_enter_exchange_beans'))),
        );
        return;
      }
      if (beans > widget.goldBeans) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('insufficient_gold_beans'))),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        final response = await _walletApi.exchangeBeanToYuan(
          beanAmount: beans,
          payPassword: _payPasswordController.text,
        );

        if (response.success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('exchange_success_yuan').replaceAll('{amount}', '${response.data['yuan_amount']}'))),
            );
            Navigator.pop(context, true);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response.message ?? l10n.translate('exchange_failed'))),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.translate('exchange_failed')}: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }
}
