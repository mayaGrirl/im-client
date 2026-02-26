/// 付费连线覆盖�?- 请求/接受/拒绝/计时
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:im_client/l10n/app_localizations.dart';

class PaidSessionOverlay extends StatefulWidget {
  final int sessionId;
  final int ratePerMinute;
  final int sessionType;
  final bool isAnchor;
  final String? requesterName;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onEnd;

  const PaidSessionOverlay({
    super.key,
    required this.sessionId,
    required this.ratePerMinute,
    this.sessionType = 3,
    this.isAnchor = false,
    this.requesterName,
    this.onAccept,
    this.onReject,
    this.onEnd,
  });

  @override
  State<PaidSessionOverlay> createState() => PaidSessionOverlayState();
}

class PaidSessionOverlayState extends State<PaidSessionOverlay> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  int _totalCost = 0;
  bool _isActive = false;

  void startTimer() {
    _isActive = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds++;
        _totalCost = (_elapsedSeconds ~/ 60 + 1) * widget.ratePerMinute;
      });
    });
  }

  void updateCharge(int totalMinutes, int viewerBalance) {
    setState(() {
      _totalCost = totalMinutes * widget.ratePerMinute;
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _isActive = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final min = _elapsedSeconds ~/ 60;
    final sec = _elapsedSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String get _sessionTypeIcon {
    switch (widget.sessionType) {
      case 1: return '💬';
      case 2: return '🎤';
      case 3: return '📹';
      default: return '📹';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 主播收到请求（待处理�?
    if (widget.isAnchor && !_isActive && widget.requesterName != null) {
      return _buildRequestCard();
    }

    // 活跃会话 - 浮动计时�?
    if (_isActive) {
      return _buildTimerOverlay();
    }

    return const SizedBox.shrink();
  }

  Widget _buildRequestCard() {
    return Positioned(
      top: 100,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_sessionTypeIcon ${AppLocalizations.of(context)?.paidSessionRequest ?? 'Paid Session Request'}',
                style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)?.requestPaidCallWith(widget.requesterName ?? '') ?? '${widget.requesterName} requests paid session',
                style: const TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)?.paidSessionRateDisplay(widget.ratePerMinute) ?? '${widget.ratePerMinute} gold beans/min',
                style: const TextStyle(color: Colors.amber, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: widget.onReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      minimumSize: const Size(80, 32),
                    ),
                    child: Text(AppLocalizations.of(context)?.rejectButton ?? 'Reject', style: const TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      widget.onAccept?.call();
                      startTimer();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      minimumSize: const Size(80, 32),
                    ),
                    child: Text(AppLocalizations.of(context)?.acceptButton ?? 'Accept', style: const TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerOverlay() {
    return Positioned(
      top: 60,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _sessionTypeIcon,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formattedTime,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$_totalCost ${AppLocalizations.of(context)?.goldBeansUnit ?? 'Gold Beans'}',
                    style: const TextStyle(color: Colors.amber, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  stopTimer();
                  widget.onEnd?.call();
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call_end, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
