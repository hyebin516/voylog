import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/saved_walking_course_model.dart';
import '../models/walking_course_model.dart';
import '../utils/dio_error_handler.dart';

class SavedWalkingCourseRepository {
  final Dio _dio = DioClient().dio;

  Future<SavedWalkingCourseModel> save({required String region, required WalkingCourseRouteModel course}) async {
    try {
      final response = await _dio.post('/walking-courses', data: {
        'region': region,
        'routeType': course.routeType,
        'transportMode': course.transportMode,
        'totalDistanceM': course.totalDistanceM,
        'totalDurationSec': course.totalDurationSec,
        'routeData': course.routeData
            .map((p) => {
                  'order': p.order,
                  'type': p.type,
                  'hotelId': p.hotelId,
                  'placeId': p.placeId,
                  'name': p.name,
                  'latitude': p.latitude,
                  'longitude': p.longitude,
                })
            .toList(),
      });
      return SavedWalkingCourseModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<SavedWalkingCourseModel>> list() async {
    try {
      final response = await _dio.get('/walking-courses');
      final list = response.data['data']['savedCourses'] as List<dynamic>;
      return list.map((e) => SavedWalkingCourseModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> delete(String savedCourseId) async {
    try {
      await _dio.delete('/walking-courses/$savedCourseId');
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
