/// 聊天状态管理
/// 管理会话列表、联系人、消息等状态
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lpinyin/lpinyin.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/local_database_service.dart';
import '../services/local_message_service.dart';
import '../services/websocket_service.dart';
import '../services/notification_sound_service.dart';
import '../services/notification_service.dart';
import '../services/chat_settings_service.dart';
import '../services/settings_service.dart';
import '../api/api_client.dart';
import '../api/friend_api.dart';
import '../api/conversation_api.dart';
import '../api/user_api.dart';
import '../api/group_api.dart';
import '../utils/conversation_utils.dart';
import '../api/system_api.dart';

/// 撤回事件
class RecallEvent {
  final String msgId;
  final String? conversId;
  final bool isSelfRecall;

  RecallEvent({
    required this.msgId,
    this.conversId,
    this.isSelfRecall = false,
  });
}

class ChatProvider extends ChangeNotifier with WidgetsBindingObserver {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final LocalMessageService _localMessageService = LocalMessageService();
  final WebSocketService _wsService = WebSocketService();
  final NotificationSoundService _soundService = NotificationSoundService();
  final ChatSettingsService _chatSettingsService = ChatSettingsService();
  final SettingsService _settingsService = SettingsService();
  late FriendApi _friendApi;
  late ConversationApi _conversationApi;
  late UserApi _userApi;
  late GroupApi _groupApi;

  /// App 是否在后台（用于决定是否显示系统通知）
  bool _isInBackground = false;
  bool get isInBackground => _isInBackground;

  int? _currentUserId;
  List<Conversation> _conversations = [];
  List<Friend> _friends = [];
  List<FriendRequest> _friendRequests = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _connectionSubscription;

  /// 当前正在查看的会话ID（用于判断是否需要增加未读数）
  String? _activeConversId;

  /// 新消息流控制器（用于通知UI有新消息）
  final _newMessageController = StreamController<Message>.broadcast();
  Stream<Message> get newMessageStream => _newMessageController.stream;

  /// 会话清空通知流控制器（用于通知UI某个会话被清空）
  final _conversationClearedController = StreamController<String>.broadcast();
  Stream<String> get conversationClearedStream => _conversationClearedController.stream;

  // Getters
  List<Conversation> get conversations => _conversations;
  List<Friend> get friends => _friends;
  List<FriendRequest> get friendRequests => _friendRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get currentUserId => _currentUserId;
  int get unreadFriendRequestCount => _friendRequests.where((r) => r.isPending).length;
  int get totalUnreadCount => _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  int _systemNotificationUnreadCount = 0;
  int get systemNotificationUnreadCount => _systemNotificationUnreadCount;
  int get messageTabTotalCount => totalUnreadCount + _systemNotificationUnreadCount;

  /// 加载系统通知未读数
  Future<void> loadSystemNotificationCount() async {
    try {
      final count = await SystemApi().getUnreadCount();
      if (_systemNotificationUnreadCount != count) {
        _systemNotificationUnreadCount = count;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// 设置当前正在查看的会话（进入聊天页面时调用）
  void setActiveConversation(String? conversId) {
    _activeConversId = conversId;
    print('[ChatProvider] 设置活动会话: $conversId');
  }

  /// 检查是否正在查看某个会话
  bool isViewingConversation(String conversId) {
    return _activeConversId == conversId;
  }

  bool _initialized = false;
  String? _token;

  /// 初始化
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasBg = _isInBackground;
    _isInBackground = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
    print('[ChatProvider] App lifecycle: $state, isInBackground=$_isInBackground');

    // App 从后台恢复到前台时，重新加载会话列表以同步离线消息和未读数
    if (wasBg && state == AppLifecycleState.resumed && _initialized) {
      print('[ChatProvider] App恢复前台，重新同步会话列表');
      loadConversations();
    }
  }

  Future<void> init(ApiClient apiClient, int userId, {String? token}) async {
    // 同一用户重新登录时，只需重连 WebSocket，不需要全部重新初始化
    if (_initialized && _currentUserId == userId) {
      _token = token;
      // 重新订阅并重连 WebSocket（token 可能已更新）
      _subscribeToWebSocket();
      if (_token != null && _token!.isNotEmpty) {
        print('[ChatProvider] 同一用户重新登录，重连WebSocket');
        _wsService.connect(_token!);
      }
      loadData();
      return;
    }

    _friendApi = FriendApi(apiClient);
    _conversationApi = ConversationApi(apiClient);
    _userApi = UserApi(apiClient);
    _groupApi = GroupApi(apiClient);
    _currentUserId = userId;
    _token = token;
    _initialized = true;

    // 注册生命周期监听
    WidgetsBinding.instance.addObserver(this);

    // 初始化本地消息存储
    await _localMessageService.init();

    // 初始化铃声服务
    await _soundService.init();

    // 初始化聊天设置服务
    await _chatSettingsService.init();

    // 从服务器加载用户设置（包括自定义铃声等）
    await SettingsService().loadFromServer();

    // 先订阅WebSocket消息流
    _subscribeToWebSocket();

    // 然后再连接WebSocket（确保订阅在连接之前）
    if (_token != null && _token!.isNotEmpty) {
      print('[ChatProvider] 连接WebSocket...');
      _wsService.connect(_token!);
    }

    loadData();
  }

  /// 订阅WebSocket消息（全局处理）
  void _subscribeToWebSocket() {
    _wsSubscription?.cancel();
    _wsSubscription = _wsService.messageStream.listen(_handleWebSocketMessage);

    // 监听 WebSocket 重连事件，重连成功后重新加载会话列表以同步离线消息和未读数
    _connectionSubscription?.cancel();
    _connectionSubscription = _wsService.connectionStream.listen((connected) {
      if (connected && _initialized) {
        print('[ChatProvider] WebSocket重连成功，重新同步会话列表');
        loadConversations();
      }
    });
  }

  /// 处理WebSocket消息
  Future<void> _handleWebSocketMessage(Map<String, dynamic> data) async {
    final type = data['type'] as String?;

    if (type == 'chat') {
      await _handleChatMessage(data);
    } else if (type == 'recall') {
      await _handleRecallMessage(data);
    } else if (type == 'clear_conversation') {
      await _handleClearConversation(data);
    } else if (type == 'red_packet') {
      await _handleRedPacketNotification(data);
    } else if (type == 'group_settings_update') {
      await _handleGroupSettingsUpdate(data);
    } else if (type == 'group_join_request') {
      await _handleGroupJoinRequest(data);
    } else if (type == 'notification') {
      await _handleNotification(data);
    } else if (type == 'online' || type == 'offline') {
      _handleFriendOnlineStatus(data, type == 'online');
    }
  }

  /// 处理好友上线/下线状态
  void _handleFriendOnlineStatus(Map<String, dynamic> data, bool isOnline) {
    final msgData = data['data'] as Map<String, dynamic>?;
    if (msgData == null) return;

    final userId = msgData['user_id'];
    int? uid;
    if (userId is int) {
      uid = userId;
    } else if (userId is String) {
      uid = int.tryParse(userId);
    }
    if (uid == null) return;

    print('[ChatProvider] 好友${isOnline ? "上线" : "下线"}: userId=$uid');

    for (int i = 0; i < _friends.length; i++) {
      if (_friends[i].friendId == uid) {
        _friends[i] = _friends[i].copyWith(isOnline: isOnline);
        notifyListeners();
        break;
      }
    }
  }

  // 红包通知控制器
  final _redPacketController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get redPacketStream => _redPacketController.stream;

  // 群设置更新通知控制器
  final _groupSettingsUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get groupSettingsUpdateStream => _groupSettingsUpdateController.stream;

  // 入群申请通知控制器
  final _groupJoinRequestController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get groupJoinRequestStream => _groupJoinRequestController.stream;

  // 消息发送失败通知控制器
  final _messageBlockedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageBlockedStream => _messageBlockedController.stream;

  // 金豆通知控制器
  final _goldBeanNotifyController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get goldBeanNotifyStream => _goldBeanNotifyController.stream;

  // 系统通知控制器（用于刷新系统通知列表）
  final _systemNotifyController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get systemNotifyStream => _systemNotifyController.stream;

  /// 处理通知消息
  Future<void> _handleNotification(Map<String, dynamic> data) async {
    try {
      final notifyData = data['data'] as Map<String, dynamic>?;
      if (notifyData == null) return;

      // 新版通知格式：notify_type 字段
      final notifyType = notifyData['notify_type'] as String? ?? notifyData['type'] as String?;
      print('[ChatProvider] 收到通知: type=$notifyType, data=$notifyData');

      if (notifyType == 'message_blocked') {
        // 消息被黑名单阻止
        final targetId = notifyData['target_id'];
        final reason = notifyData['reason'] as String?;
        final message = notifyData['message'] as String?;

        print('[ChatProvider] 消息被阻止: targetId=$targetId, reason=$reason');

        // 广播消息被阻止事件，让UI处理
        _messageBlockedController.add({
          'target_id': targetId,
          'reason': reason,
          'message': message ?? '消息发送失败',
        });
      } else if (notifyType == 'friend_deleted') {
        // 好友被删除通知
        final friendId = notifyData['friend_id'];
        print('[ChatProvider] 好友被删除: friendId=$friendId');
        // 刷新好友列表
        await loadFriends();
      } else if (notifyType == 'friend_request') {
        // 收到新的好友申请
        print('[ChatProvider] 收到好友申请');
        await loadFriendRequests();
        // 同时广播系统通知刷新事件
        _systemNotifyController.add({
          'action': 'new_notify',
          'notify_type': notifyType,
          'data': notifyData,
        });
      } else if (notifyType == 'friend_accepted' || notifyType == 'friend_added') {
        // 好友申请被接受 / 成为好友
        print('[ChatProvider] 好友申请已通过: $notifyType');
        await loadFriends();
        await loadFriendRequests();
        // 同时广播系统通知刷新事件
        _systemNotifyController.add({
          'action': 'new_notify',
          'notify_type': notifyType,
          'data': notifyData,
        });
      } else if (notifyType != null && notifyType.startsWith('gold_bean_')) {
        // 金豆相关通知
        print('[ChatProvider] 收到金豆通知: $notifyType');

        // 广播金豆通知事件
        _goldBeanNotifyController.add({
          'notify_type': notifyType,
          'notify_id': notifyData['notify_id'],
          'title': notifyData['title'],
          'content': notifyData['content'],
          'gold_bean_type': notifyData['gold_bean_type'],
          'amount': notifyData['amount'],
          'balance': notifyData['balance'],
          'related_id': notifyData['related_id'],
          'remark': notifyData['remark'],
          'created_at': notifyData['created_at'],
        });

        // 同时广播系统通知刷新事件
        _systemNotifyController.add({
          'action': 'new_notify',
          'notify_type': notifyType,
        });
      } else {
        // 其他系统通知
        print('[ChatProvider] 收到系统通知: $notifyType');
        _systemNotifyController.add({
          'action': 'new_notify',
          'notify_type': notifyType,
          'data': notifyData,
        });
      }

      // 刷新系统通知未读计数
      loadSystemNotificationCount();
    } catch (e) {
      print('[ChatProvider] 处理通知失败: $e');
    }
  }

  /// 处理红包通知（领取/过期）
  Future<void> _handleRedPacketNotification(Map<String, dynamic> data) async {
    try {
      final messageData = data['data'] as Map<String, dynamic>?;
      if (messageData == null) return;

      final action = messageData['action'] as String?;
      final conversId = messageData['convers_id'] as String?;
      final redPacketId = messageData['red_packet_id'];

      print('[ChatProvider] 收到红包通知: action=$action, conversId=$conversId, redPacketId=$redPacketId');

      // 广播红包事件，让UI处理
      _redPacketController.add({
        'action': action,
        'convers_id': conversId,
        'red_packet_id': redPacketId,
        ...messageData,
      });

    } catch (e) {
      print('[ChatProvider] 处理红包通知失败: $e');
    }
  }

  /// 处理群设置更新通知
  Future<void> _handleGroupSettingsUpdate(Map<String, dynamic> data) async {
    try {
      final messageData = data['data'] as Map<String, dynamic>?;
      if (messageData == null) return;

      final groupId = messageData['group_id'];
      final updated = messageData['updated'] as Map<String, dynamic>?;

      print('[ChatProvider] 收到群设置更新: groupId=$groupId, updated=$updated');

      // 广播群设置更新事件，让UI处理
      _groupSettingsUpdateController.add({
        'group_id': groupId,
        'updated': updated,
      });

    } catch (e) {
      print('[ChatProvider] 处理群设置更新通知失败: $e');
    }
  }

  /// 处理入群申请通知
  Future<void> _handleGroupJoinRequest(Map<String, dynamic> data) async {
    try {
      final messageData = data['data'] as Map<String, dynamic>?;
      if (messageData == null) return;

      final groupId = messageData['group_id'];
      final request = messageData['request'] as Map<String, dynamic>?;

      print('[ChatProvider] 收到入群申请通知: groupId=$groupId, request=$request');

      // 广播入群申请事件，让UI处理
      _groupJoinRequestController.add({
        'group_id': groupId,
        'request': request,
      });

    } catch (e) {
      print('[ChatProvider] 处理入群申请通知失败: $e');
    }
  }

  /// 处理聊天消息（包括离线消息）
  Future<void> _handleChatMessage(Map<String, dynamic> data) async {
    try {
      final isOffline = data['data']?['offline'] == true;
      print('[ChatProvider._handleChatMessage] 收到WebSocket消息${isOffline ? "(离线)" : ""}');
      print('[ChatProvider._handleChatMessage] _currentUserId=$_currentUserId');
      print('[ChatProvider._handleChatMessage] 原始data: $data');

      // 消息数据在 data['data'] 中，但也可能在顶层
      Map<String, dynamic> messageData;
      if (data['data'] is Map<String, dynamic>) {
        messageData = Map<String, dynamic>.from(data['data'] as Map);
        // 合并顶层的 from_user_id, to_user_id, group_id（如果data中没有的话）
        messageData['from_user_id'] ??= data['from_user_id'];
        messageData['to_user_id'] ??= data['to_user_id'];
        messageData['group_id'] ??= data['group_id'];
      } else if (data['data'] is Map) {
        // 处理 LinkedHashMap 等其他 Map 类型
        messageData = Map<String, dynamic>.from(data['data'] as Map);
        messageData['from_user_id'] ??= data['from_user_id'];
        messageData['to_user_id'] ??= data['to_user_id'];
        messageData['group_id'] ??= data['group_id'];
      } else {
        messageData = Map<String, dynamic>.from(data);
      }
      print('[ChatProvider._handleChatMessage] 解析后messageData: $messageData');

      // 辅助函数：安全地转换为int
      int? toInt(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is double) return value.toInt();
        if (value is String) return int.tryParse(value);
        return null;
      }

      // 构建conversId
      String? conversId = messageData['convers_id']?.toString();
      print('[ChatProvider._handleChatMessage] convers_id原始值: ${messageData['convers_id']} (类型: ${messageData['convers_id'].runtimeType})');
      print('[ChatProvider._handleChatMessage] from_user_id原始值: ${messageData['from_user_id']} (类型: ${messageData['from_user_id'].runtimeType})');
      print('[ChatProvider._handleChatMessage] to_user_id原始值: ${messageData['to_user_id']} (类型: ${messageData['to_user_id'].runtimeType})');

      if (conversId == null || conversId.isEmpty) {
        final fromUserId = toInt(messageData['from_user_id']);
        final toUserId = toInt(messageData['to_user_id']);
        final groupId = toInt(messageData['group_id']);

        print('计算conversId: fromUserId=$fromUserId, toUserId=$toUserId, groupId=$groupId');

        if (groupId != null && groupId > 0) {
          conversId = 'g_$groupId';
        } else if (fromUserId != null && toUserId != null) {
          final ids = [fromUserId, toUserId]..sort();
          conversId = 'p_${ids[0]}_${ids[1]}';
        }
      }

      print('最终conversId: $conversId');

      if (conversId == null || conversId.isEmpty) {
        print('无法确定conversId，跳过消息');
        return;
      }

      // 添加conversId到消息数据
      messageData['convers_id'] = conversId;

      final message = Message.fromJson(messageData);
      print('解析后的消息: msgId=${message.msgId}, content=${message.content}, fromUserId=${message.fromUserId}, toUserId=${message.toUserId}, hasFromUser=${message.fromUser != null}');
      if (message.fromUser != null) {
        print('fromUser信息: id=${message.fromUser!.id}, nickname=${message.fromUser!.nickname}');
      }

      // 检查是否是"清空群聊记录"的系统消息
      if (message.isSystem && message.extra != null) {
        try {
          final extraJson = message.extra!;
          // 尝试解析extra中的action_type
          if (extraJson.contains('group_messages_cleared')) {
            print('[ChatProvider] 收到清空群聊记录通知: conversId=$conversId');
            // 先清空该群的所有本地消息
            await _localMessageService.clearConversationMessages(conversId);
            print('[ChatProvider] 已清空群 $conversId 的本地消息');
            // 通知正在该会话的UI刷新
            _conversationClearedController.add(conversId);
          }
        } catch (e) {
          print('[ChatProvider] 解析extra失败: $e');
        }
      }

      // 保存消息到本地存储
      await _localMessageService.saveMessage(message);
      print('消息已保存到本地存储');

      // 更新会话列表（如果会话不存在会自动创建）
      final preview = _getMessagePreview(message);
      // 判断是否需要增加未读数：
      // 1. 消息不是自己发的
      // 2. 用户当前没有在查看该会话
      final shouldIncrementUnread = message.fromUserId != _currentUserId
          && !isViewingConversation(conversId);

      // 提取目标会话信息，用于创建会话时设置targetInfo
      Map<String, dynamic>? targetInfoForConversation;
      if (message.fromUserId != _currentUserId && message.fromUser != null) {
        // 收到别人的消息 → targetInfo 是发送者
        targetInfoForConversation = {
          'id': message.fromUser!.id,
          'nickname': message.fromUser!.nickname,
          'username': message.fromUser!.username,
          'avatar': message.fromUser!.avatar,
          'display_name': message.fromUser!.displayName,
        };
      } else if (message.fromUserId == _currentUserId
                 && message.toUserId != null && message.toUserId! > 0
                 && (message.groupId == null || message.groupId == 0)) {
        // 多设备同步：自己发的私聊消息 → targetInfo 是接收方
        Friend? friend;
        try {
          friend = _friends.firstWhere((f) => f.friendId == message.toUserId);
        } catch (_) {
          friend = null;
        }
        if (friend != null) {
          targetInfoForConversation = {
            'id': friend.friendId,
            'nickname': friend.displayName,
            'avatar': friend.friend.avatar,
            'username': friend.friend.username,
            'display_name': friend.displayName,
          };
        }
      }

      await updateConversation(
        conversId: conversId,
        lastMsgPreview: preview,
        lastMsgTime: message.createdAt ?? DateTime.now(),
        incrementUnread: shouldIncrementUnread,
        fromUserId: message.fromUserId,
        toUserId: message.toUserId,
        groupId: message.groupId,
        senderInfo: targetInfoForConversation,
      );

      // 通知有新消息
      print('[ChatProvider._handleChatMessage] 准备广播新消息到stream: msgId=${message.msgId}, conversId=$conversId');
      _newMessageController.add(message);
      print('[ChatProvider._handleChatMessage] 消息已广播到stream');

      // 如果是别人发的消息，播放铃声/震动通知
      if (message.fromUserId != _currentUserId) {
        print('[ChatProvider._handleChatMessage] 检查是否播放铃声: conversId=$conversId');
        // 1. 检查全局通知开关（设置 -> 新消息通知）
        if (!_settingsService.messageNotification) {
          print('[ChatProvider._handleChatMessage] 全局通知已关闭，不播放铃声');
        } else {
          // 2. 检查当前会话是否免打扰
          print('[ChatProvider._handleChatMessage] 检查会话免打扰状态...');
          final conversationMuted = await _chatSettingsService.isMuted(conversId);
          print('[ChatProvider._handleChatMessage] 会话免打扰状态: conversationMuted=$conversationMuted');
          if (conversationMuted) {
            print('[ChatProvider._handleChatMessage] 当前会话已免打扰，不播放铃声');
          } else {
            // 3. App 在后台时显示系统通知栏通知
            if (_isInBackground) {
              try {
                final senderName = targetInfoForConversation?['nickname'] as String? ??
                    targetInfoForConversation?['username'] as String? ?? '';
                final bodyText = _getNotificationBody(message);
                NotificationService().showMessageNotification(
                  title: senderName.isNotEmpty ? senderName : 'IM',
                  body: bodyText,
                  conversId: conversId,
                  unreadCount: totalUnreadCount,
                );
                print('[ChatProvider._handleChatMessage] 后台已显示系统通知');
              } catch (e) {
                print('[ChatProvider._handleChatMessage] 显示系统通知失败: $e');
              }
            }
            // 4. 检查全局声音设置
            if (_settingsService.messageSound) {
              await _soundService.playMessageSound();
              print('[ChatProvider._handleChatMessage] 播放消息铃声');
            }
            // 5. 检查全局震动设置
            if (_settingsService.messageVibrate) {
              await _soundService.playVibration();
              print('[ChatProvider._handleChatMessage] 播放震动提醒');
            }
          }
        }
      }

      // 打印调试信息
      print('[ChatProvider._handleChatMessage] 处理完成${isOffline ? "(离线)" : ""}消息: ${message.msgId} -> $conversId');
    } catch (e, stack) {
      print('处理聊天消息失败: $e');
      print('堆栈: $stack');
    }
  }

  /// 根据消息类型生成通知正文
  String _getNotificationBody(Message message) {
    switch (message.type) {
      case 'text':
        return message.content;
      case 'image':
        return '[图片]';
      case 'voice':
        return '[语音]';
      case 'video':
        return '[视频]';
      case 'file':
        return '[文件]';
      case 'location':
        return '[位置]';
      case 'red_packet':
        return '[红包]';
      case 'sticker':
        return '[表情]';
      default:
        return '[新消息]';
    }
  }

  /// 处理撤回消息
  Future<void> _handleRecallMessage(Map<String, dynamic> data) async {
    try {
      print('[ChatProvider] 收到撤回WebSocket消息: $data');

      // 安全获取嵌套的data
      Map<String, dynamic>? msgData;
      final rawData = data['data'];
      if (rawData is Map<String, dynamic>) {
        msgData = rawData;
      } else if (rawData is Map) {
        msgData = Map<String, dynamic>.from(rawData);
      }

      if (msgData == null) {
        print('[ChatProvider] 撤回消息data为空');
        return;
      }

      final msgId = msgData['msg_id']?.toString();
      if (msgId == null || msgId.isEmpty) {
        print('[ChatProvider] 撤回消息msg_id为空');
        return;
      }

      // 安全的类型转换辅助函数
      int? toInt(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is double) return value.toInt();
        if (value is String) return int.tryParse(value);
        return null;
      }

      // 获取撤回者ID和当前用户ID
      final recalledBy = toInt(msgData['recalled_by']);
      final isSelfRecall = recalledBy == _currentUserId;

      // 计算会话ID
      String? conversId;
      final groupId = toInt(msgData['group_id']);
      final fromUserId = toInt(msgData['from_user_id']);
      final toUserId = toInt(msgData['to_user_id']);

      print('[ChatProvider] 撤回消息解析: groupId=$groupId, fromUserId=$fromUserId, toUserId=$toUserId, currentUserId=$_currentUserId');

      if (groupId != null && groupId > 0) {
        conversId = 'g_$groupId';
      } else if (fromUserId != null && toUserId != null) {
        final ids = [fromUserId, toUserId]..sort();
        conversId = 'p_${ids[0]}_${ids[1]}';
      }

      print('[ChatProvider] 收到撤回消息通知: msgId=$msgId, conversId=$conversId, isSelfRecall=$isSelfRecall');

      // 从本地存储中删除消息
      if (conversId != null) {
        await _localMessageService.deleteMessage(conversId, msgId);
        print('[ChatProvider] 已从本地存储删除消息: $msgId');
      }

      // 广播撤回消息事件，包含更多信息
      _recallController.add(RecallEvent(
        msgId: msgId,
        conversId: conversId,
        isSelfRecall: isSelfRecall,
      ));
      print('[ChatProvider] 已广播撤回事件');
    } catch (e, stack) {
      print('[ChatProvider] 处理撤回消息失败: $e');
      print('[ChatProvider] 堆栈: $stack');
    }
  }

  // 撤回消息流
  final _recallController = StreamController<RecallEvent>.broadcast();
  Stream<RecallEvent> get recallStream => _recallController.stream;

  /// 处理清空会话通知（对方清空了双方的聊天记录）
  Future<void> _handleClearConversation(Map<String, dynamic> data) async {
    try {
      final msgData = data['data'] as Map<String, dynamic>?;
      if (msgData == null) return;

      final conversId = msgData['convers_id'] as String?;
      final clearBy = msgData['clear_by'];

      if (conversId == null || conversId.isEmpty) return;

      // 解析清空者ID
      int? clearById;
      if (clearBy is int) {
        clearById = clearBy;
      } else if (clearBy is String) {
        clearById = int.tryParse(clearBy);
      }

      print('[ChatProvider] 收到清空会话通知: conversId=$conversId, clearBy=$clearById, currentUserId=$_currentUserId');

      // 如果是自己发起的清空操作，忽略此通知（自己清空时已经在本地处理过了）
      if (clearById != null && clearById == _currentUserId) {
        print('[ChatProvider] 忽略自己发起的清空通知');
        return;
      }

      // 清空本地该会话的所有消息
      await _localMessageService.clearConversationMessages(conversId);

      // 更新会话显示（只有对方清空时才显示"被对方清空"的提示）
      final conversation = await _localDb.getConversation(conversId);
      if (conversation != null) {
        final updatedConv = conversation.copyWith(
          lastMsgPreview: '[聊天记录已被对方清空]',
          unreadCount: 0,
        );
        await _localDb.saveConversation(updatedConv);
        await _localMessageService.saveConversation(updatedConv);
      }

      // 重新加载会话列表
      await loadConversations();

      // 通知正在该会话的UI刷新
      _conversationClearedController.add(conversId);

      print('[ChatProvider] 会话 $conversId 的消息已被对方清空');
    } catch (e) {
      print('[ChatProvider] 处理清空会话通知失败: $e');
    }
  }

  /// 获取消息预览文本
  String _getMessagePreview(Message message) {
    switch (message.type) {
      case 1:
        final content = message.content;
        return content.length > 30 ? '${content.substring(0, 30)}...' : content;
      case 2:
        return '[图片]';
      case 3:
        return '[语音]';
      case 4:
        return '[视频]';
      case 5:
        return '[文件]';
      case 6:
        return '[位置]';
      case 7:
        return '[名片]';
      case 8:
        return '[合并转发]';
      case 9:
        return '[通话]';
      case 11:
        return '[红包]';
      case 13:
        return '[视频]';
      case 14:
        return '[直播]';
      default:
        return '[消息]';
    }
  }

  /// 加载所有数据
  Future<void> loadData() async {
    // 先加载好友列表（会话列表需要用到好友信息）
    await Future.wait([
      loadFriends(),
      loadFriendRequests(),
    ]);
    // 再加载会话列表（会调用 _fillConversationTargetInfo 补充好友信息）
    await loadConversations();
    // 加载系统通知未读数
    loadSystemNotificationCount();
  }

  /// 加载会话列表
  Future<void> loadConversations() async {
    if (_currentUserId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 确保 Hive 已初始化
      await _localMessageService.init();

      // 1. 先从 Hive 持久化存储加载
      final hiveConversations = await _localMessageService.getConversations();

      // 2. 同步到内存缓存
      for (final conv in hiveConversations) {
        await _localDb.saveConversation(conv);
      }

      // 3. 从内存缓存获取（已包含 Hive 数据）
      _conversations = await _localDb.getConversations(_currentUserId!);

      // 4. 从服务器同步最新数据（保留本地 isTop/isMute/topTime 设置）
      try {
        final serverConversations = await _conversationApi.getConversationList();
        for (final conv in serverConversations) {
          // 获取本地会话的 isTop/isMute/topTime 设置
          final localConv = await _localDb.getConversation(conv.conversId);
          final mergedConv = localConv != null
              ? conv.copyWith(
                  isTop: localConv.isTop,
                  topTime: localConv.topTime,
                  isMute: localConv.isMute,
                )
              : conv;
          // 保存到内存缓存
          await _localDb.saveConversation(mergedConv);
          // 保存到 Hive 持久化
          await _localMessageService.saveConversation(mergedConv);
        }
      } catch (e) {
        // 服务器同步失败不影响本地数据显示
        print('[ChatProvider] 服务器同步会话失败: $e');
      }

      // 5. 重新从内存加载（包含服务器同步的数据）
      _conversations = await _localDb.getConversations(_currentUserId!);

      // 6. 为缺少 targetInfo 的会话补充用户/群组信息
      await _fillConversationTargetInfo();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 为会话补充目标用户/群组信息
  /// 同时修复 targetId = 0 的损坏会话
  Future<void> _fillConversationTargetInfo() async {
    bool hasUpdates = false;

    for (int i = 0; i < _conversations.length; i++) {
      final conv = _conversations[i];

      // 检查是否需要修复：targetInfo为空 或 targetId为0
      bool needsRepair = conv.targetInfo == null || conv.targetId == 0;
      if (!needsRepair) continue;

      Map<String, dynamic>? targetInfo;
      int repairedTargetId = conv.targetId;

      // 如果 targetId 为0，尝试从 conversId 重新解析
      if (conv.targetId == 0) {
        if (conv.type == 1 && conv.conversId.startsWith('p_')) {
          final parts = conv.conversId.substring(2).split('_');
          if (parts.length == 2) {
            final id1 = int.tryParse(parts[0]) ?? 0;
            final id2 = int.tryParse(parts[1]) ?? 0;
            if (_currentUserId != null && id1 > 0 && id2 > 0) {
              repairedTargetId = (id1 == _currentUserId) ? id2 : id1;
              print('[ChatProvider] 修复私聊会话targetId: conversId=${conv.conversId}, 从${conv.targetId}改为$repairedTargetId');
            }
          }
        } else if (conv.type == 2 && conv.conversId.startsWith('g_')) {
          // 群聊：从g_groupId解析
          repairedTargetId = int.tryParse(conv.conversId.substring(2)) ?? 0;
          print('[ChatProvider] 修复群聊会话targetId: conversId=${conv.conversId}, 从${conv.targetId}改为$repairedTargetId');
        }
      }

      if (conv.type == 1 && repairedTargetId > 0) {
        // 私聊：从好友列表查找
        Friend? friend;
        try {
          friend = _friends.firstWhere((f) => f.friendId == repairedTargetId);
        } catch (_) {
          friend = null;
        }

        if (friend != null) {
          targetInfo = {
            'id': friend.friendId,
            'nickname': friend.displayName,
            'avatar': friend.friend.avatar,
            'username': friend.friend.username,
            'display_name': friend.displayName,
          };
        } else {
          // 不在好友列表中，尝试从服务器获取用户信息
          try {
            final userInfo = await _userApi.getUserById(repairedTargetId);
            if (userInfo != null) {
              final nickname = userInfo['nickname']?.toString() ?? '';
              final username = userInfo['username']?.toString() ?? '';
              targetInfo = {
                'id': repairedTargetId,
                'nickname': nickname,
                'avatar': userInfo['avatar']?.toString() ?? '',
                'username': username,
                'display_name': nickname.isNotEmpty ? nickname : username,
              };
              print('[ChatProvider] 从服务器获取用户信息成功: targetId=$repairedTargetId, nickname=$nickname');
            }
          } catch (e) {
            print('[ChatProvider] 获取用户信息失败: $e');
          }

          // 如果服务器也获取不到，使用默认名称
          targetInfo ??= {
            'id': repairedTargetId,
            'nickname': '用户$repairedTargetId',
            'avatar': '',
            'username': '',
            'display_name': '用户$repairedTargetId',
          };
        }
      } else if (conv.type == 2 && repairedTargetId > 0) {
        // 群聊：获取群组信息
        try {
          final groupInfo = await _groupApi.getGroupInfo(repairedTargetId);
          if (groupInfo != null) {
            targetInfo = {
              'id': groupInfo.id,
              'name': groupInfo.name,
              'avatar': groupInfo.avatar,
              'display_name': groupInfo.name,
            };
            print('[ChatProvider] 补充群组信息: groupId=$repairedTargetId, name=${groupInfo.name}');
          }
        } catch (e) {
          print('[ChatProvider] 获取群组信息失败: $e');
          // 使用默认名称
          targetInfo = {
            'id': repairedTargetId,
            'name': '群组$repairedTargetId',
            'avatar': '',
            'display_name': '群组$repairedTargetId',
          };
        }
      }

      if (targetInfo != null || repairedTargetId != conv.targetId) {
        _conversations[i] = conv.copyWith(
          targetId: repairedTargetId,
          targetInfo: targetInfo ?? conv.targetInfo,
        );
        // 同时更新本地数据库和 Hive
        await _localDb.saveConversation(_conversations[i]);
        await _localMessageService.saveConversation(_conversations[i]);
        hasUpdates = true;
        print('[ChatProvider] 修复会话完成: conversId=${conv.conversId}, targetId=$repairedTargetId, hasTargetInfo=${targetInfo != null}');
      }
    }

    if (hasUpdates) {
      notifyListeners();
    }
  }

  /// 加载好友列表
  Future<void> loadFriends() async {
    try {
      _friends = await _friendApi.getFriendList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  /// 加载好友申请
  Future<void> loadFriendRequests() async {
    try {
      _friendRequests = await _friendApi.getFriendRequests();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  /// 获取按字母分组的好友
  Map<String, List<Friend>> get groupedFriends {
    final grouped = <String, List<Friend>>{};
    for (final friend in _friends) {
      final firstLetter = _getFirstLetter(friend.displayName);
      grouped.putIfAbsent(firstLetter, () => []);
      grouped[firstLetter]!.add(friend);
    }

    // 对每个分组内的好友按拼音排序
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) {
        final pinyinA = PinyinHelper.getPinyinE(a.displayName, separator: '');
        final pinyinB = PinyinHelper.getPinyinE(b.displayName, separator: '');
        return pinyinA.toLowerCase().compareTo(pinyinB.toLowerCase());
      });
    }

    // 按字母排序，# 放最后
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });
    return {for (var key in sortedKeys) key: grouped[key]!};
  }

  /// 获取首字母（使用拼音库处理中文）
  String _getFirstLetter(String name) {
    if (name.isEmpty) return '#';

    final first = name[0];

    // 如果是英文字母，直接返回大写
    if (RegExp(r'[A-Za-z]').hasMatch(first)) {
      return first.toUpperCase();
    }

    // 如果是中文，使用拼音库获取首字母
    if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(first)) {
      final pinyin = PinyinHelper.getFirstWordPinyin(first);
      if (pinyin.isNotEmpty) {
        return pinyin[0].toUpperCase();
      }
    }

    // 其他字符归类到 #
    return '#';
  }

  /// 创建或获取会话
  Future<Conversation> getOrCreateConversation({
    required int targetId,
    required int type,
    dynamic targetInfo,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not logged in');
    }

    // 生成会话ID
    String conversId;
    if (type == 1) {
      // 私聊：使用两个用户ID组合
      final ids = [_currentUserId!, targetId]..sort();
      conversId = 'p_${ids[0]}_${ids[1]}';
    } else {
      // 群聊
      conversId = 'g_$targetId';
    }

    // 查找现有会话
    var conversation = await _localDb.getConversation(conversId);
    if (conversation != null) {
      // 更新targetInfo
      conversation = conversation.copyWith(targetInfo: targetInfo);
      // 预热缓存：从持久化存储同步最近消息到运行时缓存
      await _syncCacheFromPersistence(conversId, limit: 50);
      return conversation;
    }

    // 创建新会话
    conversation = Conversation(
      conversId: conversId,
      userId: _currentUserId,
      type: type,
      targetId: targetId,
      lastMsgTime: DateTime.now(),
      targetInfo: targetInfo,
    );

    await _localDb.saveConversation(conversation);
    // 同时保存到持久化存储
    await _localMessageService.saveConversation(conversation);
    await loadConversations();

    return conversation;
  }

  /// 更新会话（收到新消息时）
  /// 如果会话不存在，会自动创建新会话
  /// [senderInfo] 发送者信息，用于新会话创建时设置targetInfo
  Future<void> updateConversation({
    required String conversId,
    required String lastMsgPreview,
    required DateTime lastMsgTime,
    bool incrementUnread = false,
    int? fromUserId,
    int? toUserId,
    int? groupId,
    Map<String, dynamic>? senderInfo,
  }) async {
    var conversation = await _localDb.getConversation(conversId);

    if (conversation == null) {
      // 会话不存在，创建新会话
      // 解析 conversId 来确定会话类型和目标ID
      int type = 1; // 默认私聊
      int targetId = 0;

      if (conversId.startsWith('g_')) {
        // 群聊: g_群ID
        type = 2;
        targetId = groupId ?? int.tryParse(conversId.substring(2)) ?? 0;
      } else if (conversId.startsWith('p_')) {
        // 私聊: p_小ID_大ID
        type = 1;
        final parts = conversId.substring(2).split('_');
        if (parts.length == 2) {
          final id1 = int.tryParse(parts[0]) ?? 0;
          final id2 = int.tryParse(parts[1]) ?? 0;
          // 目标ID是对方的ID（不是当前用户的ID）
          // 确保 _currentUserId 不为 null 再比较
          if (_currentUserId != null) {
            targetId = (id1 == _currentUserId) ? id2 : id1;
          } else if (toUserId != null && toUserId > 0) {
            // 如果当前用户ID未知，但有toUserId（消息发送给的人就是当前用户）
            // 那么targetId应该是发送者，即fromUserId
            targetId = fromUserId ?? ((id1 == toUserId) ? id2 : id1);
          } else if (fromUserId != null && fromUserId > 0) {
            // 如果有fromUserId（发送者），对方就是非fromUserId的那个
            targetId = (id1 == fromUserId) ? id2 : id1;
          } else {
            // 最后的fallback
            targetId = id1;
          }
          print('[ChatProvider.updateConversation] 解析会话: conversId=$conversId, id1=$id1, id2=$id2, currentUserId=$_currentUserId, fromUserId=$fromUserId, toUserId=$toUserId, targetId=$targetId');
        }
      }

      // 使用传入的发送者信息作为targetInfo（如果有的话）
      Map<String, dynamic>? targetInfo = senderInfo;
      if (type == 2 && targetId > 0) {
        // 群聊：获取群组信息
        try {
          final groupInfo = await _groupApi.getGroupInfo(targetId);
          if (groupInfo != null) {
            targetInfo = {
              'id': groupInfo.id,
              'name': groupInfo.name,
              'avatar': groupInfo.avatar,
              'display_name': groupInfo.name,
            };
            print('[ChatProvider] 获取群组信息成功: groupId=$targetId, name=${groupInfo.name}');
          }
        } catch (e) {
          print('[ChatProvider] 获取群组信息失败: $e');
        }
      } else if (targetInfo == null && type == 1 && targetId > 0) {
        // 如果没有senderInfo，尝试从好友列表获取
        Friend? friend;
        try {
          friend = _friends.firstWhere((f) => f.friendId == targetId);
        } catch (_) {
          friend = null;
        }
        if (friend != null) {
          targetInfo = {
            'id': friend.friendId,
            'nickname': friend.displayName,
            'avatar': friend.friend.avatar,
            'username': friend.friend.username,
            'display_name': friend.displayName,
          };
        }
      }

      conversation = Conversation(
        conversId: conversId,
        userId: _currentUserId,
        type: type,
        targetId: targetId,
        lastMsgPreview: lastMsgPreview,
        lastMsgTime: lastMsgTime,
        unreadCount: incrementUnread ? 1 : 0,
        targetInfo: targetInfo,
      );

      print('[ChatProvider] 创建新会话: conversId=$conversId, type=$type, targetId=$targetId, hasTargetInfo=${targetInfo != null}');
    } else {
      // 会话存在，更新
      // 如果现有会话的targetId为0或targetInfo为空，尝试修复
      int finalTargetId = conversation.targetId;
      Map<String, dynamic>? finalTargetInfo = conversation.targetInfo as Map<String, dynamic>?;

      if (conversation.targetId == 0 && conversId.startsWith('p_')) {
        // 尝试从conversId重新解析targetId
        final parts = conversId.substring(2).split('_');
        if (parts.length == 2) {
          final id1 = int.tryParse(parts[0]) ?? 0;
          final id2 = int.tryParse(parts[1]) ?? 0;
          if (_currentUserId != null) {
            finalTargetId = (id1 == _currentUserId) ? id2 : id1;
          } else if (toUserId != null && toUserId > 0) {
            finalTargetId = fromUserId ?? ((id1 == toUserId) ? id2 : id1);
          } else if (fromUserId != null && fromUserId > 0) {
            finalTargetId = (id1 == fromUserId) ? id2 : id1;
          }
          print('[ChatProvider] 修复会话targetId: 从${conversation.targetId}改为$finalTargetId');
        }
      }

      // 如果没有targetInfo，尝试用senderInfo填充
      if (finalTargetInfo == null && senderInfo != null) {
        finalTargetInfo = senderInfo;
        print('[ChatProvider] 修复会话targetInfo');
      }

      conversation = conversation.copyWith(
        lastMsgPreview: lastMsgPreview,
        lastMsgTime: lastMsgTime,
        unreadCount: incrementUnread ? conversation.unreadCount + 1 : conversation.unreadCount,
        targetId: finalTargetId,
        targetInfo: finalTargetInfo,
      );
    }

    // 保存到内存缓存
    await _localDb.saveConversation(conversation);
    // 保存到 Hive 持久化存储
    await _localMessageService.saveConversation(conversation);
    await loadConversations();
  }

  /// 更新会话最后一条消息（简化版）
  Future<void> updateConversationLastMessage(
    String conversId,
    String lastMsgPreview,
    DateTime lastMsgTime,
  ) async {
    await updateConversation(
      conversId: conversId,
      lastMsgPreview: lastMsgPreview,
      lastMsgTime: lastMsgTime,
    );
  }

  /// 清除会话未读数
  Future<void> clearUnreadCount(String conversId) async {
    // 清除本地未读数
    await _localDb.clearUnreadCount(conversId);
    await _localMessageService.clearUnreadCount(conversId);
    // 通知服务器标记已读（异步执行，不阻塞UI）
    _conversationApi.markConversationRead(conversId).catchError((e) {
      print('[ChatProvider] 标记会话已读失败: $e');
    });
    // 刷新会话列表
    await loadConversations();
  }

  /// 删除会话
  Future<void> deleteConversation(String conversId) async {
    // 先调用服务端 API 删除（服务端软删除）
    try {
      await _conversationApi.deleteConversation(conversId);
    } catch (e) {
      print('[ChatProvider] 服务端删除会话失败: $e');
      // 服务端删除失败也继续删除本地，避免UI卡住
    }
    await _localDb.deleteConversation(conversId);
    await _localMessageService.deleteConversation(conversId);
    await loadConversations();
  }

  /// 置顶会话
  Future<void> toggleConversationTop(String conversId, bool isTop) async {
    print('[ChatProvider] toggleConversationTop: conversId=$conversId, isTop=$isTop');
    // 更新内存缓存
    await _localDb.toggleConversationTop(conversId, isTop);
    // 持久化到 Hive
    await _localMessageService.toggleConversationTop(conversId, isTop);
    // 重新加载会话列表（会触发排序）
    _conversations = await _localDb.getConversations(_currentUserId!);
    // 验证结果
    final conv = _conversations.firstWhere((c) => c.conversId == conversId, orElse: () => Conversation(conversId: '', type: 0, targetId: 0));
    print('[ChatProvider] toggleConversationTop 验证: isTop=${conv.isTop}, topTime=${conv.topTime}');
    notifyListeners();
  }

  /// 设置会话免打扰
  Future<void> toggleConversationMute(String conversId, bool isMute) async {
    print('[ChatProvider] toggleConversationMute: conversId=$conversId, isMute=$isMute');
    // 更新内存缓存
    await _localDb.toggleConversationMute(conversId, isMute);
    // 持久化到 Hive (会话列表)
    await _localMessageService.setConversationMute(conversId, isMute);
    // 持久化到 ChatSettingsService (用于通知判断)
    await _chatSettingsService.setMuted(conversId, isMute);
    // 验证保存结果
    final savedMute = await _chatSettingsService.isMuted(conversId);
    print('[ChatProvider] toggleConversationMute 验证结果: savedMute=$savedMute');
    // 重新加载会话列表
    _conversations = await _localDb.getConversations(_currentUserId!);
    notifyListeners();
  }

  /// 清空会话本地消息
  Future<void> clearLocalMessages(String conversId) async {
    // 清空本地存储的消息
    await _localMessageService.clearConversationMessages(conversId);
    // 清空内存缓存的消息
    await _localDb.deleteConversationMessages(conversId);
    // 通知聊天页面更新
    _conversationClearedController.add(conversId);
    // 更新会话列表的最后消息预览
    await loadConversations();
  }

  /// 删除好友
  Future<ApiResult> deleteFriend(int friendId) async {
    final result = await _friendApi.deleteFriend(friendId);
    if (result.success) {
      await loadFriends();
      // 删除本地会话和消息，使用工具类生成正确的conversId
      final conversId = ConversationUtils.generateConversId(
        userId1: _currentUserId ?? 0,
        userId2: friendId,
      );
      await _localMessageService.clearConversationMessages(conversId);
      await _localDb.deleteConversationMessages(conversId);
      _conversationClearedController.add(conversId);
      await loadConversations();
    }
    return result;
  }

  /// 添加到黑名单
  /// 注意：加入黑名单不会删除好友关系和聊天记录，只是阻止双方收发消息
  Future<ApiResult> addToBlacklist(int userId) async {
    final result = await _friendApi.addToBlacklist(userId);
    if (result.success) {
      await loadFriends();
    }
    return result;
  }

  /// 从黑名单移除
  /// 移除后好友会重新显示在通讯录中
  Future<ApiResult> removeFromBlacklist(int userId) async {
    final result = await _friendApi.removeFromBlacklist(userId);
    if (result.success) {
      await loadFriends();
    }
    return result;
  }

  /// 添加好友
  Future<ApiResult> addFriend(int userId, {String? message}) async {
    return await _friendApi.addFriend(userId: userId, message: message);
  }

  /// 处理好友申请
  /// action: 1 = 同意, 2 = 拒绝
  Future<ApiResult> handleFriendRequest(int requestId, int action) async {
    final result = await _friendApi.handleFriendRequest(
      requestId: requestId,
      action: action,
    );
    if (result.success) {
      await loadFriendRequests();
      if (action == 1) {
        await loadFriends();
      }
    }
    return result;
  }

  /// 更新好友备注
  Future<ApiResult> updateFriendRemark(
    int friendId, {
    String? remark,
    String? remarkPhone,
    String? remarkEmail,
    String? remarkTags,
    String? remarkDesc,
  }) async {
    final result = await _friendApi.updateRemark(
      friendId,
      remark: remark,
      remarkPhone: remarkPhone,
      remarkEmail: remarkEmail,
      remarkTags: remarkTags,
      remarkDesc: remarkDesc,
    );
    if (result.success) {
      // 刷新好友列表以更新显示名称
      await loadFriends();
      // 刷新会话列表以更新会话名称
      await loadConversations();
    }
    return result;
  }

  /// 保存消息到本地
  /// 统一存储策略：同时写入持久化存储(Hive)和运行时缓存(SQLite)
  Future<void> saveMessage(Message message) async {
    // 1. 写入持久化存储 (LocalMessageService - Hive)
    await _localMessageService.saveMessage(message);
    // 2. 写入运行时缓存 (LocalDatabaseService - SQLite)
    await _localDb.saveMessage(message);
  }

  /// 获取会话消息
  /// 统一存储策略：优先从运行时缓存获取，缓存不足时从持久化存储补充
  Future<List<Message>> getMessages({
    required String conversId,
    int limit = 20,
    DateTime? beforeTime,
  }) async {
    // 1. 先从运行时缓存获取
    var messages = await _localDb.getMessages(
      conversId: conversId,
      limit: limit,
      beforeTime: beforeTime,
    );

    // 2. 如果缓存数据不足，从持久化存储获取
    if (messages.length < limit) {
      final lastMsgId = messages.isNotEmpty ? messages.last.msgId : null;
      final persistedMessages = await _localMessageService.getMessages(
        conversId,
        limit: limit,
        beforeMsgId: lastMsgId,
      );

      // 合并去重
      final existingIds = messages.map((m) => m.msgId).toSet();
      for (final msg in persistedMessages) {
        if (!existingIds.contains(msg.msgId)) {
          messages.add(msg);
          // 同步到运行时缓存
          await _localDb.saveMessage(msg);
        }
      }

      // 重新排序
      messages.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.now();
        final bTime = b.createdAt ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      // 限制返回数量
      if (messages.length > limit) {
        messages = messages.sublist(0, limit);
      }
    }

    return messages;
  }

  /// 从持久化存储同步数据到运行时缓存
  /// 用于应用启动时预热缓存
  Future<void> _syncCacheFromPersistence(String conversId, {int limit = 50}) async {
    final persistedMessages = await _localMessageService.getMessages(conversId, limit: limit);
    for (final msg in persistedMessages) {
      await _localDb.saveMessage(msg);
    }
  }

  /// 搜索本地消息
  Future<List<Message>> searchLocalMessages(String keyword, {String? conversId, int limit = 50}) async {
    return await _localMessageService.searchMessages(keyword, conversId: conversId, limit: limit);
  }

  /// 导出消息备份
  Future<Map<String, dynamic>> exportMessages() async {
    return await _localMessageService.exportMessages();
  }

  /// 导入消息备份
  Future<int> importMessages(Map<String, dynamic> exportData) async {
    return await _localMessageService.importMessages(exportData);
  }

  /// 获取消息上下文
  Future<Map<String, List<Message>>> getMessageContext(String conversId, String msgId, {int before = 5, int after = 5}) async {
    return await _localMessageService.getMessageContext(conversId, msgId, before: before, after: after);
  }

  /// 清除所有数据（退出登录）
  Future<void> clear() async {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _conversations = [];
    _friends = [];
    _friendRequests = [];
    _currentUserId = null;
    _initialized = false;
    _systemNotificationUnreadCount = 0;
    await _localDb.clearAllData();
    notifyListeners();
  }

  @override
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wsSubscription?.cancel();
    _connectionSubscription?.cancel();
    _newMessageController.close();
    _conversationClearedController.close();
    _recallController.close();
    _redPacketController.close();
    _groupSettingsUpdateController.close();
    _groupJoinRequestController.close();
    _messageBlockedController.close();
    _goldBeanNotifyController.close();
    _systemNotifyController.close();
    super.dispose();
  }
}
