/// API客户端
/// 封装网络请求，处理认证、错误等

import 'package:dio/dio.dart';
import 'package:im_client/config/env_config.dart';
import 'package:im_client/services/device_info_service.dart';
import 'package:im_client/services/storage_service.dart';
import 'package:im_client/utils/crypto_utils.dart';

/// API客户端单例
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio _dio;
  String? _token;
  String _language = 'en'; // 默认英文
  String? _deviceType;
  String? _deviceId;

  /// Token过期且刷新失败时的回调（由 AuthProvider 设置）
  void Function()? onAuthExpired;

  /// 初始化设备信息（应在应用启动后尽早调用）
  Future<void> initDeviceInfo() async {
    try {
      final info = await DeviceInfoService().getDeviceInfo();
      _deviceType = info.deviceType;
      _deviceId = info.deviceId;
    } catch (e) {
      // ignore
    }
  }

  ApiClient._internal() {
    final env = EnvConfig.instance;
    _dio = Dio(BaseOptions(
      baseUrl: env.fullApiUrl,
      connectTimeout: Duration(milliseconds: env.timeout),
      receiveTimeout: Duration(milliseconds: env.timeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // 添加加密拦截器（最先处理请求，最后处理响应）
    if (CryptoUtils.isInitialized) {
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          // Encrypt JSON body (skip FormData / file uploads)
          // 跳过已加密的数据（防止 token 刷新重试时二次加密）
          if (options.data != null &&
              options.data is Map &&
              !(options.data as Map).containsKey('_e')) {
            options.data = CryptoUtils.encryptJson(
              Map<String, dynamic>.from(options.data as Map),
            );
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // Decrypt {"_e": "..."} response
          if (response.data is Map && response.data.containsKey('_e')) {
            final decrypted = CryptoUtils.tryDecryptJson(
              Map<String, dynamic>.from(response.data as Map),
            );
            if (decrypted != null) {
              response.data = decrypted;
            }
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          // Decrypt error response body if encrypted
          if (error.response?.data is Map &&
              (error.response!.data as Map).containsKey('_e')) {
            final decrypted = CryptoUtils.tryDecryptJson(
              Map<String, dynamic>.from(error.response!.data as Map),
            );
            if (decrypted != null) {
              error.response!.data = decrypted;
            }
          }
          return handler.next(error);
        },
      ));
    }

    // 添加拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 添加Token
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        // 添加语言头部
        options.headers['X-Language'] = _language;
        // 添加设备信息头部
        if (_deviceType != null) {
          options.headers['X-Device-Type'] = _deviceType;
        }
        if (_deviceId != null) {
          options.headers['X-Device-ID'] = _deviceId;
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (error, handler) async {
        // 处理401错误（Token过期）
        if (error.response?.statusCode == 401) {
          // 尝试刷新Token
          final refreshed = await _refreshToken();
          if (refreshed) {
            // 重试请求
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer $_token';
            try {
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          } else {
            // 刷新失败，Token彻底过期，触发登出回到登录页
            onAuthExpired?.call();
          }
        }
        return handler.next(error);
      },
    ));
  }

  /// 设置Token
  void setToken(String? token) {
    _token = token;
  }

  /// 获取Token
  String? get token => _token;

  /// 设置语言（用于X-Language头部）
  void setLanguage(String language) {
    _language = language;
  }

  /// 获取当前语言
  String get language => _language;

  /// 获取Dio实例（用于特殊请求，如Blob URL）
  Dio get dio => _dio;

  /// 刷新Token
  Future<bool> _refreshToken() async {
    if (_token == null) return false;

    try {
      final response = await _dio.post(
        '/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
      if (response.data['code'] == 0) {
        _token = response.data['data']['token'];
        await StorageService().setToken(_token!);
        return true;
      }
    } catch (e) {
      // 刷新失败
    }
    return false;
  }

  /// GET请求
  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// POST请求
  Future<ApiResponse> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      print('[API POST] $path');
      print('[API POST] data: $data');
      print('[API POST] token: ${_token != null ? "已设置" : "未设置"}');
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      print('[API POST] response: ${response.data}');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      print('[API POST] error: ${e.message}');
      print('[API POST] error response: ${e.response?.data}');
      return _handleError(e);
    }
  }

  /// PUT请求
  Future<ApiResponse> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// DELETE请求
  Future<ApiResponse> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// 上传文件（仅支持移动端，Web平台请使用 uploadBytes）
  Future<ApiResponse> upload(
    String path,
    String filePath, {
    String fieldName = 'file',
    Map<String, dynamic>? extraData,
    ProgressCallback? onProgress,
  }) async {
    try {
      // 从文件路径中提取文件名
      final fileName = filePath.split('/').last.split('\\').last;
      print('[ApiClient] Uploading file: $filePath, filename: $fileName');

      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath, filename: fileName),
        ...?extraData,
      });

      final response = await _dio.post(
        path,
        data: formData,
        onSendProgress: onProgress,
      );
      print('[ApiClient] Upload response: ${response.data}');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      print('[ApiClient] Upload error: ${e.message}, response: ${e.response?.data}');
      return _handleError(e);
    }
  }

  /// 上传文件（从字节数据，跨平台兼容）
  Future<ApiResponse> uploadBytes(
    String path,
    List<int> bytes,
    String fileName, {
    String fieldName = 'file',
    String? mimeType,
    Map<String, dynamic>? extraData,
    ProgressCallback? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: MultipartFile.fromBytes(
          bytes,
          filename: fileName,
        ),
        ...?extraData,
      });

      final response = await _dio.post(
        path,
        data: formData,
        onSendProgress: onProgress,
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// 处理错误
  ApiResponse _handleError(DioException e) {
    String message;
    int code = -1;

    if (e.response != null) {
      code = e.response!.statusCode ?? -1;
      final data = e.response!.data;
      if (data is Map && data.containsKey('message')) {
        message = data['message'];
      } else {
        message = _getErrorMessage(code);
      }
    } else {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message = '网络连接超时';
          break;
        case DioExceptionType.connectionError:
          message = '网络连接失败';
          break;
        default:
          message = '网络请求失败';
      }
    }

    return ApiResponse.error(message, code);
  }

  /// 获取错误消息
  String _getErrorMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return '请求参数错误';
      case 401:
        return '未登录或登录已过期';
      case 403:
        return '没有操作权限';
      case 404:
        return '请求的资源不存在';
      case 500:
        return '服务器内部错误';
      default:
        return '请求失败';
    }
  }
}

/// API响应封装
class ApiResponse {
  final bool success;
  final dynamic data;
  final String? message;
  final int code;
  final dynamic rawData; // 原始完整响应（用于访问顶层字段如 stream_mode）

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.code = 0,
    this.rawData,
  });

  /// Alias for success
  bool get isSuccess => success;

  factory ApiResponse.success(dynamic responseData) {
    if (responseData is Map) {
      final code = responseData['code'] ?? 0;
      // 服务器返回 code: 200 表示成功，兼容 code: 0
      return ApiResponse(
        success: code == 0 || code == 200,
        data: responseData['data'],
        message: responseData['message'],
        code: code,
        rawData: responseData,
      );
    }
    return ApiResponse(success: true, data: responseData, rawData: responseData);
  }

  factory ApiResponse.error(String message, int code) {
    return ApiResponse(
      success: false,
      message: message,
      code: code,
      rawData: {'code': code, 'message': message},
    );
  }

  /// 转换为 ApiResult
  ApiResult toResult() {
    return ApiResult(
      success: success,
      message: message,
      data: data,
    );
  }
}

/// 统一的API操作结果封装
/// 用于需要返回操作结果和消息的场景
class ApiResult {
  final bool success;
  final String? message;
  final dynamic data;

  ApiResult({required this.success, this.message, this.data});

  /// 默认的成功/失败消息
  String get displayMessage {
    if (message != null && message!.isNotEmpty) {
      return message!;
    }
    return success ? '操作成功' : '操作失败';
  }
}
