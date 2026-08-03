import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/hotel_model.dart';
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

  Future<List<HotelModel>> listHotels() async {
    try {
      final response = await _dio.get('/hotels');
      final hotels = response.data['data']['hotels'] as List<dynamic>;
      return hotels.map((e) => HotelModel.fromJson(e as Map<String, dynamic>)).toList();
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
