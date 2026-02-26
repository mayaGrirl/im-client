/// 弹幕覆盖层组�?
/// 实现从右到左滚动的弹幕效�?

import 'dart:math';
import 'package:flutter/material.dart';

class DanmakuOverlay extends StatefulWidget {
  const DanmakuOverlay({super.key});

  @override
  DanmakuOverlayState createState() => DanmakuOverlayState();
}

class DanmakuOverlayState extends State<DanmakuOverlay> with TickerProviderStateMixin {
  final List<_DanmakuItem> _danmakus = [];
  final int _maxLanes = 6;
  final Random _random = Random();

  /// 外部调用添加弹幕
  void addDanmaku(String text, {Color color = Colors.white}) {
    final lane = _findAvailableLane();
    final controller = AnimationController(
      duration: Duration(milliseconds: 5000 + _random.nextInt(3000)),
      vsync: this,
    );

    final item = _DanmakuItem(
      text: text,
      color: color,
      lane: lane,
      controller: controller,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _danmakus.remove(item);
        controller.dispose();
        if (mounted) setState(() {});
      }
    });

    setState(() => _danmakus.add(item));
    controller.forward();
  }

  int _findAvailableLane() {
    // 找到弹幕最少的车道
    final laneCounts = List.filled(_maxLanes, 0);
    for (final d in _danmakus) {
      laneCounts[d.lane]++;
    }
    int minLane = 0;
    for (int i = 1; i < _maxLanes; i++) {
      if (laneCounts[i] < laneCounts[minLane]) minLane = i;
    }
    return minLane;
  }

  @override
  void dispose() {
    final items = List<_DanmakuItem>.from(_danmakus);
    _danmakus.clear();
    for (final d in items) {
      d.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          children: _danmakus.map((item) => _buildDanmaku(item)).toList(),
        ),
      ),
    );
  }

  Widget _buildDanmaku(_DanmakuItem item) {
    final screenWidth = MediaQuery.of(context).size.width;
    final topOffset = 60.0 + item.lane * 30.0;

    return AnimatedBuilder(
      animation: item.controller,
      builder: (context, child) {
        final x = screenWidth - (screenWidth + 200) * item.controller.value;
        return Positioned(
          left: x,
          top: topOffset,
          child: child!,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          item.text,
          style: TextStyle(
            color: item.color,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _DanmakuItem {
  final String text;
  final Color color;
  final int lane;
  final AnimationController controller;

  _DanmakuItem({
    required this.text,
    required this.color,
    required this.lane,
    required this.controller,
  });
}
