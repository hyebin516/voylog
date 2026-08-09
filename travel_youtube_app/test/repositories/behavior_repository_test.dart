import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/repositories/behavior_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('record posts placeId/action/screen/distanceMeters', () async {
    final adapter = FakeDioAdapter(statusCode: 204, body: {});
    DioClient().dio.httpClientAdapter = adapter;

    await BehaviorRepository().record(placeId: 'p1', action: 'bookmark', screen: 'nearby', distanceMeters: 150);

    expect(adapter.lastOptions?.path, '/recommendations/behaviors');
    expect(adapter.lastOptions?.data['placeId'], 'p1');
    expect(adapter.lastOptions?.data['action'], 'bookmark');
    expect(adapter.lastOptions?.data['screen'], 'nearby');
    expect(adapter.lastOptions?.data['distanceMeters'], 150);
  });

  test('omits screen/distanceMeters when not provided', () async {
    final adapter = FakeDioAdapter(statusCode: 204, body: {});
    DioClient().dio.httpClientAdapter = adapter;

    await BehaviorRepository().record(placeId: 'p1', action: 'view_detail');

    expect(adapter.lastOptions?.data.containsKey('screen'), isFalse);
    expect(adapter.lastOptions?.data.containsKey('distanceMeters'), isFalse);
  });

  test('a 400 error response is surfaced as an ApiException', () async {
    final adapter = FakeDioAdapter(
      statusCode: 400,
      body: {
        'success': false,
        'error': {'code': 'INVALID_REQUEST', 'message': 'action must be one of: ...'},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    await expectLater(
      BehaviorRepository().record(placeId: 'p1', action: 'bookmark'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_REQUEST')),
    );
  });
}
