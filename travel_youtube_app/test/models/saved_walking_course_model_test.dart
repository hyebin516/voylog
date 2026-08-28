import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/saved_walking_course_model.dart';

Map<String, dynamic> _json({String routeType = 'roundTrip'}) => {
      'savedCourseId': 'sc1',
      'region': '제주',
      'routeType': routeType,
      'transportMode': 'walk',
      'totalDistanceM': 2119,
      'totalDurationSec': 1897,
      'routeData': [
        {'order': 0, 'type': 'hotel', 'hotelId': 'region-center', 'placeId': null, 'name': '제주', 'latitude': 33.5, 'longitude': 126.5},
        {'order': 1, 'type': 'place', 'hotelId': null, 'placeId': 'p1', 'name': '흑돼지집', 'latitude': 33.51, 'longitude': 126.51},
      ],
      'createdAt': '2026-08-28T12:00:00.000Z',
    };

void main() {
  group('SavedWalkingCourseModel.fromJson', () {
    test('parses all fields', () {
      final course = SavedWalkingCourseModel.fromJson(_json());

      expect(course.savedCourseId, 'sc1');
      expect(course.region, '제주');
      expect(course.transportMode, 'walk');
      expect(course.totalDistanceM, 2119);
      expect(course.totalDurationSec, 1897);
      expect(course.routeData, hasLength(2));
      expect(course.routeData[1].name, '흑돼지집');
      expect(course.createdAt, DateTime.parse('2026-08-28T12:00:00.000Z'));
    });

    test('isRoundTrip is true when routeType is roundTrip', () {
      expect(SavedWalkingCourseModel.fromJson(_json(routeType: 'roundTrip')).isRoundTrip, isTrue);
      expect(SavedWalkingCourseModel.fromJson(_json(routeType: 'hotelToHotel')).isRoundTrip, isFalse);
    });

    test('defaults routeData to an empty list when missing', () {
      final json = _json()..remove('routeData');
      expect(SavedWalkingCourseModel.fromJson(json).routeData, isEmpty);
    });
  });
}
