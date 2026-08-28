import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/walking_course_model.dart';

Map<String, dynamic> _routeJson({required String routeType, required String transportMode}) => {
      'routeType': routeType,
      'optimizationPriority': 'duration',
      'transportMode': transportMode,
      'startPlace': {'order': 0, 'type': 'hotel', 'hotelId': 'region-center', 'placeId': null, 'name': '제주', 'latitude': 33.5, 'longitude': 126.5},
      'endPlace': {'order': 2, 'type': 'hotel', 'hotelId': 'region-center', 'placeId': null, 'name': '제주', 'latitude': 33.5, 'longitude': 126.5},
      'optimizedRoute': [
        {'order': 0, 'type': 'hotel', 'hotelId': 'region-center', 'placeId': null, 'name': '제주', 'latitude': 33.5, 'longitude': 126.5},
        {'order': 1, 'type': 'place', 'hotelId': null, 'placeId': 'p1', 'name': '흑돼지집', 'latitude': 33.51, 'longitude': 126.51},
        {'order': 2, 'type': 'hotel', 'hotelId': 'region-center', 'placeId': null, 'name': '제주', 'latitude': 33.5, 'longitude': 126.5},
      ],
      'totalDistanceM': 1800,
      'totalDurationSec': 1500,
    };

Map<String, dynamic> _recommendationJson(String placeId) => {
      'placeId': placeId,
      'name': '흑돼지집',
      'latitude': 33.51,
      'longitude': 126.51,
      'distanceMeters': 300,
      'category': 'restaurant',
      'isOpen': true,
      'isOpenEstimated': true,
      'score': 0.8,
      'matchedTags': ['흑돼지'],
      'reason': '취향에 맞는 곳이에요.',
    };

void main() {
  group('WalkingCourseRouteModel.fromJson', () {
    test('isRoundTrip is true when routeType is roundTrip', () {
      final route = WalkingCourseRouteModel.fromJson(_routeJson(routeType: 'roundTrip', transportMode: 'walk'));

      expect(route.isRoundTrip, isTrue);
      expect(route.transportMode, 'walk');
      expect(route.totalDistanceM, 1800);
      expect(route.totalDurationSec, 1500);
      expect(route.routeData, hasLength(3));
      expect(route.routeData[1].name, '흑돼지집');
    });
  });

  group('WalkingCourseModel.fromJson', () {
    test('parses a populated course with its recommendations', () {
      final model = WalkingCourseModel.fromJson({
        'course': _routeJson(routeType: 'roundTrip', transportMode: 'walk'),
        'recommendations': [_recommendationJson('p1')],
      });

      expect(model.course, isNotNull);
      expect(model.course!.routeData, hasLength(3));
      expect(model.recommendations, hasLength(1));
      expect(model.recommendations.first.placeId, 'p1');
    });

    test('course is null when the region had too few mutually-walkable places', () {
      final model = WalkingCourseModel.fromJson({
        'course': null,
        'recommendations': [_recommendationJson('p1')],
      });

      expect(model.course, isNull);
      expect(model.recommendations, hasLength(1));
    });

    test('recommendations defaults to an empty list when missing', () {
      final model = WalkingCourseModel.fromJson({'course': null});

      expect(model.recommendations, isEmpty);
    });
  });
}
