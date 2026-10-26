import 'dart:math' as math;

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

  // 고른 핀으로 배율을 당긴 적이 있는지. 두 번째부터는 이동만 한다.
  bool _hasZoomedToFocus = false;

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
        // 배율은 처음 고를 때 한 번만 바꾼다. 전체 코스가 들어오는 배율에서는
        // 고른 핀이 묻히므로 한 번은 당겨줘야 하지만, 누를 때마다 당기면
        // 사용자가 직접 맞춰 둔 화면을 매번 빼앗는다. 특히 지도를 끌고 있는
        // 중에 배율이 바뀌면 손가락과 화면이 따로 노는 것처럼 느껴진다.
        if (!_hasZoomedToFocus) {
          controller.setLevel(_focusedZoomLevel);
          _hasZoomedToFocus = true;
        }
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

  List<kakao.LatLng> _routePoints() {
    if (!widget.drawRoutePolyline || widget.markers.length < 2) return const [];
    return widget.routeLegPaths.isEmpty
        // No geometry: join the stops directly, as the map always used to.
        ? widget.markers.map((m) => kakao.LatLng(m.latitude, m.longitude)).toList()
        : [
            for (final leg in widget.routeLegPaths)
              for (final point in leg) kakao.LatLng(point[0], point[1]),
          ];
  }

  List<kakao.Polyline>? _routePolylines(BuildContext context) {
    final points = _routePoints();
    if (points.length < 2) return null;

    // 카카오·네이버 길찾기처럼 흰 테두리를 깐 두 겹 선으로 그린다. 한 겹
    // 짜리 선은 비슷한 색의 도로나 하천 위에 올라가면 경계가 사라져서
    // 어디까지가 경로인지 읽히지 않는다.
    return [
      // 카카오 지도 SDK는 폴리라인을 타일 위에 그리므로 선 아래로 보낼 수
      // 없다. 지도의 가게 이름을 덜 덮도록 두 가지를 한다 -- 굵기를 줄이고,
      // 테두리를 반투명 흰색으로 둔다(불투명하면 테두리에 닿은 글자가
      // 통째로 지워진다).
      kakao.Polyline(
        polylineId: 'route-casing',
        points: points,
        strokeColor: Colors.white,
        strokeWidth: 12,
        strokeOpacity: 0.75,
        zIndex: 1,
      ),
      kakao.Polyline(
        polylineId: 'route',
        points: points,
        strokeColor: Theme.of(context).colorScheme.primary,
        strokeWidth: 8,
        strokeOpacity: 0.92,
        zIndex: 2,
      ),
    ];
  }

  /// 경로 위에 진행 방향을 알려주는 작은 화살표. 카카오·네이버 길찾기와
  /// 같은 장치다 -- 선만 있으면 어느 쪽으로 가는 경로인지 알 수 없고,
  /// 번호 핀은 멀리 떨어져 있어 중간 구간에서는 도움이 되지 않는다.
  ///
  /// 간격을 미터로 고정하지 않고 전체 길이를 n등분한다. 지도는 경로 전체가
  /// 보이도록 맞춰지므로, 코스가 길든 짧든 화면에 비슷한 간격으로 찍힌다.
  List<kakao.CustomOverlay> _directionArrows() {
    final points = _routePoints();
    if (points.length < 2) return const [];

    // 각 구간 길이(평면 근사)와 누적 길이
    final segment = <double>[];
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final length = _planarDistance(points[i], points[i + 1]);
      segment.add(length);
      total += length;
    }
    if (total <= 0) return const [];

    // 개수를 고정하면 짧고 구불구불한 코스에서는 화살표가 다닥다닥 붙고,
    // 길게 뻗은 코스에서는 듬성듬성해진다. 지도는 경로 전체가 들어오도록
    // 맞춰지므로, 경로 길이를 경계상자 대각선으로 나눈 값이 "화면에서 이
    // 선이 얼마나 길어 보이는지"에 비례한다. 곧게 뻗은 경로면 1에 가깝고
    // 꼬불꼬불할수록 커진다.
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    final diagonal = _planarDistance(
      kakao.LatLng(minLat, minLng),
      kakao.LatLng(maxLat, maxLng),
    );
    final screenRatio = diagonal <= 0 ? 1.0 : total / diagonal;
    final count = (7 * screenRatio).round().clamp(3, 18);
    final overlays = <kakao.CustomOverlay>[];

    for (var n = 1; n <= count; n++) {
      // 양 끝은 핀에 가려지므로 구간 중앙 쪽에만 찍는다.
      final target = total * n / (count + 1);
      var walked = 0.0;
      for (var i = 0; i < segment.length; i++) {
        if (walked + segment[i] < target) {
          walked += segment[i];
          continue;
        }
        final t = segment[i] == 0 ? 0.0 : (target - walked) / segment[i];
        final a = points[i];
        final b = points[i + 1];
        final at = kakao.LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
        overlays.add(kakao.CustomOverlay(
          customOverlayId: 'arrow-$n',
          latLng: at,
          content: _arrowHtml(_bearing(a, b)),
          xAnchor: 0.5,
          yAnchor: 0.5,
          zIndex: 3,
        ));
        break;
      }
    }
    return overlays;
  }

  /// kakao_map_plugin only draws markers, overlays and polylines when the
  /// widget is *updated* (its didUpdateWidget) -- never when the map is
  /// first created. So a map opened with pins showed none until something
  /// rebuilt it, e.g. the first tap on a stop, which then drew that stop as
  /// the selected one. Drawing them here makes them present from the start.
  void _drawInitialShapes(kakao.KakaoMapController controller) {
    controller.addPolyline(polylines: _routePolylines(context));
    if (_useNumberedPins) {
      controller.addCustomOverlay(customOverlays: [..._directionArrows(), ..._numberedPins()]);
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
      customOverlays: numbered ? [..._directionArrows(), ..._numberedPins()] : null,
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
/// 두 점 사이 거리(미터 아님, 비율만 맞는 평면 근사). 화살표를 균등하게
/// 나누는 데만 쓰므로 정확한 미터값이 필요 없다.
double _planarDistance(kakao.LatLng a, kakao.LatLng b) {
  final dy = b.latitude - a.latitude;
  final dx = (b.longitude - a.longitude) * math.cos(a.latitude * math.pi / 180);
  return math.sqrt(dx * dx + dy * dy);
}

/// 북쪽을 0도로 한 시계방향 각도. CSS rotate와 같은 방향이라 그대로 쓴다.
double _bearing(kakao.LatLng a, kakao.LatLng b) {
  final dy = b.latitude - a.latitude;
  final dx = (b.longitude - a.longitude) * math.cos(a.latitude * math.pi / 180);
  return math.atan2(dx, dy) * 180 / math.pi;
}

/// 선 위에 얹는 흰 화살표. 테두리를 어둡게 줘서 틸색 선 위에서도 모양이
/// 뭉개지지 않는다.
String _arrowHtml(double bearingDegrees) {
  final angle = bearingDegrees.toStringAsFixed(1);

  // 바깥 상자를 0x0으로 두고 그림만 자기 크기의 절반만큼 끌어올린다.
  // 카카오 CustomOverlay는 content의 크기를 재서 앵커(0.5, 0.5)를 적용하는데,
  // SVG가 아직 배치되기 전에 재면 0으로 읽혀 화살표가 선 중앙이 아니라
  // 한쪽으로 치우쳐 붙는다. 0x0이면 잴 것이 없으므로 그 타이밍에 영향받지
  // 않고, translate(-50%,-50%)가 항상 정확히 가운데로 맞춘다.
  return '<div style="position:relative;width:0;height:0;">'
      '<svg width="7" height="7" viewBox="0 0 14 14" '
      'style="position:absolute;left:0;top:0;display:block;'
      'transform:translate(-50%,-50%) rotate(${angle}deg);">'
      '<path d="M7 1.8L12 11.4a.7.7 0 0 1-.95.95L7 10.4l-4.05 1.95a.7.7 0 0 1-.95-.95z" '
      'fill="#fff" fill-opacity="0.8"/>'
      '</svg></div>';
}

String _pinHtml(MapMarkerData marker, bool selected) {
  final isStart = marker.kind == MapMarkerKind.start;
  final label = _escapeHtml(marker.label ?? '');

  // 숙소/출발점은 이름이 들어가야 해서 알약 모양, 나머지 방문지는 핀 모양이다.
  // 핀의 뾰족한 끝이 실제 좌표를 가리킨다(yAnchor: 1).
  final badge = isStart ? _startPillHtml(label, selected) : _placePinHtml(label, selected);

  final nameBubble = selected
      ? '<div style="margin-bottom:6px;padding:5px 10px;border-radius:12px;background:#fff;'
            'box-shadow:0 2px 8px rgba(0,0,0,.25);color:${_hex(AppColors.ink)};'
            'font:700 12px sans-serif;white-space:nowrap;">${_escapeHtml(marker.title)}</div>'
      : '';

  return '<div style="display:flex;flex-direction:column;align-items:center;">'
      '$nameBubble$badge</div>';
}

/// 카카오맵 핀을 따른 모양 -- 둥근 머리 안에 흰 원, 아래로 뾰족한 끝.
/// 원이 아니라 핀이어야 어디를 가리키는지가 분명하다(원은 중심이 좌표인지
/// 아래쪽이 좌표인지 알 수 없다). 바깥 흰 테두리는 건물과 도로가 빽빽한
/// 지도 위에서 핀이 묻히지 않게 한다.
String _placePinHtml(String label, bool selected) {
  final width = selected ? 40 : 32;
  final height = (width * 1.4).round();
  final fill = _hex(selected ? AppColors.primaryStrong : AppColors.primary);
  final fontSize = selected ? 13 : 12;

  // viewBox 32x45 기준: 머리 중심 (16, 16), 끝점 (16, 44).
  const path = 'M16 2C8.3 2 2 8.3 2 16c0 9.5 11.5 22.6 13.2 24.5.4.5 1.2.5 1.6 0'
      'C18.5 38.6 30 25.5 30 16 30 8.3 23.7 2 16 2z';

  return '<svg width="${width}px" height="${height}px" viewBox="0 0 32 45" '
      'style="display:block;filter:drop-shadow(0 2px 4px rgba(0,0,0,.3));">'
      '<path d="$path" fill="$fill" stroke="#fff" stroke-width="2"/>'
      '<circle cx="16" cy="16" r="8.5" fill="#fff"/>'
      '<text x="16" y="16" text-anchor="middle" dominant-baseline="central" '
      'fill="$fill" font-family="sans-serif" font-weight="700" '
      'font-size="$fontSize">$label</text>'
      '</svg>';
}

/// 출발·도착 지점은 숙소 이름처럼 긴 글자가 들어가므로 핀 대신 알약 모양이다.
String _startPillHtml(String label, bool selected) {
  final height = selected ? 36 : 30;
  final fontSize = selected ? 14 : 13;
  final background = _hex(AppColors.ink);

  return '<div style="height:${height}px;padding:0 10px;border-radius:${height}px;'
      'background:$background;border:2px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,.35);'
      'color:#fff;font:700 ${fontSize}px sans-serif;display:flex;align-items:center;'
      'justify-content:center;white-space:nowrap;">$label</div>';
}
