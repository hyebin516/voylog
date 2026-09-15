import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/trip_model.dart';
import '../utils/dio_error_handler.dart';

class TripRepository {
  final Dio _dio = DioClient().dio;

  /// [startDate]/[endDate] are sent as `YYYY-MM-DD` (no time component --
  /// a trip's dates aren't tied to a timezone) and are optional.
  Future<TripModel> createTrip(
    String name, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _dio.post(
        '/trips',
        data: {
          'name': name,
          if (startDate != null) 'startDate': _isoDate(startDate),
          if (endDate != null) 'endDate': _isoDate(endDate),
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return TripModel(
        tripId: data['tripId'] as String,
        name: data['name'] as String,
        dayCount: 0,
        startDate: data['startDate'] != null
            ? DateTime.parse(data['startDate'] as String)
            : null,
        endDate: data['endDate'] != null
            ? DateTime.parse(data['endDate'] as String)
            : null,
        createdAt: DateTime.parse(data['createdAt'] as String),
      );
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<List<TripModel>> listTrips() async {
    try {
      final response = await _dio.get('/trips');
      final trips = response.data['data']['trips'] as List<dynamic>;
      return trips
          .map((e) => TripModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<TripDetailModel> getTrip(String tripId) async {
    try {
      final response = await _dio.get('/trips/$tripId');
      return TripDetailModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
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

  Future<void> updateTripDates(
    String tripId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      await _dio.patch(
        '/trips/$tripId',
        data: {'startDate': _isoDate(startDate), 'endDate': _isoDate(endDate)},
      );
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
