import 'package:url_launcher/url_launcher.dart';

/// Opens a place, or a route, in the Kakao Map app -- or in Kakao Map on the
/// web when the app isn't installed. Kept behind a class (like
/// `PlaceShareService`) so screens can inject a fake and `flutter test`
/// never launches anything.
///
/// The route links come in two shapes, because the app scheme and the web
/// link don't accept the same thing (both measured on a real device,
/// 2026-09-29):
///
/// * `kakaomap://route` takes exactly two points. It has no waypoint
///   parameter at all -- `wp`, `via`, `wpp` and `viaPoints` are each
///   accepted and then ignored -- but it opens the installed app directly.
/// * `https://map.kakao.com/link/by/{mode}/...` does take waypoints, up to
///   five (seven stops). An eighth is dropped without a word: the route ends
///   one place early with the same distance and time as seven.
class KakaoMapLauncher {
  const KakaoMapLauncher();

  static const String _kakaoPlaceIdPrefix = 'kakao:';

  /// The Kakao Map app's URL scheme. A place found through Kakao search
  /// ("kakao:12345") opens its own place page; any other place is searched
  /// by name around its coordinates, which lands on the same Kakao place
  /// page when Kakao lists it and otherwise shows that spot.
  Uri appUri({
    required String placeId,
    required String name,
    required double latitude,
    required double longitude,
  }) {
    if (placeId.startsWith(_kakaoPlaceIdPrefix)) {
      return Uri.parse(
        'kakaomap://place?id=${placeId.substring(_kakaoPlaceIdPrefix.length)}',
      );
    }
    return Uri(
      scheme: 'kakaomap',
      host: 'search',
      queryParameters: {'q': name, 'p': '$latitude,$longitude'},
    );
  }

  /// Kakao Map on the web: the place page for a Kakao place, otherwise the
  /// same key-less pin link `PlaceShareService` shares.
  Uri webUri({
    required String placeId,
    required String name,
    required double latitude,
    required double longitude,
  }) {
    if (placeId.startsWith(_kakaoPlaceIdPrefix)) {
      return Uri.parse(
        'https://place.map.kakao.com/${placeId.substring(_kakaoPlaceIdPrefix.length)}',
      );
    }
    return Uri.parse(
      'https://map.kakao.com/link/map/${Uri.encodeComponent(name)},$latitude,$longitude',
    );
  }

  /// Returns false only when neither the app nor a browser could open it.
  Future<bool> open({
    required String placeId,
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    final app = appUri(
      placeId: placeId,
      name: name,
      latitude: latitude,
      longitude: longitude,
    );
    try {
      if (await launchUrl(app, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // Not installed -- fall through to the web page.
    }
    final web = webUri(
      placeId: placeId,
      name: name,
      latitude: latitude,
      longitude: longitude,
    );
    try {
      return await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Origin, destination and Kakao's five waypoints.
  static const int maxRouteStops = 7;

  /// Whether a whole route fits in one Kakao Map link.
  ///
  /// Public transport takes no waypoints whatsoever -- Kakao keeps the first
  /// two stops and drops the rest without saying so -- which is why a
  /// transit or mixed-mode route is only ever opened one leg at a time.
  static bool canOpenWholeRoute({
    required int stopCount,
    required String transportMode,
  }) =>
      stopCount >= 2 &&
      stopCount <= maxRouteStops &&
      transportMode != 'transit' &&
      transportMode != 'mixed';

  /// The two-stop app scheme. `by` is Kakao's spelling of the mode, not ours.
  Uri routeAppUri({
    required RouteStop from,
    required RouteStop to,
    required String transportMode,
  }) => Uri.parse(
    'kakaomap://route'
    '?sp=${from.latitude},${from.longitude}'
    '&ep=${to.latitude},${to.longitude}'
    '&by=${_appTravelMode(transportMode)}',
  );

  /// The web link, which is the only one of the two that keeps waypoints.
  Uri routeWebUri({
    required List<RouteStop> stops,
    required String transportMode,
  }) {
    final path = stops
        .map((s) => '${Uri.encodeComponent(s.name)},${s.latitude},${s.longitude}')
        .join('/');
    return Uri.parse(
      'https://map.kakao.com/link/by/${_webTravelMode(transportMode)}/$path',
    );
  }

  /// Opens [stops] as one route in Kakao Map. Returns false only when
  /// nothing could open it. Stops beyond what Kakao carries would arrive
  /// silently truncated, so they're refused here rather than shown wrong.
  Future<bool> openRoute({
    required List<RouteStop> stops,
    required String transportMode,
  }) async {
    if (stops.length < 2 || stops.length > maxRouteStops) return false;
    // A single leg can use the app scheme, which opens Kakao Map directly
    // with no "open with" chooser. Anything longer needs the web link.
    if (stops.length == 2) {
      try {
        if (await launchUrl(
          routeAppUri(
            from: stops.first,
            to: stops.last,
            transportMode: transportMode,
          ),
          mode: LaunchMode.externalApplication,
        )) {
          return true;
        }
      } catch (_) {
        // Not installed -- fall through to the web link.
      }
    }
    try {
      return await launchUrl(
        routeWebUri(stops: stops, transportMode: transportMode),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}

String _appTravelMode(String transportMode) {
  switch (transportMode) {
    case 'transit':
      return 'PUBLICTRANSIT';
    case 'car':
      return 'CAR';
    default:
      return 'FOOT';
  }
}

String _webTravelMode(String transportMode) {
  switch (transportMode) {
    case 'transit':
      return 'traffic';
    case 'car':
      return 'car';
    default:
      return 'walk';
  }
}

/// One stop on a route handed to Kakao Map -- only what its link carries.
class RouteStop {
  const RouteStop({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}
