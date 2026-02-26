/// 我的二维码页面
/// 显示个人二维码，可切换样式，支持保存和分享

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/conversation_api.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/api/upload_api.dart';
import 'package:im_client/api/user_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/models/group.dart';
import 'package:im_client/models/message.dart';
import 'package:im_client/models/user.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/l10n/app_localizations.dart';
// 条件导入：移动端使用 image_gallery_saver
import 'package:im_client/utils/image_saver_stub.dart'
    if (dart.library.io) 'package:im_client/utils/image_saver_mobile.dart'
    if (dart.library.html) 'package:im_client/utils/image_saver_web.dart';
import '../../utils/image_proxy.dart';

class MyQRCodeScreen extends StatefulWidget {
  const MyQRCodeScreen({super.key});

  @override
  State<MyQRCodeScreen> createState() => _MyQRCodeScreenState();
}

class _MyQRCodeScreenState extends State<MyQRCodeScreen> {
  final UserApi _userApi = UserApi(ApiClient());
  final GlobalKey _qrKey = GlobalKey();

  String? _qrContent;
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentStyle = 1;

  // 三种二维码样式配置
  List<QRCodeStyleConfig> _getStyles(AppLocalizations l10n) => [
    QRCodeStyleConfig(
      id: 1,
      name: l10n.translate('qr_style_simple'),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      gradientColors: null,
      borderRadius: 12,
    ),
    QRCodeStyleConfig(
      id: 2,
      name: l10n.translate('qr_style_gradient'),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF2196F3),
      gradientColors: [const Color(0xFF2196F3), const Color(0xFF673AB7)],
      borderRadius: 20,
    ),
    QRCodeStyleConfig(
      id: 3,
      name: l10n.translate('qr_style_vibrant'),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFFFF5722),
      gradientColors: [const Color(0xFFFF9800), const Color(0xFFFF5722)],
      borderRadius: 16,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadQRCode();
    _loadCurrentStyle();
  }

  void _loadCurrentStyle() {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      setState(() {
        _currentStyle = user.qrcodeStyle;
      });
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

  Future<void> _loadQRCode() async {
    try {
      final response = await _userApi.getMyQRCode();
      if (response.success && response.data != null) {
        setState(() {
          _qrContent = response.data['qr_content'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changeStyle(int styleId) async {
    if (_currentStyle == styleId) return;

    setState(() => _currentStyle = styleId);

    try {
      final response = await _userApi.updateProfile(qrcodeStyle: styleId);
      if (response.success) {
        // 刷新用户信息
        if (mounted) {
          context.read<AuthProvider>().refreshUser();
        }
      }
    } catch (e) {
      // 忽略错误
    }
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
      // Screenshot failed
      return null;
    }
  }

  /// 保存二维码图片到相册/下载
  Future<void> _saveQRCode() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);

    try {
      final bytes = await _captureQRCode();
      if (bytes == null) {
        _showError(l10n.translate('generate_image_failed'));
        return;
      }

      // 使用平台特定的保存方法
      final result = await saveImageToGallery(
        bytes.toList(),
        name: 'my_qrcode_${DateTime.now().millisecondsSinceEpoch}',
        quality: 100,
      );

      if (result['isSuccess'] == true) {
        _showSuccess(kIsWeb ? l10n.translate('image_download_started') : l10n.translate('image_saved_to_gallery'));
      } else {
        _showError(l10n.translate('save_failed_check_permission'));
      }
    } catch (e) {
      _showError('${l10n.translate('save_failed')}: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// 分享二维码图片给好友或群聊
  void _shareQRCode() {
    final user = context.read<AuthProvider>().user;
    final l10n = AppLocalizations.of(context)!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ShareMyQRCodeScreen(
          userName: user?.displayName ?? l10n.translate('me'),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = context.watch<AuthProvider>().user;
    final styles = _getStyles(l10n);
    final currentStyleConfig = styles.firstWhere(
      (s) => s.id == _currentStyle,
      orElse: () => styles[0],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.translate('my_qrcode')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // 二维码卡片（用于截图）
          RepaintBoundary(
            key: _qrKey,
            child: Center(
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(currentStyleConfig.borderRadius),
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
                    // 用户信息
                    Row(
                      children: [
                        Builder(builder: (context) {
                          final avatarUrl = _getFullUrl(user?.avatar ?? '');
                          return CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            backgroundImage: avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl.proxied)
                                : null,
                            child: avatarUrl.isEmpty
                              ? Text(
                                  user?.displayName.isNotEmpty == true
                                      ? user!.displayName[0]
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                          );
                        }),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? '',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (user?.bio?.isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Text(
                                  user!.bio!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 二维码
                    _isLoading
                        ? const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _qrContent != null
                            ? _buildQRCode(currentStyleConfig)
                            : SizedBox(
                                height: 200,
                                child: Center(child: Text(l10n.translate('load_failed_simple'))),
                              ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.translate('scan_qr_add_friend'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          // 样式选择
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('select_style'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: styles.map((style) {
                    final isSelected = _currentStyle == style.id;
                    return GestureDetector(
                      onTap: () => _changeStyle(style.id),
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: style.backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.qr_code,
                                  color: style.gradientColors != null
                                      ? style.gradientColors![0]
                                      : style.foregroundColor,
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              style.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey[700],
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Spacer(),
          // 操作按钮
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // 保存图片按钮
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _saveQRCode,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt, size: 18),
                    label: Text(l10n.translate('save_image')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 分享图片按钮
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _qrContent != null ? _shareQRCode : null,
                    icon: const Icon(Icons.share, size: 18),
                    label: Text(l10n.translate('share_image')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCode(QRCodeStyleConfig style) {
    final user = context.watch<AuthProvider>().user;
    final avatarUrl = _getFullUrl(user?.avatar ?? '');
    final hasAvatar = avatarUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: QrImageView(
        data: _qrContent!,
        version: QrVersions.auto,
        size: 180,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: style.gradientColors != null
              ? style.gradientColors![0]
              : style.foregroundColor,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: style.gradientColors != null
              ? style.gradientColors![1]
              : style.foregroundColor,
        ),
        // 如果用户有头像，在二维码中心显示头像
        embeddedImage: hasAvatar ? NetworkImage(avatarUrl.proxied) : null,
        embeddedImageStyle: hasAvatar
            ? QrEmbeddedImageStyle(
                size: const Size(40, 40),
              )
            : null,
      ),
    );
  }
}

/// 二维码样式配置
class QRCodeStyleConfig {
  final int id;
  final String name;
  final Color backgroundColor;
  final Color foregroundColor;
  final List<Color>? gradientColors;
  final double borderRadius;

  QRCodeStyleConfig({
    required this.id,
    required this.name,
    required this.backgroundColor,
    required this.foregroundColor,
    this.gradientColors,
    required this.borderRadius,
  });
}

/// 分享我的二维码目标选择页面
class _ShareMyQRCodeScreen extends StatefulWidget {
  final String userName;
  final Future<Uint8List?> Function() captureQRCode;

  const _ShareMyQRCodeScreen({
    required this.userName,
    required this.captureQRCode,
  });

  @override
  State<_ShareMyQRCodeScreen> createState() => _ShareMyQRCodeScreenState();
}

class _ShareMyQRCodeScreenState extends State<_ShareMyQRCodeScreen>
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
          SnackBar(content: Text('${l10n.translate('load_failed_simple')}: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 获取完整URL（处理相对路径）
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
    final selectedCount = _selectedUserIds.length + _selectedGroupIds.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('share_to')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.translate('friends')),
            Tab(text: l10n.translate('groups')),
          ],
        ),
      ),
      body: Column(
        children: [
          // 已选择的目标预览
          if (selectedCount > 0) _buildSelectedPreview(),
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
          _buildBottomBar(selectedCount),
        ],
      ),
    );
  }

  /// 构建已选择目标预览
  Widget _buildSelectedPreview() {
    final l10n = AppLocalizations.of(context)!;
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
            l10n.translate('selected_count').replaceAll('{count}', '${_selectedUserIds.length + _selectedGroupIds.length}'),
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
  Widget _buildBottomBar(int selectedCount) {
    final l10n = AppLocalizations.of(context)!;
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
                    selectedCount > 0 ? l10n.translate('send_count').replaceAll('{count}', '$selectedCount') : l10n.translate('select_share_target'),
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
        child: Text(l10n.translate('no_friends'), style: const TextStyle(color: AppColors.textSecondary)),
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
        child: Text(l10n.translate('no_groups'), style: const TextStyle(color: AppColors.textSecondary)),
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
          subtitle: Text(l10n.translate('member_count').replaceAll('{count}', '${group.memberCount}')),
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
        SnackBar(content: Text(l10n.translate('select_share_target'))),
      );
      return;
    }

    setState(() => _isSharing = true);

    try {
      // 1. 截取二维码图片
      final bytes = await widget.captureQRCode();
      if (bytes == null) {
        _showError(l10n.translate('generate_image_failed'));
        return;
      }

      // 2. 上传图片
      final uploadResult = await _uploadApi.uploadImage(
        bytes.toList(),
        type: 'chat',
        filename: 'my_qrcode_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (uploadResult == null || uploadResult.url.isEmpty) {
        _showError(l10n.translate('upload_image_failed'));
        return;
      }

      // 3. 构建图片消息的extra
      final extra = jsonEncode({
        'width': uploadResult.width ?? 300,
        'height': uploadResult.height ?? 400,
      });

      int successCount = 0;
      final tipContent = l10n.translate('shared_contact_card').replaceAll('{name}', widget.userName);

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
          debugPrint('[ShareMyQRCode] Send to user $userId failed: $e');
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
          debugPrint('[ShareMyQRCode] Send to group $groupId failed: $e');
        }
      }

      if (successCount > 0) {
        _showSuccess(l10n.translate('shared_to_contacts').replaceAll('{count}', '$successCount'));
        Navigator.pop(context);
      } else {
        _showError(l10n.translate('share_failed'));
      }
    } catch (e) {
      _showError('${l10n.translate('share_failed')}: $e');
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
