import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment variables loaded from `.env` at startup (see main.dart).
/// `.env` is git-ignored — copy `.env.example` to `.env` and fill in real
/// values locally. Never hardcode URLs or API keys directly in source.
class Env {
  Env._();

  static const String _defaultApiBaseUrl = 'http://localhost:4000/api/v1';

  static String get apiBaseUrl =>
      dotenv.isInitialized ? dotenv.maybeGet('API_BASE_URL', fallback: _defaultApiBaseUrl)! : _defaultApiBaseUrl;

  /// Kakao JavaScript key, used by kakao_map_plugin for map rendering
  /// (see docs/KAKAO_SETUP.md for why maps need the JS key, not the native key).
  static String get kakaoJavascriptKey => dotenv.isInitialized ? dotenv.maybeGet('KAKAO_JAVASCRIPT_KEY', fallback: '')! : '';

  /// Kakao Native app key, needed once Kakao Login (kakao_flutter_sdk) is integrated.
  /// Not consumed anywhere yet — declared for that future integration.
  static String get kakaoNativeAppKey => dotenv.isInitialized ? dotenv.maybeGet('KAKAO_NATIVE_APP_KEY', fallback: '')! : '';
}
