import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';
import 'package:travel_youtube_app/models/itinerary_model.dart';
import 'package:travel_youtube_app/models/saved_walking_course_model.dart';
import 'package:travel_youtube_app/providers/bookmark_provider.dart';
import 'package:travel_youtube_app/providers/saved_walking_course_provider.dart';
import 'package:travel_youtube_app/repositories/bookmark_repository.dart';
import 'package:travel_youtube_app/repositories/saved_walking_course_repository.dart';
import 'package:travel_youtube_app/screens/saved_walking_course_detail_screen.dart';
import 'package:travel_youtube_app/services/kakao_map_launcher.dart';

import 'fakes/fake_map_widget.dart';

final SavedWalkingCourseModel _course = SavedWalkingCourseModel(
  savedCourseId: 'sc1',
  region: '제주',
  routeType: 'roundTrip',
  transportMode: 'walk',
  totalDistanceM: 2119,
  totalDurationSec: 1897,
  routeData: [
    RoutePointModel(order: 0, type: 'hotel', hotelId: 'region-center', placeId: null, name: '제주 중심', latitude: 33.5, longitude: 126.5),
    RoutePointModel(order: 1, type: 'place', hotelId: null, placeId: 'p1', name: '흑돼지집', latitude: 33.51, longitude: 126.51),
  ],
  createdAt: DateTime(2026, 8, 28),
);

class FakeSavedWalkingCourseRepository extends SavedWalkingCourseRepository {
  ApiException? deleteError;
  final List<String> deleteCalls = [];

  @override
  Future<void> delete(String savedCourseId) async {
    deleteCalls.add(savedCourseId);
    if (deleteError != null) throw deleteError!;
  }
}

class FakeBookmarkRepository extends BookmarkRepository {
  @override
  Future<List<BookmarkModel>> listBookmarks() async => [];
}

class FakeKakaoMapLauncher extends KakaoMapLauncher {
  final List<Map<String, Object>> opened = [];

  @override
  Future<bool> open({
    required String placeId,
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    opened.add({'placeId': placeId, 'name': name, 'latitude': latitude});
    return true;
  }
}

/// A saved bookmark-folder route: a bus leg, then a walk.
final SavedWalkingCourseModel _folderCourse = SavedWalkingCourseModel(
  savedCourseId: 'sc2',
  region: 'ㄹ',
  routeType: 'placeToPlace',
  transportMode: 'mixed',
  totalDistanceM: 4657,
  totalDurationSec: 1736,
  routeData: const [
    RoutePointModel(order: 0, type: 'place', hotelId: null, placeId: 'a', name: '카페 산시', latitude: 36.7735, longitude: 126.9739),
    RoutePointModel(order: 1, type: 'place', hotelId: null, placeId: 'b', name: '파인데이즈', latitude: 36.7798, longitude: 127.004, legDistanceM: 4222, legDurationSec: 1289, legTransportMode: 'transit', legGuidance: '614번 · 점등이 → 온양온천역 입구'),
    RoutePointModel(order: 2, type: 'place', hotelId: null, placeId: 'c', name: '허그스', latitude: 36.7774, longitude: 127.002, legDistanceM: 435, legDurationSec: 447, legTransportMode: 'walk'),
  ],
  createdAt: DateTime(2026, 9, 17),
);

Widget _wrapCourse(SavedWalkingCourseModel course, KakaoMapLauncher launcher) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SavedWalkingCourseProvider(repository: FakeSavedWalkingCourseRepository())),
      ChangeNotifierProvider(create: (_) => BookmarkProvider(repository: FakeBookmarkRepository())),
    ],
    child: MaterialApp(
      home: SavedWalkingCourseDetailScreen(
        course: course,
        mapRepository: const FakeMapRepository(),
        kakaoMapLauncher: launcher,
      ),
    ),
  );
}

Widget _wrap(SavedWalkingCourseProvider provider) {
  // Each stop card carries a BookmarkButton, which needs BookmarkProvider.
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: provider),
      ChangeNotifierProvider(create: (_) => BookmarkProvider(repository: FakeBookmarkRepository())),
    ],
    child: MaterialApp(
      home: SavedWalkingCourseDetailScreen(course: _course, mapRepository: const FakeMapRepository()),
    ),
  );
}

void main() {
  testWidgets('shows the course summary and a map marker for each place', (tester) async {
    await tester.pumpWidget(_wrap(SavedWalkingCourseProvider(repository: FakeSavedWalkingCourseRepository())));
    await tester.pumpAndSettle();

    expect(find.text('제주 코스'), findsOneWidget);
    expect(find.text('왕복'), findsOneWidget);
    expect(find.text('marker:흑돼지집'), findsOneWidget);
  });

  testWidgets('excludes the virtual region-center anchor from the stop cards and map markers', (tester) async {
    await tester.pumpWidget(_wrap(SavedWalkingCourseProvider(repository: FakeSavedWalkingCourseRepository())));
    await tester.pumpAndSettle();

    // The route's first point ("제주 중심") is a virtual region-center
    // anchor, not a real place -- it must not render as a stop card or a
    // map marker.
    expect(find.text('제주 중심'), findsNothing);
    expect(find.text('marker:제주 중심'), findsNothing);
    expect(find.textContaining('장소 1곳'), findsOneWidget);
  });

  testWidgets('tapping a place stop focuses the map on that marker', (tester) async {
    await tester.pumpWidget(_wrap(SavedWalkingCourseProvider(repository: FakeSavedWalkingCourseRepository())));
    await tester.pumpAndSettle();

    expect(find.text('focused:p1'), findsNothing);

    // The map now sits above the list, which pushes the stops below the
    // fold of the test viewport.
    await tester.ensureVisible(find.text('흑돼지집'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('흑돼지집'));
    await tester.pumpAndSettle();

    expect(find.text('focused:p1'), findsOneWidget);
  });

  testWidgets('deleting asks for confirmation, then pops on success', (tester) async {
    final repository = FakeSavedWalkingCourseRepository();
    await tester.pumpWidget(_wrap(SavedWalkingCourseProvider(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('코스 삭제'), findsOneWidget);

    // Cancelling does not delete.
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, isEmpty);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, ['sc1']);
  });

  testWidgets("a stop's map button opens that place in Kakao Map", (tester) async {
    final launcher = FakeKakaoMapLauncher();
    await tester.pumpWidget(_wrapCourse(_folderCourse, launcher));
    await tester.pumpAndSettle();

    final mapButtons = find.byTooltip('카카오맵에서 보기');
    expect(mapButtons, findsNWidgets(3));
    await tester.ensureVisible(mapButtons.at(1));
    await tester.tap(mapButtons.at(1));
    await tester.pump();

    expect(launcher.opened, [
      {'placeId': 'b', 'name': '파인데이즈', 'latitude': 36.7798},
    ]);
  });
}
