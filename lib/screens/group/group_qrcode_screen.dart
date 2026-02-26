/// 群二维码页面
/// 显示群二维码，支持保存和分享图片

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/conversation_api.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/api/upload_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/models/group.dart';
import 'package:im_client/models/message.dart';
import 'package:im_client/models/user.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:im_client/l10n/app_localizations.dart';
// 条件导入：移动端使用 image_gallery_saver
import 'package:im_client/utils/image_saver_stub.dart'
    if (dart.library.io) 'package:im_client/utils/image_saver_mobile.dart'
    if (dart.library.html) 'package:im_client/utils/image_saver_web.dart';
import '../../utils/image_proxy.dart';

class GroupQRCodeScreen extends StatefulWidget {
  final int groupId;
  final bool allowQrcodeJoin;

  const GroupQRCodeScreen({
    super.key,
    required this.groupId,
    this.allowQrcodeJoin = true,
  });

  @override
  State<GroupQRCodeScreen> createState() => _GroupQRCodeScreenState();
}

class _GroupQRCodeScreenState extends State<GroupQRCodeScreen> {
  final GroupApi _groupApi = GroupApi(ApiClient());
  final GlobalKey _qrKey = GlobalKey();

  GroupQRCode? _qrCode;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadQRCode();
  }

  Future<void> _loadQRCode() async {
    setState(() => _isLoading = true);
    final qrCode = await _groupApi.getGroupQRCode(widget.groupId);
    setState(() {
      _qrCode = qrCode;
      _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.groupQrcode),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _qrCode == null
              ? _buildError(l10n)
              : _buildQRCodeCard(l10n),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.getQrcodeFailed,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadQRCode,
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeCard(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          children: [
            // 二维码卡片（用于截图）
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 群头像和名称
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Builder(builder: (context) {
                          final avatarUrl = _getFullUrl(_qrCode!.avatar ?? '');
                          return CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            backgroundImage: avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl.proxied)
                                : null,
                            child: avatarUrl.isEmpty
                              ? Text(
                                  _qrCode!.groupName.isNotEmpty
                                      ? _qrCode!.groupName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                          );
                        }),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _qrCode!.groupName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 二维码
                    Builder(builder: (context) {
                      final groupAvatarUrl = _getFullUrl(_qrCode!.avatar ?? '');
                      final hasGroupAvatar = groupAvatarUrl.isNotEmpty;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: QrImageView(
                          data: 'group:${_qrCode!.code}',
                          version: QrVersions.auto,
                          size: 200,
                          gapless: false,
                          // 如果群组有头像，在二维码中心显示头像
                          embeddedImage: hasGroupAvatar ? NetworkImage(groupAvatarUrl.proxied) : null,
                          embeddedImageStyle: hasGroupAvatar
                              ? const QrEmbeddedImageStyle(
                                  size: Size(40, 40),
                                )
                              : null,
                          errorStateBuilder: (ctx, err) => Center(
                            child: Text(l10n.generateQrcodeFailed),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    // 提示文字
                    Text(
                      _qrCode!.joinMode == 1 ? l10n.scanToJoin : l10n.scanToApply,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 过期时间
                    if (_qrCode!.expireAt != null)
                      Text(
                        '${l10n.validUntil} ${_formatDate(_qrCode!.expireAt!)}',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 扫码加入已关闭提示
            if (!widget.allowQrcodeJoin)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.qrcodeDisabledSaveShare,
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (!widget.allowQrcodeJoin) const SizedBox(height: 16),

            // 操作按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.allowQrcodeJoin
                          ? (_isSaving ? null : _saveQRCode)
                          : null,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_alt, size: 18),
                      label: Text(l10n.saveImage),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.allowQrcodeJoin ? _shareQRCode : null,
                      icon: const Icon(Icons.share, size: 18),
                      label: Text(l10n.shareImage),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 截取二维码图片
  Future<Uint8List?> _captureQRCode() async {
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('[GroupQRCode] Screenshot failed: $e');
      return null;
    }
  }

  /// 保存二维码图片到相册/下载
  Future<void> _saveQRCode() async {
    setState(() => _isSaving = true);

    final l10n = AppLocalizations.of(context)!;
    try {
      final bytes = await _captureQRCode();
      if (bytes == null) {
        _showError(l10n.generateImageFailed);
        return;
      }

      // 使用平台特定的保存方法
      final result = await saveImageToGallery(
        bytes.toList(),
        name: 'group_qrcode_${DateTime.now().millisecondsSinceEpoch}',
        quality: 100,
      );

      if (result['isSuccess'] == true) {
        _showSuccess(kIsWeb ? l10n.imageDownloading : l10n.imageSaved);
      } else {
        _showError(l10n.saveFailedCheckPermission);
      }
    } catch (e) {
      _showError('${l10n.saveFailed}: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// 分享二维码图片给好友或群聊
  void _shareQRCode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ShareQRCodeTargetScreen(
          groupName: _qrCode!.groupName,
          captureQRCode: _captureQRCode,
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}

/// 分享二维码目标选择页面
class _ShareQRCodeTargetScreen extends StatefulWidget {
  final String groupName;
  final Future<Uint8List?> Function() captureQRCode;

  const _ShareQRCodeTargetScreen({
    required this.groupName,
    required this.captureQRCode,
  });

  @override
  State<_ShareQRCodeTargetScreen> createState() => _ShareQRCodeTargetScreenState();
}

class _ShareQRCodeTargetScreenState extends State<_ShareQRCodeTargetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendApi _friendApi = FriendApi(ApiClient());
  final GroupApi _groupApi = GroupApi(ApiClient());
  final UploadApi _uploadApi = UploadApi(ApiClient());
  final ConversationApi _conversationApi = ConversationApi(ApiClient());

  List<Friend> _friends = [];
  List<Group> _groups = [];
  bool _isLoading = true;
  bool _isSharing = false;

  // 选中的目标
  final Set<int> _selectedUserIds = {};
  final Set<int> _selectedGroupIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _friendApi.getFriendList(),
        _groupApi.getMyGroups(),
      ]);
      setState(() {
        _friends = results[0] as List<Friend>;
        _groups = results[1] as List<Group>;
      });
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.loadFailed}: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedCount = _selectedUserIds.length + _selectedGroupIds.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shareTo),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.friends),
            Tab(text: l10n.groups),
          ],
        ),
      ),
      body: Column(
        children: [
          // 已选择的目标预览
          if (selectedCount > 0) _buildSelectedPreview(l10n),
          // 列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFriendList(),
                      _buildGroupList(),
                    ],
                  ),
          ),
          // 底部确认按钮
          _buildBottomBar(selectedCount, l10n),
        ],
      ),
    );
  }

  /// 构建已选择目标预览
  Widget _buildSelectedPreview(AppLocalizations l10n) {
    final selectedItems = <Widget>[];

    // 添加选中的好友
    for (final userId in _selectedUserIds) {
      final friend = _friends.firstWhere(
        (f) => f.friendId == userId,
        orElse: () => _friends.first,
      );
      if (_friends.any((f) => f.friendId == userId)) {
        selectedItems.add(_buildSelectedChip(
          friend.displayName,
          friend.friend.avatar,
          () => _toggleUserSelection(userId),
        ));
      }
    }

    // 添加选中的群组
    for (final groupId in _selectedGroupIds) {
      final group = _groups.firstWhere(
        (g) => g.id == groupId,
        orElse: () => _groups.first,
      );
      if (_groups.any((g) => g.id == groupId)) {
        selectedItems.add(_buildSelectedChip(
          group.name,
          group.avatar,
          () => _toggleGroupSelection(groupId),
          isGroup: true,
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.selectedCountFormat(_selectedUserIds.length + _selectedGroupIds.length),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedItems,
          ),
        ],
      ),
    );
  }

  /// 构建已选择的标签
  Widget _buildSelectedChip(String name, String avatar, VoidCallback onRemove, {bool isGroup = false}) {
    final avatarUrl = _getFullUrl(avatar);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: isGroup
                ? AppColors.secondary.withOpacity(0.1)
                : AppColors.primary.withOpacity(0.1),
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
            child: avatarUrl.isEmpty
                ? Icon(
                    isGroup ? Icons.group : Icons.person,
                    size: 12,
                    color: isGroup ? AppColors.secondary : AppColors.primary,
                  )
                : null,
          ),
          const SizedBox(width: 4),
          Text(
            name.length > 6 ? '${name.substring(0, 6)}...' : name,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部按钮栏
  Widget _buildBottomBar(int selectedCount, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: selectedCount > 0 && !_isSharing
                ? _onConfirmShare
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.divider,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _isSharing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    selectedCount > 0 ? '${l10n.send}($selectedCount)' : l10n.selectShareTarget,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// 构建好友列表
  Widget _buildFriendList() {
    final l10n = AppLocalizations.of(context)!;
    if (_friends.isEmpty) {
      return Center(
        child: Text(l10n.noFriendsYet, style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        final isSelected = _selectedUserIds.contains(friend.friendId);
        final avatarUrl = _getFullUrl(friend.friend.avatar);
        final displayName = friend.displayName;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl.proxied)
                : null,
            child: avatarUrl.isEmpty
                ? Text(
                    displayName.isNotEmpty ? displayName[0] : '?',
                    style: const TextStyle(color: AppColors.primary),
                  )
                : null,
          ),
          title: Text(displayName),
          trailing: _buildCheckbox(isSelected),
          onTap: () => _toggleUserSelection(friend.friendId),
        );
      },
    );
  }

  /// 构建群组列表
  Widget _buildGroupList() {
    final l10n = AppLocalizations.of(context)!;
    if (_groups.isEmpty) {
      return Center(
        child: Text(l10n.noGroupsYet, style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        final isSelected = _selectedGroupIds.contains(group.id);
        final avatarUrl = _getFullUrl(group.avatar);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.secondary.withOpacity(0.1),
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl.proxied)
                : null,
            child: avatarUrl.isEmpty
                ? const Icon(Icons.group, color: AppColors.secondary)
                : null,
          ),
          title: Text(group.name),
          subtitle: Text(l10n.peopleCount(group.memberCount)),
          trailing: _buildCheckbox(isSelected),
          onTap: () => _toggleGroupSelection(group.id),
        );
      },
    );
  }

  /// 构建复选框
  Widget _buildCheckbox(bool isSelected) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.textHint,
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }

  void _toggleUserSelection(int userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  void _toggleGroupSelection(int groupId) {
    setState(() {
      if (_selectedGroupIds.contains(groupId)) {
        _selectedGroupIds.remove(groupId);
      } else {
        _selectedGroupIds.add(groupId);
      }
    });
  }

  /// 确认分享
  Future<void> _onConfirmShare() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedUserIds.isEmpty && _selectedGroupIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectShareTarget)),
      );
      return;
    }

    setState(() => _isSharing = true);

    try {
      // 1. 截取二维码图片
      final bytes = await widget.captureQRCode();
      if (bytes == null) {
        _showError(l10n.generateImageFailed);
        return;
      }

      // 2. 上传图片
      final uploadResult = await _uploadApi.uploadImage(
        bytes.toList(),
        type: 'chat',
        filename: 'group_qrcode_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (uploadResult == null || uploadResult.url.isEmpty) {
        _showError(l10n.uploadFailed);
        return;
      }

      // 3. 构建图片消息的extra
      final extra = jsonEncode({
        'width': uploadResult.width ?? 300,
        'height': uploadResult.height ?? 400,
      });

      int successCount = 0;
      final tipContent = l10n.sharedGroupCard.replaceAll('{name}', widget.groupName);

      // 发送给好友
      for (final userId in _selectedUserIds) {
        try {
          final msgId = '${DateTime.now().millisecondsSinceEpoch}_$userId';
          final result = await _conversationApi.sendMessage(
            msgId: msgId,
            toUserId: userId,
            type: MessageType.image,
            content: uploadResult.url,
            extra: extra,
          );
          if (result.success) {
            successCount++;
            // 发送系统提示消息
            final tipMsgId = '${DateTime.now().millisecondsSinceEpoch}_tip_$userId';
            await _conversationApi.sendMessage(
              msgId: tipMsgId,
              toUserId: userId,
              type: MessageType.system,
              content: tipContent,
            );
          }
        } catch (e) {
          print('[ShareQRCode] Failed to send user $userId: $e');
        }
      }

      // 发送给群组
      for (final groupId in _selectedGroupIds) {
        try {
          final msgId = '${DateTime.now().millisecondsSinceEpoch}_g$groupId';
          final result = await _conversationApi.sendMessage(
            msgId: msgId,
            groupId: groupId,
            type: MessageType.image,
            content: uploadResult.url,
            extra: extra,
          );
          if (result.success) {
            successCount++;
            // 发送系统提示消息
            final tipMsgId = '${DateTime.now().millisecondsSinceEpoch}_tip_g$groupId';
            await _conversationApi.sendMessage(
              msgId: tipMsgId,
              groupId: groupId,
              type: MessageType.system,
              content: tipContent,
            );
          }
        } catch (e) {
          print('[ShareQRCode] Failed to send to group$groupId: $e');
        }
      }

      if (successCount > 0) {
        _showSuccess(l10n.sharedToContacts.replaceAll('{count}', '$successCount'));
        Navigator.pop(context);
      } else {
        _showError(l10n.shareFailed);
      }
    } catch (e) {
      _showError('${l10n.shareFailed}: $e');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
