# Why this package is vendored

This is a local copy of `kakao_map_plugin` 0.4.0 (from pub.dev), with one patch:

- `android/build.gradle`: `compileSdk` bumped from `35` to `36`.

## Reason

`kakao_map_plugin` 0.4.0 depends on `webview_flutter_android: ^4.7.0`, which
resolves to `4.13.0`. That version's Android dependencies require
`compileSdk 36`, but `kakao_map_plugin`'s own `android/build.gradle` still
hardcodes `compileSdk 35`. This makes the Android Gradle Plugin fail with:

```
Dependency ':webview_flutter_android' requires compileSdk 36 or later.
:kakao_map_plugin is currently compiled against android-35.
```

0.4.0 was, at the time of vendoring, the latest version on pub.dev (checked
via `https://pub.dev/api/packages/kakao_map_plugin`), so this isn't fixed by
upgrading. There was no compatible older `webview_flutter_android` version
confirmed safe to pin instead, so vendoring + patching was the most reliable
fix (see `travel_youtube_app/pubspec.yaml`, which points here via a `path:`
dependency instead of the pub.dev version).

## How to remove this vendored copy later

Once a `kakao_map_plugin` release ships with `compileSdk 36` (or higher)
in its own `android/build.gradle`:

1. In `pubspec.yaml`, replace the `path:` dependency with a normal version
   constraint, e.g. `kakao_map_plugin: ^<new-version>`.
2. Delete this `third_party/kakao_map_plugin/` directory.
3. Run `flutter clean && flutter pub get && flutter build apk --debug` to confirm.

Check for a fix: https://pub.dev/packages/kakao_map_plugin/changelog
