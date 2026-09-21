import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../core/config/env.dart';

/// Low-level wrapper around the native Kakao Login SDK. Screens never
/// import `kakao_flutter_sdk_user` directly — they go through this and
/// then hand the resulting access token to `AuthProvider.loginWithKakao`,
/// which calls the backend (POST /auth/kakao) to exchange it for our own JWT.
class KakaoAuthService {
  KakaoAuthService._();

  static Future<void> initialize() async {
    await KakaoSdk.init(nativeAppKey: Env.kakaoNativeAppKey);
  }

  /// Logs in and returns the resulting access token. Throws
  /// [KakaoClientException] with `reason == ClientErrorCause.cancelled`
  /// if the user backs out.
  ///
  /// The SDK's bundled chooser (`loginWithKakao`) is deliberately not used:
  /// it offers "카카오톡으로 로그인" even on a phone without KakaoTalk, and
  /// picking it fails with ACTIVITY_NOT_FOUND instead of falling back, so
  /// every login attempt on such a phone ended in "카카오 로그인에
  /// 실패했습니다". We pick the method ourselves instead -- KakaoTalk when
  /// it's there, the Kakao Account web login otherwise -- and still fall
  /// back to the web login if the KakaoTalk hand-off fails for any reason
  /// other than the user cancelling it.
  static Future<String> login() async {
    if (await isKakaoTalkInstalled()) {
      try {
        final token = await UserApi.instance.loginWithKakaoTalk();
        return token.accessToken;
      } catch (err) {
        if (_isUserCancellation(err)) rethrow;
      }
    }
    final token = await UserApi.instance.loginWithKakaoAccount();
    return token.accessToken;
  }

  /// A cancellation must not be retried with the other method -- the user
  /// backing out of KakaoTalk would immediately get the web login instead.
  static bool _isUserCancellation(Object err) {
    if (err is KakaoClientException) return err.reason == ClientErrorCause.cancelled;
    return err is PlatformException && err.code == 'CANCELED';
  }
}
