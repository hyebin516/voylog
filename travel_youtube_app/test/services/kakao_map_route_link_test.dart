import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/services/kakao_map_launcher.dart';

const _launcher = KakaoMapLauncher();

RouteStop _stop(String name, double lat, double lng) =>
    RouteStop(name: name, latitude: lat, longitude: lng);

void main() {
  group('routeAppUri', () {
    test('carries both ends and Kakao\'s spelling of the mode', () {
      // Measured against Kakao Map 6.29.0: this exact shape opens walking
      // directions with the time, distance and calories filled in.
      expect(
        _launcher
            .routeAppUri(
              from: _stop('온양온천역', 36.7803, 127.0044),
              to: _stop('신정호', 36.7735, 126.9739),
              transportMode: 'walk',
            )
            .toString(),
        'kakaomap://route?sp=36.7803,127.0044&ep=36.7735,126.9739&by=FOOT',
      );
    });

    test('maps our mode names onto Kakao\'s', () {
      String by(String mode) => _launcher
          .routeAppUri(
            from: _stop('A', 1, 2),
            to: _stop('B', 3, 4),
            transportMode: mode,
          )
          .queryParameters['by']!;

      expect(by('walk'), 'FOOT');
      expect(by('transit'), 'PUBLICTRANSIT');
      expect(by('car'), 'CAR');
      // A leg with no recorded mode walks, like the label that shows it.
      expect(by('anything else'), 'FOOT');
    });
  });

  group('routeWebUri', () {
    test('puts every stop in the path, names encoded', () {
      expect(
        _launcher
            .routeWebUri(
              stops: [
                _stop('경복궁', 37.579617, 126.977041),
                _stop('창덕궁', 37.5794, 126.9911),
              ],
              transportMode: 'walk',
            )
            .toString(),
        'https://map.kakao.com/link/by/walk/'
        '${Uri.encodeComponent('경복궁')},37.579617,126.977041/'
        '${Uri.encodeComponent('창덕궁')},37.5794,126.9911',
      );
    });

    test('transit is spelled "traffic" on the web link, not "PUBLICTRANSIT"',
        () {
      // The two links disagree on the mode names; getting this wrong sends
      // a bus leg to Kakao as a walk.
      expect(
        _launcher
            .routeWebUri(
              stops: [_stop('A', 1, 2), _stop('B', 3, 4)],
              transportMode: 'transit',
            )
            .pathSegments,
        containsAllInOrder(['link', 'by', 'traffic']),
      );
    });
  });

  group('canOpenWholeRoute', () {
    test('allows a walk or drive up to Kakao\'s seven stops', () {
      for (final count in [2, 5, 7]) {
        expect(
          KakaoMapLauncher.canOpenWholeRoute(
            stopCount: count,
            transportMode: 'walk',
          ),
          isTrue,
          reason: '$count stops should fit',
        );
      }
      expect(
        KakaoMapLauncher.canOpenWholeRoute(
          stopCount: 7,
          transportMode: 'car',
        ),
        isTrue,
      );
    });

    test('refuses an eighth stop, which Kakao drops without saying so', () {
      // Verified on the device: eight stops returned the same route as
      // seven -- same distance, same time, last place missing.
      expect(
        KakaoMapLauncher.canOpenWholeRoute(
          stopCount: 8,
          transportMode: 'walk',
        ),
        isFalse,
      );
    });

    test('refuses transit and mixed routes, which take no waypoints at all',
        () {
      // Kakao keeps the first two stops of a transit link and discards the
      // rest, so a three-stop bus course would open as a two-stop one.
      expect(
        KakaoMapLauncher.canOpenWholeRoute(
          stopCount: 3,
          transportMode: 'transit',
        ),
        isFalse,
      );
      expect(
        KakaoMapLauncher.canOpenWholeRoute(
          stopCount: 3,
          transportMode: 'mixed',
        ),
        isFalse,
      );
    });

    test('needs two stops to be a route', () {
      expect(
        KakaoMapLauncher.canOpenWholeRoute(
          stopCount: 1,
          transportMode: 'walk',
        ),
        isFalse,
      );
    });
  });

  test('openRoute refuses a route Kakao would truncate', () async {
    // No launch is attempted, so this stays safe under `flutter test`.
    expect(
      await _launcher.openRoute(
        stops: List.generate(8, (i) => _stop('P$i', 37.0 + i, 127.0 + i)),
        transportMode: 'walk',
      ),
      isFalse,
    );
    expect(
      await _launcher.openRoute(
        stops: [_stop('only', 37, 127)],
        transportMode: 'walk',
      ),
      isFalse,
    );
  });
}
