import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/shared_route_model.dart';
import '../utils/dio_error_handler.dart';

class SharedRouteRepository {
  final Dio _dio = DioClient().dio;

  /// The current user's own published routes are included in this same
  /// feed (each row's `isOwner` tells them apart) rather than a separate
  /// endpoint -- lets the home screen show, edit, and delete your own
  /// shared routes right where everyone else's appear.
  Future<List<SharedRouteModel>> getFeed({int? limit}) async {
    try {
      final response = await _dio.get('/routes/shared', queryParameters: {
        'limit': ?limit,
      });
      final list = response.data['data']['routes'] as List<dynamic>;
      return list.map((e) => SharedRouteModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> like(String sharedRouteId) async {
    try {
      await _dio.post('/routes/$sharedRouteId/like');
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> unlike(String sharedRouteId) async {
    try {
      await _dio.delete('/routes/$sharedRouteId/like');
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<SharedRouteModel> updateTitle(String sharedRouteId, String title) async {
    try {
      final response = await _dio.patch('/routes/$sharedRouteId', data: {'title': title});
      final data = response.data['data'] as Map<String, dynamic>;
      // The update response has no feed-join fields (author/like/isOwner) --
      // the caller already has the full row and only needs the new title.
      return SharedRouteModel(
        sharedRouteId: data['sharedRouteId'] as String,
        title: data['title'] as String,
        authorNickname: null,
        transportMode: data['transportMode'] as String,
        placeCount: data['placeCount'] as int,
        totalDistanceM: data['totalDistanceM'] as int?,
        totalDurationSec: data['totalDurationSec'] as int?,
        likeCount: 0,
        likedByMe: false,
        isOwner: true,
        matchPercent: null,
        createdAt: DateTime.parse(data['createdAt'] as String),
      );
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> unpublish(String sharedRouteId) async {
    try {
      await _dio.delete('/routes/$sharedRouteId');
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
