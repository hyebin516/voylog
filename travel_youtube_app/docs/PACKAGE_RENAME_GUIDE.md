# 패키지명 변경 가이드 (Voylog)

앱 표시 이름은 이미 **Voylog**로 변경되었습니다
([android/app/src/main/AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml)의 `android:label`,
[ios/Runner/Info.plist](../ios/Runner/Info.plist)의 `CFBundleDisplayName`/`CFBundleName`).

Android `applicationId`/iOS Bundle ID는 **이미 `com.luckyvicky.voylog`로 변경 완료**했습니다.
아래는 그때 실제로 적용한 절차이자, 나중에 다른 패키지명으로 다시 바꿀 때 참고할 수 있는
일반 가이드입니다.

**다음 할 일**: 패키지명을 바꿨으므로 Kakao Developers 콘솔에 `com.luckyvicky.voylog`로
Android/iOS 플랫폼을 새로 등록해야 합니다 (키 해시 포함). [KAKAO_SETUP.md](KAKAO_SETUP.md) 참고.

## 왜 Dart 패키지명(`pubspec.yaml`의 `name:`)은 그대로 두었나

`pubspec.yaml`의 `name: travel_youtube_app`은 Dart import 경로
(`package:travel_youtube_app/...`)에 쓰이는 내부 식별자로, 사용자에게 보이지 않습니다.
이걸 바꾸려면 `lib/` 전체의 모든 import 문을 고쳐야 하는 대규모 기계적 작업이 필요하고,
앱 표시 이름/스토어 등록과는 무관합니다. 요청하신 "앱 표시 이름"과는 다른 것이라
이번 변경 범위에서 제외했습니다. 정말 바꾸고 싶다면 아래 "선택: Dart 패키지명도 바꾸기"
섹션을 참고하세요.

---

## Android: applicationId 변경

### 1. `android/app/build.gradle.kts`

```kotlin
android {
    namespace = "com.luckyvicky.voylog"       // 변경
    ...
    defaultConfig {
        applicationId = "com.luckyvicky.voylog"  // 변경
        ...
    }
}
```

### 2. Kotlin 소스 디렉터리 및 패키지 선언 이동

현재 위치:

```text
android/app/src/main/kotlin/com/example/travel_youtube_app/MainActivity.kt
```

새 패키지 구조에 맞게 디렉터리를 이동하고 파일 안의 `package` 선언도 바꿔야 합니다.

```bash
# travel_youtube_app/ 에서 실행
mkdir -p android/app/src/main/kotlin/com/luckyvicky/voylog
git mv android/app/src/main/kotlin/com/example/travel_youtube_app/MainActivity.kt \
       android/app/src/main/kotlin/com/luckyvicky/voylog/MainActivity.kt
# 빈 디렉터리 정리
rmdir android/app/src/main/kotlin/com/example/travel_youtube_app
rmdir android/app/src/main/kotlin/com/example
```

`MainActivity.kt` 상단의 패키지 선언도 수정:

```kotlin
package com.luckyvicky.voylog
```

### 3. 확인

`android/app/src/main/AndroidManifest.xml`은 최신 Flutter 템플릿 기준으로 `package` 속성이
없고 `namespace`(위 1번)로 관리되므로 별도 수정이 필요 없습니다. `android:name=".MainActivity"`도
그대로 두면 됩니다 (namespace 기준 상대 경로).

---

## iOS: Bundle ID 변경

Xcode 없이 CLI로 직접 바꾸는 방법 (`ios/Runner.xcodeproj/project.pbxproj`):

```bash
# travel_youtube_app/ 에서 실행 (macOS에서만 iOS 빌드 가능)
sed -i '' 's/com\.example\.travelYoutubeApp/com.luckyvicky.voylog/g' \
  ios/Runner.xcodeproj/project.pbxproj
```

현재 6곳에서 `PRODUCT_BUNDLE_IDENTIFIER`가 `com.example.travelYoutubeApp` (RunnerTests는
`.RunnerTests` 접미사)로 지정되어 있습니다. Debug/Release/Profile 빌드 설정 전부 포함됩니다.

Xcode가 있다면 GUI로 하는 편이 더 안전합니다: `Runner.xcworkspace` 열기 →
TARGETS → Runner → Signing & Capabilities → **Bundle Identifier**를 `com.luckyvicky.voylog`로 변경
(RunnerTests 타겟도 동일하게).

`ios/Runner/Info.plist`는 `$(PRODUCT_BUNDLE_IDENTIFIER)` 변수를 참조하므로 직접 수정할 필요 없습니다.

---

## 변경 후 확인

```bash
flutter clean
flutter pub get
flutter analyze

# Android
flutter build apk --debug

# iOS (macOS에서만)
flutter build ios --debug --no-codesign
```

패키지명이 실제로 반영됐는지 확인:

```bash
# Android
grep -r "applicationId\|namespace" android/app/build.gradle.kts

# iOS
grep "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj
```

---

## 패키지명 변경 후 반드시 해야 할 일

**새 패키지명/Bundle ID로 Kakao Developers 콘솔에 플랫폼을 다시 등록해야 합니다.**
등록하지 않으면 카카오 지도/로그인이 실기기에서 로드되지 않습니다.
자세한 절차는 [KAKAO_SETUP.md](KAKAO_SETUP.md)를 참고하세요.

- Android 플랫폼: 새 패키지명 + 키 해시(디버그/릴리즈) 등록
- iOS 플랫폼: 새 Bundle ID 등록

---

## 선택: Dart 패키지명도 바꾸기 (`travel_youtube_app` → `voylog`)

표시 이름과 무관한, 순수 내부 리네이밍입니다. 필요하면:

```bash
# pubspec.yaml의 name: 변경
# name: travel_youtube_app → name: voylog

# lib/, test/, integration_test/ 전체의 import 경로 일괄 치환
grep -rl "package:travel_youtube_app" lib test integration_test | \
  xargs sed -i 's/package:travel_youtube_app/package:voylog/g'

flutter pub get
flutter analyze
```

이 작업은 이번 변경 범위에 포함하지 않았습니다 — 필요하다고 판단되면 별도로 요청해 주세요.
