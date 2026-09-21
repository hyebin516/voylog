import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/services/push_registration_service.dart';

import '../fakes/fake_device_token_repository.dart';
import '../fakes/fake_push_messaging_service.dart';

void main() {
  late FakePushMessagingService messaging;
  late FakeDeviceTokenRepository repository;
  late PushRegistrationService service;

  setUp(() {
    messaging = FakePushMessagingService();
    repository = FakeDeviceTokenRepository();
    service = PushRegistrationService(messaging: messaging, repository: repository, platform: 'android');
  });

  tearDown(() async {
    service.dispose();
    await messaging.refreshController.close();
  });

  group('registerDevice', () {
    test('sends this device\'s token and platform to the backend', () async {
      await service.registerDevice();

      expect(repository.registered, [(token: 'fcm-token', platform: 'android')]);
      expect(service.registeredToken, 'fcm-token');
    });

    test('sends nothing when the user refuses notifications', () async {
      messaging.permissionGranted = false;

      await service.registerDevice();

      expect(repository.registered, isEmpty);
      expect(messaging.tokenReads, 0);
    });

    test('sends nothing when push is unavailable on this build', () async {
      messaging.token = null;

      await service.registerDevice();

      expect(repository.registered, isEmpty);
    });

    test('re-sends a token FCM rotates, so the device keeps receiving', () async {
      await service.registerDevice();

      messaging.refreshController.add('rotated-token');
      await Future<void>.delayed(Duration.zero);

      expect(repository.registered.last, (token: 'rotated-token', platform: 'android'));
      expect(service.registeredToken, 'rotated-token');
    });

    test('swallows a backend failure -- login must not fail over a notification', () async {
      repository.registerError = const ApiException(code: 'SERVER_ERROR', message: 'boom');

      await expectLater(service.registerDevice(), completes);
      expect(service.registeredToken, isNull);
    });
  });

  group('unregisterDevice', () {
    test('releases the token this device registered', () async {
      await service.registerDevice();

      await service.unregisterDevice();

      expect(repository.unregistered, ['fcm-token']);
      expect(service.registeredToken, isNull);
    });

    test('falls back to asking the SDK when nothing was registered this run', () async {
      await service.unregisterDevice();

      expect(repository.unregistered, ['fcm-token']);
    });

    test('stops following token refreshes once the device is released', () async {
      await service.registerDevice();
      await service.unregisterDevice();

      messaging.refreshController.add('rotated-token');
      await Future<void>.delayed(Duration.zero);

      expect(repository.registered, hasLength(1));
    });

    test('swallows a backend failure -- logout must still happen', () async {
      await service.registerDevice();
      repository.unregisterError = const ApiException(code: 'SERVER_ERROR', message: 'boom');

      await expectLater(service.unregisterDevice(), completes);
    });
  });
}
