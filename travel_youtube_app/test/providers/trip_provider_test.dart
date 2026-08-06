import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/itinerary_model.dart';
import 'package:travel_youtube_app/models/trip_model.dart';
import 'package:travel_youtube_app/providers/trip_provider.dart';
import 'package:travel_youtube_app/repositories/trip_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

TripModel _trip(String id, {int dayCount = 0}) {
  return TripModel(tripId: id, name: 'Trip $id', dayCount: dayCount, createdAt: DateTime(2026, 1, 1));
}

ItineraryModel _day(String tripId, int dayNumber) {
  return ItineraryModel(
    itineraryId: 'it-$dayNumber',
    tripId: tripId,
    dayNumber: dayNumber,
    startHotelId: 'h1',
    endHotelId: 'h1',
    routeType: 'roundTrip',
    optimizationPriority: 'duration',
    totalDistanceM: 1000,
    totalDurationSec: 600,
    routeData: const [],
  );
}

class FakeTripRepository extends TripRepository {
  List<TripModel> tripsToReturn = [];
  ApiException? listError;
  TripModel? createdTrip;
  ApiException? createError;
  TripDetailModel? tripDetailToReturn;
  ApiException? getError;
  ApiException? deleteError;
  final List<String> deleteCalls = [];

  @override
  Future<List<TripModel>> listTrips() async {
    if (listError != null) throw listError!;
    return tripsToReturn;
  }

  @override
  Future<TripModel> createTrip(String name) async {
    if (createError != null) throw createError!;
    return createdTrip!;
  }

  @override
  Future<TripDetailModel> getTrip(String tripId) async {
    if (getError != null) throw getError!;
    return tripDetailToReturn!;
  }

  @override
  Future<void> deleteTrip(String tripId) async {
    deleteCalls.add(tripId);
    if (deleteError != null) throw deleteError!;
  }
}

void main() {
  late FakeTripRepository repository;
  late TripProvider provider;

  setUp(() {
    repository = FakeTripRepository();
    provider = TripProvider(repository: repository);
  });

  group('loadTrips', () {
    test('populates trips on success', () async {
      repository.tripsToReturn = [_trip('t1'), _trip('t2')];

      await provider.loadTrips();

      expect(provider.state, ViewState.success);
      expect(provider.trips, hasLength(2));
    });

    test('sets an error state on failure', () async {
      repository.listError = const ApiException(code: 'INTERNAL_ERROR', message: 'boom');

      await provider.loadTrips();

      expect(provider.state, ViewState.error);
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('createTrip', () {
    test('prepends the newly-created trip to the list', () async {
      repository.tripsToReturn = [_trip('t1')];
      await provider.loadTrips();
      repository.createdTrip = _trip('t2');

      final result = await provider.createTrip('Trip t2');

      expect(result?.tripId, 't2');
      expect(provider.trips.map((t) => t.tripId), ['t2', 't1']);
    });

    test('returns null and sets a friendly error message on failure', () async {
      repository.createError = const ApiException(code: 'INVALID_REQUEST', message: 'boom');

      final result = await provider.createTrip('Trip');

      expect(result, isNull);
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('loadTrip', () {
    test('populates currentTrip with its days on success', () async {
      repository.tripDetailToReturn = TripDetailModel(
        tripId: 't1',
        name: 'Trip t1',
        createdAt: DateTime(2026, 1, 1),
        days: [_day('t1', 1), _day('t1', 2)],
      );

      await provider.loadTrip('t1');

      expect(provider.currentTrip?.days, hasLength(2));
      expect(provider.nextDayNumber, 3);
    });

    test('nextDayNumber is 1 when there is no current trip loaded yet', () {
      expect(provider.nextDayNumber, 1);
    });
  });

  group('startBuildingDay / clearActiveDay', () {
    test('records the active trip/day the route planner should save into', () {
      provider.startBuildingDay('t1', 2);

      expect(provider.activeTripId, 't1');
      expect(provider.activeDayNumber, 2);

      provider.clearActiveDay();

      expect(provider.activeTripId, isNull);
      expect(provider.activeDayNumber, isNull);
    });
  });

  group('deleteTrip', () {
    test('removes the trip from the list and clears currentTrip if it matches', () async {
      repository.tripsToReturn = [_trip('t1'), _trip('t2')];
      await provider.loadTrips();
      repository.tripDetailToReturn = TripDetailModel(tripId: 't1', name: 'Trip t1', createdAt: DateTime(2026, 1, 1), days: []);
      await provider.loadTrip('t1');

      final result = await provider.deleteTrip('t1');

      expect(result, isTrue);
      expect(repository.deleteCalls, ['t1']);
      expect(provider.trips.map((t) => t.tripId), ['t2']);
      expect(provider.currentTrip, isNull);
    });

    test('returns false and sets a friendly error message on failure', () async {
      repository.deleteError = const ApiException(code: 'INTERNAL_ERROR', message: 'boom');

      final result = await provider.deleteTrip('t1');

      expect(result, isFalse);
      expect(provider.errorMessage, isNotNull);
    });
  });
}
