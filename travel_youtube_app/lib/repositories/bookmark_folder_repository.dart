import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/bookmark_folder_model.dart';
import '../models/bookmark_model.dart';
import '../models/walking_course_model.dart';
import '../utils/dio_error_handler.dart';

class BookmarkFolderRepository {
  final Dio _dio = DioClient().dio;

  Future<BookmarkFolderModel> createFolder(String name) async {
    try {
      final response = await _dio.post('/bookmark-folders', data: {'name': name});
      final data = response.data['data'] as Map<String, dynamic>;
      return BookmarkFolderModel(
        folderId: data['folderId'] as String,
        name: data['name'] as String,
        bookmarkCount: 0,
        createdAt: DateTime.parse(data['createdAt'] as String),
      );
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<BookmarkFolderModel>> listFolders() async {
    try {
      final response = await _dio.get('/bookmark-folders');
      final folders = response.data['data']['folders'] as List<dynamic>;
      return folders.map((e) => BookmarkFolderModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> deleteFolder(String folderId) async {
    try {
      await _dio.delete('/bookmark-folders/$folderId');
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<BookmarkModel>> listBookmarksInFolder(String folderId) async {
    try {
      final response = await _dio.get('/bookmark-folders/$folderId/bookmarks');
      final bookmarks = response.data['data']['bookmarks'] as List<dynamic>;
      return bookmarks.map((e) => BookmarkModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  /// Builds a walking route straight from this folder's bookmarks -- no
  /// hotel and no trip, so it comes back shaped like a 뚜벅이 코스 result and
  /// is rendered by the same screen.
  Future<WalkingCourseModel> createRoute(String folderId) async {
    try {
      final response = await _dio.post('/bookmark-folders/$folderId/route');
      return WalkingCourseModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> addBookmarkToFolder(String folderId, String bookmarkId) async {
    try {
      await _dio.post('/bookmark-folders/$folderId/bookmarks', data: {'bookmarkId': bookmarkId});
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> removeBookmarkFromFolder(String folderId, String bookmarkId) async {
    try {
      await _dio.delete('/bookmark-folders/$folderId/bookmarks/$bookmarkId');
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
