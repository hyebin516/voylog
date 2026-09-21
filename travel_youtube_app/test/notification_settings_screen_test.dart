import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/notification_settings_model.dart';
import 'package:travel_youtube_app/providers/notification_settings_provider.dart';
import 'package:travel_youtube_app/repositories/notification_settings_repository.dart';
import 'package:travel_youtube_app/screens/notification_settings_screen.dart';

const NotificationSettingsModel _defaults = NotificationSettingsModel(
  tripStartAlerts: true,
  routeCompleteAlerts: true,
  marketingAlerts: false,
  nightSilent: false,
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
  testWidgets('shows every toggle with its loaded value', (tester) async {
    final repository = FakeNotificationSettingsRepository()
      ..settingsToReturn = const NotificationSettingsModel(
        tripStartAlerts: true,
        routeCompleteAlerts: false,
        marketingAlerts: true,
        nightSilent: false,
      );
    await tester.pumpWidget(_wrap(NotificationSettingsProvider(repository: repository)));
    await tester.pumpAndSettle();

    final tripStartSwitch = tester.widget<SwitchListTile>(find.byKey(const Key('tripStartAlertsSwitch')));
    final routeCompleteSwitch = tester.widget<SwitchListTile>(find.byKey(const Key('routeCompleteAlertsSwitch')));
    final marketingSwitch = tester.widget<SwitchListTile>(find.byKey(const Key('marketingAlertsSwitch')));
    final nightSilentSwitch = tester.widget<SwitchListTile>(find.byKey(const Key('nightSilentSwitch')));

    expect(tripStartSwitch.value, isTrue);
    expect(routeCompleteSwitch.value, isFalse);
    expect(marketingSwitch.value, isTrue);
    expect(nightSilentSwitch.value, isFalse);
  });

  testWidgets('the master toggle reflects allEnabled and fans out when tapped', (tester) async {
    final repository = FakeNotificationSettingsRepository();
    await tester.pumpWidget(_wrap(NotificationSettingsProvider(repository: repository)));
    await tester.pumpAndSettle();

    final allSwitch = tester.widget<SwitchListTile>(find.byKey(const Key('allAlertsSwitch')));
    expect(allSwitch.value, isFalse); // marketingAlerts is false by default

    await tester.tap(find.byKey(const Key('allAlertsSwitch')));
    await tester.pumpAndSettle();

    expect(repository.lastUpdate?.tripStartAlerts, isTrue);
    expect(repository.lastUpdate?.routeCompleteAlerts, isTrue);
    expect(repository.lastUpdate?.marketingAlerts, isTrue);
    expect(repository.lastUpdate?.nightSilent, isFalse);
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
