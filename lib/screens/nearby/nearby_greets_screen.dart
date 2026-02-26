/// 收到的打招呼页面
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/nearby_api.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import '../../utils/image_proxy.dart';

class NearbyGreetsScreen extends StatefulWidget {
  const NearbyGreetsScreen({super.key});

  @override
  State<NearbyGreetsScreen> createState() => _NearbyGreetsScreenState();
}

class _NearbyGreetsScreenState extends State<NearbyGreetsScreen> {
  final NearbyApi _api = NearbyApi(ApiClient());
  final FriendApi _friendApi = FriendApi(ApiClient());

  List<NearbyGreet> _greets = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadGreets();
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

  Future<void> _loadGreets() async {
    setState(() {
      _isLoading = true;
      _page = 1;
    });

    try {
      final result = await _api.getGreets(page: 1, pageSize: _pageSize);
      if (result.success && result.data != null) {
        final list = (result.data['list'] as List?) ?? [];
        final total = result.data['total'] as int? ?? 0;
        setState(() {
          _greets = list.map((e) => NearbyGreet.fromJson(e)).toList();
          _hasMore = _greets.length < total;
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
      final result = await _api.getGreets(page: nextPage, pageSize: _pageSize);
      if (result.success && result.data != null) {
        final list = (result.data['list'] as List?) ?? [];
        final total = result.data['total'] as int? ?? 0;
        setState(() {
          _greets.addAll(list.map((e) => NearbyGreet.fromJson(e)));
          _page = nextPage;
          _hasMore = _greets.length < total;
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

  Future<void> _addFriend(NearbyGreet greet) async {
    if (greet.fromUser == null) return;
    final l10n = AppLocalizations.of(context)!;

    try {
      final result = await _friendApi.addFriend(
        userId: greet.fromId,
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

  Future<void> _replyGreet(NearbyGreet greet) async {
    if (greet.fromUser == null) return;
    final l10n = AppLocalizations.of(context)!;

    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.replyToUser(greet.fromUser!.nickname)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGreetOption(l10n.greetReplyOption1),
            _buildGreetOption(l10n.greetReplyOption2),
            _buildGreetOption(l10n.greetReplyOption3),
          ],
        ),
      ),
    );

    if (content == null) return;

    try {
      final result = await _api.sendGreet(greet.fromId, content: content);
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.replySent)),
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
        title: Text(l10n.receivedGreetsTitle),
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_greets.isEmpty) {
      return _buildEmpty(l10n);
    }

    return RefreshIndicator(
      onRefresh: _loadGreets,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _greets.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _greets.length) {
            return _buildLoadingMore();
          }
          return _buildGreetCard(_greets[index], l10n);
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
            Icons.waving_hand_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noOneGreetedYet,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.checkNearbyMakeFriends,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetCard(NearbyGreet greet, AppLocalizations l10n) {
    final user = greet.fromUser;
    if (user == null) return const SizedBox.shrink();

    final avatarUrl = _getFullUrl(user.avatar);
    final isMale = user.gender == 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 头像
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isMale
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.pink.withOpacity(0.1),
                      backgroundImage:
                          avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
                      child: avatarUrl.isEmpty
                          ? Icon(
                              isMale ? Icons.male : Icons.female,
                              size: 22,
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
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // 用户信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nickname,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(greet.createdAt, l10n),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // 状态标签
                if (greet.status == 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l10n.newTag,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // 打招呼内容
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.format_quote,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      greet.content,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _replyGreet(greet),
                    icon: const Icon(Icons.reply, size: 18),
                    label: Text(l10n.reply),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addFriend(greet),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: Text(l10n.addFriend),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
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
