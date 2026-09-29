import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';
import 'package:travel_youtube_app/models/location_result.dart';
import 'package:travel_youtube_app/models/nearby_recommendation_model.dart';
import 'package:travel_youtube_app/models/place_model.dart';
import 'package:travel_youtube_app/providers/bookmark_provider.dart';
import 'package:travel_youtube_app/providers/location_provider.dart';
import 'package:travel_youtube_app/providers/recommendation_provider.dart';
import 'package:travel_youtube_app/repositories/behavior_repository.dart';
import 'package:travel_youtube_app/repositories/bookmark_repository.dart';
import 'package:travel_youtube_app/repositories/recommendation_repository.dart';
import 'package:travel_youtube_app/routes/app_routes.dart';
import 'package:travel_youtube_app/screens/nearby_recommendations_screen.dart';

import 'fakes/fake_location_repository.dart';
import 'fakes/fake_map_widget.dart';

const LocationResult _location = LocationResult(latitude: 37.5, longitude: 127.0);

const NearbyRecommendationModel _rec = NearbyRecommendationModel(
  placeId: 'b4e01fd9-a17c-4fec-bee6-24184eff96ee',
  name: '예시 베이커리 카페',
  latitude: 37.5,
  longitude: 127.0,
  distanceMeters: 420,
  category: 'bakery',
  address: '서울 성동구 왕십리로 83',
  businessHours: {'mon': {'open': '09:00', 'close': '21:00'}},
  tags: ['소금빵'],
  isOpen: true,
  isOpenEstimated: true,
  score: 0.87,
  matchedTags: ['소금빵', '오션뷰'],
  reason: '현재 위치에서 420m 떨어져 있어요. 지금 영업 중이에요.',
);

class FakeRecommendationRepository extends RecommendationRepository {
  List<NearbyRecommendationModel> resultsToReturn = [];
  ApiException? error;

  @override
  Future<List<NearbyRecommendationModel>> getNearby({
    required double latitude,
    required double longitude,
    required DateTime localTime,
    int? radiusMeters,
    int? limit,
    String? categoryGroup,
  }) async {
    if (error != null) throw error!;
    return resultsToReturn;
  }
}

class FakeBehaviorRepository extends BehaviorRepository {
  final List<String> recordedActions = [];

  @override
  Future<void> record({
    required String placeId,
    required String action,
    String? screen,
    int? distanceMeters,
  }) async {
    recordedActions.add(action);
  }
}

class FakeBookmarkRepository extends BookmarkRepository {
  List<BookmarkModel> bookmarksToReturn = [];

  @override
  Future<List<BookmarkModel>> listBookmarks() async => bookmarksToReturn;

  @override
  Future<String> addBookmark(String placeId) async => 'new-bookmark-id';

  @override
  Future<void> removeBookmark(String bookmarkId) async {}
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String> pushedRoutes = [];
  Object? lastPushedArguments;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) pushedRoutes.add(name);
    lastPushedArguments = route.settings.arguments;
  }
}

Widget _wrap(
  LocationProvider locationProvider,
  RecommendationProvider recommendationProvider, {
  BookmarkProvider? bookmarkProvider,
  NavigatorObserver? navigatorObserver,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: locationProvider),
      ChangeNotifierProvider.value(value: recommendationProvider),
      ChangeNotifierProvider.value(value: bookmarkProvider ?? BookmarkProvider(repository: FakeBookmarkRepository())),
    ],
    child: MaterialApp(
      home: const NearbyRecommendationsScreen(mapRepository: FakeMapRepository()),
      onGenerateRoute: AppRoutes.onGenerateRoute,
      navigatorObservers: [?navigatorObserver],
    ),
  );
}

void main() {
  testWidgets('shows a location error view when permission is denied', (tester) async {
    final locationRepository = FakeLocationRepository()..permissionToReturn = LocationPermissionState.denied;

    await tester.pumpWidget(_wrap(
      LocationProvider(repository: locationRepository),
      RecommendationProvider(repository: FakeRecommendationRepository()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('주변 추천을 이용하려면 위치 권한이 필요합니다.'), findsOneWidget);
  });

  testWidgets('lists nearby recommendations once location is available', (tester) async {
    final locationRepository = FakeLocationRepository()
      ..permissionToReturn = LocationPermissionState.granted
      ..locationToReturn = _location;
    final recommendationRepository = FakeRecommendationRepository()..resultsToReturn = [_rec];

    await tester.pumpWidget(_wrap(
      LocationProvider(repository: locationRepository),
      RecommendationProvider(repository: recommendationRepository),
    ));
    await tester.pumpAndSettle();

    expect(find.text('예시 베이커리 카페'), findsOneWidget);
    expect(find.text('영업중'), findsOneWidget);
    expect(find.text('소금빵'), findsOneWidget);
    expect(find.text('오션뷰'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no nearby recommendations', (tester) async {
    final locationRepository = FakeLocationRepository()
      ..permissionToReturn = LocationPermissionState.granted
      ..locationToReturn = _location;

    await tester.pumpWidget(_wrap(
      LocationProvider(repository: locationRepository),
      RecommendationProvider(repository: FakeRecommendationRepository()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('주변에 추천할 장소가 없습니다.'), findsOneWidget);
  });

  testWidgets('shows a recommendation error view when the request fails', (tester) async {
    final locationRepository = FakeLocationRepository()
      ..permissionToReturn = LocationPermissionState.granted
      ..locationToReturn = _location;
    final recommendationRepository = FakeRecommendationRepository()
      ..error = const ApiException(code: 'NETWORK_ERROR', message: 'boom');

    await tester.pumpWidget(_wrap(
      LocationProvider(repository: locationRepository),
      RecommendationProvider(repository: recommendationRepository),
    ));
    await tester.pumpAndSettle();

    expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);
  });

  testWidgets('tapping a card records view_detail and navigates to the place detail route', (tester) async {
    final locationRepository = FakeLocationRepository()
      ..permissionToReturn = LocationPermissionState.granted
      ..locationToReturn = _location;
    final recommendationRepository = FakeRecommendationRepository()..resultsToReturn = [_rec];
    final behaviorRepository = FakeBehaviorRepository();
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(_wrap(
      LocationProvider(repository: locationRepository),
      RecommendationProvider(repository: recommendationRepository, behaviorRepository: behaviorRepository),
      navigatorObserver: observer,
    ));
    await tester.pumpAndSettle();

    // Deliberately not pumping after the tap: the place detail route renders
    // a real KakaoMapWidget (this recommendation always has coordinates),
    // which per CLAUDE.md must never load under `flutter test`. A tap's
    // gesture callback fires synchronously without a pump, which is enough
    // to observe both the behavior recording and the navigation attempt.
    await tester.tap(find.text('예시 베이커리 카페'));

    expect(behaviorRepository.recordedActions, contains('view_detail'));
    expect(observer.pushedRoutes, contains(AppRoutes.placeDetail));

    // The detail screen is opened with everything the recommendation already
    // carries; it used to get a name and a pin only, so the address, category
    // and hours sections came up empty for a place that has them.
    final place = observer.lastPushedArguments as PlaceModel;
    expect(place.address, '서울 성동구 왕십리로 83');
    expect(place.category, 'bakery');
    expect(place.businessHours!['mon'], {'open': '09:00', 'close': '21:00'});
    expect(place.tags, ['소금빵']);
  });

  testWidgets('bookmarking a card records a bookmark behavior', (tester) async {
    final locationRepository = FakeLocationRepository()
      ..permissionToReturn = LocationPermissionState.granted
      ..locationToReturn = _location;
    final recommendationRepository = FakeRecommendationRepository()..resultsToReturn = [_rec];
    final behaviorRepository = FakeBehaviorRepository();

    await tester.pumpWidget(_wrap(
      LocationProvider(repository: locationRepository),
      RecommendationProvider(repository: recommendationRepository, behaviorRepository: behaviorRepository),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('북마크'));
    await tester.pumpAndSettle();

    expect(behaviorRepository.recordedActions, contains('bookmark'));
  });

  testWidgets('tapping the map icon opens a map sheet and records map_view', (tester) async {
    final locationRepository = FakeLocationRepository()
      ..permissionToReturn = LocationPermissionState.granted
      ..locationToReturn = _location;
    final recommendationRepository = FakeRecommendationRepository()..resultsToReturn = [_rec];
    final behaviorRepository = FakeBehaviorRepository();

    await tester.pumpWidget(_wrap(
      LocationProvider(repository: locationRepository),
      RecommendationProvider(repository: recommendationRepository, behaviorRepository: behaviorRepository),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('지도 보기'));
    await tester.pumpAndSettle();

    expect(behaviorRepository.recordedActions, contains('map_view'));
    expect(find.text('예시 베이커리 카페'), findsWidgets);
  });

  testWidgets('marking a card as not interested removes it and records not_interested', (tester) async {
    final locationRepository = FakeLocationRepository()
      ..permissionToReturn = LocationPermissionState.granted
      ..locationToReturn = _location;
    final recommendationRepository = FakeRecommendationRepository()..resultsToReturn = [_rec];
    final behaviorRepository = FakeBehaviorRepository();

    await tester.pumpWidget(_wrap(
      LocationProvider(repository: locationRepository),
      RecommendationProvider(repository: recommendationRepository, behaviorRepository: behaviorRepository),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('관심 없음'));
    await tester.pumpAndSettle();

    expect(behaviorRepository.recordedActions, contains('not_interested'));
    expect(find.text('예시 베이커리 카페'), findsNothing);
    expect(find.text('주변에 추천할 장소가 없습니다.'), findsOneWidget);
  });
}
