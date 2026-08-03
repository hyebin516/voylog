import 'package:flutter/widgets.dart';
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

  /// Shows Kakao's bundled chooser (KakaoTalk app vs. Kakao Account web
  /// login) and returns the resulting access token. Throws
  /// [KakaoClientException] with `reason == ClientErrorCause.cancelled`
  /// if the user dismisses the chooser.
  static Future<String> login(BuildContext context) async {
    final token = await UserApi.instance.loginWithKakao(context);
    return token.accessToken;
  }
}
