/// 我的漂流瓶页面
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/drift_bottle_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';

class DriftBottleMyScreen extends StatefulWidget {
  const DriftBottleMyScreen({super.key});

  @override
  State<DriftBottleMyScreen> createState() => _DriftBottleMyScreenState();
}

class _DriftBottleMyScreenState extends State<DriftBottleMyScreen> {
  final DriftBottleApi _api = DriftBottleApi(ApiClient());
  final ScrollController _scrollController = ScrollController();

  List<DriftBottle> _bottles = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadBottles();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadBottles() async {
    setState(() {
      _isLoading = true;
      _page = 1;
    });

    try {
      final result = await _api.getMyBottles(page: 1, pageSize: _pageSize);
      if (result.success && result.data != null) {
        final list = (result.data['list'] as List?) ?? [];
        setState(() {
          _bottles = list.map((e) => DriftBottle.fromJson(e)).toList();
          _hasMore = list.length >= _pageSize;
        });
      }
    } catch (e) {
      // Loading failed
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final result = await _api.getMyBottles(page: _page + 1, pageSize: _pageSize);
      if (result.success && result.data != null) {
        final list = (result.data['list'] as List?) ?? [];
        setState(() {
          _page++;
          _bottles.addAll(list.map((e) => DriftBottle.fromJson(e)));
          _hasMore = list.length >= _pageSize;
        });
      }
    } catch (e) {
      // Load more failed
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _deleteBottle(DriftBottle bottle) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_bottle')),
        content: Text(l10n.translate('delete_bottle_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await _api.deleteBottle(bottle.id);
      if (result.success) {
        setState(() {
          _bottles.removeWhere((b) => b.id == bottle.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('delete_success'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('delete_failed')}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myBottles),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bottles.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadBottles,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _bottles.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _bottles.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      return _buildBottleCard(_bottles[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.translate('no_bottles_yet'),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('go_throw_bottle'),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottleCard(DriftBottle bottle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态和时间
          Row(
            children: [
              _buildStatusChip(bottle.status, AppLocalizations.of(context)!),
              const Spacer(),
              Text(
                _formatTime(bottle.createdAt, AppLocalizations.of(context)!),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteBottle(bottle),
                child: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 内容
          Text(
            bottle.content,
            style: const TextStyle(fontSize: 15),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // 统计
          Row(
            children: [
              _buildStatItem(Icons.remove_red_eye, '${bottle.pickCount}'),
              const SizedBox(width: 16),
              _buildStatItem(Icons.replay, '${bottle.throwBackCount}'),
              const Spacer(),
              Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return Text(
                    bottle.isAnonymous ? l10n.translate('anonymous') : l10n.translate('public'),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(int status, AppLocalizations l10n) {
    Color color;
    String text;

    switch (status) {
      case 1:
        color = Colors.blue;
        text = l10n.translate('status_drifting');
        break;
      case 2:
        color = Colors.green;
        text = l10n.translate('status_picked');
        break;
      case 3:
        color = Colors.grey;
        text = l10n.translate('status_expired');
        break;
      case 4:
        color = Colors.red;
        text = l10n.translate('status_violation');
        break;
      default:
        color = Colors.grey;
        text = l10n.translate('status_deleted');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  String _formatTime(DateTime time, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(time);
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    if (diff.inDays < 1) {
      return l10n.translate('today_time').replaceAll('{time}', timeStr);
    } else if (diff.inDays < 2) {
      return l10n.translate('yesterday_time').replaceAll('{time}', timeStr);
    } else if (diff.inDays < 7) {
      return l10n.translate('days_ago').replaceAll('{days}', diff.inDays.toString());
    } else {
      return l10n.translate('date_format')
          .replaceAll('{month}', time.month.toString())
          .replaceAll('{day}', time.day.toString());
    }
  }
}
