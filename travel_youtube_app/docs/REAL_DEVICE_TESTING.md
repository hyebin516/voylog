# 실기기(Android) 검증 가이드

이 문서는 [TESTING_GUIDE.md](TESTING_GUIDE.md)의 "Windows에서 `flutter test`/
에뮬레이터가 안 되는 문제"를 우회하기 위해, **실제 Android 기기를 USB로 연결해서
앱을 직접 실행하고 기능을 눈으로 확인**하는 절차입니다. `flutter test`/
`integration_test`(자동화 테스트)가 아니라 **수동 기능 검증**이 목적입니다.

## 0. 사전 준비물

- USB 케이블로 이 PC와 연결 가능한 Android 폰 (Android 6.0 이상)
- 데이터 전송이 되는 케이블 (충전 전용 케이블은 안 됨)

## 1. 폰에서 USB 디버깅 켜기

1. 설정 → 휴대전화 정보 → **빌드 번호를 7번 연속 탭** → "개발자 모드가 켜졌습니다" 토스트 확인
2. 설정 → (시스템 →) 개발자 옵션 → **USB 디버깅** 켜기
3. 폰을 PC에 USB로 연결
4. 폰 화면에 "USB 디버깅을 허용하시겠습니까?" 팝업이 뜨면 **이 컴퓨터 항상 허용**
   체크 후 허용 (놓치면 아래 `flutter devices`에 기기가 `unauthorized`로 잡힘)

## 2. 기기 인식 확인

```bash
flutter devices
```

기기 이름이 목록에 뜨면 연결 성공입니다. 안 뜨거나 `unauthorized`로 뜨면:

- USB 케이블/포트를 바꿔보기 (일부 케이블은 충전 전용)
- 폰 화면 잠금을 풀고 위 3번의 허용 팝업이 다시 뜨는지 확인
- `adb devices`로도 확인 가능 (`c:\Android\Sdk\platform-tools\adb.exe devices`)

## 3. 로컬 백엔드를 폰에서 접근 가능하게 만들기 (가장 중요, 자주 놓치는 단계)

`travel_youtube_app/.env`의 `API_BASE_URL`은 기본적으로 `http://localhost:4000/api/v1`인데,
**폰 입장에서 "localhost"는 폰 자기 자신**이지 이 PC가 아닙니다. USB로 연결된 상태에서는
`adb reverse`로 포트를 터널링하면 `.env`를 전혀 바꾸지 않고도 그대로 동작합니다.

```bash
adb reverse tcp:4000 tcp:4000
```

이 명령 하나로 폰이 보내는 `localhost:4000` 요청이 USB 케이블을 통해 이 PC의
4000번 포트(백엔드)로 전달됩니다. AI Worker(8000번)는 백엔드만 호출하고 폰이
직접 호출하지 않으므로 별도 reverse가 필요 없습니다.

**주의**: `adb reverse`는 **케이블을 뽑았다 다시 꽂거나 `adb kill-server`를 실행하면
풀립니다.** 재연결할 때마다 다시 실행해야 합니다. ("네트워크 오류"가 갑자기 뜨면
제일 먼저 이걸 의심하세요.)

Wi-Fi로 무선 디버깅을 쓰는 경우엔 `adb reverse`가 안 통하므로, 대신 이 PC의 LAN IP를
`.env`의 `API_BASE_URL`에 직접 넣어야 합니다 (`ipconfig`로 확인한 `192.168.x.x` 주소,
폰과 PC가 같은 Wi-Fi여야 함, Windows 방화벽에서 4000번 포트 인바운드 허용 필요) —
USB 연결이 가능하면 `adb reverse` 쪽이 훨씬 간단하니 그쪽을 권장합니다.

## 4. 백엔드/AI Worker/DB/Redis 실행 확인

`backend/README.md`, `ai-worker/README.md`에 정리된 순서대로 전부 떠 있어야 합니다.

```bash
"/c/PostgreSQL17/pgsql/bin/pg_isready.exe" -h localhost -p 5432
"/c/Redis/redis-cli.exe" ping
curl http://localhost:4000/api/v1/videos/search?hashtag=test   # 백엔드
curl http://localhost:8000/health                              # AI Worker
```

PC를 재부팅했다면 PostgreSQL/Redis/backend/ai-worker 넷 다 꺼져 있을 가능성이 높습니다
(전부 일반 프로세스라 서비스 등록이 안 되어 있음 — 각 README의 재시작 순서 참고).

## 5. Kakao 키 확인 (실기기에서만 드러나는 함정)

- [ ] `travel_youtube_app/.env`에 `KAKAO_JAVASCRIPT_KEY`, `KAKAO_NATIVE_APP_KEY`가
      실제 값으로 채워져 있는지 확인
- [ ] **이 PC에서 생성한 디버그 키 해시**가 Kakao Developers 콘솔의 Android 플랫폼에
      등록되어 있는지 확인 — [KAKAO_SETUP.md](KAKAO_SETUP.md) 3번 절차. 디버그
      키스토어(`~/.android/debug.keystore`)는 **PC마다 다르게 자동 생성**되므로,
      다른 PC에서 이미 등록해봤어도 이 PC 기준으로 다시 뽑아 등록해야 카카오
      로그인이 됩니다. 지도(JavaScript 키)와 REST API 키는 이 문제와 무관하게
      항상 동작합니다 — 실패하는 게 로그인뿐이라면 십중팔구 이 키 해시 문제입니다.

## 6. 앱 실행

```bash
cd travel_youtube_app
flutter run -d <device-id>   # device-id는 `flutter devices` 출력값
```

첫 빌드는 몇 분 걸릴 수 있습니다. 실행 중 콘솔에 `print`/`debugPrint`와 Dart 예외가
그대로 찍힙니다. `r`(hot reload)/`R`(hot restart)/`q`(종료)를 콘솔에서 바로 입력할 수
있습니다.

## 7. 확인할 항목 (요구사항 기준 골든 패스)

| 항목 | 요구사항 | 확인 방법 |
| --- | --- | --- |
| 카카오 로그인 | FR-08 | 로그인 화면에서 카카오 로그인 → 홈 화면 진입 |
| URL 분석 | FR-01 | 여행 브이로그 URL 입력 → 장소 카드 목록 표시 |
| 해시태그 탐색 | FR-02 (신규) | 홈 화면 하단 "#부산여행" 같은 해시태그 입력 → 영상 후보 목록 → 하나 탭 → 분석 진행 |
| 장소 카드 / 타임스탬프 | FR-03, FR-04 | 카드 탭 시 유튜브 플레이어가 해당 시각으로 이동하는지 |
| 지도 보기 | FR-05 | 장소 카드의 지도 버튼 → 실제 Kakao 지도(WebView)가 뜨는지 |
| 북마크 | FR-06 | 장소 북마크 → 북마크 화면에서 조회/삭제 |
| 호텔 선택 + 동선 | FR-07 | 지도를 드래그해 시작/종료 호텔 저장 → 북마크 2~10개 선택 → 동선 최적화 → 폴리라인/총 거리·시간 표시. 같은 호텔이면 왕복, 다르면 호텔 간 이동으로 나오는지 |
| 캐싱 | FR-09 | 같은 URL을 두 번 분석 — 두 번째는 훨씬 빠르게(LLM 재호출 없이) 응답하는지 |

## 8. 로그 보기

- `flutter run` 콘솔: Dart/Flutter 레벨 로그, 앱 내 `print`/예외
- 더 상세한 Android 네이티브 로그가 필요하면 별도 터미널에서:
  ```bash
  "c:\Android\Sdk\platform-tools\adb.exe" logcat *:E flutter:V
  ```
- 백엔드/AI Worker 쪽 요청 로그는 각각 `backend/server.log`, `ai-worker/uvicorn.log`
  (둘 다 `.gitignore` 처리되어 있으니 커밋하지 않도록 주의)

## 9. 자주 겪는 문제

| 증상 | 원인/해결 |
| --- | --- |
| `flutter devices`에 기기가 안 뜸 | USB 디버깅 허용 팝업을 놓쳤거나, 충전 전용 케이블. 케이블/포트 교체 후 재확인 |
| 앱은 뜨는데 모든 API 호출이 "네트워크 오류" | `adb reverse tcp:4000 tcp:4000`을 안 했거나, 케이블 재연결 후 다시 안 함 |
| 지도/장소 분석은 되는데 카카오 로그인만 실패 | 이 PC의 디버그 키 해시가 Kakao 콘솔에 등록 안 됨 — 5번 항목 참고 |
| 호텔 저장/동선 생성이 401로 실패 | 로그인이 안 된 상태이거나 JWT 만료 — 다시 로그인 |
| `Waiting for another flutter command to release the startup lock` | 이전 `flutter run`/`flutter build` 프로세스가 아직 안 끝남 — 해당 터미널 종료 후 재시도 |

이 문서에서 다루는 "실기기 수동 검증"은 [TESTING_GUIDE.md](TESTING_GUIDE.md)의
`integration_test/`(자동화된 실기기 테스트)와는 별개입니다. 시간이 있다면
`flutter test integration_test -d <device-id>`도 같이 돌려서 `KakaoMapWidget`이
실제로 WebView에서 SDK를 로드하는지까지 자동으로 확인하는 걸 권장합니다.
