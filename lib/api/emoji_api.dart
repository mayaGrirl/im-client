/// 表情相关API
import 'package:im_client/api/api_client.dart';

/// 表情API
class EmojiApi {
  final ApiClient _client = ApiClient();

  /// 获取系统表情列表
  Future<List<EmojiItem>> getSystemEmojis() async {
    final response = await _client.get('/emoji/system');
    if (response.success && response.data != null) {
      final list = response.data as List;
      return list.map((e) => EmojiItem.fromJson(e)).toList();
    }
    return [];
  }

  /// 获取表情包列表
  Future<List<EmojiPack>> getEmojiPacks() async {
    final response = await _client.get('/emoji/packs');
    if (response.success && response.data != null) {
      final list = response.data as List;
      return list.map((e) => EmojiPack.fromJson(e)).toList();
    }
    return [];
  }

  /// 获取表情包详情
  Future<EmojiPack?> getEmojiPackDetail(int packId) async {
    final response = await _client.get('/emoji/pack/$packId');
    if (response.success && response.data != null) {
      return EmojiPack.fromJson(response.data);
    }
    return null;
  }

  /// 获取我收藏的表情
  Future<List<EmojiItem>> getMyEmojis() async {
    final response = await _client.get('/emoji/mine');
    if (response.success && response.data != null) {
      final list = response.data as List;
      return list.map((e) => EmojiItem.fromJson(e)).toList();
    }
    return [];
  }

  /// 收藏表情
  Future<bool> addEmoji({
    required String url,
    String? name,
    String? sourceMsgId,
  }) async {
    final response = await _client.post('/emoji/add', data: {
      'url': url,
      if (name != null) 'name': name,
      if (sourceMsgId != null) 'source_msg_id': sourceMsgId,
    });
    return response.success;
  }

  /// 删除收藏的表情
  Future<bool> deleteEmoji(int id) async {
    final response = await _client.delete('/emoji/$id');
    return response.success;
  }

  /// 获取我的表情包
  Future<List<EmojiPack>> getMyEmojiPacks() async {
    final response = await _client.get('/emoji/my-packs');
    if (response.success && response.data != null) {
      final list = response.data as List;
      return list.map((e) => EmojiPack.fromJson(e)).toList();
    }
    return [];
  }

  /// 添加表情包
  Future<bool> addEmojiPack(int packId) async {
    final response = await _client.post('/emoji/pack/$packId/add');
    return response.success;
  }

  /// 移除表情包
  Future<bool> removeEmojiPack(int packId) async {
    final response = await _client.delete('/emoji/pack/$packId');
    return response.success;
  }
}

/// 表情项
class EmojiItem {
  final int id;
  final String name;
  final int type; // 1=系统 2=自定义 3=贴纸
  final String url;
  final int? packId;
  final int sort;

  EmojiItem({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    this.packId,
    this.sort = 0,
  });

  factory EmojiItem.fromJson(Map<String, dynamic> json) {
    return EmojiItem(
      id: json['id'] ?? json['ID'] ?? 0,
      name: json['name'] ?? json['Name'] ?? '',
      type: json['type'] ?? json['Type'] ?? 1,
      url: json['url'] ?? json['URL'] ?? '',
      packId: json['pack_id'] ?? json['PackID'],
      sort: json['sort'] ?? json['Sort'] ?? 0,
    );
  }
}

/// 表情包
class EmojiPack {
  final int id;
  final String name;
  final String cover;
  final String? description;
  final String? author;
  final int price;
  final int downloadCount;
  final List<EmojiItem> emojis;

  EmojiPack({
    required this.id,
    required this.name,
    required this.cover,
    this.description,
    this.author,
    this.price = 0,
    this.downloadCount = 0,
    this.emojis = const [],
  });

  factory EmojiPack.fromJson(Map<String, dynamic> json) {
    List<EmojiItem> emojiList = [];
    final emojisData = json['emojis'] ?? json['Emojis'];
    if (emojisData != null && emojisData is List) {
      emojiList = emojisData.map<EmojiItem>((e) => EmojiItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    print('[EmojiPack.fromJson] id=${json['id']}, name=${json['name']}, emojis count=${emojiList.length}');
    return EmojiPack(
      id: json['id'] ?? json['ID'] ?? 0,
      name: json['name'] ?? json['Name'] ?? '',
      cover: json['cover'] ?? json['Cover'] ?? '',
      description: json['description'] ?? json['Description'],
      author: json['author'] ?? json['Author'],
      price: json['price'] ?? json['Price'] ?? 0,
      downloadCount: json['download_count'] ?? json['DownloadCount'] ?? 0,
      emojis: emojiList,
    );
  }
}
