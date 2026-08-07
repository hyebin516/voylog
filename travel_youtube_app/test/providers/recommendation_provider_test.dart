import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/nearby_recommendation_model.dart';
import 'package:travel_youtube_app/providers/recommendation_provider.dart';
import 'package:travel_youtube_app/repositories/recommendation_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

const NearbyRecommendationModel _rec = NearbyRecommendationModel(
  placeId: 'p1',
  name: 'Place',
  latitude: 37.5,
  longitude: 127.0,
  distanceMeters: 100,
  category: 'cafe',
  isOpen: true,
  isOpenEstimated: true,
  score: 0.8,
  reason: 'reason',
);

class FakeRecommendationRepository extends RecommendationRepository {
  List<NearbyRecommendationModel> resultsToReturn = [];
  ApiException? error;
  double? lastLatitude;
  double? lastLongitude;

  @override
  Future<List<NearbyRecommendationModel>> getNearby({
    required double latitude,
    required double longitude,
    required DateTime localTime,
    int? radiusMeters,
    int? limit,
  }) async {
    lastLatitude = latitude;
    lastLongitude = longitude;
    if (error != null) throw error!;
    return resultsToReturn;
  }
}

void main() {
  late FakeRecommendationRepository repository;
  late RecommendationProvider provider;

  setUp(() {
    repository = FakeRecommendationRepository();
    provider = RecommendationProvider(repository: repository);
  });

  test('starts idle with no recommendations', () {
    expect(provider.state, ViewState.idle);
    expect(provider.recommendations, isEmpty);
  });

  group('loadNearby', () {
    test('transitions to success and stores the recommendations', () async {
      repository.resultsToReturn = [_rec];

      await provider.loadNearby(latitude: 37.5, longitude: 127.0);

      expect(repository.lastLatitude, 37.5);
      expect(repository.lastLongitude, 127.0);
      expect(provider.state, ViewState.success);
      expect(provider.recommendations, [_rec]);
    });

    test('transitions to error with a friendly message on failure', () async {
      repository.error = const ApiException(code: 'NETWORK_ERROR', message: 'boom');

      await provider.loadNearby(latitude: 37.5, longitude: 127.0);

      expect(provider.state, ViewState.error);
      expect(provider.errorMessage, isNotNull);
      expect(provider.recommendations, isEmpty);
    });
  });
}
