import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/similar_taste_recommendation_model.dart';
import '../utils/dio_error_handler.dart';

class SimilarTasteRepository {
  final Dio _dio = DioClient().dio;

  Future<SimilarTasteResultModel> getRecommendations({int? limit}) async {
    try {
      final response = await _dio.get('/recommendations/similar-taste', queryParameters: {
        'limit': ?limit,
      });
      return SimilarTasteResultModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
