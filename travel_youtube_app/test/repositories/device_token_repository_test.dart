import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/repositories/device_token_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('register posts the token and platform', () async {
    final adapter = FakeDioAdapter(statusCode: 201, body: {
      'success': true,
      'data': {'registered': true},
    });
    DioClient().dio.httpClientAdapter = adapter;

    await DeviceTokenRepository().register('fcm-token', 'android');

    expect(adapter.lastOptions?.path, '/device-tokens');
    expect(adapter.lastOptions?.method, 'POST');
    expect(adapter.lastOptions?.data, {'token': 'fcm-token', 'platform': 'android'});
  });

  test('unregister deletes the token, escaped for the URL', () async {
    final adapter = FakeDioAdapter(statusCode: 204, body: const {});
    DioClient().dio.httpClientAdapter = adapter;

    // Real FCM tokens contain ':' and can contain '/'.
    await DeviceTokenRepository().unregister('abc:def/ghi');

    expect(adapter.lastOptions?.method, 'DELETE');
    expect(adapter.lastOptions?.path, '/device-tokens/abc%3Adef%2Fghi');
  });

  test('turns a backend error into an ApiException', () async {
    DioClient().dio.httpClientAdapter = FakeDioAdapter(statusCode: 401, body: {
      'success': false,
      'error': {'code': 'JWT_INVALID', 'message': 'no'},
    });

    expect(
      () => DeviceTokenRepository().register('fcm-token', 'android'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'JWT_INVALID')),
    );
  });
}
