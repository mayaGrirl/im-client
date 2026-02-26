/// 礼物动画覆盖层
/// TikTok风格礼物动画效果：banner/center/fullscreen + 连击计数
/// 队列系统：banner可并发，center/fullscreen排队播放
/// 连击系统：相同礼物3秒内连续送出，显示 x2, x3... 递增动画

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:im_client/l10n/app_localizations.dart';

/// 礼物动画类型
enum GiftAnimationType { banner, center, fullscreen }

/// 礼物动画数据
class GiftAnimationData {
  final String giftName;
  final String giftIcon;
  final int count;
  final String senderName;
  final String? senderAvatar;
  final int price;
  final GiftAnimationType animationType;
  final bool isSpecial;
  final int tier;
  final bool comboEnabled;
  final int animationDuration;
  final int senderId;
  final String effectUrl;

  GiftAnimationData({
    required this.giftName,
    required this.giftIcon,
    required this.count,
    required this.senderName,
    this.senderAvatar,
    required this.price,
    required this.animationType,
    this.isSpecial = false,
    this.tier = 1,
    this.comboEnabled = false,
    this.animationDuration = 3000,
    this.senderId = 0,
    this.effectUrl = '',
  });

  factory GiftAnimationData.fromAnimationString(String animation, {
    required String giftName,
    required String giftIcon,
    required int count,
    required String senderName,
    String? senderAvatar,
    required int price,
    bool isSpecial = false,
    int tier = 1,
    bool comboEnabled = false,
    int animationDuration = 3000,
    int senderId = 0,
    String effectUrl = '',
  }) {
    GiftAnimationType type;
    switch (animation) {
      case 'center':
        type = GiftAnimationType.center;
        break;
      case 'fullscreen':
        type = GiftAnimationType.fullscreen;
        break;
      default:
        type = GiftAnimationType.banner;
    }
    return GiftAnimationData(
      giftName: giftName,
      giftIcon: giftIcon,
      count: count,
      senderName: senderName,
      senderAvatar: senderAvatar,
      price: price,
      animationType: type,
      isSpecial: isSpecial,
      tier: tier,
      comboEnabled: comboEnabled,
      animationDuration: animationDuration,
      senderId: senderId,
      effectUrl: effectUrl,
    );
  }

  /// 构建礼物图标：优先Lottie，其次GIF/图片，最后emoji
  Widget buildGiftIcon({double size = 48}) {
    if (effectUrl.isNotEmpty) {
      if (effectUrl.endsWith('.json')) {
        return SizedBox(
          width: size,
          height: size,
          child: Lottie.network(
            effectUrl,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Text(giftIcon, style: TextStyle(fontSize: size * 0.7));
            },
          ),
        );
      } else if (effectUrl.endsWith('.gif') || effectUrl.startsWith('http')) {
        return SizedBox(
          width: size,
          height: size,
          child: Image.network(
            effectUrl,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(giftIcon, style: TextStyle(fontSize: size * 0.7)),
          ),
        );
      }
    }
    return Text(giftIcon, style: TextStyle(fontSize: size * 0.7));
  }
}

class GiftAnimationOverlay extends StatefulWidget {
  const GiftAnimationOverlay({super.key});

  @override
  GiftAnimationOverlayState createState() => GiftAnimationOverlayState();
}

class GiftAnimationOverlayState extends State<GiftAnimationOverlay>
    with TickerProviderStateMixin {
  final List<_BannerItem> _bannerItems = [];
  final List<GiftAnimationData> _queue = [];
  bool _playingCenter = false;
  _CenterItem? _currentCenter;
  final Random _random = Random();

  // 连击追踪: key = "senderId_giftName"
  final Map<String, _ComboTracker> _comboTrackers = {};

  /// 外部调用：展示礼物动画
  void showGift(GiftAnimationData data) {
    if (data.animationType == GiftAnimationType.banner) {
      _showBanner(data);
    } else {
      // 豪华礼物优先排队
      if (data.tier == 3 && _queue.isNotEmpty) {
        _queue.insert(0, data);
      } else {
        _queue.add(data);
      }
      _processQueue();
    }
  }

  String _comboKey(GiftAnimationData data) =>
      '${data.senderId}_${data.giftName}';

  void _showBanner(GiftAnimationData data) {
    // 连击检测
    final key = _comboKey(data);
    if (data.comboEnabled) {
      final existing = _bannerItems.where((item) =>
        _comboKey(item.data) == key &&
        item.controller.isAnimating).toList();

      if (existing.isNotEmpty) {
        // 更新已有banner的连击数
        final item = existing.first;
        item.comboCount += data.count;
        item.comboAnimController?.forward(from: 0);
        // 延长显示时间：重置controller
        if (item.controller.value < 0.6) {
          // 还在显示中，不需要处理
        }
        if (mounted) setState(() {});
        return;
      }
    }

    final duration = Duration(milliseconds: data.animationDuration > 0 ? data.animationDuration : 3000);
    final controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    final slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Interval(0, 0.3, curve: Curves.easeOut),
    ));

    final fadeOutAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    ));

    // 连击计数弹跳动画
    final comboAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    final comboScale = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: comboAnimController, curve: Curves.elasticOut),
    );

    // 计算banner位置（最多3个同时显示）
    double topOffset = 100.0;
    for (int i = 0; i < _bannerItems.length && i < 2; i++) {
      topOffset += 56.0;
    }

    final item = _BannerItem(
      data: data,
      controller: controller,
      slideAnimation: slideAnimation,
      fadeOutAnimation: fadeOutAnimation,
      topOffset: topOffset,
      comboCount: data.count,
      comboAnimController: comboAnimController,
      comboScale: comboScale,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _bannerItems.remove(item);
        controller.dispose();
        comboAnimController.dispose();
        if (mounted) setState(() {});
      }
    });

    setState(() => _bannerItems.add(item));
    controller.forward();
  }

  void _processQueue() {
    if (_playingCenter || _queue.isEmpty) return;
    _playingCenter = true;

    final data = _queue.removeAt(0);
    if (data.animationType == GiftAnimationType.fullscreen) {
      _showFullscreen(data);
    } else {
      _showCenter(data);
    }
  }

  void _showCenter(GiftAnimationData data) {
    final duration = Duration(milliseconds: data.animationDuration > 0 ? data.animationDuration : 2500);
    final controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    final scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0, 0.4, curve: Curves.elasticOut),
      ),
    );

    final fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    final item = _CenterItem(
      data: data,
      controller: controller,
      scaleAnimation: scaleAnimation,
      fadeOutAnimation: fadeOutAnimation,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        _currentCenter = null;
        _playingCenter = false;
        if (mounted) setState(() {});
        _processQueue();
      }
    });

    setState(() => _currentCenter = item);
    controller.forward();
  }

  void _showFullscreen(GiftAnimationData data) {
    final duration = Duration(milliseconds: data.animationDuration > 0 ? data.animationDuration : 3500);
    final controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    final scaleAnimation = Tween<double>(begin: 0.3, end: 1.2).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0, 0.3, curve: Curves.easeOutBack),
      ),
    );

    final fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
      ),
    );

    final item = _CenterItem(
      data: data,
      controller: controller,
      scaleAnimation: scaleAnimation,
      fadeOutAnimation: fadeOutAnimation,
      isFullscreen: true,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        _currentCenter = null;
        _playingCenter = false;
        if (mounted) setState(() {});
        _processQueue();
      }
    });

    setState(() => _currentCenter = item);
    controller.forward();
  }

  @override
  void dispose() {
    for (final item in List.from(_bannerItems)) {
      item.controller.dispose();
      item.comboAnimController?.dispose();
    }
    _currentCenter?.controller.dispose();
    _bannerItems.clear();
    _queue.clear();
    _comboTrackers.clear();
    super.dispose();
  }

  // 档次对应的渐变色
  List<Color> _tierGradient(int tier) {
    switch (tier) {
      case 3:
        return [Colors.deepPurple.withValues(alpha: 0.9), Colors.pink.withValues(alpha: 0.9)];
      case 2:
        return [Colors.orange.withValues(alpha: 0.9), Colors.red.withValues(alpha: 0.9)];
      default:
        return [Colors.blue.withValues(alpha: 0.85), Colors.cyan.withValues(alpha: 0.85)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Banner礼物通知
          ..._bannerItems.map(_buildBanner),

          // Center/Fullscreen礼物
          if (_currentCenter != null) _buildCenterGift(_currentCenter!),
        ],
      ),
    );
  }

  Widget _buildBanner(_BannerItem item) {
    final tierColors = _tierGradient(item.data.tier);
    return AnimatedBuilder(
      animation: item.controller,
      builder: (context, child) {
        return Positioned(
          top: item.topOffset,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: item.slideAnimation,
            child: FadeTransition(
              opacity: item.fadeOutAnimation,
              child: child!,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: tierColors),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: tierColors.first.withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头像
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                child: Text(
                  item.data.senderName.isNotEmpty
                      ? item.data.senderName[0]
                      : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              // 文本
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.data.senderName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      AppLocalizations.of(context)!.translate('sent_gift_combo').replaceAll('{gift}', item.data.giftName),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 礼物图标（支持Lottie）
              item.data.buildGiftIcon(size: 36),
              const SizedBox(width: 4),
              // 连击计数
              if (item.comboCount > 0)
                AnimatedBuilder(
                  animation: item.comboScale ?? const AlwaysStoppedAnimation(1.0),
                  builder: (context, child) {
                    final scale = item.comboScale?.value ?? 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _comboCountColor(item.comboCount),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'x${item.comboCount}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: item.comboCount >= 10 ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        shadows: item.comboCount >= 6
                            ? const [Shadow(color: Colors.amber, blurRadius: 6)]
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _comboCountColor(int count) {
    if (count >= 10) return Colors.deepPurple;
    if (count >= 6) return Colors.orange;
    return Colors.red.withValues(alpha: 0.8);
  }

  Widget _buildCenterGift(_CenterItem item) {
    return AnimatedBuilder(
      animation: item.controller,
      builder: (context, child) {
        return Positioned.fill(
          child: FadeTransition(
            opacity: item.fadeOutAnimation,
            child: Container(
              color: item.isFullscreen
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.transparent,
              child: Center(
                child: ScaleTransition(
                  scale: item.scaleAnimation,
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 礼物图标
          Container(
            width: item.isFullscreen ? 120 : 80,
            height: item.isFullscreen ? 120 : 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: item.data.tier >= 2
                  ? [
                      BoxShadow(
                        color: item.data.tier == 3
                            ? Colors.purple.withValues(alpha: 0.7)
                            : Colors.amber.withValues(alpha: 0.6),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: item.data.buildGiftIcon(size: item.isFullscreen ? 100 : 70),
            ),
          ),
          const SizedBox(height: 12),
          // 礼物名称
          Text(
            item.data.giftName,
            style: TextStyle(
              color: Colors.white,
              fontSize: item.isFullscreen ? 24 : 18,
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 发送者
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              AppLocalizations.of(context)!.translate('gift_sent_by_count').replaceAll('{name}', item.data.senderName).replaceAll('{count}', '${item.data.count}'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
          if (item.isFullscreen) ...[
            const SizedBox(height: 8),
            // 粒子效果 - 根据档次选择不同粒子
            SizedBox(
              width: 240,
              height: 50,
              child: Stack(
                children: List.generate(12, (i) {
                  final particles = item.data.tier == 3
                      ? ['✨', '💎', '👑', '🌟', '💫', '⭐']
                      : ['✨', '⭐', '💫', '🌟'];
                  return Positioned(
                    left: 10.0 + _random.nextDouble() * 220,
                    top: _random.nextDouble() * 40,
                    child: Text(
                      particles[i % particles.length],
                      style: TextStyle(fontSize: 12 + _random.nextDouble() * 10),
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerItem {
  final GiftAnimationData data;
  final AnimationController controller;
  final Animation<Offset> slideAnimation;
  final Animation<double> fadeOutAnimation;
  final double topOffset;
  int comboCount;
  final AnimationController? comboAnimController;
  final Animation<double>? comboScale;

  _BannerItem({
    required this.data,
    required this.controller,
    required this.slideAnimation,
    required this.fadeOutAnimation,
    required this.topOffset,
    this.comboCount = 1,
    this.comboAnimController,
    this.comboScale,
  });
}

class _CenterItem {
  final GiftAnimationData data;
  final AnimationController controller;
  final Animation<double> scaleAnimation;
  final Animation<double> fadeOutAnimation;
  final bool isFullscreen;

  _CenterItem({
    required this.data,
    required this.controller,
    required this.scaleAnimation,
    required this.fadeOutAnimation,
    this.isFullscreen = false,
  });
}

class _ComboTracker {
  int count;
  Timer? timer;
  _ComboTracker({this.count = 1, this.timer});
}
