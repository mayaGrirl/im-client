/// 应用国际化
/// 管理多语言支持

import 'package:flutter/material.dart';

// 导入各语言包文件
import 'strings_zh_cn.dart';
import 'strings_zh_tw.dart';
import 'strings_en.dart';
import 'strings_fr.dart';
import 'strings_hi.dart';

/// 支持的语言列表
class AppLocalizations {
  final Locale locale;
  static final RegExp _hanRegex = RegExp(r'[\u4E00-\u9FFF]');

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// 支持的语言
  static const List<Locale> supportedLocales = [
    Locale('zh', 'CN'), // 简体中文
    Locale('zh', 'TW'), // 繁体中文
    Locale('en', 'US'), // 英语
    Locale('fr', 'FR'), // 法语
    Locale('hi', 'IN'), // 印地语
  ];

  /// 获取当前语言的翻译
  Map<String, String> get _localizedStrings {
    switch (locale.languageCode) {
      case 'en':
        return enStrings;
      case 'zh':
        if (locale.countryCode == 'TW') {
          return zhTWStrings;
        }
        return zhCNStrings;
      case 'fr':
        return frStrings;
      case 'hi':
        return hiStrings;
      default:
        return zhCNStrings;
    }
  }

  /// 获取翻译文本
  String translate(String key) {
    final translated = _localizedStrings[key];
    if (translated == null) {
      return enStrings[key] ?? key;
    }

    // 非中文语言环境下，如果翻译文本意外返回了中文，回退到英文，避免页面出现中英混杂。
    if (locale.languageCode != 'zh' && _hanRegex.hasMatch(translated)) {
      return enStrings[key] ?? translated;
    }

    return translated;
  }

  // ============ 快捷访问器 ============

  // 通用
  String get appName => translate('app_name');
  String get confirm => translate('confirm');
  String get cancel => translate('cancel');
  String get save => translate('save');
  String get delete => translate('delete');
  String get edit => translate('edit');
  String get search => translate('search');
  String get loading => translate('loading');
  String get success => translate('success');
  String get failed => translate('failed');
  String get retry => translate('retry');
  String get noData => translate('no_data');
  String get networkError => translate('network_error');
  String get unknownError => translate('unknown_error');

  // 登录/注册
  String get login => translate('login');
  String get logout => translate('logout');
  String get register => translate('register');
  String get username => translate('username');
  String get password => translate('password');
  String get confirmPassword => translate('confirm_password');
  String get phone => translate('phone');
  String get email => translate('email');
  String get verifyCode => translate('verify_code');
  String get forgotPassword => translate('forgot_password');
  String get loginSuccess => translate('login_success');
  String get loginFailed => translate('login_failed');
  String get logoutConfirm => translate('logout_confirm');

  // 首页
  String get messages => translate('messages');
  String get contacts => translate('contacts');
  String get discover => translate('discover');
  String get profile => translate('profile');

  // 聊天
  String get chat => translate('chat');
  String get sendMessage => translate('send_message');
  String get inputMessage => translate('input_message');
  String get voice => translate('voice');
  String get image => translate('image');
  String get video => translate('video');
  String get playFailed => translate('play_failed');
  String get loadVideoFailed => translate('load_video_failed');
  String get file => translate('file');
  String get location => translate('location');
  String get recall => translate('recall');
  String get copy => translate('copy');
  String get forward => translate('forward');
  String get reply => translate('reply');
  String get messageRecalled => translate('message_recalled');
  String get holdToTalk => translate('hold_to_talk');
  String get releaseToSend => translate('release_to_send');
  String get releaseToCancel => translate('release_to_cancel');

  // 联系人
  String get newFriend => translate('new_friend');
  String get groupChat => translate('group_chat');
  String get addFriend => translate('add_friend');
  String get friendRequest => translate('friend_request');
  String get accept => translate('accept');
  String get reject => translate('reject');
  String get sendRequest => translate('send_request');
  String get requestSent => translate('request_sent');
  String get friendAdded => translate('friend_added');

  // 群组
  String get createGroup => translate('create_group');
  String get groupName => translate('group_name');
  String get groupNotice => translate('group_notice');
  String get groupMembers => translate('group_members');
  String get groupSettings => translate('group_settings');
  String get inviteMembers => translate('invite_members');
  String get removeMembers => translate('remove_members');
  String get leaveGroup => translate('leave_group');
  String get dismissGroup => translate('dismiss_group');
  String get groupOwner => translate('group_owner');
  String get groupAdmin => translate('group_admin');
  String get groupMember => translate('group_member');
  String get muteAll => translate('mute_all');
  String get shareGroup => translate('share_group');
  String get joinGroup => translate('join_group');
  String get applyJoin => translate('apply_join');
  String get joinMode => translate('join_mode');
  String get joinModeFree => translate('join_mode_free');
  String get joinModeVerify => translate('join_mode_verify');
  String get joinModeQuestion => translate('join_mode_question');
  String get joinModeInvite => translate('join_mode_invite');
  String get joinModeForbid => translate('join_mode_forbid');

  // 发现
  String get moments => translate('moments');
  String get scan => translate('scan');
  String get shake => translate('shake');
  String get nearby => translate('nearby');

  // 个人
  String get settings => translate('settings');
  String get nickname => translate('nickname');
  String get avatar => translate('avatar');
  String get gender => translate('gender');
  String get male => translate('male');
  String get female => translate('female');
  String get signature => translate('signature');
  String get qrCode => translate('qr_code');
  String get accountSecurity => translate('account_security');
  String get notification => translate('notification');
  String get privacy => translate('privacy');
  String get general => translate('general');
  String get about => translate('about');
  String get feedback => translate('feedback');
  String get version => translate('version');
  String get language => translate('language');
  String get darkMode => translate('dark_mode');
  String get clearCache => translate('clear_cache');

  // 通话
  String get voiceCall => translate('voice_call');
  String get videoCall => translate('video_call');
  String get inCall => translate('in_call');
  String get incomingCall => translate('incoming_call');
  String get calling => translate('calling');
  String get connecting => translate('connecting');
  String get callEnded => translate('call_ended');
  String get answer => translate('answer');
  String get hangUp => translate('hang_up');
  String get speaker => translate('speaker');
  String get switchCamera => translate('switch_camera');
  String get cameraSwitched => translate('camera_switched');
  String get turnOnCameraFirst => translate('turn_on_camera_first');
  String get cameraSwitchNotSupported => translate('camera_switch_not_supported');
  String get cameraSwitchFailed => translate('camera_switch_failed');
  String get turnOffVideo => translate('turn_off_video');
  String get turnOnVideo => translate('turn_on_video');
  String get callHistory => translate('call_history');
  String get deleteCallRecord => translate('delete_call_record');
  String get deleteCallRecordConfirm => translate('delete_call_record_confirm');
  String get otherRejected => translate('other_rejected');
  String get rejected => translate('call_rejected');
  String get cancelled => translate('call_cancelled');
  String get otherCancelled => translate('other_cancelled');
  String get missed => translate('call_missed');
  String get missedCall => translate('missed_call');
  String get otherBusy => translate('other_busy');
  String get ended => translate('call_status_ended');
  String get unknown => translate('unknown');

  // 钱包
  String get wallet => translate('wallet');
  String get refresh => translate('refresh');
  String get transactionRecords => translate('transaction_records');
  String get availableBalance => translate('available_balance');
  String get frozen => translate('frozen');
  String get goldBeans => translate('gold_beans');
  String get recharge => translate('recharge');
  String get withdraw => translate('withdraw');
  String get exchange => translate('exchange');
  String get rechargeRecords => translate('recharge_records');
  String get withdrawRecords => translate('withdraw_records');
  String get exchangeRecords => translate('exchange_records');
  String get walletFlow => translate('wallet_flow');
  String get contactCustomerService => translate('contact_customer_service');
  String get getWalletInfoFailed => translate('get_wallet_info_failed');
  String get rechargeNotAvailable => translate('recharge_not_available');
  String get withdrawNotAvailable => translate('withdraw_not_available');
  String get setPayPasswordFirst => translate('set_pay_password_first');
  String get pendingWithdrawOrder => translate('pending_withdraw_order');
  String get exchangeNotAvailable => translate('exchange_not_available');
  String get copiedToClipboard => translate('copied_to_clipboard');
  String get offlineTransfer => translate('offline_transfer');
  String get forcedOfflineTitle => translate('forced_offline_title');
  String get forcedOfflineMessage => translate('forced_offline_message');
  String get messagePreview => translate('message_preview');
  String get livestreamPreview => translate('livestream_preview');
  String get redPacketPreview => translate('red_packet_preview');
  String get stickerPreview => translate('sticker_preview');
  String get newMessagePreview => translate('new_message_preview');
  String get chatClearedByOtherPreview => translate('chat_cleared_by_other_preview');
  String get usdtPayment => translate('usdt_payment');
  String get balanceToGoldBeans => translate('balance_to_gold_beans');
  String get goldBeansToBalance => translate('gold_beans_to_balance');
  String get exchangeAmount => translate('exchange_amount');
  String get pleaseEnterAmount => translate('please_enter_amount');
  String get goldBeansObtainable => translate('gold_beans_obtainable');
  String get goldBeansQuantity => translate('gold_beans_quantity');
  String get pleaseEnterGoldBeans => translate('please_enter_gold_beans');
  String get amountObtainable => translate('amount_obtainable');
  String get payPassword => translate('pay_password');
  String get forFinancialOperations => translate('for_financial_operations');

  // 账号安全
  String get accountInfo => translate('account_info');
  String get account => translate('account');
  String get userId => translate('user_id');
  String get passwordManagement => translate('password_management');
  String get changeLoginPassword => translate('change_login_password');
  String get securityBinding => translate('security_binding');
  String get notBound => translate('not_bound');
  String get change => translate('change');
  String get toBind => translate('to_bind');
  String get loginManagement => translate('login_management');
  String get deviceManagement => translate('device_management');
  String get viewManageDevices => translate('view_manage_devices');
  String get calculating => translate('calculating');
  
  // WebSocket 强制登出原因
  String get logoutOtherDevice => translate('logout_other_device');
  String get logoutAdminKick => translate('logout_admin_kick');
  String get logoutTokenExpired => translate('logout_token_expired');
  String get logoutUserLogout => translate('logout_user_logout');
  String get logoutMaxDevices => translate('logout_max_devices');
  String get clearCacheConfirm => translate('clear_cache_confirm');
  String get cacheCleared => translate('cache_cleared');
  String get clearFailed => translate('clear_failed');
  String get chatSettings => translate('chat_settings');
  String get backgroundFontHistory => translate('background_font_history');
  String get newMessageNotification => translate('new_message_notification');
  String get simplifiedChinese => translate('simplified_chinese');

  // 时间相关
  String get yesterday => translate('yesterday');
  String get monday => translate('monday');
  String get tuesday => translate('tuesday');
  String get wednesday => translate('wednesday');
  String get thursday => translate('thursday');
  String get friday => translate('friday');
  String get saturday => translate('saturday');
  String get sunday => translate('sunday');

  // 群分享
  String get shareLinkCreated => translate('share_link_created');
  String get shareCodeCopied => translate('share_code_copied');
  String get revokeShareLink => translate('revoke_share_link');
  String get revoke => translate('revoke');
  String get linkRevoked => translate('link_revoked');
  String get myShareLinks => translate('my_share_links');
  String get createShareLink => translate('create_share_link');
  String get neverExpire => translate('never_expire');
  String get unlimited => translate('unlimited');
  String get generateShareLink => translate('generate_share_link');
  String get unlimitedTimes => translate('unlimited_times');

  // 其他
  String get loadFailed => translate('load_failed');
  String get onlyOwnerCanModify => translate('only_owner_can_modify');
  String get settingsSaved => translate('settings_saved');
  String get saveFailed => translate('save_failed');
  String get anyoneCanJoin => translate('anyone_can_join');
  String get requiresAdminApproval => translate('requires_admin_approval');
  String get onlyThroughInvitation => translate('only_through_invitation');
  String get pausedAcceptingMembers => translate('paused_accepting_members');

  // 个人中心
  String get notLoggedIn => translate('not_logged_in');
  String get dailyClaim => translate('daily_claim');
  String get alreadyClaimed => translate('already_claimed');
  String get claimSuccess => translate('claim_success');
  String get claimFailed => translate('claim_failed');
  String get inviteFriends => translate('invite_friends');
  String get inviteCodeShareInfo => translate('invite_code_share_info');
  String get copyInviteCode => translate('copy_invite_code');
  String get inviteCodeCopied => translate('invite_code_copied');
  String get orCopyInviteLink => translate('or_copy_invite_link');
  String get copyLink => translate('copy_link');
  String get inviteLinkCopied => translate('invite_link_copied');
  String get inviteRewardInfo => translate('invite_reward_info');
  String get close => translate('close');
  String get favorites => translate('favorites');
  String get goldBeanMall => translate('gold_bean_mall');
  String get inDevelopment => translate('in_development');
  String get editProfile => translate('edit_profile');
  String get bio => translate('bio');
  String get notSet => translate('not_set');
  String get region => translate('region');
  String get myQrcode => translate('my_qrcode');
  String get myAddress => translate('my_address');
  String get takePhoto => translate('take_photo');
  String get selectFromAlbum => translate('select_from_album');
  String get uploadFailed => translate('upload_failed');
  String get avatarUpdated => translate('avatar_updated');
  String get operationFailed => translate('operation_failed');
  String get editNickname => translate('edit_nickname');
  String get inputNickname => translate('input_nickname');
  String get nicknameRequired => translate('nickname_required');
  String get nicknameUpdated => translate('nickname_updated');
  String get editBio => translate('edit_bio');
  String get inputBio => translate('input_bio');
  String get bioUpdated => translate('bio_updated');
  String get editRegion => translate('edit_region');
  String get inputRegion => translate('input_region');
  String get regionUpdated => translate('region_updated');
  String get editAddress => translate('edit_address');
  String get inputAddress => translate('input_address');
  String get addressUpdated => translate('address_updated');
  String get selectGender => translate('select_gender');
  String get secret => translate('secret');
  String get genderUpdated => translate('gender_updated');

  // 等级系统
  String get levelCenter => translate('level_center');
  String get currentPoints => translate('current_points');
  String get distanceToNext => translate('distance_to_next');
  String get pointsNeeded => translate('points_needed');
  String get maxLevelReached => translate('max_level_reached');
  String get privilegesOverview => translate('privileges_overview');
  String get requirePoints => translate('require_points');
  String get currentLevel => translate('current_level');
  String get howToUpgrade => translate('how_to_upgrade');
  String get autoUpgradeInfo => translate('auto_upgrade_info');
  String get downgradeRules => translate('downgrade_rules');
  String get inactivityWarning => translate('inactivity_warning');
  String get warmTips => translate('warm_tips');

  // 金豆
  String get goldBeanBalance => translate('gold_bean_balance');
  String get dailyClaimable => translate('daily_claimable');
  String get goldBeanRecords => translate('gold_bean_records');
  String get noGoldBeanRecords => translate('no_gold_bean_records');
  String get noMore => translate('no_more');
  String get recordTime => translate('record_time');
  String get amountChange => translate('amount_change');
  String get balanceAfter => translate('balance_after');
  String get remark => translate('remark');
  String get relatedUserId => translate('related_user_id');

  // 收藏
  String get searchFavorites => translate('search_favorites');
  String get deleteFavorite => translate('delete_favorite');
  String get deleteFavoriteConfirm => translate('delete_favorite_confirm');
  String get deleted => translate('deleted');
  String get deleteFailed => translate('delete_failed');
  String get noFavorites => translate('no_favorites');
  String get noFavoritesHint => translate('no_favorites_hint');
  String get voiceMessage => translate('voice_message');
  String get chatRecord => translate('chat_record');
  String get card => translate('card');
  String get message => translate('message');
  String daysAgo(int count) => translate('days_ago').replaceAll('{days}', count.toString());

  // 二维码
  String get scanToAddFriend => translate('scan_to_add_friend');
  String get chooseStyle => translate('choose_style');
  String get shareTo => translate('share_to');
  String get friends => translate('friends');
  String get friendGroups => translate('friend_groups');
  String get selectedCount => translate('selected_count');
  String get sendWithCount => translate('send_with_count');
  String get pleaseSelectTarget => translate('please_select_target');
  String get noFriends => translate('no_friends');
  String get noGroups => translate('no_groups');
  String get sharedWithContacts => translate('shared_with_contacts');

  // 树洞
  String get treeHole => translate('tree_hole');
  String get shareYourStory => translate('share_your_story');
  String get commentSuccess => translate('comment_success');
  String get commentFailed => translate('comment_failed');
  String get deleteConfirm => translate('delete_confirm');
  String get deleteTreeHoleConfirm => translate('delete_tree_hole_confirm');
  String get postDetails => translate('post_details');
  String get popular => translate('popular');
  String get comments => translate('comments');
  String get noComments => translate('no_comments');
  String get originalPoster => translate('original_poster');
  String get replyTo => translate('reply_to');
  String get anonymousComment => translate('anonymous_comment');
  String get send => translate('send');
  String get justNow => translate('just_now');
  String minutesAgo(int count) => translate('minutes_ago').replaceAll('{count}', count.toString());
  String hoursAgo(int count) => translate('hours_ago').replaceAll('{count}', count.toString());
  String get all => translate('all');
  String get loadTopicsFailed => translate('load_topics_failed');
  String get loadPostsFailed => translate('load_posts_failed');
  String get loadMoreFailed => translate('load_more_failed');
  String get likeFailed => translate('like_failed');
  String get latest => translate('latest');
  String get noContent => translate('no_content');
  String get beFirstToShare => translate('be_first_to_share');
  String get maxImagesAllowed => translate('max_images_allowed');
  String get selectImageFailed => translate('select_image_failed');
  String get pleaseEnterContent => translate('please_enter_content');
  String get preparingPublish => translate('preparing_publish');
  String get uploadingImage => translate('uploading_image');
  String get publishing => translate('publishing');
  String get publishSuccess => translate('publish_success');
  String get publishFailed => translate('publish_failed');
  String get publishPost => translate('publish_post');
  String get publish => translate('publish');
  String get publishAnonymously => translate('publish_anonymously');
  String get identityHidden => translate('identity_hidden');
  String get secretSpace => translate('secret_space');
  String get addImages => translate('add_images');
  String get selectTopic => translate('select_topic');
  String get customTags => translate('custom_tags');
  String get enterTag => translate('enter_tag');
  String get clear => translate('clear');

  // 漂流瓶
  String get driftBottle => translate('drift_bottle');
  String get discoverNearby => translate('discover_nearby');
  String get driftConversations => translate('drift_conversations');
  String get loadConversationsFailed => translate('load_conversations_failed');
  String get noConversations => translate('no_conversations');
  String get conversationsHint => translate('conversations_hint');
  String get anonymousUser => translate('anonymous_user');
  String get loadRepliesFailed => translate('load_replies_failed');
  String get sendFailed => translate('send_failed');
  String get bottleContent => translate('bottle_content');
  String get noReplies => translate('no_replies');
  String get enterMessage => translate('enter_message');
  String get today => translate('today');
  String get deleteBottle => translate('delete_bottle');
  String get deleteBottleConfirm => translate('delete_bottle_confirm');
  String get deleteSuccess => translate('delete_success');
  String get myBottles => translate('my_bottles');
  String get noBottlesYet => translate('no_bottles_yet');
  String get goThrowBottle => translate('go_throw_bottle');
  String get anonymous => translate('anonymous');
  String get publicVisible => translate('public_visible');
  String get floating => translate('floating');
  String get pickedUp => translate('picked_up');
  String get expired => translate('expired');
  String get violation => translate('violation');
  String get pickedUpBottle => translate('picked_up_bottle');
  String get bottleThrownBack => translate('bottle_thrown_back');
  String get pleaseEnterReply => translate('please_enter_reply');
  String get replySuccess => translate('reply_success');
  String get replyFailed => translate('reply_failed');
  String get boyBottle => translate('boy_bottle');
  String get girlBottle => translate('girl_bottle');
  String get viewedTimes => translate('viewed_times');
  String get thrownBackTimes => translate('thrown_back_times');
  String get throwBackToSea => translate('throw_back_to_sea');
  String get replyTa => translate('reply_ta');
  String get writeToTa => translate('write_to_ta');
  String get dailyLimitReached => translate('daily_limit_reached');
  String get noBottleThisTime => translate('no_bottle_this_time');
  String get continuePickUp => translate('continue_pick_up');
  String get chooseBottleType => translate('choose_bottle_type');
  String get noLimit => translate('no_limit');
  String get boysBottles => translate('boys_bottles');
  String get girlsBottles => translate('girls_bottles');
  String get throwBottle => translate('throw_bottle');
  String get pickBottle => translate('pick_bottle');
  String get canActionToday => translate('can_action_today');
  String get pickingUp => translate('picking_up');
  String get pressToFilter => translate('press_to_filter');
  String get pleaseEnterBottleContent => translate('please_enter_bottle_content');
  String get contentTooLong => translate('content_too_long');
  String get bottleThrown => translate('bottle_thrown');
  String get throwBottleFailed => translate('throw_bottle_failed');
  String get throwOut => translate('throw_out');
  String get writeAndThrow => translate('write_and_throw');
  String get hopeWhoPicksUp => translate('hope_who_picks_up');
  String get boys => translate('boys');
  String get girls => translate('girls');
  String get sendAnonymously => translate('send_anonymously');
  String get reminder => translate('reminder');
  String get bottleFloatDays => translate('bottle_float_days');
  String get maxPickUpTimes => translate('max_pick_up_times');
  String get pickerCanReply => translate('picker_can_reply');
  String get beCivil => translate('be_civil');

  // 朋友圈
  String get loadMomentsFailed => translate('load_moments_failed');
  String get deleteMoment => translate('delete_moment');
  String get deleteMomentConfirm => translate('delete_moment_confirm');
  String get momentDeleted => translate('moment_deleted');
  String get momentMayBeDeleted => translate('moment_may_be_deleted');
  String get newLikesAndComments => translate('new_likes_and_comments');
  String get unlike => translate('unlike');
  String get like => translate('like');
  String get comment => translate('comment');
  String get messageNotifications => translate('message_notifications');
  String get noNotifications => translate('no_notifications');
  String get likedYourMoment => translate('liked_your_moment');
  String get commentedOnYou => translate('commented_on_you');
  String get selectVideoFailed => translate('select_video_failed');
  String get videoImagesTogether => translate('video_images_together');
  String get addContentOrMedia => translate('add_content_or_media');
  String get preparingUpload => translate('preparing_upload');
  String get uploadingVideo => translate('uploading_video');
  String get whoCanView => translate('who_can_view');
  String get publicView => translate('public_view');
  String get allFriendsVisible => translate('all_friends_visible');
  String get privateView => translate('private_view');
  String get onlyMeVisible => translate('only_me_visible');
  String get publishToMoments => translate('publish_to_moments');
  String get post => translate('post');
  String get whatsOnYourMind => translate('whats_on_your_mind');
  String get locationServiceDisabled => translate('location_service_disabled');
  String get locationPermissionDenied => translate('location_permission_denied');
  String get locationPermissionPermanentlyDenied => translate('location_permission_permanently_denied');
  String get getLocationFailed => translate('get_location_failed');
  String get currentLocation => translate('current_location');
  String get needLocationPermission => translate('need_location_permission');
  String get enableLocationInSettings => translate('enable_location_in_settings');
  String get goToSettings => translate('go_to_settings');
  String get dontShow => translate('dont_show');
  String get searchLocation => translate('search_location');
  String get gettingLocation => translate('getting_location');
  String get myLocation => translate('my_location');
  String get selectOnMap => translate('select_on_map');
  String get selectLocationOnMap => translate('select_location_on_map');
  String get popularDomestic => translate('popular_domestic');
  String get popularInternational => translate('popular_international');
  String get cannotGetLocation => translate('cannot_get_location');
  String get tapToRetry => translate('tap_to_retry');
  String get yourLocation => translate('your_location');
  String get positioning => translate('positioning');
  String get mapPicker => translate('map_picker');
  String get tapRetryGetLocation => translate('tap_retry_get_location');
  String get selectedVideo => translate('selected_video');
  String get selectedLocation => translate('selected_location');
  String get tapMapToSelect => translate('tap_map_to_select');
  String get pleaseEnableLocationService => translate('please_enable_location_service');
  String get cannotGetCurrentLocation => translate('cannot_get_current_location');
  String get selectLocation => translate('select_location');

  // 热门城市列表
  List<String> get domesticCities => [
    translate('city_beijing'), translate('city_shanghai'), translate('city_guangzhou'),
    translate('city_shenzhen'), translate('city_hangzhou'), translate('city_chengdu'),
    translate('city_wuhan'), translate('city_xian'), translate('city_nanjing'),
    translate('city_chongqing'), translate('city_suzhou'), translate('city_tianjin'),
    translate('city_changsha'), translate('city_qingdao'), translate('city_xiamen'),
    translate('city_sanya'), translate('city_lijiang'), translate('city_dali'),
    translate('city_guilin'), translate('city_hongkong'), translate('city_macau'),
    translate('city_taipei'),
  ];

  List<String> get internationalCities => [
    translate('city_newyork'), translate('city_london'), translate('city_paris'),
    translate('city_tokyo'), translate('city_seoul'), translate('city_singapore'),
    translate('city_dubai'), translate('city_sydney'), translate('city_losangeles'),
    translate('city_sanfrancisco'), translate('city_bangkok'), translate('city_bali'),
    translate('city_maldives'), translate('city_phuket'), translate('city_chiangmai'),
    translate('city_rome'), translate('city_barcelona'), translate('city_amsterdam'),
    translate('city_milan'), translate('city_venice'), translate('city_hawaii'),
    translate('city_santorini'), translate('city_prague'), translate('city_vienna'),
    translate('city_munich'),
  ];

  String get images => translate('images');
  String get noMomentsYet => translate('no_moments_yet');
  String get theyNoMomentsYet => translate('they_no_moments_yet');
  String get postsCount => translate('posts_count');
  String get fullDateFormat => translate('full_date_format');

  // 附近的人
  String get nearbyPeople => translate('nearby_people');
  String get enableLocationService => translate('enable_location_service');
  String get locationPermissionNeeded => translate('location_permission_needed');
  String get checkPermissionsFailed => translate('check_permissions_failed');
  String get enableLocationFailed => translate('enable_location_failed');
  String get clearLocation => translate('clear_location');
  String get clearLocationConfirm => translate('clear_location_confirm');
  String get locationCleared => translate('location_cleared');
  String get clearLocationFailed => translate('clear_location_failed');
  String get selectDistanceRange => translate('select_distance_range');
  String get filterGender => translate('filter_gender');
  String get boysOnly => translate('boys_only');
  String get girlsOnly => translate('girls_only');
  String get whoViewedMe => translate('who_viewed_me');
  String get greet => translate('greet');
  String get refreshLocation => translate('refresh_location');
  String get locationSettings => translate('location_settings');
  String get enableLocationToDiscover => translate('enable_location_to_discover');
  String get locationVisibilityInfo => translate('location_visibility_info');
  String get enableLocation => translate('enable_location');
  String get searchingNearby => translate('searching_nearby');
  String get noNearbyUsers => translate('no_nearby_users');
  String get expandSearchRange => translate('expand_search_range');
  String get yearsOld => translate('years_old');
  String get foundYouNearby => translate('found_you_nearby');
  String get friendRequestSent => translate('friend_request_sent');
  String get greetTo => translate('greet_to');
  String get niceToMeetYou => translate('nice_to_meet_you');
  String get greetingSent => translate('greeting_sent');
  String get locationRefreshed => translate('location_refreshed');
  String get refreshLocationFailed => translate('refresh_location_failed');
  String get whoCanSeeMe => translate('who_can_see_me');
  String get everyone => translate('everyone');
  String get everyoneNearby => translate('everyone_nearby');
  String get oppositeGenderOnly => translate('opposite_gender_only');
  String get onlyOppositeGender => translate('only_opposite_gender');
  String get hide => translate('hide');
  String get notShownInList => translate('not_shown_in_list');
  String get showCity => translate('show_city');
  String get othersCanSeeCity => translate('others_can_see_city');
  String get saveSettings => translate('save_settings');
  String get receivedGreets => translate('received_greets');
  String get noGreetsYet => translate('no_greets_yet');
  String get checkNearbyPeople => translate('check_nearby_people');
  String get newGreet => translate('new_greet');
  String get noOneViewedYet => translate('no_one_viewed_yet');
  String get enableLocationToBeVisible => translate('enable_location_to_be_visible');
  String get openSettings => translate('open_settings');
  String get tryExpandRange => translate('try_expand_range');
  String get maleOnly => translate('male_only');
  String get femaleOnly => translate('female_only');
  String get notInNearbyList => translate('not_in_nearby_list');
  String get checkPermissionFailed => translate('check_permission_failed');
  String get greetOption1 => translate('greet_option_1');
  String get greetOption2 => translate('greet_option_2');
  String get greetOption3 => translate('greet_option_3');
  String greetToUser(String name) => translate('greet_to_user').replaceAll('{name}', name);
  String replyToUser(String name) => translate('reply_to_user').replaceAll('{name}', name);
  String get greetReplyOption1 => translate('greet_reply_option_1');
  String get greetReplyOption2 => translate('greet_reply_option_2');
  String get greetReplyOption3 => translate('greet_reply_option_3');
  String get replySent => translate('reply_sent');
  String get noOneGreetedYet => translate('no_one_greeted_yet');
  String get checkNearbyMakeFriends => translate('check_nearby_make_friends');
  String get newTag => translate('new_tag');
  String get receivedGreetsTitle => translate('received_greets_title');
  String ageYears(int age) => '$age${translate('years_old')}';

  // 群组管理
  String get noticeUpdated => translate('notice_updated');
  String get noNotice => translate('no_notice');
  String get publishNotice => translate('publish_notice');
  String get enterNoticeContent => translate('enter_notice_content');
  String get noticeWillNotifyAll => translate('notice_will_notify_all');
  String get adminPermissions => translate('admin_permissions');
  String get adminPermissionsConfig => translate('admin_permissions_config');
  String get kickMembers => translate('kick_members');
  String get kickMembersDesc => translate('kick_members_desc');
  String get muteMembers => translate('mute_members');
  String get muteMembersDesc => translate('mute_members_desc');
  String get inviteMembersDesc => translate('invite_members_desc');
  String get editGroupInfo => translate('edit_group_info');
  String get editGroupInfoDesc => translate('edit_group_info_desc');
  String get editNotice => translate('edit_notice');
  String get editNoticeDesc => translate('edit_notice_desc');
  String get viewMemberList => translate('view_member_list');
  String get viewMemberListDesc => translate('view_member_list_desc');
  String get clearChatHistory => translate('clear_chat_history');
  String get clearChatHistoryDesc => translate('clear_chat_history_desc');
  String get searchChatHistory => translate('search_chat_history');
  String get enterKeywordToSearch => translate('enter_keyword_to_search');
  String get noResultsFor => translate('no_results_for');
  String get foundMessages => translate('found_messages');
  String get unknownUser => translate('unknown_user');
  String get chatBackground => translate('chat_background');
  String get backgroundUpdated => translate('background_updated');
  String get defaultBackground => translate('default_background');
  String get solidColor => translate('solid_color');
  String get gradientBackground => translate('gradient_background');
  String get customImage => translate('custom_image');
  String get customImageHint => translate('custom_image_hint');
  String get selectAtLeastOne => translate('select_at_least_one');
  String get enterGroupName => translate('enter_group_name');
  String get groupCreated => translate('group_created');
  String get createFailed => translate('create_failed');
  String get groupAvatar => translate('group_avatar');
  String get selectedPeople => translate('selected_people');
  String get noFriendsYet => translate('no_friends_yet');
  String get addFriendsFirst => translate('add_friends_first');
  String get pleaseSelectFriends => translate('please_select_friends');
  String get invitedFriends => translate('invited_friends');
  String get inviteFailed => translate('invite_failed');
  String get searchFriends => translate('search_friends');
  String get clearSelection => translate('clear_selection');
  String get noMatchingFriends => translate('no_matching_friends');
  String get alreadyInGroup => translate('already_in_group');
  String get groupNumber => translate('group_number');
  String get groupNumberCopied => translate('group_number_copied');
  String get groupMaxMembers => translate('group_max_members');
  String get groupMaxMembersHint => translate('group_max_members_hint');
  String get maxMembersRange => translate('max_members_range');
  String get maxMembersUpdated => translate('max_members_updated');
  String get updateFailed => translate('update_failed');
  String get joinSettings => translate('join_settings');
  String get joinMethod => translate('join_method');
  String get allowQrCodeJoin => translate('allow_qr_code_join');
  String get qrCodeJoinDisabled => translate('qr_code_join_disabled');
  String get allowMemberAddFriend => translate('allow_member_add_friend');
  String get showMemberList => translate('show_member_list');
  String get allMembersCanView => translate('all_members_can_view');
  String get onlyAdminCanView => translate('only_admin_can_view');
  String get allowMemberInvite => translate('allow_member_invite');
  String get membersCanInvite => translate('members_can_invite');
  String get onlyAdminCanInvite => translate('only_admin_can_invite');
  String get groupManageSettings => translate('group_manage_settings');
  String get administrators => translate('administrators');
  String get joinRequests => translate('join_requests');
  String get muteAllMembers => translate('mute_all_members');
  String get muteAllDesc => translate('mute_all_desc');
  String get myNicknameInGroup => translate('my_nickname_in_group');
  String get pinChat => translate('pin_chat');
  String get doNotDisturb => translate('do_not_disturb');
  String get showMemberNickname => translate('show_member_nickname');
  String get findChatHistory => translate('find_chat_history');
  String get clearLocalHistory => translate('clear_local_history');
  String get clearAllMembersHistory => translate('clear_all_members_history');
  String get transferOwnership => translate('transfer_ownership');
  String get selectNewOwner => translate('select_new_owner');
  String get groupRemark => translate('group_remark');
  String get modifyGroupName => translate('modify_group_name');
  String get groupNameModified => translate('group_name_modified');
  String get setGroupRemark => translate('set_group_remark');
  String get groupRemarkOnlyMe => translate('group_remark_only_me');
  String get groupRemarkUpdated => translate('group_remark_updated');
  String get muteAllEnabled => translate('mute_all_enabled');
  String get muteAllDisabled => translate('mute_all_disabled');
  String get setGroupNickname => translate('set_group_nickname');
  String get enterNicknameInGroup => translate('enter_nickname_in_group');
  String get groupNicknameUpdated => translate('group_nickname_updated');
  String get clearLocalHistoryConfirm => translate('clear_local_history_confirm');
  String get localHistoryCleared => translate('local_history_cleared');
  String get clearAllHistoryConfirm => translate('clear_all_history_confirm');
  String get historyCleared => translate('history_cleared');
  String get clearHistoryFailed => translate('clear_history_failed');
  String get transferOwnershipConfirm => translate('transfer_ownership_confirm');
  String get ownershipTransferred => translate('ownership_transferred');
  String get transferFailed => translate('transfer_failed');
  String get dismissGroupConfirm => translate('dismiss_group_confirm');
  String get groupDismissed => translate('group_dismissed');
  String get dismissFailed => translate('dismiss_failed');
  String get leaveGroupConfirm => translate('leave_group_confirm');
  String get leftGroup => translate('left_group');
  String get leaveFailed => translate('leave_failed');
  String get cannotSelectOwner => translate('cannot_select_owner');
  String get ownerForbidAddFriend => translate('owner_forbid_add_friend');
  String get viewProfile => translate('view_profile');
  String get removeFromGroup => translate('remove_from_group');
  String get unmute => translate('unmute');
  String get mute => translate('mute');
  String get cancelAdmin => translate('cancel_admin');
  String get setAsAdmin => translate('set_as_admin');
  String get removeFromGroupConfirm => translate('remove_from_group_confirm');
  String get memberRemoved => translate('member_removed');
  String get memberUnmuted => translate('member_unmuted');
  String get muteFor => translate('mute_for');
  String get tenMinutes => translate('ten_minutes');
  String get oneHour => translate('one_hour');
  String get twelveHours => translate('twelve_hours');
  String get oneDay => translate('one_day');
  String get sevenDays => translate('seven_days');
  String get thirtyDays => translate('thirty_days');
  String get memberMuted => translate('member_muted');
  String get cancelAdminConfirm => translate('cancel_admin_confirm');
  String get setAdminConfirm => translate('set_admin_confirm');
  String get adminCancelled => translate('admin_cancelled');
  String get adminSet => translate('admin_set');
  String get alreadyFriend => translate('already_friend');
  String get addAdmin => translate('add_admin');
  String get noAdmins => translate('no_admins');
  String get adminAdded => translate('admin_added');
  String get addFailed => translate('add_failed');
  String get selectMembers => translate('select_members');
  String get noMembersToSelect => translate('no_members_to_select');
  String get rejectRequest => translate('reject_request');
  String get rejectReason => translate('reject_reason');
  String get confirmReject => translate('confirm_reject');
  String get verificationMessage => translate('verification_message');
  String get noVerificationMessage => translate('no_verification_message');
  String get applicationTime => translate('application_time');
  String get approveJoin => translate('approve_join');
  String get noJoinRequests => translate('no_join_requests');
  String get joinRequestsHint => translate('join_requests_hint');
  String get applyToJoinGroup => translate('apply_to_join_group');
  String get revokeConfirm => translate('revoke_confirm');
  String get validity => translate('validity');
  String get usageLimit => translate('usage_limit');
  String get shareCode => translate('share_code');
  String get enterShareCode => translate('enter_share_code');
  String get shareCodeInvalid => translate('share_code_invalid');
  String get answerQuestion => translate('answer_question');
  String get yourAnswer => translate('your_answer');
  String get applicationMessage => translate('application_message');
  String get applicationReason => translate('application_reason');
  String get groupQrcode => translate('group_qrcode');
  String get getQrcodeFailed => translate('get_qrcode_failed');
  String get generateQrcodeFailed => translate('generate_qrcode_failed');
  String get scanToJoin => translate('scan_to_join');
  String get scanToApply => translate('scan_to_apply');
  String get validUntil => translate('valid_until');
  String get qrcodeDisabledHint => translate('qrcode_disabled_hint');
  String get saveImage => translate('save_image');
  String get shareImage => translate('share_image');
  String get imageDownloading => translate('image_downloading');
  String get imageSaved => translate('image_saved');
  String get saveFailedCheckPermission => translate('save_failed_check_permission');
  String get generateImageFailed => translate('generate_image_failed');
  String get selectShareTarget => translate('select_share_target');
  String get sharedToContacts => translate('shared_to_contacts');
  String get shareFailed => translate('share_failed');
  String get noGroupsYet => translate('no_groups_yet');
  String get rejectJoinRequest => translate('reject_join_request');
  String get approve => translate('approve');
  String get friendRequestFailed => translate('friend_request_failed');
  String get user => translate('user');
  String get groups => translate('groups');
  String get operationSuccess => translate('operation_success');
  String get qrcodeDisabledSaveShare => translate('qrcode_disabled_save_share');
  String get sharedGroupCard => translate('shared_group_card');
  String peopleCount(int count) => translate('people_count').replaceAll('{count}', count.toString());
  String selectedCountFormat(int count) => translate('selected_count').replaceAll('{count}', count.toString());

  // 聊天设置
  String get chatAppearance => translate('chat_appearance');
  String get hasSet => translate('has_set');
  String get fontSize => translate('font_size');
  String get chatFeatures => translate('chat_features');
  String get autoDownload => translate('auto_download');
  String get autoDownloadDesc => translate('auto_download_desc');
  String get saveToAlbum => translate('save_to_album');
  String get saveToAlbumDesc => translate('save_to_album_desc');
  String get callRingtone => translate('call_ringtone');
  String get customRingtone => translate('custom_ringtone');
  String get previewRingtone => translate('preview_ringtone');
  String get playingRingtone => translate('playing_ringtone');
  String get tapToPreview => translate('tap_to_preview');
  String get chatHistoryBackup => translate('chat_history_backup');
  String get backupToCloud => translate('backup_to_cloud');
  String get restoreFromCloud => translate('restore_from_cloud');
  String get featureInDevelopment => translate('feature_in_development');
  String get clearAllChatHistory => translate('clear_all_chat_history');

  // 隐私设置
  String get addMeMethod => translate('add_me_method');
  String get allowAnyone => translate('allow_anyone');
  String get anyoneCanAddMe => translate('anyone_can_add_me');
  String get requireVerification => translate('require_verification');
  String get rejectEveryone => translate('reject_everyone');
  String get onlineStatus => translate('online_status');
  String get showOnlineStatus => translate('show_online_status');
  String get other => translate('other');
  String get blacklist => translate('blacklist');
  String get manageBlacklist => translate('manage_blacklist');

  // 黑名单
  String get removeFromBlacklist => translate('remove_from_blacklist');
  String get removeFromBlacklistConfirm => translate('remove_from_blacklist_confirm');
  String get willShowInContacts => translate('will_show_in_contacts');
  String get removedFromBlacklist => translate('removed_from_blacklist');
  String get blacklistEmpty => translate('blacklist_empty');
  String get blacklistHint => translate('blacklist_hint');
  String get removeBlacklist => translate('remove_blacklist');

  // 标签
  String get tags => translate('tags');
  String get noTags => translate('no_tags');
  String get addTagsHint => translate('add_tags_hint');
  String get people => translate('people');
  String get tagDetails => translate('tag_details');
  String get noFriendsWithTag => translate('no_friends_with_tag');

  // 帮助中心
  String get helpCenter => translate('help_center');
  String get searchProblems => translate('search_problems');
  String get hotProblems => translate('hot_problems');
  String get helpCategories => translate('help_categories');
  String get contactOnlineService => translate('contact_online_service');
  String get ifProblemNotSolved => translate('if_problem_not_solved');
  String get noArticles => translate('no_articles');
  String get thanksForFeedback => translate('thanks_for_feedback');
  String get submitProblem => translate('submit_problem');
  String get describeProblem => translate('describe_problem');
  String get submit => translate('submit');

  // 关于
  String get imMessenger => translate('im_messenger');
  String get featureIntro => translate('feature_intro');
  String get checkUpdate => translate('check_update');
  String get alreadyLatest => translate('already_latest');
  String get rateUs => translate('rate_us');
  String get thanksForSupport => translate('thanks_for_support');
  String get legalInfo => translate('legal_info');
  String get userAgreement => translate('user_agreement');
  String get privacyPolicy => translate('privacy_policy');
  String get gotIt => translate('got_it');

  // 通知设置
  String get receiveNotification => translate('receive_notification');
  String get turnOffNotificationHint => translate('turn_off_notification_hint');
  String get notificationMethod => translate('notification_method');
  String get sound => translate('sound');
  String get vibrate => translate('vibrate');
  String get notificationContent => translate('notification_content');
  String get showMessageContent => translate('show_message_content');

  // 转发
  String get forwardTarget => translate('forward_target');
  String get forwardMethod => translate('forward_method');
  String get forwardOneByOne => translate('forward_one_by_one');
  String get forwardOneByOneDesc => translate('forward_one_by_one_desc');
  String get forwardMerge => translate('forward_merge');
  String get forwardMergeDesc => translate('forward_merge_desc');
  String get setTitle => translate('set_title');
  String get chatRecordTitle => translate('chat_record_title');
  String get enterChatRecordTitle => translate('enter_chat_record_title');
  String get forwardSuccess => translate('forward_success');
  String get youAreMuted => translate('you_are_muted');
  String get groupMutedAll => translate('group_muted_all');

  // ==================== 付费通话/观看 ====================
  String get paidCall => translate('paid_call');
  String get paidSession => translate('paid_session');
  String get paidCallRequest => translate('paid_call_request');
  String get paidSessionRequest => translate('paid_session_request');
  String get paidCallEstablished => translate('paid_call_established');
  String get paidSessionEstablished => translate('paid_session_established');
  String get paidCallEnded => translate('paid_call_ended');
  String get paidSessionEnded => translate('paid_session_ended');
  String get paidCallRejected => translate('paid_call_rejected');
  String get paidSessionRejected => translate('paid_session_rejected');
  String get anchorInPaidCall => translate('anchor_in_paid_call');
  String get anchorPaidCallEnded => translate('anchor_paid_call_ended');
  String get requestPaidSession => translate('request_paid_session');
  String get requestPaidSessionSent => translate('request_paid_session_sent');
  String get alreadyInPaidSession => translate('already_in_paid_session');
  String paidSessionRate(int rate) => translate('paid_session_rate').replaceAll('{rate}', rate.toString());
  String paidSessionRateDisplay(int rate) => translate('paid_session_rate_display').replaceAll('{rate}', rate.toString());
  String requestPaidSessionWith(String name) => translate('request_paid_session_with').replaceAll('{name}', name);
  String requestPaidCallWith(String name) => translate('request_paid_call_with').replaceAll('{name}', name);
  String get paidSessionMenuTitle => translate('paid_session_menu_title');
  String paidSessionMenuSubtitle(int rate) => translate('paid_session_menu_subtitle').replaceAll('{rate}', rate.toString());
  String paidWatchTrialInfo(int seconds, int price) => translate('paid_watch_trial_info').replaceAll('{seconds}', seconds.toString()).replaceAll('{price}', price.toString());
  String paidWatchTrialBanner(int seconds, int price) => translate('paid_watch_trial_banner').replaceAll('{seconds}', seconds.toString()).replaceAll('{price}', price.toString());
  String get paidWatchChargingStarted => translate('paid_watch_charging_started');
  String paidWatchCharged(int amount, int balance) => translate('paid_watch_charged').replaceAll('{amount}', amount.toString()).replaceAll('{balance}', balance.toString());
  String get paidWatchInsufficient => translate('paid_watch_insufficient');
  String get paidWatchInsufficientDetail => translate('paid_watch_insufficient_detail');
  String get goldBeansUnit => translate('gold_beans_unit');
  String get perMinute => translate('per_minute');
  String get anchorOfflineWaiting => translate('anchor_offline_waiting');
  String get anchorReconnected => translate('anchor_reconnected');
  String get livestreamEndedTitle => translate('livestream_ended_title');
  String get livestreamEndedReplay => translate('livestream_ended_replay');
  String get livestreamEndedSwitching => translate('livestream_ended_switching');
  String get viewReplay => translate('view_replay');
  String get goBack => translate('go_back');
  String get cohostEstablished => translate('cohost_established');
  String get cohostEnded => translate('cohost_ended');
  String get cohostRejected => translate('cohost_rejected');
  String cohostRequest(String name) => translate('cohost_request').replaceAll('{name}', name);
  String get cohostTapToExitEnlarge => translate('cohost_tap_to_exit_enlarge');
  String enteredLivestream(String name) => translate('entered_livestream').replaceAll('{name}', name);
  String leftLivestream(String name) => translate('left_livestream').replaceAll('{name}', name);
  String userLiked(String name) => translate('user_liked').replaceAll('{name}', name);
  String giftSentDanmaku(String name, String gift, int count) => translate('gift_sent_danmaku').replaceAll('{name}', name).replaceAll('{gift}', gift).replaceAll('{count}', count.toString());
  String get cannotGiftSelf => translate('cannot_gift_self');
  String get anchorMutedYou => translate('anchor_muted_you');
  String get anchorUnmutedYou => translate('anchor_unmuted_you');
  String get youAreKicked => translate('you_are_kicked');
  String get switchedRtmpMode => translate('switched_rtmp_mode');
  String get switchedWebrtcMode => translate('switched_webrtc_mode');
  String mediaInitFailed(String error) => translate('media_init_failed').replaceAll('{error}', error);
  String get joinLivestreamFailed => translate('join_livestream_failed');
  String get videoLoadFailed => translate('video_load_failed');
  String get defaultUser => translate('default_user');
  String get anchorLabel => translate('anchor');
  /// Backward-compatible alias for older callsites.
  String get anchor => anchorLabel;
  String get meLabel => translate('me');

  // === Livestream UI ===
  String get systemLabel => translate('system_label');
  String get cohostDisconnected => translate('cohost_disconnected');
  String get mutedOther => translate('muted_other');
  String get unmutedOther => translate('unmuted_other');
  String get anchorSettings => translate('anchor_settings');
  String get cameraLabel => translate('camera_label');
  String get noCameraAvailable => translate('no_camera_available');
  String get microphoneLabel => translate('microphone_label');
  String get cameraMicBothOff => translate('camera_mic_both_off');
  String get audioLiveBroadcasting => translate('audio_live_broadcasting');
  String get cameraNotEnabled => translate('camera_not_enabled');
  String get initializingCamera => translate('initializing_camera');
  String get connectingAnchor => translate('connecting_anchor');
  String get anchorLiveConnecting => translate('anchor_live_connecting');
  String get endLivestream => translate('end_livestream');
  String get confirmEndLivestream => translate('confirm_end_livestream');
  String get endLivestreamFailed => translate('end_livestream_failed');
  String get endButton => translate('end_button');
  String get livestreamRoom => translate('livestream_room');
  String get roomNotExist => translate('room_not_exist');
  String get youAreSilenced => translate('you_are_silenced');
  String get saySomething => translate('say_something');
  String get followingAlready => translate('following_already');
  String get followButton => translate('follow_button');
  String autoCloseCountdown(int seconds) => translate('auto_close_countdown').replaceAll('{seconds}', seconds.toString());
  String get switchedToStreaming => translate('switched_to_streaming');
  String get switchedToLowLatency => translate('switched_to_low_latency');
  String get rejectButton => translate('reject_button');
  String get acceptButton => translate('accept_button');
  String get startConnection => translate('start_connection');
  String get connectionTypeVideo => translate('connection_type_video');
  String get requestFailed => translate('request_failed');
  String get replayNotReady => translate('replay_not_ready');
  String replayLoadFailed(String error) => translate('replay_load_failed').replaceAll('{error}', error);
  String sentGiftCombo(String gift) => translate('sent_gift_combo').replaceAll('{gift}', gift);
  String get chatLabel => translate('chat_label');
  String get danmakuLabel => translate('danmaku_label');
  String get cohostLabel => translate('cohost_label');
  String get cohostActiveLabel => translate('cohost_active_label');
  String get cohostSubtitle => translate('cohost_subtitle');
  String get selectQuality => translate('select_quality');
  String get originalQuality => translate('original_quality');
  String get interactMenu => translate('interact_menu');
  String get onlineViewers => translate('online_viewers');
  String viewersOnlineCount(int count) => translate('viewers_online_count').replaceAll('{count}', count.toString());
  String get noOnlineViewers => translate('no_online_viewers');
  String get pinUser => translate('pin_user');
  String get unpinUser => translate('unpin_user');
  String get setModerator => translate('set_moderator');
  String get removeModerator => translate('remove_moderator');
  String get muteUserAction => translate('mute_user_action');
  String get kickUserAction => translate('kick_user_action');
  String pinnedUser(String name) => translate('pinned_user').replaceAll('{name}', name);
  String unpinnedUser(String name) => translate('unpinned_user').replaceAll('{name}', name);
  String get shareLivestream => translate('share_livestream');
  String get friendsLabel => translate('friends_label');
  String get groupChatLabel => translate('group_chat_label');
  String get momentsLabel => translate('moments_label');
  String get shareToMoments => translate('share_to_moments');
  String livestreamSharingText(String title) => translate('livestream_sharing_text').replaceAll('{title}', title);
  String get sharedToMoments => translate('shared_to_moments');
  String get publishButton => translate('publish_button');
  String get sendDanmakuHint => translate('send_danmaku_hint');
  String get sendButton => translate('send_button');
  String get tenThousandUnit => translate('ten_thousand_unit');
  String get livestreamPaused => translate('livestream_paused');
  String get livestreamPausedHint => translate('livestream_paused_hint');
  String get livestreamResumed => translate('livestream_resumed');
  String get cancelScheduledLivestream => translate('cancel_scheduled_livestream');
  String get scheduledCancelled => translate('scheduled_cancelled');
  String newReservation(String name) => translate('new_reservation').replaceAll('{name}', name);

  // 直播开播页面
  String get startLivestream => translate('start_livestream');
  String get livestreamCover => translate('livestream_cover');
  String get livestreamTitle => translate('livestream_title');
  String get giveTitle => translate('give_title');
  String get livestreamDesc => translate('livestream_desc');
  String get describeContent => translate('describe_content');
  String get livestreamCategory => translate('livestream_category');
  String get ticketPaid => translate('ticket_paid');
  String get ticketPaidDesc => translate('ticket_paid_desc');
  String get perMinuteBilling => translate('per_minute_billing');
  String get perMinuteDesc => translate('per_minute_desc');
  String get scheduleLivestream => translate('schedule_livestream');
  String get scheduleDesc => translate('schedule_desc');
  String get creating => translate('creating');
  String get scheduleStart => translate('schedule_start');
  String get allCategories => translate('all_categories');
  String get clickUploadCover => translate('click_upload_cover');
  String get recommendedSize => translate('recommended_size');
  String get ticketPriceBeans => translate('ticket_price_beans');
  String get ticketType => translate('ticket_type');
  String get singleTicket => translate('single_ticket');
  String get monthlyTicket => translate('monthly_ticket');
  String get allowPreview => translate('allow_preview');
  String get pricePerMinuteBeans => translate('price_per_minute_beans');
  String get freeTrial => translate('free_trial');
  String get allowPaidCall => translate('allow_paid_call');
  String get paidCallSubtitle => translate('paid_call_subtitle');
  String get paidCallRateBeans => translate('paid_call_rate_beans');
  String get useSystemDefault => translate('use_system_default');
  String get selectTime => translate('select_time');
  String get coverUploadFailed => translate('cover_upload_failed');
  String get enterLivestreamTitle => translate('enter_livestream_title');
  String get scheduleSuccess => translate('schedule_success');
  String anchorShare(int ratio, int platform) => translate('anchor_share').replaceAll('{ratio}', ratio.toString()).replaceAll('{platform}', platform.toString());
  String previewSeconds(int seconds) => translate('preview_seconds').replaceAll('{seconds}', seconds.toString());
  String paidCallShareInfo(int ratio, int platform) => translate('paid_call_share_info').replaceAll('{ratio}', ratio.toString()).replaceAll('{platform}', platform.toString());
  String coverUploadError(String error) => translate('cover_upload_error').replaceAll('{error}', error);


  // PK Battle
  String get pkBattle => translate('pk_battle');
  String get pkInvite => translate('pk_invite');
  String get pkAccept => translate('pk_accept');
  String get pkReject => translate('pk_reject');
  String get pkResult => translate('pk_result');
  String get pkWin => translate('pk_win');
  String get pkLose => translate('pk_lose');
  String get pkDraw => translate('pk_draw');
  String get pkPunishment => translate('pk_punishment');
  String get pkPunishRemaining => translate('pk_punish_remaining');
  String get pkStreak => translate('pk_streak');
  String get pkRankings => translate('pk_rankings');
  String get pkTotalPoints => translate('pk_total_points');
  String get pkSeasonRankings => translate('pk_season_rankings');
  String get pkStreakRanking => translate('pk_streak_ranking');
  String get pkHistory => translate('pk_history');
  String get pkInviteTitle => translate('pk_invite_title');
  String get pkSearchAnchor => translate('pk_search_anchor');
  String get pkInviteSent => translate('pk_invite_sent');
  String get pkRandomMatch => translate('pk_random_match');
  String get pkRandomMatchDesc => translate('pk_random_match_desc');
  String get pkInviteTimeout => translate('pk_invite_timeout');
  String get pkNoActiveAnchors => translate('pk_no_active_anchors');
  String get pkConstraintCohost => translate('pk_constraint_cohost');
  String get pkConstraintPaidCall => translate('pk_constraint_paid_call');
  String get pkMyStats => translate('pk_my_stats');
  String get pkWins => translate('pk_wins');
  String get pkLosses => translate('pk_losses');
  String get pkExpired => translate('pk_expired');
  String get pkStarted => translate('pk_started');
  String get pkEnded => translate('pk_ended');
  String get pkWinnerIs => translate('pk_winner_is');
  String get pkHistoryTab => translate('pk_history_tab');
  String get pkInProgress => translate('pk_in_progress');
  String get pkRules => translate('pk_rules');
  String get pkRulesScoreThreshold => translate('pk_rules_score_threshold');
  String get pkRulesWinPoints => translate('pk_rules_win_points');
  String get pkRulesLosePoints => translate('pk_rules_lose_points');
  String get pkRulesDrawPoints => translate('pk_rules_draw_points');
  String get pkRulesDuration => translate('pk_rules_duration');
  String get pkRulesPunish => translate('pk_rules_punish');
  String get pkRulesRankingDesc => translate('pk_rules_ranking_desc');
  String get pkRulesIndependent => translate('pk_rules_independent');
}

/// 本地化代理
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['zh', 'en', 'fr', 'hi'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
