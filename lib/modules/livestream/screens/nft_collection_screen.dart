/// NFT收藏页面
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/modules/livestream/models/livestream.dart';
import 'package:im_client/modules/livestream/providers/livestream_provider.dart';
import 'package:im_client/modules/livestream/screens/nft_detail_screen.dart';

class NFTCollectionScreen extends StatefulWidget {
  const NFTCollectionScreen({super.key});

  @override
  State<NFTCollectionScreen> createState() => _NFTCollectionScreenState();
}

class _NFTCollectionScreenState extends State<NFTCollectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LivestreamProvider>().loadNFTCollection();
    });
  }

  Color _rarityColor(int rarity) {
    switch (rarity) {
      case 1: return Colors.grey;
      case 2: return Colors.blue;
      case 3: return Colors.purple;
      case 4: return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的NFT收藏')),
      body: Consumer<LivestreamProvider>(
        builder: (context, provider, _) {
          if (provider.nftCollection.isEmpty) {
            return const Center(child: Text('暂无NFT收藏'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: provider.nftCollection.length,
            itemBuilder: (context, index) {
              final nft = provider.nftCollection[index];
              return _buildNFTCard(nft);
            },
          );
        },
      ),
    );
  }

  Widget _buildNFTCard(LivestreamNFTGift nft) {
    final rarityColor = _rarityColor(nft.rarity);
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => NFTDetailScreen(nftId: nft.id),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rarityColor, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 稀有度标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: rarityColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                nft.rarityText,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            // 礼物图标
            if (nft.gift != null && nft.gift!.icon.isNotEmpty)
              Image.network(EnvConfig.instance.getFileUrl(nft.gift!.icon), width: 64, height: 64, errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, size: 64, color: Colors.amber))
            else
              const Icon(Icons.card_giftcard, size: 64, color: Colors.amber),
            const SizedBox(height: 8),
            // 名称
            Text(
              nft.gift?.name ?? 'NFT #${nft.id}',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // 编号
            Text(
              '#${nft.serialNumber}/${nft.totalSupply}',
              style: TextStyle(color: rarityColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            // 转让次数
            Text(
              '转让 ${nft.transferCount} �?,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
