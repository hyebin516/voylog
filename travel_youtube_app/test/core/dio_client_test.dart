import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/models/api_exception.dart';

/// Builds the DioException an interceptor would see for a given response.
DioException _responseError({int? statusCode, Object? body}) {
  final request = RequestOptions(path: '/api/v1/auth/login');
  return DioException(
    requestOptions: request,
    response: statusCode == null
        ? null
        : Response<Object?>(requestOptions: request, statusCode: statusCode, data: body),
    type: statusCode == null ? DioExceptionType.connectionError : DioExceptionType.badResponse,
  );
}

ApiException _run(DioClient client, DioException error) {
  // ignore: invalid_use_of_visible_for_testing_member
  return client.normalizeForTest(error).error as ApiException;
}

void main() {
  late DioClient client;
  late int unauthorizedCalls;

  setUp(() {
    client = DioClient();
    unauthorizedCalls = 0;
    client.onUnauthorized = () => unauthorizedCalls++;
  });

  tearDown(() => client.onUnauthorized = null);

  group('a 401 that is about the request, not the session', () {
    test('a wrong password keeps the user logged in', () {
      // Changing a password with the wrong current one answers 401
      // INVALID_CREDENTIALS. Treating that as a lost session logged the
      // user out of the app for a typo.
      final result = _run(
        client,
        _responseError(
          statusCode: 401,
          body: {
            'success': false,
            'error': {'code': 'INVALID_CREDENTIALS', 'message': 'nope'},
          },
        ),
      );

      expect(result.code, 'INVALID_CREDENTIALS');
      expect(result.friendlyMessage, '이메일 또는 비밀번호가 올바르지 않습니다.');
      expect(unauthorizedCalls, 0);
    });
  });

  group('a session that has gone bad', () {
    test('an invalid token drops the session', () {
      final result = _run(
        client,
        _responseError(
          statusCode: 401,
          body: {
            'success': false,
            'error': {'code': 'JWT_INVALID', 'message': 'bad token'},
          },
        ),
      );

      expect(result.code, 'JWT_INVALID');
      expect(unauthorizedCalls, 1);
    });

    test('an expired token drops the session', () {
      _run(
        client,
        _responseError(
          statusCode: 403,
          body: {
            'success': false,
            'error': {'code': 'JWT_EXPIRED', 'message': 'expired'},
          },
        ),
      );

      expect(unauthorizedCalls, 1);
    });

    test('a bare 401 with no readable body still drops the session', () {
      // Nothing to read means the app cannot tell why it was refused, and
      // a refused request with a stored token is most likely the session.
      _run(client, _responseError(statusCode: 401, body: 'Unauthorized'));

      expect(unauthorizedCalls, 1);
    });
  });

  group('failures that never reached the server', () {
    test('no response at all reads as a network error', () {
      final result = _run(client, _responseError());

      expect(result.code, 'NETWORK_ERROR');
      expect(result.friendlyMessage, '네트워크 연결을 확인해 주세요.');
      expect(unauthorizedCalls, 0);
    });

    test('a 500 with no body is not a session problem', () {
      final result = _run(client, _responseError(statusCode: 500, body: 'oops'));

      expect(result.code, 'INTERNAL_ERROR');
      expect(unauthorizedCalls, 0);
    });
  });
}
