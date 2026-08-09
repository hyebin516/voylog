import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../utils/dio_error_handler.dart';

class BehaviorRepository {
  final Dio _dio = DioClient().dio;

  Future<void> record({
    required String placeId,
    required String action,
    String? screen,
    int? distanceMeters,
  }) async {
    try {
      await _dio.post('/recommendations/behaviors', data: {
        'placeId': placeId,
        'action': action,
        'screen': ?screen,
        'distanceMeters': ?distanceMeters,
      });
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
