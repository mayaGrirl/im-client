/// 编辑个人资料页面
/// 修改昵称、头像、签名、性别、地区、二维码样式、地址等

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/user_api.dart';
import 'package:im_client/api/upload_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/providers/auth_provider.dart';
import 'package:im_client/screens/profile/my_qrcode_screen.dart';
import 'package:im_client/utils/image_crop_helper.dart';
import '../../utils/image_proxy.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final UserApi _userApi = UserApi(ApiClient());
  final UploadApi _uploadApi = UploadApi(ApiClient());
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.editProfile),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),
          // 头像
          Container(
            color: Colors.white,
            child: ListTile(
              title: Text(l10n.avatar),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(builder: (context) {
                    final avatarUrl = _getFullUrl(user?.avatar ?? '');
                    return CircleAvatar(
                      radius: 25,
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
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    );
                  }),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
                ],
              ),
              onTap: () => _showAvatarPicker(context),
            ),
          ),
          const Divider(height: 1, indent: 16),
          // 昵称
          _buildEditItem(
            l10n: l10n,
            title: l10n.nickname,
            value: user?.nickname ?? '',
            onTap: () => _editNickname(context, user?.nickname ?? ''),
          ),
          const Divider(height: 1, indent: 16),
          // 账号（不可编辑）
          Container(
            color: Colors.white,
            child: ListTile(
              title: Text(l10n.translate('account')),
              trailing: Text(
                user?.username ?? '',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 个性签名
          _buildEditItem(
            l10n: l10n,
            title: l10n.bio,
            value: user?.bio ?? l10n.notSet,
            onTap: () => _editBio(context, user?.bio ?? ''),
          ),
          const Divider(height: 1, indent: 16),
          // 小视频简介
          _buildEditItem(
            l10n: l10n,
            title: l10n.translate('video_bio'),
            value: user?.videoBio ?? l10n.notSet,
            onTap: () => _editVideoBio(context, user?.videoBio ?? ''),
          ),
          const Divider(height: 1, indent: 16),
          // 小视频主页封面
          Container(
            color: Colors.white,
            child: ListTile(
              title: Text(l10n.translate('video_cover')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(builder: (context) {
                    final coverUrl = _getFullUrl(user?.videoCover ?? '');
                    return Container(
                      width: 60,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey[200],
                        image: coverUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(coverUrl.proxied),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: coverUrl.isEmpty
                          ? Icon(Icons.image_outlined, size: 20, color: Colors.grey[400])
                          : null,
                    );
                  }),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
                ],
              ),
              onTap: () => _showVideoCoverPicker(context),
            ),
          ),
          const Divider(height: 1, indent: 16),
          // 性别
          _buildEditItem(
            l10n: l10n,
            title: l10n.gender,
            value: _getGenderText(l10n, user?.gender ?? 0),
            onTap: () => _selectGender(context, user?.gender ?? 0),
          ),
          const Divider(height: 1, indent: 16),
          // 地区
          _buildEditItem(
            l10n: l10n,
            title: l10n.region,
            value: user?.region ?? l10n.notSet,
            onTap: () => _editRegion(context, user?.region ?? ''),
          ),
          const SizedBox(height: 10),
          // 我的二维码
          Container(
            color: Colors.white,
            child: ListTile(
              title: Text(l10n.myQrcode),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyQRCodeScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // 我的地址
          _buildEditItem(
            l10n: l10n,
            title: l10n.myAddress,
            value: user?.address ?? l10n.notSet,
            onTap: () => _editAddress(context, user?.address ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _buildEditItem({
    required AppLocalizations l10n,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Container(
      color: Colors.white,
      child: ListTile(
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                value.isEmpty ? l10n.notSet : value,
                style: TextStyle(
                  color: value.isEmpty ? Colors.grey[400] : Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _getGenderText(AppLocalizations l10n, int gender) {
    switch (gender) {
      case 1:
        return l10n.male;
      case 2:
        return l10n.female;
      default:
        return l10n.notSet;
    }
  }

  void _showAvatarPicker(BuildContext context) {
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
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.selectFromAlbum),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
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

  Future<void> _pickImage(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
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

      setState(() => _isLoading = true);

      // 上传图片
      UploadResult? uploadResult;
      if (kIsWeb) {
        // Web平台：读取字节数据上传
        final bytes = await pickedFile.readAsBytes();
        uploadResult = await _uploadApi.uploadAvatar(bytes, filename: 'avatar.jpg');
      } else {
        // 移动端：使用裁剪后的文件路径上传
        uploadResult = await _uploadApi.uploadAvatar(imagePath!);
      }

      if (uploadResult == null || uploadResult.url.isEmpty) {
        _showError(l10n.uploadFailed);
        return;
      }

      final avatarUrl = uploadResult.url;

      // 更新头像
      final response = await _userApi.updateProfile(avatar: avatarUrl);
      if (response.success && mounted) {
        context.read<AuthProvider>().refreshUser();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.avatarUpdated)),
        );
      } else {
        _showError(response.message ?? l10n.updateFailed);
      }
    } catch (e) {
      _showError('${l10n.operationFailed}: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showVideoCoverPicker(BuildContext context) {
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
                _pickVideoCover(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.selectFromAlbum),
              onTap: () {
                Navigator.pop(context);
                _pickVideoCover(ImageSource.gallery);
              },
            ),
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

  Future<void> _pickVideoCover(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      // 上传图片
      UploadResult? uploadResult;
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        uploadResult = await _uploadApi.uploadImage(bytes, filename: 'video_cover.jpg');
      } else {
        uploadResult = await _uploadApi.uploadImage(pickedFile.path);
      }

      if (uploadResult == null || uploadResult.url.isEmpty) {
        _showError(l10n.uploadFailed);
        return;
      }

      final coverUrl = uploadResult.url;

      // 更新封面
      final response = await _userApi.updateProfile(videoCover: coverUrl);
      if (response.success && mounted) {
        context.read<AuthProvider>().refreshUser();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('video_cover_updated'))),
        );
      } else {
        _showError(response.message ?? l10n.updateFailed);
      }
    } catch (e) {
      _showError('${l10n.operationFailed}: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _editNickname(BuildContext context, String currentValue) {
    final l10n = AppLocalizations.of(context)!;
    _showEditBottomSheet(
      context: context,
      title: l10n.editNickname,
      initialValue: currentValue,
      hintText: l10n.inputNickname,
      maxLength: 20,
      onSave: (value) async {
        if (value.isEmpty) {
          _showError(l10n.nicknameRequired);
          return;
        }
        final response = await _userApi.updateProfile(nickname: value);
        if (response.success && mounted) {
          context.read<AuthProvider>().refreshUser();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.nicknameUpdated)),
          );
        } else {
          _showError(response.message ?? l10n.updateFailed);
        }
      },
    );
  }

  void _editBio(BuildContext context, String currentValue) {
    final l10n = AppLocalizations.of(context)!;
    _showEditBottomSheet(
      context: context,
      title: l10n.editBio,
      initialValue: currentValue,
      hintText: l10n.inputBio,
      maxLength: 100,
      maxLines: 3,
      onSave: (value) async {
        final response = await _userApi.updateProfile(bio: value);
        if (response.success && mounted) {
          context.read<AuthProvider>().refreshUser();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.bioUpdated)),
          );
        } else {
          _showError(response.message ?? l10n.updateFailed);
        }
      },
    );
  }

  void _editVideoBio(BuildContext context, String currentValue) {
    final l10n = AppLocalizations.of(context)!;
    _showEditBottomSheet(
      context: context,
      title: l10n.translate('edit_video_bio'),
      initialValue: currentValue,
      hintText: l10n.translate('input_video_bio'),
      maxLength: 200,
      maxLines: 3,
      onSave: (value) async {
        final response = await _userApi.updateProfile(videoBio: value);
        if (response.success && mounted) {
          context.read<AuthProvider>().refreshUser();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('video_bio_updated'))),
          );
        } else {
          _showError(response.message ?? l10n.updateFailed);
        }
      },
    );
  }

  void _editRegion(BuildContext context, String currentValue) {
    final l10n = AppLocalizations.of(context)!;
    _showEditBottomSheet(
      context: context,
      title: l10n.editRegion,
      initialValue: currentValue,
      hintText: l10n.inputRegion,
      maxLength: 50,
      onSave: (value) async {
        final response = await _userApi.updateProfile(region: value);
        if (response.success && mounted) {
          context.read<AuthProvider>().refreshUser();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.regionUpdated)),
          );
        } else {
          _showError(response.message ?? l10n.updateFailed);
        }
      },
    );
  }

  void _editAddress(BuildContext context, String currentValue) {
    final l10n = AppLocalizations.of(context)!;
    _showEditBottomSheet(
      context: context,
      title: l10n.editAddress,
      initialValue: currentValue,
      hintText: l10n.inputAddress,
      maxLength: 100,
      maxLines: 2,
      onSave: (value) async {
        final response = await _userApi.updateProfile(address: value);
        if (response.success && mounted) {
          context.read<AuthProvider>().refreshUser();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.addressUpdated)),
          );
        } else {
          _showError(response.message ?? l10n.updateFailed);
        }
      },
    );
  }

  void _selectGender(BuildContext context, int currentGender) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动条
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.selectGender,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: Text(l10n.male),
                trailing: currentGender == 1
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => _updateGender(ctx, 1),
              ),
              const Divider(height: 1, indent: 16),
              ListTile(
                title: Text(l10n.female),
                trailing: currentGender == 2
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => _updateGender(ctx, 2),
              ),
              const Divider(height: 1, indent: 16),
              ListTile(
                title: Text(l10n.secret),
                trailing: currentGender == 0
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => _updateGender(ctx, 0),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateGender(BuildContext ctx, int gender) async {
    final l10n = AppLocalizations.of(context)!;
    Navigator.pop(ctx);
    final response = await _userApi.updateProfile(gender: gender);
    if (response.success && mounted) {
      context.read<AuthProvider>().refreshUser();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.genderUpdated)),
      );
    } else {
      _showError(response.message ?? l10n.updateFailed);
    }
  }

  void _showEditBottomSheet({
    required BuildContext context,
    required String title,
    required String initialValue,
    required String hintText,
    required int maxLength,
    int maxLines = 1,
    required Future<void> Function(String value) onSave,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initialValue);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.cancel),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setState(() => isSaving = true);
                              await onSave(controller.text.trim());
                              setState(() => isSaving = false);
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.save),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 输入框
                TextField(
                  controller: controller,
                  maxLength: maxLength,
                  maxLines: maxLines,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: hintText,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    }
  }
}
