import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/place_search_result_model.dart';
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

  /// 폴더에 넣을 장소를 찾는다. 서버가 내 북마크와 카카오 검색 결과를
  /// 한 번에 돌려주므로 화면은 목록 하나만 그리면 된다.
  Future<List<PlaceSearchResultModel>> searchPlaces(String query) async {
    try {
      final response = await _dio.get('/places/search', queryParameters: {'query': query});
      final places = response.data['data']['places'] as List<dynamic>;
      return places
          .map((e) => PlaceSearchResultModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  /// 카카오에서 찾은 장소를 폴더에 넣는다. 아직 저장된 적 없는 장소라
  /// 서버가 적재하고 북마크까지 만들어 준다.
  Future<void> addSearchedPlaceToFolder(String folderId, PlaceSearchResultModel place) async {
    try {
      await _dio.post(
        '/bookmark-folders/$folderId/bookmarks',
        data: {'place': place.toAddPlaceBody()},
      );
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
