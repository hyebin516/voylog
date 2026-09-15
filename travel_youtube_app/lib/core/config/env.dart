import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment variables loaded from `.env` at startup (see main.dart).
/// `.env` is git-ignored — copy `.env.example` to `.env` and fill in real
/// values locally. Never hardcode URLs or API keys directly in source.
class Env {
  Env._();

  static const String _defaultApiBaseUrl = 'http://localhost:4000/api/v1';
  static const String _defaultYoutubeEmbedOrigin = 'https://voylog.app';

  static String get apiBaseUrl => dotenv.isInitialized
      ? dotenv.maybeGet('API_BASE_URL', fallback: _defaultApiBaseUrl)!
      : _defaultApiBaseUrl;

  /// Kakao JavaScript key, used by kakao_map_plugin for map rendering
  /// (see docs/KAKAO_SETUP.md for why maps need the JS key, not the native key).
  static String get kakaoJavascriptKey => dotenv.isInitialized
      ? dotenv.maybeGet('KAKAO_JAVASCRIPT_KEY', fallback: '')!
      : '';

  /// Kakao Native app key, needed once Kakao Login (kakao_flutter_sdk) is integrated.
  /// Not consumed anywhere yet — declared for that future integration.
  static String get kakaoNativeAppKey => dotenv.isInitialized
      ? dotenv.maybeGet('KAKAO_NATIVE_APP_KEY', fallback: '')!
      : '';

  /// Origin the embedded YouTube player page claims to be served from. It is
  /// never fetched -- it only becomes the page's origin and the Referer
  /// YouTube sees. It must be an ordinary https site: youtube_player_iframe
  /// defaults to https://www.youtube.com, and YouTube now refuses embeds
  /// claiming its own origin (error 152-4, "This video is unavailable"),
  /// which left every video as a blank player.
  static String get youtubeEmbedOrigin => dotenv.isInitialized
      ? dotenv.maybeGet(
          'YOUTUBE_EMBED_ORIGIN',
          fallback: _defaultYoutubeEmbedOrigin,
        )!
      : _defaultYoutubeEmbedOrigin;
}
