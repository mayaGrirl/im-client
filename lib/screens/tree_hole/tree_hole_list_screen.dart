/// 树洞列表页面
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/tree_hole_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/screens/tree_hole/tree_hole_detail_screen.dart';
import 'package:im_client/screens/tree_hole/tree_hole_publish_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class TreeHoleListScreen extends StatefulWidget {
  const TreeHoleListScreen({super.key});

  @override
  State<TreeHoleListScreen> createState() => _TreeHoleListScreenState();
}

class _TreeHoleListScreenState extends State<TreeHoleListScreen>
    with SingleTickerProviderStateMixin {
  final TreeHoleApi _api = TreeHoleApi(ApiClient());
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  List<TreeHolePost> _posts = [];
  List<String> _topics = [];
  String? _selectedTopic; // null means "all"
  String? _selectedTag; // tag filter
  String _sortBy = 'latest';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _pageSize = 20;

  // 服务器话题 -> i18n key 映射
  static const Map<String, String> _topicKeyMap = {
    '日常': 'topic_daily',
    '情感': 'topic_emotion',
    '工作': 'topic_work',
    '学习': 'topic_study',
    '吐槽': 'topic_vent',
    '求助': 'topic_help',
    '分享': 'topic_share',
    '深夜': 'topic_night',
    '职场': 'topic_career',
    '校园': 'topic_campus',
    '暗恋': 'topic_crush',
    '失恋': 'topic_heartbreak',
    '单身': 'topic_single',
    '脱单': 'topic_relationship',
    '焦虑': 'topic_anxiety',
    '压力': 'topic_pressure',
    '迷茫': 'topic_confused',
    '成长': 'topic_growth',
    '梦想': 'topic_dream',
    '回忆': 'topic_memory',
    '秘密': 'topic_secret',
    '家庭': 'topic_family',
    '友情': 'topic_friendship',
    '八卦': 'topic_gossip',
    '追星': 'topic_fandom',
    '游戏': 'topic_game',
    '美食': 'topic_food',
    '旅行': 'topic_travel',
    '健身': 'topic_fitness',
    '穿搭': 'topic_fashion',
    '音乐': 'topic_music',
    '电影': 'topic_movie',
    '读书': 'topic_reading',
    '其他': 'topic_other',
  };

  // 获取话题的本地化显示名称
  String _getTopicDisplayName(AppLocalizations l10n, String serverTopic) {
    final key = _topicKeyMap[serverTopic] ?? 'topic_other';
    return l10n.translate(key);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _sortBy = _tabController.index == 0 ? 'latest' : 'hot';
          _page = 1;
          _posts = [];
          _hasMore = true;
        });
        _loadPosts();
      }
    });
    _scrollController.addListener(_onScroll);
    _loadTopics();
    _loadPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadTopics() async {
    try {
      final response = await _api.getTopics();
      if (response.success && response.data != null) {
        final topicList = (response.data as List).map((e) => e.toString()).toList();
        setState(() {
          _topics = topicList;
        });
      }
    } catch (e) {
      debugPrint('Load topics failed: $e');
    }
  }

  Future<void> _loadPosts() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final response = await _api.getTreeHoleList(
        page: 1,
        pageSize: _pageSize,
        topic: _selectedTopic,
        tag: _selectedTag,
        sort: _sortBy,
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final list = (data['list'] as List?) ?? [];
        setState(() {
          _posts = list.map((e) => TreeHolePost.fromJson(e)).toList();
          _page = 1;
          _hasMore = list.length >= _pageSize;
        });
      }
    } catch (e) {
      debugPrint('Load tree hole failed: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.loadFailed}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final response = await _api.getTreeHoleList(
        page: _page + 1,
        pageSize: _pageSize,
        topic: _selectedTopic,
        tag: _selectedTag,
        sort: _sortBy,
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final list = (data['list'] as List?) ?? [];
        setState(() {
          _posts.addAll(list.map((e) => TreeHolePost.fromJson(e)));
          _page++;
          _hasMore = list.length >= _pageSize;
        });
      }
    } catch (e) {
      debugPrint('Load more failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    _page = 1;
    _hasMore = true;
    await _loadPosts();
  }

  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    try {
      final response = await _api.toggleLike(post.id);
      if (response.success) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _posts[index] = post.copyWith(
            isLiked: data['liked'] ?? !post.isLiked,
            likeCount: data['like_count'] ?? post.likeCount,
          );
        });
      }
    } catch (e) {
      debugPrint('Like failed: $e');
    }
  }

  void _goToDetail(TreeHolePost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TreeHoleDetailScreen(post: post),
      ),
    ).then((result) {
      if (result == true) {
        _onRefresh();
      }
    });
  }

  void _filterByTag(String tag) {
    setState(() {
      _selectedTag = tag;
      _page = 1;
      _posts = [];
      _hasMore = true;
    });
    _loadPosts();
  }

  void _clearTagFilter() {
    setState(() {
      _selectedTag = null;
      _page = 1;
      _posts = [];
      _hasMore = true;
    });
    _loadPosts();
  }

  void _goToPublish() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TreeHolePublishScreen(),
      ),
    ).then((result) {
      if (result == true) {
        _onRefresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final allTopics = [l10n.all, ..._topics];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(l10n.treeHole),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(88),
          child: Column(
            children: [
              // 话题筛选
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: allTopics.length,
                  itemBuilder: (context, index) {
                    final topic = allTopics[index];
                    final isAll = index == 0;
                    final isSelected = isAll ? _selectedTopic == null : topic == _selectedTopic;
                    // 第一个是"全部"使用原值，其他话题需要翻译
                    final displayName = isAll ? topic : _getTopicDisplayName(l10n, topic);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(displayName),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedTopic = isAll ? null : topic;
                              _page = 1;
                              _posts = [];
                              _hasMore = true;
                            });
                            _loadPosts();
                          }
                        },
                        selectedColor: Theme.of(context).primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // 排序标签
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: [
                  Tab(text: l10n.latest),
                  Tab(text: l10n.popular),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // 标签筛选指示器
          if (_selectedTag != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.teal.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.label, size: 16, color: Colors.teal[700]),
                  const SizedBox(width: 6),
                  Text(
                    '#$_selectedTag',
                    style: TextStyle(color: Colors.teal[700], fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _clearTagFilter,
                    child: Icon(Icons.close, size: 18, color: Colors.teal[700]),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: _isLoading && _posts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _posts.isEmpty
                      ? _buildEmpty(l10n)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 8),
                          itemCount: _posts.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _posts.length) {
                              return _buildLoadingMore(l10n);
                            }
                            return _buildPostItem(_posts[index], index, l10n);
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToPublish,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.eco_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            l10n.noContent,
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.beFirstToShare,
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMore(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: _isLoadingMore
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              l10n.noMore,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
    );
  }

  Widget _buildPostItem(TreeHolePost post, int index, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => _goToDetail(post),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 匿名头像
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getAvatarColor(post.anonymousId),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              post.anonymousId,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                            if (post.isHot) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n.popular,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTime(post.createdAt, l10n),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (post.topic != null && post.topic!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#${_getTopicDisplayName(l10n, post.topic!)}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 内容
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                post.content,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
            // 标签
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: post.tags.map((tag) {
                    return GestureDetector(
                      onTap: () => _filterByTag(tag),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          color: Colors.teal[600],
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            // 图片
            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildImages(post.images),
              ),
            ],
            // 底部操作栏
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildActionButton(
                    icon: Icons.remove_red_eye_outlined,
                    count: post.viewCount,
                    onTap: null,
                  ),
                  const SizedBox(width: 24),
                  _buildActionButton(
                    icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                    count: post.likeCount,
                    color: post.isLiked ? Colors.red : null,
                    onTap: () => _toggleLike(index),
                  ),
                  const SizedBox(width: 24),
                  _buildActionButton(
                    icon: Icons.chat_bubble_outline,
                    count: post.commentCount,
                    onTap: () => _goToDetail(post),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImages(List<String> images) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: CachedNetworkImage(
            imageUrl: EnvConfig.instance.getFileUrl(images[0]),
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: images.length == 4 ? 2 : 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: images.length > 9 ? 9 : images.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            imageUrl: EnvConfig.instance.getFileUrl(images[index]),
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[200]),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, size: 20),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    Color? color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            count > 0 ? _formatCount(count) : '',
            style: TextStyle(
              color: color ?? Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Color _getAvatarColor(String anonymousId) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];
    final index = anonymousId.hashCode.abs() % colors.length;
    return colors[index];
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
      return DateFormat('MM-dd').format(time);
    }
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 1000).toStringAsFixed(0)}k';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}
