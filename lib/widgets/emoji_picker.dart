/// 表情选择器组件
import 'package:flutter/material.dart';
import 'package:im_client/api/emoji_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';

/// 常用 Unicode 表情列表
const List<String> defaultEmojis = [
  // 笑脸
  '\u{1F600}', '\u{1F603}', '\u{1F604}', '\u{1F601}', '\u{1F606}', '\u{1F605}',
  '\u{1F602}', '\u{1F923}', '\u{1F60A}', '\u{1F607}', '\u{1F642}', '\u{1F643}',
  '\u{1F609}', '\u{1F60C}', '\u{1F60D}', '\u{1F970}', '\u{1F618}', '\u{1F617}',
  '\u{1F619}', '\u{1F61A}', '\u{1F60B}', '\u{1F61B}', '\u{1F61C}', '\u{1F92A}',
  '\u{1F61D}', '\u{1F911}', '\u{1F917}', '\u{1F92D}', '\u{1F92B}', '\u{1F914}',
  // 其他表情
  '\u{1F910}', '\u{1F928}', '\u{1F610}', '\u{1F611}', '\u{1F636}', '\u{1F60F}',
  '\u{1F612}', '\u{1F644}', '\u{1F62C}', '\u{1F925}', '\u{1F60C}', '\u{1F614}',
  '\u{1F62A}', '\u{1F924}', '\u{1F634}', '\u{1F637}', '\u{1F912}', '\u{1F915}',
  '\u{1F922}', '\u{1F92E}', '\u{1F927}', '\u{1F975}', '\u{1F976}', '\u{1F974}',
  '\u{1F635}', '\u{1F92F}', '\u{1F920}', '\u{1F973}', '\u{1F978}', '\u{1F60E}',
  // 负面表情
  '\u{1F615}', '\u{1F61F}', '\u{1F641}', '\u{2639}',  '\u{1F62E}', '\u{1F62F}',
  '\u{1F632}', '\u{1F633}', '\u{1F97A}', '\u{1F626}', '\u{1F627}', '\u{1F628}',
  '\u{1F630}', '\u{1F625}', '\u{1F622}', '\u{1F62D}', '\u{1F631}', '\u{1F616}',
  '\u{1F623}', '\u{1F61E}', '\u{1F613}', '\u{1F629}', '\u{1F62B}', '\u{1F624}',
  '\u{1F621}', '\u{1F620}', '\u{1F92C}', '\u{1F608}', '\u{1F47F}', '\u{1F480}',
  // 手势
  '\u{1F44D}', '\u{1F44E}', '\u{1F44A}', '\u{270A}',  '\u{1F91B}', '\u{1F91C}',
  '\u{1F44F}', '\u{1F64C}', '\u{1F450}', '\u{1F932}', '\u{1F91D}', '\u{1F64F}',
  '\u{270D}',  '\u{1F485}', '\u{1F933}', '\u{1F4AA}', '\u{1F9B5}', '\u{1F9B6}',
  '\u{1F442}', '\u{1F443}', '\u{1F9E0}', '\u{1F9B7}', '\u{1F9B4}', '\u{1F440}',
  '\u{1F441}', '\u{1F445}', '\u{1F444}', '\u{1F48B}', '\u{1F476}', '\u{1F9D2}',
  // 动物
  '\u{1F436}', '\u{1F431}', '\u{1F42D}', '\u{1F439}', '\u{1F430}', '\u{1F98A}',
  '\u{1F43B}', '\u{1F43C}', '\u{1F428}', '\u{1F42F}', '\u{1F981}', '\u{1F42E}',
  '\u{1F437}', '\u{1F438}', '\u{1F435}', '\u{1F649}', '\u{1F64A}', '\u{1F412}',
  '\u{1F414}', '\u{1F427}', '\u{1F426}', '\u{1F985}', '\u{1F986}', '\u{1F989}',
  // 食物
  '\u{1F34E}', '\u{1F34F}', '\u{1F34A}', '\u{1F34B}', '\u{1F34C}', '\u{1F349}',
  '\u{1F347}', '\u{1F353}', '\u{1F348}', '\u{1F352}', '\u{1F351}', '\u{1F34D}',
  '\u{1F354}', '\u{1F355}', '\u{1F32D}', '\u{1F32E}', '\u{1F32F}', '\u{1F37F}',
  '\u{1F366}', '\u{1F367}', '\u{1F368}', '\u{1F369}', '\u{1F36A}', '\u{1F382}',
  // 心形
  '\u{2764}',  '\u{1F9E1}', '\u{1F49B}', '\u{1F49A}', '\u{1F499}', '\u{1F49C}',
  '\u{1F5A4}', '\u{1F90D}', '\u{1F90E}', '\u{1F494}', '\u{2763}',  '\u{1F495}',
  '\u{1F49E}', '\u{1F493}', '\u{1F497}', '\u{1F496}', '\u{1F498}', '\u{1F49D}',
  // 符号
  '\u{2728}',  '\u{1F31F}', '\u{1F4A5}', '\u{1F4A2}', '\u{1F4A6}', '\u{1F4A8}',
  '\u{1F4AB}', '\u{1F4AC}', '\u{1F4AD}', '\u{1F4A4}', '\u{1F525}', '\u{1F4AF}',
  '\u{2705}',  '\u{274C}',  '\u{2753}',  '\u{2757}',  '\u{1F44C}', '\u{270C}',
];

/// 表情选择器
class EmojiPicker extends StatefulWidget {
  final Function(String emoji) onEmojiSelected;
  final double height;

  const EmojiPicker({
    super.key,
    required this.onEmojiSelected,
    this.height = 300,
  });

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final EmojiApi _emojiApi = EmojiApi();
  List<EmojiItem> _systemEmojis = [];
  List<EmojiItem> _myEmojis = [];
  List<EmojiPack> _emojiPacks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEmojis();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadEmojis() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _emojiApi.getSystemEmojis(),
        _emojiApi.getMyEmojis(),
        _emojiApi.getEmojiPacks(),
      ]);

      final systemEmojis = results[0] as List<EmojiItem>;
      final myEmojis = results[1] as List<EmojiItem>;
      final packs = results[2] as List<EmojiPack>;

      // 加载每个表情包的详情
      List<EmojiPack> packsWithEmojis = [];
      for (final pack in packs) {

        try {
          final detail = await _emojiApi.getEmojiPackDetail(pack.id);
          if (detail != null && detail.emojis.isNotEmpty) {
            packsWithEmojis.add(detail);
          }
        } catch (e) {
          print('[EmojiPicker] Failed to load emoticon package${pack.id}: $e');
        }
      }

      setState(() {
        _systemEmojis = systemEmojis;
        _myEmojis = myEmojis;
        _emojiPacks = packsWithEmojis;

        // 创建TabController: 常用 + 系统 + 表情包数量 + 收藏
        final tabCount = 3 + _emojiPacks.length;

        _tabController?.dispose();
        _tabController = TabController(length: tabCount, vsync: this);
      });
    } catch (e, stack) {
      print('[EmojiPicker] Stack: $stack');
      // 加载失败使用默认配置
      setState(() {
        _tabController?.dispose();
        _tabController = TabController(length: 3, vsync: this);
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 获取完整图片URL（通过代理解决CORS问题）
  String _getImageUrl(String url) {
    if (url.isEmpty) return '';

    // 如果已经是代理URL，提取原始URL重新代理
    if (url.contains('/proxy/image?url=')) {
      try {
        final uri = Uri.parse(url);
        final originalUrl = uri.queryParameters['url'];
        if (originalUrl != null && originalUrl.isNotEmpty) {
          // 使用当前服务器的代理地址
          final encodedUrl = Uri.encodeComponent(originalUrl);
          return '${EnvConfig.instance.fullApiUrl}/proxy/image?url=$encodedUrl';
        }
      } catch (_) {}
    }

    if (url.startsWith('http')) {
      // 外部CDN图片通过后端代理加载（解决CORS问题）
      final encodedUrl = Uri.encodeComponent(url);
      return '${EnvConfig.instance.fullApiUrl}/proxy/image?url=$encodedUrl';
    }
    return EnvConfig.instance.getFileUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_tabController == null || l10n == null) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // 构建Tab列表
    final tabs = <Widget>[
      Tab(text: l10n.translate('frequentlyUsed')),
      Tab(text: l10n.translate('system')),
      ..._emojiPacks.map((pack) => Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pack.cover.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    _getImageUrl(pack.cover),
                    width: 20,
                    height: 20,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Text(pack.name, overflow: TextOverflow.ellipsis),
          ],
        ),
      )),
      Tab(text: l10n.translate('favorites')),
    ];

    // 构建TabBarView内容
    final tabViews = <Widget>[
      _buildDefaultEmojiGrid(),
      _buildSystemEmojiGrid(l10n),
      ..._emojiPacks.map((pack) => _buildPackEmojiGrid(pack, l10n)),
      _buildMyEmojiGrid(l10n),
    ];

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 拖动指示器
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标签栏
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs,
          ),
          // 表情网格
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: tabViews,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建默认 Unicode 表情网格
  Widget _buildDefaultEmojiGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: defaultEmojis.length,
      itemBuilder: (context, index) {
        return _buildEmojiButton(defaultEmojis[index]);
      },
    );
  }

  /// 构建系统表情网格
  Widget _buildSystemEmojiGrid(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_systemEmojis.isEmpty) {
      return Center(child: Text(l10n.translate('noSystemEmojis')));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _systemEmojis.length,
      itemBuilder: (context, index) {
        final emoji = _systemEmojis[index];
        return _buildImageEmojiButton(emoji, l10n: l10n);
      },
    );
  }

  /// 构建我的表情网格
  Widget _buildMyEmojiGrid(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_myEmojis.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_emotions_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(l10n.translate('noFavoriteEmojis'), style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(l10n.translate('longPressToCollect'), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _myEmojis.length,
      itemBuilder: (context, index) {
        final emoji = _myEmojis[index];
        return _buildMyEmojiButton(emoji, l10n);
      },
    );
  }

  /// 构建我的收藏表情按钮（支持删除）
  Widget _buildMyEmojiButton(EmojiItem emoji, AppLocalizations l10n) {
    final imageUrl = _getImageUrl(emoji.url);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onEmojiSelected('[emoji:$imageUrl]');
        },
        onLongPress: () {
          _showDeleteEmojiDialog(emoji, l10n);
        },
        borderRadius: BorderRadius.circular(8),
        splashColor: AppColors.primary.withOpacity(0.2),
        highlightColor: AppColors.primary.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[100],
          ),
          padding: const EdgeInsets.all(4),
          child: Stack(
            children: [
              Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.broken_image, color: Colors.grey);
                  },
                ),
              ),
              // 删除按钮（可点击）
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: () {
                    _showDeleteEmojiDialog(emoji, l10n);
                  },
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示删除表情确认对话框
  void _showDeleteEmojiDialog(EmojiItem emoji, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('deleteFavorite')),
          content: Text(l10n.translate('confirmRemoveEmoji').replaceAll('{name}', emoji.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.translate('cancel')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteEmoji(emoji, l10n);
              },
              child: Text(l10n.translate('delete'), style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// 删除收藏的表情
  Future<void> _deleteEmoji(EmojiItem emoji, AppLocalizations l10n) async {
    try {
      final success = await _emojiApi.deleteEmoji(emoji.id);
      if (success && mounted) {
        setState(() {
          _myEmojis.removeWhere((e) => e.id == emoji.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('removedFromFavorites')), duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('deleteFailed')}: $e')),
        );
      }
    }
  }

  /// 构建表情包表情网格
  Widget _buildPackEmojiGrid(EmojiPack pack, AppLocalizations l10n) {
    if (pack.emojis.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_emotions_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(l10n.translate('noEmojisInPack'), style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 表情包表情通常较大，使用4列
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: pack.emojis.length,
      itemBuilder: (context, index) {
        final emoji = pack.emojis[index];
        return _buildImageEmojiButton(emoji, isLarge: true, l10n: l10n);
      },
    );
  }

  /// 构建 Unicode 表情按钮
  Widget _buildEmojiButton(String emoji) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onEmojiSelected(emoji);
        },
        borderRadius: BorderRadius.circular(8),
        splashColor: AppColors.primary.withOpacity(0.2),
        highlightColor: AppColors.primary.withOpacity(0.1),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }

  /// 构建图片表情按钮（支持长按收藏）
  Widget _buildImageEmojiButton(EmojiItem emoji, {bool isLarge = false, required AppLocalizations l10n}) {
    final imageUrl = _getImageUrl(emoji.url);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 发送时使用完整URL
          widget.onEmojiSelected('[emoji:$imageUrl]');
        },
        onLongPress: () {
          _showCollectEmojiDialog(emoji, imageUrl, l10n);
        },
        borderRadius: BorderRadius.circular(8),
        splashColor: AppColors.primary.withOpacity(0.2),
        highlightColor: AppColors.primary.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[100],
          ),
          padding: EdgeInsets.all(isLarge ? 6 : 4),
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.broken_image, color: Colors.grey);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 显示收藏表情对话框
  void _showCollectEmojiDialog(EmojiItem emoji, String imageUrl, AppLocalizations l10n) {
    // 检查是否已收藏
    final isCollected = _myEmojis.any((e) => e.url == emoji.url || _getImageUrl(e.url) == imageUrl);

    if (isCollected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('alreadyInFavorites')), duration: const Duration(seconds: 1)),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('collectEmoji')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
              const SizedBox(height: 12),
              Text(l10n.translate('confirmCollectEmoji').replaceAll('{name}', emoji.name)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.translate('cancel')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _collectEmoji(emoji, imageUrl, l10n);
              },
              child: Text(l10n.translate('collect')),
            ),
          ],
        );
      },
    );
  }

  /// 收藏表情
  Future<void> _collectEmoji(EmojiItem emoji, String imageUrl, AppLocalizations l10n) async {
    try {
      // 保存原始CDN URL，而不是代理URL
      final success = await _emojiApi.addEmoji(
        url: emoji.url,
        name: emoji.name,
      );
      if (success && mounted) {
        // 重新加载我的表情
        final myEmojis = await _emojiApi.getMyEmojis();
        setState(() {
          _myEmojis = myEmojis;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('addedToFavorites')), duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('collectFailed')}: $e')),
        );
      }
    }
  }
}

/// 显示表情选择器的底部弹窗
void showEmojiPicker(BuildContext context, Function(String emoji) onSelected) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => EmojiPicker(
      onEmojiSelected: (emoji) {
        onSelected(emoji);
        Navigator.pop(context);
      },
    ),
  );
}
