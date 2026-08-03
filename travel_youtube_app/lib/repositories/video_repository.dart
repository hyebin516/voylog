import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/video_model.dart';
import '../utils/dio_error_handler.dart';

class VideoRepository {
  final Dio _dio = DioClient().dio;

  Future<VideoModel> analyze(String youtubeUrl) async {
    try {
      final response = await _dio.post('/videos/analyze', data: {'youtubeUrl': youtubeUrl});
      return VideoModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
