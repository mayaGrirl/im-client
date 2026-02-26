/// 提现页面（线下转账 / USDT）
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/wallet_api.dart';
import 'package:im_client/api/upload_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';

class WithdrawScreen extends StatefulWidget {
  final WalletConfig config;
  final double balance;

  const WithdrawScreen({
    super.key,
    required this.config,
    required this.balance,
  });

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> with SingleTickerProviderStateMixin {
  final WalletApi _walletApi = WalletApi(ApiClient());
  TabController? _tabController;

  // 通用
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _payPasswordController = TextEditingController();

  // 线下转账收款信息
  int _channel = WithdrawChannel.bank;
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _accountNoController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();

  // USDT收款信息
  final TextEditingController _walletAddressController = TextEditingController();

  // 收款二维码
  String? _receiveQrcode;
  bool _isUploadingQrcode = false;

  bool _isSubmitting = false;
  bool _showPassword = false;
  bool _confirmed = false;
  PaymentAccount? _savedAccount;

  /// 是否显示USDT选项
  bool get _showUsdt => widget.config.usdtWithdrawEnabled;

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
      _accountNameController.text = _savedAccount!.getAccountName(_channel);
      _accountNoController.text = _savedAccount!.getAccountNo(_channel);
      if (_channel == WithdrawChannel.bank) {
        _bankNameController.text = _savedAccount!.bankName;
      }
      // 加载收款二维码
      final qrcode = _savedAccount!.getReceiveQrcode(_channel);
      setState(() {
        _receiveQrcode = qrcode.isNotEmpty ? qrcode : null;
      });
    }
    // USDT Tab
    else if (_showUsdt) {
      _walletAddressController.text = _savedAccount!.usdtWalletAddress;
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
          bankAccountName: _channel == WithdrawChannel.bank ? _accountNameController.text : account.bankAccountName,
          bankAccountNo: _channel == WithdrawChannel.bank ? _accountNoController.text : account.bankAccountNo,
          bankName: _channel == WithdrawChannel.bank ? _bankNameController.text : account.bankName,
          alipayAccountName: _channel == WithdrawChannel.alipay ? _accountNameController.text : account.alipayAccountName,
          alipayAccountNo: _channel == WithdrawChannel.alipay ? _accountNoController.text : account.alipayAccountNo,
          alipayReceiveQrcode: _channel == WithdrawChannel.alipay ? (_receiveQrcode ?? '') : account.alipayReceiveQrcode,
          wechatAccountName: _channel == WithdrawChannel.wechat ? _accountNameController.text : account.wechatAccountName,
          wechatAccountNo: _channel == WithdrawChannel.wechat ? _accountNoController.text : account.wechatAccountNo,
          wechatReceiveQrcode: _channel == WithdrawChannel.wechat ? (_receiveQrcode ?? '') : account.wechatReceiveQrcode,
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
          alipayReceiveQrcode: account.alipayReceiveQrcode,
          wechatAccountName: account.wechatAccountName,
          wechatAccountNo: account.wechatAccountNo,
          wechatReceiveQrcode: account.wechatReceiveQrcode,
          usdtWalletAddress: _walletAddressController.text,
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
    _payPasswordController.dispose();
    _accountNameController.dispose();
    _accountNoController.dispose();
    _bankNameController.dispose();
    _walletAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(l10n.withdraw),
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
                  if (_showUsdt) const Tab(text: 'USDT'),
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
          _buildBalanceCard(l10n),
          const SizedBox(height: 16),
          _buildAmountInput(l10n),
          const SizedBox(height: 16),
          _buildChannelSelector(l10n),
          const SizedBox(height: 16),
          _buildAccountInfoInput(l10n),
          const SizedBox(height: 16),
          _buildRemarkInput(l10n),
          const SizedBox(height: 16),
          _buildPasswordInput(l10n),
          const SizedBox(height: 16),
          _buildFeeInfo(l10n),
          const SizedBox(height: 20),
          _buildConfirmCheckbox(l10n),
          const SizedBox(height: 20),
          _buildSubmitButton(l10n, isUsdt: false),
          const SizedBox(height: 16),
          _buildTips(l10n),
        ],
      ),
    );
  }

  /// 获取可用的收款渠道
  List<int> get _availableChannels {
    final channels = <int>[];
    if (widget.config.bankWithdrawEnabled) channels.add(WithdrawChannel.bank);
    if (widget.config.alipayWithdrawEnabled) channels.add(WithdrawChannel.alipay);
    if (widget.config.wechatWithdrawEnabled) channels.add(WithdrawChannel.wechat);
    return channels;
  }

  Widget _buildChannelSelector(AppLocalizations l10n) {
    final channels = _availableChannels;

    // 如果当前选择的渠道不可用，自动切换到第一个可用渠道
    if (!channels.contains(_channel) && channels.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _channel = channels.first);
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
            l10n.translate('receive_method'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (widget.config.bankWithdrawEnabled)
                _buildChannelChip(WithdrawChannel.bank, l10n.translate('bank_card'), Icons.account_balance),
              if (widget.config.alipayWithdrawEnabled)
                _buildChannelChip(WithdrawChannel.alipay, l10n.translate('alipay'), Icons.payment),
              if (widget.config.wechatWithdrawEnabled)
                _buildChannelChip(WithdrawChannel.wechat, l10n.translate('wechat'), Icons.chat),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelChip(int channel, String label, IconData icon) {
    final isSelected = _channel == channel;
    return GestureDetector(
      onTap: () {
        setState(() => _channel = channel);
        _loadAccountForChannel();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF9800).withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF9800) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFFF9800) : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFFF9800) : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfoInput(AppLocalizations l10n) {
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
            l10n.translate('receive_account_info'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.translate('receive_account_desc'),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountNameController,
            decoration: InputDecoration(
              labelText: l10n.translate('receiver_name'),
              hintText: l10n.translate('enter_receiver_name'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountNoController,
            decoration: InputDecoration(
              labelText: _getAccountLabel(l10n),
              hintText: _getAccountHint(l10n),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          if (_channel == WithdrawChannel.bank) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _bankNameController,
              decoration: InputDecoration(
                labelText: l10n.translate('bank_name'),
                hintText: l10n.translate('enter_bank_name'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
          // 支付宝/微信显示收款二维码上传
          if (_channel == WithdrawChannel.alipay || _channel == WithdrawChannel.wechat) ...[
            const SizedBox(height: 16),
            _buildQrcodeUpload(l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildQrcodeUpload(AppLocalizations l10n) {
    final channelName = _channel == WithdrawChannel.alipay ? l10n.translate('alipay') : l10n.translate('wechat');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('receive_qrcode').replaceAll('{channel}', channelName),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.translate('qrcode_speed_up'),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isUploadingQrcode ? null : _pickAndUploadQrcode,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _isUploadingQrcode
                ? const Center(child: CircularProgressIndicator())
                : _receiveQrcode != null && _receiveQrcode!.isNotEmpty
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              EnvConfig.instance.getFileUrl(_receiveQrcode!),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image,
                                size: 40,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _receiveQrcode = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            l10n.translate('click_upload'),
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadQrcode() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    setState(() => _isUploadingQrcode = true);

    try {
      final uploadApi = UploadApi(ApiClient());
      UploadResult? result;

      if (kIsWeb) {
        // Web平台：读取字节数据上传
        final bytes = await pickedFile.readAsBytes();
        result = await uploadApi.uploadImage(bytes, type: 'qrcode', filename: pickedFile.name);
      } else {
        // 移动平台：使用文件路径上传
        result = await uploadApi.uploadImage(File(pickedFile.path), type: 'qrcode');
      }

      if (result != null && result.url.isNotEmpty) {
        setState(() {
          _receiveQrcode = result!.url;
        });
      } else {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('upload_failed'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('upload_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingQrcode = false);
      }
    }
  }

  String _getAccountLabel(AppLocalizations l10n) {
    switch (_channel) {
      case WithdrawChannel.alipay:
        return l10n.translate('alipay_account');
      case WithdrawChannel.wechat:
        return l10n.translate('wechat_id');
      default:
        return l10n.translate('bank_card_number');
    }
  }

  String _getAccountHint(AppLocalizations l10n) {
    switch (_channel) {
      case WithdrawChannel.alipay:
        return l10n.translate('enter_receive_alipay');
      case WithdrawChannel.wechat:
        return l10n.translate('enter_receive_wechat');
      default:
        return l10n.translate('enter_receive_bank');
    }
  }

  // ==================== USDT ====================
  Widget _buildUsdtTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBalanceCard(l10n),
          const SizedBox(height: 16),
          _buildAmountInput(l10n),
          const SizedBox(height: 16),
          _buildUsdtAccountInput(l10n),
          const SizedBox(height: 16),
          _buildRemarkInput(l10n),
          const SizedBox(height: 16),
          _buildPasswordInput(l10n),
          const SizedBox(height: 16),
          _buildFeeInfo(l10n),
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

  Widget _buildUsdtAccountInput(AppLocalizations l10n) {
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
            l10n.translate('receive_wallet_address'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.translate('receive_wallet_desc'),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _walletAddressController,
            decoration: InputDecoration(
              labelText: l10n.translate('usdt_wallet_address'),
              hintText: l10n.translate('enter_usdt_receive'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.translate('network_label')}: ${widget.config.usdtNetwork}  |  ${l10n.translate('rate_label')}: 1 USDT ≈ ¥${widget.config.usdtRate}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
              Text(l10n.translate('usdt_withdraw_tips'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFA000))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1. ${l10n.translate('usdt_withdraw_tips_1').replaceAll('{network}', widget.config.usdtNetwork)}\n'
            '2. ${l10n.translate('usdt_withdraw_tips_2')}\n'
            '3. ${l10n.translate('usdt_withdraw_tips_3')}',
            style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ==================== 通用组件 ====================
  Widget _buildBalanceCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.translate('withdrawable_balance'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                '¥${widget.balance.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: _withdrawAll,
            child: Text(l10n.translate('withdraw_all'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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
          Text(l10n.translate('withdraw_amount'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.translate('withdraw_range')}: ¥${widget.config.withdrawMinAmount.toStringAsFixed(0)} - ¥${widget.config.withdrawMaxAmount.toStringAsFixed(0)}',
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
          Text(l10n.translate('remark_optional'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          Text(l10n.payPassword, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _buildFeeInfo(AppLocalizations l10n) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final feeRate = widget.config.withdrawFeeRate;
    final fee = amount * feeRate + widget.config.withdrawFixedFee;
    final actualAmount = amount - fee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoRow(l10n.translate('withdraw_amount'), '¥${amount.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildInfoRow(
            '${l10n.translate('fee')} (${(feeRate * 100).toStringAsFixed(1)}%${widget.config.withdrawFixedFee > 0 ? ' + ¥${widget.config.withdrawFixedFee.toStringAsFixed(0)}' : ''})',
            '-¥${fee.toStringAsFixed(2)}',
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.translate('actual_amount'), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '¥${actualAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFFF9800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildConfirmCheckbox(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _confirmed ? const Color(0xFFFFF3E0) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _confirmed ? const Color(0xFFFF9800) : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _confirmed,
            onChanged: (value) => setState(() => _confirmed = value ?? false),
            activeColor: const Color(0xFFFF9800),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _confirmed = !_confirmed),
              child: Text(
                l10n.translate('confirm_receive_correct'),
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
        onPressed: (_isSubmitting || !_confirmed) ? null : () => _submitWithdraw(isUsdt),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF9800),
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : Text(l10n.translate('submit_withdraw'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildTips(AppLocalizations l10n) {
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
              Text(l10n.translate('withdraw_tips'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFA000))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1. ${l10n.translate('withdraw_tips_1').replaceAll('{limit}', '${widget.config.withdrawDailyLimit}')}\n'
            '2. ${l10n.translate('withdraw_tips_2').replaceAll('{count}', '${widget.config.withdrawExtraFeeCount}').replaceAll('{rate}', (widget.config.withdrawExtraFeeRate * 100).toStringAsFixed(1))}\n'
            '3. ${l10n.translate('withdraw_tips_3')}\n'
            '4. ${l10n.translate('withdraw_tips_4')}',
            style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  void _withdrawAll() {
    final maxAmount = widget.balance > widget.config.withdrawMaxAmount
        ? widget.config.withdrawMaxAmount
        : widget.balance;
    _amountController.text = maxAmount.toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _submitWithdraw(bool isUsdt) async {
    final l10n = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountController.text) ?? 0;

    // 验证金额
    if (amount < widget.config.withdrawMinAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('min_withdraw_amount').replaceAll('{amount}', widget.config.withdrawMinAmount.toStringAsFixed(0)))),
      );
      return;
    }
    if (amount > widget.config.withdrawMaxAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('max_withdraw_amount').replaceAll('{amount}', widget.config.withdrawMaxAmount.toStringAsFixed(0)))),
      );
      return;
    }
    if (amount > widget.balance) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('insufficient_balance'))));
      return;
    }

    // 验证收款信息
    if (isUsdt) {
      if (_walletAddressController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('enter_usdt_address'))));
        return;
      }
    } else {
      if (_accountNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('enter_receiver_name_required'))));
        return;
      }
      if (_accountNoController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.translate('enter_receiver_name_required').split(' ').first} ${_getAccountLabel(l10n)}')));
        return;
      }
      if (_channel == WithdrawChannel.bank && _bankNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('enter_bank_name_required'))));
        return;
      }
    }

    // 验证支付密码
    if (_payPasswordController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('enter_pay_password'))));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await _walletApi.createWithdraw(
        method: isUsdt ? WithdrawMethod.usdt : WithdrawMethod.offline,
        amount: amount,
        payPassword: _payPasswordController.text,
        // 线下转账收款信息
        channel: isUsdt ? null : _channel,
        accountName: isUsdt ? null : _accountNameController.text,
        accountNo: isUsdt ? null : _accountNoController.text,
        bankName: (_channel == WithdrawChannel.bank && !isUsdt) ? _bankNameController.text : null,
        receiveQrcode: (!isUsdt && (_channel == WithdrawChannel.alipay || _channel == WithdrawChannel.wechat)) ? _receiveQrcode : null,
        // USDT收款信息
        walletAddress: isUsdt ? _walletAddressController.text : null,
        // 其他
        remark: _remarkController.text.isNotEmpty ? _remarkController.text : null,
      );

      if (response.success) {
        // 保存用户的收款账户信息，方便下次自动填充
        await _savePaymentAccount();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('withdraw_submitted'))),
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
