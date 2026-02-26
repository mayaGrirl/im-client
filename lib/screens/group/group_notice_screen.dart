/// 群公告页面
/// 显示和编辑群公告

import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';

class GroupNoticeScreen extends StatefulWidget {
  final int groupId;
  final String? notice;
  final bool canEdit;

  const GroupNoticeScreen({
    super.key,
    required this.groupId,
    this.notice,
    this.canEdit = false,
  });

  @override
  State<GroupNoticeScreen> createState() => _GroupNoticeScreenState();
}

class _GroupNoticeScreenState extends State<GroupNoticeScreen> {
  final GroupApi _groupApi = GroupApi(ApiClient());
  final TextEditingController _controller = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.notice ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveNotice() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);

    final res = await _groupApi.updateGroup(
      widget.groupId,
      notice: _controller.text,
    );

    setState(() => _isSaving = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noticeUpdated)),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? l10n.saveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupNotice),
        actions: [
          if (widget.canEdit && !_isEditing)
            TextButton(
              onPressed: () => setState(() => _isEditing = true),
              child: Text(l10n.edit),
            ),
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _saveNotice,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
        ],
      ),
      body: _isEditing ? _buildEditView(l10n) : _buildDisplayView(l10n),
    );
  }

  Widget _buildDisplayView(AppLocalizations l10n) {
    final notice = widget.notice;

    if (notice == null || notice.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.announcement_outlined,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noNotice,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            if (widget.canEdit) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit),
                label: Text(l10n.publishNotice),
              ),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(
          notice,
          style: const TextStyle(
            fontSize: 16,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildEditView(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: l10n.enterNoticeContent,
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noticeWillNotifyAll,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
