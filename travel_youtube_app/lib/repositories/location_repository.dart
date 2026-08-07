import 'package:geolocator/geolocator.dart';

import '../models/location_result.dart';

/// Abstraction over "where is the user right now". Providers depend on
/// this, not on the `geolocator` plugin directly, so widget tests can
/// substitute a fake instead of touching real platform location services.
abstract class LocationRepository {
  const LocationRepository();

  Future<LocationPermissionState> checkAndRequestPermission();

  Future<LocationResult?> getCurrentLocation();

  /// Emits a new location only after the device has moved roughly
  /// [distanceFilterMeters] since the last emission.
  Stream<LocationResult> watchPosition({int distanceFilterMeters = 150});
}

/// Production implementation, backed by the native `geolocator` plugin.
class GeolocatorLocationRepository extends LocationRepository {
  const GeolocatorLocationRepository();

  @override
  Future<LocationPermissionState> checkAndRequestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionState.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) return LocationPermissionState.deniedForever;
    if (permission == LocationPermission.denied) return LocationPermissionState.denied;
    return LocationPermissionState.granted;
  }

  @override
  Future<LocationResult?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return LocationResult(latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<LocationResult> watchPosition({int distanceFilterMeters = 150}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilterMeters),
    ).map((position) => LocationResult(latitude: position.latitude, longitude: position.longitude));
  }
}
