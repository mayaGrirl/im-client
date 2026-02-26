/// 发布树洞页面
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/tree_hole_api.dart';
import 'package:im_client/api/upload_api.dart';
import 'package:im_client/l10n/app_localizations.dart';

class TreeHolePublishScreen extends StatefulWidget {
  const TreeHolePublishScreen({super.key});

  @override
  State<TreeHolePublishScreen> createState() => _TreeHolePublishScreenState();
}

class _TreeHolePublishScreenState extends State<TreeHolePublishScreen> {
  final TreeHoleApi _treeHoleApi = TreeHoleApi(ApiClient());
  final UploadApi _uploadApi = UploadApi(ApiClient());
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final List<_MediaItem> _mediaItems = [];
  final List<String> _tags = [];
  List<Map<String, dynamic>> _tagSuggestions = [];
  String? _selectedTopic;
  List<String> _topics = [];
  bool _isPublishing = false;
  double _uploadProgress = 0;
  String _uploadingText = '';

  static const int maxImages = 9;

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

  // 话题图标映射 (使用 i18n key)
  static const Map<String, IconData> _topicIcons = {
    'topic_daily': Icons.wb_sunny_outlined,
    'topic_emotion': Icons.favorite_border,
    'topic_work': Icons.work_outline,
    'topic_study': Icons.school_outlined,
    'topic_vent': Icons.sentiment_dissatisfied_outlined,
    'topic_help': Icons.help_outline,
    'topic_share': Icons.share_outlined,
    'topic_night': Icons.nightlight_outlined,
    'topic_career': Icons.business_center_outlined,
    'topic_campus': Icons.account_balance_outlined,
    'topic_crush': Icons.visibility_outlined,
    'topic_heartbreak': Icons.heart_broken_outlined,
    'topic_single': Icons.person_outline,
    'topic_relationship': Icons.people_outline,
    'topic_anxiety': Icons.psychology_outlined,
    'topic_pressure': Icons.compress_outlined,
    'topic_confused': Icons.explore_outlined,
    'topic_growth': Icons.trending_up_outlined,
    'topic_dream': Icons.star_outline,
    'topic_memory': Icons.photo_album_outlined,
    'topic_secret': Icons.lock_outline,
    'topic_family': Icons.home_outlined,
    'topic_friendship': Icons.group_outlined,
    'topic_gossip': Icons.chat_bubble_outline,
    'topic_fandom': Icons.star_border,
    'topic_game': Icons.sports_esports_outlined,
    'topic_food': Icons.restaurant_outlined,
    'topic_travel': Icons.flight_outlined,
    'topic_fitness': Icons.fitness_center_outlined,
    'topic_fashion': Icons.checkroom_outlined,
    'topic_music': Icons.music_note_outlined,
    'topic_movie': Icons.movie_outlined,
    'topic_reading': Icons.menu_book_outlined,
    'topic_other': Icons.more_horiz,
  };

  // 话题颜色映射 (使用 i18n key)
  static const Map<String, Color> _topicColors = {
    'topic_daily': Colors.orange,
    'topic_emotion': Colors.pink,
    'topic_work': Colors.blue,
    'topic_study': Colors.green,
    'topic_vent': Colors.red,
    'topic_help': Colors.purple,
    'topic_share': Colors.teal,
    'topic_night': Colors.indigo,
    'topic_career': Colors.blueGrey,
    'topic_campus': Colors.lightBlue,
    'topic_crush': Colors.pinkAccent,
    'topic_heartbreak': Colors.grey,
    'topic_single': Colors.amber,
    'topic_relationship': Colors.redAccent,
    'topic_anxiety': Colors.deepOrange,
    'topic_pressure': Colors.brown,
    'topic_confused': Colors.blueGrey,
    'topic_growth': Colors.lightGreen,
    'topic_dream': Colors.deepPurple,
    'topic_memory': Colors.cyan,
    'topic_secret': Colors.black87,
    'topic_family': Colors.lime,
    'topic_friendship': Colors.orangeAccent,
    'topic_gossip': Colors.pink,
    'topic_fandom': Colors.yellow,
    'topic_game': Colors.indigoAccent,
    'topic_food': Colors.deepOrangeAccent,
    'topic_travel': Colors.lightBlueAccent,
    'topic_fitness': Colors.greenAccent,
    'topic_fashion': Colors.purpleAccent,
    'topic_music': Colors.cyanAccent,
    'topic_movie': Colors.amberAccent,
    'topic_reading': Colors.brown,
    'topic_other': Colors.grey,
  };

  // 获取话题的 i18n key
  String _getTopicKey(String serverTopic) {
    return _topicKeyMap[serverTopic] ?? 'topic_other';
  }

  // 获取话题的本地化显示名称
  String _getTopicDisplayName(AppLocalizations l10n, String serverTopic) {
    final key = _getTopicKey(serverTopic);
    return l10n.translate(key);
  }

  // 获取话题图标
  IconData _getTopicIcon(String serverTopic) {
    final key = _getTopicKey(serverTopic);
    return _topicIcons[key] ?? Icons.tag;
  }

  // 获取话题颜色
  Color _getTopicColor(String serverTopic) {
    final key = _getTopicKey(serverTopic);
    return _topicColors[key] ?? Colors.grey;
  }

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    try {
      final response = await _treeHoleApi.getTopics();
      if (response.success && response.data != null) {
        setState(() {
          _topics = (response.data as List).map((e) => e.toString()).toList();
        });
      }
    } catch (e) {
      debugPrint('Load topics failed: $e');
    }
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.of(context)!;
    if (_mediaItems.length >= maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.maxImagesAllowed)),
      );
      return;
    }

    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        final remaining = maxImages - _mediaItems.length;
        final toAdd = images.take(remaining).toList();

        for (final image in toAdd) {
          final bytes = kIsWeb ? await image.readAsBytes() : null;
          setState(() {
            _mediaItems.add(_MediaItem(
              xFile: image,
              bytes: bytes,
            ));
          });
        }
      }
    } catch (e) {
      debugPrint('Pick images failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.selectImageFailed}: $e')),
        );
      }
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaItems.removeAt(index);
    });
  }

  Future<void> _publish() async {
    final l10n = AppLocalizations.of(context)!;
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterContent)),
      );
      return;
    }

    setState(() {
      _isPublishing = true;
      _uploadProgress = 0;
      _uploadingText = l10n.preparingPublish;
    });

    try {
      // 上传图片
      final List<String> imageUrls = [];
      final totalItems = _mediaItems.length;

      for (int i = 0; i < _mediaItems.length; i++) {
        final item = _mediaItems[i];
        setState(() {
          _uploadingText = l10n.uploadingImage;
          _uploadProgress = (i + 1) / (totalItems + 1);
        });

        UploadResult? result;
        if (kIsWeb) {
          result = await _uploadApi.uploadImage(
            item.bytes!.toList(),
            type: 'tree_hole',
            filename: item.xFile.name,
          );
        } else {
          result = await _uploadApi.uploadImage(
            File(item.xFile.path),
            type: 'tree_hole',
            filename: item.xFile.name,
          );
        }

        if (result != null && result.url.isNotEmpty) {
          imageUrls.add(result.url);
        }
      }

      setState(() {
        _uploadingText = l10n.publishing;
        _uploadProgress = 0.9;
      });

      // 发布树洞
      final response = await _treeHoleApi.createTreeHole(
        content: content,
        images: imageUrls,
        topic: _selectedTopic,
        tags: _tags.isNotEmpty ? _tags : null,
      );

      if (response.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.publishSuccess)),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message ?? l10n.publishFailed)),
          );
        }
      }
    } catch (e) {
      debugPrint('Publish failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.publishFailed}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(l10n.publishPost),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: ElevatedButton(
              onPressed: _isPublishing ? null : _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.teal.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
              ),
              child: _isPublishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(l10n.publish, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 匿名提示卡片
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.withOpacity(0.1), Colors.cyan.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.security, color: Colors.teal, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.publishAnonymously,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.teal,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.identityHidden,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 内容输入区
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _contentController,
                        maxLines: 8,
                        maxLength: 2000,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                        decoration: InputDecoration(
                          hintText: l10n.shareYourStory,
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          counterStyle: TextStyle(color: Colors.grey[400]),
                        ),
                      ),
                      // 图片预览区
                      if (_mediaItems.isNotEmpty) _buildImagePreview(l10n),
                      // 添加图片按钮
                      _buildAddImageButton(l10n),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 话题选择区
                _buildTopicSection(l10n),

                const SizedBox(height: 16),

                // 标签输入区
                _buildTagSection(l10n),

                const SizedBox(height: 100),
              ],
            ),
          ),

          // 上传进度遮罩
          if (_isPublishing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: _uploadProgress > 0 ? _uploadProgress : null,
                              strokeWidth: 4,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                            ),
                            if (_uploadProgress > 0)
                              Text(
                                '${(_uploadProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _uploadingText,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _mediaItems.length,
            itemBuilder: (context, index) {
              final item = _mediaItems[index];
              return _buildImageItem(item, index);
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.images}: ${_mediaItems.length}/$maxImages',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildImageItem(_MediaItem item, int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: kIsWeb
                ? Image.memory(
                    item.bytes!,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    File(item.xFile.path),
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeMedia(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddImageButton(AppLocalizations l10n) {
    if (_mediaItems.length >= maxImages) return const SizedBox();

    return InkWell(
      onTap: _pickImages,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_photo_alternate, color: Colors.teal, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.addImages,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Text(
              '${_mediaItems.length}/$maxImages',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicSection(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.tag, size: 20, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  l10n.selectTopic,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_selectedTopic != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedTopic = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.clear,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.close, size: 14, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 已选话题显示
          if (_selectedTopic != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getTopicColor(_selectedTopic!).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getTopicColor(_selectedTopic!).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getTopicIcon(_selectedTopic!),
                    size: 18,
                    color: _getTopicColor(_selectedTopic!),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '#${_getTopicDisplayName(l10n, _selectedTopic!)}',
                    style: TextStyle(
                      color: _getTopicColor(_selectedTopic!),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // 话题网格
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _topics.map((topic) {
                final isSelected = topic == _selectedTopic;
                final color = _getTopicColor(topic);
                final displayName = _getTopicDisplayName(l10n, topic);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTopic = isSelected ? null : topic;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.15) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? color.withOpacity(0.5) : Colors.grey[200]!,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTopicIcon(topic),
                          size: 16,
                          color: isSelected ? color : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? color : Colors.grey[700],
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _addTag(String tagName) {
    tagName = tagName.trim().replaceAll('#', '');
    if (tagName.isEmpty || tagName.length > 20) return;
    if (_tags.length >= 10) return;
    if (_tags.contains(tagName)) return;
    setState(() {
      _tags.add(tagName);
      _tagController.clear();
      _tagSuggestions = [];
    });
  }

  void _removeTag(int index) {
    setState(() {
      _tags.removeAt(index);
    });
  }

  Future<void> _searchTags(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() => _tagSuggestions = []);
      return;
    }
    try {
      final response = await _treeHoleApi.searchTags(keyword.trim());
      if (response.success && response.data != null) {
        setState(() {
          _tagSuggestions = (response.data as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Search tags failed: $e');
    }
  }

  Widget _buildTagSection(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.label_outline, size: 20, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  l10n.translate('custom_tags'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_tags.length}/10',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          // 已添加标签
          if (_tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_tags.length, (index) {
                  return Chip(
                    label: Text('#${_tags[index]}', style: const TextStyle(fontSize: 13)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removeTag(index),
                    backgroundColor: Colors.teal.withOpacity(0.1),
                    deleteIconColor: Colors.teal,
                    labelStyle: const TextStyle(color: Colors.teal),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }),
              ),
            ),
          // 标签输入
          if (_tags.length < 10)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagController,
                          decoration: InputDecoration(
                            hintText: l10n.translate('enter_tag'),
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: Colors.teal),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            isDense: true,
                            prefixText: '# ',
                            prefixStyle: const TextStyle(color: Colors.teal),
                          ),
                          maxLength: 20,
                          buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
                          onChanged: _searchTags,
                          onSubmitted: _addTag,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _addTag(_tagController.text),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  // 搜索建议
                  if (_tagSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _tagSuggestions.length,
                        itemBuilder: (context, index) {
                          final tag = _tagSuggestions[index];
                          return ListTile(
                            dense: true,
                            title: Text('#${tag['name']}', style: const TextStyle(fontSize: 14)),
                            trailing: Text(
                              '${tag['use_count'] ?? 0}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                            onTap: () => _addTag(tag['name'].toString()),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaItem {
  final XFile xFile;
  final Uint8List? bytes;

  _MediaItem({
    required this.xFile,
    this.bytes,
  });
}
