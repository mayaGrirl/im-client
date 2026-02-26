/// 帮助中心页面
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _categories = [];
  List<dynamic> _hotArticles = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiClient.get('/help/categories'),
        _apiClient.get('/help/articles/hot', queryParameters: {'limit': 5}),
      ]);

      if (results[0].success) {
        setState(() {
          _categories = results[0].data as List<dynamic>? ?? [];
        });
      }
      if (results[1].success) {
        setState(() {
          _hotArticles = results[1].data as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('load_fail')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _search() {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HelpSearchResultScreen(keyword: keyword),
      ),
    );
  }

  IconData _getCategoryIcon(String? iconName) {
    switch (iconName) {
      case 'school':
        return Icons.school;
      case 'person':
        return Icons.person;
      case 'chat':
        return Icons.chat;
      case 'contacts':
        return Icons.contacts;
      case 'security':
        return Icons.security;
      case 'help':
        return Icons.help;
      default:
        return Icons.folder;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.helpCenter),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                children: [
                  // 搜索框
                  Container(
                    color: AppColors.white,
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: l10n.searchProblems,
                        prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward, color: AppColors.primary),
                          onPressed: _search,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 热门问题
                  if (_hotArticles.isNotEmpty) ...[
                    _buildSectionHeader(l10n.translate('hot_questions')),
                    Container(
                      color: AppColors.white,
                      child: Column(
                        children: _hotArticles.map((article) {
                          return _buildArticleItem(article);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 帮助分类
                  _buildSectionHeader(l10n.helpCategories),
                  Container(
                    color: AppColors.white,
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return _buildCategoryItem(category);
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 联系客服入口
                  Container(
                    color: AppColors.white,
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.headset_mic, color: AppColors.primary),
                      ),
                      title: Text(l10n.translate('contact_support')),
                      subtitle: Text(l10n.translate('contact_support_hint'), style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                      onTap: () {
                        // TODO: 跳转客服页面
                        Navigator.pop(context);
                      },
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildCategoryItem(dynamic category) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HelpCategoryScreen(
              categoryId: category['id'] as int,
              categoryName: category['name'] as String? ?? '',
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(category['icon'] as String?),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category['name'] as String? ?? '',
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleItem(dynamic article) {
    return ListTile(
      leading: const Icon(Icons.article_outlined, color: AppColors.primary),
      title: Text(
        article['title'] as String? ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HelpArticleScreen(articleId: article['id'] as int),
          ),
        );
      },
    );
  }
}

/// 帮助分类文章列表
class HelpCategoryScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const HelpCategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<HelpCategoryScreen> createState() => _HelpCategoryScreenState();
}

class _HelpCategoryScreenState extends State<HelpCategoryScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _articles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.get('/help/categories/${widget.categoryId}/articles');
      if (res.success) {
        final data = res.data as Map<String, dynamic>?;
        setState(() {
          _articles = data?['list'] as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('load_fail')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.article_outlined, size: 64, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      Text(l10n.noArticles, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _articles.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final article = _articles[index];
                    return Container(
                      color: AppColors.white,
                      child: ListTile(
                        title: Text(article['title'] as String? ?? ''),
                        subtitle: article['summary'] != null
                            ? Text(
                                article['summary'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                              )
                            : null,
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HelpArticleScreen(articleId: article['id'] as int),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

/// 帮助文章详情
class HelpArticleScreen extends StatefulWidget {
  final int articleId;

  const HelpArticleScreen({super.key, required this.articleId});

  @override
  State<HelpArticleScreen> createState() => _HelpArticleScreenState();
}

class _HelpArticleScreenState extends State<HelpArticleScreen> {
  final ApiClient _apiClient = ApiClient();
  Map<String, dynamic>? _article;
  bool _isLoading = true;
  bool _hasLiked = false;

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  Future<void> _loadArticle() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.get('/help/articles/${widget.articleId}');
      if (res.success) {
        setState(() {
          _article = res.data as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('load_fail')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _likeArticle() async {
    if (_hasLiked) return;

    try {
      final res = await _apiClient.post('/help/articles/${widget.articleId}/like');
      if (res.success) {
        setState(() {
          _hasLiked = true;
          if (_article != null) {
            _article!['like_count'] = (_article!['like_count'] ?? 0) + 1;
          }
        });
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('thanks_feedback')), duration: const Duration(seconds: 1)),
          );
        }
      }
    } catch (e) {
      // 静默失败
    }
  }

  Future<void> _submitFeedback(String type) async {
    final l10n = AppLocalizations.of(context)!;
    String? content;
    if (type == 'question') {
      content = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            title: Text(l10n.translate('submit_question')),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.translate('describe_your_problem'),
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: Text(l10n.translate('submit')),
              ),
            ],
          );
        },
      );

      if (content == null || content.isEmpty) return;
    }

    try {
      await _apiClient.post('/help/feedback', data: {
        'article_id': widget.articleId,
        'type': type,
        'content': content ?? '',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('thanks_feedback'))),
        );
      }
    } catch (e) {
      // 静默失败
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(l10n.translate('help_detail')),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _article == null
              ? Center(child: Text(l10n.translate('article_not_exist')))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 标题
                            Text(
                              _article!['title'] as String? ?? '',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 信息
                            Row(
                              children: [
                                Text(
                                  l10n.translate('view_count').replaceAll('{count}', '${_article!['view_count'] ?? 0}'),
                                  style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  l10n.translate('like_count').replaceAll('{count}', '${_article!['like_count'] ?? 0}'),
                                  style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            // 内容 (Markdown)
                            MarkdownBody(
                              data: _article!['content'] as String? ?? '',
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(fontSize: 15, height: 1.8),
                                h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 底部反馈
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            l10n.translate('article_help_question'),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _hasLiked ? null : _likeArticle,
                                icon: Icon(
                                  _hasLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                  size: 18,
                                ),
                                label: Text(l10n.translate('helpful')),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _hasLiked ? Colors.green : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                onPressed: () => _submitFeedback('not_helpful'),
                                icon: const Icon(Icons.thumb_down_outlined, size: 18),
                                label: Text(l10n.translate('not_helpful')),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                onPressed: () => _submitFeedback('question'),
                                icon: const Icon(Icons.help_outline, size: 18),
                                label: Text(l10n.translate('have_question')),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// 搜索结果页面
class HelpSearchResultScreen extends StatefulWidget {
  final String keyword;

  const HelpSearchResultScreen({super.key, required this.keyword});

  @override
  State<HelpSearchResultScreen> createState() => _HelpSearchResultScreenState();
}

class _HelpSearchResultScreenState extends State<HelpSearchResultScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _results = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.get('/help/search', queryParameters: {
        'keyword': widget.keyword,
      });
      if (res.success) {
        final data = res.data as Map<String, dynamic>?;
        setState(() {
          _results = data?['list'] as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('search_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${l10n.search}: ${widget.keyword}'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 64, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      Text(l10n.translate('no_search_results').replaceAll('{keyword}', widget.keyword), style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final article = _results[index];
                    return Container(
                      color: AppColors.white,
                      child: ListTile(
                        title: Text(article['title'] as String? ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (article['summary'] != null)
                              Text(
                                article['summary'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                              ),
                            if (article['category'] != null)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  article['category']['name'] as String? ?? '',
                                  style: TextStyle(color: AppColors.primary, fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HelpArticleScreen(articleId: article['id'] as int),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
