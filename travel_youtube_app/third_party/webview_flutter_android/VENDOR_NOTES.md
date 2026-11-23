# Why this package is vendored

Local copy of `webview_flutter_android` 4.13.0 (from pub.dev) with one patch.
`example/`, `test/` and `pigeons/` were dropped to keep the repository small.
`travel_youtube_app/pubspec.yaml` points here through `dependency_overrides`,
so `youtube_player_iframe` and `kakao_map_plugin` (which both depend on
`webview_flutter`) also use this copy.

## The patch

`android/src/main/java/io/flutter/plugins/webviewflutter/WebViewClientProxyApi.java`:
`WebViewClientImpl` overrides `onRenderProcessGone` and returns `true`.

When Android kills a WebView's renderer process -- usually to reclaim memory
-- and the app's `WebViewClient` does not claim it, Android kills the whole
app. Upstream never overrides it. On the test phone (Galaxy A7, 3GB RAM)
crashing the YouTube player's renderer (DevTools `Page.crash`, 2026-11-23)
closed Voylog outright.

Claiming it keeps the app alive with a dead WebView. The YouTube player
notices (its JavaScript health check stops answering, see `_PlayerLoader` in
`lib/repositories/video_player_repository.dart`) and replaces the WebView.

## How to remove this vendored copy later

Once upstream handles `onRenderProcessGone` (check the changelog at
https://pub.dev/packages/webview_flutter_android/changelog):

1. Remove the `webview_flutter_android` entry from `dependency_overrides`
   in `pubspec.yaml`.
2. Delete this `third_party/webview_flutter_android/` directory.
3. `flutter clean && flutter pub get && flutter build apk --debug`, then crash
   the renderer again on a device and confirm the app survives.
