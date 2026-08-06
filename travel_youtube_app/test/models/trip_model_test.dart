import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/trip_model.dart';

void main() {
  group('TripModel.fromJson', () {
    test('parses a trip summary with its day count', () {
      final trip = TripModel.fromJson({
        'tripId': 't1',
        'name': '제주도 여행',
        'dayCount': 2,
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(trip.tripId, 't1');
      expect(trip.name, '제주도 여행');
      expect(trip.dayCount, 2);
    });
  });

  group('TripDetailModel.fromJson', () {
    test('parses the trip with its days ordered as returned', () {
      final trip = TripDetailModel.fromJson({
        'tripId': 't1',
        'name': '제주도 여행',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'days': [
          {
            'itineraryId': 'it1',
            'tripId': 't1',
            'dayNumber': 1,
            'startHotelId': 'h1',
            'endHotelId': 'h2',
            'routeType': 'hotelToHotel',
            'optimizationPriority': 'duration',
            'totalDistanceM': 1000,
            'totalDurationSec': 600,
            'routeData': [],
          },
        ],
      });

      expect(trip.days, hasLength(1));
      expect(trip.days.first.dayNumber, 1);
      expect(trip.days.first.tripId, 't1');
    });

    test('defaults days to an empty list when missing', () {
      final trip = TripDetailModel.fromJson({
        'tripId': 't1',
        'name': '제주도 여행',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(trip.days, isEmpty);
    });
  });
}
