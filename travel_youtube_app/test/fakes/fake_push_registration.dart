import 'package:travel_youtube_app/services/push_registration_service.dart';

import 'fake_device_token_repository.dart';
import 'fake_push_messaging_service.dart';

/// A [PushRegistrationService] that talks to no native SDK and no backend.
///
/// Any test that builds an [AuthProvider] needs one: logging in registers
/// this device for FR-12 notifications, and the real implementation would
/// reach for the Firebase platform channel.
PushRegistrationService fakePushRegistration() {
  return PushRegistrationService(
    messaging: FakePushMessagingService(),
    repository: FakeDeviceTokenRepository(),
    platform: 'android',
  );
}
