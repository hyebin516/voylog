# 배포 가이드

Voylog를 로컬 밖으로 내보낼 때 필요한 것들. 호스팅 업체를 고르기 전에
읽어야 하는 제약이 맨 앞에 있다.

---

## 0. 고르기 전에 확인할 것 — 유튜브 IP 차단

**이 서비스에서 가장 먼저 확인해야 할 위험이다.** 서버가 유튜브에
두 가지를 요청한다.

- `youtube-transcript-api`로 자막 가져오기 (모든 분석의 1단계)
- `yt-dlp`로 저해상도 영상 내려받기 (자막 없는 영상의 OCR 폴백)

유튜브는 **데이터센터 IP에서 오는 이 요청들을 차단하는 경우가 많다.**
집이나 학교 네트워크에서는 잘 되던 것이 클라우드에 올리는 순간
"Sign in to confirm you're not a bot"으로 막힐 수 있다. 막히면 영상
분석 — 즉 이 앱의 핵심 기능 — 이 통째로 동작하지 않는다.

그래서 **호스팅을 정하기 전에, 후보 서버에서 영상 하나를 분석해보는
것이 첫 번째 할 일이다.** 아래 한 줄이면 확인된다.

```bash
# 후보 서버에 ai-worker만 띄우고
curl -X POST http://<후보서버>:8000/extract-transcript \
  -H 'Content-Type: application/json' \
  -d '{"youtubeUrl":"https://www.youtube.com/watch?v=8tIGm8xndws"}'
```

자막이 돌아오면 그 호스팅을 써도 된다. 막히면 선택지는
① 다른 리전/업체를 시도 ② 프록시를 경유 ③ AI 워커만 집/학교 회선에
두고 백엔드만 클라우드에 올리는 하이브리드 — 순으로 검토한다.

---

## 1. 구성 요소

| 서비스 | 공개 여부 | 비고 |
| --- | --- | --- |
| 백엔드 (Node) | **공개** | 앱이 직접 호출. HTTPS 필수 |
| AI 워커 (Python) | **비공개** | 백엔드만 호출. 공개해야 한다면 `AI_WORKER_TOKEN` 필수 |
| PostgreSQL | 비공개 | 약 334MB (공공데이터 장소 85만 건 포함) |
| Redis | 비공개 | 선택. 없으면 캐시 없이 동작 |

AI 워커를 공개하면 안 되는 이유: **사용자 계정 개념이 없는데 호출마다
LLM 비용이 든다.** 주소만 알면 누구나 예산을 태울 수 있다.

---

## 2. 환경변수

`backend/.env.example`과 `ai-worker/.env.example`을 복사해 채운다.
배포에서 **반드시 로컬과 달라야 하는 값**은 다음과 같다.

### backend

| 변수 | 로컬 | 배포 |
| --- | --- | --- |
| `NODE_ENV` | `development` | `production` |
| `DATABASE_URL` | localhost | 실제 DB 주소 |
| `AI_WORKER_URL` | `http://localhost:8000` | 내부망 주소 |
| `JWT_SECRET` | 아무거나 | **새로 길게 생성** (아래 참고) |
| `TRUST_PROXY` | `0` | 프록시 1개 뒤면 `1` |
| `AI_WORKER_TOKEN` | 비움 | **새로 생성**, 워커와 동일 값 |

비밀값 생성:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

`TRUST_PROXY`를 빠뜨리면 **모든 사용자가 프록시 IP 하나로 묶여 레이트
리밋에 같이 걸린다.** 반대로 프록시가 없는데 켜면 `X-Forwarded-For`로
IP를 위조할 수 있다. 실제 구성에 맞게만 켠다.

### ai-worker

`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `KAKAO_REST_API_KEY`,
`YOUTUBE_API_KEY`, 그리고 백엔드와 같은 `AI_WORKER_TOKEN`.

### 앱 (travel_youtube_app)

`API_BASE_URL`을 배포된 백엔드의 **https 주소**로 바꾼다.

```
API_BASE_URL=https://api.example.com/api/v1
```

---

## 3. 올리기

```bash
docker compose up --build        # 로컬에서 서버와 같은 구성으로 확인
```

컨테이너 없이 올린다면 각 서비스의 `Dockerfile`이 필요한 것을 그대로
알려준다 — Node 24, Python 3.12 + `libglib2.0-0`(opencv), 그리고
`node src/server.js` / `uvicorn app.main:app`.

### DB 준비

`database/migrations/`의 `.sql`을 번호 순서대로 적용한다. compose는
최초 1회 자동 적용한다.

공공데이터 장소는 따로 적재한다(시간이 걸린다).

```bash
node scripts/import-tour-api.js                    # 약 20초
node scripts/import-semas.js <지역.csv>            # 약 80초
```

### 확인

```bash
curl https://<백엔드>/health        # {"status":"ok"}
```

---

## 4. 배포 후 확인 목록

- [ ] `/health`가 200을 반환한다
- [ ] 앱에서 **영상 분석이 실제로 된다** (0번 항목 — 가장 중요)
- [ ] 카카오 지도가 뜬다 (Kakao Developers에 배포 도메인 등록 필요)
- [ ] 카카오 로그인이 된다 (Redirect URI 등록 필요)
- [ ] 이메일 인증코드가 도착한다
- [ ] 레이트 리밋이 사람에게는 안 걸린다 (분석 시간당 20회)
- [ ] AI 워커가 **바깥에서 닿지 않는다** (`curl https://<워커주소>/health`가 실패해야 정상)
- [ ] 프로필 사진이 재배포 후에도 남아 있다

---

## 5. 앱 스토어 출시 (서버 배포와 별개)

서버가 떠야 시작할 수 있다. 앱이 바라볼 주소가 필요하기 때문.

### 코드 쪽 — 아직 안 된 것

- [ ] **릴리스 서명 키스토어** — 지금은 디버그 키로 서명한다
      (`android/app/build.gradle.kts`의 `signingConfigs.getByName("debug")`).
      이 상태로는 Play Store에 올릴 수 없다. 키스토어를 만들고
      `key.properties`로 분리한 뒤 **절대 잃어버리면 안 된다** — 잃으면
      같은 앱으로 업데이트할 수 없다.
- [ ] **`usesCleartextTraffic="true"` 제거** — 아래 "7. 해결 못 한 문제"
      참고. 2026-10-12에 시도했다가 지도가 깨져서 되돌렸다.
- [ ] `flutter build appbundle --release`로 빌드가 통과하는지 확인

### 계정·심사 쪽 — 사람이 해야 하는 것

- [ ] Google Play 개발자 계정 (1회 $25)
- [ ] 개인정보처리방침 URL (위치·이메일·사진을 수집하므로 필수)
- [ ] 데이터 안전성 섹션 작성 — 수집 항목을 실제와 맞게 적어야 한다
      (위치는 추천에만 쓰고 좌표를 저장하지 않는다는 점 포함)
- [ ] 스크린샷, 앱 아이콘, 설명
- [ ] Kakao Developers에 **릴리스 키 해시** 등록 (디버그 키 해시와 다르다)
- [ ] 카카오 API 쿼터 — 사용량이 늘면 검수 신청이 필요할 수 있다

### iOS

Apple Developer Program(연 $99)과 Mac이 필요하다. CI에서
`ios-build`가 통과하므로 컴파일 자체는 된다.

---

## 6. 알려진 제약

- **프로필 사진이 로컬 디스크에 저장된다** (`backend/uploads/`).
  파일시스템이 휘발성인 호스팅에서는 재배포마다 사라진다. compose는
  볼륨으로 막아두었고, 그런 호스팅을 쓴다면 영구 디스크를 붙이거나
  오브젝트 스토리지로 옮겨야 한다.
- **레이트 리밋 카운터가 프로세스 메모리에 있다.** 백엔드를 2개 이상
  띄우면 인스턴스마다 따로 센다. 그때는 Redis 저장소로 바꾼다.
- **월 1회 공공데이터 갱신이 인스턴스마다 돈다.** 여러 개 띄우면 하나만
  남기고 `PUBLIC_DATA_REFRESH_ENABLED=false`로 끈다.

---

## 7. 해결 못 한 문제 — 평문(HTTP) 통신 제한

앱은 지금 `android:usesCleartextTraffic="true"`(안드로이드)와
`NSAllowsArbitraryLoads`(iOS)로 **아무 주소로나 평문 HTTP를 허용**한다.
개발용으로 들어간 설정이고 스토어 출시 전에 좁혀야 하는데,
**2026-10-12에 시도했다가 지도가 빈 화면이 되어 되돌렸다.**

### 확인된 사실

실기기(SM-A750N)에서, **네트워크 정상 + 지도 첫 로딩 버그 수정 적용 +
감시 타이머 재시도 소진(45초 대기)** 조건으로 확인했다.

| 설정 | 지도 |
| --- | --- |
| `usesCleartextTraffic="true"` (현재) | **정상** |
| localhost/127.0.0.1/10.0.2.2만 허용하는 network-security-config | **빈 화면** |

아래 둘은 지도 첫 로딩 버그를 고치기 **전에** 시도한 것이라 신뢰도가
낮다. 다시 할 때는 재검증할 것.

| 추가 시도 (신뢰도 낮음) | 결과 |
| --- | --- |
| 위 + 지도 origin을 `https://localhost:5000`으로 변경 | 빈 화면 |
| 위 + `daumcdn.net`·`kakaocdn.net`·`daum.net` 허용 | 빈 화면 |

**logcat에 cleartext 차단 오류가 한 줄도 남지 않는다.** 조용히 비어버려서
무엇이 막혔는지 로그로는 알 수 없었다. 이게 세 번의 시도가 전부 추측이
될 수밖에 없었던 이유다.

### 배경

지도는 WebView이고 `MapService.initialize`가 그 origin을
`http://localhost:5000`으로 지정한다. 카카오 개발자 콘솔에 등록된
JavaScript SDK 도메인과 일치해야 해서 http를 쓴다.

### 다음에 할 일 — 추측하지 말고 먼저 볼 것

1. **WebView의 네트워크 오류를 먼저 확보한다.** 이것 없이 설정만 바꿔보는
   건 시간 낭비였다. 방법은 두 가지다.
   - `WebView.setWebContentsDebuggingEnabled(true)`를 켜고 PC 크롬의
     `chrome://inspect`로 기기 WebView에 붙어 Network 탭에서 **실제로
     차단된 요청**을 본다. (가장 확실)
   - 또는 `KakaoMapWidget`에 임시로 콘솔 메시지 핸들러를 달아 로그를 본다.
2. 차단된 호스트를 확인한 뒤 그 호스트만 예외에 추가한다.
3. 카카오 개발자 콘솔에 `https://localhost:5000`을 **추가 등록**한 뒤
   origin을 https로 바꾸는 것도 후보다(등록 없이 바꿨을 땐 실패했다).

### 급하지 않은 이유

서버 배포에는 영향이 없다. 백엔드가 HTTPS가 되면 앱이 평문으로 주고받는
것은 지도 WebView뿐이고, 그건 공개된 지도 타일이라 가로채여도 잃을 것이
없다. 스토어 심사 전에만 끝내면 된다.
