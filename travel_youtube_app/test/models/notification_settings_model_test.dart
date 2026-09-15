import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/notification_settings_model.dart';

void main() {
  test('NotificationSettingsModel.fromJson parses all four toggles', () {
    final settings = NotificationSettingsModel.fromJson({
      'newVlogAlerts': true,
      'routeCompleteAlerts': false,
      'marketingAlerts': true,
      'nightSilent': false,
    });

    expect(settings.newVlogAlerts, isTrue);
    expect(settings.routeCompleteAlerts, isFalse);
    expect(settings.marketingAlerts, isTrue);
    expect(settings.nightSilent, isFalse);
  });

  test('copyWith replaces only the given fields', () {
    const settings = NotificationSettingsModel(
      newVlogAlerts: true,
      routeCompleteAlerts: true,
      marketingAlerts: false,
      nightSilent: false,
    );

    final updated = settings.copyWith(marketingAlerts: true);

    expect(updated.newVlogAlerts, isTrue);
    expect(updated.routeCompleteAlerts, isTrue);
    expect(updated.marketingAlerts, isTrue);
    expect(updated.nightSilent, isFalse);
  });

  group('allEnabled', () {
    test('true when every alert is on and night-silent is off', () {
      const settings = NotificationSettingsModel(
        newVlogAlerts: true,
        routeCompleteAlerts: true,
        marketingAlerts: true,
        nightSilent: false,
      );

      expect(settings.allEnabled, isTrue);
    });

    test('false when any alert is off', () {
      const settings = NotificationSettingsModel(
        newVlogAlerts: true,
        routeCompleteAlerts: false,
        marketingAlerts: true,
        nightSilent: false,
      );

      expect(settings.allEnabled, isFalse);
    });

    test('false when night-silent is on', () {
      const settings = NotificationSettingsModel(
        newVlogAlerts: true,
        routeCompleteAlerts: true,
        marketingAlerts: true,
        nightSilent: true,
      );

      expect(settings.allEnabled, isFalse);
    });
  });
}
