import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart' as kakao;

import '../core/theme/app_theme.dart';
import '../models/map_view_types.dart';

/// Native Kakao Maps view for Android/iOS, built on `kakao_map_plugin`
/// (a real Flutter plugin backed by `webview_flutter`, not browser-only
/// `dart:js_interop`/`package:web`). Screens never construct this widget
/// directly — they depend on [MapRepository], which builds either this
/// (real) or `FakeMapWidget` (tests), so map code never leaks into UI code.
class KakaoMapWidget extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final List<MapMarkerData> markers;
  final bool drawRoutePolyline;

  /// The roads the route actually follows, one entry per leg, each a list of
  /// [latitude, longitude] pairs from the AI Worker. When empty the map falls
  /// back to straight lines between markers -- which is what routes saved
  /// before the geometry was captured, and legs where Kakao was unavailable,
  /// still have.
  final List<List<List<double>>> routeLegPaths;
  final ValueChanged<MapCenter>? onCenterChanged;
  final ValueChanged<String>? onMarkerTap;
  // When set to a marker id from `markers`, zooms the camera in on that
  // marker and draws its pin highlighted -- lets a screen show which place
  // the user just selected (e.g. tapped a stop in a list).
  final String? focusedMarkerId;

  const KakaoMapWidget({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.markers = const [],
    this.drawRoutePolyline = false,
    this.routeLegPaths = const [],
    this.onCenterChanged,
    this.onMarkerTap,
    this.focusedMarkerId,
  });

  @override
  State<KakaoMapWidget> createState() => _KakaoMapWidgetState();
}

// Kakao zoom level used when focusing a single place: close enough to see
// the street it's on. (Lower is closer; the plugin's default view is ~3-4.)
const int _focusedZoomLevel = 3;

// Visual-only nudge for pins that share a coordinate (e.g. two listings in
// one building), ~13m east per duplicate. Without it they stack exactly and
// the lower one is invisible.
const double _duplicatePinOffsetDeg = 0.00015;

// How long to wait for the map to report itself created before assuming the
// WebView came up blank. A cold WebView on an older phone takes a couple of
// seconds, so this is generous enough not to throw away a slow but working
// load.
const Duration _mapLoadTimeout = Duration(seconds: 6);

// A blank map recovers on the first retry in practice. The cap is here so a
// genuinely broken setup (no network, bad app key) settles on an empty panel
// instead of rebuilding a WebView forever.
const int _maxMapLoadAttempts = 3;

// Covers a bottom sheet's slide-in (Flutter's is 250ms) with a little room,
// and is the backstop for a route that never reports completing.
const Duration _revealFallbackDelay = Duration(milliseconds: 400);

class _KakaoMapWidgetState extends State<KakaoMapWidget> {
  kakao.KakaoMapController? _controller;

  // Overlay id -> marker id, for turning a pin tap back into a marker id.
  final Map<String, String> _markerIdByOverlayId = {};

  /// False until the route that holds this map has finished animating in.
  ///
  /// The map is a WebView, and creating one while its surface is still being
  /// composited -- which is exactly what a bottom sheet sliding up does --
  /// leaves it blank: the place map came up empty on first open and only
  /// drew after closing and reopening the sheet.
  bool _visible = false;
  Animation<double>? _routeAnimation;
  Timer? _revealFallback;

  /// Bumped to give [kakao.KakaoMap] a new key, which throws the blank
  /// WebView away and builds a fresh one.
  int _attempt = 0;
  bool _mapCreated = false;
  Timer? _watchdog;

  bool get _useNumberedPins => widget.markers.any((m) => m.label != null);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_visible) return;

    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _visible = true;
      _startWatchdog();
      return;
    }

    _routeAnimation = animation..addStatusListener(_onRouteAnimationStatus);

    // Not every route reports a completion. One that was never animated --
    // an app's first route, or a push with no transition -- sits at rest
    // and fires no status change, and waiting on it meant the map was never
    // built at all. Whatever happens, reveal shortly after; the point is
    // only to miss the frames where a sheet is still sliding.
    _revealFallback = Timer(_revealFallbackDelay, _reveal);
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _reveal();
  }

  void _reveal() {
    if (_visible || !mounted) return;
    _revealFallback?.cancel();
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    setState(() => _visible = true);
    _startWatchdog();
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    if (_mapCreated || _attempt + 1 >= _maxMapLoadAttempts) return;

    _watchdog = Timer(_mapLoadTimeout, () {
      if (!mounted || _mapCreated) return;
      setState(() {
        _attempt++;
        // The old WebView is going away, and its controller with it.
        _controller = null;
        _markerIdByOverlayId.clear();
      });
      _startWatchdog();
    });
  }

  @override
  void dispose() {
    _revealFallback?.cancel();
    _watchdog?.cancel();
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    super.dispose();
  }

  @override
  void didUpdateWidget(KakaoMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedMarkerId != null &&
        widget.focusedMarkerId != oldWidget.focusedMarkerId) {
      _focusMarker();
    }
  }

  void _focusMarker() {
    final controller = _controller;
    final id = widget.focusedMarkerId;
    if (controller == null || id == null) return;

    final positions = _displayPositions();
    for (final marker in widget.markers) {
      if (marker.id == id) {
        // Panning alone kept the old zoom, where a whole course fits on
        // screen and the selected pin barely stood out.
        controller.setLevel(_focusedZoomLevel);
        controller.panTo(positions[marker.id]!);
        return;
      }
    }
  }

  void _showAllMarkers() {
    final controller = _controller;
    if (controller == null || widget.markers.length < 2) return;
    controller.fitBounds(
      widget.markers.map((m) => kakao.LatLng(m.latitude, m.longitude)).toList(),
    );
  }

  Map<String, kakao.LatLng> _displayPositions() {
    final seen = <String, int>{};
    final positions = <String, kakao.LatLng>{};
    for (final m in widget.markers) {
      final key =
          '${m.latitude.toStringAsFixed(5)},${m.longitude.toStringAsFixed(5)}';
      final duplicates = seen[key] ?? 0;
      seen[key] = duplicates + 1;
      positions[m.id] = kakao.LatLng(
        m.latitude,
        m.longitude + duplicates * _duplicatePinOffsetDeg,
      );
    }
    return positions;
  }

  List<kakao.CustomOverlay> _numberedPins() {
    final positions = _displayPositions();
    _markerIdByOverlayId.clear();
    return widget.markers.map((m) {
      final selected = m.id == widget.focusedMarkerId;
      final position = positions[m.id]!;
      final content = _pinHtml(m, selected);
      final overlayId = _overlayId(m.id, content, position);
      _markerIdByOverlayId[overlayId] = m.id;
      return kakao.CustomOverlay(
        customOverlayId: overlayId,
        latLng: position,
        content: content,
        xAnchor: 0.5,
        yAnchor: 1,
        zIndex: selected ? 10 : (m.kind == MapMarkerKind.start ? 5 : 1),
      );
    }).toList();
  }

  List<kakao.Marker> _plainMarkers() => widget.markers
      .map(
        (m) => kakao.Marker(
          markerId: m.id,
          latLng: kakao.LatLng(m.latitude, m.longitude),
          infoWindowContent: m.title,
        ),
      )
      .toList();

  List<kakao.Polyline>? _routePolylines(BuildContext context) {
    if (!widget.drawRoutePolyline || widget.markers.length < 2) return null;

    final points = widget.routeLegPaths.isEmpty
        // No geometry: join the stops directly, as the map always used to.
        ? widget.markers.map((m) => kakao.LatLng(m.latitude, m.longitude)).toList()
        : [
            for (final leg in widget.routeLegPaths)
              for (final point in leg) kakao.LatLng(point[0], point[1]),
          ];

    return [
      kakao.Polyline(
        polylineId: 'route',
        points: points,
        strokeColor: Theme.of(context).colorScheme.primary,
        strokeWidth: 4,
      ),
    ];
  }

  /// kakao_map_plugin only draws markers, overlays and polylines when the
  /// widget is *updated* (its didUpdateWidget) -- never when the map is
  /// first created. So a map opened with pins showed none until something
  /// rebuilt it, e.g. the first tap on a stop, which then drew that stop as
  /// the selected one. Drawing them here makes them present from the start.
  void _drawInitialShapes(kakao.KakaoMapController controller) {
    controller.addPolyline(polylines: _routePolylines(context));
    if (_useNumberedPins) {
      controller.addCustomOverlay(customOverlays: _numberedPins());
    } else {
      controller.addMarker(markers: _plainMarkers());
    }
  }

  @override
  Widget build(BuildContext context) {
    final numbered = _useNumberedPins;

    // Holding the map's place until the sheet or page has settled. Tinted
    // rather than white so it reads as "the map is coming", not as the blank
    // panel this exists to prevent.
    if (!_visible) {
      return const ColoredBox(color: AppColors.surfaceTint1);
    }

    return kakao.KakaoMap(
      // Changing this key is how the watchdog replaces a WebView that never
      // reported itself created.
      key: ValueKey(_attempt),
      center: kakao.LatLng(widget.initialLatitude, widget.initialLongitude),
      // The plugin claims no gestures by default, so a drag started on the
      // map is otherwise won by an ancestor Scrollable (e.g. this widget
      // embedded in a SingleChildScrollView) instead of panning the map.
      // Eagerly claiming gestures here makes the map itself draggable, the
      // same way any other embedded interactive map behaves.
      gestureRecognizers: {Factory(() => EagerGestureRecognizer())},
      markers: numbered ? const [] : _plainMarkers(),
      customOverlays: numbered ? _numberedPins() : null,
      polylines: _routePolylines(context),
      onMapCreated: (controller) {
        _mapCreated = true;
        _watchdog?.cancel();
        _controller = controller;
        _drawInitialShapes(controller);
        if (widget.focusedMarkerId != null) {
          _focusMarker();
        } else {
          _showAllMarkers();
        }
      },
      onCameraIdle: (latLng, _) {
        widget.onCenterChanged?.call(
          MapCenter(latitude: latLng.latitude, longitude: latLng.longitude),
        );
      },
      onMarkerTap: (markerId, latLng, zoomLevel) {
        widget.onMarkerTap?.call(markerId);
      },
      onCustomOverlayTap: (overlayId, latLng) {
        final markerId = _markerIdByOverlayId[overlayId];
        if (markerId != null) widget.onMarkerTap?.call(markerId);
      },
    );
  }
}

/// A pin's overlay id changes whenever what the pin shows changes.
///
/// kakao_map_plugin can't update an existing overlay: on every rebuild it
/// keeps overlays whose ids are still listed (its `clearCustomOverlay` only
/// removes ids NOT passed in) and `addCustomOverlay` returns early for an id
/// that already exists. With stable ids, the first-drawn pins stayed forever
/// -- the map panned to the tapped stop but the highlighted pin and its name
/// bubble stuck on whichever was drawn first. Deriving the id from the
/// content makes a changed pin a new id, so the stale one is removed and the
/// new one drawn, while unchanged pins are left alone.
String _overlayId(String markerId, String content, kakao.LatLng position) {
  final signature = Object.hash(content, position.latitude, position.longitude);
  // Only [A-Za-z0-9_] -- the id is also used as a DOM id and inside JS
  // string literals by the plugin, where a quote in a place name would break.
  final safeMarkerId = markerId.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  return 'pin_${safeMarkerId}_${signature.toUnsigned(32).toRadixString(16)}';
}

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String _escapeHtml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// A round numbered pin, or a pill for the start point. The selected pin is
/// larger, drawn in the accent color, and carries the place's name so the
/// user can see exactly which spot they picked.
String _pinHtml(MapMarkerData marker, bool selected) {
  final isStart = marker.kind == MapMarkerKind.start;
  final size = selected ? 40 : 30;
  final background = selected
      ? _hex(AppColors.danger)
      : (isStart ? _hex(AppColors.ink) : _hex(AppColors.primary));
  final label = _escapeHtml(marker.label ?? '');
  final fontSize = selected ? 15 : 13;

  final badge = isStart
      ? '<div style="height:${size}px;padding:0 10px;border-radius:${size}px;'
            'background:$background;border:2px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,.35);'
            'color:#fff;font:700 ${fontSize}px sans-serif;display:flex;align-items:center;'
            'justify-content:center;white-space:nowrap;">$label</div>'
      : '<div style="width:${size}px;height:${size}px;border-radius:50%;'
            'background:$background;border:2px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,.35);'
            'color:#fff;font:700 ${fontSize}px sans-serif;display:flex;align-items:center;'
            'justify-content:center;">$label</div>';

  final nameBubble = selected
      ? '<div style="margin-bottom:6px;padding:5px 10px;border-radius:12px;background:#fff;'
            'box-shadow:0 2px 8px rgba(0,0,0,.25);color:${_hex(AppColors.ink)};'
            'font:700 12px sans-serif;white-space:nowrap;">${_escapeHtml(marker.title)}</div>'
      : '';

  return '<div style="display:flex;flex-direction:column;align-items:center;">'
      '$nameBubble$badge</div>';
}
