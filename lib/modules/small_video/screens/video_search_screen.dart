/// 视频搜索页面

import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/modules/small_video/api/small_video_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/modules/small_video/models/small_video.dart';
import 'package:im_client/modules/small_video/screens/video_detail_screen.dart';

class VideoSearchScreen extends StatefulWidget {
  const VideoSearchScreen({super.key});

  @override
  State<VideoSearchScreen> createState() => _VideoSearchScreenState();
}

class _VideoSearchScreenState extends State<VideoSearchScreen> {
  final SmallVideoApi _api = SmallVideoApi(ApiClient());
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<SmallVideo> _results = [];
  List<SmallVideoTag> _hotTags = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadHotTags();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadHotTags() async {
    try {
      // Get current locale
      final locale = Localizations.localeOf(context);
      String lang = 'zh-CN'; // default
      
      // Map Flutter locale to backend language codes
      if (locale.languageCode == 'en') {
        lang = 'en';
      } else if (locale.languageCode == 'zh') {
        if (locale.countryCode == 'TW' || locale.scriptCode == 'Hant') {
          lang = 'zh-TW';
        } else {
          lang = 'zh-CN';
        }
      } else if (locale.languageCode == 'fr') {
        lang = 'fr';
      } else if (locale.languageCode == 'hi') {
        lang = 'hi';
      }
      
      final response = await _api.getHotTags(lang: lang);
      if (response.success && response.data != null) {
        final data = response.data;
        List list;
        if (data is Map && data['list'] != null) {
          list = data['list'] as List;
        } else if (data is List) {
          list = data;
        } else {
          list = [];
        }
        setState(() {
          _hotTags = list.map((e) => SmallVideoTag.fromJson(e)).toList();
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _search({bool isNew = true}) async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    if (isNew) {
      _page = 1;
      _hasMore = true;
      setState(() {
        _results = [];
        _hasSearched = true;
      });
    }

    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final response = await _api.searchVideos(keyword, page: _page);
      if (response.success && response.data != null) {
        final data = response.data;
        List list;
        if (data is Map && data['list'] != null) {
          list = data['list'] as List;
        } else if (data is List) {
          list = data;
        } else {
          list = [];
        }
        final videos = list.map((e) => SmallVideo.fromJson(e)).toList();
        setState(() {
          if (isNew) {
            _results = videos;
          } else {
            _results.addAll(videos);
          }
          _page++;
          _hasMore = videos.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), duration: const Duration(seconds: 2)),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    if (_hasMore && !_isLoading) {
      await _search(isNew: false);
    }
  }

  void _searchTag(String tagName) {
    // Use the default name (original Chinese name) for searching
    // This ensures search works across all languages
    _searchController.text = tagName;
    _search();
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 38,
          margin: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.translate('sv_search'),
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
        ),
      ),
      body: !_hasSearched
          ? _buildHotTags(l10n)
          : _buildSearchResults(l10n),
    );
  }

  Widget _buildHotTags(AppLocalizations l10n) {
    if (_hotTags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
              const SizedBox(width: 6),
              Text(
                l10n.translate('sv_hot'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _hotTags.map((tag) => GestureDetector(
              onTap: () => _searchTag(tag.name),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#${tag.name}',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    if (tag.videoCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        _formatCount(tag.videoCount),
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(AppLocalizations l10n) {
    if (_results.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          l10n.translate('no_data'),
          style: TextStyle(color: AppColors.textHint, fontSize: 15),
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _results.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildSearchResultItem(_results[index]);
      },
    );
  }

  Widget _buildSearchResultItem(SmallVideo video) {
    return GestureDetector(
      onTap: () {
        final index = _results.indexOf(video);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoDetailScreen(
              videos: _results,
              initialIndex: index >= 0 ? index : 0,
            ),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 封面
          video.coverUrl.isNotEmpty
              ? Image.network(
                  video.coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.video_library, size: 32, color: Colors.grey),
                  ),
                )
              : Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.video_library, size: 32, color: Colors.grey),
                ),

          // 渐变遮罩
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (video.title.isNotEmpty)
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // 头像
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: video.user?.avatar.isNotEmpty == true
                            ? NetworkImage(video.user!.avatar)
                            : null,
                        child: video.user?.avatar.isEmpty != false
                            ? const Icon(Icons.person, size: 12)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          video.user?.nickname ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      const Icon(Icons.favorite, size: 14, color: Colors.white70),
                      const SizedBox(width: 2),
                      Text(
                        _formatCount(video.likeCount),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
