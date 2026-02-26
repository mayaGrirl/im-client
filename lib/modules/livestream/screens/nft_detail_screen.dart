/// NFT详情页面
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/modules/livestream/models/livestream.dart';
import 'package:im_client/modules/livestream/providers/livestream_provider.dart';

class NFTDetailScreen extends StatefulWidget {
  final int nftId;

  const NFTDetailScreen({super.key, required this.nftId});

  @override
  State<NFTDetailScreen> createState() => _NFTDetailScreenState();
}

class _NFTDetailScreenState extends State<NFTDetailScreen> {
  LivestreamNFTGift? _nft;
  List<LivestreamNFTTransfer> _transfers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<LivestreamProvider>();
    final data = await provider.getNFTDetail(widget.nftId);
    if (data != null && mounted) {
      setState(() {
        _nft = LivestreamNFTGift.fromJson(data['nft']);
        _transfers = (data['transfers'] as List? ?? [])
            .map((e) => LivestreamNFTTransfer.fromJson(e))
            .toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
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
      appBar: AppBar(title: const Text('NFT详情')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _nft == null
              ? const Center(child: Text('NFT不存))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 大图
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: _rarityColor(_nft!.rarity), width: 3),
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.grey.shade900,
                        ),
                        child: _nft!.gift != null && _nft!.gift!.icon.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.network(EnvConfig.instance.getFileUrl(_nft!.gift!.icon), fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, size: 64, color: Colors.amber)),
                              )
                            : const Icon(Icons.card_giftcard, size: 64, color: Colors.amber),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _nft!.gift?.name ?? 'NFT',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // 稀有度 + 编号
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _rarityColor(_nft!.rarity),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _nft!.rarityText,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '#${_nft!.serialNumber} / ${_nft!.totalSupply}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _rarityColor(_nft!.rarity)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // 信息卡片
                      _buildInfoCard(),
                      const SizedBox(height: 24),
                      // 转移记录
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('转移记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      if (_transfers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(AppLocalizations.of(context)!.translate('nft_no_transfers'), style: const TextStyle(color: Colors.grey)),
                        )
                      else
                        ..._transfers.map((t) => _buildTransferItem(t)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard() {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(l10n.translate('nft_mint_time'), _nft!.mintTime.isNotEmpty ? _nft!.mintTime.substring(0, 10) : '-'),
            _infoRow(l10n.translate('nft_owner'), _nft!.owner?.nickname ?? '${l10n.translate('user_prefix')}${_nft!.ownerId}'),
            _infoRow(l10n.translate('nft_transfer_count'), l10n.translate('nft_times_count').replaceAll('{count}', '${_nft!.transferCount}')),
            _infoRow(l10n.translate('nft_tradeable'), _nft!.isTradeable ? '是' : '否'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getTransferTypeText(int type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case 1: return l10n.translate('nft_transfer_mint');
      case 2: return l10n.translate('nft_transfer_gift');
      case 3: return l10n.translate('nft_transfer_trade');
      default: return l10n.translate('unknown');
    }
  }

  Widget _buildTransferItem(LivestreamNFTTransfer transfer) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      dense: true,
      leading: Icon(
        transfer.transferType == 1 ? Icons.auto_awesome : transfer.transferType == 2 ? Icons.card_giftcard : Icons.swap_horiz,
        color: transfer.transferType == 1 ? Colors.amber : transfer.transferType == 3 ? Colors.green : Colors.blue,
      ),
      title: Text(_getTransferTypeText(transfer.transferType)),
      subtitle: Text(
        '${transfer.fromUser?.nickname ?? (transfer.fromUserId == 0 ? l10n.translate('system') : "${l10n.translate('user_prefix')}${transfer.fromUserId}")} �?${transfer.toUser?.nickname ?? "${l10n.translate('user_prefix')}${transfer.toUserId}"}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: transfer.price > 0 ? Text(l10n.translate('gold_beans_value').replaceAll('{amount}', '${transfer.price}'), style: const TextStyle(color: Colors.amber, fontSize: 12)) : null,
    );
  }
}
