# 푸시 알림 설정 (FR-12)

Firebase Cloud Messaging(FCM)으로 두 가지 알림을 보낸다.

| 알림 | 언제 | 설정 토글 |
| --- | --- | --- |
| 영상 분석이 끝났어요 | 백그라운드 장소 보강(OCR 패스)이 끝난 순간 | `routeCompleteAlerts` ("동선 생성 완료") |
| 내일 여행이 시작돼요 | 여행 시작일 하루 전, KST 10~21시 사이 | `tripStartAlerts` ("여행 시작 알림") |

둘 다 **야간 침묵**(`nightSilent`)을 켠 사용자에게는 KST 22:00~08:00 사이에 보내지 않는다.

이 문서의 설정을 **하지 않아도 앱과 백엔드는 그대로 돌아간다** — 알림만 꺼진다.
콘솔 작업은 계정 소유자만 할 수 있어 Claude Code가 대신할 수 없다.

---

## 1. Firebase 프로젝트 만들기

1. https://console.firebase.google.com → **프로젝트 추가**
2. 프로젝트 이름: `voylog` (아무거나 상관없음)
3. Google 애널리틱스는 **사용 안 함**으로 둬도 된다 (FCM에 필요 없음)

## 2. Android 앱 등록

1. 프로젝트 개요 → **Android 아이콘** 클릭
2. Android 패키지 이름: **`com.luckyvicky.voylog`** (오타 주의 — `android/app/build.gradle.kts`의 `applicationId`와 정확히 같아야 함)
3. 앱 닉네임 / 디버그 서명 인증서 SHA-1은 **비워둬도 된다** (FCM만 쓸 거라 필요 없음. Google 로그인을 붙일 때만 필요)
4. **`google-services.json` 다운로드** → `travel_youtube_app/android/app/google-services.json`에 저장
   - 이 파일은 gitignore 되어 있다. 커밋하지 말 것.
   - 파일을 넣으면 Gradle이 자동으로 google-services 플러그인을 적용한다(`android/app/build.gradle.kts`의 `if (file("google-services.json").exists())`). 없으면 건너뛴다.
5. 남은 "SDK 추가" 단계는 **이미 코드에 반영되어 있으니 그냥 다음 → 콘솔로 이동**

## 3. 서버 키(서비스 계정) 받기

1. 프로젝트 설정(톱니) → **서비스 계정** 탭
2. **새 비공개 키 생성** → JSON 다운로드
3. `C:\GradudtionProject\backend\firebase-service-account.json`으로 저장 (gitignore 되어 있음)
4. `backend/.env`에 경로를 적는다:
   ```
   FIREBASE_SERVICE_ACCOUNT_PATH=C:\GradudtionProject\backend\firebase-service-account.json
   ```
5. 백엔드를 재시작한다. 설정이 안 되어 있으면 시작 로그에
   `Push notifications are off: no Firebase service account at FIREBASE_SERVICE_ACCOUNT_PATH`
   가 한 번 찍히고 모든 발송이 no-op이 된다.

## 4. 확인

1. `flutter run`으로 앱을 실기기에 올리고 로그인한다 (Android 13+면 알림 권한 팝업이 뜬다 — 허용)
2. DB에서 토큰이 들어왔는지 확인:
   ```sql
   SELECT user_id, platform, created_at FROM device_tokens;
   ```
3. 영상 하나를 분석하고(로그인 상태여야 함) 앱을 백그라운드로 보낸 뒤 2~3분 기다린다 — 보강이 끝나면 알림이 온다.
   - watcher가 등록됐는지: `SELECT * FROM video_analysis_watchers;`
4. 여행 알림을 바로 보고 싶으면 여행의 시작일을 **내일**로 맞추고 `start_alert_sent_at`을 비운 뒤, KST 10~21시 사이에 백엔드를 재시작한다(시작 1분 뒤 첫 스윕이 돈다).
   ```sql
   UPDATE trips SET start_date = current_date + 1, start_alert_sent_at = NULL WHERE trip_id = '...';
   ```

## 5. iOS (아직 미적용)

iOS는 Firebase 콘솔의 Android 단계와 같은 흐름에 **APNs 인증 키(.p8)** 업로드가 추가로 필요하고,
빌드는 macOS + Xcode에서만 된다. 현재 개발 환경이 Windows라 여기까지는 설정하지 않았다.
준비가 되면:

1. Firebase 콘솔 → iOS 앱 추가, 번들 ID `com.luckyvicky.voylog`
2. `GoogleService-Info.plist` → `travel_youtube_app/ios/Runner/GoogleService-Info.plist` (gitignore 되어 있음)
3. Apple Developer → Keys → APNs 키 생성 → Firebase 프로젝트 설정 → 클라우드 메시징에 업로드
4. Xcode에서 Push Notifications + Background Modes(Remote notifications) Capability 추가

앱 코드(`PushRegistrationService`)는 이미 플랫폼을 구분해 `ios`로 등록하므로 Dart 쪽 수정은 필요 없다.

## 문제가 생기면

| 증상 | 원인 |
| --- | --- |
| `device_tokens`가 비어 있음 | 알림 권한 거부, 또는 `google-services.json` 누락 → 앱 로그에 `Push notifications are off: Firebase is not configured` |
| 토큰은 있는데 알림이 안 옴 | 백엔드 `.env`의 `FIREBASE_SERVICE_ACCOUNT_PATH` 누락, 알림 설정 토글 off, 또는 야간 침묵 시간대 |
| `Default FirebaseApp is not initialized` | `google-services.json`을 넣은 뒤 **전체 재빌드**(`flutter run`을 다시)를 안 함 — 핫 리로드로는 반영되지 않는다 |
| 빌드 실패 `File google-services.json is missing` | 파일을 `android/`가 아니라 `android/app/`에 넣어야 한다 |
