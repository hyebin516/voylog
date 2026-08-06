import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/notification_settings_model.dart';
import 'package:travel_youtube_app/providers/notification_settings_provider.dart';
import 'package:travel_youtube_app/repositories/notification_settings_repository.dart';
import 'package:travel_youtube_app/screens/notification_settings_screen.dart';

const NotificationSettingsModel _defaults = NotificationSettingsModel(
  tripAlerts: true,
  serviceAlerts: true,
  marketingAlerts: false,
);

class FakeNotificationSettingsRepository extends NotificationSettingsRepository {
  NotificationSettingsModel settingsToReturn = _defaults;
  ApiException? getError;
  NotificationSettingsModel? lastUpdate;

  @override
  Future<NotificationSettingsModel> getSettings() async {
    if (getError != null) throw getError!;
    return settingsToReturn;
  }

  @override
  Future<NotificationSettingsModel> updateSettings(NotificationSettingsModel settings) async {
    lastUpdate = settings;
    return settings;
  }
}

Widget _wrap(NotificationSettingsProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: const MaterialApp(home: NotificationSettingsScreen()),
  );
}

void main() {
  testWidgets('shows the three toggles with their loaded values', (tester) async {
    final repository = FakeNotificationSettingsRepository()
      ..settingsToReturn = const NotificationSettingsModel(tripAlerts: true, serviceAlerts: false, marketingAlerts: true);
    await tester.pumpWidget(_wrap(NotificationSettingsProvider(repository: repository)));
    await tester.pumpAndSettle();

    final tripSwitch = tester.widget<SwitchListTile>(find.byKey(const Key('tripAlertsSwitch')));
    final serviceSwitch = tester.widget<SwitchListTile>(find.byKey(const Key('serviceAlertsSwitch')));
    final marketingSwitch = tester.widget<SwitchListTile>(find.byKey(const Key('marketingAlertsSwitch')));

    expect(tripSwitch.value, isTrue);
    expect(serviceSwitch.value, isFalse);
    expect(marketingSwitch.value, isTrue);
  });

  testWidgets('toggling a switch persists the change through the repository', (tester) async {
    final repository = FakeNotificationSettingsRepository();
    await tester.pumpWidget(_wrap(NotificationSettingsProvider(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('marketingAlertsSwitch')));
    await tester.pumpAndSettle();

    expect(repository.lastUpdate?.marketingAlerts, isTrue);
  });

  testWidgets('shows an error view when loading fails', (tester) async {
    final repository = FakeNotificationSettingsRepository()
      ..getError = const ApiException(code: 'NETWORK_ERROR', message: 'boom');
    await tester.pumpWidget(_wrap(NotificationSettingsProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);
  });
}
