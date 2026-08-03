import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('loginWithKakao maps the response into a UserModel', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'token': 'jwt-token',
          'user': {'userId': 'u1', 'email': 'a@b.com', 'nickname': 'Nagyeong', 'profileImage': null},
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final user = await AuthRepository().loginWithKakao('kakao-token');

    expect(user.userId, 'u1');
    expect(adapter.lastOptions?.path, '/auth/kakao');
    expect(adapter.lastOptions?.data, {'kakaoAccessToken': 'kakao-token'});
  });

  test('fetchProfile maps the response into a UserModel', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'userId': 'u1', 'email': 'a@b.com', 'nickname': 'Nagyeong', 'profileImage': null},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final user = await AuthRepository().fetchProfile();

    expect(user.userId, 'u1');
    expect(adapter.lastOptions?.path, '/auth/profile');
    expect(adapter.lastOptions?.method, 'GET');
  });

  test('deleteAccount calls DELETE /auth/profile and then clears the local session', () async {
    final adapter = FakeDioAdapter(statusCode: 204, body: const {});
    DioClient().dio.httpClientAdapter = adapter;

    await AuthRepository().deleteAccount();

    expect(adapter.lastOptions?.path, '/auth/profile');
    expect(adapter.lastOptions?.method, 'DELETE');
  });

  test('deleteAccount surfaces the backend error and does not clear the local session', () async {
    final adapter = FakeDioAdapter(
      statusCode: 401,
      body: {
        'success': false,
        'error': {'code': 'JWT_EXPIRED', 'message': 'JWT has expired'},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    await expectLater(
      AuthRepository().deleteAccount(),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'JWT_EXPIRED')),
    );
  });
}
