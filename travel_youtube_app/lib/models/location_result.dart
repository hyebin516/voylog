class LocationResult {
  final double latitude;
  final double longitude;

  const LocationResult({required this.latitude, required this.longitude});

  @override
  bool operator ==(Object other) =>
      other is LocationResult && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Mirrors the meaningfully different outcomes of asking for location
/// access, so the UI can show a specific, actionable message for each
/// instead of a single generic "location unavailable" error.
enum LocationPermissionState { granted, denied, deniedForever, serviceDisabled }
