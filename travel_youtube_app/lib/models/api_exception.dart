/// Thrown by repositories when the backend returns
/// `{ "success": false, "error": { "code": "...", "message": "..." } }`.
class ApiException implements Exception {
  final String code;
  final String message;

  const ApiException({required this.code, required this.message});

  /// User-friendly message. Never surface raw exception text to the UI.
  String get friendlyMessage {
    switch (code) {
      case 'TRANSCRIPT_NOT_FOUND':
        return '이 영상에는 자막이 없어 분석할 수 없습니다.';
      case 'INVALID_URL':
        return '유효한 유튜브 URL을 입력해 주세요.';
      case 'JWT_EXPIRED':
      case 'JWT_INVALID':
        return '로그인이 만료되었습니다. 다시 로그인해 주세요.';
      case 'BOOKMARK_EXISTS':
        return '이미 북마크한 장소입니다.';
      case 'HOTEL_NOT_FOUND':
        return '선택한 호텔을 찾을 수 없습니다.';
      case 'EMAIL_EXISTS':
        return '이미 가입된 이메일입니다.';
      case 'OTP_INVALID':
        return '인증번호가 올바르지 않습니다.';
      case 'OTP_EXPIRED':
        return '인증번호가 만료되었습니다. 다시 요청해 주세요.';
      case 'OTP_NOT_VERIFIED':
        return '이메일 인증을 먼저 완료해 주세요.';
      case 'INVALID_CREDENTIALS':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'AI_TIMEOUT':
      case 'AI_PROVIDER_ERROR':
        return 'AI 분석에 실패했습니다. 잠시 후 다시 시도해 주세요.';
      case 'GEOCODING_FAILED':
        return '위치 정보를 가져오지 못했습니다.';
      case 'NETWORK_ERROR':
        return '네트워크 연결을 확인해 주세요.';
      default:
        return '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
  }
}
