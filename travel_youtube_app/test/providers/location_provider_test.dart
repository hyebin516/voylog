import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/location_result.dart';
import 'package:travel_youtube_app/providers/location_provider.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

import '../fakes/fake_location_repository.dart';

const LocationResult _location = LocationResult(latitude: 37.5, longitude: 127.0);

void main() {
  late FakeLocationRepository repository;
  late LocationProvider provider;

  setUp(() {
    repository = FakeLocationRepository();
    provider = LocationProvider(repository: repository);
  });

  tearDown(() {
    provider.stop();
    repository.closeStream();
  });

  test('starts idle with no location', () {
    expect(provider.state, ViewState.idle);
    expect(provider.currentLocation, isNull);
  });

  group('start', () {
    test('fetches and stores the current location when permission is granted', () async {
      repository.permissionToReturn = LocationPermissionState.granted;
      repository.locationToReturn = _location;

      await provider.start();

      expect(provider.state, ViewState.success);
      expect(provider.currentLocation, _location);
    });

    test('sets an error state without fetching location when permission is denied', () async {
      repository.permissionToReturn = LocationPermissionState.denied;

      await provider.start();

      expect(provider.state, ViewState.error);
      expect(provider.currentLocation, isNull);
      expect(provider.errorMessage, isNotNull);
    });

    test('sets an error state when the location service is disabled', () async {
      repository.permissionToReturn = LocationPermissionState.serviceDisabled;

      await provider.start();

      expect(provider.state, ViewState.error);
      expect(provider.errorMessage, contains('위치 서비스'));
    });

    test('sets an error state when permission is denied forever', () async {
      repository.permissionToReturn = LocationPermissionState.deniedForever;

      await provider.start();

      expect(provider.state, ViewState.error);
      expect(provider.errorMessage, contains('설정'));
    });

    test('sets an error state when the initial fetch fails despite granted permission', () async {
      repository.permissionToReturn = LocationPermissionState.granted;
      repository.locationToReturn = null;

      await provider.start();

      expect(provider.state, ViewState.error);
      expect(provider.currentLocation, isNull);
    });

    test('updates currentLocation as the position stream emits new fixes', () async {
      repository.permissionToReturn = LocationPermissionState.granted;
      repository.locationToReturn = _location;
      await provider.start();

      const moved = LocationResult(latitude: 37.51, longitude: 127.01);
      repository.emitPosition(moved);
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentLocation, moved);
    });
  });

  test('stop cancels the position stream subscription', () async {
    repository.permissionToReturn = LocationPermissionState.granted;
    repository.locationToReturn = _location;
    await provider.start();

    provider.stop();
    repository.emitPosition(const LocationResult(latitude: 1, longitude: 1));
    await Future<void>.delayed(Duration.zero);

    expect(provider.currentLocation, _location);
  });
}
