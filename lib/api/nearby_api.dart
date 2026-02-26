/// 附近的人 API
import 'package:im_client/api/api_client.dart';

/// 附近的人配置
class NearbyConfig {
  final double maxDistance;
  final double defaultDistance;
  final int locationExpireHours;
  final int refreshInterval;
  final int maxResultsPerPage;
  final bool allowFilter;
  final int minAge;
  final int maxAge;
  final bool enableNearby;
  final List<double> distanceOptions;

  NearbyConfig({
    required this.maxDistance,
    required this.defaultDistance,
    required this.locationExpireHours,
    required this.refreshInterval,
    required this.maxResultsPerPage,
    required this.allowFilter,
    required this.minAge,
    required this.maxAge,
    required this.enableNearby,
    required this.distanceOptions,
  });

  factory NearbyConfig.fromJson(Map<String, dynamic> json) {
    List<double> distances = [];
    final distanceStr = json['distance_options'] as String? ?? '0.5,1,2,5,10';
    for (var d in distanceStr.split(',')) {
      distances.add(double.tryParse(d.trim()) ?? 1.0);
    }

    return NearbyConfig(
      maxDistance: (json['max_distance'] as num?)?.toDouble() ?? 10.0,
      defaultDistance: (json['default_distance'] as num?)?.toDouble() ?? 1.0,
      locationExpireHours: json['location_expire_hours'] as int? ?? 24,
      refreshInterval: json['refresh_interval'] as int? ?? 300,
      maxResultsPerPage: json['max_results_per_page'] as int? ?? 50,
      allowFilter: json['allow_filter'] as bool? ?? true,
      minAge: json['min_age'] as int? ?? 18,
      maxAge: json['max_age'] as int? ?? 100,
      enableNearby: json['enable_nearby'] as bool? ?? true,
      distanceOptions: distances,
    );
  }
}

/// 用户位置
class UserLocation {
  final int id;
  final int userId;
  final double latitude;
  final double longitude;
  final String? city;
  final String? district;
  final int visibility;
  final bool showCity;
  final DateTime expireAt;
  final DateTime updatedAt;

  UserLocation({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.city,
    this.district,
    required this.visibility,
    required this.showCity,
    required this.expireAt,
    required this.updatedAt,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    return UserLocation(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      city: json['city'] as String?,
      district: json['district'] as String?,
      visibility: json['visibility'] as int? ?? 1,
      showCity: json['show_city'] as bool? ?? true,
      expireAt: json['expire_at'] != null
          ? DateTime.parse(json['expire_at'])
          : DateTime.now().add(const Duration(hours: 24)),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }
}

/// 附近的用户
class NearbyUser {
  final int userId;
  final String nickname;
  final String avatar;
  final int gender;
  final String? bio;
  final int? age;
  final double distance;
  final String? city;
  final String? district;
  final DateTime updatedAt;

  NearbyUser({
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.gender,
    this.bio,
    this.age,
    required this.distance,
    this.city,
    this.district,
    required this.updatedAt,
  });

  factory NearbyUser.fromJson(Map<String, dynamic> json) {
    return NearbyUser(
      userId: json['user_id'] as int? ?? 0,
      nickname: json['nickname'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      gender: json['gender'] as int? ?? 0,
      bio: json['bio'] as String?,
      age: json['age'] as int?,
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      city: json['city'] as String?,
      district: json['district'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  /// 格式化距离显示
  String get formattedDistance {
    if (distance < 0.1) {
      return '< 100m';
    } else if (distance < 1) {
      return '${(distance * 1000).round()}m';
    } else {
      return '${distance.toStringAsFixed(1)}km';
    }
  }
}

/// 浏览记录
class NearbyView {
  final int id;
  final int viewerId;
  final int viewedId;
  final double distance;
  final DateTime createdAt;
  final NearbyViewUser? viewer;

  NearbyView({
    required this.id,
    required this.viewerId,
    required this.viewedId,
    required this.distance,
    required this.createdAt,
    this.viewer,
  });

  factory NearbyView.fromJson(Map<String, dynamic> json) {
    return NearbyView(
      id: json['id'] as int? ?? 0,
      viewerId: json['viewer_id'] as int? ?? 0,
      viewedId: json['viewed_id'] as int? ?? 0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      viewer: json['viewer'] != null
          ? NearbyViewUser.fromJson(json['viewer'])
          : null,
    );
  }
}

/// 浏览用户简要信息
class NearbyViewUser {
  final int id;
  final String nickname;
  final String avatar;
  final int gender;

  NearbyViewUser({
    required this.id,
    required this.nickname,
    required this.avatar,
    required this.gender,
  });

  factory NearbyViewUser.fromJson(Map<String, dynamic> json) {
    return NearbyViewUser(
      id: json['id'] as int? ?? 0,
      nickname: json['nickname'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      gender: json['gender'] as int? ?? 0,
    );
  }
}

/// 打招呼记录
class NearbyGreet {
  final int id;
  final int fromId;
  final int toId;
  final String content;
  final int type;
  final int status;
  final DateTime createdAt;
  final NearbyViewUser? fromUser;

  NearbyGreet({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.content,
    required this.type,
    required this.status,
    required this.createdAt,
    this.fromUser,
  });

  factory NearbyGreet.fromJson(Map<String, dynamic> json) {
    return NearbyGreet(
      id: json['id'] as int? ?? 0,
      fromId: json['from_id'] as int? ?? 0,
      toId: json['to_id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      type: json['type'] as int? ?? 1,
      status: json['status'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      fromUser: json['from_user'] != null
          ? NearbyViewUser.fromJson(json['from_user'])
          : null,
    );
  }
}

/// 附近的人 API 客户端
class NearbyApi {
  final ApiClient _client;

  NearbyApi(this._client);

  /// 获取配置
  Future<ApiResponse> getConfig() async {
    return _client.get('/nearby/config');
  }

  /// 更新位置
  Future<ApiResponse> updateLocation({
    required double latitude,
    required double longitude,
    String? city,
    String? district,
    String? address,
    int visibility = 1,
    bool showCity = true,
  }) async {
    return _client.post('/nearby/location', data: {
      'latitude': latitude,
      'longitude': longitude,
      if (city != null) 'city': city,
      if (district != null) 'district': district,
      if (address != null) 'address': address,
      'visibility': visibility,
      'show_city': showCity,
    });
  }

  /// 获取我的位置
  Future<ApiResponse> getMyLocation() async {
    return _client.get('/nearby/location');
  }

  /// 清除位置
  Future<ApiResponse> clearLocation() async {
    return _client.delete('/nearby/location');
  }

  /// 更新位置设置
  Future<ApiResponse> updateSettings({
    required int visibility,
    required bool showCity,
  }) async {
    return _client.put('/nearby/settings', data: {
      'visibility': visibility,
      'show_city': showCity,
    });
  }

  /// 获取附近的用户
  Future<ApiResponse> getNearbyUsers({
    double? latitude,
    double? longitude,
    double distance = 1.0,
    int gender = 0,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'distance': distance,
      'gender': gender,
      'page': page,
      'page_size': pageSize,
    };
    if (latitude != null) params['latitude'] = latitude;
    if (longitude != null) params['longitude'] = longitude;

    return _client.get('/nearby/users', queryParameters: params);
  }

  /// 获取谁看过我
  Future<ApiResponse> getViewers({
    int page = 1,
    int pageSize = 20,
  }) async {
    return _client.get('/nearby/viewers', queryParameters: {
      'page': page,
      'page_size': pageSize,
    });
  }

  /// 记录查看
  Future<ApiResponse> recordView(int userId, {double? distance}) async {
    return _client.post('/nearby/view/$userId', queryParameters: {
      if (distance != null) 'distance': distance,
    });
  }

  /// 打招呼
  Future<ApiResponse> sendGreet(
    int userId, {
    String? content,
    int type = 1,
  }) async {
    return _client.post('/nearby/greet/$userId', data: {
      if (content != null) 'content': content,
      'type': type,
    });
  }

  /// 获取收到的打招呼
  Future<ApiResponse> getGreets({
    int page = 1,
    int pageSize = 20,
  }) async {
    return _client.get('/nearby/greets', queryParameters: {
      'page': page,
      'page_size': pageSize,
    });
  }
}
