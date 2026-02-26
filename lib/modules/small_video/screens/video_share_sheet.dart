/// 视频转发目标选择底部面板
/// 选择好友或群组后发送视频分享卡片消息

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/api/group_api.dart';
import 'package:im_client/api/conversation_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/models/user.dart';
import 'package:im_client/models/group.dart';
import 'package:im_client/modules/small_video/models/small_video.dart';
import 'package:provider/provider.dart';
import 'package:im_client/modules/small_video/providers/small_video_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../utils/image_proxy.dart';

class VideoShareSheet extends StatefulWidget {
  final SmallVideo video;

  const VideoShareSheet({super.key, required this.video});

  @override
  State<VideoShareSheet> createState() => _VideoShareSheetState();
}

class _VideoShareSheetState extends State<VideoShareSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendApi _friendApi = FriendApi(ApiClient());
  final GroupApi _groupApi = GroupApi(ApiClient());
  final ConversationApi _conversationApi = ConversationApi(ApiClient());

  List<Friend> _friends = [];
  List<Group> _groups = [];
  bool _isLoading = true;
  bool _isSending = false;

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
    try {
      final results = await Future.wait([
        _friendApi.getFriendList(),
        _groupApi.getMyGroups(),
      ]);
      if (mounted) {
        setState(() {
          _friends = results[0] as List<Friend>;
          _groups = results[1] as List<Group>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return EnvConfig.instance.getFileUrl(url);
  }

  Future<void> _sendShare() async {
    if (_selectedUserIds.isEmpty && _selectedGroupIds.isEmpty) return;
    setState(() => _isSending = true);

    final video = widget.video;
    final extra = jsonEncode({
      'video_id': video.id,
      'title': video.title,
      'cover_url': video.coverUrl,
      'video_url': video.videoUrl,
      'author_name': video.user?.nickname ?? '',
      'author_avatar': video.user?.avatar ?? '',
      'duration': video.duration,
      'description': video.description,
    });

    try {
      // Send to each selected friend
      for (final userId in _selectedUserIds) {
        await _conversationApi.sendMessage(
          msgId: const Uuid().v4(),
          toUserId: userId,
          type: MessageType.videoShare,
          content: video.coverUrl,
          extra: extra,
        );
      }

      // Send to each selected group
      for (final groupId in _selectedGroupIds) {
        await _conversationApi.sendMessage(
          msgId: const Uuid().v4(),
          groupId: groupId,
          type: MessageType.videoShare,
          content: video.coverUrl,
          extra: extra,
        );
      }

      // Update share count via provider (calls API + optimistic update)
      if (mounted) {
        context.read<SmallVideoProvider>().shareVideo(video.id);
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('sv_share_success'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedCount = _selectedUserIds.length + _selectedGroupIds.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title + Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      l10n.translate('sv_share_to'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Tab bar
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: l10n.translate('contacts')),
                  Tab(text: l10n.groupChat),
                ],
              ),

              // List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFriendList(l10n),
                          _buildGroupList(l10n),
                        ],
                      ),
              ),

              // Bottom send button
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed:
                          selectedCount > 0 && !_isSending ? _sendShare : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              selectedCount > 0
                                  ? '${l10n.translate('sv_share_send')}($selectedCount)'
                                  : l10n.translate('sv_share_send'),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFriendList(AppLocalizations l10n) {
    if (_friends.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('no_friends'),
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        final isSelected = _selectedUserIds.contains(friend.friendId);
        final avatarUrl = _getFullUrl(friend.friend.avatar);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
            child: avatarUrl.isEmpty
                ? const Icon(Icons.person, color: AppColors.primary)
                : null,
          ),
          title: Text(friend.displayName),
          trailing: _buildCheckbox(isSelected),
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedUserIds.remove(friend.friendId);
              } else {
                _selectedUserIds.add(friend.friendId);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildGroupList(AppLocalizations l10n) {
    if (_groups.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('no_groups'),
          style: TextStyle(color: AppColors.textSecondary),
        ),
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
            backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
            backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
            child: avatarUrl.isEmpty
                ? const Icon(Icons.group, color: AppColors.secondary)
                : null,
          ),
          title: Text(group.name),
          subtitle: Text(
            l10n
                .translate('people_count')
                .replaceAll('{count}', '${group.memberCount}'),
          ),
          trailing: _buildCheckbox(isSelected),
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedGroupIds.remove(group.id);
              } else {
                _selectedGroupIds.add(group.id);
              }
            });
          },
        );
      },
    );
  }

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
}
