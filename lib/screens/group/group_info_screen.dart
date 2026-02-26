/// 群设置主页面 (WeChat-style)
/// 显示群信息、成员管理、权限设置、聊天设置等

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/api/upload_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/models/group.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/providers/chat_provider.dart';
import 'package:im_client/screens/group/group_member_list_screen.dart';
import 'package:im_client/screens/group/group_admin_list_screen.dart';
import 'package:im_client/screens/group/group_notice_screen.dart';
import 'package:im_client/screens/group/group_qrcode_screen.dart';
import 'package:im_client/screens/group/group_admin_permissions_screen.dart';
import 'package:im_client/screens/group/group_settings_screen.dart';
import 'package:im_client/screens/group/friend_select_screen.dart';
import 'package:im_client/screens/group/chat_background_screen.dart';
import 'package:im_client/screens/group/chat_history_search_screen.dart';
import 'package:im_client/screens/group/group_requests_screen.dart';
import 'package:im_client/services/local_database_service.dart';
import 'package:im_client/services/local_message_service.dart';
import 'package:im_client/services/chat_settings_service.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/utils/image_crop_helper.dart';
import 'package:provider/provider.dart';
import '../../utils/image_proxy.dart';

class GroupInfoScreen extends StatefulWidget {
  final int groupId;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final GroupApi _groupApi = GroupApi(ApiClient());
  final UploadApi _uploadApi = UploadApi(ApiClient());

  GroupFullInfo? _groupInfo;
  List<GroupMember> _members = [];
  bool _isLoading = true;
  int _pendingRequestCount = 0;

  StreamSubscription<Map<String, dynamic>>? _settingsUpdateSubscription;
  StreamSubscription<Map<String, dynamic>>? _joinRequestSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenForUpdates();
  }

  @override
  void dispose() {
    _settingsUpdateSubscription?.cancel();
    _joinRequestSubscription?.cancel();
    super.dispose();
  }

  void _listenForUpdates() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    // 监听群设置更新
    _settingsUpdateSubscription = chatProvider.groupSettingsUpdateStream.listen((data) {
      final groupId = data['group_id'];
      if (groupId == widget.groupId) {
        print('[GroupInfoScreen] Receive group settings update notification and refresh data: groupId=$groupId');
        _loadData();
      }
    });

    // 监听入群申请通知
    _joinRequestSubscription = chatProvider.groupJoinRequestStream.listen((data) {
      final groupId = data['group_id'];
      if (groupId == widget.groupId) {
        print('[GroupInfoScreen] Receive the group application notification and refresh the number of applications: groupId=$groupId');
        _loadPendingRequestCount();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _groupApi.getGroupFullInfo(widget.groupId),
      _groupApi.getGroupMembers(widget.groupId),
    ]);

    setState(() {
      _groupInfo = results[0] as GroupFullInfo?;
      _members = (results[1] as List<GroupMember>?) ?? [];
      _isLoading = false;
    });

    // 如果是管理员，加载待审核申请数量
    if (_groupInfo != null && _groupInfo!.isAdmin) {
      _loadPendingRequestCount();
    }
  }

  Future<void> _loadPendingRequestCount() async {
    if (_groupInfo == null || !_groupInfo!.isAdmin) return;

    final requests = await _groupApi.getGroupRequests(widget.groupId);
    setState(() {
      _pendingRequestCount = requests.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.groupSettings)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_groupInfo == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.groupSettings)),
        body: Center(child: Text(l10n.loadFailed)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.groupSettings),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            // 群头像（放在最前面）
            _buildGroupAvatarSection(),

            const SizedBox(height: 12),

            // 成员头像网格
            _buildMemberGrid(),

            const SizedBox(height: 12),

            // 群信息
            _buildGroupInfoSection(),

            const SizedBox(height: 12),

            // 群公告（移动到群信息下面）
            _buildNoticeSection(),

            const SizedBox(height: 12),

            // 加群设置（群主/管理员可见）
            if (_groupInfo!.isOwner) ...[
              _buildJoinSettingsSection(),
              const SizedBox(height: 12),
            ],

            // 群管理设置（群主/管理员可见）
            if (_groupInfo!.isAdmin) ...[
              _buildManagementSection(),
              const SizedBox(height: 12),
            ],

            // 聊天设置
            _buildChatSettingsSection(),

            const SizedBox(height: 12),

            // 聊天记录
            _buildChatHistorySection(),

            const SizedBox(height: 12),

            // 群操作
            _buildGroupActionsSection(),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  /// 获取完整URL（处理相对路径）
  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    // 防止只有 / 的情况
    if (url == '/') return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    // 相对路径，添加服务器地址
    final baseUrl = EnvConfig.instance.baseUrl;
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }

  /// 获取加群方式的国际化文本
  String _getJoinModeText(int joinMode) {
    final l10n = AppLocalizations.of(context)!;
    switch (joinMode) {
      case 1:
        return l10n.translate('join_mode_free');
      case 2:
        return l10n.translate('join_mode_verify');
      case 3:
        return l10n.translate('join_mode_forbid');
      case 4:
        return l10n.translate('join_mode_invite');
      case 5:
        return l10n.translate('join_mode_question');
      case 6:
        return l10n.translate('join_mode_paid');
      default:
        return l10n.translate('unknown');
    }
  }

  /// 群头像部分
  Widget _buildGroupAvatarSection() {
    final l10n = AppLocalizations.of(context)!;
    final group = _groupInfo!.group;
    final canEdit = _groupInfo!.canEditInfo; // 群主或有权限的管理员可以修改
    final avatarUrl = _getFullUrl(group.avatar);

    return Container(
      color: AppColors.white,
      child: ListTile(
        leading: GestureDetector(
          onTap: canEdit ? _showAvatarOptions : null,
          child: CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl.proxied)
                : null,
            child: avatarUrl.isEmpty
                ? Text(
                    group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                    style: const TextStyle(
                      fontSize: 24,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
        ),
        title: Text(
          group.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${l10n.groupNumber}: ${group.groupNo}',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: canEdit
            ? IconButton(
                icon: const Icon(Icons.camera_alt_outlined, color: AppColors.textHint),
                onPressed: _showAvatarOptions,
              )
            : null,
      ),
    );
  }

  /// 显示头像选择选项
  void _showAvatarOptions() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.takePhoto),
              onTap: () {
                Navigator.pop(context);
                _pickAvatarImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.selectFromAlbum),
              onTap: () {
                Navigator.pop(context);
                _pickAvatarImage(ImageSource.gallery);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l10n.cancel),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 选择并上传群头像
  Future<void> _pickAvatarImage(ImageSource source) async {
    bool loadingShown = false;
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      // 裁剪图片（非Web平台）
      String? imagePath = pickedFile.path;
      if (!kIsWeb) {
        if (!mounted) return;
        final croppedPath = await ImageCropHelper.cropImage(
          context,
          pickedFile.path,
          CropType.avatar,
        );
        if (croppedPath == null) return;
        imagePath = croppedPath;
      }

      _showLoading(AppLocalizations.of(context)!.loading);
      loadingShown = true;

      // 上传图片
      print('[GroupInfoScreen] 开始上传头像: $imagePath');

      UploadResult? uploadResult;
      if (kIsWeb) {
        // Web平台：读取字节数据上传
        final bytes = await pickedFile.readAsBytes();
        uploadResult = await _uploadApi.uploadAvatar(bytes, filename: 'avatar.jpg');
      } else {
        // 移动端：使用裁剪后的文件路径上传
        uploadResult = await _uploadApi.uploadAvatar(imagePath!);
      }

      if (mounted) Navigator.pop(context); // 关闭loading
      loadingShown = false;

      if (uploadResult == null || uploadResult.url.isEmpty) {
        print('[GroupInfoScreen] 头像上传失败: uploadResult=$uploadResult');
        _showError(AppLocalizations.of(context)!.uploadFailed);
        return;
      }

      print('[GroupInfoScreen] 头像上传成功: ${uploadResult.url}');

      // 更新群头像
      final res = await _groupApi.updateGroup(
        widget.groupId,
        avatar: uploadResult.url,
      );

      print('[GroupInfoScreen] 更新群头像结果: success=${res.success}, message=${res.message}');

      if (res.success) {
        // 清除旧头像的图片缓存
        if (_groupInfo?.group.avatar.isNotEmpty == true) {
          final oldAvatarUrl = _getFullUrl(_groupInfo!.group.avatar);
          imageCache.evict(NetworkImage(oldAvatarUrl.proxied));
        }
        // 预加载新头像（uploadResult.url 可能是相对路径）
        final newAvatarUrl = _getFullUrl(uploadResult.url);
        if (mounted && newAvatarUrl.isNotEmpty) {
          await precacheImage(NetworkImage(newAvatarUrl.proxied), context);
        }
        _showSuccess(AppLocalizations.of(context)!.avatarUpdated);
        await _loadData(); // 刷新数据
        print('[GroupInfoScreen] 数据刷新完成，新头像: ${_groupInfo?.group.avatar}, 完整URL: ${_getFullUrl(_groupInfo?.group.avatar ?? '')}');
      } else {
        _showError(res.message ?? AppLocalizations.of(context)!.updateFailed);
      }
    } catch (e) {
      print('[GroupInfoScreen] 头像上传异常: $e');
      if (loadingShown && mounted) {
        Navigator.pop(context); // 关闭loading
      }
      _showError('${AppLocalizations.of(context)!.operationFailed}: $e');
    }
  }

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// 成员头像网格
  Widget _buildMemberGrid() {
    final l10n = AppLocalizations.of(context)!;
    final displayMembers = _members.take(20).toList();
    // 权限判断：群主始终可以查看，管理员需要有canViewMembers权限，普通成员需要showMember开启
    final showMemberList = _groupInfo!.isOwner ||
        (_groupInfo!.isAdmin && _groupInfo!.adminPermissions.canViewMembers) ||
        (!_groupInfo!.isAdmin && _groupInfo!.group.showMember);

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.groupMembers} (${_groupInfo!.group.memberCount})',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              if (showMemberList)
                GestureDetector(
                  onTap: _showMemberList,
                  child: Row(
                    children: [
                      Text(
                        l10n.translate('view_all'),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...displayMembers.map((m) => _buildMemberAvatar(m)),
              // 群主/有权限的管理员始终显示+号，普通成员需要"允许成员邀请"开启才显示
              // canInvite = isOwner || (isAdmin && adminPermissions.canInvite)
              if (_groupInfo!.canInvite || (!_groupInfo!.isAdmin && _groupInfo!.group.allowInvite))
                _buildAddMemberButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatar(GroupMember member) {
    final avatarUrl = _getFullUrl(member.avatar);
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl.proxied)
                  : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      member.displayName.isNotEmpty
                          ? member.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            if (member.isOwner)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.star,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            if (member.isAdmin && !member.isOwner)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.shield,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 48,
          child: Text(
            member.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddMemberButton() {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: _inviteMembers,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider, width: 1.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.add,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.inviteMembers,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 群信息部分
  Widget _buildGroupInfoSection() {
    final l10n = AppLocalizations.of(context)!;
    final group = _groupInfo!.group;
    final mySettings = _groupInfo!.mySettings;

    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          // 群名称
          ListTile(
            title: Text(l10n.groupName),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (_groupInfo!.canEditInfo)
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
            onTap: _groupInfo!.canEditInfo ? _editGroupName : null,
          ),
          const Divider(height: 1, indent: 16),

          // 群备注（个人）
          ListTile(
            title: Text(l10n.groupRemark),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mySettings.groupRemark ?? l10n.notSet,
                  style: TextStyle(
                    color: mySettings.groupRemark != null
                        ? AppColors.textSecondary
                        : AppColors.textHint,
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
            onTap: _editGroupRemark,
          ),
          const Divider(height: 1, indent: 16),

          // 群二维码
          // 权限：群主/有邀请权限的管理员始终可以，普通成员需要开启allowQrcodeJoin
          Builder(builder: (context) {
            final canAccessQRCode = _groupInfo!.canInvite ||
                (!_groupInfo!.isAdmin && group.allowQrcodeJoin);

            return ListTile(
              title: Text(l10n.groupQrcode),
              subtitle: !canAccessQRCode
                  ? Text(
                      l10n.qrCodeJoinDisabled,
                      style: TextStyle(fontSize: 12, color: AppColors.textHint),
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code,
                    color: canAccessQRCode ? AppColors.textSecondary : AppColors.textHint,
                    size: 20,
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: canAccessQRCode ? AppColors.textHint : AppColors.divider,
                  ),
                ],
              ),
              onTap: canAccessQRCode ? _showQRCode : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.qrCodeJoinDisabled)),
                );
              },
            );
          }),
          const Divider(height: 1, indent: 16),

          // 群号
          ListTile(
            title: Text(l10n.groupNumber),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  group.groupNo,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _copyGroupNo(group.groupNo),
                  child: const Icon(
                    Icons.copy,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16),

          // 人数上限
          ListTile(
            title: Text(l10n.groupMaxMembers),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${group.memberCount}/${group.maxMembers}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (_groupInfo!.isOwner)
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
            onTap: _groupInfo!.isOwner ? _editMaxMembers : null,
          ),
        ],
      ),
    );
  }

  /// 加群设置部分
  Widget _buildJoinSettingsSection() {
    final l10n = AppLocalizations.of(context)!;
    final group = _groupInfo!.group;

    return Container(
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              l10n.joinSettings,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // 加群方式
          ListTile(
            title: Text(l10n.joinMethod),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getJoinModeText(group.joinMode),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
            onTap: _openJoinSettings,
          ),
          const Divider(height: 1, indent: 16),

          // 二维码加群
          SwitchListTile(
            title: Text(l10n.allowQrCodeJoin),
            value: group.allowQrcodeJoin,
            onChanged: (v) => _updateJoinSettings(allowQrcodeJoin: v),
          ),
          const Divider(height: 1, indent: 16),

          // 成员互加好友
          SwitchListTile(
            title: Text(l10n.allowMemberAddFriend),
            value: group.allowAddFriend,
            onChanged: (v) => _updateJoinSettings(allowAddFriend: v),
          ),
          const Divider(height: 1, indent: 16),

          // 显示群成员列表
          SwitchListTile(
            title: Text(l10n.showMemberList),
            subtitle: Text(
              group.showMember ? l10n.allMembersCanView : l10n.onlyAdminCanView,
              style: TextStyle(
                fontSize: 12,
                color: group.showMember ? AppColors.textHint : AppColors.error,
              ),
            ),
            value: group.showMember,
            onChanged: (v) => _updateShowMember(v),
          ),
          const Divider(height: 1, indent: 16),

          // 允许成员邀请
          SwitchListTile(
            title: Text(l10n.allowMemberInvite),
            subtitle: Text(
              group.allowInvite ? l10n.membersCanInvite : l10n.onlyAdminCanInvite,
              style: TextStyle(
                fontSize: 12,
                color: group.allowInvite ? AppColors.textHint : AppColors.error,
              ),
            ),
            value: group.allowInvite,
            onChanged: (v) => _updateAllowInvite(v),
          ),
        ],
      ),
    );
  }

  /// 获取定时清除显示文本
  String _getAutoClearText(int days) {
    final l10n = AppLocalizations.of(context)!;
    if (days <= 0) {
      return l10n.translate('auto_clear_disabled');
    }
    return l10n.translate('auto_clear_every_n_days').replaceAll('{days}', days.toString());
  }

  /// 显示定时清除选项
  void _showAutoClearOptions() {
    final l10n = AppLocalizations.of(context)!;
    final group = _groupInfo!.group;
    final options = [0, 1, 3, 7, 10, 30];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.translate('select_auto_clear_interval'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ...options.map((days) {
              final isSelected = group.autoClearDays == days;
              String text;
              if (days == 0) {
                text = l10n.translate('auto_clear_disabled');
              } else {
                text = l10n.translate('every_n_days').replaceAll('{days}', days.toString());
              }
              return ListTile(
                title: Text(text),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _updateAutoClearDays(days);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 更新定时清除设置
  Future<void> _updateAutoClearDays(int days) async {
    final l10n = AppLocalizations.of(context)!;
    final originalGroup = _groupInfo!.group;

    // 乐观更新
    setState(() {
      _groupInfo = _groupInfo!.copyWith(
        group: originalGroup.copyWith(autoClearDays: days),
      );
    });

    final res = await _groupApi.updateAutoClearSettings(widget.groupId, days);

    if (!res.success) {
      // 恢复原值
      setState(() {
        _groupInfo = _groupInfo!.copyWith(group: originalGroup);
      });
      _showError(res.message ?? l10n.translate('update_failed'));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('settings_saved'))),
      );
    }
  }

  /// 确认清除所有成员的聊天记录
  Future<void> _confirmClearAllMessages() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('clear_all_chat_history')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('clear_all_members_history_confirm')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.translate('clear_all_warning'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.translate('confirm_clear'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _groupApi.clearGroupMessages(widget.groupId);
      if (res.success) {
        // 清空本地消息缓存
        final conversId = 'g_${widget.groupId}';
        final chatProvider = context.read<ChatProvider>();
        await chatProvider.clearLocalMessages(conversId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('all_messages_cleared'))),
        );
      } else {
        _showError(res.message ?? l10n.translate('clear_failed'));
      }
    }
  }

  /// 群管理设置部分
  Widget _buildManagementSection() {
    final l10n = AppLocalizations.of(context)!;
    final group = _groupInfo!.group;

    return Container(
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              l10n.groupManageSettings,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // 管理员列表
          ListTile(
            title: Text(l10n.administrators),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.translate('people_count').replaceAll('{count}', '${group.adminCount + 1}'), // +1 包括群主
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
            onTap: _showAdminList,
          ),
          const Divider(height: 1, indent: 16),

          // 入群申请（需要审核模式下显示）
          if (group.joinMode == 2)
            ListTile(
              title: Text(l10n.joinRequests),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pendingRequestCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _pendingRequestCount > 99 ? '99+' : '$_pendingRequestCount',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
                ],
              ),
              onTap: _openGroupRequests,
            ),
          if (group.joinMode == 2)
            const Divider(height: 1, indent: 16),

          // 全体禁言
          SwitchListTile(
            title: Text(l10n.muteAll),
            subtitle: Text(
              l10n.muteAllDesc,
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
            value: group.muteAll,
            onChanged: _toggleMuteAll,
          ),

          // 管理员权限设置（仅群主可见）
          if (_groupInfo!.isOwner) ...[
            const Divider(height: 1, indent: 16),
            ListTile(
              title: Text(l10n.adminPermissions),
              trailing:
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
              onTap: _openAdminPermissions,
            ),
          ],
        ],
      ),
    );
  }

  /// 聊天设置部分
  Widget _buildChatSettingsSection() {
    final l10n = AppLocalizations.of(context)!;
    final mySettings = _groupInfo!.mySettings;

    return Container(
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              l10n.chatSettings,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // 我的群昵称
          ListTile(
            title: Text(l10n.myNicknameInGroup),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mySettings.nickname ?? l10n.notSet,
                  style: TextStyle(
                    color: mySettings.nickname != null
                        ? AppColors.textSecondary
                        : AppColors.textHint,
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
            onTap: _editNickname,
          ),
          const Divider(height: 1, indent: 16),

          // 聊天背景
          ListTile(
            title: Text(l10n.chatBackground),
            trailing:
                const Icon(Icons.chevron_right, color: AppColors.textHint),
            onTap: _selectChatBackground,
          ),
          const Divider(height: 1, indent: 16),

          // 置顶
          SwitchListTile(
            title: Text(l10n.pinChat),
            value: mySettings.isTop,
            onChanged: (v) => _updateMySettings(isTop: v),
          ),
          const Divider(height: 1, indent: 16),

          // 消息免打扰
          SwitchListTile(
            title: Text(l10n.doNotDisturb),
            value: mySettings.isNoDisturb,
            onChanged: (v) => _updateMySettings(isNoDisturb: v),
          ),
          const Divider(height: 1, indent: 16),

          // 显示群昵称
          SwitchListTile(
            title: Text(l10n.showMemberNickname),
            value: mySettings.showNickname,
            onChanged: (v) => _updateMySettings(showNickname: v),
          ),
        ],
      ),
    );
  }

  /// 聊天记录部分
  Widget _buildChatHistorySection() {
    final l10n = AppLocalizations.of(context)!;
    final group = _groupInfo!.group;

    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          // 查找聊天记录
          ListTile(
            title: Text(l10n.findChatHistory),
            trailing:
                const Icon(Icons.chevron_right, color: AppColors.textHint),
            onTap: _searchChatHistory,
          ),
          const Divider(height: 1, indent: 16),

          // 清空本地记录
          ListTile(
            title: Text(l10n.clearLocalHistory),
            trailing:
                const Icon(Icons.chevron_right, color: AppColors.textHint),
            onTap: _clearLocalMessages,
          ),

          // 定时清除设置（仅群主可见）
          if (_groupInfo!.isOwner) ...[
            const Divider(height: 1, indent: 16),
            ListTile(
              title: Text(l10n.translate('auto_clear_chat_history')),
              subtitle: Text(
                _getAutoClearText(group.autoClearDays),
                style: TextStyle(
                  fontSize: 12,
                  color: group.autoClearDays > 0 ? Colors.orange : AppColors.textHint,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
              onTap: _showAutoClearOptions,
            ),
          ],

          // 清空所有记录（权限控制）
          if (_groupInfo!.canClearHistory) ...[
            const Divider(height: 1, indent: 16),
            ListTile(
              title: Text(
                l10n.clearAllMembersHistory,
                style: const TextStyle(color: Colors.red),
              ),
              trailing:
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
              onTap: _confirmClearAllMessages,
            ),
          ],
        ],
      ),
    );
  }

  /// 群公告部分
  Widget _buildNoticeSection() {
    final l10n = AppLocalizations.of(context)!;
    final notice = _groupInfo!.group.notice;

    return Container(
      color: AppColors.white,
      child: ListTile(
        title: Text(l10n.groupNotice),
        subtitle: notice != null && notice.isNotEmpty
            ? Text(
                notice,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              )
            : Text(
                l10n.noNotice,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint,
                ),
              ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
        onTap: _showNotice,
      ),
    );
  }

  /// 群操作部分
  Widget _buildGroupActionsSection() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          // 转让群主（仅群主）
          if (_groupInfo!.isOwner) ...[
            ListTile(
              title: Text(l10n.transferOwnership),
              trailing:
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
              onTap: _transferOwnership,
            ),
            const Divider(height: 1, indent: 16),
          ],

          // 解散/退出群聊
          ListTile(
            title: Text(
              _groupInfo!.isOwner ? l10n.translate('dismiss_group') : l10n.leaveGroup,
              style: const TextStyle(color: AppColors.error),
            ),
            onTap: _groupInfo!.isOwner ? _disbandGroup : _leaveGroup,
          ),
        ],
      ),
    );
  }

  // ============ 操作方法 ============

  void _showMemberList() {
    final currentUserId = context.read<AuthProvider>().user?.id;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupMemberListScreen(
          groupId: widget.groupId,
          isAdmin: _groupInfo!.isAdmin,
          isOwner: _groupInfo!.isOwner,
          canKick: _groupInfo!.canKick,
          canMute: _groupInfo!.canMute,
          allowAddFriend: _groupInfo!.group.allowAddFriend,
          currentUserId: currentUserId,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _inviteMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendSelectScreen(groupId: widget.groupId),
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  void _editGroupName() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await _showInputDialog(
      title: l10n.modifyGroupName,
      initialValue: _groupInfo!.group.name,
      hintText: l10n.enterGroupName,
    );
    if (result != null && result.isNotEmpty) {
      final res = await _groupApi.updateGroup(widget.groupId, name: result);
      if (res.success) {
        _loadData();
        _showSuccess(l10n.groupNameModified);
      } else {
        _showError(res.message ?? l10n.updateFailed);
      }
    }
  }

  void _editGroupRemark() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await _showInputDialog(
      title: l10n.setGroupRemark,
      initialValue: _groupInfo!.mySettings.groupRemark ?? '',
      hintText: l10n.groupRemarkOnlyMe,
    );
    if (result != null) {
      final res = await _groupApi.updateGroupRemark(widget.groupId, result);
      if (res.success) {
        _loadData();
        _showSuccess(l10n.groupRemarkUpdated);
      } else {
        _showError(res.message ?? l10n.updateFailed);
      }
    }
  }

  void _showQRCode() {
    // 能进入这个函数说明已经通过了权限检查，可以操作二维码
    // 群主/有邀请权限的管理员：始终可以
    // 普通成员：allowQrcodeJoin 开启时可以
    final canOperate = _groupInfo!.canInvite ||
        (!_groupInfo!.isAdmin && _groupInfo!.group.allowQrcodeJoin);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupQRCodeScreen(
          groupId: widget.groupId,
          allowQrcodeJoin: canOperate,
        ),
      ),
    );
  }

  void _copyGroupNo(String groupNo) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: groupNo));
    _showSuccess(l10n.groupNumberCopied);
  }

  void _editMaxMembers() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await _showInputDialog(
      title: l10n.groupMaxMembers,
      initialValue: _groupInfo!.group.maxMembers.toString(),
      hintText: l10n.groupMaxMembersHint,
      keyboardType: TextInputType.number,
    );
    if (result != null) {
      final max = int.tryParse(result);
      if (max == null || max < 10 || max > 2000) {
        _showError(l10n.maxMembersRange);
        return;
      }
      final res = await _groupApi.updateMaxMembers(widget.groupId, max);
      if (res.success) {
        _loadData();
        _showSuccess(l10n.maxMembersUpdated);
      } else {
        _showError(res.message ?? l10n.updateFailed);
      }
    }
  }

  void _openJoinSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupSettingsScreen(
          group: _groupInfo!.group,
          isOwner: _groupInfo!.isOwner,
        ),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _updateJoinSettings({
    bool? allowAddFriend,
    bool? allowQrcodeJoin,
  }) async {
    // 保存原始群组信息
    final originalGroup = _groupInfo!.group;

    // 乐观更新
    setState(() {
      _groupInfo = _groupInfo!.copyWith(
        group: originalGroup.copyWith(
          allowAddFriend: allowAddFriend,
          allowQrcodeJoin: allowQrcodeJoin,
        ),
      );
    });

    final res = await _groupApi.updateGroupJoinSettings(
      widget.groupId,
      allowAddFriend: allowAddFriend,
      allowQrcodeJoin: allowQrcodeJoin,
    );

    if (!res.success) {
      final l10n = AppLocalizations.of(context)!;
      // 失败时恢复
      setState(() {
        _groupInfo = _groupInfo!.copyWith(group: originalGroup);
      });
      _showError(res.message ?? l10n.updateFailed);
    }
  }

  Future<void> _updateShowMember(bool showMember) async {
    final originalGroup = _groupInfo!.group;

    // 乐观更新
    setState(() {
      _groupInfo = _groupInfo!.copyWith(
        group: originalGroup.copyWith(showMember: showMember),
      );
    });

    final res = await _groupApi.updateGroupSettings(
      widget.groupId,
      showMember: showMember,
    );

    if (!res.success) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _groupInfo = _groupInfo!.copyWith(group: originalGroup);
      });
      _showError(res.message ?? l10n.updateFailed);
    }
  }

  Future<void> _updateAllowInvite(bool allowInvite) async {
    final originalGroup = _groupInfo!.group;

    // 乐观更新
    setState(() {
      _groupInfo = _groupInfo!.copyWith(
        group: originalGroup.copyWith(allowInvite: allowInvite),
      );
    });

    final res = await _groupApi.updateGroupSettings(
      widget.groupId,
      allowInvite: allowInvite,
    );

    if (!res.success) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _groupInfo = _groupInfo!.copyWith(group: originalGroup);
      });
      _showError(res.message ?? l10n.updateFailed);
    }
  }

  void _showAdminList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupAdminListScreen(
          groupId: widget.groupId,
          isOwner: _groupInfo!.isOwner,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _openGroupRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupRequestsScreen(
          groupId: widget.groupId,
          groupName: _groupInfo!.group.name,
        ),
      ),
    );
    // 返回后刷新待审核数量
    _loadPendingRequestCount();
  }

  Future<void> _toggleMuteAll(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    final originalGroup = _groupInfo!.group;

    // 乐观更新
    setState(() {
      _groupInfo = _groupInfo!.copyWith(
        group: originalGroup.copyWith(muteAll: value),
      );
    });

    final res = await _groupApi.setGroupMuteAll(widget.groupId, value);
    if (res.success) {
      _showSuccess(value ? l10n.muteAllEnabled : l10n.muteAllDisabled);
    } else {
      // 失败时恢复
      setState(() {
        _groupInfo = _groupInfo!.copyWith(group: originalGroup);
      });
      _showError(res.message ?? l10n.operationFailed);
    }
  }

  void _openAdminPermissions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupAdminPermissionsScreen(groupId: widget.groupId),
      ),
    ).then((_) => _loadData());
  }

  void _editNickname() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await _showInputDialog(
      title: l10n.setGroupNickname,
      initialValue: _groupInfo!.mySettings.nickname ?? '',
      hintText: l10n.enterNicknameInGroup,
    );
    if (result != null) {
      final res = await _groupApi.updateMyGroupSettings(
        widget.groupId,
        nickname: result,
      );
      if (res.success) {
        _loadData();
        _showSuccess(l10n.groupNicknameUpdated);
      } else {
        _showError(res.message ?? l10n.updateFailed);
      }
    }
  }

  void _selectChatBackground() async {
    final conversId = 'g_${widget.groupId}';
    final chatSettingsService = ChatSettingsService();
    await chatSettingsService.init();
    final currentBackground = await chatSettingsService.getBackgroundImage(conversId);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatBackgroundScreen(
          conversId: conversId,
          currentBackground: currentBackground,
        ),
      ),
    );
  }

  Future<void> _updateMySettings({
    bool? isTop,
    bool? isNoDisturb,
    bool? showNickname,
  }) async {
    // 保存原始设置用于失败时恢复
    final originalSettings = _groupInfo!.mySettings;

    // 乐观更新：先更新本地UI
    setState(() {
      _groupInfo = _groupInfo!.copyWith(
        mySettings: originalSettings.copyWith(
          isTop: isTop,
          isNoDisturb: isNoDisturb,
          showNickname: showNickname,
        ),
      );
    });

    final res = await _groupApi.updateMyGroupSettings(
      widget.groupId,
      isTop: isTop,
      isNoDisturb: isNoDisturb,
      showNickname: showNickname,
    );

    if (res.success) {
      // 同步本地会话列表的置顶状态
      if (isTop != null) {
        final conversId = 'g_${widget.groupId}';
        final chatProvider = context.read<ChatProvider>();
        await chatProvider.toggleConversationTop(conversId, isTop);
      }
      // 同步本地会话列表的免打扰状态
      if (isNoDisturb != null) {
        final conversId = 'g_${widget.groupId}';
        final chatProvider = context.read<ChatProvider>();
        await chatProvider.toggleConversationMute(conversId, isNoDisturb);
      }
    } else {
      final l10n = AppLocalizations.of(context)!;
      // 失败时恢复原始值
      setState(() {
        _groupInfo = _groupInfo!.copyWith(mySettings: originalSettings);
      });
      _showError(res.message ?? l10n.updateFailed);
    }
  }

  void _searchChatHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatHistorySearchScreen(
          groupId: widget.groupId,
          groupName: _groupInfo!.group.name,
        ),
      ),
    );
  }

  void _clearLocalMessages() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await _showConfirmDialog(
      title: l10n.clearLocalHistory,
      content: l10n.clearLocalHistoryConfirm,
    );
    if (confirm == true) {
      final conversId = 'g_${widget.groupId}';
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.clearLocalMessages(conversId);
      _showSuccess(l10n.localHistoryCleared);
    }
  }

  void _showNotice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupNoticeScreen(
          groupId: widget.groupId,
          notice: _groupInfo!.group.notice,
          canEdit: _groupInfo!.canEditNotice,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _transferOwnership() async {
    final l10n = AppLocalizations.of(context)!;
    // 打开成员选择页面
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupMemberListScreen(
          groupId: widget.groupId,
          isAdmin: true,
          isOwner: true,
          selectMode: true,
          selectTitle: l10n.selectNewOwner,
        ),
      ),
    );
    if (result != null) {
      final confirm = await _showConfirmDialog(
        title: l10n.transferOwnership,
        content: l10n.transferOwnershipConfirm,
        isDestructive: true,
      );
      if (confirm == true) {
        final res = await _groupApi.transferGroup(widget.groupId, result);
        if (res.success) {
          _showSuccess(l10n.ownershipTransferred);
          _loadData();
        } else {
          _showError(res.message ?? l10n.transferFailed);
        }
      }
    }
  }

  void _disbandGroup() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await _showConfirmDialog(
      title: l10n.translate('dismiss_group'),
      content: l10n.dismissGroupConfirm,
      isDestructive: true,
    );
    if (confirm == true) {
      final res = await _groupApi.disbandGroup(widget.groupId);
      if (res.success) {
        _showSuccess(l10n.groupDismissed);
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        _showError(res.message ?? l10n.dismissFailed);
      }
    }
  }

  void _leaveGroup() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await _showConfirmDialog(
      title: l10n.leaveGroup,
      content: l10n.leaveGroupConfirm,
      isDestructive: true,
    );
    if (confirm == true) {
      final res = await _groupApi.leaveGroup(widget.groupId);
      if (res.success) {
        _showSuccess(l10n.leftGroup);
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        _showError(res.message ?? l10n.leaveFailed);
      }
    }
  }

  // ============ 辅助方法 ============

  Future<String?> _showInputDialog({
    required String title,
    String? initialValue,
    String? hintText,
    TextInputType? keyboardType,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
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
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    bool isDestructive = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.confirm,
              style: TextStyle(
                color: isDestructive ? AppColors.error : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
