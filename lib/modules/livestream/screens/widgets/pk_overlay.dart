/// PK对战覆盖(抖音风格)
/// 头像+昵称、服务端同步倒计时、渐变分数条、结果动画、惩罚倒计时

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';

class PKData {
  final int pkId;
  final int userIdA;
  final int userIdB;
  final String anchorNameA;
  final String anchorNameB;
  final String avatarA;
  final String avatarB;
  int scoreA;
  int scoreB;
  final int duration; // seconds
  int remaining; // 服务端推送的剩余时间

  // 结果
  int winnerId;
  int loserId;
  int punishSeconds;
  bool isPunishing;

  PKData({
    required this.pkId,
    this.userIdA = 0,
    this.userIdB = 0,
    required this.anchorNameA,
    required this.anchorNameB,
    this.avatarA = '',
    this.avatarB = '',
    this.scoreA = 0,
    this.scoreB = 0,
    this.duration = 180,
    int? remaining,
    this.winnerId = 0,
    this.loserId = 0,
    this.punishSeconds = 0,
    this.isPunishing = false,
  }) : remaining = remaining ?? duration;

  int get totalScore => scoreA + scoreB;
  double get ratioA => totalScore > 0 ? scoreA / totalScore : 0.5;
  bool get isEnded => (remaining <= 0 && winnerId > 0) || isPunishing;
  bool get isDraw => winnerId == 0 && loserId == 0 && remaining <= 0;
}

class PKOverlay extends StatefulWidget {
  final PKData data;
  final VoidCallback? onPKEnd;

  const PKOverlay({super.key, required this.data, this.onPKEnd});

  @override
  PKOverlayState createState() => PKOverlayState();
}

class PKOverlayState extends State<PKOverlay>
    with TickerProviderStateMixin {
  bool _showResult = false;
  Timer? _punishTimer;
  int _punishRemaining = 0;
  late AnimationController _scoreAnimController;
  late Animation<double> _scorePulse;
  late AnimationController _resultAnimController;
  late Animation<double> _resultScale;

  // 本地倒计时（不依赖服务端推送，避免WS丢包导致卡死�?
  Timer? _countdownTimer;
  int _localRemaining = 0;

  @override
  void initState() {
    super.initState();

    _localRemaining = widget.data.remaining;
    _startCountdown();

    _scoreAnimController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scorePulse = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _scoreAnimController, curve: Curves.elasticOut),
    );

    _resultAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _resultScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _resultAnimController, curve: Curves.elasticOut),
    );
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_localRemaining > 0) {
        setState(() {
          _localRemaining--;
          widget.data.remaining = _localRemaining;
        });
      } else {
        timer.cancel();
      }
    });
  }

  /// 更新PK分数（从WS消息调用�?
  void updateScore(int scoreA, int scoreB) {
    if (!mounted) return;
    setState(() {
      widget.data.scoreA = scoreA;
      widget.data.scoreB = scoreB;
    });
    _scoreAnimController.forward(from: 0);
  }

  /// 更新剩余时间（从WS pk_timer消息调用，用于与服务端同步校正）
  void updateRemaining(int remaining) {
    if (mounted) {
      setState(() {
        _localRemaining = remaining;
        widget.data.remaining = remaining;
      });
    }
  }

  /// 显示PK结果
  void showPKResult({int winnerId = 0, int loserId = 0, int punishSeconds = 0}) {
    setState(() {
      _showResult = true;
      widget.data.winnerId = winnerId;
      widget.data.loserId = loserId;
      widget.data.punishSeconds = punishSeconds;
    });
    _resultAnimController.forward(from: 0);
  }

  /// 开始惩罚倒计�?
  void startPunish(int loserId, int punishSeconds) {
    setState(() {
      widget.data.loserId = loserId;
      widget.data.isPunishing = true;
      _punishRemaining = punishSeconds;
    });
    _punishTimer?.cancel();
    _punishTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _punishRemaining--;
        if (_punishRemaining <= 0) {
          timer.cancel();
          widget.data.isPunishing = false;
          widget.onPKEnd?.call();
        }
      });
    });
  }

  /// 外部调用结束PK
  void endPK({int winnerId = 0, int loserId = 0, int punishSeconds = 0}) {
    _countdownTimer?.cancel(); // 停止本地倒计�?
    showPKResult(winnerId: winnerId, loserId: loserId, punishSeconds: punishSeconds);
    if (punishSeconds > 0 && loserId > 0) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) startPunish(loserId, punishSeconds);
      });
    } else {
      Future.delayed(const Duration(seconds: 3), () {
        widget.onPKEnd?.call();
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scoreAnimController.dispose();
    _resultAnimController.dispose();
    _punishTimer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    if (seconds < 0) seconds = 0;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPKPanel(),
        if (_showResult && !widget.data.isPunishing) _buildResult(context),
        if (widget.data.isPunishing) _buildPunishBar(context),
      ],
    );
  }

  Widget _buildAvatar(String url, String name, Color borderColor) {
    final fullUrl = url.isNotEmpty ? EnvConfig.instance.getFileUrl(url) : '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    debugPrint('[PK Overlay] _buildAvatar: raw="$url", fullUrl="$fullUrl", name="$name"');
    Widget fallback() => Container(
      color: borderColor.withOpacity(0.3),
      child: Center(child: Text(initial, style: TextStyle(color: borderColor, fontSize: 16, fontWeight: FontWeight.bold))),
    );
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: ClipOval(
        child: fullUrl.isNotEmpty
            ? Image.network(fullUrl, fit: BoxFit.cover,
                errorBuilder: (_, error, ___) {
                  debugPrint('[PK Overlay] Image.network error for "$fullUrl": $error');
                  return fallback();
                })
            : fallback(),
      ),
    );
  }

  Widget _buildPKPanel() {
    final ratioA = widget.data.ratioA;
    final remaining = _localRemaining;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 头像 + 分数 + VS + 倒计�?
          Row(
            children: [
              // A�?
              Expanded(
                child: Row(
                  children: [
                    _buildAvatar(widget.data.avatarA, widget.data.anchorNameA, Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.data.anchorNameA,
                            style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          AnimatedBuilder(
                            animation: _scorePulse,
                            builder: (context, child) => Transform.scale(
                              scale: _scorePulse.value,
                              alignment: Alignment.centerLeft,
                              child: child,
                            ),
                            child: Text(
                              '${widget.data.scoreA}',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // VS + 倒计�?
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.amber, Colors.orange],
                      ).createShader(bounds),
                      child: const Text(
                        'VS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: remaining <= 30
                            ? Colors.red.withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatTime(remaining),
                        style: TextStyle(
                          color: remaining <= 30 ? Colors.redAccent : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // B�?
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.data.anchorNameB,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                          AnimatedBuilder(
                            animation: _scorePulse,
                            builder: (context, child) => Transform.scale(
                              scale: _scorePulse.value,
                              alignment: Alignment.centerRight,
                              child: child,
                            ),
                            child: Text(
                              '${widget.data.scoreB}',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildAvatar(widget.data.avatarB, widget.data.anchorNameB, Colors.redAccent),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 渐变进度�?
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Flexible(
                    flex: (ratioA * 100).round().clamp(1, 99),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2196F3), Color(0xFF42A5F5)],
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    flex: ((1 - ratioA) * 100).round().clamp(1, 99),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFEF5350), Color(0xFFF44336)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDraw = widget.data.winnerId == 0;
    String winnerName = '';
    if (!isDraw) {
      winnerName = widget.data.winnerId == widget.data.userIdA
          ? widget.data.anchorNameA
          : widget.data.anchorNameB;
    }

    return ScaleTransition(
      scale: _resultScale,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDraw
                ? [Colors.grey.withOpacity(0.8), Colors.grey.withOpacity(0.6)]
                : [Colors.amber.withOpacity(0.9), Colors.orange.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDraw ? Colors.grey.withOpacity(0.3) : Colors.amber.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isDraw ? '⚖️' : '🏆', style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 6),
            Text(
              isDraw
                  ? (l10n?.pkDraw ?? 'Draw!')
                  : '${l10n?.pkWin ?? ''} $winnerName!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPunishBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            '${l10n?.pkPunishRemaining ?? 'Punishment'}: ${_formatTime(_punishRemaining)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
