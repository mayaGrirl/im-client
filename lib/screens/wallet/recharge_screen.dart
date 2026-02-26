/// 充值页面（线下转账 / USDT支付）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/wallet_api.dart';
import 'package:im_client/l10n/app_localizations.dart';

class RechargeScreen extends StatefulWidget {
  final WalletConfig config;

  const RechargeScreen({super.key, required this.config});

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> with SingleTickerProviderStateMixin {
  final WalletApi _walletApi = WalletApi(ApiClient());
  TabController? _tabController;

  // 通用
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();

  // 线下转账
  int _payChannel = RechargePayChannel.bank;
  final TextEditingController _payerNameController = TextEditingController();
  final TextEditingController _payerAccountController = TextEditingController();
  final TextEditingController _payerBankNameController = TextEditingController();

  // USDT支付
  final TextEditingController _payerWalletAddressController = TextEditingController();
  final TextEditingController _usdtAmountController = TextEditingController();
  final TextEditingController _txHashController = TextEditingController();

  bool _isSubmitting = false;
  bool _confirmed = false;
  PaymentAccount? _savedAccount;

  /// 是否显示USDT选项
  bool get _showUsdt => widget.config.usdtRechargeEnabled;

  /// Tab数量
  int get _tabCount => _showUsdt ? 2 : 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        setState(() {
          _confirmed = false;
        });
        // 切换Tab时加载对应的保存账户信息
        _loadAccountForChannel();
      }
    });
    _loadPaymentAccount();
  }

  Future<void> _loadPaymentAccount() async {
    try {
      final response = await _walletApi.getPaymentAccount();
      if (response.success && response.data != null) {
        setState(() {
          _savedAccount = PaymentAccount.fromJson(response.data);
        });
        _loadAccountForChannel();
      }
    } catch (e) {
      // 忽略错误，使用空值
    }
  }

  void _loadAccountForChannel() {
    if (_savedAccount == null) return;

    // 线下转账Tab (index 0 or no tabs)
    final isOfflineTab = _tabController == null || _tabController!.index == 0;
    if (isOfflineTab) {
      _payerNameController.text = _savedAccount!.getAccountName(_payChannel);
      _payerAccountController.text = _savedAccount!.getAccountNo(_payChannel);
      if (_payChannel == RechargePayChannel.bank) {
        _payerBankNameController.text = _savedAccount!.bankName;
      }
    }
    // USDT Tab
    else if (_showUsdt) {
      _payerWalletAddressController.text = _savedAccount!.usdtWalletAddress;
    }
  }

  Future<void> _savePaymentAccount() async {
    final account = _savedAccount ?? PaymentAccount.empty();

    try {
      // 根据当前Tab和渠道保存对应的账户信息
      final isOfflineTab = _tabController == null || _tabController!.index == 0;
      if (isOfflineTab) {
        // 线下转账
        await _walletApi.updatePaymentAccount(
          bankAccountName: _payChannel == RechargePayChannel.bank ? _payerNameController.text : account.bankAccountName,
          bankAccountNo: _payChannel == RechargePayChannel.bank ? _payerAccountController.text : account.bankAccountNo,
          bankName: _payChannel == RechargePayChannel.bank ? _payerBankNameController.text : account.bankName,
          alipayAccountName: _payChannel == RechargePayChannel.alipay ? _payerNameController.text : account.alipayAccountName,
          alipayAccountNo: _payChannel == RechargePayChannel.alipay ? _payerAccountController.text : account.alipayAccountNo,
          wechatAccountName: _payChannel == RechargePayChannel.wechat ? _payerNameController.text : account.wechatAccountName,
          wechatAccountNo: _payChannel == RechargePayChannel.wechat ? _payerAccountController.text : account.wechatAccountNo,
          usdtWalletAddress: account.usdtWalletAddress,
        );
      } else {
        // USDT
        await _walletApi.updatePaymentAccount(
          bankAccountName: account.bankAccountName,
          bankAccountNo: account.bankAccountNo,
          bankName: account.bankName,
          alipayAccountName: account.alipayAccountName,
          alipayAccountNo: account.alipayAccountNo,
          wechatAccountName: account.wechatAccountName,
          wechatAccountNo: account.wechatAccountNo,
          usdtWalletAddress: _payerWalletAddressController.text,
        );
      }
    } catch (e) {
      // 忽略保存错误
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _amountController.dispose();
    _remarkController.dispose();
    _payerNameController.dispose();
    _payerAccountController.dispose();
    _payerBankNameController.dispose();
    _payerWalletAddressController.dispose();
    _usdtAmountController.dispose();
    _txHashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(l10n.recharge),
        centerTitle: true,
        elevation: 0,
        bottom: _tabCount > 1
            ? TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).primaryColor,
                tabs: [
                  Tab(text: l10n.offlineTransfer),
                  if (_showUsdt) Tab(text: l10n.usdtPayment),
                ],
              )
            : null,
      ),
      body: _tabCount > 1
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildOfflineTab(l10n),
                if (_showUsdt) _buildUsdtTab(l10n),
              ],
            )
          : _buildOfflineTab(l10n),
    );
  }

  // ==================== 线下转账 ====================
  Widget _buildOfflineTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAmountInput(l10n),
          const SizedBox(height: 16),
          _buildPayChannelSelector(l10n),
          const SizedBox(height: 16),
          _buildPayerInfoInput(l10n),
          const SizedBox(height: 16),
          _buildRemarkInput(l10n),
          const SizedBox(height: 20),
          _buildConfirmCheckbox(l10n),
          const SizedBox(height: 20),
          _buildSubmitButton(l10n, isUsdt: false),
          const SizedBox(height: 16),
          _buildOfflineTips(l10n),
        ],
      ),
    );
  }

  /// 获取可用的付款渠道
  List<int> get _availableChannels {
    final channels = <int>[];
    if (widget.config.bankRechargeEnabled) channels.add(RechargePayChannel.bank);
    if (widget.config.alipayRechargeEnabled) channels.add(RechargePayChannel.alipay);
    if (widget.config.wechatRechargeEnabled) channels.add(RechargePayChannel.wechat);
    return channels;
  }

  Widget _buildPayChannelSelector(AppLocalizations l10n) {
    final channels = _availableChannels;

    // 如果当前选择的渠道不可用，自动切换到第一个可用渠道
    if (!channels.contains(_payChannel) && channels.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _payChannel = channels.first);
        _loadAccountForChannel();
      });
    }

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
            l10n.translate('payment_method'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (widget.config.bankRechargeEnabled)
                _buildChannelChip(RechargePayChannel.bank, l10n.translate('bank_card'), Icons.account_balance),
              if (widget.config.alipayRechargeEnabled)
                _buildChannelChip(RechargePayChannel.alipay, l10n.translate('alipay'), Icons.payment),
              if (widget.config.wechatRechargeEnabled)
                _buildChannelChip(RechargePayChannel.wechat, l10n.translate('wechat'), Icons.chat),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelChip(int channel, String label, IconData icon) {
    final isSelected = _payChannel == channel;
    return GestureDetector(
      onTap: () {
        setState(() => _payChannel = channel);
        _loadAccountForChannel();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF4CAF50) : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayerInfoInput(AppLocalizations l10n) {
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
            l10n.translate('payer_info'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.translate('payer_info_desc'),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _payerNameController,
            decoration: InputDecoration(
              labelText: l10n.translate('payer_name'),
              hintText: l10n.translate('enter_payer_name'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _payerAccountController,
            decoration: InputDecoration(
              labelText: _getAccountLabel(l10n),
              hintText: _getAccountHint(l10n),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          if (_payChannel == RechargePayChannel.bank) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _payerBankNameController,
              decoration: InputDecoration(
                labelText: l10n.translate('bank_name'),
                hintText: l10n.translate('enter_bank_name'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getAccountLabel(AppLocalizations l10n) {
    switch (_payChannel) {
      case RechargePayChannel.alipay:
        return l10n.translate('alipay_account');
      case RechargePayChannel.wechat:
        return l10n.translate('wechat_id');
      default:
        return l10n.translate('bank_card_number');
    }
  }

  String _getAccountHint(AppLocalizations l10n) {
    switch (_payChannel) {
      case RechargePayChannel.alipay:
        return l10n.translate('enter_alipay_account');
      case RechargePayChannel.wechat:
        return l10n.translate('enter_wechat_id');
      default:
        return l10n.translate('enter_bank_card_number');
    }
  }

  Widget _buildOfflineTips(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFFFA000), size: 18),
              const SizedBox(width: 8),
              Text(l10n.translate('recharge_tips'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFA000))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1. ${l10n.translate('recharge_tips_1')}\n'
            '2. ${l10n.translate('recharge_tips_2')}\n'
            '3. ${l10n.translate('recharge_tips_3')}\n'
            '4. ${l10n.translate('recharge_tips_4').replaceAll('{min}', widget.config.rechargeMinAmount.toStringAsFixed(0)).replaceAll('{max}', widget.config.rechargeMaxAmount.toStringAsFixed(0))}',
            style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ==================== USDT支付 ====================
  Widget _buildUsdtTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAmountInput(l10n),
          const SizedBox(height: 16),
          _buildUsdtInfo(l10n),
          const SizedBox(height: 16),
          _buildPayerWalletInput(l10n),
          const SizedBox(height: 16),
          _buildRemarkInput(l10n),
          const SizedBox(height: 20),
          _buildConfirmCheckbox(l10n),
          const SizedBox(height: 20),
          _buildSubmitButton(l10n, isUsdt: true),
          const SizedBox(height: 16),
          _buildUsdtTips(l10n),
        ],
      ),
    );
  }

  Widget _buildUsdtInfo(AppLocalizations l10n) {
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
            l10n.translate('platform_receive_address'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    widget.config.usdtWalletAddress.isNotEmpty
                        ? widget.config.usdtWalletAddress
                        : l10n.translate('contact_support_for_address'),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  ),
                ),
                if (widget.config.usdtWalletAddress.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.config.usdtWalletAddress));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.copiedToClipboard)),
                      );
                    },
                    tooltip: l10n.translate('copy_address'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.translate('network_label')}: ${widget.config.usdtNetwork}  |  ${l10n.translate('rate_label')}: 1 USDT ≈ ¥${widget.config.usdtRate}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.support_agent, size: 16, color: Color(0xFF1976D2)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.translate('contact_support_before_transfer'),
                    style: TextStyle(color: Colors.blue[800], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayerWalletInput(AppLocalizations l10n) {
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
            l10n.translate('your_wallet_info'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.translate('your_wallet_info_desc'),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _payerWalletAddressController,
            decoration: InputDecoration(
              labelText: l10n.translate('your_usdt_wallet'),
              hintText: l10n.translate('enter_your_wallet'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usdtAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}'))],
            decoration: InputDecoration(
              labelText: l10n.translate('usdt_quantity'),
              hintText: l10n.translate('enter_usdt_quantity'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _txHashController,
            decoration: InputDecoration(
              labelText: l10n.translate('tx_hash_optional'),
              hintText: l10n.translate('enter_tx_hash'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsdtTips(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFFFA000), size: 18),
              const SizedBox(width: 8),
              Text(l10n.translate('usdt_recharge_tips'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFA000))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1. ${l10n.translate('usdt_tips_1')}\n'
            '2. ${l10n.translate('usdt_tips_2').replaceAll('{network}', widget.config.usdtNetwork)}\n'
            '3. ${l10n.translate('usdt_tips_3')}\n'
            '4. ${l10n.translate('usdt_tips_4')}\n'
            '5. ${l10n.translate('usdt_tips_5')}',
            style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ==================== 通用组件 ====================
  Widget _buildAmountInput(AppLocalizations l10n) {
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
            l10n.translate('recharge_amount_yuan'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: '¥ ',
              prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              hintText: l10n.translate('enter_amount'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.translate('recharge_range')}: ¥${widget.config.rechargeMinAmount.toStringAsFixed(0)} - ¥${widget.config.rechargeMaxAmount.toStringAsFixed(0)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarkInput(AppLocalizations l10n) {
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
            l10n.translate('remark_optional'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _remarkController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: l10n.translate('enter_remark'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmCheckbox(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _confirmed ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _confirmed ? const Color(0xFF4CAF50) : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _confirmed,
            onChanged: (value) => setState(() => _confirmed = value ?? false),
            activeColor: const Color(0xFF4CAF50),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _confirmed = !_confirmed),
              child: Text(
                l10n.translate('confirm_info_correct'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(AppLocalizations l10n, {required bool isUsdt}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (_isSubmitting || !_confirmed) ? null : () => _submitRecharge(isUsdt),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : Text(l10n.translate('submit_recharge'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Future<void> _submitRecharge(bool isUsdt) async {
    final l10n = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountController.text) ?? 0;

    // 验证金额
    if (amount < widget.config.rechargeMinAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('min_recharge_amount').replaceAll('{amount}', widget.config.rechargeMinAmount.toStringAsFixed(0)))),
      );
      return;
    }
    if (amount > widget.config.rechargeMaxAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('max_recharge_amount').replaceAll('{amount}', widget.config.rechargeMaxAmount.toStringAsFixed(0)))),
      );
      return;
    }

    if (isUsdt) {
      // USDT验证
      if (_payerWalletAddressController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('enter_usdt_wallet_required'))));
        return;
      }
    } else {
      // 线下转账验证
      if (_payerNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('enter_payer_name_required'))));
        return;
      }
      if (_payerAccountController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.translate('enter_payer_name_required').split(' ').first} ${_getAccountLabel(l10n)}')));
        return;
      }
      if (_payChannel == RechargePayChannel.bank && _payerBankNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('enter_bank_name_required'))));
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await _walletApi.createRecharge(
        method: isUsdt ? RechargeMethod.usdt : RechargeMethod.offline,
        amount: amount,
        // 线下转账信息
        payChannel: isUsdt ? null : _payChannel,
        payerName: isUsdt ? null : _payerNameController.text,
        payerAccount: isUsdt ? null : _payerAccountController.text,
        payerBankName: (_payChannel == RechargePayChannel.bank && !isUsdt) ? _payerBankNameController.text : null,
        // USDT信息
        payerWalletAddress: isUsdt ? _payerWalletAddressController.text : null,
        usdtAmount: isUsdt ? (double.tryParse(_usdtAmountController.text)) : null,
        txHash: isUsdt && _txHashController.text.isNotEmpty ? _txHashController.text : null,
        // 其他
        remark: _remarkController.text.isNotEmpty ? _remarkController.text : null,
      );

      if (response.success) {
        // 保存用户的支付账户信息，方便下次自动填充
        await _savePaymentAccount();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('recharge_submitted'))),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message ?? l10n.translate('submit_failed'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('submit_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
