import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/nearby_recommendation_model.dart';
import '../utils/dio_error_handler.dart';

class RecommendationRepository {
  final Dio _dio = DioClient().dio;

  Future<List<NearbyRecommendationModel>> getNearby({
    required double latitude,
    required double longitude,
    required DateTime localTime,
    int? radiusMeters,
    int? limit,
  }) async {
    try {
      final response = await _dio.post('/recommendations/nearby', data: {
        'latitude': latitude,
        'longitude': longitude,
        'localTime': localTime.toIso8601String(),
        'radiusMeters': ?radiusMeters,
        'limit': ?limit,
      });
      final list = response.data['data']['recommendations'] as List<dynamic>;
      return list.map((e) => NearbyRecommendationModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
