/// 收藏页面
/// 显示用户收藏的消息列表

import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/favorite_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoriteApi _favoriteApi = FavoriteApi(ApiClient());
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<FavoriteItem> _favorites = [];
  bool _isLoading = false;
  bool _isFirstLoad = true; // 首次加载标记
  bool _hasMore = true;
  int _currentPage = 1;
  int? _filterContentType;
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFavorites({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = 1;
        _favorites = [];
        _hasMore = true;
      }
    });

    try {
      final response = await _favoriteApi.getFavorites(
        page: _currentPage,
        contentType: _filterContentType,
        keyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
      );

      if (response.success && response.data != null) {
        final List<dynamic> list = response.data['list'] ?? response.data ?? [];
        final newFavorites =
            list.map((e) => FavoriteItem.fromJson(e)).toList();

        setState(() {
          if (refresh) {
            _favorites = newFavorites;
          } else {
            _favorites.addAll(newFavorites);
          }
          _hasMore = newFavorites.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('load_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFirstLoad = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    _currentPage++;
    await _loadFavorites();
  }

  Future<void> _deleteFavorite(FavoriteItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_favorite')),
        content: Text(l10n.translate('delete_favorite_confirm')),
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
      final response = await _favoriteApi.deleteFavorite(item.id);
      if (response.success) {
        setState(() {
          _favorites.removeWhere((f) => f.id == item.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('deleted'))),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message ?? l10n.translate('delete_failed'))),
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

  void _showFilterOptions() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: Text(l10n.translate('all')),
              selected: _filterContentType == null,
              onTap: () {
                Navigator.pop(context);
                setState(() => _filterContentType = null);
                _loadFavorites(refresh: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: Text(l10n.translate('text_type')),
              selected: _filterContentType == 1,
              onTap: () {
                Navigator.pop(context);
                setState(() => _filterContentType = 1);
                _loadFavorites(refresh: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: Text(l10n.translate('image')),
              selected: _filterContentType == 2,
              onTap: () {
                Navigator.pop(context);
                setState(() => _filterContentType = 2);
                _loadFavorites(refresh: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: Text(l10n.translate('video')),
              selected: _filterContentType == 4,
              onTap: () {
                Navigator.pop(context);
                setState(() => _filterContentType = 4);
                _loadFavorites(refresh: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: Text(l10n.translate('file')),
              selected: _filterContentType == 5,
              onTap: () {
                Navigator.pop(context);
                setState(() => _filterContentType = 5);
                _loadFavorites(refresh: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    if (url == '/') return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final baseUrl = EnvConfig.instance.baseUrl;
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.favorites),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.translate('search_favorites'),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchKeyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchKeyword = '');
                          _loadFavorites(refresh: true);
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (value) {
                setState(() => _searchKeyword = value);
                _loadFavorites(refresh: true);
              },
            ),
          ),
          // 筛选标签
          if (_filterContentType != null)
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Chip(
                    label: Text(_getFilterName(_filterContentType!, l10n)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() => _filterContentType = null);
                      _loadFavorites(refresh: true);
                    },
                  ),
                ],
              ),
            ),
          // 收藏列表
          Expanded(
            child: _isFirstLoad
                ? const Center(child: CircularProgressIndicator())
                : _favorites.isEmpty
                    ? _buildEmptyState(l10n)
                    : RefreshIndicator(
                        onRefresh: () => _loadFavorites(refresh: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 8, bottom: 16),
                          itemCount: _favorites.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _favorites.length) {
                              return _isLoading
                                  ? const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : const SizedBox.shrink();
                            }
                            return _buildFavoriteItem(_favorites[index], l10n);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _getFilterName(int contentType, AppLocalizations l10n) {
    switch (contentType) {
      case 1:
        return l10n.translate('text_type');
      case 2:
        return l10n.translate('image');
      case 3:
        return l10n.translate('voice');
      case 4:
        return l10n.translate('video');
      case 5:
        return l10n.translate('file');
      default:
        return l10n.translate('all');
    }
  }

  /// 获取内容类型本地化名称
  String _getContentTypeName(int contentType, AppLocalizations l10n) {
    switch (contentType) {
      case 1:
        return l10n.translate('text_type');
      case 2:
        return l10n.translate('image');
      case 3:
        return l10n.translate('voice');
      case 4:
        return l10n.translate('video');
      case 5:
        return l10n.translate('file');
      case 6:
        return l10n.translate('location');
      case 7:
        return l10n.translate('card');
      case 8:
        return l10n.translate('chat_record');
      default:
        return l10n.translate('message');
    }
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_outline,
                size: 48,
                color: Colors.grey[350],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.translate('no_favorites'),
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('no_favorites_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteItem(FavoriteItem item, AppLocalizations l10n) {
    return Dismissible(
      key: Key('favorite_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_outline, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(l10n.delete, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _deleteFavorite(item);
        return false;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showFavoriteDetail(item),
            onLongPress: () => _deleteFavorite(item),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildItemContent(item, l10n),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemContent(FavoriteItem item, AppLocalizations l10n) {
    // 图片类型特殊布局
    if (item.contentType == 2) {
      return _buildImageItem(item, l10n);
    }
    // 其他类型通用布局
    return _buildGeneralItem(item, l10n);
  }

  /// 图片类型收藏项
  Widget _buildImageItem(FavoriteItem item, AppLocalizations l10n) {
    final imageUrl = _getFullUrl(item.content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部信息栏
        Row(
          children: [
            _buildTypeTag(item, l10n),
            const Spacer(),
            Text(
              _formatDate(item.createdAt, l10n),
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 图片预览
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: double.infinity,
            height: 160,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 160,
              color: Colors.grey[100],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              height: 160,
              color: Colors.grey[100],
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
              ),
            ),
          ),
        ),
        // 来源信息
        if (item.extraInfo?.fromUser != null) ...[
          const SizedBox(height: 8),
          _buildFromUserInfo(item, l10n),
        ],
      ],
    );
  }

  /// 通用类型收藏项
  Widget _buildGeneralItem(FavoriteItem item, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧图标
        _buildLeadingIcon(item),
        const SizedBox(width: 12),
        // 中间内容
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：类型标签 + 时间
              Row(
                children: [
                  _buildTypeTag(item, l10n),
                  const Spacer(),
                  Text(
                    _formatDate(item.createdAt, l10n),
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 内容预览
              Text(
                _getContentPreview(item, l10n),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              // 来源信息
              if (item.extraInfo?.fromUser != null) ...[
                const SizedBox(height: 8),
                _buildFromUserInfo(item, l10n),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 类型标签
  Widget _buildTypeTag(FavoriteItem item, AppLocalizations l10n) {
    final typeInfo = _getTypeInfo(item.contentType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: typeInfo.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(typeInfo.icon, size: 12, color: typeInfo.color),
          const SizedBox(width: 4),
          Text(
            _getContentTypeName(item.contentType, l10n),
            style: TextStyle(
              color: typeInfo.color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 来源用户信息
  Widget _buildFromUserInfo(FavoriteItem item, AppLocalizations l10n) {
    return Row(
      children: [
        Icon(Icons.person_outline, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(
          '${l10n.translate('from_user')} ${item.extraInfo!.fromUser!.nickname ?? l10n.translate('unknown_user')}',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLeadingIcon(FavoriteItem item) {
    final typeInfo = _getTypeInfo(item.contentType);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: typeInfo.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(typeInfo.icon, color: typeInfo.color, size: 22),
    );
  }

  /// 获取类型信息
  _TypeInfo _getTypeInfo(int contentType) {
    switch (contentType) {
      case 1:
        return _TypeInfo(Icons.article_outlined, Colors.blue);
      case 2:
        return _TypeInfo(Icons.image_outlined, Colors.green);
      case 3:
        return _TypeInfo(Icons.mic_outlined, Colors.orange);
      case 4:
        return _TypeInfo(Icons.videocam_outlined, Colors.purple);
      case 5:
        return _TypeInfo(Icons.insert_drive_file_outlined, Colors.teal);
      case 6:
        return _TypeInfo(Icons.location_on_outlined, Colors.red);
      case 7:
        return _TypeInfo(Icons.person_outlined, Colors.indigo);
      case 8:
        return _TypeInfo(Icons.chat_outlined, Colors.deepPurple);
      default:
        return _TypeInfo(Icons.chat_bubble_outline, Colors.grey);
    }
  }

  /// 获取内容预览文本
  String _getContentPreview(FavoriteItem item, AppLocalizations l10n) {
    switch (item.contentType) {
      case 1:
        return item.content;
      case 3:
        return '[${l10n.translate('voice_message')}]';
      case 4:
        return '[${l10n.translate('video')}]';
      case 5:
        return '[${l10n.translate('file')}]';
      case 6:
        return '[${l10n.translate('location')}]';
      case 7:
        return '[${l10n.translate('card')}]';
      case 8:
        return '[${l10n.translate('chat_record')}]';
      default:
        return item.content.isNotEmpty ? item.content : '[${l10n.translate('message')}]';
    }
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return l10n.translate('yesterday');
    } else if (diff.inDays < 7) {
      return l10n.translate('days_ago').replaceAll('{days}', diff.inDays.toString());
    } else {
      return '${date.month}/${date.day}';
    }
  }

  void _showFavoriteDetail(FavoriteItem item) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getContentTypeName(item.contentType, l10n)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.contentType == 2) ...[
                // 图片
                CachedNetworkImage(
                  imageUrl: _getFullUrl(item.content),
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                ),
              ] else ...[
                Text(item.content),
              ],
              if (item.note != null && item.note!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '${l10n.translate('remark')}: ${item.note}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
              if (item.extraInfo?.fromUser != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${l10n.translate('from_user')}: ${item.extraInfo!.fromUser!.nickname ?? l10n.translate('unknown_user')}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${l10n.translate('favorite_time')}: ${item.createdAt.toString().substring(0, 16)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('close')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFavorite(item);
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 类型信息辅助类
class _TypeInfo {
  final IconData icon;
  final Color color;

  _TypeInfo(this.icon, this.color);
}
