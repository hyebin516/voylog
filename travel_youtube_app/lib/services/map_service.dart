import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/config/env.dart';

/// Low-level bootstrap for the Kakao Maps SDK. Must be called once before
/// any `KakaoMapWidget` is built (call from main() before runApp()).
class MapService {
  MapService._();

  static void initialize() {
    // `baseUrl` becomes the WebView's origin when kakao_map_plugin loads its
    // local HTML (see docs/KAKAO_SETUP.md's "지도가 안 뜨는 경우" section) --
    // without it, the SDK script loads from a blank/originless page, which
    // Kakao's CDN can reject as "kakao is not defined" at runtime. This
    // value must exactly match a JavaScript SDK domain registered on the
    // JavaScript key in Kakao Developers (앱 > 플랫폼 키 > JavaScript 키 >
    // JavaScript SDK 도메인) -- currently registered as localhost:5000.
    AuthRepository.initialize(appKey: Env.kakaoJavascriptKey, baseUrl: 'http://localhost:5000');

    _enableWebViewDebuggingInDebugBuilds();
  }

  /// Lets a desktop Chrome attach to the map's WebView via chrome://inspect.
  ///
  /// The map is a WebView, and when it fails it fails silently -- no error
  /// reaches logcat, so the only way to see which request was refused is to
  /// open its devtools. Restricting the app's cleartext traffic went three
  /// rounds of guesswork for exactly this reason (docs/DEPLOYMENT.md).
  ///
  /// Debug builds only: this exposes the WebView's contents to anything on
  /// the machine, which has no business being true in a shipped app.
  static void _enableWebViewDebuggingInDebugBuilds() {
    if (!kDebugMode || !Platform.isAndroid) return;
    AndroidWebViewController.enableDebugging(true);
  }
}
