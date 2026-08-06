import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/repositories/itinerary_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('createItinerary sends tripId/dayNumber/startHotelId/endHotelId/placeIds and maps the optimized route back', () async {
    final adapter = FakeDioAdapter(
      statusCode: 201,
      body: {
        'success': true,
        'data': {
          'itineraryId': 'it1',
          'tripId': 'trip1',
          'dayNumber': 1,
          'startHotelId': 'h1',
          'endHotelId': 'h1',
          'routeType': 'roundTrip',
          'optimizationPriority': 'duration',
          'totalDistanceM': 1000,
          'totalDurationSec': 600,
          'routeData': [
            {'order': 0, 'type': 'hotel', 'hotelId': 'h1', 'placeId': null, 'name': 'Hotel', 'latitude': 37.5, 'longitude': 127.0},
          ],
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final itinerary = await ItineraryRepository().createItinerary(
      tripId: 'trip1',
      dayNumber: 1,
      startHotelId: 'h1',
      endHotelId: 'h1',
      placeIds: ['p1', 'p2'],
    );

    expect(itinerary.isRoundTrip, isTrue);
    expect(itinerary.tripId, 'trip1');
    expect(itinerary.dayNumber, 1);
    expect(itinerary.routeData, hasLength(1));
    expect(adapter.lastOptions?.path, '/itineraries');
    expect(adapter.lastOptions?.data, {
      'tripId': 'trip1',
      'dayNumber': 1,
      'startHotelId': 'h1',
      'endHotelId': 'h1',
      'placeIds': ['p1', 'p2'],
    });
  });
}
