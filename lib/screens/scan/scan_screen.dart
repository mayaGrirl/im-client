/// 扫一扫页面
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/screens/profile/my_qrcode_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/image_proxy.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  MobileScannerController? _scannerController;

  final FriendApi _friendApi = FriendApi(ApiClient());
  final GroupApi _groupApi = GroupApi(ApiClient());
  final ImagePicker _imagePicker = ImagePicker();

  bool _isProcessing = false;
  bool _isTorchOn = false;
  bool _hasPermission = true;
  bool _isInitialized = false;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // 检查是否支持手电筒（仅移动端支持）
  bool get _supportsTorch =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
        autoStart: true,
      );

      // 不在此处调用 start()，让 MobileScanner widget 构建后自动启动
      // controller 的 attach 发生在 widget build 阶段
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasPermission = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize scanner: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _isInitialized = true;
          _hasPermission = false;
          _errorMessage = _getErrorMessage(e.toString(), l10n);
        });
      }
    }
  }

  /// 根据错误信息返回友好的错误提示
  String _getErrorMessage(String error, AppLocalizations l10n) {
    final errorLower = error.toLowerCase();

    if (kIsWeb) {
      if (errorLower.contains('notallowederror') || errorLower.contains('permission')) {
        return l10n.translate('camera_permission_denied');
      }
      if (errorLower.contains('notfounderror') || errorLower.contains('no camera')) {
        return l10n.translate('no_camera_found');
      }
      if (errorLower.contains('notreadableerror') || errorLower.contains('in use')) {
        return l10n.translate('camera_in_use');
      }
      if (errorLower.contains('overconstrained')) {
        return l10n.translate('camera_config_not_supported');
      }
      if (errorLower.contains('securityerror') || errorLower.contains('https')) {
        return l10n.translate('https_required');
      }
      return l10n.translate('camera_start_failed');
    }

    // 移动端
    if (errorLower.contains('permission')) {
      return l10n.translate('grant_camera_permission');
    }
    return '${l10n.translate('cannot_access_camera')}: $error';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);
    _scannerController?.stop();
    _handleQRCode(code);
  }

  Future<void> _handleQRCode(String code) async {
    debugPrint('扫描到二维码: $code');

    try {
      // 解析二维码类型
      if (code.startsWith('im://qr/')) {
        // 平台二维码，调用服务器API获取详情
        final qrCode = code.replaceFirst('im://qr/', '');
        await _handlePlatformQRCode(qrCode);
      } else if (code.startsWith('im://user/')) {
        // 添加好友（旧格式兼容）
        final userId = code.replaceFirst('im://user/', '');
        await _handleAddFriend(userId);
      } else if (code.startsWith('im://group/')) {
        // 加入群聊（旧格式兼容）
        final groupId = code.replaceFirst('im://group/', '');
        await _handleJoinGroup(groupId);
      } else if (code.startsWith('http://') || code.startsWith('https://')) {
        // 打开链接
        await _handleUrl(code);
      } else {
        // 显示扫描结果
        _showScanResult(code);
      }
    } catch (e) {
      debugPrint('处理二维码失败: $e');
      final l10n = AppLocalizations.of(context)!;
      _showError('${l10n.translate('processing_failed')}: $e');
    }
  }

  /// 处理平台二维码（im://qr/{code}格式）
  Future<void> _handlePlatformQRCode(String qrCode) async {
    final l10n = AppLocalizations.of(context)!;
    _showLoading(l10n.translate('loading'));

    try {
      final response = await ApiClient().get('/qrcode/scan/$qrCode');
      Navigator.pop(context); // 关闭loading

      if (!response.success || response.data == null) {
        _showError(response.message ?? l10n.translate('qrcode_invalid'));
        return;
      }

      final data = response.data;
      final type = data['type'] as int?;

      switch (type) {
        case 1: // 用户二维码
          final userData = data['user'];
          if (userData != null) {
            final isFriend = data['is_friend'] == true;
            await _handleUserQRCode(userData, isFriend);
          } else {
            _showError(l10n.translate('user_not_found'));
          }
          break;
        case 2: // 群组二维码
          final groupData = data['group'];
          if (groupData != null) {
            final isMember = data['is_member'] == true;
            await _handleGroupQRCode(groupData, isMember);
          } else {
            _showError(l10n.translate('group_not_found'));
          }
          break;
        case 4: // 收款二维码
          final payUserData = data['user'];
          if (payUserData != null) {
            _showError(l10n.translate('payment_qrcode_not_supported'));
          }
          break;
        default:
          _showError(l10n.translate('unknown_qrcode_type'));
      }
    } catch (e) {
      Navigator.pop(context); // 关闭loading
      _showError('${l10n.translate('processing_failed')}: $e');
    }
  }

  /// 处理用户二维码扫描结果
  Future<void> _handleUserQRCode(Map<String, dynamic> userData, bool isFriend) async {
    final l10n = AppLocalizations.of(context)!;
    final userId = userData['id'];
    final nickname = userData['nickname'] ?? userData['username'] ?? 'User';
    final avatar = userData['avatar'] ?? '';

    if (isFriend) {
      // 已经是好友，提示并返回
      _showSnackBar(l10n.translate('already_friend'), isSuccess: true);
      _resumeScanning();
      return;
    }

    // 显示确认添加好友对话框
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(dialogL10n.addFriend),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar.proxied) : null,
                child: avatar.isEmpty ? Text(nickname.isNotEmpty ? nickname[0] : '?') : null,
              ),
              const SizedBox(height: 12),
              Text(nickname, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(dialogL10n.translate('add_friend_confirm_user').replaceAll('#{name}', nickname)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(dialogL10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(dialogL10n.translate('add_button')),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _showLoading(l10n.translate('sending_friend_request'));
      try {
        final response = await _friendApi.addFriend(
          userId: userId,
          message: l10n.translate('friend_request_via_qrcode'),
          source: 'qrcode',
        );
        Navigator.pop(context); // 关闭loading
        if (response.success) {
          _showSuccessAndClose(l10n.translate('friend_request_sent'));
        } else {
          _showError(response.message ?? l10n.translate('send_failed'));
        }
      } catch (e) {
        Navigator.pop(context);
        _showError('${l10n.translate('send_failed')}: $e');
      }
    } else {
      _resumeScanning();
    }
  }

  /// 处理群组二维码扫描结果
  Future<void> _handleGroupQRCode(Map<String, dynamic> groupData, bool isMember) async {
    final l10n = AppLocalizations.of(context)!;
    final groupId = groupData['id'];
    final groupName = groupData['name'] ?? 'Group';
    final avatar = groupData['avatar'] ?? '';
    final memberCount = groupData['member_count'] ?? 0;

    if (isMember) {
      // 已经是群成员，提示并返回
      _showSnackBar(l10n.translate('already_group_member'), isSuccess: true);
      _resumeScanning();
      return;
    }

    // 显示确认加入群聊对话框
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(dialogL10n.translate('join_group_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar.proxied) : null,
                child: avatar.isEmpty ? const Icon(Icons.group, size: 40) : null,
              ),
              const SizedBox(height: 12),
              Text(groupName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${dialogL10n.translate('member_count').replaceAll('{count}', '$memberCount')}'),
              const SizedBox(height: 8),
              Text(dialogL10n.translate('join_group_confirm_name').replaceAll('#{name}', groupName)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(dialogL10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(dialogL10n.translate('join_button')),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _showLoading(l10n.translate('applying_to_join'));
      try {
        final response = await _groupApi.joinGroup(groupId);
        Navigator.pop(context); // 关闭loading
        if (response.success) {
          _showSuccessAndClose(l10n.translate('joined_group_success'));
        } else {
          _showError(response.message ?? l10n.translate('join_failed'));
        }
      } catch (e) {
        Navigator.pop(context);
        _showError('${l10n.translate('join_failed')}: $e');
      }
    } else {
      _resumeScanning();
    }
  }

  Future<void> _handleAddFriend(String userIdStr) async {
    final l10n = AppLocalizations.of(context)!;
    // 显示确认对话框
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(dialogL10n.addFriend),
          content: Text(dialogL10n.translate('add_friend_confirm').replaceAll('#{id}', userIdStr)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(dialogL10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(dialogL10n.translate('add_button')),
            ),
          ],
        );
      },
    );

    if (result == true) {
      // 发送好友请求
      _showLoading(l10n.translate('sending_friend_request'));
      try {
        final userId = int.tryParse(userIdStr);
        if (userId != null) {
          final response = await _friendApi.addFriend(
            userId: userId,
            message: l10n.translate('friend_request_via_qrcode'),
            source: 'qrcode',
          );
          Navigator.pop(context); // 关闭loading
          if (response.success) {
            _showSuccessAndClose(l10n.translate('friend_request_sent'));
          } else {
            _showError(response.message ?? l10n.translate('send_failed'));
          }
        } else {
          Navigator.pop(context);
          _showError(l10n.translate('invalid_user_id'));
        }
      } catch (e) {
        Navigator.pop(context);
        _showError('${l10n.translate('send_failed')}: $e');
      }
    } else {
      _resumeScanning();
    }
  }

  Future<void> _handleJoinGroup(String groupId) async {
    final l10n = AppLocalizations.of(context)!;
    // 显示确认对话框
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(dialogL10n.translate('join_group_title')),
          content: Text(dialogL10n.translate('join_group_confirm').replaceAll('#{id}', groupId)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(dialogL10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(dialogL10n.translate('join_button')),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _showLoading(l10n.translate('applying_to_join'));
      try {
        final gid = int.tryParse(groupId);
        if (gid != null) {
          final response = await _groupApi.joinGroup(gid);
          Navigator.pop(context); // 关闭loading
          if (response.success) {
            _showSuccessAndClose(l10n.translate('joined_group_success'));
          } else {
            _showError(response.message ?? l10n.translate('join_failed'));
          }
        } else {
          Navigator.pop(context);
          _showError(l10n.translate('invalid_group_id'));
        }
      } catch (e) {
        Navigator.pop(context);
        _showError('${l10n.translate('join_failed')}: $e');
      }
    } else {
      _resumeScanning();
    }
  }

  Future<void> _handleUrl(String url) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(dialogL10n.translate('link_detected')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dialogL10n.translate('open_link_confirm')),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  url,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: Text(dialogL10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'copy'),
              child: Text(dialogL10n.copy),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'open'),
              child: Text(dialogL10n.translate('open_button')),
            ),
          ],
        );
      },
    );

    switch (result) {
      case 'open':
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showError(l10n.translate('cannot_open_link'));
          return;
        }
        if (mounted) Navigator.pop(context);
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: url));
        _showSnackBar(l10n.translate('copied_to_clipboard'), isSuccess: true);
        _resumeScanning();
        break;
      default:
        _resumeScanning();
    }
  }

  void _showScanResult(String result) {
    showDialog(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(dialogL10n.translate('scan_result')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  result,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resumeScanning();
              },
              child: Text(dialogL10n.translate('continue_scanning')),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: result));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(dialogL10n.translate('copied_to_clipboard'))),
                  );
                }
              },
              child: Text(dialogL10n.copy),
            ),
          ],
        );
      },
    );
  }

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : null,
      ),
    );
  }

  void _showSuccessAndClose(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
    _resumeScanning();
  }

  void _resumeScanning() {
    setState(() => _isProcessing = false);
    try {
      _scannerController?.start();
    } catch (e) {
      debugPrint('Resume scanning failed: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null && _scannerController != null) {
        setState(() => _isProcessing = true);
        // Web端可能需要使用bytes而不是path
        final result = await _scannerController!.analyzeImage(image.path);
        if (result != null && result.barcodes.isNotEmpty) {
          final code = result.barcodes.first.rawValue;
          if (code != null && code.isNotEmpty) {
            _handleQRCode(code);
            return;
          }
        }
        _showError(l10n.translate('no_qrcode_found'));
      }
    } catch (e) {
      debugPrint('从相册选择失败: $e');
      _showError('${l10n.translate('recognition_failed')}: ${kIsWeb ? l10n.translate('web_gallery_not_supported') : e.toString()}');
    }
  }

  void _toggleFlashlight() {
    if (!_supportsTorch) {
      final l10n = AppLocalizations.of(context)!;
      _showSnackBar(l10n.translate('platform_no_flashlight'));
      return;
    }
    _scannerController?.toggleTorch();
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanAreaSize = MediaQuery.of(context).size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.translate('scan_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: _pickImageFromGallery,
            tooltip: AppLocalizations.of(context)!.translate('select_from_gallery'),
          ),
        ],
      ),
      body: _buildBody(scanAreaSize),
    );
  }

  Widget _buildBody(double scanAreaSize) {
    // 初始化中
    if (!_isInitialized) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(l10n.translate('starting_camera'), style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    // 没有权限
    if (!_hasPermission) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white38),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? l10n.translate('cannot_access_camera'),
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  _scannerController?.dispose();
                  _scannerController = null;
                  setState(() {
                    _isInitialized = false;
                    _hasPermission = true;
                    _errorMessage = null;
                  });
                  _initializeScanner();
                },
                icon: const Icon(Icons.refresh),
                label: Text(l10n.translate('reauthorize')),
              ),
              const SizedBox(height: 16),
              // 从相册选择按钮（备用方案）
              OutlinedButton.icon(
                onPressed: _pickImageFromGallery,
                icon: const Icon(Icons.photo_library, color: Colors.white70),
                label: Text(l10n.translate('select_from_gallery'), style: const TextStyle(color: Colors.white70)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38),
                ),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '💡 ${l10n.translate('web_scan_tip')}',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('web_scan_instructions'),
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                        textAlign: TextAlign.left,
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

    // 正常扫描界面
    return Stack(
      children: [
        // 相机预览
        if (_scannerController != null)
          MobileScanner(
            controller: _scannerController!,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              // 相机启动失败时显示错误界面
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _hasPermission) {
                  final l10n = AppLocalizations.of(context)!;
                  setState(() {
                    _hasPermission = false;
                    _errorMessage = _getErrorMessage(error.toString(), l10n);
                  });
                }
              });
              return const SizedBox.shrink();
            },
          ),
        // 扫描框遮罩
        _buildScanOverlay(scanAreaSize),
        // 底部工具栏
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomBar(),
        ),
      ],
    );
  }

  Widget _buildScanOverlay(double scanAreaSize) {
    return Stack(
      children: [
        // 半透明遮罩
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.6),
            BlendMode.srcOut,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: scanAreaSize,
                  height: scanAreaSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 扫描框边框
        Center(
          child: Container(
            width: scanAreaSize,
            height: scanAreaSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
            ),
            child: Stack(
              children: [
                // 四角装饰
                ..._buildCorners(scanAreaSize),
                // 扫描线动画
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Positioned(
                      top: _animation.value * (scanAreaSize - 4),
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFF07C160),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // 提示文字
        Center(
          child: Padding(
            padding: EdgeInsets.only(top: scanAreaSize + 40),
            child: Text(
              AppLocalizations.of(context)!.translate('scan_hint'),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCorners(double size) {
    const cornerLength = 20.0;
    const cornerWidth = 3.0;
    const cornerColor = Color(0xFF07C160);

    return [
      // 左上角
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: cornerLength,
          height: cornerWidth,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
          ),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: cornerWidth,
          height: cornerLength,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
          ),
        ),
      ),
      // 右上角
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: cornerLength,
          height: cornerWidth,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(topRight: Radius.circular(12)),
          ),
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: cornerWidth,
          height: cornerLength,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(topRight: Radius.circular(12)),
          ),
        ),
      ),
      // 左下角
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: cornerLength,
          height: cornerWidth,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12)),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: cornerWidth,
          height: cornerLength,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12)),
          ),
        ),
      ),
      // 右下角
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: cornerLength,
          height: cornerWidth,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(12)),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: cornerWidth,
          height: cornerLength,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(12)),
          ),
        ),
      ),
    ];
  }

  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.fromLTRB(40, 24, 40, MediaQuery.of(context).padding.bottom + 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 手电筒（仅移动端显示）
          if (_supportsTorch)
            _buildBottomButton(
              icon: Icon(
                _isTorchOn ? Icons.flashlight_on : Icons.flashlight_off,
                color: _isTorchOn ? const Color(0xFF07C160) : Colors.white,
                size: 28,
              ),
              label: l10n.translate('flashlight'),
              onTap: _toggleFlashlight,
            ),
          // 我的二维码
          _buildBottomButton(
            icon: const Icon(Icons.qr_code, color: Colors.white, size: 28),
            label: l10n.translate('my_qrcode'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const MyQRCodeScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(child: icon),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
