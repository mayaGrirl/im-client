 /// 群设置页面
/// 群主/管理员设置进群方式等

import 'package:flutter/material.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/models/group.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/l10n/app_localizations.dart';

class GroupSettingsScreen extends StatefulWidget {
  final Group group;
  final bool isOwner;

  const GroupSettingsScreen({
    super.key,
    required this.group,
    this.isOwner = false,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final GroupApi _groupApi = GroupApi(ApiClient());

  late int _joinMode;

  // 付费群设置
  late bool _isPaidGroup;
  late int _priceType;       // 价格类型：1一次性 2包月 3包年
  late int _allowTrialDays;  // 试用天数
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _trialDaysController = TextEditingController();
  PaidGroupConfig? _paidGroupConfig;

  // 群通话设置
  late bool _allowGroupCall;
  late bool _allowVoiceCall;
  late bool _allowVideoCall;
  late bool _memberCanInitiateCall;
  late int _maxCallParticipants;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _joinMode = widget.group.joinMode;
    _isPaidGroup = widget.group.isPaid;
    _priceType = widget.group.priceType;
    _allowTrialDays = widget.group.allowTrialDays;
    _priceController.text = widget.group.price > 0 ? widget.group.price.toInt().toString() : '';
    _trialDaysController.text = _allowTrialDays > 0 ? _allowTrialDays.toString() : '';
    // 初始化群通话设置
    _allowGroupCall = widget.group.allowGroupCall;
    _allowVoiceCall = widget.group.allowVoiceCall;
    _allowVideoCall = widget.group.allowVideoCall;
    _memberCanInitiateCall = widget.group.memberCanInitiateCall;
    _maxCallParticipants = widget.group.maxCallParticipants;
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
    _priceController.dispose();
    _trialDaysController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context)!;
    if (!widget.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.onlyOwnerCanModify)),
      );
      return;
    }

    // 验证付费群价格
    if (_isPaidGroup) {
      final price = double.tryParse(_priceController.text) ?? 0;
      if (price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('please_enter_valid_price'))),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    // 保存进群方式
    final result = await _groupApi.updateGroupSettings(
      widget.group.id,
      joinMode: _joinMode,
    );

    if (!result.success) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? l10n.saveFailed)),
      );
      return;
    }

    // 保存付费群设置（分成比例由管理端设置，群主只能设置价格、类型、试用天数）
    final price = double.tryParse(_priceController.text) ?? 0;
    final trialDays = int.tryParse(_trialDaysController.text) ?? 0;
    final paidResult = await _groupApi.updatePaidGroupSettings(
      widget.group.id,
      isPaid: _isPaidGroup,
      price: _isPaidGroup ? price : 0,
      priceType: _isPaidGroup ? _priceType : null,
      allowTrialDays: _isPaidGroup ? trialDays : null,
    );

    setState(() => _isLoading = false);

    if (paidResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsSaved)),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(paidResult.message ?? l10n.saveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupSettings),
        actions: [
          if (widget.isOwner)
            TextButton(
              onPressed: _isLoading ? null : _saveSettings,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
        ],
      ),
      body: ListView(
        children: [
          // 进群方式
          _buildSectionTitle(l10n.joinMethod),
          _buildJoinModeSection(l10n),
          // 付费群设置（仅群主可见）
          if (widget.isOwner) ...[
            _buildSectionTitle(l10n.translate('paid_group_settings')),
            _buildPaidGroupSection(l10n),
          ],
          // 群通话设置（仅付费群且群主可见）
          if (widget.isOwner && _isPaidGroup) ...[
            _buildSectionTitle(l10n.translate('group_call_settings')),
            _buildGroupCallSection(l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildJoinModeSection(AppLocalizations l10n) {
    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          _buildJoinModeItem(
            title: l10n.joinModeFree,
            subtitle: l10n.anyoneCanJoin,
            value: GroupJoinMode.free,
            icon: Icons.lock_open,
            color: Colors.green,
          ),
          const Divider(indent: 56),
          _buildJoinModeItem(
            title: l10n.joinModeVerify,
            subtitle: l10n.requiresAdminApproval,
            value: GroupJoinMode.verify,
            icon: Icons.verified_user,
            color: Colors.orange,
          ),
          const Divider(indent: 56),
          _buildJoinModeItem(
            title: l10n.joinModeInvite,
            subtitle: l10n.onlyThroughInvitation,
            value: GroupJoinMode.invite,
            icon: Icons.person_add,
            color: Colors.purple,
          ),
          const Divider(indent: 56),
          _buildJoinModeItem(
            title: l10n.joinModeForbid,
            subtitle: l10n.pausedAcceptingMembers,
            value: GroupJoinMode.forbid,
            icon: Icons.block,
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildJoinModeItem({
    required String title,
    required String subtitle,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _joinMode == value;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppColors.textHint,
          fontSize: 12,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : const Icon(Icons.circle_outlined, color: AppColors.textHint),
      onTap: widget.isOwner
          ? () {
              setState(() => _joinMode = value);
            }
          : null,
    );
  }

  Widget _buildPaidGroupSection(AppLocalizations l10n) {
    final config = _paidGroupConfig;
    // 如果当前已是付费群，允许继续设置；否则检查是否还能创建付费群
    final canEnablePaidGroup = widget.group.isPaid || (config?.canCreatePaidGroup ?? false);

    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          // 付费群开关
          SwitchListTile(
            secondary: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.monetization_on, color: Colors.amber),
            ),
            title: Text(l10n.translate('paid_group')),
            subtitle: Text(
              canEnablePaidGroup
                  ? l10n.translate('paid_group_tip')
                  : l10n.translate('paid_group_level_limit'),
              style: TextStyle(
                color: canEnablePaidGroup ? AppColors.textHint : AppColors.error,
                fontSize: 12,
              ),
            ),
            value: _isPaidGroup,
            onChanged: canEnablePaidGroup
                ? (value) {
                    setState(() => _isPaidGroup = value);
                  }
                : null,
          ),

          // 等级限制提示
          if (!canEnablePaidGroup && config != null) ...[
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
            const Divider(indent: 16, endIndent: 16),

            // 价格类型选择
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.schedule, color: Colors.blue),
              ),
              title: Text(l10n.translate('price_type')),
              subtitle: Text(
                l10n.translate('price_type_tip'),
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
              trailing: DropdownButton<int>(
                value: _priceType,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 1, child: Text(l10n.translate('price_type_once'))),
                  DropdownMenuItem(value: 2, child: Text(l10n.translate('price_type_monthly'))),
                  DropdownMenuItem(value: 3, child: Text(l10n.translate('price_type_yearly'))),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _priceType = value);
                },
              ),
            ),
            const Divider(indent: 56, endIndent: 16),

            // 价格输入
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.attach_money, color: Colors.green),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      decoration: InputDecoration(
                        labelText: l10n.translate('group_price'),
                        hintText: l10n.translate('enter_price'),
                        suffixText: l10n.translate('gold_beans'),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(indent: 56, endIndent: 16),

            // 试用天数
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.timer, color: Colors.orange),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _trialDaysController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.translate('trial_days'),
                        hintText: l10n.translate('trial_days_hint'),
                        suffixText: l10n.translate('days'),
                        helperText: l10n.translate('trial_days_tip'),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 分成比例显示
            if (config != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
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
              ),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupCallSection(AppLocalizations l10n) {
    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          // 群通话总开关
          SwitchListTile(
            secondary: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.call, color: Colors.blue),
            ),
            title: Text(l10n.translate('allow_group_call')),
            subtitle: Text(
              l10n.translate('allow_group_call_tip'),
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 12,
              ),
            ),
            value: _allowGroupCall,
            onChanged: (value) {
              setState(() {
                _allowGroupCall = value;
                if (!value) {
                  // 关闭总开关时，同时关闭语音和视频
                  _allowVoiceCall = false;
                  _allowVideoCall = false;
                }
              });
              _saveCallSettings();
            },
          ),

          // 仅在总开关打开时显示详细设置
          if (_allowGroupCall) ...[
            const Divider(indent: 56, endIndent: 16),

            // 语音通话开关
            SwitchListTile(
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mic, color: Colors.green),
              ),
              title: Text(l10n.translate('allow_voice_call')),
              subtitle: Text(
                l10n.translate('allow_voice_call_tip'),
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                ),
              ),
              value: _allowVoiceCall,
              onChanged: (value) {
                setState(() => _allowVoiceCall = value);
                _saveCallSettings();
              },
            ),
            const Divider(indent: 56, endIndent: 16),

            // 视频通话开关
            SwitchListTile(
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.videocam, color: Colors.purple),
              ),
              title: Text(l10n.translate('allow_video_call')),
              subtitle: Text(
                l10n.translate('allow_video_call_tip'),
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                ),
              ),
              value: _allowVideoCall,
              onChanged: (value) {
                setState(() => _allowVideoCall = value);
                _saveCallSettings();
              },
            ),
            const Divider(indent: 56, endIndent: 16),

            // 成员发起权限
            SwitchListTile(
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: Colors.orange),
              ),
              title: Text(l10n.translate('member_can_initiate_call')),
              subtitle: Text(
                l10n.translate('member_can_initiate_call_tip'),
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                ),
              ),
              value: _memberCanInitiateCall,
              onChanged: (value) {
                setState(() => _memberCanInitiateCall = value);
                _saveCallSettings();
              },
            ),
            const Divider(indent: 56, endIndent: 16),

            // 最大参与人数
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.group, color: Colors.teal),
              ),
              title: Text(l10n.translate('max_call_participants')),
              subtitle: Text(
                l10n.translate('max_call_participants_tip'),
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                ),
              ),
              trailing: DropdownButton<int>(
                value: _maxCallParticipants,
                underline: const SizedBox(),
                items: [4, 9, 16, 25, 36, 49].map((count) {
                  return DropdownMenuItem<int>(
                    value: count,
                    child: Text('$count ${l10n.translate('people')}'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _maxCallParticipants = value);
                    _saveCallSettings();
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveCallSettings() async {
    final result = await _groupApi.updateGroupCallSettings(
      widget.group.id,
      allowGroupCall: _allowGroupCall,
      allowVoiceCall: _allowVoiceCall,
      allowVideoCall: _allowVideoCall,
      memberCanInitiateCall: _memberCanInitiateCall,
      maxCallParticipants: _maxCallParticipants,
    );
    if (!result.success && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? l10n.saveFailed)),
      );
    }
  }
}
