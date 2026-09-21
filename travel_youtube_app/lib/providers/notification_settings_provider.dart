import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/notification_settings_model.dart';
import '../repositories/notification_settings_repository.dart';
import '../utils/view_state.dart';

class NotificationSettingsProvider extends ChangeNotifier {
  final NotificationSettingsRepository _repository;

  NotificationSettingsProvider({NotificationSettingsRepository? repository})
      : _repository = repository ?? NotificationSettingsRepository();

  ViewState _state = ViewState.idle;
  NotificationSettingsModel? _settings;
  String? _errorMessage;
  bool _isSaving = false;

  ViewState get state => _state;
  NotificationSettingsModel? get settings => _settings;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;
  bool get isSaving => _isSaving;

  Future<void> loadSettings() async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _settings = await _repository.getSettings();
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  Future<void> updateTripStartAlerts(bool value) => _update(_settings?.copyWith(tripStartAlerts: value));

  Future<void> updateRouteCompleteAlerts(bool value) => _update(_settings?.copyWith(routeCompleteAlerts: value));

  Future<void> updateMarketingAlerts(bool value) => _update(_settings?.copyWith(marketingAlerts: value));

  Future<void> updateNightSilent(bool value) => _update(_settings?.copyWith(nightSilent: value));

  /// Design's "전체 알림" master toggle -- not backed by its own field
  /// (see [NotificationSettingsModel.allEnabled]), so turning it on/off
  /// just fans out to every underlying toggle at once.
  Future<void> updateAll(bool enabled) => _update(
        _settings?.copyWith(
          tripStartAlerts: enabled,
          routeCompleteAlerts: enabled,
          marketingAlerts: enabled,
          nightSilent: !enabled,
        ),
      );

  Future<void> _update(NotificationSettingsModel? next) async {
    if (next == null) return;
    final previous = _settings;
    _settings = next;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _settings = await _repository.updateSettings(next);
    } on ApiException catch (e) {
      _settings = previous;
      _errorMessage = e.friendlyMessage;
    }

    _isSaving = false;
    notifyListeners();
  }
}
