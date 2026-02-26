/// 创建群聊页面
/// 选择联系人创建新群组

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/api/upload_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/models/user.dart';
import 'package:im_client/models/group.dart';
import 'package:im_client/utils/image_crop_helper.dart';
import '../../utils/image_proxy.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _groupNameController = TextEditingController();
  final _friendApi = FriendApi(ApiClient());
  final _groupApi = GroupApi(ApiClient());
  final _uploadApi = UploadApi(ApiClient());
  final _imagePicker = ImagePicker();

  List<Friend> _friends = [];
  Set<int> _selectedIds = {};
  bool _isLoading = true;
  bool _isCreating = false;
  String? _avatarUrl;
  File? _avatarFile;
  Uint8List? _avatarBytes; // For web platform

  // 付费群相关
  bool _isPaidGroup = false;
  final _priceController = TextEditingController(text: '100');
  final _trialDaysController = TextEditingController(text: '0');
  int _priceType = GroupPriceType.once;  // 默认一次性付费
  PaidGroupConfig? _paidGroupConfig;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadPaidGroupConfig();
  }

  Future<void> _loadPaidGroupConfig() async {
    try {
      final config = await _groupApi.getPaidGroupConfig();
      if (mounted) {
        setState(() {
          _paidGroupConfig = config;
        });
      }
    } catch (e) {
      debugPrint('加载付费群配置失败: $e');
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _priceController.dispose();
    _trialDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _friendApi.getFriendList();
      setState(() {
        _friends = friends;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.loadFailed}: $e')),
        );
      }
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image != null) {
        // 裁剪图片
        final croppedPath = await ImageCropHelper.cropImage(
          context,
          image.path,
          CropType.avatar,
        );
        if (croppedPath == null) return; // 用户取消裁剪

        // 上传图片
        UploadResult? result;

        if (kIsWeb) {
          // Web平台：读取裁剪后文件字节上传
          final bytes = await File(croppedPath).readAsBytes();
          setState(() {
            _avatarBytes = bytes;
            _avatarFile = null;
          });
          result = await _uploadApi.uploadImage(bytes.toList(), type: 'group_avatar', filename: image.name);
        } else {
          // 移动端：使用裁剪后的File上传
          setState(() {
            _avatarFile = File(croppedPath);
            _avatarBytes = null;
          });
          result = await _uploadApi.uploadImage(_avatarFile!, type: 'group_avatar');
        }

        if (result != null && result.url.isNotEmpty) {
          setState(() {
            _avatarUrl = result!.url;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.uploadFailed)),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.selectImageFailed}: $e')),
        );
      }
    }
  }

  Future<void> _createGroup() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectAtLeastOne)),
      );
      return;
    }

    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterGroupName)),
      );
      return;
    }

    // 付费群价格验证
    double? price;
    if (_isPaidGroup) {
      price = double.tryParse(_priceController.text.trim());
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('invalid_price'))),
        );
        return;
      }
    }

    setState(() => _isCreating = true);

    try {
      ApiResult result;
      if (_isPaidGroup) {
        // 创建付费群（分成比例由管理端设置）
        final trialDays = int.tryParse(_trialDaysController.text.trim()) ?? 0;
        result = await _groupApi.createPaidGroup(
          name: groupName,
          memberIds: _selectedIds.toList(),
          avatar: _avatarUrl,
          price: price!,
          priceType: _priceType,
          allowTrialDays: trialDays < 0 ? 0 : trialDays,
        );
      } else {
        // 创建普通群
        result = await _groupApi.createGroup(
          name: groupName,
          memberIds: _selectedIds.toList(),
          avatar: _avatarUrl,
        );
      }

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.groupCreated),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, result.data);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.displayMessage),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.createFailed}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isCreating = false);
    }
  }

  void _toggleSelection(int friendId) {
    setState(() {
      if (_selectedIds.contains(friendId)) {
        _selectedIds.remove(friendId);
      } else {
        _selectedIds.add(friendId);
      }
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

  /// 获取头像装饰图
  DecorationImage? _getAvatarDecoration() {
    if (_avatarBytes != null) {
      // Web平台：使用内存图片
      return DecorationImage(
        image: MemoryImage(_avatarBytes!),
        fit: BoxFit.cover,
      );
    } else if (_avatarFile != null) {
      // 移动端：使用文件图片
      return DecorationImage(
        image: FileImage(_avatarFile!),
        fit: BoxFit.cover,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('create_group')),
        actions: [
          TextButton(
            onPressed: _selectedIds.isNotEmpty && !_isCreating
                ? _createGroup
                : null,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '${l10n.createGroup}(${_selectedIds.length})',
                    style: TextStyle(
                      color: _selectedIds.isNotEmpty
                          ? AppColors.primary
                          : AppColors.textHint,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 群头像和名称输入
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.white,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 群头像
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      image: _getAvatarDecoration(),
                    ),
                    child: (_avatarFile == null && _avatarBytes == null)
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, color: AppColors.primary, size: 24),
                              const SizedBox(height: 4),
                              Text(
                                l10n.groupAvatar,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                // 群名称
                Expanded(
                  child: TextField(
                    controller: _groupNameController,
                    decoration: InputDecoration(
                      labelText: l10n.translate('group_name'),
                      hintText: l10n.translate('input_group_name'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLength: 20,
                  ),
                ),
              ],
            ),
          ),

          // 付费群设置
          _buildPaidGroupSection(),

          // 已选择的成员
          if (_selectedIds.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.background,
              child: Text(
                '${l10n.selectedPeople}: ${_selectedIds.length}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              height: 88,
              color: AppColors.white,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _selectedIds.length,
                itemBuilder: (context, index) {
                  final friendId = _selectedIds.elementAt(index);
                  final friend = _friends.firstWhere(
                    (f) => f.friendId == friendId,
                    orElse: () => _friends.first,
                  );
                  return _buildSelectedMember(friend);
                },
              ),
            ),
          ],

          // 好友列表标题
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.background,
            child: Text(
              l10n.translate('select_friends'),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),

          // 好友列表
          Expanded(
            child: _buildFriendList(),
          ),
        ],
      ),
    );
  }

  /// 构建付费群设置区域
  Widget _buildPaidGroupSection() {
    final l10n = AppLocalizations.of(context)!;
    final config = _paidGroupConfig;
    final canCreatePaidGroup = config?.canCreatePaidGroup ?? false;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 付费群开关
          SwitchListTile(
            title: Text(l10n.translate('paid_group')),
            subtitle: Text(
              canCreatePaidGroup
                  ? l10n.translate('enable_paid_group')
                  : l10n.translate('paid_group_level_limit'),
              style: TextStyle(
                fontSize: 12,
                color: canCreatePaidGroup ? AppColors.textSecondary : AppColors.error,
              ),
            ),
            value: _isPaidGroup,
            activeColor: AppColors.primary,
            onChanged: canCreatePaidGroup
                ? (value) {
                    setState(() => _isPaidGroup = value);
                  }
                : null,
          ),

          // 等级限制提示
          if (!canCreatePaidGroup && config != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '您当前等级最多可创建 ${config.maxPaidGroups} 个付费群，已创建 ${config.currentPaidGroupCount} 个',
                        style: TextStyle(fontSize: 12, color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 付费群详细设置
          if (_isPaidGroup) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 入群价格
                  Row(
                    children: [
                      Text(
                        l10n.translate('group_price'),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: false),
                          decoration: InputDecoration(
                            hintText: l10n.translate('enter_price'),
                            suffixText: l10n.translate('gold_beans'),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 价格类型
                  Row(
                    children: [
                      Text(
                        l10n.translate('price_type'),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _priceType,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: GroupPriceType.once,
                              child: Text(l10n.translate('price_type_once')),
                            ),
                            DropdownMenuItem(
                              value: GroupPriceType.monthly,
                              child: Text(l10n.translate('price_type_monthly')),
                            ),
                            DropdownMenuItem(
                              value: GroupPriceType.yearly,
                              child: Text(l10n.translate('price_type_yearly')),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _priceType = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 试用天数
                  Row(
                    children: [
                      Text(
                        l10n.translate('trial_days'),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _trialDaysController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: l10n.translate('trial_days_hint'),
                            suffixText: l10n.translate('days'),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 试用天数提示
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.translate('trial_days_tip'),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),

                  // 分成比例显示
                  if (config != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pie_chart, size: 16, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                l10n.translate('income_preview'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${l10n.translate('your_income')}: ${config.ownerShareRatio}%',
                                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${l10n.translate('platform_commission')}: ${config.platformCommission}%',
                                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 提示信息
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.translate('paid_group_tip'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedMember(Friend friend) {
    final avatarUrl = _getFullUrl(friend.friend.avatar);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: GestureDetector(
        onTap: () => _toggleSelection(friend.friendId),
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl.proxied)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            friend.displayName.isNotEmpty ? friend.displayName[0] : '?',
                            style: const TextStyle(color: AppColors.primary),
                          )
                        : null,
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                friend.displayName,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendList() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noFriendsYet,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.addFriendsFirst,
              style: TextStyle(color: AppColors.textHint, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _friends.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final friend = _friends[index];
        final isSelected = _selectedIds.contains(friend.friendId);
        return _buildFriendItem(friend, isSelected);
      },
    );
  }

  Widget _buildFriendItem(Friend friend, bool isSelected) {
    final avatarUrl = _getFullUrl(friend.friend.avatar);
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withOpacity(0.1),
        backgroundImage: avatarUrl.isNotEmpty
            ? NetworkImage(avatarUrl.proxied)
            : null,
        child: avatarUrl.isEmpty
            ? Text(
                friend.displayName.isNotEmpty ? friend.displayName[0] : '?',
                style: const TextStyle(color: AppColors.primary),
              )
            : null,
      ),
      title: Text(
        friend.displayName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: friend.friend.bio != null && friend.friend.bio!.isNotEmpty
          ? Text(
              friend.friend.bio!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          : null,
      trailing: Checkbox(
        value: isSelected,
        onChanged: (_) => _toggleSelection(friend.friendId),
        activeColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      onTap: () => _toggleSelection(friend.friendId),
    );
  }
}
