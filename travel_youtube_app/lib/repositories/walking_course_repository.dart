import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/start_point_model.dart';
import '../models/walking_course_model.dart';
import '../utils/dio_error_handler.dart';

class WalkingCourseRepository {
  final Dio _dio = DioClient().dio;

  Future<WalkingCourseModel> generate({
    required String region,
    required DateTime localTime,
    String? mood,
    String? walkDuration,
    StartPointModel? startPoint,
    List<String> avoidPlaceIds = const [],
  }) async {
    try {
      final response = await _dio.post(
        '/recommendations/walking-course',
        data: {
          'region': region,
          'localTime': localTime.toIso8601String(),
          'mood': ?mood,
          'walkDuration': ?walkDuration,
          if (startPoint != null) 'startLatitude': startPoint.latitude,
          if (startPoint != null) 'startLongitude': startPoint.longitude,
          if (startPoint != null) 'startName': startPoint.name,
          if (avoidPlaceIds.isNotEmpty) 'avoidPlaceIds': avoidPlaceIds,
        },
      );
      return WalkingCourseModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
