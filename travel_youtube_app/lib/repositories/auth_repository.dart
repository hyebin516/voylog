import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants/storage_keys.dart';
import '../core/network/dio_client.dart';
import '../models/user_model.dart';
import '../utils/dio_error_handler.dart';

class AuthRepository {
  final Dio _dio = DioClient().dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<UserModel> loginWithKakao(String kakaoAccessToken) async {
    try {
      final response = await _dio.post('/auth/kakao', data: {'kakaoAccessToken': kakaoAccessToken});
      final data = response.data['data'] as Map<String, dynamic>;
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

      await _secureStorage.write(key: StorageKeys.jwt, value: token);
      await _secureStorage.write(key: StorageKeys.userId, value: user.userId);

      return user;
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<UserModel> fetchProfile() async {
    try {
      final response = await _dio.get('/auth/profile');
      return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<bool> hasValidSession() async {
    final token = await _secureStorage.read(key: StorageKeys.jwt);
    return token != null;
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: StorageKeys.jwt);
    await _secureStorage.delete(key: StorageKeys.userId);
  }

  Future<void> deleteAccount() async {
    try {
      await _dio.delete('/auth/profile');
    } on DioException catch (e) {
      throwApiException(e);
    }
    await logout();
  }
}
