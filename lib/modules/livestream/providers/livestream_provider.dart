/// 流直播模块状态管理
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/modules/livestream/api/livestream_api.dart';
import 'package:im_client/modules/livestream/models/livestream.dart';

String _generateUUID() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

final ApiClient _walletClient = ApiClient();

class LivestreamProvider extends ChangeNotifier {
  final LivestreamApi _api = LivestreamApi(ApiClient());

  // 直播列表
  List<LivestreamRoom> _liveList = [];
  List<LivestreamRoom> get liveList => _liveList;
  int _liveTotal = 0;
  int get liveTotal => _liveTotal;
  int _livePage = 1;
  bool _liveLoading = false;
  bool get liveLoading => _liveLoading;
  bool _liveHasMore = true;
  bool get liveHasMore => _liveHasMore;

  // 关注直播列表
  List<LivestreamRoom> _followingList = [];
  List<LivestreamRoom> get followingList => _followingList;
  int _followingTotal = 0;
  int get followingTotal => _followingTotal;
  bool _followingLoading = false;
  bool get followingLoading => _followingLoading;

  /// 分类
  List<LivestreamCategory> _categories = [];
  List<LivestreamCategory> get categories => _categories;
  int? _selectedCategoryId;
  int? get selectedCategoryId => _selectedCategoryId;

  // 礼物列表
  List<LivestreamGift> _gifts = [];
  List<LivestreamGift> get gifts => _gifts;

  // 当前直播间
  LivestreamRoom? _currentRoom;
  LivestreamRoom? get currentRoom => _currentRoom;

  // 推流模式 (webrtc / rtmp)
  String _lastStreamMode = 'rtmp';
  String get lastStreamMode => _lastStreamMode;

  // 缓存的推流密钥（用于 WebRTC 推流验证）
  String? _lastPushKey;
  String? get lastPushKey => _lastPushKey;

  // 余额
  int _goldBeans = 0;
  int get goldBeans => _goldBeans;

  // 错误信息
  String? _error;
  String? get error => _error;

  // ==================== 直播列表 ====================

  /// 加载直播列表，可指定刷新
  Future<void> loadLiveList({bool refresh = false}) async {
    if (_liveLoading) return;
    if (refresh) {
      _livePage = 1;
      _liveHasMore = true;
    }
    if (!_liveHasMore) return;

    _liveLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 根据分类或推荐获取直播列表
      final res = _selectedCategoryId == null
          ? await _api.getRecommendedLives(page: _livePage, pageSize: 20)
          : await _api.getLiveList(
              page: _livePage,
              pageSize: 20,
              categoryId: _selectedCategoryId,
            );
      if (res.isSuccess) {
        final data = res.data;
        final list = (data['list'] as List? ?? [])
            .map((e) => LivestreamRoom.fromJson(e))
            .toList();
        _liveTotal = data['total'] ?? 0;

        if (refresh || _livePage == 1) {
          _liveList = list;
        } else {
          _liveList.addAll(list);
        }

        _liveHasMore = list.length >= 20;
        _livePage++;
      } else {
        _error = res.message;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _liveLoading = false;
      notifyListeners();
    }
  }

  /// 加载更多直播
  Future<void> loadMoreLives() async {
    if (_liveLoading || !_liveHasMore) return;
    await loadLiveList();
  }

  /// 刷新直播列表
  Future<void> refreshLiveList() async {
    await loadLiveList(refresh: true);
  }

  /// 选择分类
  void selectCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
    refreshLiveList();
  }

  // ====================关注直播 ====================

  /// 加载关注的直播
  Future<void> loadFollowingLives() async {
    _followingLoading = true;
    notifyListeners();

    try {
      final res = await _api.getFollowingLives();
      if (res.isSuccess) {
        final data = res.data;
        _followingList = (data['list'] as List? ?? [])
            .map((e) => LivestreamRoom.fromJson(e))
            .toList();
        _followingTotal = data['total'] ?? 0;
      }
    } catch (e) {
      debugPrint('Load following lives error: $e');
    } finally {
      _followingLoading = false;
      notifyListeners();
    }
  }

  // ==================== 分类/礼物  ====================

  /// 加载分类列表
  Future<void> loadCategories() async {
    try {
      final res = await _api.getCategories();
      if (res.isSuccess) {
        _categories = (res.data as List? ?? [])
            .map((e) => LivestreamCategory.fromJson(e))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Load categories error: $e');
    }
  }

  /// 加载礼物列表
  Future<void> loadGifts() async {
    try {
      final res = await _api.getGiftList();
      if (res.isSuccess) {
        _gifts = (res.data as List? ?? [])
            .map((e) => LivestreamGift.fromJson(e))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Load gifts error: $e');
    }
  }

  // ==================== 直播间操作 ====================

  /// 加载指定直播间信息
  Future<LivestreamRoom?> loadLivestream(int id) async {
    try {
      final res = await _api.getLivestream(id);
      if (res.isSuccess) {
        _currentRoom = LivestreamRoom.fromJson(res.data);
        // 从 API 响应中读取 stream_mode
        if (res.rawData is Map) {
          _lastStreamMode = (res.rawData as Map)['stream_mode'] as String? ?? 'rtmp';
        }
        notifyListeners();
        return _currentRoom;
      }
    } catch (e) {
      debugPrint('Load livestream error: $e');
    }
    return null;
  }

  /// 创建直播间
  Future<LivestreamRoom?> createLivestream({
    required String title,
    String? description,
    String? coverUrl,
    int? categoryId,
    int type = 0,
    bool isPaid = false,
    int ticketPrice = 0,
    int ticketPriceType = 1,
    int anchorShareRatio = 70,
    bool allowPreview = false,
    int previewDuration = 60,
    String? scheduledAt,
    int roomType = 0,
    int pricePerMin = 0,
    int trialSeconds = 0,
    bool allowPaidCall = false,
    int paidCallRate = 0,
  }) async {
    try {
      final res = await _api.createLivestream(
        title: title,
        description: description,
        coverUrl: coverUrl,
        categoryId: categoryId,
        type: type,
        isPaid: isPaid,
        ticketPrice: ticketPrice,
        ticketPriceType: ticketPriceType,
        anchorShareRatio: anchorShareRatio,
        allowPreview: allowPreview,
        previewDuration: previewDuration,
        scheduledAt: scheduledAt,
        roomType: roomType,
        pricePerMin: pricePerMin,
        trialSeconds: trialSeconds,
        allowPaidCall: allowPaidCall,
        paidCallRate: paidCallRate,
      );
      if (res.isSuccess) {
        _currentRoom = LivestreamRoom.fromJson(res.data);
        // 从 API 响应中读取 stream_mode 和 push_key
        if (res.rawData is Map) {
          final rawMap = res.rawData as Map;
          _lastStreamMode = rawMap['stream_mode'] as String? ?? 'rtmp';
          _lastPushKey = rawMap['push_key'] as String?;
        }
        notifyListeners();
        return _currentRoom;
      } else {
        _error = res.message;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
    return null;
  }

  /// 开始直播
  Future<bool> startLivestream(int id) async {
    try {
      final res = await _api.startLivestream(id);
      if (res.isSuccess) {
        _currentRoom = LivestreamRoom.fromJson(res.data);
        // 从 API 响应中读取 stream_mode 和 push_key
        if (res.rawData is Map) {
          final rawMap = res.rawData as Map;
          _lastStreamMode = rawMap['stream_mode'] as String? ?? 'rtmp';
          _lastPushKey = rawMap['push_key'] as String?;
        }
        notifyListeners();
        return true;
      }
      _error = res.message;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
    return false;
  }

  /// 结束直播
  Future<bool> endLivestream(int id) async {
    try {
      final res = await _api.endLivestream(id);
      if (res.isSuccess) {
        _currentRoom = null;
        notifyListeners();
        return true;
      }
      _error = res.message;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
    return false;
  }

  /// 加入直播间
  Future<bool> joinLivestream(int id, {String? password}) async {
    try {
      final res = await _api.joinLivestream(id, password: password);
      if (!res.isSuccess) {
        _error = res.message;
        notifyListeners();
      }
      return res.isSuccess;
    } catch (e) {
      debugPrint('Join livestream error: $e');
    }
    return false;
  }

  /// 加入付费直播间（返回是否允许、试看时长和错误信息）
  /// 返回代码 {allowed: bool, preview_duration: int, error: String?}
  Future<Map<String, dynamic>> joinPaidLivestream(int id, {bool usePreview = false}) async {
    try {
      final res = await _api.joinPaidLivestream(id, usePreview: usePreview);
      if (res.isSuccess) {
        final data = res.data as Map<String, dynamic>? ?? {};
        return {
          'allowed': data['allowed'] ?? false,
          'preview_duration': (data['preview_duration'] as num?)?.toInt() ?? 0,
        };
      }
      return {'allowed': false, 'preview_duration': 0, 'error': res.message};
    } catch (e) {
      debugPrint('Join paid livestream error: $e');
      return {'allowed': false, 'preview_duration': 0, 'error': e.toString()};
    }
  }

  /// 购买门票
  Future<bool> buyTicket(int id, {int priceType = 1}) async {
    try {
      final res = await _api.buyTicket(id, priceType: priceType);
      if (!res.isSuccess) {
        _error = res.message;
        notifyListeners();
      }
      return res.isSuccess;
    } catch (e) {
      debugPrint('Buy ticket error: $e');
    }
    return false;
  }

  /// 离开直播间
  Future<void> leaveLivestream(int id) async {
    try {
      await _api.leaveLivestream(id);
    } catch (e) {
      debugPrint('Leave livestream error: $e');
    }
    _currentRoom = null;
    notifyListeners();
  }

  /// 发送礼物（幂等）
  Future<bool> sendGift(int livestreamId, {required int giftId, int count = 1, String? message}) async {
    try {
      final idempotencyKey = _generateUUID();
      final res = await _api.sendGift(livestreamId, giftId: giftId, count: count, message: message, idempotencyKey: idempotencyKey);
      return res.isSuccess;
    } catch (e) {
      debugPrint('Send gift error: $e');
    }
    return false;
  }

  /// 发送弹幕（带重试）
  Future<String?> sendDanmakuWithRetry(int livestreamId, {required String content, String? color, int position = 0, int maxRetries = 2}) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final res = await _api.sendDanmaku(livestreamId, content: content, color: color, position: position);
        if (res.isSuccess) return null;
        return res.message ?? 'Send failed';
      } catch (e) {
        debugPrint('Send danmaku error (attempt $attempt): $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        return e.toString();
      }
    }
    return 'Send failed';
  }

  /// 发送弹幕（简单版）
  Future<bool> sendDanmaku(int livestreamId, {required String content, String? color, int position = 0}) async {
    final err = await sendDanmakuWithRetry(livestreamId, content: content, color: color, position: position);
    return err == null;
  }

  /// 检查是否已关注主播
  Future<bool> checkFollowing(int anchorId) async {
    try {
      final res = await _api.checkFollowing(anchorId);
      if (res.isSuccess) {
        return res.data?['following'] ?? false;
      }
    } catch (e) {
      debugPrint('Check following error: $e');
    }
    return false;
  }

  /// 关注主播
  Future<bool> followAnchor(int anchorId) async {
    try {
      final res = await _api.followAnchor(anchorId);
      return res.isSuccess;
    } catch (e) {
      debugPrint('Follow anchor error: $e');
    }
    return false;
  }

  /// 取消关注主播
  Future<bool> unfollowAnchor(int anchorId) async {
    try {
      final res = await _api.unfollowAnchor(anchorId);
      return res.isSuccess;
    } catch (e) {
      debugPrint('Unfollow anchor error: $e');
    }
    return false;
  }

  // ==================== 付费直播 ====================

  List<LivestreamRoom> _scheduledList = [];
  List<LivestreamRoom> get scheduledList => _scheduledList;
  bool _scheduledLoading = false;
  bool get scheduledLoading => _scheduledLoading;

  /// 加载预约直播列表
  Future<void> loadScheduledLives() async {
    _scheduledLoading = true;
    notifyListeners();

    try {
      final res = await _api.getScheduledLives();
      if (res.isSuccess) {
        final data = res.data;
        _scheduledList = (data['list'] as List? ?? [])
            .map((e) => LivestreamRoom.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('Load scheduled lives error: $e');
    } finally {
      _scheduledLoading = false;
      notifyListeners();
    }
  }

  // ==================== 预约直播 ====================

  /// 预约直播
  Future<bool> reserveLivestream(int id, {bool autoEnter = false}) async {
    try {
      final res = await _api.reserveLivestream(id, autoEnter: autoEnter);
      if (res.isSuccess) {
        final idx = _scheduledList.indexWhere((r) => r.id == id);
        if (idx >= 0) {
          loadScheduledLives();
        }
        return true;
      }
      _error = res.message;
      notifyListeners();
    } catch (e) {
      debugPrint('Reserve livestream error: $e');
    }
    return false;
  }

  /// 取消预约直播
  Future<bool> cancelScheduledLivestream(int id) async {
    try {
      final res = await _api.cancelScheduledLivestream(id);
      if (res.isSuccess) {
        _scheduledList.removeWhere((r) => r.id == id);
        notifyListeners();
        return true;
      }
      _error = res.message;
      notifyListeners();
    } catch (e) {
      debugPrint('Cancel scheduled livestream error: $e');
    }
    return false;
  }

  /// 取消预约
  Future<bool> cancelReservation(int id) async {
    try {
      final res = await _api.cancelReservation(id);
      if (res.isSuccess) {
        loadScheduledLives();
        return true;
      }
      _error = res.message;
      notifyListeners();
    } catch (e) {
      debugPrint('Cancel reservation error: $e');
    }
    return false;
  }

  /// 检查是否已预约
  Future<bool> checkReservation(int id) async {
    try {
      final res = await _api.checkReservation(id);
      if (res.isSuccess) {
        return res.data?['reserved'] ?? false;
      }
    } catch (e) {
      debugPrint('Check reservation error: $e');
    }
    return false;
  }

  // ==================== 礼物和点赞 ====================

  /// 点赞直播间
  Future<bool> likeLivestream(int livestreamId) async {
    try {
      final res = await _api.likeLivestream(livestreamId);
      return res.isSuccess;
    } catch (e) {
      debugPrint('Like livestream error: $e');
    }
    return false;
  }

  /// 清除错误信息
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 清除当前直播间信息
  void clearCurrentRoom() {
    _currentRoom = null;
    notifyListeners();
  }

  /// 加载用户金币/金豆
  Future<void> loadGoldBeans() async {
    try {
      final res = await _walletClient.get('/wallet/info');
      if (res.isSuccess) {
        _goldBeans = (res.data?['gold_beans'] as num?)?.toInt() ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Load gold beans error: $e');
    }
  }

  // ==================== 付费通话 ====================

  /// 请求付费通话
  Future<LivestreamPaidSession?> requestPaidSession(int livestreamId, {required int sessionType, int ratePerMinute = 0}) async {
    try {
      final res = await _api.requestPaidSession(livestreamId, sessionType: sessionType, ratePerMinute: ratePerMinute);
      if (res.isSuccess) {
        return LivestreamPaidSession.fromJson(res.data);
      }
      _error = res.message;
      notifyListeners();
    } catch (e) {
      debugPrint('Request paid session error: $e');
    }
    return null;
  }

  /// 接受付费通话
  Future<bool> acceptPaidSession(int livestreamId, int sessionId) async {
    try {
      final res = await _api.acceptPaidSession(livestreamId, sessionId: sessionId);
      return res.isSuccess;
    } catch (e) {
      debugPrint('Accept paid session error: $e');
    }
    return false;
  }

  /// 拒绝付费通话
  Future<bool> rejectPaidSession(int livestreamId, int sessionId) async {
    try {
      final res = await _api.rejectPaidSession(livestreamId, sessionId: sessionId);
      return res.isSuccess;
    } catch (e) {
      debugPrint('Reject paid session error: $e');
    }
    return false;
  }

  /// 结束付费通话
  Future<bool> endPaidSession(int livestreamId, int sessionId) async {
    try {
      final res = await _api.endPaidSession(livestreamId, sessionId: sessionId);
      return res.isSuccess;
    } catch (e) {
      debugPrint('End paid session error: $e');
    }
    return false;
  }

  // ==================== NFT ====================

  List<LivestreamNFTGift> _nftCollection = [];
  List<LivestreamNFTGift> get nftCollection => _nftCollection;
  int _nftTotal = 0;
  int get nftTotal => _nftTotal;

  /// 加载 NFT 收藏
  Future<void> loadNFTCollection({int page = 1, int pageSize = 20}) async {
    try {
      final res = await _api.getNFTCollection(page: page, pageSize: pageSize);
      if (res.isSuccess) {
        final data = res.data;
        _nftCollection = (data['list'] as List? ?? [])
            .map((e) => LivestreamNFTGift.fromJson(e))
            .toList();
        _nftTotal = data['total'] ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Load NFT collection error: $e');
    }
  }

  /// 获取 NFT 详情
  Future<Map<String, dynamic>?> getNFTDetail(int nftId) async {
    try {
      final res = await _api.getNFTDetail(nftId);
      if (res.isSuccess) {
        return res.data;
      }
    } catch (e) {
      debugPrint('Get NFT detail error: $e');
    }
    return null;
  }

  /// 交易 NFT
  Future<bool> tradeNFT(int nftId, {required int toUserId, int price = 0}) async {
    try {
      final res = await _api.tradeNFT(nftId, toUserId: toUserId, price: price);
      return res.isSuccess;
    } catch (e) {
      debugPrint('Trade NFT error: $e');
    }
    return false;
  }

  // ==================== 仪表盘 ====================

  DashboardOverview? _dashboardOverview;
  DashboardOverview? get dashboardOverview => _dashboardOverview;

  /// 加载仪表盘概览
  Future<DashboardOverview?> loadDashboardOverview() async {
    try {
      final res = await _api.getDashboardOverview();
      if (res.isSuccess) {
        _dashboardOverview = DashboardOverview.fromJson(res.data);
        notifyListeners();
        return _dashboardOverview;
      }
    } catch (e) {
      debugPrint('Load dashboard overview error: $e');
    }
    return null;
  }

  /// 加载仪表盘收入
  Future<List<Map<String, dynamic>>> loadDashboardIncome({String period = 'weekly'}) async {
    try {
      final res = await _api.getDashboardIncome(period: period);
      if (res.isSuccess) {
        return List<Map<String, dynamic>>.from(res.data ?? []);
      }
    } catch (e) {
      debugPrint('Load dashboard income error: $e');
    }
    return [];
  }

  /// 加载仪表盘打赏榜
  Future<List<Map<String, dynamic>>> loadDashboardTopGivers({int limit = 10}) async {
    try {
      final res = await _api.getDashboardTopGivers(limit: limit);
      if (res.isSuccess) {
        return List<Map<String, dynamic>>.from(res.data ?? []);
      }
    } catch (e) {
      debugPrint('Load dashboard top givers error: $e');
    }
    return [];
  }

  /// 加载礼物排行榜
  Future<List<Map<String, dynamic>>> loadDashboardGiftRankings({int limit = 10}) async {
    try {
      final res = await _api.getDashboardGiftRankings(limit: limit);
      if (res.isSuccess) {
        return List<Map<String, dynamic>>.from(res.data ?? []);
      }
    } catch (e) {
      debugPrint('Load dashboard gift rankings error: $e');
    }
    return [];
  }
}
