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
        'data': {'tripAlerts': true, 'serviceAlerts': true, 'marketingAlerts': false},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final settings = await NotificationSettingsRepository().getSettings();

    expect(settings.tripAlerts, isTrue);
    expect(settings.marketingAlerts, isFalse);
    expect(adapter.lastOptions?.path, '/notification-settings');
    expect(adapter.lastOptions?.method, 'GET');
  });

  test('updateSettings sends all three fields and maps the saved response', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'tripAlerts': false, 'serviceAlerts': false, 'marketingAlerts': true},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final settings = await NotificationSettingsRepository().updateSettings(
      const NotificationSettingsModel(tripAlerts: false, serviceAlerts: false, marketingAlerts: true),
    );

    expect(settings.marketingAlerts, isTrue);
    expect(adapter.lastOptions?.path, '/notification-settings');
    expect(adapter.lastOptions?.method, 'PUT');
    expect(adapter.lastOptions?.data, {'tripAlerts': false, 'serviceAlerts': false, 'marketingAlerts': true});
  });
}
