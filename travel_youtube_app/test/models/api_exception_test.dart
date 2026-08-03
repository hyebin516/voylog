import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';

void main() {
  group('ApiException.friendlyMessage', () {
    const cases = {
      'TRANSCRIPT_NOT_FOUND': '이 영상에는 자막이 없어 분석할 수 없습니다.',
      'INVALID_URL': '유효한 유튜브 URL을 입력해 주세요.',
      'JWT_EXPIRED': '로그인이 만료되었습니다. 다시 로그인해 주세요.',
      'JWT_INVALID': '로그인이 만료되었습니다. 다시 로그인해 주세요.',
      'BOOKMARK_EXISTS': '이미 북마크한 장소입니다.',
      'HOTEL_NOT_FOUND': '선택한 호텔을 찾을 수 없습니다.',
      'AI_TIMEOUT': 'AI 분석에 실패했습니다. 잠시 후 다시 시도해 주세요.',
      'AI_PROVIDER_ERROR': 'AI 분석에 실패했습니다. 잠시 후 다시 시도해 주세요.',
      'GEOCODING_FAILED': '위치 정보를 가져오지 못했습니다.',
      'NETWORK_ERROR': '네트워크 연결을 확인해 주세요.',
    };

    cases.forEach((code, expected) {
      test('maps $code to a Korean user-facing message', () {
        expect(ApiException(code: code, message: 'raw').friendlyMessage, expected);
      });
    });

    test('never surfaces the raw backend message for a known code', () {
      const exception = ApiException(code: 'BOOKMARK_EXISTS', message: 'raw internal detail');
      expect(exception.friendlyMessage, isNot(contains('raw internal detail')));
    });

    test('falls back to a generic message for an unrecognized code', () {
      const exception = ApiException(code: 'SOME_NEW_BACKEND_CODE', message: 'raw');
      expect(exception.friendlyMessage, '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    });
  });
}
