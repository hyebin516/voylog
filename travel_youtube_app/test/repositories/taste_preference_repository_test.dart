import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/repositories/taste_preference_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('getPreferences maps the JSON response into a TastePreferenceModel', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'tags': ['소금빵', '오션뷰'],
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final preferences = await TastePreferenceRepository().getPreferences();

    expect(preferences.tags, ['소금빵', '오션뷰']);
    expect(adapter.lastOptions?.path, '/taste-preferences');
    expect(adapter.lastOptions?.method, 'GET');
  });

  test('setPreferences sends the tags array and maps the saved response', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'tags': ['소금빵'],
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final preferences = await TastePreferenceRepository().setPreferences(['소금빵']);

    expect(preferences.tags, ['소금빵']);
    expect(adapter.lastOptions?.path, '/taste-preferences');
    expect(adapter.lastOptions?.method, 'PUT');
    expect(adapter.lastOptions?.data, {
      'tags': ['소금빵'],
    });
  });

  test('clearPreferences calls DELETE /taste-preferences', () async {
    final adapter = FakeDioAdapter(statusCode: 204, body: const {});
    DioClient().dio.httpClientAdapter = adapter;

    await TastePreferenceRepository().clearPreferences();

    expect(adapter.lastOptions?.path, '/taste-preferences');
    expect(adapter.lastOptions?.method, 'DELETE');
  });

  test('a 401 error response is surfaced as an ApiException', () async {
    final adapter = FakeDioAdapter(
      statusCode: 401,
      body: {
        'success': false,
        'error': {'code': 'JWT_INVALID', 'message': 'Authorization header is missing or malformed'},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    await expectLater(
      TastePreferenceRepository().getPreferences(),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'JWT_INVALID')),
    );
  });
}
