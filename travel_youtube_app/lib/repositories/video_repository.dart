import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/video_model.dart';
import '../models/video_search_result_model.dart';
import '../utils/dio_error_handler.dart';

class VideoRepository {
  final Dio _dio = DioClient().dio;

  /// A first analysis waits on the transcript (up to 30s on the server) and
  /// then place extraction (up to 60s) -- a 25-minute vlog took ~32s in
  /// total, past the client-wide 30s receive timeout.
  static const Duration analyzeReceiveTimeout = Duration(seconds: 100);

  Future<VideoModel> analyze(String youtubeUrl) async {
    try {
      final response = await _dio.post(
        '/videos/analyze',
        data: {'youtubeUrl': youtubeUrl},
        options: Options(receiveTimeout: analyzeReceiveTimeout),
      );
      return VideoModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<VideoSearchResultModel>> searchByHashtag(String hashtag) async {
    try {
      final response = await _dio.get('/videos/search', queryParameters: {'hashtag': hashtag});
      final videos = response.data['data']['videos'] as List<dynamic>;
      return videos.map((e) => VideoSearchResultModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<VideoSearchResultModel>> getRecommendations({
    required List<String> regions,
    required List<String> themes,
    required String duration,
  }) async {
    try {
      final response = await _dio.post('/videos/recommendations', data: {
        'regions': regions,
        'themes': themes,
        'duration': duration,
      });
      final videos = response.data['data']['videos'] as List<dynamic>;
      return videos.map((e) => VideoSearchResultModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
