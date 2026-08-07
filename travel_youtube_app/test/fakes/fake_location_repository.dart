import 'dart:async';

import 'package:travel_youtube_app/models/location_result.dart';
import 'package:travel_youtube_app/repositories/location_repository.dart';

/// Test double for [LocationRepository]. Configure the fields before
/// pumping, and use [emitPosition] to simulate a stream update after the
/// initial fetch (e.g. the device having moved).
class FakeLocationRepository extends LocationRepository {
  LocationPermissionState permissionToReturn = LocationPermissionState.granted;
  LocationResult? locationToReturn;
  final StreamController<LocationResult> _positionController = StreamController<LocationResult>.broadcast();

  @override
  Future<LocationPermissionState> checkAndRequestPermission() async => permissionToReturn;

  @override
  Future<LocationResult?> getCurrentLocation() async => locationToReturn;

  @override
  Stream<LocationResult> watchPosition({int distanceFilterMeters = 150}) => _positionController.stream;

  void emitPosition(LocationResult location) => _positionController.add(location);

  void closeStream() => _positionController.close();
}
