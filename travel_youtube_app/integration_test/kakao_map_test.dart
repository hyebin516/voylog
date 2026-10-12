// Integration test for the real native Kakao Maps view.
//
// Widget tests under test/ use FakeMapRepository/FakeMapWidget because the
// real map needs a platform WebView, which `flutter test` cannot render
// (and, on this project's Windows dev machine, currently crashes the
// `flutter_tester.exe` host entirely — see docs/TESTING_GUIDE.md). This
// test exercises the actual `kakao_map_plugin` native map and must run on
// a real Android emulator or device with network access. Copy
// .env.example to .env and fill in KAKAO_JAVASCRIPT_KEY first (see
// docs/KAKAO_SETUP.md), then:
//
//   flutter test integration_test/kakao_map_test.dart -d <device-id>
//
// It is not run as part of `flutter test` / `flutter analyze` CI checks.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:travel_youtube_app/models/map_view_types.dart';
import 'package:travel_youtube_app/repositories/map_repository.dart';
import 'package:travel_youtube_app/services/map_service.dart';
import 'package:travel_youtube_app/widgets/kakao_map_widget.dart';

/// Pumps until [condition] holds, or gives up after [timeout].
///
/// `pumpAndSettle(d)` is the wrong tool here: its first argument is the
/// interval between pumps, not a deadline, and it returns as soon as no
/// frame is scheduled. The Kakao SDK loads inside a WebView on its own
/// thread and schedules no Flutter frames while it does, so settling says
/// nothing about whether the map is up. This waits in real time instead.
Future<bool> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return true;
    await tester.pump(const Duration(milliseconds: 250));
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return condition();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MapRepository loads the real native map and reports the center coordinate', (tester) async {
    await dotenv.load(fileName: '.env', isOptional: true);
    MapService.initialize();

    MapCenter? reportedCenter;
    const mapRepository = KakaoMapRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: mapRepository.buildMap(
            initialLatitude: 37.5665,
            initialLongitude: 126.9780,
            markers: const [
              MapMarkerData(id: 'seoul-city-hall', title: '서울시청', latitude: 37.5665, longitude: 126.9780),
            ],
            onCenterChanged: (center) => reportedCenter = center,
          ),
        ),
      ),
    );

    // The Kakao Maps SDK loads asynchronously inside the embedded WebView.
    await pumpUntil(tester, () => reportedCenter != null);

    expect(find.byType(KakaoMapWidget), findsOneWidget);
    expect(reportedCenter, isNotNull);
  });

  testWidgets('the map still loads inside a sheet that animates in', (tester) async {
    // The regression this guards: the place map lives in a bottom sheet, and
    // creating its WebView while the sheet was still sliding up left the
    // panel blank. It only drew after closing and reopening the sheet, so
    // every user saw an empty map on the first tap.
    await dotenv.load(fileName: '.env', isOptional: true);
    MapService.initialize();

    MapCenter? reportedCenter;
    const mapRepository = KakaoMapRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: mapRepository.buildMap(
                    initialLatitude: 37.5665,
                    initialLongitude: 126.9780,
                    onCenterChanged: (center) => reportedCenter = center,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    // Long enough to cover the sheet animation plus one watchdog retry.
    await pumpUntil(tester, () => reportedCenter != null, timeout: const Duration(seconds: 45));

    // Reporting a center means the SDK came up: a blank WebView never calls
    // back at all.
    expect(reportedCenter, isNotNull);
  });
}
