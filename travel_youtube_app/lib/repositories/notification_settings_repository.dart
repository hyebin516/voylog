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
        'tripStartAlerts': settings.tripStartAlerts,
        'routeCompleteAlerts': settings.routeCompleteAlerts,
        'marketingAlerts': settings.marketingAlerts,
        'nightSilent': settings.nightSilent,
      });
      return NotificationSettingsModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
