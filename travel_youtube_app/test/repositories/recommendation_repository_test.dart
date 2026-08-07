import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/repositories/recommendation_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('getNearby posts latitude/longitude/localTime and maps the recommendations', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'recommendations': [
            {
              'placeId': 'p1',
              'name': 'Place 1',
              'latitude': 37.5,
              'longitude': 127.0,
              'distanceMeters': 420,
              'category': 'cafe',
              'isOpen': true,
              'isOpenEstimated': true,
              'score': 0.87,
              'reason': '현재 위치에서 420m 떨어져 있어요.',
            },
          ],
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final localTime = DateTime(2026, 8, 10, 12, 0, 0);
    final results = await RecommendationRepository().getNearby(latitude: 37.5, longitude: 127.0, localTime: localTime);

    expect(results, hasLength(1));
    expect(results.first.placeId, 'p1');
    expect(adapter.lastOptions?.path, '/recommendations/nearby');
    expect(adapter.lastOptions?.data['latitude'], 37.5);
    expect(adapter.lastOptions?.data['localTime'], localTime.toIso8601String());
    expect(adapter.lastOptions?.data.containsKey('radiusMeters'), isFalse);
  });

  test('getNearby includes radiusMeters/limit only when provided', () async {
    final adapter = FakeDioAdapter(statusCode: 200, body: {'success': true, 'data': {'recommendations': []}});
    DioClient().dio.httpClientAdapter = adapter;

    await RecommendationRepository().getNearby(
      latitude: 37.5,
      longitude: 127.0,
      localTime: DateTime(2026, 8, 10, 12, 0, 0),
      radiusMeters: 1000,
      limit: 5,
    );

    expect(adapter.lastOptions?.data['radiusMeters'], 1000);
    expect(adapter.lastOptions?.data['limit'], 5);
  });

  test('a 400 error response is surfaced as an ApiException', () async {
    final adapter = FakeDioAdapter(
      statusCode: 400,
      body: {
        'success': false,
        'error': {'code': 'INVALID_REQUEST', 'message': 'A valid latitude is required'},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    await expectLater(
      RecommendationRepository().getNearby(latitude: 37.5, longitude: 127.0, localTime: DateTime(2026, 8, 10)),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_REQUEST')),
    );
  });
}
