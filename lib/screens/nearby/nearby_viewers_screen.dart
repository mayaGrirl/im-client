/// 谁看过我页面
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/nearby_api.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import '../../utils/image_proxy.dart';

class NearbyViewersScreen extends StatefulWidget {
  const NearbyViewersScreen({super.key});

  @override
  State<NearbyViewersScreen> createState() => _NearbyViewersScreenState();
}

class _NearbyViewersScreenState extends State<NearbyViewersScreen> {
  final NearbyApi _api = NearbyApi(ApiClient());
  final FriendApi _friendApi = FriendApi(ApiClient());

  List<NearbyView> _viewers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadViewers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadViewers() async {
    setState(() {
      _isLoading = true;
      _page = 1;
    });

    try {
      final result = await _api.getViewers(page: 1, pageSize: _pageSize);
      if (result.success && result.data != null) {
        final list = (result.data['list'] as List?) ?? [];
        final total = result.data['total'] as int? ?? 0;
        setState(() {
          _viewers = list.map((e) => NearbyView.fromJson(e)).toList();
          _hasMore = _viewers.length < total;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.loadFailed}: $e')),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _page + 1;
      final result = await _api.getViewers(page: nextPage, pageSize: _pageSize);
      if (result.success && result.data != null) {
        final list = (result.data['list'] as List?) ?? [];
        final total = result.data['total'] as int? ?? 0;
        setState(() {
          _viewers.addAll(list.map((e) => NearbyView.fromJson(e)));
          _page = nextPage;
          _hasMore = _viewers.length < total;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  String _getFullUrl(String url) {
    if (url.isEmpty || url == '/') return '';
    if (url.startsWith('http')) return url;
    return EnvConfig.instance.getFileUrl(url);
  }

  String _formatTime(DateTime time, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return l10n.justNow;
    } else if (diff.inMinutes < 60) {
      return l10n.minutesAgo(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return l10n.hoursAgo(diff.inHours);
    } else if (diff.inDays < 7) {
      return l10n.daysAgo(diff.inDays);
    } else {
      return '${time.month}-${time.day}';
    }
  }

  String _formatDistance(double distance) {
    if (distance < 0.1) {
      return '< 100m';
    } else if (distance < 1) {
      return '${(distance * 1000).round()}m';
    } else {
      return '${distance.toStringAsFixed(1)}km';
    }
  }

  Future<void> _addFriend(NearbyView view) async {
    if (view.viewer == null) return;
    final l10n = AppLocalizations.of(context)!;

    try {
      final result = await _friendApi.addFriend(
        userId: view.viewerId,
        message: l10n.foundYouNearby,
      );
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.requestSent)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? l10n.sendFailed)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.sendFailed}: $e')),
        );
      }
    }
  }

  Future<void> _sendGreet(NearbyView view) async {
    if (view.viewer == null) return;
    final l10n = AppLocalizations.of(context)!;

    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.greetToUser(view.viewer!.nickname)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGreetOption(l10n.greetOption1),
            _buildGreetOption(l10n.greetOption2),
            _buildGreetOption(l10n.greetOption3),
          ],
        ),
      ),
    );

    if (content == null) return;

    try {
      final result = await _api.sendGreet(view.viewerId, content: content);
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.greetingSent)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? l10n.sendFailed)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.sendFailed}: $e')),
        );
      }
    }
  }

  Widget _buildGreetOption(String text) {
    return ListTile(
      title: Text(text),
      onTap: () => Navigator.pop(context, text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.whoViewedMe),
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewers.isEmpty) {
      return _buildEmpty(l10n);
    }

    return RefreshIndicator(
      onRefresh: _loadViewers,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _viewers.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _viewers.length) {
            return _buildLoadingMore();
          }
          return _buildViewerCard(_viewers[index], l10n);
        },
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.visibility_off,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noOneViewedYet,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.enableLocationToBeVisible,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewerCard(NearbyView view, AppLocalizations l10n) {
    final viewer = view.viewer;
    if (viewer == null) return const SizedBox.shrink();

    final avatarUrl = _getFullUrl(viewer.avatar);
    final isMale = viewer.gender == 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: isMale
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.pink.withOpacity(0.1),
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
              child: avatarUrl.isEmpty
                  ? Icon(
                      isMale ? Icons.male : Icons.female,
                      size: 24,
                      color: isMale ? Colors.blue : Colors.pink,
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isMale ? Colors.blue : Colors.pink,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(
                  isMale ? Icons.male : Icons.female,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                viewer.nickname,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 2),
                Text(
                  _formatDistance(view.distance),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 2),
                Text(
                  _formatTime(view.createdAt, l10n),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _sendGreet(view),
              icon: const Icon(Icons.waving_hand),
              color: AppColors.primary,
              tooltip: l10n.greet,
            ),
            IconButton(
              onPressed: () => _addFriend(view),
              icon: const Icon(Icons.person_add),
              color: AppColors.primary,
              tooltip: l10n.addFriend,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMore() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
