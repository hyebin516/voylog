import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/place_model.dart';

void main() {
  group('PlaceModel.fromJson', () {
    test('parses a fully-geocoded place', () {
      final place = PlaceModel.fromJson({
        'placeId': 'p1',
        'name': '해운대해수욕장',
        'timestampSec': 42,
        'latitude': 35.1587,
        'longitude': 129.1603,
        'address': '부산 해운대구',
        'source': 'transcript',
        'confidence': 0.9,
      });

      expect(place.placeId, 'p1');
      expect(place.name, '해운대해수욕장');
      expect(place.timestampSec, 42);
      expect(place.latitude, 35.1587);
      expect(place.longitude, 129.1603);
      expect(place.address, '부산 해운대구');
      expect(place.source, 'transcript');
      expect(place.confidence, 0.9);
      expect(place.hasCoordinates, isTrue);
    });

    test('accepts integer latitude/longitude/confidence (num, not just double)', () {
      final place = PlaceModel.fromJson({
        'placeId': 'p1',
        'name': 'Place',
        'timestampSec': null,
        'latitude': 35,
        'longitude': 129,
        'address': null,
        'source': 'title',
        'confidence': 1,
      });

      expect(place.latitude, 35.0);
      expect(place.longitude, 129.0);
      expect(place.confidence, 1.0);
    });

    test('hasCoordinates is false when geocoding failed (null lat/lng)', () {
      final place = PlaceModel.fromJson({
        'placeId': 'p1',
        'name': 'Unknown Place',
        'timestampSec': null,
        'latitude': null,
        'longitude': null,
        'address': null,
        'source': 'description',
        'confidence': 0.3,
      });

      expect(place.hasCoordinates, isFalse);
      expect(place.latitude, isNull);
      expect(place.longitude, isNull);
      expect(place.address, isNull);
    });
  });
}
