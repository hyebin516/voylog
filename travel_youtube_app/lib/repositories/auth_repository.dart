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
      return _storeSession(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> requestSignupOtp(String email) async {
    try {
      await _dio.post('/auth/signup/request-otp', data: {'email': email});
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> verifySignupOtp(String email, String code) async {
    try {
      await _dio.post('/auth/signup/verify-otp', data: {'email': email, 'code': code});
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<bool> checkNicknameAvailable(String nickname) async {
    try {
      final response = await _dio.get('/auth/check-nickname', queryParameters: {'nickname': nickname});
      return response.data['data']['available'] as bool;
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<UserModel> signup({required String email, required String password, required String nickname}) async {
    try {
      final response = await _dio.post('/auth/signup', data: {
        'email': email,
        'password': password,
        'nickname': nickname,
      });
      return _storeSession(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<UserModel> loginWithEmail(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
      return _storeSession(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<UserModel> _storeSession(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

    await _secureStorage.write(key: StorageKeys.jwt, value: token);
    await _secureStorage.write(key: StorageKeys.userId, value: user.userId);

    return user;
  }

  Future<UserModel> fetchProfile() async {
    try {
      final response = await _dio.get('/auth/profile');
      return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<UserModel> updateNickname(String nickname) async {
    try {
      final response = await _dio.patch('/auth/profile', data: {'nickname': nickname});
      return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  /// Uploads a photo the user picked from their own gallery. [filePath] is
  /// what `image_picker` returned -- already downscaled on the device, so
  /// this is tens of KB rather than a full-resolution camera shot.
  Future<UserModel> uploadProfileImage(String filePath) async {
    try {
      final form = FormData.fromMap({'image': await MultipartFile.fromFile(filePath)});
      final response = await _dio.put('/auth/profile/image', data: form);
      return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<UserModel> removeProfileImage() async {
    try {
      final response = await _dio.delete('/auth/profile/image');
      return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    try {
      await _dio.patch('/auth/password', data: {'currentPassword': currentPassword, 'newPassword': newPassword});
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> requestPasswordResetOtp(String email) async {
    try {
      await _dio.post('/auth/password/reset/request-otp', data: {'email': email});
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> verifyPasswordResetOtp(String email, String code) async {
    try {
      await _dio.post('/auth/password/reset/verify-otp', data: {'email': email, 'code': code});
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> resetPassword({required String email, required String newPassword}) async {
    try {
      await _dio.post('/auth/password/reset', data: {'email': email, 'newPassword': newPassword});
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
