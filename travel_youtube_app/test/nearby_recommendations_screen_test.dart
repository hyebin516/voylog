import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/location_result.dart';
import 'package:travel_youtube_app/models/nearby_recommendation_model.dart';
import 'package:travel_youtube_app/providers/location_provider.dart';
import 'package:travel_youtube_app/providers/recommendation_provider.dart';
import 'package:travel_youtube_app/repositories/recommendation_repository.dart';
import 'package:travel_youtube_app/screens/nearby_recommendations_screen.dart';

import 'fakes/fake_location_repository.dart';

const LocationResult _location = LocationResult(latitude: 37.5, longitude: 127.0);

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
  }) async {
    if (error != null) throw error!;
    return resultsToReturn;
  }
}

Widget _wrap(LocationProvider locationProvider, RecommendationProvider recommendationProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: locationProvider),
      ChangeNotifierProvider.value(value: recommendationProvider),
    ],
    child: const MaterialApp(home: NearbyRecommendationsScreen()),
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
    final recommendationRepository = FakeRecommendationRepository()
      ..resultsToReturn = [
        const NearbyRecommendationModel(
          placeId: 'p1',
          name: '예시 베이커리 카페',
          latitude: 37.5,
          longitude: 127.0,
          distanceMeters: 420,
          category: 'bakery',
          isOpen: true,
          isOpenEstimated: true,
          score: 0.87,
          matchedTags: ['소금빵', '오션뷰'],
          reason: '현재 위치에서 420m 떨어져 있어요. 지금 영업 중이에요.',
        ),
      ];

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
}
