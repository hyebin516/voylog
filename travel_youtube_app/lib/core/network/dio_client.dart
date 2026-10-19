import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  /// Called when the stored session is no longer accepted, so the app can
  /// drop the user back to the login screen.
  ///
  /// Only for a session that has gone bad -- not for every 401. Logging in
  /// with the wrong password and changing a password with the wrong current
  /// one both answer 401 INVALID_CREDENTIALS, and treating those as a lost
  /// session logs the user out of the app for mistyping a password.
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

  /// The codes the backend answers with when the token itself is the
  /// problem (auth middleware). Anything else behind a 401 is about what
  /// the request asked for, not about the session.
  static const _sessionLostCodes = {'JWT_INVALID', 'JWT_EXPIRED'};

  /// The error mapping on its own, so a test can check which failures
  /// count as a lost session without standing up a server.
  @visibleForTesting
  DioException normalizeForTest(DioException error) => _normalizeError(error);

  DioException _normalizeError(DioException error) {
    final statusCode = error.response?.statusCode;

    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final errorBody = data['error'] as Map;
      final code = errorBody['code'] as String? ?? 'UNKNOWN_ERROR';
      if (_sessionLostCodes.contains(code)) onUnauthorized?.call();
      return error.copyWith(
        error: ApiException(
          code: code,
          message: errorBody['message'] as String? ?? 'Unknown error',
        ),
      );
    }

    // No readable body. A bare 401/403 still means the request was refused
    // outright, which is the session being gone as far as the app can tell.
    if (statusCode == 401 || statusCode == 403) {
      onUnauthorized?.call();
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
