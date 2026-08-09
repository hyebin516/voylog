import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/nearby_recommendation_model.dart';
import 'package:travel_youtube_app/providers/recommendation_provider.dart';
import 'package:travel_youtube_app/repositories/behavior_repository.dart';
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
  matchedTags: [],
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

class FakeBehaviorRepository extends BehaviorRepository {
  ApiException? error;
  final List<Map<String, dynamic>> recordedCalls = [];

  @override
  Future<void> record({
    required String placeId,
    required String action,
    String? screen,
    int? distanceMeters,
  }) async {
    recordedCalls.add({'placeId': placeId, 'action': action, 'screen': screen, 'distanceMeters': distanceMeters});
    if (error != null) throw error!;
  }
}

void main() {
  late FakeRecommendationRepository repository;
  late FakeBehaviorRepository behaviorRepository;
  late RecommendationProvider provider;

  setUp(() {
    repository = FakeRecommendationRepository();
    behaviorRepository = FakeBehaviorRepository();
    provider = RecommendationProvider(repository: repository, behaviorRepository: behaviorRepository);
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

  group('recordViewDetail', () {
    test('records a view_detail behavior with the place distance', () async {
      await provider.recordViewDetail(_rec);

      expect(behaviorRepository.recordedCalls, [
        {'placeId': 'p1', 'action': 'view_detail', 'screen': 'nearby', 'distanceMeters': 100},
      ]);
    });

    test('does not throw when the recording call fails (best-effort)', () async {
      behaviorRepository.error = const ApiException(code: 'NETWORK_ERROR', message: 'boom');

      await expectLater(provider.recordViewDetail(_rec), completes);
    });
  });

  group('recordBookmark', () {
    test('records a bookmark behavior with the place distance', () async {
      await provider.recordBookmark(_rec);

      expect(behaviorRepository.recordedCalls, [
        {'placeId': 'p1', 'action': 'bookmark', 'screen': 'nearby', 'distanceMeters': 100},
      ]);
    });
  });

  group('markNotInterested', () {
    test('optimistically removes the place from the list and records not_interested', () async {
      repository.resultsToReturn = [_rec];
      await provider.loadNearby(latitude: 37.5, longitude: 127.0);
      expect(provider.recommendations, [_rec]);

      await provider.markNotInterested(_rec);

      expect(provider.recommendations, isEmpty);
      expect(behaviorRepository.recordedCalls, [
        {'placeId': 'p1', 'action': 'not_interested', 'screen': 'nearby', 'distanceMeters': 100},
      ]);
    });

    test('still removes the place from the list even when the recording call fails', () async {
      repository.resultsToReturn = [_rec];
      await provider.loadNearby(latitude: 37.5, longitude: 127.0);
      behaviorRepository.error = const ApiException(code: 'NETWORK_ERROR', message: 'boom');

      await provider.markNotInterested(_rec);

      expect(provider.recommendations, isEmpty);
    });
  });
}
