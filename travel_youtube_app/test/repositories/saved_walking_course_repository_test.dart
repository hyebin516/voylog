import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/models/itinerary_model.dart';
import 'package:travel_youtube_app/models/walking_course_model.dart';
import 'package:travel_youtube_app/repositories/saved_walking_course_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

const _route = WalkingCourseRouteModel(
  routeType: 'roundTrip',
  transportMode: 'walk',
  totalDistanceM: 2119,
  totalDurationSec: 1897,
  routeData: [
    RoutePointModel(order: 0, type: 'hotel', hotelId: 'region-center', placeId: null, name: '제주', latitude: 33.5, longitude: 126.5),
    RoutePointModel(order: 1, type: 'place', hotelId: null, placeId: 'p1', name: '흑돼지집', latitude: 33.51, longitude: 126.51, legDistanceM: 900, legDurationSec: 720),
  ],
);

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('save posts region and the flattened course, and maps the saved course back', () async {
    final adapter = FakeDioAdapter(
      statusCode: 201,
      body: {
        'success': true,
        'data': {
          'savedCourseId': 'sc1',
          'region': '제주',
          'routeType': 'roundTrip',
          'transportMode': 'walk',
          'totalDistanceM': 2119,
          'totalDurationSec': 1897,
          'routeData': [
            {'order': 0, 'type': 'hotel', 'hotelId': 'region-center', 'placeId': null, 'name': '제주', 'latitude': 33.5, 'longitude': 126.5},
          ],
          'createdAt': '2026-08-28T12:00:00.000Z',
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final saved = await SavedWalkingCourseRepository().save(region: '제주', course: _route);

    expect(adapter.lastOptions?.path, '/walking-courses');
    expect(adapter.lastOptions?.data['region'], '제주');
    expect(adapter.lastOptions?.data['routeType'], 'roundTrip');
    expect(adapter.lastOptions?.data['transportMode'], 'walk');
    expect(adapter.lastOptions?.data['totalDistanceM'], 2119);
    expect((adapter.lastOptions?.data['routeData'] as List).length, 2);
    expect((adapter.lastOptions?.data['routeData'] as List).first, {
      'order': 0,
      'type': 'hotel',
      'hotelId': 'region-center',
      'placeId': null,
      'name': '제주',
      'latitude': 33.5,
      'longitude': 126.5,
      'legDistanceM': null,
      'legDurationSec': null,
    });
    // Each stop's travel time is saved with it -- it used to be dropped, so a
    // saved course showed no time between stops.
    expect((adapter.lastOptions?.data['routeData'] as List)[1], containsPair('legDurationSec', 720));
    expect((adapter.lastOptions?.data['routeData'] as List)[1], containsPair('legDistanceM', 900));
    expect(saved.savedCourseId, 'sc1');
  });

  test('list maps the JSON savedCourses array', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'savedCourses': [
            {
              'savedCourseId': 'sc1',
              'region': '제주',
              'routeType': 'roundTrip',
              'transportMode': 'walk',
              'totalDistanceM': 2119,
              'totalDurationSec': 1897,
              'routeData': [],
              'createdAt': '2026-08-28T12:00:00.000Z',
            },
          ],
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final courses = await SavedWalkingCourseRepository().list();

    expect(adapter.lastOptions?.path, '/walking-courses');
    expect(courses, hasLength(1));
    expect(courses.first.region, '제주');
  });

  test('delete calls DELETE /walking-courses/:id', () async {
    final adapter = FakeDioAdapter(statusCode: 204, body: {});
    DioClient().dio.httpClientAdapter = adapter;

    await SavedWalkingCourseRepository().delete('sc1');

    expect(adapter.lastOptions?.path, '/walking-courses/sc1');
    expect(adapter.lastOptions?.method, 'DELETE');
  });
}
