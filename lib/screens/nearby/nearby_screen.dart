/// 附近的人页面
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/nearby_api.dart';
import 'package:im_client/api/friend_api.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/screens/nearby/nearby_viewers_screen.dart';
import 'package:im_client/screens/nearby/nearby_greets_screen.dart';
import '../../utils/image_proxy.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen>
    with SingleTickerProviderStateMixin {
  final NearbyApi _api = NearbyApi(ApiClient());

  List<NearbyUser> _users = [];
  NearbyConfig? _config;
  bool _isLoading = true;
  bool _isLocationEnabled = false;
  bool _hasPermission = false;
  String? _errorMessage;

  double _currentLat = 0;
  double _currentLon = 0;
  double _selectedDistance = 1.0;
  int _selectedGender = 0; // 0全部 1男 2女

  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _init();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadConfig();
    await _checkPermission();
  }

  Future<void> _loadConfig() async {
    try {
      final result = await _api.getConfig();
      if (result.success && result.data != null) {
        setState(() {
          _config = NearbyConfig.fromJson(result.data);
          _selectedDistance = _config!.defaultDistance;
        });
      }
    } catch (e) {
      debugPrint('Failed to load configuration: $e');
    }
  }

  Future<void> _checkPermission() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _hasPermission = false;
          _errorMessage = l10n.locationServiceDisabled;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _hasPermission = false;
            _errorMessage = l10n.locationPermissionNeeded;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _hasPermission = false;
          _errorMessage = l10n.locationPermissionPermanentlyDenied;
        });
        return;
      }

      setState(() {
        _hasPermission = true;
      });

      // 检查是否已开启位置
      await _checkMyLocation();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '${l10n.checkPermissionFailed}: $e';
      });
    }
  }

  Future<void> _checkMyLocation() async {
    try {
      final result = await _api.getMyLocation();
      if (result.success && result.data != null) {
        final location = UserLocation.fromJson(result.data);
        setState(() {
          _isLocationEnabled = true;
          _currentLat = location.latitude;
          _currentLon = location.longitude;
        });
        await _loadNearbyUsers();
      } else {
        setState(() {
          _isLoading = false;
          _isLocationEnabled = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _enableLocation() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentLat = position.latitude;
      _currentLon = position.longitude;

      // 更新位置到服务器
      final result = await _api.updateLocation(
        latitude: _currentLat,
        longitude: _currentLon,
      );

      if (result.success) {
        setState(() {
          _isLocationEnabled = true;
        });
        await _loadNearbyUsers();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result.message ?? l10n.enableLocationFailed;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '${l10n.getLocationFailed}: $e';
      });
    }
  }

  Future<void> _loadNearbyUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _api.getNearbyUsers(
        latitude: _currentLat,
        longitude: _currentLon,
        distance: _selectedDistance,
        gender: _selectedGender,
      );

      if (result.success && result.data != null) {
        final list = (result.data['list'] as List?) ?? [];
        setState(() {
          _users = list.map((e) => NearbyUser.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        _errorMessage = '${l10n.loadFailed}: $e';
      });
    }
  }

  Future<void> _clearLocation() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearLocation),
        content: Text(l10n.clearLocationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await _api.clearLocation();
      if (result.success) {
        setState(() {
          _isLocationEnabled = false;
          _users = [];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.locationCleared)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.clearLocationFailed}: $e')),
        );
      }
    }
  }

  void _showDistanceSelector() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.selectDistanceRange,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: (_config?.distanceOptions ?? [0.5, 1, 2, 5, 10])
                  .map((d) => ChoiceChip(
                        label: Text('${d}km'),
                        selected: _selectedDistance == d,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedDistance = d;
                            });
                            Navigator.pop(context);
                            _loadNearbyUsers();
                          }
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showGenderFilter() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.filterGender,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.people),
              title: Text(l10n.all),
              trailing: _selectedGender == 0
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                setState(() => _selectedGender = 0);
                Navigator.pop(context);
                _loadNearbyUsers();
              },
            ),
            ListTile(
              leading: const Icon(Icons.male, color: Colors.blue),
              title: Text(l10n.maleOnly),
              trailing: _selectedGender == 1
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                setState(() => _selectedGender = 1);
                Navigator.pop(context);
                _loadNearbyUsers();
              },
            ),
            ListTile(
              leading: const Icon(Icons.female, color: Colors.pink),
              title: Text(l10n.femaleOnly),
              trailing: _selectedGender == 2
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                setState(() => _selectedGender = 2);
                Navigator.pop(context);
                _loadNearbyUsers();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getFullUrl(String url) {
    if (url.isEmpty || url == '/') return '';
    if (url.startsWith('http')) return url;
    return EnvConfig.instance.getFileUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.nearbyPeople),
        actions: [
          if (_isLocationEnabled)
            IconButton(
              icon: const Icon(Icons.location_off),
              tooltip: l10n.clearLocation,
              onPressed: _clearLocation,
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'viewers') {
                _showViewers();
              } else if (value == 'greets') {
                _showGreets();
              } else if (value == 'settings') {
                _showSettings();
              } else if (value == 'refresh') {
                _refreshLocation();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'viewers',
                child: Row(
                  children: [
                    const Icon(Icons.visibility, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.whoViewedMe),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'greets',
                child: Row(
                  children: [
                    const Icon(Icons.waving_hand, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.greet),
                  ],
                ),
              ),
              if (_isLocationEnabled) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.refreshLocation),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      const Icon(Icons.settings, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.locationSettings),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_hasPermission) {
      return _buildPermissionRequest();
    }

    if (!_isLocationEnabled) {
      return _buildEnableLocation();
    }

    if (_isLoading) {
      return _buildLoading();
    }

    if (_errorMessage != null) {
      return _buildError();
    }

    return _buildUserList();
  }

  Widget _buildPermissionRequest() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_disabled,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage ?? l10n.needLocationPermission,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await Geolocator.openLocationSettings();
              },
              icon: const Icon(Icons.settings),
              label: Text(l10n.openSettings),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableLocation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 雷达动画
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 背景圆圈
                  ...List.generate(3, (index) {
                    return Container(
                      width: 60.0 + index * 50,
                      height: 60.0 + index * 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3 - index * 0.1),
                          width: 1,
                        ),
                      ),
                    );
                  }),
                  // 中心图标
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_pin_circle,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Builder(builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Column(
                children: [
                  Text(
                    l10n.enableLocationToDiscover,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.locationVisibilityInfo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _enableLocation,
                    icon: const Icon(Icons.location_on),
                    label: Text(l10n.enableLocation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 雷达扫描动画
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 圆圈
                ...List.generate(4, (index) {
                  return Container(
                    width: 50.0 + index * 40,
                    height: 50.0 + index * 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3 - index * 0.07),
                        width: 1,
                      ),
                    ),
                  );
                }),
                // 扫描线
                AnimatedBuilder(
                  animation: _radarController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _radarController.value * 2 * 3.14159,
                      child: Container(
                        width: 180,
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.primary.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // 中心点
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Builder(builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Text(
              l10n.searchingNearby,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildError() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? l10n.loadFailed,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadNearbyUsers,
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // 筛选栏
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: _showDistanceSelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.explore,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_selectedDistance}km',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_config?.allowFilter ?? true)
                GestureDetector(
                  onTap: _showGenderFilter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedGender == 0
                              ? Icons.people
                              : _selectedGender == 1
                                  ? Icons.male
                                  : Icons.female,
                          size: 16,
                          color: _selectedGender == 1
                              ? Colors.blue
                              : _selectedGender == 2
                                  ? Colors.pink
                                  : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedGender == 0
                              ? l10n.all
                              : _selectedGender == 1
                                  ? l10n.male
                                  : l10n.female,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                l10n.peopleCount(_users.length),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 用户列表
        Expanded(
          child: _users.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadNearbyUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      return _buildUserCard(_users[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noNearbyUsers,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tryExpandRange,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(NearbyUser user) {
    final avatarUrl = _getFullUrl(user.avatar);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _viewUserProfile(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 头像
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: user.gender == 1
                        ? Colors.blue.withOpacity(0.1)
                        : user.gender == 2
                            ? Colors.pink.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
                    child: avatarUrl.isEmpty
                        ? Icon(
                            user.gender == 1
                                ? Icons.male
                                : user.gender == 2
                                    ? Icons.female
                                    : Icons.person,
                            size: 28,
                            color: user.gender == 1
                                ? Colors.blue
                                : user.gender == 2
                                    ? Colors.pink
                                    : Colors.grey,
                          )
                        : null,
                  ),
                  // 性别标识
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: user.gender == 1
                            ? Colors.blue
                            : user.gender == 2
                                ? Colors.pink
                                : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Icon(
                        user.gender == 1 ? Icons.male : Icons.female,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // 用户信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.nickname,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.age != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: user.gender == 1
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.pink.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Builder(builder: (context) {
                              final l10n = AppLocalizations.of(context)!;
                              return Text(
                                l10n.ageYears(user.age!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: user.gender == 1
                                      ? Colors.blue
                                      : Colors.pink,
                                ),
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      Text(
                        user.bio!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 2),
                        Text(
                          user.formattedDistance,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        if (user.city != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            user.city!,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 打招呼按钮
              Builder(builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                return ElevatedButton(
                  onPressed: () => _sendGreet(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: Text(l10n.greet),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _viewUserProfile(NearbyUser user) async {
    // 记录查看
    await _api.recordView(user.userId, distance: user.distance);

    if (!mounted) return;

    // 显示用户信息弹窗
    _showUserInfoDialog(user);
  }

  void _showUserInfoDialog(NearbyUser user) {
    final avatarUrl = _getFullUrl(user.avatar);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头像
              CircleAvatar(
                radius: 50,
                backgroundColor: user.gender == 1
                    ? Colors.blue.withOpacity(0.1)
                    : user.gender == 2
                        ? Colors.pink.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl.proxied) : null,
                child: avatarUrl.isEmpty
                    ? Icon(
                        user.gender == 1
                            ? Icons.male
                            : user.gender == 2
                                ? Icons.female
                                : Icons.person,
                        size: 40,
                        color: user.gender == 1
                            ? Colors.blue
                            : user.gender == 2
                                ? Colors.pink
                                : Colors.grey,
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              // 昵称
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    user.nickname,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: user.gender == 1
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.pink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          user.gender == 1 ? Icons.male : Icons.female,
                          size: 14,
                          color: user.gender == 1 ? Colors.blue : Colors.pink,
                        ),
                        if (user.age != null) ...[
                          const SizedBox(width: 2),
                          Text(
                            '${user.age}',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  user.gender == 1 ? Colors.blue : Colors.pink,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 距离和位置
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    user.formattedDistance,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (user.city != null) ...[
                    Text(' · ', style: TextStyle(color: Colors.grey[400])),
                    Text(user.city!, style: TextStyle(color: Colors.grey[600])),
                  ],
                ],
              ),
              if (user.bio != null && user.bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  user.bio!,
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 24),
              // 操作按钮
              Builder(builder: (ctx) {
                final l10n = AppLocalizations.of(ctx)!;
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _sendGreet(user);
                        },
                        icon: const Icon(Icons.waving_hand),
                        label: Text(l10n.greet),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _addFriend(user);
                        },
                        icon: const Icon(Icons.person_add),
                        label: Text(l10n.addFriend),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addFriend(NearbyUser user) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final friendApi = FriendApi(ApiClient());
      final result = await friendApi.addFriend(
        userId: user.userId,
        message: l10n.foundYouNearby,
      );
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.requestSent)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? l10n.sendFailed)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.sendFailed}: $e')),
        );
      }
    }
  }

  Future<void> _sendGreet(NearbyUser user) async {
    final l10n = AppLocalizations.of(context)!;
    // 显示打招呼内容选择
    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.greetToUser(user.nickname)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGreetOption(l10n.greetOption1),
            _buildGreetOption(l10n.greetOption2),
            _buildGreetOption(l10n.greetOption3),
          ],
        ),
      ),
    );

    if (content == null) return;

    try {
      final result = await _api.sendGreet(user.userId, content: content);
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.greetingSent)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? l10n.sendFailed)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.sendFailed}: $e')),
        );
      }
    }
  }

  Widget _buildGreetOption(String text) {
    return ListTile(
      title: Text(text),
      onTap: () => Navigator.pop(context, text),
    );
  }

  void _showViewers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NearbyViewersScreen()),
    );
  }

  void _showGreets() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NearbyGreetsScreen()),
    );
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentLat = position.latitude;
      _currentLon = position.longitude;

      final result = await _api.updateLocation(
        latitude: _currentLat,
        longitude: _currentLon,
      );

      final l10n = AppLocalizations.of(context)!;
      if (result.success) {
        await _loadNearbyUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.locationRefreshed)),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result.message ?? l10n.refreshLocationFailed;
        });
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        _errorMessage = '${l10n.getLocationFailed}: $e';
      });
    }
  }

  void _showSettings() {
    final l10n = AppLocalizations.of(context)!;
    int visibility = 1; // 1公开 0隐藏 2仅异性
    bool showCity = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.locationSettings,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.whoCanSeeMe,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              _buildVisibilityOption(
                setModalState,
                visibility,
                1,
                l10n.everyone,
                l10n.everyoneNearby,
                Icons.public,
                (v) => setModalState(() => visibility = v),
              ),
              _buildVisibilityOption(
                setModalState,
                visibility,
                2,
                l10n.oppositeGenderOnly,
                l10n.onlyOppositeGender,
                Icons.favorite,
                (v) => setModalState(() => visibility = v),
              ),
              _buildVisibilityOption(
                setModalState,
                visibility,
                0,
                l10n.hide,
                l10n.notInNearbyList,
                Icons.visibility_off,
                (v) => setModalState(() => visibility = v),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.showCity),
                subtitle: Text(l10n.othersCanSeeCity),
                value: showCity,
                onChanged: (v) => setModalState(() => showCity = v),
                activeColor: AppColors.primary,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _saveSettings(visibility, showCity);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(l10n.saveSettings),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityOption(
    StateSetter setModalState,
    int currentValue,
    int value,
    String title,
    String subtitle,
    IconData icon,
    ValueChanged<int> onChanged,
  ) {
    final isSelected = currentValue == value;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isSelected ? AppColors.primary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings(int visibility, bool showCity) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await _api.updateSettings(
        visibility: visibility,
        showCity: showCity,
      );
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.settingsSaved)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? l10n.saveFailed)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.saveFailed}: $e')),
        );
      }
    }
  }

}
