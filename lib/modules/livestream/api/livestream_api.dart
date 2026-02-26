/// 直播模块API
import 'package:im_client/api/api_client.dart';

class LivestreamApi {
  final ApiClient _client;

  LivestreamApi(this._client);

  // ==================== 直播列表 ====================

  /// 获取正在直播列表
  Future<ApiResponse> getLiveList({int page = 1, int pageSize = 20, int? categoryId}) {
    return _client.get('/livestream/live', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
      if (categoryId != null) 'category_id': categoryId.toString(),
    });
  }

  /// 获取推荐直播列表
  Future<ApiResponse> getRecommendedLives({int page = 1, int pageSize = 20}) {
    return _client.get('/livestream/recommend', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 搜索直播
  Future<ApiResponse> searchLives(String keyword, {int page = 1, int pageSize = 20}) {
    return _client.get('/livestream/search', queryParameters: {
      'keyword': keyword,
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 获取关注的主播直�?
  Future<ApiResponse> getFollowingLives({int page = 1, int pageSize = 20}) {
    return _client.get('/livestream/following', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 获取直播间详请
  Future<ApiResponse> getLivestream(int id) {
    return _client.get('/livestream/$id');
  }

  /// 获取分类列表
  Future<ApiResponse> getCategories() {
    return _client.get('/livestream/categories');
  }

  /// 获取礼物列表
  Future<ApiResponse> getGiftList() {
    return _client.get('/livestream/gifts');
  }

  // ==================== 直播间管�?====================

  /// 创建直播间
  Future<ApiResponse> createLivestream({
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
  }) {
    return _client.post('/livestream', data: {
      'title': title,
      if (description != null) 'description': description,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (categoryId != null) 'category_id': categoryId,
      'type': type,
      'is_paid': isPaid,
      if (isPaid) ...{
        'ticket_price': ticketPrice,
        'ticket_price_type': ticketPriceType,
        'anchor_share_ratio': anchorShareRatio,
        'allow_preview': allowPreview,
        'preview_duration': previewDuration,
      },
      if (roomType == 1) ...{
        'room_type': roomType,
        'price_per_min': pricePerMin,
        'trial_seconds': trialSeconds,
      },
      if (allowPaidCall) 'allow_paid_call': allowPaidCall,
      if (paidCallRate > 0) 'paid_call_rate': paidCallRate,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
    });
  }

  /// 开始直播
  Future<ApiResponse> startLivestream(int id) {
    return _client.post('/livestream/$id/start');
  }

  /// 结束直播
  Future<ApiResponse> endLivestream(int id) {
    return _client.post('/livestream/$id/end');
  }

  /// 我的直播历史
  Future<ApiResponse> getMyLives({int page = 1, int pageSize = 20}) {
    return _client.get('/livestream/my', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  // ==================== 观众操作 ====================

  /// 加入直播表
  Future<ApiResponse> joinLivestream(int id, {String? password}) {
    return _client.post('/livestream/$id/join', data: {
      if (password != null && password.isNotEmpty) 'password': password,
    });
  }

  /// 加入付费直播间
  Future<ApiResponse> joinPaidLivestream(int id, {bool usePreview = false}) {
    return _client.post('/livestream/$id/join-paid', data: {
      'use_preview': usePreview,
    });
  }

  /// 离开直播间
  Future<ApiResponse> leaveLivestream(int id) {
    return _client.post('/livestream/$id/leave');
  }

  /// 购买门票
  Future<ApiResponse> buyTicket(int id, {int priceType = 1}) {
    return _client.post('/livestream/$id/ticket', data: {
      'price_type': priceType,
    });
  }

  /// 送礼物
  Future<ApiResponse> sendGift(int id, {required int giftId, int count = 1, String? message, String? idempotencyKey}) {
    return _client.post('/livestream/$id/gift', data: {
      'gift_id': giftId,
      'count': count,
      if (message != null) 'message': message,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    });
  }

  /// 发送弹幕
  Future<ApiResponse> sendDanmaku(int id, {required String content, String? color, int position = 0}) {
    return _client.post('/livestream/$id/danmaku', data: {
      'content': content,
      if (color != null) 'color': color,
      'position': position,
    });
  }

  /// 获取观众列表
  Future<ApiResponse> getViewers(int id, {int page = 1, int pageSize = 20}) {
    return _client.get('/livestream/$id/viewers', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 获取弹幕历史
  Future<ApiResponse> getDanmakus(int id, {int startTime = 0, int? endTime}) {
    return _client.get('/livestream/$id/danmakus', queryParameters: {
      'start_time': startTime.toString(),
      if (endTime != null) 'end_time': endTime.toString(),
    });
  }

  /// 获取礼物记录
  Future<ApiResponse> getGiftRecords(int id, {int page = 1, int pageSize = 20}) {
    return _client.get('/livestream/$id/gift-records', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 获取直播回放
  Future<ApiResponse> getRecords(int id) {
    return _client.get('/livestream/$id/records');
  }

  // ==================== 付费直播 ====================

  /// 更新付费设置
  Future<ApiResponse> updatePaidSettings(int id, {
    bool? isPaid,
    int? ticketPrice,
    int? ticketPriceType,
    int? anchorShareRatio,
    bool? allowPreview,
    int? previewDuration,
  }) {
    return _client.put('/livestream/$id/paid-settings', data: {
      if (isPaid != null) 'is_paid': isPaid,
      if (ticketPrice != null) 'ticket_price': ticketPrice,
      if (ticketPriceType != null) 'ticket_price_type': ticketPriceType,
      if (anchorShareRatio != null) 'anchor_share_ratio': anchorShareRatio,
      if (allowPreview != null) 'allow_preview': allowPreview,
      if (previewDuration != null) 'preview_duration': previewDuration,
    });
  }

  /// 门票购买历史
  Future<ApiResponse> getTicketHistory({int page = 1, int pageSize = 20}) {
    return _client.get('/livestream/tickets', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 主播门票收入
  Future<ApiResponse> getAnchorIncome({int page = 1, int pageSize = 20}) {
    return _client.get('/livestream/anchor/income', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  // ==================== 关注/禁言 ====================

  /// 关注主播
  Future<ApiResponse> followAnchor(int anchorId) {
    return _client.post('/livestream/anchor/$anchorId/follow');
  }

  /// 取消关注主播
  Future<ApiResponse> unfollowAnchor(int anchorId) {
    return _client.delete('/livestream/anchor/$anchorId/follow');
  }

  /// 检查是否关注主播
  Future<ApiResponse> checkFollowing(int anchorId) {
    return _client.get('/livestream/anchor/$anchorId/following');
  }

  /// 禁言/封禁用户
  Future<ApiResponse> banUser(int id, {required int userId, int banType = 1, String? reason, int duration = 0}) {
    return _client.post('/livestream/$id/ban', data: {
      'user_id': userId,
      'ban_type': banType,
      if (reason != null) 'reason': reason,
      'duration': duration,
    });
  }

  /// 解除禁言
  Future<ApiResponse> unbanUser(int id, int userId) {
    return _client.delete('/livestream/$id/ban/$userId');
  }

  /// 添加房管
  Future<ApiResponse> addModerator(int id, int userId) {
    return _client.post('/livestream/$id/moderator', data: {'user_id': userId});
  }

  /// 移除房管
  Future<ApiResponse> removeModerator(int id, int userId) {
    return _client.delete('/livestream/$id/moderator/$userId');
  }

  /// 获取房管列表
  Future<ApiResponse> getModerators(int id) {
    return _client.get('/livestream/$id/moderators');
  }

  // ==================== 点赞 ====================

  /// 点赞
  Future<ApiResponse> likeLivestream(int id) {
    return _client.post('/livestream/$id/like');
  }

  // ==================== 连麦 ====================

  /// 请求连麦
  Future<ApiResponse> requestCoHost(int id) {
    return _client.post('/livestream/$id/cohost/request');
  }

  /// 接受连麦
  Future<ApiResponse> acceptCoHost(int id, {required int userId}) {
    return _client.post('/livestream/$id/cohost/accept', data: {'user_id': userId});
  }

  /// 拒绝连麦
  Future<ApiResponse> rejectCoHost(int id, {required int userId}) {
    return _client.post('/livestream/$id/cohost/reject', data: {'user_id': userId});
  }

  /// 结束连麦
  Future<ApiResponse> endCoHost(int id) {
    return _client.post('/livestream/$id/cohost/end');
  }

  /// 踢出指定连麦用户（主播专用）
  Future<ApiResponse> kickCoHost(int id, {required int userId}) {
    return _client.post('/livestream/$id/cohost/kick', data: {'user_id': userId});
  }

  /// 获取连麦列表
  Future<ApiResponse> getCoHosts(int id) {
    return _client.get('/livestream/$id/cohost');
  }

  /// 获取连麦LiveKit Token（断线重连时使用�?
  Future<ApiResponse> getCoHostToken(int id) {
    return _client.get('/livestream/$id/cohost/token');
  }

  // ==================== PK ====================

  /// 邀请PK
  Future<ApiResponse> invitePK(int id, {required int targetLivestreamId}) {
    return _client.post('/livestream/$id/pk/invite', data: {'target_livestream_id': targetLivestreamId});
  }

  /// 接受PK
  Future<ApiResponse> acceptPK(int id, {required int pkId}) {
    return _client.post('/livestream/$id/pk/accept', data: {'pk_id': pkId});
  }

  /// 拒绝PK
  Future<ApiResponse> rejectPK(int id, {required int pkId}) {
    return _client.post('/livestream/$id/pk/reject', data: {'pk_id': pkId});
  }

  /// 获取当前PK
  Future<ApiResponse> getActivePK(int id) {
    return _client.get('/livestream/$id/pk/active');
  }

  /// 获取PK LiveKit Token（观众subscribe-only)
  Future<ApiResponse> getPKToken(int id) {
    return _client.get('/livestream/$id/pk/token');
  }

  /// 随机PK匹配
  Future<ApiResponse> randomPK(int id) {
    return _client.post('/livestream/$id/pk/random');
  }

  /// 获取PK排行榜
  Future<ApiResponse> getPKRankings({String type = 'points', int page = 1, int pageSize = 20}) {
    return _client.get('/livestream/pk/rankings', queryParameters: {
      'type': type,
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 获取我的PK统计
  Future<ApiResponse> getMyPKStats() {
    return _client.get('/livestream/pk/my-stats');
  }

  /// 获取PK历史
  Future<ApiResponse> getPKHistory({int page = 1}) {
    return _client.get('/livestream/pk/history', queryParameters: {
      'page': page.toString(),
    });
  }

  /// 获取PK规则
  Future<ApiResponse> getPKRules() {
    return _client.get('/livestream/pk/rules');
  }

  // ==================== 预约 ====================

  /// 获取预约直播列表
  Future<ApiResponse> getScheduledLives({int page = 1, int pageSize = 20}) {
    return _client.get('/livestream/scheduled', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 预约直播
  Future<ApiResponse> reserveLivestream(int id, {bool autoEnter = false}) {
    return _client.post('/livestream/$id/reserve', data: {'auto_enter': autoEnter});
  }

  /// 主播取消预约直播
  Future<ApiResponse> cancelScheduledLivestream(int id) {
    return _client.post('/livestream/$id/cancel-scheduled');
  }

  /// 取消预约
  Future<ApiResponse> cancelReservation(int id) {
    return _client.delete('/livestream/$id/reserve');
  }

  /// 检查是否已预约
  Future<ApiResponse> checkReservation(int id) {
    return _client.get('/livestream/$id/reserve/check');
  }

  /// 获取预约列表
  Future<ApiResponse> getReservations(int id, {int page = 1, int pageSize = 20}) {
    return _client.get('/livestream/$id/reservations', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  // ==================== 付费连线 ====================

  /// 请求付费连线
  Future<ApiResponse> requestPaidSession(int id, {required int sessionType, int ratePerMinute = 0}) {
    return _client.post('/livestream/$id/paid-session/request', data: {
      'session_type': sessionType,
      if (ratePerMinute > 0) 'rate_per_minute': ratePerMinute,
    });
  }

  /// 接受付费连线
  Future<ApiResponse> acceptPaidSession(int id, {required int sessionId}) {
    return _client.post('/livestream/$id/paid-session/accept', data: {'session_id': sessionId});
  }

  /// 拒绝付费连线
  Future<ApiResponse> rejectPaidSession(int id, {required int sessionId}) {
    return _client.post('/livestream/$id/paid-session/reject', data: {'session_id': sessionId});
  }

  /// 结束付费连线
  Future<ApiResponse> endPaidSession(int id, {required int sessionId}) {
    return _client.post('/livestream/$id/paid-session/end', data: {'session_id': sessionId});
  }

  /// 付费连线历史
  Future<ApiResponse> getPaidSessionHistory({int page = 1, int pageSize = 20}) {
    return _client.get('/livestream/paid-sessions', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  // ==================== 付费通话(LiveKit) ====================

  /// 申请付费通话
  Future<ApiResponse> applyPaidCall(int id, {required int sessionType, int ratePerMinute = 0}) {
    return _client.post('/livestream/$id/paid-call/apply', data: {
      'session_type': sessionType,
      if (ratePerMinute > 0) 'rate_per_minute': ratePerMinute,
    });
  }

  /// 接受付费通话
  Future<ApiResponse> acceptPaidCall(int id, {required int sessionId}) {
    return _client.post('/livestream/$id/paid-call/accept', data: {'session_id': sessionId});
  }

  /// 拒绝付费通话
  Future<ApiResponse> rejectPaidCall(int id, {required int sessionId}) {
    return _client.post('/livestream/$id/paid-call/reject', data: {'session_id': sessionId});
  }

  /// 结束付费通话
  Future<ApiResponse> endPaidCall(int id, {required int sessionId}) {
    return _client.post('/livestream/$id/paid-call/end', data: {'session_id': sessionId});
  }

  // ==================== NFT ====================

  /// 获取NFT收藏
  Future<ApiResponse> getNFTCollection({int page = 1, int pageSize = 20}) {
    return _client.get('/livestream/nft/collection', queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  /// 获取NFT详情
  Future<ApiResponse> getNFTDetail(int nftId) {
    return _client.get('/livestream/nft/$nftId');
  }

  /// NFT交易
  Future<ApiResponse> tradeNFT(int nftId, {required int toUserId, int price = 0}) {
    return _client.post('/livestream/nft/$nftId/trade', data: {
      'to_user_id': toUserId,
      'price': price,
    });
  }

  // ==================== 数据看板 ====================

  /// 看板概览
  Future<ApiResponse> getDashboardOverview() {
    return _client.get('/livestream/dashboard/overview');
  }

  /// 收入趋势
  Future<ApiResponse> getDashboardIncome({String period = 'weekly'}) {
    return _client.get('/livestream/dashboard/income', queryParameters: {
      'period': period,
    });
  }

  /// 打赏榜
  Future<ApiResponse> getDashboardTopGivers({int limit = 10}) {
    return _client.get('/livestream/dashboard/top-givers', queryParameters: {
      'limit': limit.toString(),
    });
  }

  /// 礼物排行
  Future<ApiResponse> getDashboardGiftRankings({int limit = 10}) {
    return _client.get('/livestream/dashboard/gift-rankings', queryParameters: {
      'limit': limit.toString(),
    });
  }

  /// 获取用户直播画像
  Future<ApiResponse> getUserLivestreamAnalytics(int userId) {
    return _client.get('/livestream/user/$userId/analytics');
  }
}
