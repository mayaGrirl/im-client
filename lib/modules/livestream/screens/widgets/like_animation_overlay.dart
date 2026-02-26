/// 点赞动画覆盖�?
/// 右侧浮动爱心动画，从底部飘向顶部

import 'dart:math';
import 'package:flutter/material.dart';

class LikeAnimationOverlay extends StatefulWidget {
  const LikeAnimationOverlay({super.key});

  @override
  LikeAnimationOverlayState createState() => LikeAnimationOverlayState();
}

class LikeAnimationOverlayState extends State<LikeAnimationOverlay>
    with TickerProviderStateMixin {
  final List<_HeartItem> _hearts = [];
  final Random _random = Random();

  static const _colors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.orange,
    Colors.yellow,
    Colors.deepPurple,
    Colors.pinkAccent,
  ];

  static const _icons = [
    Icons.favorite,
    Icons.favorite_border,
    Icons.favorite_rounded,
  ];

  /// 触发点赞动画�?-3颗心�?
  void addLike({int count = 0}) {
    final heartCount = count > 0 ? count : (1 + _random.nextInt(3));
    for (int i = 0; i < heartCount; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (!mounted) return;
        _addHeart();
      });
    }
  }

  void _addHeart() {
    final controller = AnimationController(
      duration: Duration(milliseconds: 2000 + _random.nextInt(2000)),
      vsync: this,
    );

    final color = _colors[_random.nextInt(_colors.length)];
    final size = 20.0 + _random.nextDouble() * 16;
    final icon = _icons[_random.nextInt(_icons.length)];
    final horizontalDrift = -20.0 + _random.nextDouble() * 40;

    final riseAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );

    final fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    final scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.6),
        weight: 70,
      ),
    ]).animate(controller);

    final item = _HeartItem(
      controller: controller,
      riseAnimation: riseAnimation,
      fadeAnimation: fadeAnimation,
      scaleAnimation: scaleAnimation,
      color: color,
      size: size,
      icon: icon,
      horizontalDrift: horizontalDrift,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _hearts.remove(item);
        controller.dispose();
        if (mounted) setState(() {});
      }
    });

    setState(() => _hearts.add(item));
    controller.forward();
  }

  @override
  void dispose() {
    for (final item in List.from(_hearts)) {
      item.controller.dispose();
    }
    _hearts.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 80,
        height: 300,
        child: Stack(
          clipBehavior: Clip.none,
          children: _hearts.map((item) {
            return AnimatedBuilder(
              animation: item.controller,
              builder: (context, child) {
                final rise = item.riseAnimation.value;
                final fade = item.fadeAnimation.value;
                final scale = item.scaleAnimation.value;
                // Sine wave horizontal drift
                final dx = item.horizontalDrift * sin(rise * pi * 2);
                final dy = -rise * 280; // rise upward

                return Positioned(
                  bottom: 0,
                  right: 20,
                  child: Transform.translate(
                    offset: Offset(dx, dy),
                    child: Opacity(
                      opacity: fade,
                      child: Transform.scale(
                        scale: scale,
                        child: Icon(
                          item.icon,
                          color: item.color,
                          size: item.size,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _HeartItem {
  final AnimationController controller;
  final Animation<double> riseAnimation;
  final Animation<double> fadeAnimation;
  final Animation<double> scaleAnimation;
  final Color color;
  final double size;
  final IconData icon;
  final double horizontalDrift;

  _HeartItem({
    required this.controller,
    required this.riseAnimation,
    required this.fadeAnimation,
    required this.scaleAnimation,
    required this.color,
    required this.size,
    required this.icon,
    required this.horizontalDrift,
  });
}
