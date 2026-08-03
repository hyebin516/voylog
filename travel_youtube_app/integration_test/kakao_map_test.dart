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
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.byType(KakaoMapWidget), findsOneWidget);
    expect(reportedCenter, isNotNull);
  });
}
