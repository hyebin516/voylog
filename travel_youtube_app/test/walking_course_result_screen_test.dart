import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/itinerary_model.dart';
import 'package:travel_youtube_app/models/nearby_recommendation_model.dart';
import 'package:travel_youtube_app/models/start_point_model.dart';
import 'package:travel_youtube_app/models/walking_course_model.dart';
import 'package:travel_youtube_app/models/saved_walking_course_model.dart';
import 'package:travel_youtube_app/providers/bookmark_provider.dart';
import 'package:travel_youtube_app/providers/walking_course_provider.dart';
import 'package:travel_youtube_app/repositories/bookmark_folder_repository.dart';
import 'package:travel_youtube_app/repositories/saved_walking_course_repository.dart';
import 'package:travel_youtube_app/repositories/walking_course_repository.dart';
import 'package:travel_youtube_app/screens/walking_course_result_screen.dart';

import 'fakes/fake_map_widget.dart';
import 'helpers/phone_viewport.dart';

const NearbyRecommendationModel _bookmarkableRec = NearbyRecommendationModel(
  placeId: 'p1',
  name: '흑돼지집',
  latitude: 33.51,
  longitude: 126.51,
  distanceMeters: 300,
  category: 'restaurant',
  isOpen: true,
  isOpenEstimated: true,
  score: 0.8,
  matchedTags: ['흑돼지'],
  reason: '취향으로 등록하신 흑돼지와 잘 맞는 곳이에요.',
);

const NearbyRecommendationModel _kakaoRec = NearbyRecommendationModel(
  placeId: 'kakao:999',
  name: '용두암',
  latitude: 33.52,
  longitude: 126.52,
  distanceMeters: 500,
  category: 'attraction',
  isOpen: null,
  isOpenEstimated: false,
  score: 0.6,
  matchedTags: [],
  reason: '현재 위치에서 500m 떨어져 있어요.',
);

// The screen lists the course's own stops (not the scored recommendations),
// so the fixture needs real route points for anything to render.
const _course = WalkingCourseRouteModel(
  routeType: 'roundTrip',
  transportMode: 'walk',
  totalDistanceM: 1800,
  totalDurationSec: 1500,
  routeData: [
    RoutePointModel(order: 0, type: 'hotel', hotelId: 'region-center', placeId: null, name: '제주', latitude: 33.5, longitude: 126.5),
    RoutePointModel(order: 1, type: 'place', hotelId: null, placeId: 'p1', name: '흑돼지집', latitude: 33.51, longitude: 126.51, legDistanceM: 900, legDurationSec: 720),
    RoutePointModel(order: 2, type: 'place', hotelId: null, placeId: 'kakao:999', name: '용두암', latitude: 33.515, longitude: 126.512, legDistanceM: 600, legDurationSec: 480),
    RoutePointModel(order: 3, type: 'hotel', hotelId: 'region-center', placeId: null, name: '제주', latitude: 33.5, longitude: 126.5, legDistanceM: 300, legDurationSec: 240),
  ],
);

class FakeSavedWalkingCourseRepository extends SavedWalkingCourseRepository {
  ApiException? error;
  String? lastRegion;

  @override
  Future<SavedWalkingCourseModel> save({
    required String region,
    required WalkingCourseRouteModel course,
  }) async {
    lastRegion = region;
    if (error != null) throw error!;
    return SavedWalkingCourseModel(
      savedCourseId: 'sc1',
      region: region,
      routeType: course.routeType,
      transportMode: course.transportMode,
      totalDistanceM: course.totalDistanceM,
      totalDurationSec: course.totalDurationSec,
      routeData: course.routeData,
      createdAt: DateTime(2026, 8, 28),
    );
  }
}

class FakeWalkingCourseRepository extends WalkingCourseRepository {
  WalkingCourseModel? resultToReturn;
  ApiException? error;
  String? lastRegion;
  int generateCalls = 0;

  /// When set, `generate()` waits on this instead of resolving immediately
  /// -- lets a test observe the provider's loading state deterministically
  /// instead of racing a real (unawaited) async gap against `pumpWidget`.
  Completer<WalkingCourseModel>? pendingCompleter;

  @override
  Future<WalkingCourseModel> generate({
    required String region,
    required DateTime localTime,
    String? mood,
    String? walkDuration,
    StartPointModel? startPoint,
    List<String> avoidPlaceIds = const [],
  }) async {
    generateCalls++;
    lastRegion = region;
    if (pendingCompleter != null) return pendingCompleter!.future;
    if (error != null) throw error!;
    return resultToReturn!;
  }
}

/// Returns a bookmark-folder route: two places walked between, then a bus.
class FakeFolderRouteRepository extends BookmarkFolderRepository {
  @override
  Future<WalkingCourseModel> createRoute(String folderId) async {
    return const WalkingCourseModel(
      course: WalkingCourseRouteModel(
        routeType: 'placeToPlace',
        transportMode: 'mixed',
        totalDistanceM: 5600,
        totalDurationSec: 1140,
        routeData: [
          RoutePointModel(order: 0, type: 'place', hotelId: null, placeId: 'a', name: '허그스', latitude: 36.78, longitude: 127.0),
          RoutePointModel(order: 1, type: 'place', hotelId: null, placeId: 'b', name: '파인데이즈', latitude: 36.781, longitude: 127.0, legDistanceM: 400, legDurationSec: 420, legTransportMode: 'walk'),
          RoutePointModel(order: 2, type: 'place', hotelId: null, placeId: 'c', name: '카페 산시', latitude: 36.77, longitude: 126.95, legDistanceM: 3391, legDurationSec: 1253, legTransportMode: 'transit', legGuidance: '600번 · 온양온천역 신한은행 → 신정호관광지 건너'),
        ],
      ),
      recommendations: [],
    );
  }
}

Widget _wrap(WalkingCourseProvider provider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: provider),
      ChangeNotifierProvider(create: (_) => BookmarkProvider()),
    ],
    child: MaterialApp(
      home: WalkingCourseResultScreen(mapRepository: const FakeMapRepository()),
    ),
  );
}

void main() {
  testWidgets('shows a loading indicator while the course is being generated', (
    tester,
  ) async {
    final completer = Completer<WalkingCourseModel>();
    final repository = FakeWalkingCourseRepository()
      ..pendingCompleter = completer;
    final provider = WalkingCourseProvider(repository: repository);

    final generateFuture = provider.generate('제주');
    await tester.pumpWidget(_wrap(provider));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(
      const WalkingCourseModel(course: null, recommendations: []),
    );
    await generateFuture;
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows an error view with a retry option on failure', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = FakeWalkingCourseRepository()
      ..error = const ApiException(code: 'GEOCODING_FAILED', message: 'boom');
    final provider = WalkingCourseProvider(repository: repository);
    await provider.generate('존재하지않는지역');

    await tester.pumpWidget(_wrap(provider));

    expect(find.text('위치 정보를 가져오지 못했습니다.'), findsOneWidget);

    repository.error = null;
    repository.resultToReturn = const WalkingCourseModel(
      course: _course,
      recommendations: [_bookmarkableRec],
    );
    await tester.ensureVisible(find.text('다시 시도'));
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('흑돼지집'), findsOneWidget);
  });

  testWidgets(
    'shows an empty-state message when the region has too few walkable places',
    (tester) async {
    usePhoneViewport(tester);
      final repository = FakeWalkingCourseRepository()
        ..resultToReturn = const WalkingCourseModel(
          course: null,
          recommendations: [_bookmarkableRec],
        );
      final provider = WalkingCourseProvider(repository: repository);
      await provider.generate('어딘가');

      await tester.pumpWidget(_wrap(provider));

      expect(find.textContaining('충분하지 않아요'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the title/subtitle, map markers, and a numbered stop list with inter-stop walk times',
    (tester) async {
    usePhoneViewport(tester);
      const courseWithRoute = WalkingCourseRouteModel(
        routeType: 'roundTrip',
        transportMode: 'walk',
        totalDistanceM: 1800,
        totalDurationSec: 1500,
        routeData: [
          RoutePointModel(
            order: 0,
            type: 'hotel',
            hotelId: 'region-center',
            placeId: null,
            name: '제주 중심',
            latitude: 33.5,
            longitude: 126.5,
          ),
          RoutePointModel(
            order: 1,
            type: 'place',
            hotelId: null,
            placeId: 'p1',
            name: '흑돼지집',
            latitude: 33.51,
            longitude: 126.51,
          ),
          RoutePointModel(
            order: 2,
            type: 'place',
            hotelId: null,
            placeId: 'kakao:999',
            name: '용두암',
            latitude: 33.52,
            longitude: 126.52,
            legDistanceM: 620,
            legDurationSec: 480,
          ),
        ],
      );
      final repository = FakeWalkingCourseRepository()
        ..resultToReturn = const WalkingCourseModel(
          course: courseWithRoute,
          recommendations: [_bookmarkableRec, _kakaoRec],
        );
      final provider = WalkingCourseProvider(repository: repository);
      await provider.generate('제주');

      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      expect(find.text('걸어서 도는 코스예요'), findsOneWidget);
      expect(find.textContaining('제주 · 도보 2곳'), findsOneWidget);
      expect(find.text('marker:흑돼지집'), findsOneWidget);
      expect(find.text('흑돼지집'), findsOneWidget);
      expect(find.text('용두암'), findsOneWidget);
      expect(find.textContaining('도보 시작'), findsOneWidget);
      // The leg arriving at the 2nd stop (480s) renders as an inter-stop walk-time row.
      expect(find.text('도보 8분'), findsOneWidget);

      // Tapping a stop focuses the map on that stop's marker.
      expect(find.text('focused:kakao:999'), findsNothing);
      await tester.ensureVisible(find.text('용두암'));
      await tester.tap(find.text('용두암'));
      await tester.pumpAndSettle();
      expect(find.text('focused:kakao:999'), findsOneWidget);
    },
  );

  testWidgets('tapping "다시 생성" regenerates the course for the same region', (
    tester,
  ) async {
    const courseWithRoute = WalkingCourseRouteModel(
      routeType: 'roundTrip',
      transportMode: 'walk',
      totalDistanceM: 1800,
      totalDurationSec: 1500,
      routeData: [
        RoutePointModel(
          order: 0,
          type: 'hotel',
          hotelId: 'region-center',
          placeId: null,
          name: '제주 중심',
          latitude: 33.5,
          longitude: 126.5,
        ),
        RoutePointModel(
          order: 1,
          type: 'place',
          hotelId: null,
          placeId: 'p1',
          name: '흑돼지집',
          latitude: 33.51,
          longitude: 126.51,
        ),
      ],
    );
    final repository = FakeWalkingCourseRepository()
      ..resultToReturn = const WalkingCourseModel(
        course: courseWithRoute,
        recommendations: [_bookmarkableRec],
      );
    final provider = WalkingCourseProvider(repository: repository);
    await provider.generate('제주');

    await tester.pumpWidget(_wrap(provider));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('다시 생성'));
    await tester.tap(find.text('다시 생성'));
    await tester.pumpAndSettle();

    expect(repository.generateCalls, 2);
    expect(repository.lastRegion, '제주');
  });

  testWidgets(
    'tapping "코스 저장하기" saves the course and relabels the button once saved',
    (tester) async {
    usePhoneViewport(tester);
      const courseWithRoute = WalkingCourseRouteModel(
        routeType: 'roundTrip',
        transportMode: 'walk',
        totalDistanceM: 1800,
        totalDurationSec: 1500,
        routeData: [
          RoutePointModel(
            order: 0,
            type: 'hotel',
            hotelId: 'region-center',
            placeId: null,
            name: '제주 중심',
            latitude: 33.5,
            longitude: 126.5,
          ),
        ],
      );
      final repository = FakeWalkingCourseRepository()
        ..resultToReturn = const WalkingCourseModel(
          course: courseWithRoute,
          recommendations: [],
        );
      final savedRepository = FakeSavedWalkingCourseRepository();
      final provider = WalkingCourseProvider(
        repository: repository,
        savedCourseRepository: savedRepository,
      );
      await provider.generate('제주');

      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      expect(find.text('코스 저장하기'), findsOneWidget);

      await tester.ensureVisible(find.text('코스 저장하기'));
      await tester.tap(find.text('코스 저장하기'));
      await tester.pumpAndSettle();

      expect(savedRepository.lastRegion, '제주');
      expect(find.text('저장됨'), findsOneWidget);
      expect(find.text('코스를 저장했어요.'), findsOneWidget); // SnackBar
    },
  );

  testWidgets(
    'shows a snackbar with the friendly error message when saving fails',
    (tester) async {
    usePhoneViewport(tester);
      const courseWithRoute = WalkingCourseRouteModel(
        routeType: 'roundTrip',
        transportMode: 'walk',
        totalDistanceM: 1800,
        totalDurationSec: 1500,
        routeData: [
          RoutePointModel(
            order: 0,
            type: 'hotel',
            hotelId: 'region-center',
            placeId: null,
            name: '제주 중심',
            latitude: 33.5,
            longitude: 126.5,
          ),
        ],
      );
      final repository = FakeWalkingCourseRepository()
        ..resultToReturn = const WalkingCourseModel(
          course: courseWithRoute,
          recommendations: [],
        );
      final savedRepository = FakeSavedWalkingCourseRepository()
        ..error = const ApiException(code: 'NETWORK_ERROR', message: 'boom');
      final provider = WalkingCourseProvider(
        repository: repository,
        savedCourseRepository: savedRepository,
      );
      await provider.generate('제주');

      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('코스 저장하기'));
      await tester.tap(find.text('코스 저장하기'));
      await tester.pumpAndSettle();

      expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);
      expect(
        find.text('코스 저장하기'),
        findsOneWidget,
      ); // button stays enabled to retry
    },
  );

  testWidgets('a bookmark-folder route shows which legs are walked and which bus to take', (tester) async {
    // A pure walking route had a 61-minute walk between two bookmarks.
    usePhoneViewport(tester);
    final provider = WalkingCourseProvider(
      repository: FakeWalkingCourseRepository(),
      folderRepository: FakeFolderRouteRepository(),
    );
    await provider.generateFromBookmarkFolder(folderId: 'f1', folderName: '아산');

    await tester.pumpWidget(_wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text('걷고, 먼 곳은 버스로 가는 코스예요'), findsOneWidget);
    expect(find.textContaining('아산 · 장소 3곳'), findsOneWidget);
    expect(find.text('도보 7분'), findsOneWidget);
    expect(find.text('버스 21분 · 600번 · 온양온천역 신한은행 → 신정호관광지 건너'), findsOneWidget);
    expect(find.text('출발'), findsOneWidget);
    expect(find.textContaining('도보 시작'), findsNothing);
    // No region to re-anchor on, so no start point picker.
    expect(find.text('시작 지점 정하기'), findsNothing);
  });
}
