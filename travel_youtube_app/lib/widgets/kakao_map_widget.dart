import 'package:flutter/material.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart' as kakao;

import '../models/map_view_types.dart';

/// Native Kakao Maps view for Android/iOS, built on `kakao_map_plugin`
/// (a real Flutter plugin backed by `webview_flutter`, not browser-only
/// `dart:js_interop`/`package:web`). Screens never construct this widget
/// directly — they depend on [MapRepository], which builds either this
/// (real) or `FakeMapWidget` (tests), so map code never leaks into UI code.
class KakaoMapWidget extends StatelessWidget {
  final double initialLatitude;
  final double initialLongitude;
  final List<MapMarkerData> markers;
  final bool drawRoutePolyline;
  final ValueChanged<MapCenter>? onCenterChanged;
  final ValueChanged<String>? onMarkerTap;

  const KakaoMapWidget({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.markers = const [],
    this.drawRoutePolyline = false,
    this.onCenterChanged,
    this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    return kakao.KakaoMap(
      center: kakao.LatLng(initialLatitude, initialLongitude),
      markers: markers
          .map(
            (m) => kakao.Marker(
              markerId: m.id,
              latLng: kakao.LatLng(m.latitude, m.longitude),
              infoWindowContent: m.title,
            ),
          )
          .toList(),
      polylines: drawRoutePolyline && markers.length >= 2
          ? [
              kakao.Polyline(
                polylineId: 'route',
                points: markers.map((m) => kakao.LatLng(m.latitude, m.longitude)).toList(),
                strokeColor: Theme.of(context).colorScheme.primary,
                strokeWidth: 4,
              ),
            ]
          : null,
      onCameraIdle: (latLng, _) {
        onCenterChanged?.call(MapCenter(latitude: latLng.latitude, longitude: latLng.longitude));
      },
      onMarkerTap: (markerId, latLng, zoomLevel) {
        onMarkerTap?.call(markerId);
      },
    );
  }
}
