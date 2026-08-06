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

  test('requestSignupOtp posts the email', () async {
    final adapter = FakeDioAdapter(statusCode: 200, body: {'success': true, 'data': {}});
    DioClient().dio.httpClientAdapter = adapter;

    await AuthRepository().requestSignupOtp('a@b.com');

    expect(adapter.lastOptions?.path, '/auth/signup/request-otp');
    expect(adapter.lastOptions?.data, {'email': 'a@b.com'});
  });

  test('requestSignupOtp surfaces a 409 EMAIL_EXISTS error', () async {
    final adapter = FakeDioAdapter(
      statusCode: 409,
      body: {
        'success': false,
        'error': {'code': 'EMAIL_EXISTS', 'message': 'This email is already registered'},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    await expectLater(
      AuthRepository().requestSignupOtp('a@b.com'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'EMAIL_EXISTS')),
    );
  });

  test('verifySignupOtp posts the email and code', () async {
    final adapter = FakeDioAdapter(statusCode: 200, body: {'success': true, 'data': {}});
    DioClient().dio.httpClientAdapter = adapter;

    await AuthRepository().verifySignupOtp('a@b.com', '123456');

    expect(adapter.lastOptions?.path, '/auth/signup/verify-otp');
    expect(adapter.lastOptions?.data, {'email': 'a@b.com', 'code': '123456'});
  });

  test('signup posts email/password/nickname and maps the response into a UserModel', () async {
    final adapter = FakeDioAdapter(
      statusCode: 201,
      body: {
        'success': true,
        'data': {
          'token': 'jwt-token',
          'user': {'userId': 'u1', 'email': 'a@b.com', 'nickname': 'Nagyeong', 'profileImage': null},
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final user = await AuthRepository().signup(email: 'a@b.com', password: 'password123', nickname: 'Nagyeong');

    expect(user.userId, 'u1');
    expect(adapter.lastOptions?.path, '/auth/signup');
    expect(adapter.lastOptions?.data, {'email': 'a@b.com', 'password': 'password123', 'nickname': 'Nagyeong'});
  });

  test('loginWithEmail posts email/password and maps the response into a UserModel', () async {
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

    final user = await AuthRepository().loginWithEmail('a@b.com', 'password123');

    expect(user.userId, 'u1');
    expect(adapter.lastOptions?.path, '/auth/login');
    expect(adapter.lastOptions?.data, {'email': 'a@b.com', 'password': 'password123'});
  });

  test('loginWithEmail surfaces a 401 INVALID_CREDENTIALS error', () async {
    final adapter = FakeDioAdapter(
      statusCode: 401,
      body: {
        'success': false,
        'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Invalid email or password'},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    await expectLater(
      AuthRepository().loginWithEmail('a@b.com', 'wrong-password'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS')),
    );
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
