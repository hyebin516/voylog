import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';
import 'package:travel_youtube_app/models/itinerary_model.dart';
import 'package:travel_youtube_app/providers/itinerary_provider.dart';
import 'package:travel_youtube_app/repositories/itinerary_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

ItineraryModel _result({
  required String startHotelId,
  required String endHotelId,
  String transportMode = 'car',
}) {
  return ItineraryModel(
    itineraryId: 'it1',
    tripId: 'trip1',
    dayNumber: 1,
    startHotelId: startHotelId,
    endHotelId: endHotelId,
    routeType: startHotelId == endHotelId ? 'roundTrip' : 'hotelToHotel',
    optimizationPriority: 'duration',
    transportMode: transportMode,
    totalDistanceM: 1000,
    totalDurationSec: 600,
    routeData: const [],
  );
}

BookmarkModel _place(String placeId) {
  return BookmarkModel(
    bookmarkId: 'b-$placeId',
    placeId: placeId,
    videoId: 'v1',
    name: 'place $placeId',
    address: null,
    latitude: null,
    longitude: null,
    timestampSec: null,
    source: 'transcript',
    confidence: 1,
    bookmarkedAt: DateTime(2026, 1, 1),
  );
}

class FakeItineraryRepository extends ItineraryRepository {
  ItineraryModel? resultToReturn;
  ApiException? error;
  Map<String, dynamic>? lastCallArgs;

  @override
  Future<ItineraryModel> createItinerary({
    required String tripId,
    required int dayNumber,
    required String startHotelId,
    required String endHotelId,
    required List<String> placeIds,
    String transportMode = 'car',
  }) async {
    lastCallArgs = {
      'tripId': tripId,
      'dayNumber': dayNumber,
      'startHotelId': startHotelId,
      'endHotelId': endHotelId,
      'placeIds': placeIds,
      'transportMode': transportMode,
    };
    if (error != null) throw error!;
    return resultToReturn!;
  }
}

void main() {
  late FakeItineraryRepository repository;
  late ItineraryProvider provider;

  setUp(() {
    repository = FakeItineraryRepository();
    provider = ItineraryProvider(repository: repository);
  });

  group('setSelectedPlacesFromFolder (min 2, max 10)', () {
    test('canOptimize is false below the minimum of 2 places', () {
      provider.setSelectedPlacesFromFolder('f1', '제주 폴더', [_place('p1')]);
      expect(provider.canOptimize, isFalse);
    });

    test('canOptimize becomes true once 2 places are selected', () {
      provider.setSelectedPlacesFromFolder('f1', '제주 폴더', [
        _place('p1'),
        _place('p2'),
      ]);
      expect(provider.canOptimize, isTrue);
    });

    test('records the source folder id and name', () {
      provider.setSelectedPlacesFromFolder('f1', '제주 폴더', [
        _place('p1'),
        _place('p2'),
      ]);
      expect(provider.sourceFolderId, 'f1');
      expect(provider.sourceFolderName, '제주 폴더');
    });

    test('removePlace drops a place from the selection', () {
      provider.setSelectedPlacesFromFolder('f1', '제주 폴더', [
        _place('p1'),
        _place('p2'),
      ]);
      provider.removePlace('p1');
      expect(provider.selectedPlaceIds, {'p2'});
    });

    test('caps the selection at the maximum of 10 places', () {
      final places = [for (var i = 0; i < 12; i++) _place('p$i')];
      provider.setSelectedPlacesFromFolder('f1', '제주 폴더', places);
      expect(provider.selectedPlaces, hasLength(10));
    });

    test('replaces a previous folder selection entirely', () {
      provider.setSelectedPlacesFromFolder('f1', '제주 폴더', [
        _place('p1'),
        _place('p2'),
      ]);
      provider.setSelectedPlacesFromFolder('f2', '부산 폴더', [_place('p3')]);
      expect(provider.selectedPlaceIds, {'p3'});
      expect(provider.sourceFolderName, '부산 폴더');
    });
  });

  group('transportMode', () {
    test('defaults to car', () {
      expect(provider.transportMode, 'car');
    });

    test('selectTransportMode updates the selected mode', () {
      provider.selectTransportMode('walk');
      expect(provider.transportMode, 'walk');
    });
  });

  group('optimize', () {
    test('sends the selected transportMode to the repository', () async {
      provider.setSelectedPlacesFromFolder('f1', '제주 폴더', [
        _place('p1'),
        _place('p2'),
      ]);
      provider.selectTransportMode('walk');
      repository.resultToReturn = _result(
        startHotelId: 'h1',
        endHotelId: 'h1',
        transportMode: 'walk',
      );

      await provider.optimize(
        tripId: 'trip1',
        dayNumber: 1,
        startHotelId: 'h1',
        endHotelId: 'h1',
      );

      expect(repository.lastCallArgs?['transportMode'], 'walk');
      expect(provider.result?.isWalk, isTrue);
    });

    test(
      'does nothing when fewer than 2 places are selected (guarded by canOptimize)',
      () async {
        provider.setSelectedPlacesFromFolder('f1', '제주 폴더', [_place('p1')]);

        await provider.optimize(
          tripId: 'trip1',
          dayNumber: 1,
          startHotelId: 'h1',
          endHotelId: 'h1',
        );

        expect(provider.state, ViewState.idle);
        expect(repository.lastCallArgs, isNull);
      },
    );

    test(
      'sends the trip/day and selected place ids, and derives the result on success',
      () async {
        provider.setSelectedPlacesFromFolder('f1', '제주 폴더', [
          _place('p1'),
          _place('p2'),
        ]);
        repository.resultToReturn = _result(
          startHotelId: 'h1',
          endHotelId: 'h1',
        );

        await provider.optimize(
          tripId: 'trip1',
          dayNumber: 2,
          startHotelId: 'h1',
          endHotelId: 'h1',
        );

        expect(provider.state, ViewState.success);
        expect(provider.result?.isRoundTrip, isTrue);
        expect(repository.lastCallArgs?['tripId'], 'trip1');
        expect(repository.lastCallArgs?['dayNumber'], 2);
        expect(repository.lastCallArgs?['startHotelId'], 'h1');
        expect(repository.lastCallArgs?['endHotelId'], 'h1');
        expect((repository.lastCallArgs?['placeIds'] as List).toSet(), {
          'p1',
          'p2',
        });
      },
    );

    test('sets an error state with a friendly message on failure', () async {
      provider.setSelectedPlacesFromFolder('f1', '제주 폴더', [
        _place('p1'),
        _place('p2'),
      ]);
      repository.error = const ApiException(
        code: 'HOTEL_NOT_FOUND',
        message: 'boom',
      );

      await provider.optimize(
        tripId: 'trip1',
        dayNumber: 1,
        startHotelId: 'h1',
        endHotelId: 'h2',
      );

      expect(provider.state, ViewState.error);
      expect(provider.errorMessage, '선택한 호텔을 찾을 수 없습니다.');
    });
  });

  test(
    'reset clears selection, source folder, result, transportMode, and returns to idle',
    () async {
      provider.setSelectedPlacesFromFolder('f1', '제주 폴더', [
        _place('p1'),
        _place('p2'),
      ]);
      provider.selectTransportMode('walk');
      repository.resultToReturn = _result(
        startHotelId: 'h1',
        endHotelId: 'h1',
        transportMode: 'walk',
      );
      await provider.optimize(
        tripId: 'trip1',
        dayNumber: 1,
        startHotelId: 'h1',
        endHotelId: 'h1',
      );

      provider.reset();

      expect(provider.selectedPlaceIds, isEmpty);
      expect(provider.sourceFolderId, isNull);
      expect(provider.sourceFolderName, isNull);
      expect(provider.result, isNull);
      expect(provider.state, ViewState.idle);
      expect(provider.transportMode, 'car');
    },
  );
}
