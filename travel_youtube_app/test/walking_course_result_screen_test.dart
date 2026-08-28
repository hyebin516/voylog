import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/itinerary_model.dart';
import 'package:travel_youtube_app/models/nearby_recommendation_model.dart';
import 'package:travel_youtube_app/models/walking_course_model.dart';
import 'package:travel_youtube_app/models/saved_walking_course_model.dart';
import 'package:travel_youtube_app/providers/bookmark_provider.dart';
import 'package:travel_youtube_app/providers/walking_course_provider.dart';
import 'package:travel_youtube_app/repositories/saved_walking_course_repository.dart';
import 'package:travel_youtube_app/repositories/walking_course_repository.dart';
import 'package:travel_youtube_app/screens/walking_course_result_screen.dart';

import 'fakes/fake_map_widget.dart';

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

const _course = WalkingCourseRouteModel(
  routeType: 'roundTrip',
  transportMode: 'walk',
  totalDistanceM: 1800,
  totalDurationSec: 1500,
  routeData: [],
);

class FakeSavedWalkingCourseRepository extends SavedWalkingCourseRepository {
  ApiException? error;
  String? lastRegion;

  @override
  Future<SavedWalkingCourseModel> save({required String region, required WalkingCourseRouteModel course}) async {
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

  /// When set, `generate()` waits on this instead of resolving immediately
  /// -- lets a test observe the provider's loading state deterministically
  /// instead of racing a real (unawaited) async gap against `pumpWidget`.
  Completer<WalkingCourseModel>? pendingCompleter;

  @override
  Future<WalkingCourseModel> generate({required String region, required DateTime localTime}) async {
    if (pendingCompleter != null) return pendingCompleter!.future;
    if (error != null) throw error!;
    return resultToReturn!;
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
  testWidgets('shows a loading indicator while the course is being generated', (tester) async {
    final completer = Completer<WalkingCourseModel>();
    final repository = FakeWalkingCourseRepository()..pendingCompleter = completer;
    final provider = WalkingCourseProvider(repository: repository);

    final generateFuture = provider.generate('제주');
    await tester.pumpWidget(_wrap(provider));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const WalkingCourseModel(course: null, recommendations: []));
    await generateFuture;
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows an error view with a retry option on failure', (tester) async {
    final repository = FakeWalkingCourseRepository()..error = const ApiException(code: 'GEOCODING_FAILED', message: 'boom');
    final provider = WalkingCourseProvider(repository: repository);
    await provider.generate('존재하지않는지역');

    await tester.pumpWidget(_wrap(provider));

    expect(find.text('위치 정보를 가져오지 못했습니다.'), findsOneWidget);

    repository.error = null;
    repository.resultToReturn = const WalkingCourseModel(course: _course, recommendations: [_bookmarkableRec]);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('흑돼지집'), findsOneWidget);
  });

  testWidgets('shows an empty-state message when the region has too few walkable places', (tester) async {
    final repository = FakeWalkingCourseRepository()
      ..resultToReturn = const WalkingCourseModel(course: null, recommendations: [_bookmarkableRec]);
    final provider = WalkingCourseProvider(repository: repository);
    await provider.generate('어딘가');

    await tester.pumpWidget(_wrap(provider));

    expect(find.textContaining('충분하지 않아요'), findsOneWidget);
  });

  testWidgets('shows the course summary, map markers, and per-place reasons; only bookmarkable places get a bookmark button', (tester) async {
    const courseWithRoute = WalkingCourseRouteModel(
      routeType: 'roundTrip',
      transportMode: 'walk',
      totalDistanceM: 1800,
      totalDurationSec: 1500,
      routeData: [
        RoutePointModel(order: 0, type: 'hotel', hotelId: 'region-center', placeId: null, name: '제주 중심', latitude: 33.5, longitude: 126.5),
        RoutePointModel(order: 1, type: 'place', hotelId: null, placeId: 'p1', name: '흑돼지집', latitude: 33.51, longitude: 126.51),
      ],
    );
    final repository = FakeWalkingCourseRepository()
      ..resultToReturn = const WalkingCourseModel(course: courseWithRoute, recommendations: [_bookmarkableRec, _kakaoRec]);
    final provider = WalkingCourseProvider(repository: repository);
    await provider.generate('제주');

    await tester.pumpWidget(_wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text('왕복'), findsOneWidget);
    expect(find.text('marker:흑돼지집'), findsOneWidget);
    expect(find.text('흑돼지집'), findsWidgets); // once in the route list, once in the recommendation card
    expect(find.text('용두암'), findsOneWidget);
    expect(find.text('취향으로 등록하신 흑돼지와 잘 맞는 곳이에요.'), findsOneWidget);
    expect(find.text('흑돼지'), findsOneWidget); // matched-tag chip

    // Only the bookmarkable (non-"kakao:"-prefixed) recommendation gets a bookmark button.
    expect(find.byTooltip('북마크'), findsOneWidget);
  });

  testWidgets('tapping "코스 저장하기" saves the course and relabels the button once saved', (tester) async {
    const courseWithRoute = WalkingCourseRouteModel(
      routeType: 'roundTrip',
      transportMode: 'walk',
      totalDistanceM: 1800,
      totalDurationSec: 1500,
      routeData: [
        RoutePointModel(order: 0, type: 'hotel', hotelId: 'region-center', placeId: null, name: '제주 중심', latitude: 33.5, longitude: 126.5),
      ],
    );
    final repository = FakeWalkingCourseRepository()
      ..resultToReturn = const WalkingCourseModel(course: courseWithRoute, recommendations: []);
    final savedRepository = FakeSavedWalkingCourseRepository();
    final provider = WalkingCourseProvider(repository: repository, savedCourseRepository: savedRepository);
    await provider.generate('제주');

    await tester.pumpWidget(_wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text('코스 저장하기'), findsOneWidget);

    await tester.tap(find.text('코스 저장하기'));
    await tester.pumpAndSettle();

    expect(savedRepository.lastRegion, '제주');
    expect(find.text('저장됨'), findsOneWidget);
    expect(find.text('코스를 저장했어요.'), findsOneWidget); // SnackBar
  });

  testWidgets('shows a snackbar with the friendly error message when saving fails', (tester) async {
    const courseWithRoute = WalkingCourseRouteModel(
      routeType: 'roundTrip',
      transportMode: 'walk',
      totalDistanceM: 1800,
      totalDurationSec: 1500,
      routeData: [
        RoutePointModel(order: 0, type: 'hotel', hotelId: 'region-center', placeId: null, name: '제주 중심', latitude: 33.5, longitude: 126.5),
      ],
    );
    final repository = FakeWalkingCourseRepository()
      ..resultToReturn = const WalkingCourseModel(course: courseWithRoute, recommendations: []);
    final savedRepository = FakeSavedWalkingCourseRepository()
      ..error = const ApiException(code: 'NETWORK_ERROR', message: 'boom');
    final provider = WalkingCourseProvider(repository: repository, savedCourseRepository: savedRepository);
    await provider.generate('제주');

    await tester.pumpWidget(_wrap(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('코스 저장하기'));
    await tester.pumpAndSettle();

    expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);
    expect(find.text('코스 저장하기'), findsOneWidget); // button stays enabled to retry
  });
}
