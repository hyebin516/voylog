import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/itinerary_model.dart';
import '../models/shared_route_model.dart';
import '../utils/dio_error_handler.dart';

class ItineraryRepository {
  final Dio _dio = DioClient().dio;

  Future<ItineraryModel> createItinerary({
    required String tripId,
    required int dayNumber,
    required String startHotelId,
    required String endHotelId,
    required List<String> placeIds,
    String transportMode = 'car',
  }) async {
    try {
      final response = await _dio.post('/itineraries', data: {
        'tripId': tripId,
        'dayNumber': dayNumber,
        'startHotelId': startHotelId,
        'endHotelId': endHotelId,
        'placeIds': placeIds,
        'transportMode': transportMode,
      });
      return ItineraryModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<SharedRouteModel> publish({required String itineraryId, required String title}) async {
    try {
      final response = await _dio.post('/itineraries/$itineraryId/publish', data: {'title': title});
      final data = response.data['data'] as Map<String, dynamic>;
      // The publish response has no author/like/isOwner fields (they only
      // make sense once the route is joined into the feed) -- fill in the
      // values that are trivially true for a route you just published yourself.
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
}
