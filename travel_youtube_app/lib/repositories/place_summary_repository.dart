import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/place_summary_model.dart';
import '../utils/dio_error_handler.dart';

class PlaceSummaryRepository {
  final Dio _dio = DioClient().dio;

  Future<PlaceSummaryModel> getSummary(String placeId) async {
    try {
      final response = await _dio.get('/places/$placeId/summary');
      return PlaceSummaryModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
