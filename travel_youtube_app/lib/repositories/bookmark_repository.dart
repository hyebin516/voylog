import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/bookmark_model.dart';
import '../utils/dio_error_handler.dart';

class BookmarkRepository {
  final Dio _dio = DioClient().dio;

  Future<String> addBookmark(String placeId) async {
    try {
      final response = await _dio.post('/bookmarks', data: {'placeId': placeId});
      return response.data['data']['bookmarkId'] as String;
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<BookmarkModel>> listBookmarks() async {
    try {
      final response = await _dio.get('/bookmarks');
      final bookmarks = response.data['data']['bookmarks'] as List<dynamic>;
      return bookmarks.map((e) => BookmarkModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> removeBookmark(String bookmarkId) async {
    try {
      await _dio.delete('/bookmarks/$bookmarkId');
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
