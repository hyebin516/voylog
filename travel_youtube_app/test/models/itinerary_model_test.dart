import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/itinerary_model.dart';

void main() {
  group('RoutePointModel', () {
    test('isHotel is true for a hotel point and false for a place point', () {
      final hotelPoint = RoutePointModel.fromJson({
        'order': 0,
        'type': 'hotel',
        'hotelId': 'h1',
        'placeId': null,
        'name': 'Hotel',
        'latitude': 37.5,
        'longitude': 127.0,
      });
      final placePoint = RoutePointModel.fromJson({
        'order': 1,
        'type': 'place',
        'hotelId': null,
        'placeId': 'p1',
        'name': 'Place',
        'latitude': 37.51,
        'longitude': 127.01,
      });

      expect(hotelPoint.isHotel, isTrue);
      expect(placePoint.isHotel, isFalse);
    });

    test('parses legDistanceM/legDurationSec when present, and leaves them null when missing', () {
      final withLeg = RoutePointModel.fromJson({
        'order': 1,
        'type': 'place',
        'hotelId': null,
        'placeId': 'p1',
        'name': 'Place',
        'latitude': 37.51,
        'longitude': 127.01,
        'legDistanceM': 350,
        'legDurationSec': 480,
      });
      final withoutLeg = RoutePointModel.fromJson({
        'order': 0,
        'type': 'hotel',
        'hotelId': 'h1',
        'placeId': null,
        'name': 'Hotel',
        'latitude': 37.5,
        'longitude': 127.0,
      });

      expect(withLeg.legDistanceM, 350);
      expect(withLeg.legDurationSec, 480);
      expect(withoutLeg.legDistanceM, isNull);
      expect(withoutLeg.legDurationSec, isNull);
    });
  });

  group('ItineraryModel.fromJson', () {
    Map<String, dynamic> baseJson({required String startHotelId, required String endHotelId}) => {
          'itineraryId': 'it1',
          'tripId': 'trip1',
          'dayNumber': 1,
          'startHotelId': startHotelId,
          'endHotelId': endHotelId,
          'routeType': startHotelId == endHotelId ? 'roundTrip' : 'hotelToHotel',
          'optimizationPriority': 'duration',
          'transportMode': 'car',
          'totalDistanceM': 1000,
          'totalDurationSec': 600,
          'routeData': [
            {'order': 0, 'type': 'hotel', 'hotelId': startHotelId, 'placeId': null, 'name': 'Start', 'latitude': 37.5, 'longitude': 127.0},
            {'order': 1, 'type': 'place', 'hotelId': null, 'placeId': 'p1', 'name': 'Place', 'latitude': 37.5, 'longitude': 127.0},
            {'order': 2, 'type': 'hotel', 'hotelId': endHotelId, 'placeId': null, 'name': 'End', 'latitude': 37.6, 'longitude': 127.1},
          ],
        };

    test('isRoundTrip is true when startHotelId equals endHotelId', () {
      final itinerary = ItineraryModel.fromJson(baseJson(startHotelId: 'h1', endHotelId: 'h1'));

      expect(itinerary.isRoundTrip, isTrue);
      expect(itinerary.routeType, 'roundTrip');
      expect(itinerary.routeData, hasLength(3));
      expect(itinerary.tripId, 'trip1');
      expect(itinerary.dayNumber, 1);
    });

    test('isRoundTrip is false when startHotelId differs from endHotelId', () {
      final itinerary = ItineraryModel.fromJson(baseJson(startHotelId: 'h1', endHotelId: 'h2'));

      expect(itinerary.isRoundTrip, isFalse);
      expect(itinerary.routeType, 'hotelToHotel');
    });

    test('defaults routeData to an empty list when missing', () {
      final json = baseJson(startHotelId: 'h1', endHotelId: 'h1')..remove('routeData');
      final itinerary = ItineraryModel.fromJson(json);

      expect(itinerary.routeData, isEmpty);
    });

    test('isWalk is true when transportMode is walk, false for car', () {
      final walkJson = baseJson(startHotelId: 'h1', endHotelId: 'h1')..['transportMode'] = 'walk';
      final carJson = baseJson(startHotelId: 'h1', endHotelId: 'h1');

      expect(ItineraryModel.fromJson(walkJson).isWalk, isTrue);
      expect(ItineraryModel.fromJson(carJson).isWalk, isFalse);
    });

    test('defaults transportMode to car when missing', () {
      final json = baseJson(startHotelId: 'h1', endHotelId: 'h1')..remove('transportMode');
      final itinerary = ItineraryModel.fromJson(json);

      expect(itinerary.transportMode, 'car');
      expect(itinerary.isWalk, isFalse);
    });
  });
}
