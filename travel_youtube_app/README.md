# Voylog

유튜브 여행 영상에서 장소를 자동 추출하고, 호텔 기반 최적 동선을 계획해주는
Flutter **Android/iOS 네이티브** 앱. Flutter Web은 지원하지 않습니다.

- 상태 관리: Provider
- 네트워킹: Dio
- 지도: `kakao_map_plugin` (webview_flutter 기반 네이티브 플러그인 — 브라우저 전용
  `package:web`/`dart:js_interop`는 사용하지 않음)
- 아키텍처: Screen → Provider → Repository → Backend API

## 환경변수 설정

이 프로젝트는 `flutter_dotenv`로 `.env` 파일에서 환경변수를 읽습니다. `.env`는
`.gitignore`에 포함되어 있어 커밋되지 않습니다 — **처음 받으면 반드시 아래처럼
직접 만들어야 합니다.**

```bash
cp .env.example .env
```

그런 다음 `.env` 파일을 열어 [docs/KAKAO_SETUP.md](docs/KAKAO_SETUP.md) 절차대로
Kakao Developers에서 직접 발급받은 키를 채워 넣으세요.

```env
API_BASE_URL=http://localhost:4000/api/v1
KAKAO_JAVASCRIPT_KEY=<카카오 콘솔에서 발급받은 JavaScript 키>
KAKAO_NATIVE_APP_KEY=<카카오 로그인 연동 시 필요, 아직 미사용>
```

`.env`를 만들지 않아도 앱은 실행되지만(코드의 fallback 기본값 사용), 카카오 지도는
로드되지 않습니다.

## 실행

이 저장소의 Windows 개발 환경에서는 로컬 Android 에뮬레이터가 부팅 중 크래시하는
문제가 있어(원인·시도한 방법은 [docs/TESTING_GUIDE.md](docs/TESTING_GUIDE.md) 참고),
**실제 Android 기기를 USB로 연결**해서 실행하는 걸 권장합니다. `flutter build apk
--debug`(빌드만)는 이 환경에서 정상적으로 성공하므로, 앱 코드 자체는 문제가 없습니다.

### 실제 Android 기기로 실행하기

1. 폰에서 **설정 → 휴대전화 정보 → 빌드 번호를 7번 연속 탭** → "개발자 모드가
   활성화되었습니다" 표시 확인 (이미 개발자 옵션이 있다면 생략)
2. **설정 → 개발자 옵션 → USB 디버깅** 켜기
3. 폰을 USB 케이블로 PC에 연결
4. 폰 화면에 "USB 디버깅을 허용하시겠습니까?" 팝업이 뜨면 **허용**
5. PC에서 확인:
   ```bash
   flutter devices
   ```
   폰이 목록에 나오면 (`<모델명> • <device-id> • android-arm64 • ...`) 연결 성공.
   안 보이면 `flutter doctor -v`로 USB 드라이버 관련 경고가 있는지 확인하세요
   (일부 제조사는 별도 USB 드라이버 설치가 필요합니다).
6. 실행:
   ```bash
   flutter pub get
   flutter run -d <device-id>
   ```
   `.env`를 만들지 않았다면 카카오 지도는 안 뜨지만 앱 자체는 실행됩니다 — 위
   "환경변수 설정" 참고.

### (참고) Android Studio에서 실행하기

터미널 대신 Android Studio를 쓴다면: 상단 기기 선택 드롭다운에서 연결된 폰을
선택하고 ▶(Run 'main.dart') 버튼을 누르면 동일하게 동작합니다.

## 검증 명령어

```bash
flutter analyze                                   # 정적 분석
flutter test                                       # 일반 테스트 (네이티브 플러그인 미의존)
flutter devices                                    # 연결된 기기/에뮬레이터 확인
flutter emulators                                  # 설치된 에뮬레이터 목록
flutter run -d <device-id>                         # 실기기/에뮬레이터에서 앱 실행
flutter test integration_test -d <device-id>       # 실기기 통합 테스트 (지도 등, .env 필요)
flutter build apk --debug                          # Android 빌드
```

> **알려진 한계 (Windows)**: 이 저장소의 Windows 개발 환경에서 세 가지 문제가
> 있습니다 — (1) `flutter test`가 `flutter_tester.exe` 네이티브 크래시로
> 실행되지 않음, (2) 계정명이 한글이면 `PUB_CACHE`/Android SDK 경로를 ASCII로
> 옮겨야 `flutter build apk`가 성공함 (이미 조치 완료, 아래 참고), (3) 로컬
> Android 에뮬레이터가 원인 미상으로 부팅 중 크래시함 (WHPX 활성화로 1차
> 문제는 해결했으나 그 다음 단계에서 재현, 원인 불명이라 실기기 사용 권장).
> `flutter analyze`와 `flutter build apk --debug`는 세 문제와 무관하게 정상
> 통과·성공합니다. 셋 다 원인·시도 내역은 [docs/TESTING_GUIDE.md](docs/TESTING_GUIDE.md)에
> 정리해 뒀습니다.

## 문서

- [docs/KAKAO_SETUP.md](docs/KAKAO_SETUP.md) — Kakao Developers 콘솔 설정 체크리스트
- [docs/PACKAGE_RENAME_GUIDE.md](docs/PACKAGE_RENAME_GUIDE.md) — Android/iOS 패키지명 변경 절차
- [docs/TESTING_GUIDE.md](docs/TESTING_GUIDE.md) — 일반 테스트 vs 통합 테스트 구조
- [claude.md](claude.md) — 프론트엔드 아키텍처/코딩 규칙
