/// 礼物面板组件
/// TikTok风格底部弹出的礼物选择和发送面板
/// 支持分类tab、档次标签、连击发送、金豆余额显示

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/modules/livestream/models/livestream.dart';
import 'package:im_client/modules/livestream/providers/livestream_provider.dart';

class GiftPanel extends StatefulWidget {
  final int livestreamId;
  final Function(LivestreamGift gift)? onGiftSent;

  const GiftPanel({super.key, required this.livestreamId, this.onGiftSent});

  @override
  State<GiftPanel> createState() => _GiftPanelState();
}

class _GiftPanelState extends State<GiftPanel> with TickerProviderStateMixin {
  int? _selectedGiftId;
  int _count = 1;
  bool _sending = false;
  String _activeCategory = '全部';
  TabController? _tabController;
  List<String> _categories = ['全部'];
  bool _categoriesBuilt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<LivestreamProvider>(context, listen: false);
      provider.loadGifts();
      provider.loadGoldBeans();
      // 等礼物加载后动态构建分类
      provider.addListener(_onGiftsChanged);
    });
  }

  void _onGiftsChanged() {
    if (!mounted) return;
    final provider = Provider.of<LivestreamProvider>(context, listen: false);
    if (provider.gifts.isNotEmpty && !_categoriesBuilt) {
      _buildCategories(provider.gifts);
    }
  }

  void _buildCategories(List<LivestreamGift> gifts) {
    // 从礼物列表动态提取所有分类
    final catSet = <String>{};
    for (final g in gifts) {
      if (g.category.isNotEmpty) catSet.add(g.category);
    }
    // 固定顺序: 全部在前，然后按优先级排列已知分类，最后其余按字母排
    const priorityOrder = ['热门', '浪漫', '美食', '萌宠', '派对', '豪车', '皇室', '游戏', '自然', '节日', '新品', '特效', '豪华', '至尊'];
    final ordered = <String>['全部'];
    for (final cat in priorityOrder) {
      if (catSet.contains(cat)) {
        ordered.add(cat);
        catSet.remove(cat);
      }
    }
    // 剩余未知分类
    final remaining = catSet.toList()..sort();
    ordered.addAll(remaining);

    setState(() {
      _categories = ordered;
      _categoriesBuilt = true;
      _tabController?.dispose();
      _tabController = TabController(length: _categories.length, vsync: this);
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          setState(() {
            _activeCategory = _categories[_tabController!.index];
          });
        }
      });
    });
  }

  @override
  void dispose() {
    final provider = Provider.of<LivestreamProvider>(context, listen: false);
    provider.removeListener(_onGiftsChanged);
    _tabController?.dispose();
    super.dispose();
  }

  List<LivestreamGift> _filteredGifts(List<LivestreamGift> gifts) {
    if (_activeCategory == '全部') return gifts;
    return gifts.where((g) => g.category == _activeCategory).toList();
  }

  Color _tierBorderColor(int tier) {
    switch (tier) {
      case 3: return Colors.purple;
      case 2: return Colors.orange;
      default: return Colors.transparent;
    }
  }

  Color _nftRarityColor(int rarity) {
    switch (rarity) {
      case 1: return Colors.grey;
      case 2: return Colors.blue;
      case 3: return Colors.purple;
      case 4: return Colors.orange;
      default: return Colors.grey;
    }
  }

  Color _tierBadgeColor(int tier) {
    switch (tier) {
      case 3: return Colors.purple;
      case 2: return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _tierLabel(int tier) {
    switch (tier) {
      case 3: return 'S';
      case 2: return 'A';
      default: return '';
    }
  }

  String _getLangCode(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (loc == null) return 'zh_cn';
    final lang = loc.locale.languageCode;
    final country = loc.locale.countryCode;
    if (country != null && country.isNotEmpty) {
      return '${lang}_${country.toLowerCase()}';
    }
    return lang;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 顶部把手
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题和余额
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  '送礼物',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                // 金豆余额
                Consumer<LivestreamProvider>(
                  builder: (context, provider, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            '${provider.goldBeans}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // 分类 Tab
          if (_tabController != null)
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.red,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabAlignment: TabAlignment.start,
              tabs: _categories.map((c) => Tab(text: c)).toList(),
            ),
          // 礼物网格
          Expanded(
            child: Consumer<LivestreamProvider>(
              builder: (context, provider, _) {
                final gifts = _filteredGifts(provider.gifts);
                if (gifts.isEmpty) {
                  return const Center(
                    child: Text('暂无礼物', style: TextStyle(color: Colors.white54)),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: gifts.length,
                  itemBuilder: (context, index) {
                    final gift = gifts[index];
                    final selected = _selectedGiftId == gift.id;
                    return GestureDetector(
                      onTap: () {
                        if (selected && gift.comboEnabled) {
                          _sendGift();
                        } else {
                          setState(() {
                            _selectedGiftId = gift.id;
                            _count = 1;
                          });
                        }
                      },
                      onLongPress: () => _showGiftPreview(gift),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected ? Colors.red.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? Colors.red
                                : gift.isNFT
                                    ? _nftRarityColor(gift.nftRarity).withValues(alpha: 0.7)
                                    : _tierBorderColor(gift.tier).withValues(alpha: 0.5),
                            width: selected ? 2 : (gift.isNFT ? 1.5 : (gift.tier >= 2 ? 1 : 0)),
                          ),
                        ),
                        child: Stack(
                          children: [
                            // 档次标签
                            if (gift.tier >= 2)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _tierBadgeColor(gift.tier),
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(9),
                                      bottomLeft: Radius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    _tierLabel(gift.tier),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            // NFT限量标签
                            if (gift.isNFT)
                              Positioned(
                                top: 0,
                                left: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _nftRarityColor(gift.nftRarity),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(9),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    gift.nftSoldOut ? '已售罄' : '限量 ${gift.nftMintedCount}/${gift.nftTotalSupply}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            // 内容
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // 礼物图标 - 直接显示emoji
                                  Text(
                                    gift.icon,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    gift.localizedName(_getLangCode(context)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('🪙', style: TextStyle(fontSize: 10)),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${gift.price}',
                                        style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w500),
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
                  },
                );
              },
            ),
          ),
          // 底部发送栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                // 数量选择
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white, size: 16),
                        onPressed: _count > 1 ? () => setState(() => _count--) : null,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '$_count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 16),
                        onPressed: _count < 99 ? () => setState(() => _count++) : null,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 快捷数量
                ...[1, 5, 10, 66, 99].map((n) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _count = n),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _count == n ? Colors.red.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: _count == n ? Border.all(color: Colors.red.withValues(alpha: 0.5)) : null,
                      ),
                      child: Text(
                        '$n',
                        style: TextStyle(
                          color: _count == n ? Colors.red : Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                )),
                const Spacer(),
                // 发送按钮
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: (_selectedGiftId != null && !_sending) ? _sendGift : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: _sending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(AppLocalizations.of(context)!.translate('send_out'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGiftPreview(LivestreamGift gift) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 礼物预览（Lottie/图片/emoji）
              SizedBox(
                width: 120,
                height: 120,
                child: gift.effectUrl.isNotEmpty && gift.effectUrl.endsWith('.json')
                    ? Lottie.network(
                        gift.effectUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Text(gift.icon, style: const TextStyle(fontSize: 72)),
                      )
                    : gift.effectUrl.isNotEmpty
                        ? Image.network(
                            gift.effectUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                Text(gift.icon, style: const TextStyle(fontSize: 72)),
                          )
                        : Center(child: Text(gift.icon, style: const TextStyle(fontSize: 72))),
              ),
              const SizedBox(height: 12),
              Text(
                gift.localizedName(_getLangCode(context)),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '${gift.price}',
                    style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (gift.comboEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('支持连击', style: TextStyle(color: Colors.red, fontSize: 11)),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendGift() async {
    if (_selectedGiftId == null) return;

    // Check if NFT gift is sold out
    final provider = Provider.of<LivestreamProvider>(context, listen: false);
    final selectedGift = provider.gifts.where((g) => g.id == _selectedGiftId).firstOrNull;
    if (selectedGift != null && selectedGift.isNFT && selectedGift.nftSoldOut) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该NFT礼物已售罄')),
        );
      }
      return;
    }

    setState(() => _sending = true);

    final ok = await provider.sendGift(
      widget.livestreamId,
      giftId: _selectedGiftId!,
      count: _count,
    );

    if (ok) {
      final gift = provider.gifts.firstWhere((g) => g.id == _selectedGiftId);
      widget.onGiftSent?.call(gift);
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('送礼失败，金豆不足')),
        );
      }
    }

    if (mounted) setState(() => _sending = false);
  }
}
