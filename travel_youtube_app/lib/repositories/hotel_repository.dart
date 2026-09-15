import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/hotel_model.dart';
import '../models/hotel_search_candidate.dart';
import '../utils/dio_error_handler.dart';

class HotelRepository {
  final Dio _dio = DioClient().dio;

  Future<HotelModel> createHotel(HotelModel hotel) async {
    try {
      final response = await _dio.post('/hotels', data: hotel.toCreateJson());
      return HotelModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<HotelSearchCandidate>> searchHotels(String query) async {
    try {
      final response = await _dio.get(
        '/hotels/search',
        queryParameters: {'query': query},
      );
      final candidates = response.data['data']['candidates'] as List<dynamic>;
      return candidates
          .map((e) => HotelSearchCandidate.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final response = await _dio.get(
        '/hotels/reverse-geocode',
        queryParameters: {'latitude': latitude, 'longitude': longitude},
      );
      return response.data['data']['address'] as String?;
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<HotelModel>> listHotels() async {
    try {
      final response = await _dio.get('/hotels');
      final hotels = response.data['data']['hotels'] as List<dynamic>;
      return hotels
          .map((e) => HotelModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> deleteHotel(String hotelId) async {
    try {
      await _dio.delete('/hotels/$hotelId');
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
