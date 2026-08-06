import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/notification_settings_model.dart';

void main() {
  test('NotificationSettingsModel.fromJson parses all three toggles', () {
    final settings = NotificationSettingsModel.fromJson({
      'tripAlerts': true,
      'serviceAlerts': false,
      'marketingAlerts': true,
    });

    expect(settings.tripAlerts, isTrue);
    expect(settings.serviceAlerts, isFalse);
    expect(settings.marketingAlerts, isTrue);
  });

  test('copyWith replaces only the given fields', () {
    const settings = NotificationSettingsModel(tripAlerts: true, serviceAlerts: true, marketingAlerts: false);

    final updated = settings.copyWith(marketingAlerts: true);

    expect(updated.tripAlerts, isTrue);
    expect(updated.serviceAlerts, isTrue);
    expect(updated.marketingAlerts, isTrue);
  });
}
