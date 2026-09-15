/// What a marker stands for, which decides how its pin is drawn.
enum MapMarkerKind { place, start }

/// A place to render as a marker on a map.
class MapMarkerData {
  final String id;
  final String title;
  final double latitude;
  final double longitude;

  /// Short text drawn inside the pin, e.g. a stop's order ("1", "2"). When
  /// any marker on a map has one, the map draws numbered pins instead of
  /// Kakao's default identical ones -- with identical pins a user can't tell
  /// which pin is which stop.
  final String? label;
  final MapMarkerKind kind;

  const MapMarkerData({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.label,
    this.kind = MapMarkerKind.place,
  });
}

/// A map's current center coordinate, reported once camera movement settles.
class MapCenter {
  final double latitude;
  final double longitude;

  const MapCenter({required this.latitude, required this.longitude});
}
