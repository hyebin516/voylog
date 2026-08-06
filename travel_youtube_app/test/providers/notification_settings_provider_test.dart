import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/notification_settings_model.dart';
import 'package:travel_youtube_app/providers/notification_settings_provider.dart';
import 'package:travel_youtube_app/repositories/notification_settings_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

const NotificationSettingsModel _defaults = NotificationSettingsModel(
  tripAlerts: true,
  serviceAlerts: true,
  marketingAlerts: false,
);

class FakeNotificationSettingsRepository extends NotificationSettingsRepository {
  NotificationSettingsModel settingsToReturn = _defaults;
  ApiException? getError;
  ApiException? updateError;
  NotificationSettingsModel? lastUpdate;

  @override
  Future<NotificationSettingsModel> getSettings() async {
    if (getError != null) throw getError!;
    return settingsToReturn;
  }

  @override
  Future<NotificationSettingsModel> updateSettings(NotificationSettingsModel settings) async {
    lastUpdate = settings;
    if (updateError != null) throw updateError!;
    return settings;
  }
}

void main() {
  late FakeNotificationSettingsRepository repository;
  late NotificationSettingsProvider provider;

  setUp(() {
    repository = FakeNotificationSettingsRepository();
    provider = NotificationSettingsProvider(repository: repository);
  });

  test('starts idle with no settings loaded', () {
    expect(provider.state, ViewState.idle);
    expect(provider.settings, isNull);
  });

  group('loadSettings', () {
    test('transitions to success and stores the settings', () async {
      repository.settingsToReturn = _defaults;

      await provider.loadSettings();

      expect(provider.state, ViewState.success);
      expect(provider.settings?.tripAlerts, isTrue);
    });

    test('transitions to error on failure', () async {
      repository.getError = const ApiException(code: 'NETWORK_ERROR', message: 'boom');

      await provider.loadSettings();

      expect(provider.state, ViewState.error);
      expect(provider.settings, isNull);
    });
  });

  group('updateTripAlerts / updateServiceAlerts / updateMarketingAlerts', () {
    test('optimistically flips the toggle and persists it', () async {
      await provider.loadSettings();

      await provider.updateMarketingAlerts(true);

      expect(provider.settings?.marketingAlerts, isTrue);
      expect(repository.lastUpdate?.marketingAlerts, isTrue);
      expect(provider.isSaving, isFalse);
    });

    test('rolls back to the previous value when the update fails', () async {
      await provider.loadSettings();
      repository.updateError = const ApiException(code: 'INTERNAL_ERROR', message: 'boom');

      await provider.updateTripAlerts(false);

      expect(provider.settings?.tripAlerts, isTrue);
      expect(provider.errorMessage, isNotNull);
    });

    test('does nothing when settings have not loaded yet', () async {
      await provider.updateTripAlerts(false);

      expect(provider.settings, isNull);
      expect(repository.lastUpdate, isNull);
    });
  });
}
