import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../utils/dio_error_handler.dart';

/// FR-12: hands this device's FCM registration token to the backend, which
/// is what lets it push "영상 분석 완료" and "여행 시작" notifications here.
class DeviceTokenRepository {
  final Dio _dio = DioClient().dio;

  Future<void> register(String token, String platform) async {
    try {
      await _dio.post('/device-tokens', data: {'token': token, 'platform': platform});
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> unregister(String token) async {
    try {
      await _dio.delete('/device-tokens/${Uri.encodeComponent(token)}');
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
