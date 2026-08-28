import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/repositories/walking_course_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('generate sends region/localTime and maps the course + recommendations back', () async {
    final localTime = DateTime(2026, 8, 10, 12, 0, 0);
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'course': {
            'routeType': 'roundTrip',
            'optimizationPriority': 'duration',
            'transportMode': 'walk',
            'startPlace': {'order': 0, 'type': 'hotel', 'hotelId': 'region-center', 'placeId': null, 'name': '제주', 'latitude': 33.5, 'longitude': 126.5},
            'endPlace': {'order': 1, 'type': 'hotel', 'hotelId': 'region-center', 'placeId': null, 'name': '제주', 'latitude': 33.5, 'longitude': 126.5},
            'optimizedRoute': [
              {'order': 0, 'type': 'hotel', 'hotelId': 'region-center', 'placeId': null, 'name': '제주', 'latitude': 33.5, 'longitude': 126.5},
            ],
            'totalDistanceM': 500,
            'totalDurationSec': 400,
          },
          'recommendations': [
            {
              'placeId': 'p1',
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
            },
          ],
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final result = await WalkingCourseRepository().generate(region: '제주', localTime: localTime);

    expect(adapter.lastOptions?.path, '/recommendations/walking-course');
    expect(adapter.lastOptions?.data, {
      'region': '제주',
      'localTime': localTime.toIso8601String(),
    });
    expect(result.course, isNotNull);
    expect(result.course!.transportMode, 'walk');
    expect(result.recommendations, hasLength(1));
    expect(result.recommendations.first.name, '흑돼지집');
  });

  test('generate maps a null course when the region had too few walkable places', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'course': null, 'recommendations': []},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final result = await WalkingCourseRepository().generate(region: '어딘가', localTime: DateTime(2026, 1, 1));

    expect(result.course, isNull);
    expect(result.recommendations, isEmpty);
  });
}
