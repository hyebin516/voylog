import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/repositories/similar_taste_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('getRecommendations maps hasPreference and the recommendation list', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'hasPreference': true,
          'recommendations': [
            {
              'placeId': 'p1',
              'name': '흑돼지집',
              'latitude': 33.51,
              'longitude': 126.51,
              'category': 'restaurant',
              'score': 1.6,
              'contributorCount': 2,
              'reason': '취향이 비슷한 사용자 2명이 북마크한 곳이에요.',
            },
          ],
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final result = await SimilarTasteRepository().getRecommendations();

    expect(adapter.lastOptions?.path, '/recommendations/similar-taste');
    expect(result.hasPreference, isTrue);
    expect(result.recommendations, hasLength(1));
    expect(result.recommendations.first.name, '흑돼지집');
  });

  test('getRecommendations omits limit from query params when not provided', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'hasPreference': false, 'recommendations': []},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    await SimilarTasteRepository().getRecommendations();

    expect(adapter.lastOptions?.queryParameters.containsKey('limit'), isFalse);
  });

  test('getRecommendations includes limit when provided', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'hasPreference': false, 'recommendations': []},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    await SimilarTasteRepository().getRecommendations(limit: 5);

    expect(adapter.lastOptions?.queryParameters['limit'], 5);
  });
}
