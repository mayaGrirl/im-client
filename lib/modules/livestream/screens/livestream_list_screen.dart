/// 直播列表页面
/// 双列网格展示正在直播的房

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/modules/livestream/api/livestream_api.dart';
import 'package:im_client/modules/livestream/models/livestream.dart';
import 'package:im_client/modules/livestream/providers/livestream_provider.dart';
import 'package:im_client/modules/livestream/screens/livestream_viewer_screen.dart';
import 'package:im_client/modules/livestream/screens/livestream_swipe_screen.dart';
import 'package:im_client/modules/livestream/screens/livestream_start_screen.dart';
import 'package:im_client/modules/livestream/screens/pk_ranking_screen.dart';
import 'package:im_client/providers/auth_provider.dart';

String _getFullUrl(String url) {
  if (url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  return EnvConfig.instance.getFileUrl(url);
}

class LivestreamListScreen extends StatefulWidget {
  const LivestreamListScreen({super.key});

  @override
  State<LivestreamListScreen> createState() => _LivestreamListScreenState();
}

class _LivestreamListScreenState extends State<LivestreamListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late LivestreamProvider _provider;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _provider = Provider.of<LivestreamProvider>(context, listen: false);
      _initialized = true;
      Future.microtask(() {
        _provider.loadCategories();
        _provider.refreshLiveList();
        _provider.loadFollowingLives();
        _provider.loadScheduledLives();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('livestream')),
        actions: [
          IconButton(
            icon: const Icon(Icons.sports_mma),
            tooltip: l10n.translate('pk_rankings'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PKRankingScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.translate('livestream_recommend')),
            Tab(text: l10n.translate('livestream_following')),
            Tab(text: l10n.translate('livestream_scheduled')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecommendTab(),
          _buildFollowingTab(),
          _buildScheduledTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LivestreamStartScreen()),
          );
          // 从开直播间返回后刷新列表
          _provider.refreshLiveList();
        },
        child: const Icon(Icons.videocam),
      ),
    );
  }

  Widget _buildRecommendTab() {
    return Consumer<LivestreamProvider>(
      builder: (context, provider, _) {
        final currentUserId = Provider.of<AuthProvider>(context, listen: false).userId;
        final filteredList = provider.liveList
            .where((room) => room.userId != currentUserId && room.isLive)
            .toList();
        return Column(
          children: [
            // 分类筛
            if (provider.categories.isNotEmpty) _buildCategoryBar(provider),
            // 直播列表
            Expanded(
              child: provider.liveLoading && provider.liveList.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredList.isEmpty
                      ? RefreshIndicator(
                          onRefresh: provider.refreshLiveList,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height - 200,
                              child: _buildEmpty(),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: provider.refreshLiveList,
                          child: _buildLiveGrid(filteredList, provider),
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryBar(LivestreamProvider provider) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          _buildCategoryChip(null, AppLocalizations.of(context)!.allCategories, provider),
          ...provider.categories.map((cat) {
            final locale = Localizations.localeOf(context).languageCode;
            return _buildCategoryChip(cat.id, cat.localizedName(locale), provider);
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(int? id, String name, LivestreamProvider provider) {
    final selected = provider.selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(name, style: const TextStyle(fontSize: 13)),
        selected: selected,
        onSelected: (_) => provider.selectCategory(id),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildFollowingTab() {
    return Consumer<LivestreamProvider>(
      builder: (context, provider, _) {
        final currentUserId = Provider.of<AuthProvider>(context, listen: false).userId;
        final filteredList = provider.followingList
            .where((room) => room.userId != currentUserId && room.isLive)
            .toList();
        return provider.followingLoading && provider.followingList.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : filteredList.isEmpty
                ? RefreshIndicator(
                    onRefresh: provider.loadFollowingLives,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height - 200,
                        child: _buildEmpty(),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: provider.loadFollowingLives,
                    child: _buildLiveGrid(filteredList, provider),
                  );
      },
    );
  }

  Widget _buildScheduledTab() {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<LivestreamProvider>(
      builder: (context, provider, _) {
        return provider.scheduledLoading && provider.scheduledList.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.scheduledList.isEmpty
                ? RefreshIndicator(
                    onRefresh: provider.loadScheduledLives,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height - 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today, size: 64, color: AppColors.textHint),
                              const SizedBox(height: 16),
                              Text(
                                l10n.translate('no_scheduled_livestream'),
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: provider.loadScheduledLives,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: provider.scheduledList.length,
                      itemBuilder: (context, index) {
                        final room = provider.scheduledList[index];
                        return _buildScheduledCard(room);
                      },
                    ),
                  );
      },
    );
  }

  String _formatScheduledTime(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }

  Widget _buildScheduledCard(LivestreamRoom room) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _getFullUrl(room.coverUrl).isNotEmpty
                  ? Image.network(_getFullUrl(room.coverUrl), width: 80, height: 60, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80, height: 60, color: Colors.grey[300],
                        child: const Icon(Icons.live_tv, size: 24),
                      ),
                    )
                  : Container(
                      width: 80, height: 60, color: Colors.grey[300],
                      child: const Icon(Icons.live_tv, size: 24),
                    ),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(room.user?.nickname ?? l10n.translate('livestream'),
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (room.scheduledAt != null) ...[
                        const Icon(Icons.schedule, size: 13, color: Colors.orange),
                        const SizedBox(width: 3),
                        Text(_formatScheduledTime(room.scheduledAt),
                          style: const TextStyle(fontSize: 12, color: Colors.orange)),
                        const SizedBox(width: 12),
                      ],
                      if (room.reserveCount > 0) ...[
                        const Icon(Icons.people_outline, size: 13, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(l10n.translate('reserve_count').replaceAll('{count}', room.reserveCount.toString()),
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 主播显示取消按钮，观众显示预约按
            Builder(builder: (ctx) {
              final currentUserId = Provider.of<AuthProvider>(ctx, listen: false).userId;
              if (room.userId == currentUserId) {
                return _CancelScheduledButton(room: room, provider: _provider);
              }
              return _ReserveButton(room: room, provider: _provider);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveGrid(List<LivestreamRoom> lives, LivestreamProvider provider) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200) {
          provider.loadMoreLives();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: lives.length,
        itemBuilder: (context, index) => _buildLiveCard(lives[index]),
      ),
    );
  }

  void _navigateToViewer(LivestreamRoom room) {
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).userId;
    final isOwn = room.userId == currentUserId;

    if (room.isPrivate && !isOwn) {
      _showPasswordDialog(room);
    } else if (isOwn) {
      // 主播直接进入独立viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LivestreamViewerScreen(
            livestreamId: room.id,
            isAnchor: true,
          ),
        ),
      );
    } else {
      // 观众进入滑动模式
      final swipeRooms = _provider.liveList
          .where((r) => r.isLive && !r.isPrivate && r.userId != currentUserId)
          .toList();
      final index = swipeRooms.indexWhere((r) => r.id == room.id);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LivestreamSwipeScreen(
            initialRooms: swipeRooms,
            initialIndex: index >= 0 ? index : 0,
          ),
        ),
      );
    }
  }

  void _showPasswordDialog(LivestreamRoom room) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, size: 20),
            SizedBox(width: 8),
            Text('私密直播'),
          ],
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: '请输入直播间密码',
            prefixIcon: Icon(Icons.vpn_key),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LivestreamViewerScreen(
                    livestreamId: room.id,
                    password: controller.text,
                  ),
                ),
              );
            },
            child: const Text('进入'),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCard(LivestreamRoom room) {
    return GestureDetector(
      onTap: () => _navigateToViewer(room),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _getFullUrl(room.coverUrl).isNotEmpty
                      ? Image.network(
                          _getFullUrl(room.coverUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.live_tv, size: 40, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.live_tv, size: 40, color: Colors.grey),
                        ),
                  // 直播状态标
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 8),
                          SizedBox(width: 4),
                          Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  // 观看人数
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility, color: Colors.white, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            _formatViewerCount(room.viewerCount),
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 私密标签
                  if (room.isPrivate)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, color: Colors.amber, size: 10),
                            SizedBox(width: 2),
                            Text('私密', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  // 付费标签（门票）
                  if (room.isPaid)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          room.allowPreview && room.previewDuration > 0
                              ? '${room.ticketPrice}金豆 试看${room.previewDuration}秒'
                              : '${room.ticketPrice}金豆',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                  // 按分钟付费标
                  if (room.roomType == 1)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          room.trialSeconds > 0
                              ? '${room.pricePerMin}金豆/分 试看${room.trialSeconds}秒'
                              : '${room.pricePerMin}金豆/分',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 信息区域
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: room.user?.avatar.isNotEmpty == true
                            ? NetworkImage(_getFullUrl(room.user!.avatar))
                            : null,
                        child: room.user?.avatar.isEmpty != false
                            ? const Icon(Icons.person, size: 12)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          room.user?.nickname ?? '主播',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.live_tv, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            '暂无直播',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatViewerCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return count.toString();
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _LiveSearchDelegate(),
    );
  }
}

class _CancelScheduledButton extends StatefulWidget {
  final LivestreamRoom room;
  final LivestreamProvider provider;

  const _CancelScheduledButton({required this.room, required this.provider});

  @override
  State<_CancelScheduledButton> createState() => _CancelScheduledButtonState();
}

class _CancelScheduledButtonState extends State<_CancelScheduledButton> {
  bool _loading = false;

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('cancel_scheduled_livestream')),
        content: Text(l10n.translate('cancel_scheduled_livestream') + '?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.translate('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.translate('confirm'))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    final success = await widget.provider.cancelScheduledLivestream(widget.room.id);
    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('scheduled_cancelled'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const SizedBox(width: 70, height: 32, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))));
    }

    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: _cancel,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: const BorderSide(color: Colors.red),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(l10n.translate('cancel_scheduled_livestream'),
          style: const TextStyle(fontSize: 11, color: Colors.red)),
      ),
    );
  }
}

class _ReserveButton extends StatefulWidget {
  final LivestreamRoom room;
  final LivestreamProvider provider;

  const _ReserveButton({required this.room, required this.provider});

  @override
  State<_ReserveButton> createState() => _ReserveButtonState();
}

class _ReserveButtonState extends State<_ReserveButton> {
  bool _reserved = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkReservation();
  }

  Future<void> _checkReservation() async {
    final reserved = await widget.provider.checkReservation(widget.room.id);
    if (mounted) {
      setState(() {
        _reserved = reserved;
        _loading = false;
      });
    }
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    bool success;
    if (_reserved) {
      success = await widget.provider.cancelReservation(widget.room.id);
      if (success && mounted) setState(() => _reserved = false);
    } else {
      success = await widget.provider.reserveLivestream(widget.room.id);
      if (success && mounted) setState(() => _reserved = true);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const SizedBox(width: 70, height: 32, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))));
    }

    return SizedBox(
      height: 32,
      child: _reserved
          ? OutlinedButton(
              onPressed: _toggle,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                side: const BorderSide(color: Colors.grey),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(l10n.translate('reserved'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            )
          : FilledButton(
              onPressed: _toggle,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: Colors.orange,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(l10n.translate('reserve'), style: const TextStyle(fontSize: 12)),
            ),
    );
  }
}

class _LiveSearchDelegate extends SearchDelegate<String> {
  final LivestreamApi _api = LivestreamApi(ApiClient());
  List<LivestreamRoom> _results = [];

  _LiveSearchDelegate();

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder(
      future: _search(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_results.isEmpty) {
          return const Center(child: Text('没有找到相关直播'));
        }
        return ListView.builder(
          itemCount: _results.length,
          itemBuilder: (context, index) {
            final room = _results[index];
            return ListTile(
              leading: _getFullUrl(room.coverUrl).isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(_getFullUrl(room.coverUrl), width: 60, height: 40, fit: BoxFit.cover),
                    )
                  : Container(
                      width: 60, height: 40,
                      color: Colors.grey[300],
                      child: const Icon(Icons.live_tv, size: 20),
                    ),
              title: Text(room.title),
              subtitle: Text(room.user?.nickname ?? ''),
              trailing: Text('${room.viewerCount}观看'),
              onTap: () {
                if (room.isPrivate) {
                  _showPasswordDialog(context, room);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LivestreamViewerScreen(livestreamId: room.id),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(child: Text('搜索直播间'));
  }

  Future<void> _search() async {
    if (query.isEmpty) return;
    final res = await _api.searchLives(query);
    if (res.isSuccess) {
      _results = (res.data['list'] as List? ?? [])
          .map((e) => LivestreamRoom.fromJson(e))
          .toList();
    }
  }

  void _showPasswordDialog(BuildContext context, LivestreamRoom room) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, size: 20),
            SizedBox(width: 8),
            Text('私密直播'),
          ],
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: '请输入直播间密码',
            prefixIcon: Icon(Icons.vpn_key),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LivestreamViewerScreen(
                    livestreamId: room.id,
                    password: controller.text,
                  ),
                ),
              );
            },
            child: const Text('进入'),
          ),
        ],
      ),
    );
  }
}
