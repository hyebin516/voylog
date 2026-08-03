import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/hotel_model.dart';

void main() {
  group('HotelModel', () {
    test('fromJson parses all fields', () {
      final hotel = HotelModel.fromJson({
        'hotelId': 'h1',
        'name': 'Grand Hotel',
        'address': 'Seoul',
        'latitude': 37.5,
        'longitude': 127.0,
      });

      expect(hotel.hotelId, 'h1');
      expect(hotel.name, 'Grand Hotel');
      expect(hotel.address, 'Seoul');
      expect(hotel.latitude, 37.5);
      expect(hotel.longitude, 127.0);
    });

    test('fromJson accepts integer lat/lng', () {
      final hotel = HotelModel.fromJson({
        'hotelId': 'h1',
        'name': 'Hotel',
        'address': 'addr',
        'latitude': 37,
        'longitude': 127,
      });

      expect(hotel.latitude, 37.0);
      expect(hotel.longitude, 127.0);
    });

    test('toCreateJson omits hotelId (server assigns it) and includes only the writable fields', () {
      const hotel = HotelModel(hotelId: 'h1', name: 'Grand Hotel', address: 'Seoul', latitude: 37.5, longitude: 127.0);

      final json = hotel.toCreateJson();

      expect(json, {
        'name': 'Grand Hotel',
        'address': 'Seoul',
        'latitude': 37.5,
        'longitude': 127.0,
      });
      expect(json.containsKey('hotelId'), isFalse);
    });
  });
}
