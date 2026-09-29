import 'package:flutter/material.dart';

import '../models/map_view_types.dart';
import '../widgets/kakao_map_widget.dart';

/// Abstraction over "build a map view". Screens depend on this, not on
/// any concrete map SDK — so map code stays out of UI code, and widget
/// tests can substitute a fake instead of loading a real native map.
abstract class MapRepository {
  const MapRepository();

  Widget buildMap({
    required double initialLatitude,
    required double initialLongitude,
    List<MapMarkerData> markers,
    bool drawRoutePolyline,
    List<List<List<double>>> routeLegPaths,
    ValueChanged<MapCenter>? onCenterChanged,
    ValueChanged<String>? onMarkerTap,
    // When set to a marker id from `markers`, pans the camera to that
    // marker -- lets a screen focus the map on whichever place the user
    // just selected (e.g. tapped a stop in a list).
    String? focusedMarkerId,
  });
}

/// Production implementation, backed by the native `kakao_map_plugin`.
class KakaoMapRepository extends MapRepository {
  const KakaoMapRepository();

  @override
  Widget buildMap({
    required double initialLatitude,
    required double initialLongitude,
    List<MapMarkerData> markers = const [],
    bool drawRoutePolyline = false,
    List<List<List<double>>> routeLegPaths = const [],
    ValueChanged<MapCenter>? onCenterChanged,
    ValueChanged<String>? onMarkerTap,
    String? focusedMarkerId,
  }) {
    return KakaoMapWidget(
      initialLatitude: initialLatitude,
      initialLongitude: initialLongitude,
      markers: markers,
      drawRoutePolyline: drawRoutePolyline,
      routeLegPaths: routeLegPaths,
      onCenterChanged: onCenterChanged,
      onMarkerTap: onMarkerTap,
      focusedMarkerId: focusedMarkerId,
    );
  }
}
