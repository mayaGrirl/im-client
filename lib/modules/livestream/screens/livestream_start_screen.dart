/// 开播准备页面
/// 设置直播标题、分类、封面等

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/upload_api.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/modules/livestream/providers/livestream_provider.dart';
import 'package:im_client/modules/livestream/screens/livestream_viewer_screen.dart';

class LivestreamStartScreen extends StatefulWidget {
  const LivestreamStartScreen({super.key});

  @override
  State<LivestreamStartScreen> createState() => _LivestreamStartScreenState();
}

class _LivestreamStartScreenState extends State<LivestreamStartScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  int? _selectedCategoryId;
  bool _isPaid = false;
  final _ticketPriceController = TextEditingController(text: '100');
  int _ticketPriceType = 1;
  bool _allowPreview = false;
  int _previewDuration = 60;
  bool _creating = false;
  // 按分钟付费
  int _roomType = 0; // 0=免费, 1=按分钟付费
  final _pricePerMinController = TextEditingController(text: '10');
  int _trialSeconds = 30;
  bool _allowPaidCall = false;
  final _paidCallRateController = TextEditingController(text: '100');
  int _paidCallShareRatio = 70;
  bool _isScheduled = false;
  DateTime? _scheduledAt;
  File? _coverImage;
  Uint8List? _coverBytes; // Web平台用字节数据
  String? _coverUrl;
  bool _uploadingCover = false;
  // 分成比例
  int _anchorShareRatio = 70;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LivestreamProvider>(context, listen: false).loadCategories();
    });
    _fetchShareRatio();
  }

  Future<void> _fetchShareRatio() async {
    try {
      final resp = await ApiClient().get('/config/paid');
      if (resp != null && resp.success && resp.data is Map) {
        final data = resp.data as Map;
        if (data.containsKey('paid_livestream_anchor_share_ratio')) {
          final val = int.tryParse(data['paid_livestream_anchor_share_ratio']?.toString() ?? '');
          if (val != null && mounted) {
            setState(() => _anchorShareRatio = val);
          }
        }
        if (data.containsKey('paid_call_anchor_share_ratio')) {
          final val = int.tryParse(data['paid_call_anchor_share_ratio']?.toString() ?? '');
          if (val != null && mounted) {
            setState(() => _paidCallShareRatio = val);
          }
        }
        if (data.containsKey('paid_session_rate_per_minute')) {
          final val = data['paid_session_rate_per_minute']?.toString() ?? '100';
          if (mounted) {
            setState(() => _paidCallRateController.text = val);
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _ticketPriceController.dispose();
    _pricePerMinController.dispose();
    _paidCallRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('start_livestream'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图
            Text(l10n.translate('livestream_cover'), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickCoverImage,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  image: (_coverBytes != null || _coverImage != null)
                      ? DecorationImage(
                          image: kIsWeb
                              ? MemoryImage(_coverBytes!) as ImageProvider
                              : FileImage(_coverImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _uploadingCover
                    ? const Center(child: CircularProgressIndicator())
                    : (_coverBytes == null && _coverImage == null)
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(l10n.translate('click_upload_cover'), style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(l10n.translate('recommended_size'), style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            ],
                          )
                        : null,
              ),
            ),
            const SizedBox(height: 16),

            // 标题
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.translate('livestream_title'),
                hintText: l10n.translate('give_title'),
                border: const OutlineInputBorder(),
              ),
              maxLength: 200,
            ),
            const SizedBox(height: 12),

            // 描述
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: l10n.translate('livestream_desc'),
                hintText: l10n.translate('describe_content'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 16),

            // 分类
            Consumer<LivestreamProvider>(
              builder: (context, provider, _) {
                if (provider.categories.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.translate('livestream_category'), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: provider.categories.map((cat) {
                        final locale = Localizations.localeOf(context).languageCode;
                        return ChoiceChip(
                          label: Text(cat.localizedName(locale)),
                          selected: _selectedCategoryId == cat.id,
                          onSelected: (_) => setState(() => _selectedCategoryId = cat.id),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // 付费设置
            const Divider(),
            SwitchListTile(
              title: Text(l10n.translate('ticket_paid')),
              subtitle: Text(l10n.translate('ticket_paid_desc')),
              value: _isPaid,
              onChanged: _roomType == 1 ? null : (v) => setState(() => _isPaid = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_isPaid) ...[
              TextField(
                controller: _ticketPriceController,
                decoration: InputDecoration(
                  labelText: l10n.translate('livestream_start_ticket_price_beans'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(l10n.translate('livestream_start_ticket_type')),
                  ChoiceChip(
                    label: Text(l10n.translate('livestream_start_single_ticket')),
                    selected: _ticketPriceType == 1,
                    onSelected: (_) => setState(() => _ticketPriceType = 1),
                  ),
                  // const SizedBox(width: 8),
                  // ChoiceChip(
                  //   label: Text(l10n.translate('monthly_ticket')),
                  //   selected: _ticketPriceType == 2,
                  //   onSelected: (_) => setState(() => _ticketPriceType = 2),
                  // ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  l10n.translate('livestream_start_anchor_share').replaceAll('{ratio}', _anchorShareRatio.toString()).replaceAll('{platform}', (100 - _anchorShareRatio).toString()),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
              SwitchListTile(
                title: Text(l10n.translate('livestream_start_allow_preview')),
                value: _allowPreview,
                onChanged: (v) => setState(() => _allowPreview = v),
                contentPadding: EdgeInsets.zero,
              ),
              if (_allowPreview)
                Slider(
                  value: _previewDuration.toDouble(),
                  min: 10,
                  max: 300,
                  divisions: 29,
                  label: l10n.translate('preview_seconds').replaceAll('{seconds}', _previewDuration.toString()),
                  onChanged: (v) => setState(() => _previewDuration = v.round()),
                ),
            ],

            // 按分钟付费
            SwitchListTile(
              title: Text(l10n.translate('per_minute_billing')),
              subtitle: Text(l10n.translate('per_minute_desc')),
              value: _roomType == 1,
              onChanged: _isPaid ? null : (v) => setState(() {
                _roomType = v ? 1 : 0;
              }),
              contentPadding: EdgeInsets.zero,
            ),
            if (_roomType == 1) ...[
              TextField(
                controller: _pricePerMinController,
                decoration: InputDecoration(
                  labelText: l10n.translate('price_per_minute_beans'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  l10n.translate('anchor_share').replaceAll('{ratio}', _anchorShareRatio.toString()).replaceAll('{platform}', (100 - _anchorShareRatio).toString()),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(l10n.translate('free_trial')),
                  Expanded(
                    child: Slider(
                      value: _trialSeconds.toDouble(),
                      min: 0,
                      max: 300,
                      divisions: 30,
                      label: l10n.translate('preview_seconds').replaceAll('{seconds}', _trialSeconds.toString()),
                      onChanged: (v) => setState(() => _trialSeconds = v.round()),
                    ),
                  ),
                  Text(l10n.translate('preview_seconds').replaceAll('{seconds}', _trialSeconds.toString())),
                ],
              ),
              SwitchListTile(
                title: Text(l10n.translate('allow_paid_call')),
                subtitle: Text(l10n.translate('paid_call_subtitle')),
                value: _allowPaidCall,
                onChanged: (v) => setState(() => _allowPaidCall = v),
                contentPadding: EdgeInsets.zero,
              ),
              if (_allowPaidCall) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _paidCallRateController,
                  decoration: InputDecoration(
                    labelText: l10n.translate('paid_call_rate_beans'),
                    border: const OutlineInputBorder(),
                    hintText: l10n.translate('use_system_default'),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.translate('paid_call_share_info').replaceAll('{ratio}', _paidCallShareRatio.toString()).replaceAll('{platform}', (100 - _paidCallShareRatio).toString()),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ],

            // 预约设置
            const Divider(),
            SwitchListTile(
              title: Text(l10n.translate('schedule_livestream')),
              subtitle: Text(l10n.translate('schedule_desc')),
              value: _isScheduled,
              onChanged: (v) => setState(() {
                _isScheduled = v;
                if (v && _scheduledAt == null) {
                  _scheduledAt = DateTime.now().add(const Duration(hours: 1));
                }
              }),
              contentPadding: EdgeInsets.zero,
            ),
            if (_isScheduled) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _scheduledAt != null
                      ? '${_scheduledAt!.year}-${_scheduledAt!.month.toString().padLeft(2, '0')}-${_scheduledAt!.day.toString().padLeft(2, '0')} ${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')}'
                      : l10n.translate('select_time'),
                ),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _scheduledAt ?? DateTime.now().add(const Duration(hours: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date != null && mounted) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(
                        _scheduledAt ?? DateTime.now().add(const Duration(hours: 1)),
                      ),
                    );
                    if (time != null && mounted) {
                      setState(() {
                        _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      });
                    }
                  }
                },
              ),
            ],

            const SizedBox(height: 24),

            // 开始直播按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _creating ? null : _startLive,
                icon: _creating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.videocam),
                label: Text(_creating ? l10n.translate('creating') : (_isScheduled ? l10n.translate('schedule_start') : l10n.translate('start_livestream'))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCoverImage() async {
    final l10n = AppLocalizations.of(context)!;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    // 读取字节数据（Web和移动端通用）
    final bytes = await picked.readAsBytes();

    setState(() {
      _coverBytes = bytes;
      if (!kIsWeb) {
        _coverImage = File(picked.path);
      }
      _uploadingCover = true;
    });

    try {
      final uploadApi = UploadApi(ApiClient());
      // Web传字节，移动端传File
      final dynamic uploadData = kIsWeb ? bytes.toList() : _coverImage!;
      final result = await uploadApi.uploadImage(uploadData, type: 'image', filename: 'livestream_cover.jpg');
      if (result != null && result.url.isNotEmpty) {
        setState(() => _coverUrl = result.url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('cover_upload_failed'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('cover_upload_error').replaceAll('{error}', e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _startLive() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('enter_livestream_title'))),
      );
      return;
    }

    setState(() => _creating = true);

    final provider = Provider.of<LivestreamProvider>(context, listen: false);

    String? scheduledAtStr;
    if (_isScheduled && _scheduledAt != null) {
      scheduledAtStr = _scheduledAt!.toUtc().toIso8601String();
    }

    final room = await provider.createLivestream(
      title: title,
      description: _descController.text.trim(),
      coverUrl: _coverUrl,
      categoryId: _selectedCategoryId,
      type: 0,
      isPaid: _isPaid,
      ticketPrice: int.tryParse(_ticketPriceController.text) ?? 100,
      ticketPriceType: _ticketPriceType,
      allowPreview: _allowPreview,
      previewDuration: _previewDuration,
      scheduledAt: scheduledAtStr,
      roomType: _roomType,
      pricePerMin: int.tryParse(_pricePerMinController.text) ?? 10,
      trialSeconds: _trialSeconds,
      allowPaidCall: _allowPaidCall,
      paidCallRate: int.tryParse(_paidCallRateController.text) ?? 0,
    );

    if (room != null) {
      if (_isScheduled) {
        // 预约成功，返回
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('schedule_success'))),
          );
          Navigator.pop(context, true);
        }
      } else {
        // 开始直播
        final started = await provider.startLivestream(room.id);
        if (started && mounted) {
          // 进入直播间画面（主播模式）
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LivestreamViewerScreen(
                livestreamId: room.id,
                isAnchor: true,
              ),
            ),
          );
        }
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? l10n.translate('create_failed'))),
      );
    }

    if (mounted) setState(() => _creating = false);
  }
}
