/// 群分享页面
/// 用于分享群组和通过分享码加入群组

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/models/group.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/l10n/app_localizations.dart';
import '../../utils/image_proxy.dart';

/// 群分享页面 - 创建分享链接
class GroupShareScreen extends StatefulWidget {
  final Group group;

  const GroupShareScreen({super.key, required this.group});

  @override
  State<GroupShareScreen> createState() => _GroupShareScreenState();
}

class _GroupShareScreenState extends State<GroupShareScreen> {
  final GroupApi _groupApi = GroupApi(ApiClient());

  int _expireDays = 7;
  int _maxUses = 0;
  ShareLinkResult? _shareLink;
  bool _isLoading = false;
  List<ShareLinkResult> _existingLinks = [];

  @override
  void initState() {
    super.initState();
    _loadExistingLinks();
  }

  Future<void> _loadExistingLinks() async {
    final links = await _groupApi.getMyShareLinks(widget.group.id);
    setState(() {
      _existingLinks = links;
    });
  }

  /// 获取完整URL（处理相对路径）
  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    // 防止只有 / 的情况
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

  Future<void> _createShareLink() async {
    setState(() => _isLoading = true);

    final result = await _groupApi.createShareLink(
      widget.group.id,
      expireDays: _expireDays,
      maxUses: _maxUses,
    );

    setState(() {
      _isLoading = false;
      if (result != null) {
        _shareLink = result;
        _existingLinks.insert(0, result);
      }
    });

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.shareLinkCreated)),
      );
    }
  }

  void _copyShareCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.shareCodeCopied)),
    );
  }

  Future<void> _revokeLink(ShareLinkResult link) async {
    if (link.id == null) return;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.revokeShareLink),
        content: Text(l10n.revokeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.revoke),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _groupApi.revokeShareLink(widget.group.id, link.id!);
      if (result.success) {
        setState(() {
          _existingLinks.removeWhere((l) => l.id == link.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.linkRevoked)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shareGroup),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 群组信息卡片
            _buildGroupInfoCard(l10n),
            const SizedBox(height: 24),

            // 创建分享链接
            _buildCreateShareSection(l10n),
            const SizedBox(height: 24),

            // 已创建的链接列表
            if (_existingLinks.isNotEmpty) ...[
              Text(
                l10n.myShareLinks,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildExistingLinksList(l10n),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupInfoCard(AppLocalizations l10n) {
    final avatarUrl = _getFullUrl(widget.group.avatar);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl.proxied)
                  : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      widget.group.name[0],
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.group.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.groupNumber}: ${widget.group.groupNo}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${widget.group.memberCount} ${l10n.people}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateShareSection(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.createShareLink,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 过期时间选择
            Row(
              children: [
                Text('${l10n.validity}: '),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _expireDays,
                  items: [
                    const DropdownMenuItem(value: 1, child: Text('1')),
                    const DropdownMenuItem(value: 3, child: Text('3')),
                    const DropdownMenuItem(value: 7, child: Text('7')),
                    const DropdownMenuItem(value: 30, child: Text('30')),
                    DropdownMenuItem(value: 0, child: Text(l10n.neverExpire)),
                  ],
                  onChanged: (value) {
                    setState(() => _expireDays = value ?? 7);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 使用次数限制
            Row(
              children: [
                Text('${l10n.usageLimit}: '),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _maxUses,
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l10n.unlimited)),
                    const DropdownMenuItem(value: 1, child: Text('1')),
                    const DropdownMenuItem(value: 10, child: Text('10')),
                    const DropdownMenuItem(value: 50, child: Text('50')),
                    const DropdownMenuItem(value: 100, child: Text('100')),
                  ],
                  onChanged: (value) {
                    setState(() => _maxUses = value ?? 0);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 创建按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createShareLink,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.generateShareLink),
              ),
            ),

            // 显示新创建的分享码
            if (_shareLink != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l10n.shareCode}:',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          Text(
                            _shareLink!.shareCode,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyShareCode(_shareLink!.shareCode),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExistingLinksList(AppLocalizations l10n) {
    return Column(
      children: _existingLinks.map((link) {
        return Card(
          child: ListTile(
            title: Text(
              link.shareCode,
              style: const TextStyle(
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
            ),
            subtitle: Text(
              '${link.expireAt != null ? "${l10n.validUntil}: ${_formatDate(link.expireAt!)}" : l10n.neverExpire} | '
              '${link.maxUses > 0 ? "${link.usedCount}/${link.maxUses}" : l10n.unlimitedTimes}',
              style: TextStyle(
                color: link.isValid ? AppColors.textSecondary : AppColors.error,
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _copyShareCode(link.shareCode),
                ),
                if (link.isValid)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: AppColors.error),
                    onPressed: () => _revokeLink(link),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}

/// 通过分享码加入群组页面
class JoinGroupByCodeScreen extends StatefulWidget {
  final String? initialCode;

  const JoinGroupByCodeScreen({super.key, this.initialCode});

  @override
  State<JoinGroupByCodeScreen> createState() => _JoinGroupByCodeScreenState();
}

class _JoinGroupByCodeScreenState extends State<JoinGroupByCodeScreen> {
  final GroupApi _groupApi = GroupApi(ApiClient());
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();

  Group? _group;
  bool _isLoading = false;
  bool _isJoining = false;
  String? _error;
  String? _question;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
      _searchGroup();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _messageController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  /// 获取完整URL（处理相对路径）
  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    // 防止只有 / 的情况
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

  Future<void> _searchGroup() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _error = AppLocalizations.of(context)!.enterShareCode;
        _group = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _question = null;
    });

    final group = await _groupApi.getGroupByShareCode(code);

    setState(() {
      _isLoading = false;
      _group = group;
      if (group == null) {
        _error = AppLocalizations.of(context)!.shareCodeInvalid;
      }
    });
  }

  Future<void> _joinGroup() async {
    if (_group == null) return;

    setState(() {
      _isJoining = true;
      _error = null;
    });

    final result = await _groupApi.joinGroupByShareCode(
      _codeController.text.trim(),
      message: _messageController.text.trim(),
      answer: _answerController.text.trim(),
    );

    setState(() {
      _isJoining = false;
    });

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? AppLocalizations.of(context)!.operationSuccess)),
      );
      if (result.message?.contains('joined') == true || result.message?.contains('已加入') == true) {
        Navigator.pop(context, true);
      }
    } else {
      // 检查是否需要回答问题
      if (result.data != null && result.data['need_answer'] == true) {
        setState(() {
          _question = result.data['question'];
        });
      } else {
        setState(() {
          _error = result.message ?? 'Failed to join';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.joinGroup),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 输入分享码
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: l10n.shareCode,
                hintText: l10n.enterShareCode,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _isLoading ? null : _searchGroup,
                ),
              ),
              onSubmitted: (_) => _searchGroup(),
            ),
            const SizedBox(height: 16),

            // 错误信息
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),

            // 加载中
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),

            // 群组信息
            if (_group != null) ...[
              const SizedBox(height: 16),
              _buildGroupInfoCard(l10n),
              const SizedBox(height: 16),

              // 需要回答问题
              if (_question != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.answerQuestion,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _question!,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _answerController,
                          decoration: InputDecoration(
                            labelText: l10n.yourAnswer,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 需要审核时显示申请消息输入框
              if (_group!.needVerify) ...[
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.applicationMessage,
                    hintText: l10n.applicationReason,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 加入按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isJoining ? null : _joinGroup,
                  child: _isJoining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_group!.needVerify ? l10n.applyJoin : l10n.joinGroup),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupInfoCard(AppLocalizations l10n) {
    final avatarUrl = _getFullUrl(_group!.avatar);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl.proxied)
                  : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      _group!.name[0],
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _group!.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_group!.description != null && _group!.description!.isNotEmpty)
                    Text(
                      _group!.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${_group!.memberCount} ${l10n.people}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getJoinModeColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _group!.joinModeText,
                          style: TextStyle(
                            color: _getJoinModeColor(),
                            fontSize: 11,
                          ),
                        ),
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
  }

  Color _getJoinModeColor() {
    switch (_group?.joinMode) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return AppColors.error;
      case 4:
        return Colors.purple;
      case 5:
        return Colors.blue;
      default:
        return AppColors.textSecondary;
    }
  }
}
