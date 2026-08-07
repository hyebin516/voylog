import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/taste_preference_model.dart';
import '../utils/dio_error_handler.dart';

class TastePreferenceRepository {
  final Dio _dio = DioClient().dio;

  Future<TastePreferenceModel> getPreferences() async {
    try {
      final response = await _dio.get('/taste-preferences');
      return TastePreferenceModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<TastePreferenceModel> setPreferences(List<String> tags) async {
    try {
      final response = await _dio.put('/taste-preferences', data: {'tags': tags});
      return TastePreferenceModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> clearPreferences() async {
    try {
      await _dio.delete('/taste-preferences');
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
