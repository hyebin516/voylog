import 'package:flutter/material.dart';
import 'package:travel_youtube_app/models/map_view_types.dart';
import 'package:travel_youtube_app/repositories/map_repository.dart';

/// Stand-in for the real native Kakao map in widget tests. Renders plain
/// Flutter widgets instead of a platform WebView, and exposes a button to
/// simulate the user dragging the map to a new center.
class FakeMapWidget extends StatelessWidget {
  final double initialLatitude;
  final double initialLongitude;
  final List<MapMarkerData> markers;
  final ValueChanged<MapCenter>? onCenterChanged;
  final ValueChanged<String>? onMarkerTap;

  const FakeMapWidget({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.markers = const [],
    this.onCenterChanged,
    this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('fake-map center=$initialLatitude,$initialLongitude'),
        for (final marker in markers)
          TextButton(
            onPressed: onMarkerTap == null ? null : () => onMarkerTap!(marker.id),
            child: Text('marker:${marker.title}'),
          ),
        if (onCenterChanged != null)
          ElevatedButton(
            onPressed: () => onCenterChanged!(
              MapCenter(latitude: initialLatitude + 0.001, longitude: initialLongitude + 0.001),
            ),
            child: const Text('simulate-drag'),
          ),
      ],
    );
  }
}

/// Test double for [MapRepository]. Use in `pumpWidget` for any screen
/// that would otherwise render a real (and untestable) native map.
class FakeMapRepository extends MapRepository {
  const FakeMapRepository();

  @override
  Widget buildMap({
    required double initialLatitude,
    required double initialLongitude,
    List<MapMarkerData> markers = const [],
    bool drawRoutePolyline = false,
    ValueChanged<MapCenter>? onCenterChanged,
    ValueChanged<String>? onMarkerTap,
  }) {
    return FakeMapWidget(
      initialLatitude: initialLatitude,
      initialLongitude: initialLongitude,
      markers: markers,
      onCenterChanged: onCenterChanged,
      onMarkerTap: onMarkerTap,
    );
  }
}
