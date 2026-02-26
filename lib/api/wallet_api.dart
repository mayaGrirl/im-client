/// 钱包API
/// 钱包、充值、提现、兑换相关接口

import 'package:im_client/api/api_client.dart';

class WalletApi {
  final ApiClient _client;

  WalletApi(this._client);

  // ==================== 钱包信息 ====================

  /// 获取完整钱包信息（包含配置）
  Future<ApiResponse> getWalletFullInfo() {
    return _client.get('/wallet/full-info');
  }

  /// 获取钱包流水
  Future<ApiResponse> getWalletLogs({
    int page = 1,
    int pageSize = 20,
    int? type,
  }) {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (type != null) params['type'] = type.toString();
    return _client.get('/wallet/logs', queryParameters: params);
  }

  // ==================== 支付账户 ====================

  /// 获取用户支付账户信息
  Future<ApiResponse> getPaymentAccount() {
    return _client.get('/wallet/payment-account');
  }

  /// 更新用户支付账户信息
  Future<ApiResponse> updatePaymentAccount({
    String? bankAccountName,
    String? bankAccountNo,
    String? bankName,
    String? alipayAccountName,
    String? alipayAccountNo,
    String? alipayReceiveQrcode,
    String? wechatAccountName,
    String? wechatAccountNo,
    String? wechatReceiveQrcode,
    String? usdtWalletAddress,
  }) {
    return _client.post('/wallet/payment-account', data: {
      'bank_account_name': bankAccountName ?? '',
      'bank_account_no': bankAccountNo ?? '',
      'bank_name': bankName ?? '',
      'alipay_account_name': alipayAccountName ?? '',
      'alipay_account_no': alipayAccountNo ?? '',
      'alipay_receive_qrcode': alipayReceiveQrcode ?? '',
      'wechat_account_name': wechatAccountName ?? '',
      'wechat_account_no': wechatAccountNo ?? '',
      'wechat_receive_qrcode': wechatReceiveQrcode ?? '',
      'usdt_wallet_address': usdtWalletAddress ?? '',
    });
  }

  // ==================== 充值 ====================

  /// 创建充值订单
  /// [method] 充值方式：1线下转账 2USDT
  /// [amount] 充值金额（元）
  /// 线下转账时：[payChannel] 付款渠道, [payerName] 付款人姓名, [payerAccount] 付款账号, [payerBankName] 付款银行
  /// USDT时：[payerWalletAddress] 付款人钱包地址, [usdtAmount] USDT数量, [txHash] 交易哈希
  Future<ApiResponse> createRecharge({
    required int method,
    required double amount,
    // 线下转账信息
    int? payChannel,
    String? payerName,
    String? payerAccount,
    String? payerBankName,
    // USDT信息
    String? payerWalletAddress,
    double? usdtAmount,
    String? txHash,
    // 其他
    String? paymentProof,
    String? remark,
  }) {
    return _client.post('/wallet/recharge/create', data: {
      'method': method,
      'amount': amount,
      if (payChannel != null) 'pay_channel': payChannel,
      if (payerName != null) 'payer_name': payerName,
      if (payerAccount != null) 'payer_account': payerAccount,
      if (payerBankName != null) 'payer_bank_name': payerBankName,
      if (payerWalletAddress != null) 'payer_wallet_address': payerWalletAddress,
      if (usdtAmount != null) 'usdt_amount': usdtAmount,
      if (txHash != null) 'tx_hash': txHash,
      if (paymentProof != null) 'payment_proof': paymentProof,
      if (remark != null) 'remark': remark,
    });
  }

  /// 获取充值记录
  Future<ApiResponse> getRechargeRecords({
    int page = 1,
    int pageSize = 20,
    int? status,
  }) {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (status != null) params['status'] = status.toString();
    return _client.get('/wallet/recharge/records', queryParameters: params);
  }

  /// 取消充值
  Future<ApiResponse> cancelRecharge(String orderNo) {
    return _client.post('/wallet/recharge/cancel/$orderNo');
  }

  // ==================== 提现 ====================

  /// 创建提现订单
  /// [method] 提现方式：1线下转账 2USDT
  /// [amount] 提现金额
  /// [payPassword] 支付密码
  /// 线下转账时：[channel] 收款渠道, [accountName] 收款人姓名, [accountNo] 收款账号, [bankName] 开户银行, [receiveQrcode] 收款二维码
  /// USDT时：[walletAddress] USDT钱包地址
  Future<ApiResponse> createWithdraw({
    required int method,
    required double amount,
    required String payPassword,
    // 线下转账收款信息
    int? channel,
    String? accountName,
    String? accountNo,
    String? bankName,
    String? receiveQrcode,
    // USDT收款信息
    String? walletAddress,
    // 其他
    String? remark,
  }) {
    return _client.post('/wallet/withdraw/create', data: {
      'method': method,
      'amount': amount,
      'pay_password': payPassword,
      if (channel != null) 'channel': channel,
      if (accountName != null) 'account_name': accountName,
      if (accountNo != null) 'account_no': accountNo,
      if (bankName != null) 'bank_name': bankName,
      if (receiveQrcode != null) 'receive_qrcode': receiveQrcode,
      if (walletAddress != null) 'wallet_address': walletAddress,
      if (remark != null) 'remark': remark,
    });
  }

  /// 获取提现记录
  Future<ApiResponse> getWithdrawRecords({
    int page = 1,
    int pageSize = 20,
    int? status,
  }) {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (status != null) params['status'] = status.toString();
    return _client.get('/wallet/withdraw/records', queryParameters: params);
  }

  /// 取消提现
  Future<ApiResponse> cancelWithdraw(String orderNo) {
    return _client.post('/wallet/withdraw/cancel/$orderNo');
  }

  // ==================== 兑换 ====================

  /// 元兑换金豆
  Future<ApiResponse> exchangeYuanToBean({
    required double yuanAmount,
    required String payPassword,
  }) {
    return _client.post('/wallet/exchange/yuan-to-bean', data: {
      'yuan_amount': yuanAmount,
      'pay_password': payPassword,
    });
  }

  /// 金豆兑换元
  Future<ApiResponse> exchangeBeanToYuan({
    required int beanAmount,
    required String payPassword,
  }) {
    return _client.post('/wallet/exchange/bean-to-yuan', data: {
      'bean_amount': beanAmount,
      'pay_password': payPassword,
    });
  }

  /// 获取兑换记录
  Future<ApiResponse> getExchangeRecords({
    int page = 1,
    int pageSize = 20,
    int? type,
  }) {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (type != null) params['type'] = type.toString();
    return _client.get('/wallet/exchange/records', queryParameters: params);
  }
}

// ==================== 数据模型 ====================

/// 用户支付账户信息
class PaymentAccount {
  final String bankAccountName;
  final String bankAccountNo;
  final String bankName;
  final String alipayAccountName;
  final String alipayAccountNo;
  final String alipayReceiveQrcode;
  final String wechatAccountName;
  final String wechatAccountNo;
  final String wechatReceiveQrcode;
  final String usdtWalletAddress;

  PaymentAccount({
    required this.bankAccountName,
    required this.bankAccountNo,
    required this.bankName,
    required this.alipayAccountName,
    required this.alipayAccountNo,
    required this.alipayReceiveQrcode,
    required this.wechatAccountName,
    required this.wechatAccountNo,
    required this.wechatReceiveQrcode,
    required this.usdtWalletAddress,
  });

  factory PaymentAccount.fromJson(Map<String, dynamic> json) {
    return PaymentAccount(
      bankAccountName: json['bank_account_name'] ?? '',
      bankAccountNo: json['bank_account_no'] ?? '',
      bankName: json['bank_name'] ?? '',
      alipayAccountName: json['alipay_account_name'] ?? '',
      alipayAccountNo: json['alipay_account_no'] ?? '',
      alipayReceiveQrcode: json['alipay_receive_qrcode'] ?? '',
      wechatAccountName: json['wechat_account_name'] ?? '',
      wechatAccountNo: json['wechat_account_no'] ?? '',
      wechatReceiveQrcode: json['wechat_receive_qrcode'] ?? '',
      usdtWalletAddress: json['usdt_wallet_address'] ?? '',
    );
  }

  /// 创建空的支付账户对象
  factory PaymentAccount.empty() {
    return PaymentAccount(
      bankAccountName: '',
      bankAccountNo: '',
      bankName: '',
      alipayAccountName: '',
      alipayAccountNo: '',
      alipayReceiveQrcode: '',
      wechatAccountName: '',
      wechatAccountNo: '',
      wechatReceiveQrcode: '',
      usdtWalletAddress: '',
    );
  }

  /// 根据渠道获取户名
  String getAccountName(int channel) {
    switch (channel) {
      case 1: return bankAccountName;
      case 2: return alipayAccountName;
      case 3: return wechatAccountName;
      default: return '';
    }
  }

  /// 根据渠道获取账号
  String getAccountNo(int channel) {
    switch (channel) {
      case 1: return bankAccountNo;
      case 2: return alipayAccountNo;
      case 3: return wechatAccountNo;
      default: return '';
    }
  }

  /// 根据渠道获取收款二维码
  String getReceiveQrcode(int channel) {
    switch (channel) {
      case 2: return alipayReceiveQrcode;
      case 3: return wechatReceiveQrcode;
      default: return '';
    }
  }
}

/// 钱包信息
class WalletInfo {
  final double balance;
  final double frozenBalance;
  final int goldBeans;
  final double totalRecharge;
  final double totalWithdraw;

  WalletInfo({
    required this.balance,
    required this.frozenBalance,
    required this.goldBeans,
    required this.totalRecharge,
    required this.totalWithdraw,
  });

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      balance: (json['balance'] ?? 0).toDouble(),
      frozenBalance: (json['frozen_balance'] ?? 0).toDouble(),
      goldBeans: json['gold_beans'] ?? 0,
      totalRecharge: (json['total_recharge'] ?? 0).toDouble(),
      totalWithdraw: (json['total_withdraw'] ?? 0).toDouble(),
    );
  }
}

/// 钱包配置
class WalletConfig {
  final double yuanToBeanRate;
  final double beanToYuanRate;
  final double usdtRate;
  final String usdtWalletAddress;
  final String usdtNetwork;
  final double rechargeMinAmount;
  final double rechargeMaxAmount;
  final double rechargeDailyLimit;
  final double rechargeFeeRate;
  final double withdrawMinAmount;
  final double withdrawMaxAmount;
  final int withdrawDailyLimit;
  final double withdrawFeeRate;
  final int withdrawExtraFeeCount;
  final double withdrawExtraFeeRate;
  final double withdrawFixedFee;
  final double largeWithdrawThreshold;
  final double vipFeeDiscount;
  final String? customerServiceWechat;
  final String? customerServiceQQ;
  final String? customerServicePhone;
  final String? customerServiceQRCode;
  final bool rechargeEnabled;
  final bool withdrawEnabled;
  final bool exchangeEnabled;
  final bool usdtRechargeEnabled;
  final bool usdtWithdrawEnabled;
  // 充值收款方式开关
  final bool bankRechargeEnabled;
  final bool alipayRechargeEnabled;
  final bool wechatRechargeEnabled;
  // 提现收款方式开关
  final bool bankWithdrawEnabled;
  final bool alipayWithdrawEnabled;
  final bool wechatWithdrawEnabled;
  final String? notice;

  WalletConfig({
    required this.yuanToBeanRate,
    required this.beanToYuanRate,
    required this.usdtRate,
    required this.usdtWalletAddress,
    required this.usdtNetwork,
    required this.rechargeMinAmount,
    required this.rechargeMaxAmount,
    required this.rechargeDailyLimit,
    required this.rechargeFeeRate,
    required this.withdrawMinAmount,
    required this.withdrawMaxAmount,
    required this.withdrawDailyLimit,
    required this.withdrawFeeRate,
    required this.withdrawExtraFeeCount,
    required this.withdrawExtraFeeRate,
    required this.withdrawFixedFee,
    required this.largeWithdrawThreshold,
    required this.vipFeeDiscount,
    this.customerServiceWechat,
    this.customerServiceQQ,
    this.customerServicePhone,
    this.customerServiceQRCode,
    required this.rechargeEnabled,
    required this.withdrawEnabled,
    required this.exchangeEnabled,
    required this.usdtRechargeEnabled,
    required this.usdtWithdrawEnabled,
    required this.bankRechargeEnabled,
    required this.alipayRechargeEnabled,
    required this.wechatRechargeEnabled,
    required this.bankWithdrawEnabled,
    required this.alipayWithdrawEnabled,
    required this.wechatWithdrawEnabled,
    this.notice,
  });

  factory WalletConfig.fromJson(Map<String, dynamic> json) {
    return WalletConfig(
      yuanToBeanRate: (json['yuan_to_bean_rate'] ?? 1000).toDouble(),
      beanToYuanRate: (json['bean_to_yuan_rate'] ?? 1000).toDouble(),
      usdtRate: (json['usdt_rate'] ?? 7.2).toDouble(),
      usdtWalletAddress: json['usdt_wallet_address'] ?? '',
      usdtNetwork: json['usdt_network'] ?? 'TRC20',
      rechargeMinAmount: (json['recharge_min_amount'] ?? 10).toDouble(),
      rechargeMaxAmount: (json['recharge_max_amount'] ?? 100000).toDouble(),
      rechargeDailyLimit: (json['recharge_daily_limit'] ?? 0).toDouble(),
      rechargeFeeRate: (json['recharge_fee_rate'] ?? 0).toDouble(),
      withdrawMinAmount: (json['withdraw_min_amount'] ?? 100).toDouble(),
      withdrawMaxAmount: (json['withdraw_max_amount'] ?? 50000).toDouble(),
      withdrawDailyLimit: json['withdraw_daily_limit'] ?? 3,
      withdrawFeeRate: (json['withdraw_fee_rate'] ?? 0.02).toDouble(),
      withdrawExtraFeeCount: json['withdraw_extra_fee_count'] ?? 2,
      withdrawExtraFeeRate: (json['withdraw_extra_fee_rate'] ?? 0.01).toDouble(),
      withdrawFixedFee: (json['withdraw_fixed_fee'] ?? 0).toDouble(),
      largeWithdrawThreshold: (json['large_withdraw_threshold'] ?? 10000).toDouble(),
      vipFeeDiscount: (json['vip_fee_discount'] ?? 0).toDouble(),
      customerServiceWechat: json['customer_service_wechat'],
      customerServiceQQ: json['customer_service_qq'],
      customerServicePhone: json['customer_service_phone'],
      customerServiceQRCode: json['customer_service_qrcode'],
      rechargeEnabled: json['recharge_enabled'] ?? true,
      withdrawEnabled: json['withdraw_enabled'] ?? true,
      exchangeEnabled: json['exchange_enabled'] ?? true,
      usdtRechargeEnabled: json['usdt_recharge_enabled'] ?? true,
      usdtWithdrawEnabled: json['usdt_withdraw_enabled'] ?? true,
      bankRechargeEnabled: json['bank_recharge_enabled'] ?? true,
      alipayRechargeEnabled: json['alipay_recharge_enabled'] ?? true,
      wechatRechargeEnabled: json['wechat_recharge_enabled'] ?? true,
      bankWithdrawEnabled: json['bank_withdraw_enabled'] ?? true,
      alipayWithdrawEnabled: json['alipay_withdraw_enabled'] ?? true,
      wechatWithdrawEnabled: json['wechat_withdraw_enabled'] ?? true,
      notice: json['notice'],
    );
  }
}

/// 完整钱包信息响应
class WalletFullInfo {
  final WalletInfo wallet;
  final WalletConfig config;
  final bool hasPayPassword;
  final bool hasPendingWithdraw;

  WalletFullInfo({
    required this.wallet,
    required this.config,
    required this.hasPayPassword,
    required this.hasPendingWithdraw,
  });

  factory WalletFullInfo.fromJson(Map<String, dynamic> json) {
    return WalletFullInfo(
      wallet: WalletInfo.fromJson(json['wallet'] ?? {}),
      config: WalletConfig.fromJson(json['config'] ?? {}),
      hasPayPassword: json['has_pay_password'] ?? false,
      hasPendingWithdraw: json['has_pending_withdraw'] ?? false,
    );
  }
}

/// 充值记录
class RechargeRecord {
  final int id;
  final String orderNo;
  final int method;
  final String methodName;
  final double amount;
  final double? usdtAmount;
  final double? usdtRate;
  final double fee;
  final double actualAmount;
  final int status;
  final String statusName;
  final String? remark;
  final String? adminRemark;
  final String createdAt;
  final String? reviewedAt;

  RechargeRecord({
    required this.id,
    required this.orderNo,
    required this.method,
    required this.methodName,
    required this.amount,
    this.usdtAmount,
    this.usdtRate,
    required this.fee,
    required this.actualAmount,
    required this.status,
    required this.statusName,
    this.remark,
    this.adminRemark,
    required this.createdAt,
    this.reviewedAt,
  });

  factory RechargeRecord.fromJson(Map<String, dynamic> json) {
    return RechargeRecord(
      id: json['id'] ?? 0,
      orderNo: json['order_no'] ?? '',
      method: json['method'] ?? 1,
      methodName: json['method_name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      usdtAmount: json['usdt_amount']?.toDouble(),
      usdtRate: json['usdt_rate']?.toDouble(),
      fee: (json['fee'] ?? 0).toDouble(),
      actualAmount: (json['actual_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 0,
      statusName: json['status_name'] ?? '',
      remark: json['remark'],
      adminRemark: json['admin_remark'],
      createdAt: json['created_at'] ?? '',
      reviewedAt: json['reviewed_at'],
    );
  }

  /// 是否可取消
  bool get canCancel => status == 0; // 待审核
}

/// 提现记录
class WithdrawRecord {
  final int id;
  final String orderNo;
  final int method;
  final String methodName;
  final double amount;
  final double fee;
  final double actualAmount;
  final int status;
  final String statusName;
  final String? accountName;
  final String? accountNo;
  final String? bankName;
  final String? walletAddress;
  final String? remark;
  final String? adminRemark;
  final String createdAt;
  final String? reviewedAt;
  final String? completedAt;

  WithdrawRecord({
    required this.id,
    required this.orderNo,
    required this.method,
    required this.methodName,
    required this.amount,
    required this.fee,
    required this.actualAmount,
    required this.status,
    required this.statusName,
    this.accountName,
    this.accountNo,
    this.bankName,
    this.walletAddress,
    this.remark,
    this.adminRemark,
    required this.createdAt,
    this.reviewedAt,
    this.completedAt,
  });

  factory WithdrawRecord.fromJson(Map<String, dynamic> json) {
    return WithdrawRecord(
      id: json['id'] ?? 0,
      orderNo: json['order_no'] ?? '',
      method: json['method'] ?? 1,
      methodName: json['method_name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      fee: (json['fee'] ?? 0).toDouble(),
      actualAmount: (json['actual_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 0,
      statusName: json['status_name'] ?? '',
      accountName: json['account_name'],
      accountNo: json['account_no'],
      bankName: json['bank_name'],
      walletAddress: json['wallet_address'],
      remark: json['remark'],
      adminRemark: json['admin_remark'],
      createdAt: json['created_at'] ?? '',
      reviewedAt: json['reviewed_at'],
      completedAt: json['completed_at'],
    );
  }

  /// 是否可取消
  bool get canCancel => status == 0; // 待审核
}

/// 兑换记录
class ExchangeRecord {
  final int id;
  final String orderNo;
  final int type;
  final String typeName;
  final double yuanAmount;
  final int beanAmount;
  final double exchangeRate;
  final String createdAt;

  ExchangeRecord({
    required this.id,
    required this.orderNo,
    required this.type,
    required this.typeName,
    required this.yuanAmount,
    required this.beanAmount,
    required this.exchangeRate,
    required this.createdAt,
  });

  factory ExchangeRecord.fromJson(Map<String, dynamic> json) {
    return ExchangeRecord(
      id: json['id'] ?? 0,
      orderNo: json['order_no'] ?? '',
      type: json['type'] ?? 1,
      typeName: json['type_name'] ?? '',
      yuanAmount: (json['yuan_amount'] ?? 0).toDouble(),
      beanAmount: json['bean_amount'] ?? 0,
      exchangeRate: (json['exchange_rate'] ?? 1000).toDouble(),
      createdAt: json['created_at'] ?? '',
    );
  }
}

/// 钱包流水
class WalletLog {
  final int id;
  final int type;
  final String typeName;
  final double amount;
  final int beanAmount;
  final double balanceBefore;
  final double balanceAfter;
  final int beansBefore;
  final int beansAfter;
  final String? remark;
  final String createdAt;

  WalletLog({
    required this.id,
    required this.type,
    required this.typeName,
    required this.amount,
    required this.beanAmount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.beansBefore,
    required this.beansAfter,
    this.remark,
    required this.createdAt,
  });

  factory WalletLog.fromJson(Map<String, dynamic> json) {
    return WalletLog(
      id: json['id'] ?? 0,
      type: json['type'] ?? 0,
      typeName: json['type_name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      beanAmount: json['bean_amount'] ?? 0,
      balanceBefore: (json['balance_before'] ?? 0).toDouble(),
      balanceAfter: (json['balance_after'] ?? 0).toDouble(),
      beansBefore: json['beans_before'] ?? 0,
      beansAfter: json['beans_after'] ?? 0,
      remark: json['remark'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

/// 充值方式
class RechargeMethod {
  static const int offline = 1; // 线下转账
  static const int usdt = 2; // USDT支付

  static String getName(int method) {
    switch (method) {
      case offline:
        return 'Offline Transfer';
      case usdt:
        return 'USDT Payment';
      default:
        return 'Unknown';
    }
  }
}

/// 充值付款渠道（线下转账时）
class RechargePayChannel {
  static const int bank = 1; // 银行卡
  static const int alipay = 2; // 支付宝
  static const int wechat = 3; // 微信

  static String getName(int channel) {
    switch (channel) {
      case bank:
        return 'Bank Card';
      case alipay:
        return 'Alipay';
      case wechat:
        return 'WeChat';
      default:
        return 'Unknown';
    }
  }
}

/// 提现方式
class WithdrawMethod {
  static const int offline = 1; // 线下转账
  static const int usdt = 2; // USDT

  static String getName(int method) {
    switch (method) {
      case offline:
        return 'Offline Transfer';
      case usdt:
        return 'USDT';
      default:
        return 'Unknown';
    }
  }
}

/// 提现收款渠道（线下转账时）
class WithdrawChannel {
  static const int bank = 1; // 银行卡
  static const int alipay = 2; // 支付宝
  static const int wechat = 3; // 微信

  static String getName(int channel) {
    switch (channel) {
      case bank:
        return 'Bank Card';
      case alipay:
        return 'Alipay';
      case wechat:
        return 'WeChat';
      default:
        return 'Unknown';
    }
  }
}

/// 充值状态
class RechargeStatus {
  static const int pending = 0; // 待审核
  static const int approved = 1; // 已通过
  static const int rejected = 2; // 已拒绝
  static const int canceled = 3; // 已取消

  static String getName(int status) {
    switch (status) {
      case pending:
        return 'Pending';
      case approved:
        return 'Approved';
      case rejected:
        return 'Rejected';
      case canceled:
        return 'Canceled';
      default:
        return 'Unknown';
    }
  }
}

/// 提现状态
class WithdrawStatus {
  static const int pending = 0; // 待审核
  static const int processing = 1; // 处理中
  static const int completed = 2; // 已完成
  static const int rejected = 3; // 已拒绝
  static const int canceled = 4; // 已取消

  static String getName(int status) {
    switch (status) {
      case pending:
        return 'Pending';
      case processing:
        return 'Processing';
      case completed:
        return 'Completed';
      case rejected:
        return 'Rejected';
      case canceled:
        return 'Canceled';
      default:
        return 'Unknown';
    }
  }
}

/// 兑换类型
class ExchangeType {
  static const int yuanToBean = 1; // 元兑换金豆
  static const int beanToYuan = 2; // 金豆兑换元

  static String getName(int type) {
    switch (type) {
      case yuanToBean:
        return 'Yuan to Beans';
      case beanToYuan:
        return 'Beans to Yuan';
      default:
        return 'Unknown';
    }
  }
}
