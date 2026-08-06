import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/notification_settings_model.dart';
import '../utils/dio_error_handler.dart';

class NotificationSettingsRepository {
  final Dio _dio = DioClient().dio;

  Future<NotificationSettingsModel> getSettings() async {
    try {
      final response = await _dio.get('/notification-settings');
      return NotificationSettingsModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<NotificationSettingsModel> updateSettings(NotificationSettingsModel settings) async {
    try {
      final response = await _dio.put('/notification-settings', data: {
        'tripAlerts': settings.tripAlerts,
        'serviceAlerts': settings.serviceAlerts,
        'marketingAlerts': settings.marketingAlerts,
      });
      return NotificationSettingsModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
