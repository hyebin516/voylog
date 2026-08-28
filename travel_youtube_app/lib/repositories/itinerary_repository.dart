import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/itinerary_model.dart';
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
}
