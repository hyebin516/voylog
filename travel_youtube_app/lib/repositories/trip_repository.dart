import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/trip_model.dart';
import '../utils/dio_error_handler.dart';

class TripRepository {
  final Dio _dio = DioClient().dio;

  Future<TripModel> createTrip(String name) async {
    try {
      final response = await _dio.post('/trips', data: {'name': name});
      final data = response.data['data'] as Map<String, dynamic>;
      return TripModel(
        tripId: data['tripId'] as String,
        name: data['name'] as String,
        dayCount: 0,
        createdAt: DateTime.parse(data['createdAt'] as String),
      );
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<TripModel>> listTrips() async {
    try {
      final response = await _dio.get('/trips');
      final trips = response.data['data']['trips'] as List<dynamic>;
      return trips.map((e) => TripModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<TripDetailModel> getTrip(String tripId) async {
    try {
      final response = await _dio.get('/trips/$tripId');
      return TripDetailModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> deleteTrip(String tripId) async {
    try {
      await _dio.delete('/trips/$tripId');
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
