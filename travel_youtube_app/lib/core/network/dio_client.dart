import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env.dart';
import '../constants/storage_keys.dart';
import '../../models/api_exception.dart';

/// A single shared Dio instance for the whole app.
/// All repositories must use this instance instead of creating their own.
class DioClient {
  DioClient._internal();

  static final DioClient _instance = DioClient._internal();

  factory DioClient() => _instance;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  late final Dio dio = _createDio();

  /// Called by AuthProvider when the session becomes invalid (401/403),
  /// so the app can navigate back to the login screen.
  void Function()? onUnauthorized;

  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        contentType: 'application/json',
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: StorageKeys.jwt);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(_normalizeError(error));
        },
      ),
    );

    return dio;
  }

  DioException _normalizeError(DioException error) {
    final statusCode = error.response?.statusCode;

    if (statusCode == 401 || statusCode == 403) {
      onUnauthorized?.call();
    }

    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final errorBody = data['error'] as Map;
      return error.copyWith(
        error: ApiException(
          code: errorBody['code'] as String? ?? 'UNKNOWN_ERROR',
          message: errorBody['message'] as String? ?? 'Unknown error',
        ),
      );
    }

    if (statusCode == null) {
      return error.copyWith(
        error: const ApiException(code: 'NETWORK_ERROR', message: 'Network error'),
      );
    }

    return error.copyWith(
      error: const ApiException(code: 'INTERNAL_ERROR', message: 'Internal server error'),
    );
  }
}
