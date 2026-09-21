import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../repositories/device_token_repository.dart';
import 'push_messaging_service.dart';

/// Keeps the backend's copy of this device's push token in step with the
/// signed-in user (FR-12): claimed on login, released on logout, and
/// re-sent whenever FCM rotates it.
///
/// Nothing here ever throws. Push notifications are an extra -- a user must
/// never fail to log in because Firebase was unreachable.
class PushRegistrationService {
  final PushMessagingService _messaging;
  final DeviceTokenRepository _repository;
  final String _platform;

  PushRegistrationService({
    PushMessagingService? messaging,
    DeviceTokenRepository? repository,
    String? platform,
  })  : _messaging = messaging ?? FirebasePushMessagingService(),
        _repository = repository ?? DeviceTokenRepository(),
        _platform = platform ?? (Platform.isIOS ? 'ios' : 'android');

  StreamSubscription<String>? _refreshSubscription;
  String? _registeredToken;

  String? get registeredToken => _registeredToken;

  Future<void> registerDevice() async {
    try {
      if (!await _messaging.requestPermission()) return;

      final token = await _messaging.getToken();
      if (token == null) return;
      await _repository.register(token, _platform);
      _registeredToken = token;

      _cancelRefreshSubscription();
      _refreshSubscription = _messaging.onTokenRefresh.listen((refreshed) async {
        try {
          await _repository.register(refreshed, _platform);
          _registeredToken = refreshed;
        } on ApiException catch (e) {
          debugPrint('Could not register the refreshed push token: ${e.friendlyMessage}');
        }
      });
    } on ApiException catch (e) {
      debugPrint('Could not register this device for push notifications: ${e.friendlyMessage}');
    }
  }

  /// Called before the JWT is cleared -- the request needs it, and a phone
  /// that signed out must stop receiving that account's notifications.
  Future<void> unregisterDevice() async {
    _cancelRefreshSubscription();

    final token = _registeredToken ?? await _messaging.getToken();
    _registeredToken = null;
    if (token == null) return;

    try {
      await _repository.unregister(token);
    } on ApiException catch (e) {
      debugPrint('Could not unregister this device: ${e.friendlyMessage}');
    }
  }

  void dispose() => _cancelRefreshSubscription();

  /// Deliberately not awaited. Cancelling stops delivery immediately, and
  /// no caller needs to know when the stream has finished tearing down --
  /// while awaiting it deadlocks under `testWidgets`, where a broadcast
  /// stream's cancel future only completes on the next pump.
  void _cancelRefreshSubscription() {
    unawaited(_refreshSubscription?.cancel() ?? Future<void>.value());
    _refreshSubscription = null;
  }
}
