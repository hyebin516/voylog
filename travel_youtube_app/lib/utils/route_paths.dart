import '../models/itinerary_model.dart';

/// The road geometry of a route, ready for [KakaoMapWidget.routeLegPaths] --
/// one entry per leg, each a list of [latitude, longitude] pairs.
///
/// A leg with no geometry (Kakao routing failed for that pair, or the route
/// was saved before paths were captured) becomes the straight segment between
/// its two stops. That keeps the line continuous and keeps the real roads on
/// every other leg: dropping the whole route back to straight lines because
/// one leg out of four failed would throw away the part that works.
///
/// Returns an empty list when no leg has geometry at all, which leaves the
/// map drawing its own straight line through the markers.
List<List<List<double>>> routeLegPathsOf(List<RoutePointModel> points) {
  final located = points.where((p) => p.latitude != null && p.longitude != null).toList();
  if (located.length < 2) return const [];
  if (located.skip(1).every((p) => p.legPath == null || p.legPath!.isEmpty)) return const [];

  final legs = <List<List<double>>>[];
  for (var i = 1; i < located.length; i++) {
    final path = located[i].legPath;
    legs.add(
      path != null && path.isNotEmpty
          ? path
          : [
              [located[i - 1].latitude!, located[i - 1].longitude!],
              [located[i].latitude!, located[i].longitude!],
            ],
    );
  }
  return legs;
}
