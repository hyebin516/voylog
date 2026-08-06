import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/repositories/trip_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('createTrip posts the name and maps the created trip (dayCount starts at 0)', () async {
    final adapter = FakeDioAdapter(
      statusCode: 201,
      body: {
        'success': true,
        'data': {'tripId': 't1', 'name': '제주도 여행', 'createdAt': '2026-01-01T00:00:00.000Z'},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final trip = await TripRepository().createTrip('제주도 여행');

    expect(trip.tripId, 't1');
    expect(trip.dayCount, 0);
    expect(adapter.lastOptions?.path, '/trips');
    expect(adapter.lastOptions?.data, {'name': '제주도 여행'});
  });

  test('listTrips maps the JSON trips array', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'trips': [
            {'tripId': 't1', 'name': '제주도 여행', 'dayCount': 2, 'createdAt': '2026-01-01T00:00:00.000Z'},
          ],
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final trips = await TripRepository().listTrips();

    expect(trips, hasLength(1));
    expect(trips.first.dayCount, 2);
    expect(adapter.lastOptions?.path, '/trips');
    expect(adapter.lastOptions?.method, 'GET');
  });

  test('getTrip maps the trip detail including its days', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'tripId': 't1',
          'name': '제주도 여행',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'days': [
            {
              'itineraryId': 'it1',
              'tripId': 't1',
              'dayNumber': 1,
              'startHotelId': 'h1',
              'endHotelId': 'h1',
              'routeType': 'roundTrip',
              'optimizationPriority': 'duration',
              'totalDistanceM': 1000,
              'totalDurationSec': 600,
              'routeData': [],
            },
          ],
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final trip = await TripRepository().getTrip('t1');

    expect(trip.days, hasLength(1));
    expect(adapter.lastOptions?.path, '/trips/t1');
  });

  test('deleteTrip calls DELETE /trips/:id', () async {
    final adapter = FakeDioAdapter(statusCode: 204, body: const {});
    DioClient().dio.httpClientAdapter = adapter;

    await TripRepository().deleteTrip('t1');

    expect(adapter.lastOptions?.path, '/trips/t1');
    expect(adapter.lastOptions?.method, 'DELETE');
  });
}
