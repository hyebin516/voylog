/// A place to render as a marker on a map.
class MapMarkerData {
  final String id;
  final String title;
  final double latitude;
  final double longitude;

  const MapMarkerData({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
  });
}

/// A map's current center coordinate, reported once camera movement settles.
class MapCenter {
  final double latitude;
  final double longitude;

  const MapCenter({required this.latitude, required this.longitude});
}
