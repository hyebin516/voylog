import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// The native push SDK, behind an interface so tests never load it
/// (CLAUDE.md's rule for platform features: real implementation + fake).
abstract class PushMessagingService {
  /// Asks the user for notification permission. iOS always prompts;
  /// Android only from 13 (API 33) on, where it is a runtime permission.
  Future<bool> requestPermission();

  /// This device's FCM registration token, or null when push is
  /// unavailable (no Firebase config, permission denied, no Play services).
  Future<String?> getToken();

  /// FCM rotates tokens; the backend must be told when it happens or the
  /// device silently stops receiving notifications.
  Stream<String> get onTokenRefresh;
}

class FirebasePushMessagingService implements PushMessagingService {
  /// Every call to the native SDK is bounded. A device with broken or
  /// missing Play Services can leave `initializeApp`/`getToken` pending
  /// forever, and login awaits this -- notifications going quiet is a far
  /// smaller failure than a login that never finishes.
  static const Duration _callTimeout = Duration(seconds: 5);

  bool _initialised = false;

  /// Firebase needs its per-platform config file (google-services.json /
  /// GoogleService-Info.plist) to exist. It is git-ignored, so a checkout
  /// without one must still run -- just without notifications.
  Future<bool> _ensureInitialised() async {
    if (_initialised) return true;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp().timeout(_callTimeout);
      _initialised = true;
      return true;
    } catch (e) {
      debugPrint('Push notifications are off: Firebase is not configured on this build ($e)');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!await _ensureInitialised()) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission().timeout(_callTimeout);
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('Could not ask for notification permission: $e');
      return false;
    }
  }

  @override
  Future<String?> getToken() async {
    if (!await _ensureInitialised()) return null;
    try {
      return await FirebaseMessaging.instance.getToken().timeout(_callTimeout);
    } catch (e) {
      debugPrint('Could not read the FCM token: $e');
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh =>
      _initialised ? FirebaseMessaging.instance.onTokenRefresh : const Stream<String>.empty();
}
