# Kakao Developers 설정 체크리스트 (Voylog)

이 문서는 Kakao Developers 콘솔에서 **계정 소유자가 직접** 해야 하는 작업을 정리한
체크리스트입니다. Claude Code가 대신 수행할 수 없는 항목들입니다 (계정 로그인, 앱 등록,
플랫폼 등록 등 외부 콘솔 조작이기 때문).

## ⚠️ 먼저 읽어주세요: 키 종류에 대한 중요한 정정

요청하신 항목 중 "JavaScript Key는 Flutter Android/iOS 앱 지도 구현에는 기본적으로
사용하지 않는다"는 가정이 있었는데, **이 프로젝트가 실제로 사용하는 지도 플러그인
(`kakao_map_plugin`)에는 해당하지 않습니다.** 정확한 사실을 알려드립니다.

`kakao_map_plugin`은 진짜 네이티브 SDK 바인딩이 아니라, **Kakao Maps JavaScript SDK를
`webview_flutter`(공식 Flutter WebView 플러그인)로 감싸서 앱 내부에 내장된 WebView 안에서
실행**하는 방식입니다 (pub.dev 패키지 설명: "Javascript 라이브러리를 이용하여 제작한
플러그인"). 그래서:

- **지도 렌더링(`KakaoMapWidget`)에는 JavaScript 키가 필요합니다.**
  [lib/services/map_service.dart](../lib/services/map_service.dart)에서
  `AuthRepository.initialize(appKey: ...)`로 주입하는 키가 바로 이 JavaScript 키입니다.
- Kakao의 진짜 네이티브 Android/iOS Maps SDK(다른 패키지)를 썼다면 Native App Key를 썼겠지만,
  이 프로젝트는 그 SDK를 쓰지 않습니다.
- **Native App Key는 Kakao 로그인(카카오 소셜 로그인)에 필요**합니다.
  [lib/screens/login_screen.dart](../lib/screens/login_screen.dart)와
  [lib/services/kakao_auth_service.dart](../lib/services/kakao_auth_service.dart)에
  `kakao_flutter_sdk_user` 연동이 완료되어 있습니다 — Native App Key만 등록하면
  바로 동작합니다.

요약하면 아래 표와 같습니다.

| 기능 | 사용 패키지 | 필요한 키 | 등록 위치 |
| --- | --- | --- | --- |
| 지도 렌더링 (`KakaoMapWidget`) | `kakao_map_plugin` (WebView 기반) | **JavaScript 키** | 앱 설정 → 앱 키 → JavaScript 키 |
| 카카오 로그인 (`kakao_flutter_sdk_user`, 연동 완료) | `LoginScreen` → `KakaoAuthService` | **Native 앱 키** | 앱 설정 → 앱 키 → Native 앱 키 |
| AI Worker의 좌표 변환/길찾기 | 백엔드 서버 (`ai-worker/`) | **REST API 키** | 앱 설정 → 앱 키 → REST API 키 |

---

## 1. 앱 생성/확인

- [ ] [Kakao Developers](https://developers.kakao.com/) 로그인 → 내 애플리케이션
- [ ] 앱 이름을 **Voylog**로 설정 (또는 기존 앱이 있다면 이름 변경)

## 2. 플랫폼 등록 — Android

경로: 앱 설정 → 플랫폼 → Android 플랫폼 등록

- [ ] **패키지명**: `com.luckyvicky.voylog` (이미 코드에 적용 완료 — `android/app/build.gradle.kts`의
      `applicationId`. [PACKAGE_RENAME_GUIDE.md](PACKAGE_RENAME_GUIDE.md) 참고)
- [ ] **마켓 URL**: 아직 배포 전이면 비워둬도 됨
- [ ] **키 해시**: 아래 3번 절차로 생성한 값 등록 (디버그 키 해시 + 나중에 릴리즈 키 해시)

## 3. Android 키 해시 생성

### 디버그 키 해시 (개발 중 사용, `~/.android/debug.keystore` 기준)

macOS/Linux:

```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore \
  -storepass android -keypass android | openssl sha1 -binary | openssl base64
```

Windows (Git Bash):

```bash
keytool -exportcert -alias androiddebugkey -keystore "$USERPROFILE/.android/debug.keystore" \
  -storepass android -keypass android | openssl sha1 -binary | openssl base64
```

### 릴리즈 키 해시 (배포 시 사용, 실제 서명 키스토어 기준)

```bash
keytool -exportcert -alias <release-key-alias> -keystore <release-keystore-경로> \
  -storepass <keystore-비밀번호> | openssl sha1 -binary | openssl base64
```

- [ ] **디버그 키 해시와 릴리즈 키 해시는 서로 다릅니다.** 개발 중에는 디버그 키 해시만
      등록해도 되지만, Play Store 배포 직전에는 **반드시 릴리즈 키 해시도 추가 등록**해야
      실기기 배포판에서 카카오 기능이 정상 동작합니다. (Google Play App Signing을 쓰면
      Play Console이 재서명하므로, 그 경우 Play Console에 표시되는 "앱 서명 키 인증서"의
      SHA-1로 키 해시를 다시 뽑아 등록해야 합니다.)

## 4. 플랫폼 등록 — iOS

경로: 앱 설정 → 플랫폼 → iOS 플랫폼 등록

- [ ] **번들 ID**: `com.luckyvicky.voylog` (Android와 동일하게 맞추는 것을 권장하지만 필수는 아님)

## 5. JavaScript 키 등록 (지도용, 필수)

경로(2026년 개편된 콘솔 기준): 앱 > **플랫폼 키** 페이지에서 JavaScript 키 항목을
찾으면 그 안에 **"JavaScript SDK 도메인"** 입력란이 바로 있습니다(예전 "앱 설정 →
플랫폼 → Web 플랫폼 등록"이라는 별도 메뉴가 아니라, 플랫폼 키 페이지 자체에 통합되어
있음 — "제품 링크 관리 → 웹 도메인"은 카카오 로그인/공유용이라 다른 메뉴이니 헷갈리지
말 것). 여기에 도메인을 등록해야 JavaScript 키의 도메인 검증이 동작합니다
(`kakao_map_plugin`이 내부적으로 WebView에 로컬 HTML을 로드하는 방식이라 실제 브라우저
도메인 검증과는 다르게 동작할 수 있습니다 — 문제가 생기면 아래 "문제 해결" 참고).

- [ ] `travel_youtube_app/.env.example`을 복사해 `travel_youtube_app/.env`를 만들고
      (한 번만), `KAKAO_JAVASCRIPT_KEY=`에 발급받은 JavaScript 키를 채워 넣습니다:

  ```bash
  cd travel_youtube_app
  cp .env.example .env
  # .env 파일을 열어 KAKAO_JAVASCRIPT_KEY=<발급받은 키> 로 수정
  ```

- [ ] `.env`는 `.gitignore`에 포함되어 있어 커밋되지 않습니다 — 절대 `.env.example`에
      실제 키를 채워서 커밋하지 마세요 ([core/config/env.dart](../lib/core/config/env.dart)가
      `flutter_dotenv`로 앱 시작 시 `.env`를 읽습니다).
- [ ] 실제 배포 빌드(CI 등)에서도 빌드 서버에 `.env` 파일을 생성하는 단계를 추가해야 합니다
      (코드에 키를 하드코딩하지 마세요).

### 문제 해결: 지도가 안 뜨는 경우

`kakao_map_plugin`은 `AuthRepository.initialize(appKey: ..., baseUrl: ...)`의 `baseUrl`을
WebView의 origin으로 사용합니다. **`MapService.initialize()`가 `baseUrl`을 아예 안
넘기면 WebView가 `about:blank` origin으로 SDK를 요청하게 되어, Kakao 쪽에서 출처
불명으로 거부해 `"kakao is not defined"` 콘솔 에러가 남습니다** — 2026-09-08에 실기기
테스트로 이 증상을 확인하고 고침. JavaScript 키에 도메인 제한이 걸려 있어 지도가 안 뜨면:

1. Kakao Developers → 앱 > 플랫폼 키 > JavaScript 키의 "JavaScript SDK 도메인"에
   `http://localhost:5000`처럼 실제 사용할 개발용 도메인을 등록(포트까지 정확히 일치해야 함)
2. `MapService.initialize()`([lib/services/map_service.dart](../lib/services/map_service.dart))의
   `baseUrl` 파라미터를 1번에서 등록한 도메인과 정확히 일치시킴 — 현재 코드는
   `http://localhost:5000`으로 맞춰져 있음(콘솔에 이미 이 도메인이 등록되어 있었음).
   다른 도메인으로 바꿔 등록했다면 이 값도 같이 바꿔야 함.

## 6. Native 앱 키 (카카오 로그인용)

카카오 로그인은 `kakao_flutter_sdk_user`로 연동 완료된 상태입니다
([lib/screens/login_screen.dart](../lib/screens/login_screen.dart),
[lib/services/kakao_auth_service.dart](../lib/services/kakao_auth_service.dart)).
Native 앱 키만 등록하면 됩니다.

### Android (자동 반영됨 — `.env`만 채우면 끝)

- [ ] Native 앱 키를 `travel_youtube_app/.env`의 `KAKAO_NATIVE_APP_KEY`에 채워 넣기
- [ ] 그걸로 끝입니다. `android/app/build.gradle.kts`가 빌드 시점에 `.env`를 직접
      읽어 `AndroidManifest.xml`의 `${kakaoNativeAppKey}` 플레이스홀더(리다이렉트
      URL 스킴)에 자동으로 채워 넣습니다 — 별도 수동 설정 불필요.
- [ ] `flutter build apk --debug`로 빌드해 확인 (이 저장소에서 실제로 성공 확인됨)

### iOS (수동 설정 필요, **미검증** — 이 저장소 개발 환경이 Windows라 빌드 테스트 불가)

Xcode의 Info.plist는 `.env`를 직접 읽을 수 없어서, Android와 달리 **별도로
한 번 더** 값을 넣어야 합니다 (두 파일이 서로 안 맞으면 로그인이 실패하니
주의하세요).

- [ ] `ios/Flutter/KakaoKeys.xcconfig.example`을 복사해
      `ios/Flutter/KakaoKeys.xcconfig` 생성 (git-ignored)
- [ ] 그 안의 `KAKAO_NATIVE_APP_KEY = ...` 값을 `.env`와 동일한 실제 키로 수정
- [ ] macOS에서 `flutter build ios --debug --no-codesign` 또는 Xcode로 빌드해
      `Info.plist`의 `CFBundleURLTypes`/`LSApplicationQueriesSchemes`가 정상
      반영되는지 확인 (Mac 보유자가 직접 검증 필요)

## 7. REST API 키 (백엔드/AI Worker용, 프론트엔드에는 절대 넣지 않음)

- [ ] REST API 키를 복사해 `ai-worker/.env`의 `KAKAO_REST_API_KEY`에 설정
      (`ai-worker/.env.example` 참고, 실제 `.env`는 커밋 금지)
- [ ] 이 키는 Flutter 앱(`travel_youtube_app/`)에는 절대 포함하지 않습니다 —
      root [CLAUDE.md](../../CLAUDE.md)의 "프론트엔드는 Kakao REST API를 직접 호출하지 않는다" 규칙

---

## 체크리스트 요약

- [ ] 앱 이름 Voylog로 설정
- [ ] Android 플랫폼 등록 (패키지명 + 디버그 키 해시)
- [ ] iOS 플랫폼 등록 (번들 ID)
- [ ] Web 플랫폼 등록 (JavaScript 키 도메인 검증용)
- [ ] JavaScript 키 → `travel_youtube_app/.env`의 `KAKAO_JAVASCRIPT_KEY`
- [ ] REST API 키 → `ai-worker/.env`의 `KAKAO_REST_API_KEY`
- [ ] Native 앱 키 → `travel_youtube_app/.env`의 `KAKAO_NATIVE_APP_KEY` (Android는 이걸로 끝)
- [ ] Native 앱 키 → iOS는 추가로 `ios/Flutter/KakaoKeys.xcconfig`에도 동일한 값 입력 (수동, 미검증)
- [ ] 배포 직전: 릴리즈 키 해시를 Android 플랫폼에 추가 등록
