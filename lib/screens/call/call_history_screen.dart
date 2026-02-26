/// 通话记录页面
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/call_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/screens/call/call_screen.dart';
import '../../utils/image_proxy.dart';

/// 通话记录页面
class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final CallApi _callApi = CallApi(ApiClient());
  final List<Map<String, dynamic>> _records = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords({bool refresh = false}) async {
    if (_isLoading) return;
    if (!refresh && !_hasMore) return;

    setState(() => _isLoading = true);

    if (refresh) {
      _page = 1;
      _records.clear();
    }

    try {
      final response = await _callApi.getCallHistory(
        page: _page,
        pageSize: _pageSize,
      );

      if (response.success && response.data != null) {
        final list = response.data['list'] as List? ?? [];
        final total = response.data['total'] as int? ?? 0;

        setState(() {
          for (var item in list) {
            _records.add(item as Map<String, dynamic>);
          }
          _hasMore = _records.length < total;
          _page++;
        });
      }
    } catch (e) {
      // Load call records failed
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRecord(String callId, int index) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_call_record')),
        content: Text(l10n.translate('confirm_delete_call_record')),
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
      final response = await _callApi.deleteCallRecord(callId);
      if (response.success) {
        setState(() => _records.removeAt(index));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('deleted_success'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('delete_failed_text'))),
        );
      }
    }
  }

  void _callUser(Map<String, dynamic> record, int callType) {
    final targetUser = record['target_user'] as Map<String, dynamic>?;
    if (targetUser == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          targetUserId: targetUser['id'] as int? ?? 0,
          targetUserName: targetUser['nickname'] as String? ?? '',
          targetUserAvatar: targetUser['avatar'] as String? ?? '',
          callType: callType,
        ),
      ),
    );
  }

  String _getFullUrl(String url) {
    if (url.isEmpty || url == '/') return '';
    if (url.startsWith('http')) return url;
    return EnvConfig.instance.getFileUrl(url);
  }

  String _formatTime(String? timeStr, AppLocalizations l10n) {
    if (timeStr == null || timeStr.isEmpty) return '';
    try {
      final time = DateTime.parse(timeStr);
      final now = DateTime.now();
      final diff = now.difference(time);

      if (diff.inDays == 0) {
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        return l10n.yesterday;
      } else if (diff.inDays < 7) {
        final weekDays = [
          l10n.translate('monday_short'),
          l10n.translate('tuesday_short'),
          l10n.translate('wednesday_short'),
          l10n.translate('thursday_short'),
          l10n.translate('friday_short'),
          l10n.translate('saturday_short'),
          l10n.translate('sunday_short'),
        ];
        return weekDays[time.weekday - 1];
      } else {
        return '${time.month}/${time.day}';
      }
    } catch (e) {
      return '';
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _getStatusText(int status, bool isOutgoing, AppLocalizations l10n) {
    switch (status) {
      case 0: // calling
        return isOutgoing ? l10n.translate('calling_status') : l10n.translate('incoming_status');
      case 1: // connected
        return l10n.translate('connected_status');
      case 2: // rejected
        return isOutgoing ? l10n.translate('other_rejected_call') : l10n.translate('you_rejected_call');
      case 3: // cancelled
        return isOutgoing ? l10n.translate('you_cancelled_call') : l10n.translate('other_cancelled_call');
      case 4: // missed
        return isOutgoing ? l10n.translate('you_missed_call') : l10n.translate('missed_incoming_call');
      case 5: // busy
        return l10n.translate('other_busy_call');
      case 6: // ended
        return l10n.translate('call_ended_text');
      default:
        return l10n.translate('unknown_status');
    }
  }

  Color _getStatusColor(int status, bool isOutgoing) {
    switch (status) {
      case 1: // connected
      case 6: // ended
        return Colors.grey;
      case 2: // rejected
      case 4: // missed
        return isOutgoing ? Colors.orange : Colors.red;
      case 5: // busy
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.callHistory),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadRecords(refresh: true),
        child: _records.isEmpty && !_isLoading
            ? _buildEmptyView(l10n)
            : ListView.builder(
                itemCount: _records.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _records.length) {
                    _loadRecords();
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _buildRecordItem(_records[index], index, l10n);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyView(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.call,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.translate('no_call_record'),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(Map<String, dynamic> record, int index, AppLocalizations l10n) {
    final targetUser = record['target_user'] as Map<String, dynamic>?;
    final isOutgoing = record['is_outgoing'] as bool? ?? false;
    final callType = record['call_type'] as int? ?? CallType.voice;
    final status = record['status'] as int? ?? 0;
    final duration = record['duration'] as int? ?? 0;
    final startTime = record['start_time'] as String?;
    final callId = record['call_id'] as String? ?? '';

    final avatarUrl = _getFullUrl(targetUser?['avatar'] as String? ?? '');
    final nickname = targetUser?['nickname'] as String? ?? l10n.translate('unknown_user');

    return Dismissible(
      key: Key(callId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteRecord(callId, index),
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.translate('delete_call_record')),
            content: Text(l10n.translate('confirm_delete_call_record')),
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
        return confirm == true;
      },
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl.proxied)
              : null,
          child: avatarUrl.isEmpty
              ? const Icon(Icons.person, color: Colors.white54)
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                nickname,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Icon(
              isOutgoing
                  ? Icons.call_made
                  : Icons.call_received,
              size: 14,
              color: _getStatusColor(status, isOutgoing),
            ),
            const SizedBox(width: 4),
            Icon(
              callType == CallType.video ? Icons.videocam : Icons.call,
              size: 14,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              _getStatusText(status, isOutgoing, l10n),
              style: TextStyle(
                color: _getStatusColor(status, isOutgoing),
                fontSize: 12,
              ),
            ),
            if (duration > 0) ...[
              const SizedBox(width: 8),
              Text(
                _formatDuration(duration),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(startTime, l10n),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _callUser(record, CallType.voice),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.call, size: 20, color: Colors.green),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _callUser(record, CallType.video),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.videocam, size: 20, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
