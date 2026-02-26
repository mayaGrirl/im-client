/// 主页面
/// 包含消息、通讯录、发现、我的四个Tab

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/providers/chat_provider.dart';
import 'package:im_client/screens/tabs/message_tab.dart';
import 'package:im_client/screens/tabs/contacts_tab.dart';
import 'package:im_client/screens/tabs/discover_tab.dart';
import 'package:im_client/screens/tabs/profile_tab.dart';
import 'package:im_client/services/webrtc_service.dart';
import 'package:im_client/services/call_ringtone_service.dart';
import 'package:im_client/services/web_push_service.dart';
import 'package:im_client/screens/call/incoming_call_overlay.dart';
import 'package:im_client/screens/call/call_screen.dart';
import 'package:im_client/screens/call/group_call_overlay.dart';
import 'package:im_client/providers/group_call_provider.dart';
import 'package:im_client/api/call_api.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/services/notification_service.dart';
// 条件导入：默认使用 stub（非web），web 平台使用 dart:html
import 'package:im_client/utils/html_stub.dart' as html
    if (dart.library.html) 'dart:html';

/// 主页面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final WebRTCService _webrtcService = WebRTCService();
  final CallRingtoneService _ringtoneService = CallRingtoneService();
  final WebPushService _webPushService = WebPushService();
  StreamSubscription? _callActionSub;

  // Web端iOS音频解锁提示相关
  bool _showAudioUnlockBanner = false;
  bool _hasUserInteracted = false;

  List<Widget> _buildTabs() => [
    const MessageTab(),
    ContactsTab(isVisible: _currentIndex == 1),
    const DiscoverTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    // 延迟初始化，确保context可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initWebRTCService();
      _checkWebAudioStatus();
      _initWebPushService();
    });
  }

  /// 初始化Web Push服务（仅Web端）
  Future<void> _initWebPushService() async {
    if (!kIsWeb) return;

    try {
      await _webPushService.initialize();

      // 设置来电推送回调
      _webPushService.onIncomingCallNotification = (callId, callerId, callerName, callerAvatar, callType) {
        debugPrint('[HomeScreen] 收到Web Push来电通知: callId=$callId');
        // 如果应用在前台，WebRTC服务会处理来电
        // 这里主要处理从后台点击通知进入的情况
      };

      // 检查权限状态，如果已授权且已订阅，不需要做任何事
      // 如果已授权但未订阅，自动订阅（可能是之前订阅过但服务器数据丢失）
      final status = await _webPushService.getPermissionStatus();
      if (status == NotificationPermissionStatus.granted) {
        final subscription = await _webPushService.getSubscription();
        if (subscription == null) {
          // 已授权但未订阅，自动订阅
          await _subscribeToWebPush();
        } else {
          debugPrint('[HomeScreen] Web Push已订阅');
        }
      }
      // 不自动请求权限，让用户在设置中手动开启
    } catch (e) {
      debugPrint('[HomeScreen] Web Push初始化失败: $e');
    }
  }

  /// 订阅Web Push通知
  Future<void> _subscribeToWebPush() async {
    try {
      // 从服务器获取VAPID公钥
      final response = await CallApi(ApiClient()).getVapidPublicKey();
      if (response.success && response.data != null) {
        final vapidKey = response.data['vapid_public_key'] as String?;
        if (vapidKey != null && vapidKey.isNotEmpty) {
          await _webPushService.subscribe(vapidKey);
          debugPrint('[HomeScreen] Web Push订阅成功');
        }
      }
    } catch (e) {
      debugPrint('[HomeScreen] Web Push订阅失败: $e');
    }
  }

  /// 检查Web音频状态，显示解锁提示（仅iOS Web需要）
  void _checkWebAudioStatus() {
    if (kIsWeb && _isIOSWeb() && !_ringtoneService.isWebAudioUnlocked) {
      setState(() {
        _showAudioUnlockBanner = true;
      });
    }
  }

  /// 检测是否是iOS Web浏览器
  bool _isIOSWeb() {
    if (!kIsWeb) return false;
    try {
      final userAgent = html.window.navigator.userAgent.toLowerCase();
      // 检测 iPhone, iPad, iPod
      if (userAgent.contains('iphone') ||
          userAgent.contains('ipad') ||
          userAgent.contains('ipod')) {
        return true;
      }
      // iOS 13+ iPad 可能显示为 Mac，通过触摸点数检测
      if (userAgent.contains('macintosh')) {
        final maxTouchPoints = html.window.navigator.maxTouchPoints;
        return maxTouchPoints != null && maxTouchPoints > 0;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 处理用户交互，解锁Web音频（仅iOS Web需要）
  void _handleUserInteraction() {
    if (!kIsWeb || _hasUserInteracted) return;

    // 仅iOS Web需要解锁
    if (!_isIOSWeb()) return;

    _hasUserInteracted = true;
    debugPrint('[HomeScreen] iOS Web用户交互，尝试解锁音频...');

    // 解锁音频
    _ringtoneService.unlockWebAudio().then((_) {
      debugPrint('[HomeScreen] iOS Web音频解锁完成');
      if (mounted && _showAudioUnlockBanner) {
        setState(() {
          _showAudioUnlockBanner = false;
        });
      }
    });
  }

  // 来电悬浮层
  OverlayEntry? _incomingCallOverlay;

  // 群通话来电悬浮层
  OverlayEntry? _incomingGroupCallOverlay;

  /// 初始化WebRTC服务和来电监听
  Future<void> _initWebRTCService() async {
    try {
      // 设置当前用户ID（用于铃声设置判断）
      final authProvider = context.read<AuthProvider>();
      if (authProvider.userId > 0) {
        _webrtcService.setCurrentUserId(authProvider.userId);
      }

      await _webrtcService.initialize();

      // 设置来电回调
      _webrtcService.onIncomingCall = (callId, callerId, callerName, callerAvatar, callType) {
        _showIncomingCall(callId, callerId, callerName, callerAvatar, callType);
        // 同时显示系统通知（后台/锁屏时用户可见，含接听/拒绝按钮）
        NotificationService().showIncomingCallNotification(
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          callerAvatar: callerAvatar,
          callType: callType,
        );
      };

      // 设置来电取消回调（主叫方取消）
      _webrtcService.onIncomingCallCancelled = () {
        _dismissIncomingCall();
        NotificationService().cancelCallNotification();
      };

      // 监听通知栏来电操作（接听/拒绝）
      _callActionSub = NotificationService().onCallAction.listen(_handleCallAction);
    } catch (e) {
          debugPrint('WebRTC initialization failed: $e');
    }
  }

  /// 处理通知栏来电操作
  void _handleCallAction(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    debugPrint('[HomeScreen] 通知栏来电操作: $action');

    if (action == NotificationActions.acceptCall) {
      // 从通知栏接听 - 显示通话页面
      final callId = data['call_id'] as String? ?? '';
      final callerId = int.tryParse(data['caller_id']?.toString() ?? '') ?? 0;
      final callerName = data['caller_name'] as String? ?? '';
      final callerAvatar = data['caller_avatar'] as String? ?? '';
      final callType = int.tryParse(data['call_type']?.toString() ?? '') ?? CallType.voice;

      _dismissIncomingCall();
      NotificationService().cancelCallNotification();
      if (mounted && callId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CallScreen(
              targetUserId: callerId,
              targetUserName: callerName,
              targetUserAvatar: callerAvatar,
              callType: callType,
              isIncoming: true,
              callId: callId,
            ),
          ),
        );
      }
    } else if (action == NotificationActions.rejectCall) {
      // 从通知栏拒绝
      _webrtcService.rejectCall();
      _dismissIncomingCall();
      NotificationService().cancelCallNotification();
    }
  }

  /// 关闭来电悬浮层
  void _dismissIncomingCall() {
    _incomingCallOverlay?.remove();
    _incomingCallOverlay = null;
  }

  /// 管理群通话来电Overlay（由build方法中的Consumer触发）
  void _updateGroupCallOverlay(GroupCallProvider provider) {
    if (!mounted) return;

    if (provider.incomingCall != null && _incomingGroupCallOverlay == null) {
      _showIncomingGroupCall(provider);
    } else if (provider.incomingCall == null && _incomingGroupCallOverlay != null) {
      _dismissIncomingGroupCall();
    }
  }

  /// 显示群通话来电界面（全局Overlay，最高优先级）
  void _showIncomingGroupCall(GroupCallProvider provider) {
    if (!mounted) return;
    _dismissIncomingGroupCall();

    final overlay = Overlay.of(context);
    final incoming = provider.incomingCall!;
    // 保存 HomeScreen 的 context，因为 OverlayEntry 的 builder context 在移除后会失效
    final homeContext = context;

    _incomingGroupCallOverlay = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: MediaQuery.of(overlayContext).padding.top,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: IncomingGroupCallBanner(
            callId: incoming.callId,
            groupId: incoming.groupId,
            callType: incoming.callType,
            initiatorName: incoming.initiatorName,
            initiatorAvatar: incoming.initiatorAvatar,
            groupName: incoming.groupName,
            onJoin: () async {
              final incomingCall = provider.incomingCall;
              if (incomingCall == null) return;
              provider.clearIncomingCall();
              _dismissIncomingGroupCall();
              final success = await provider.joinCall(
                incomingCall.groupId,
                incomingCall.callId,
                incomingCall.callType,
                groupName: incomingCall.groupName,
              );
              if (success && mounted) {
                GroupCallOverlayManager.show(homeContext);
              }
            },
            onDismiss: () {
              provider.clearIncomingCall();
              _dismissIncomingGroupCall();
            },
          ),
        ),
      ),
    );

    overlay.insert(_incomingGroupCallOverlay!);
    debugPrint('[HomeScreen] 已显示群通话来电Overlay: callId=${incoming.callId}');
  }

  /// 关闭群通话来电悬浮层
  void _dismissIncomingGroupCall() {
    if (_incomingGroupCallOverlay != null) {
      _incomingGroupCallOverlay!.remove();
      _incomingGroupCallOverlay = null;
      debugPrint('[HomeScreen] 已关闭群通话来电Overlay');
    }
  }

  /// 显示来电界面
  void _showIncomingCall(String callId, int callerId, String callerName, String callerAvatar, int callType) {
    if (!mounted) return;

    // 先关闭之前的来电悬浮层（如果有的话）
    _dismissIncomingCall();

    // 使用Overlay显示来电通知
    final overlay = Overlay.of(context);

    _incomingCallOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: IncomingCallOverlay(
            callId: callId,
            callerId: callerId,
            callerName: callerName,
            callerAvatar: callerAvatar,
            callType: callType,
            onDismiss: _dismissIncomingCall,
          ),
        ),
      ),
    );

    overlay.insert(_incomingCallOverlay!);
  }

  @override
  void dispose() {
    _dismissIncomingCall();
    _dismissIncomingGroupCall();
    // 清除回调
    _webrtcService.onIncomingCall = null;
    _webrtcService.onIncomingCallCancelled = null;
    // 清理Web Push回调
    _webPushService.onIncomingCallNotification = null;
    _webPushService.onNotificationClick = null;
    // 清理通知来电操作监听
    _callActionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 监听GroupCallProvider变化，管理来电Overlay
    final groupCallProvider = context.watch<GroupCallProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateGroupCallOverlay(groupCallProvider);
      }
    });

    // Web端使用GestureDetector捕获任意用户交互来解锁音频
    Widget scaffold = Scaffold(
      body: Column(
        children: [
          // iOS Web音频解锁提示横幅
          if (_showAudioUnlockBanner)
            _buildAudioUnlockBanner(l10n),
          // 主内容
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _buildTabs(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(l10n),
    );

    // iOS Web端包装GestureDetector以捕获用户交互解锁音频
    // Android Web不需要此处理
    if (kIsWeb && _isIOSWeb()) {
      return GestureDetector(
        onTap: _handleUserInteraction,
        onPanDown: (_) => _handleUserInteraction(),
        behavior: HitTestBehavior.translucent,
        child: scaffold,
      );
    }

    return scaffold;
  }

  /// 构建iOS Web音频解锁提示横幅
  Widget _buildAudioUnlockBanner(AppLocalizations l10n) {
    return Material(
      color: AppColors.primary.withOpacity(0.95),
      child: InkWell(
        onTap: () {
          _handleUserInteraction();
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.translate('tap_to_enable_sound'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建底部导航栏
  Widget _buildBottomNavigationBar(AppLocalizations l10n) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              // iOS Web端：解锁音频（_handleUserInteraction内部检测iOS）
              _handleUserInteraction();
              setState(() => _currentIndex = index);
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.white,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: [
              BottomNavigationBarItem(
                icon: _buildBadgeIcon(
                  Icons.chat_bubble_outline,
                  chatProvider.messageTabTotalCount,
                ),
                activeIcon: _buildBadgeIcon(
                  Icons.chat_bubble,
                  chatProvider.messageTabTotalCount,
                ),
                label: l10n.messages,
              ),
              BottomNavigationBarItem(
                icon: _buildBadgeIcon(
                  Icons.people_outline,
                  chatProvider.unreadFriendRequestCount,
                ),
                activeIcon: _buildBadgeIcon(
                  Icons.people,
                  chatProvider.unreadFriendRequestCount,
                ),
                label: l10n.contacts,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.explore_outlined),
                activeIcon: const Icon(Icons.explore),
                label: l10n.discover,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                activeIcon: const Icon(Icons.person),
                label: l10n.profile,
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建带角标的图标
  Widget _buildBadgeIcon(IconData icon, int count) {
    if (count <= 0) {
      return Icon(icon);
    }
    return Badge(
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(fontSize: 10),
      ),
      child: Icon(icon),
    );
  }
}
