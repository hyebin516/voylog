import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/models/notification_settings_model.dart';
import 'package:travel_youtube_app/repositories/notification_settings_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('getSettings maps the JSON response into a NotificationSettingsModel', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'tripStartAlerts': true, 'routeCompleteAlerts': true, 'marketingAlerts': false, 'nightSilent': false},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final settings = await NotificationSettingsRepository().getSettings();

    expect(settings.tripStartAlerts, isTrue);
    expect(settings.marketingAlerts, isFalse);
    expect(adapter.lastOptions?.path, '/notification-settings');
    expect(adapter.lastOptions?.method, 'GET');
  });

  test('updateSettings sends all four fields and maps the saved response', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'tripStartAlerts': false, 'routeCompleteAlerts': false, 'marketingAlerts': true, 'nightSilent': true},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final settings = await NotificationSettingsRepository().updateSettings(
      const NotificationSettingsModel(
        tripStartAlerts: false,
        routeCompleteAlerts: false,
        marketingAlerts: true,
        nightSilent: true,
      ),
    );

    expect(settings.marketingAlerts, isTrue);
    expect(adapter.lastOptions?.path, '/notification-settings');
    expect(adapter.lastOptions?.method, 'PUT');
    expect(adapter.lastOptions?.data, {
      'tripStartAlerts': false,
      'routeCompleteAlerts': false,
      'marketingAlerts': true,
      'nightSilent': true,
    });
  });
}
