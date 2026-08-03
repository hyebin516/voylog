# CLAUDE.md

이 파일은 Claude Code가 본 프로젝트에서 작업할 때 참고하는 최상위 가이드입니다. 각 서비스 디렉토리(`travel_youtube_app/`, `backend/`, `ai-worker/`, `database/`)에는 해당 계층 전용 CLAUDE.md가 별도로 있으니 그쪽 작업 시 함께 참고하세요.

## 프로젝트 개요

**여행 유튜브 요약 서비스** — 유튜브 여행·브이로그 영상을 분석하여 영상 속 등장 장소를 자동 추출하고, 사용자가 선택한 시작/종료 호텔을 기준으로 북마크한 장소들을 순회하는 최적 동선(왕복 또는 호텔 간 이동)을 AI가 계획해주는 여행 일정 플래너 서비스. Clean Architecture(계층 분리)를 따른다.

- **팀명**: 럭키비키 (팀장: 김혜빈 / 팀원: 최나경, 황현빈)
- **문서 버전**: v2.1 (시작/종료 호텔 분리, 표준 응답 포맷, LLM 폴백 규칙 반영)

### 핵심 사용자 흐름
1. 유튜브 URL 입력 또는 해시태그로 브이로그 탐색
2. 자막 추출 → LLM 장소 파싱 → Kakao Maps 좌표 변환 → 장소 카드 목록 제공
3. 타임스탬프 클릭(영상 이동), 지도 보기, 북마크
4. Kakao Maps로 시작 호텔·종료 호텔 선택 (같은 호텔을 선택하면 왕복, 다른 호텔이면 호텔 간 이동)
5. 북마크된 장소(2~10개) 기반 AI 동선 최적화 (시작 호텔 → 장소들 → 종료 호텔)

## 기술 스택

| 계층 | 기술 |
| --- | --- |
| 프론트엔드 (`travel_youtube_app/`) | Flutter (Dart, Android/iOS 네이티브), kakao_map_plugin(webview_flutter 기반 네이티브 지도), youtube_player_iframe, Provider, Dio, flutter_secure_storage |
| 메인 백엔드 (`backend/`) | Node.js, Express, PostgreSQL, Redis, JWT, Kakao OAuth |
| AI 워커 (`ai-worker/`) | Python, FastAPI, youtube-transcript-api, OpenAI API, Claude API, Kakao Maps API |
| 데이터베이스 (`database/`) | PostgreSQL (영구 저장), Redis (캐시) |
| 외부 API | YouTube Data API v3, Kakao Local/Maps/Mobility API, OpenAI GPT, Claude API, Kakao OAuth |

### 아키텍처 (3-Tier + Clean Architecture)
```
Flutter (travel_youtube_app/)
        │ REST API (JSON)
        ▼
Node.js Backend (backend/)
   - 인증(JWT/Kakao OAuth), 비즈니스 로직, DB/Redis, AI Worker 호출
        │ HTTP
        ▼
Python AI Worker (ai-worker/)
   - 자막 추출, LLM 호출(OpenAI→Claude 폴백), Kakao 지오코딩, 동선 최적화
        │
        ▼
OpenAI / Claude / YouTube / Kakao Maps
```

### 디렉토리 구조 (실제 레포 기준)
```
GradudtionProject/
  CLAUDE.md                # 이 파일 (전체 규칙)
  travel_youtube_app/      # Flutter 프론트엔드 (문서상 "frontend"에 대응)
  backend/                 # Node.js + Express
  ai-worker/               # Python + FastAPI
  database/                # 마이그레이션, 스키마 문서
  docs/                    # 기획/설계 문서
```

## 계층 책임 원칙

- 프론트엔드는 절대 비즈니스 로직을 갖지 않는다. UI/상태관리/API 호출만.
- 백엔드는 절대 OpenAI/Claude를 직접 호출하지 않는다. AI Worker(FastAPI)를 통해서만 LLM을 사용한다.
- AI Worker는 인증, DB 직접 접근(PostgreSQL), 북마크 저장, JWT 발급을 하지 않는다.
- DB 접근은 항상 Repository 계층을 통해서만 한다.
- 비즈니스 로직 중복 금지 — 동일 로직은 백엔드 또는 AI Worker 한 곳에만 존재해야 한다.

## 네이밍 규칙

| 대상 | 규칙 |
| --- | --- |
| DB 테이블/컬럼 | snake_case |
| REST API 필드 | camelCase |
| Flutter 변수/필드 | camelCase |
| 클래스명 | PascalCase |
| 상수 | UPPER_SNAKE_CASE |

## 표준 API 응답 포맷

성공:
```json
{ "success": true, "data": {} }
```
실패:
```json
{ "success": false, "error": { "code": "", "message": "" } }
```
- 배열 필드는 비어있어도 `[]`로 존재해야 함 (필드 생략 금지).
- 알 수 없는 값은 빈 문자열이 아닌 `null` 사용.

## 백엔드 API 명세 (핵심)

| Method | Endpoint | 인증 | 설명 |
| --- | --- | --- | --- |
| POST | `/api/v1/videos/analyze` | 불필요 | YouTube URL 분석. body: `{ youtubeUrl }` |
| POST | `/api/v1/bookmarks` | 필수 (JWT) | 북마크 저장. body: `{ placeId }` |
| GET/DELETE | `/api/v1/bookmarks`, `/api/v1/bookmarks/:id` | 필수 (JWT) | 북마크 조회/삭제 |
| POST/GET/PUT/DELETE | `/api/v1/hotels`, `/api/v1/hotels/:id` | 필수 (JWT) | 호텔 CRUD |
| POST | `/api/v1/itineraries` | 필수 (JWT) | 동선 생성. body: `{ startHotelId, endHotelId, placeIds[] }` (장소 최소 2개, 최대 10개). `startHotelId == endHotelId`면 왕복(roundTrip), 다르면 호텔 간 이동(hotelToHotel)으로 서버가 자동 판별. 구버전 호환: `{ hotelId }`만 오면 `startHotelId = endHotelId = hotelId`로 취급 |
| POST | `/api/v1/auth/kakao` | 불필요 | Kakao OAuth 로그인 → JWT 발급 |
| GET | `/api/v1/auth/profile` | 필수 (JWT) | 내 정보 조회 |

### 주요 오류 코드
- `400` INVALID_URL / 유효하지 않은 요청 / 장소 2개 미만
- `401` JWT_INVALID / 미인증
- `403` JWT_EXPIRED
- `409` BOOKMARK_EXISTS
- `422` TRANSCRIPT_NOT_FOUND (자막 없는 영상)
- `500` 내부 오류
- `503` AI_TIMEOUT / AI_PROVIDER_ERROR / GEOCODING_FAILED (외부 API 실패)

## DB 스키마 (핵심 테이블)

모든 PK는 UUID, 모든 테이블에 `created_at`/`updated_at`(TIMESTAMPTZ) 포함, 하드 삭제 대신 `deleted_at` 소프트 삭제 원칙.

- **users**: `user_id(PK)`, `provider`(kakao), `provider_id`(UNIQUE), `email`(nullable), `nickname`, `profile_image`, `created_at`, `updated_at`
- **videos**: `video_id(PK)`, `youtube_url`(UNIQUE), `title`, `description`, `thumbnail_url`, `channel_name`, `published_at`, `duration_sec`, `language`, `is_analyzed`, `analysis_version`, `created_at`, `updated_at`
- **places**: `place_id(PK)`, `video_id(FK)`, `name`, `address`, `latitude`, `longitude`, `timestamp_sec`, `source`(transcript/hashtags/description/title), `confidence`(0~1), `created_at`, `updated_at`
- **hotels**: `hotel_id(PK)`, `user_id(FK)`, `name`, `address`, `latitude`, `longitude`(NOT NULL — Kakao Maps 검색으로만 저장), `created_at`, `updated_at`
- **bookmarks**: `bookmark_id(PK)`, `user_id(FK)`, `place_id(FK)`, `created_at`, UNIQUE(`user_id`, `place_id`)
- **itineraries**: `itinerary_id(PK)`, `user_id(FK)`, `start_hotel_id(FK → hotels.hotel_id)`, `end_hotel_id(FK → hotels.hotel_id)`, `route_type`(roundTrip | hotelToHotel, `start_hotel_id == end_hotel_id`일 때 roundTrip), `optimization_priority`(duration), `total_distance_m`, `total_duration_sec`, `route_data`(JSONB), `created_at`, `updated_at`

인덱스: `youtube_url`, `provider_id`, `video_id`, `user_id`, `place_id`, `hotel_id`, `start_hotel_id`, `end_hotel_id`, `created_at` + 복합 인덱스 `(user_id, place_id)`, `(video_id, timestamp_sec)`.

## 핵심 처리 로직

### 영상 분석 (7단계)
1. URL 수신·유효성 검증 (실패 시 400)
2. `videos` 캐시 조회 (`is_analyzed = true`면 3~6 건너뜀)
3. `youtube-transcript-api`로 자막 추출 (없으면 422)
4. 자막+메타데이터(제목/설명/해시태그) → LLM 파싱 (실패 시 재시도 후 503)
5. Kakao Local API로 좌표 변환 (실패 시 lat/lng/address = null, 전체 분석은 중단하지 않음)
6. `videos`, `places` 저장 및 `is_analyzed = true`
7. 결과 반환

### 동선 최적화 (시작/종료 호텔 기반)
1. `startHotelId`, `endHotelId` + `placeIds` 최소 2개, 최대 10개 검증. 둘 다 요청 사용자 소유 호텔이어야 함
2. `route_type`을 서버에서 자동 판별: `startHotelId == endHotelId` → `roundTrip`, 다르면 → `hotelToHotel` (클라이언트가 보낸 routeType은 신뢰하지 않음)
3. 시작 호텔·종료 호텔·각 장소 좌표 조회 (좌표 없는 장소는 제외)
4. Kakao Mobility(길찾기) API로 이동 시간 계산, 실패 시 Haversine 직선거리로 대체
5. 시작 호텔과 종료 호텔을 고정 양 끝점으로 유지한 채 장소들의 방문 순서만 TSP 스타일로 최적화: 시작 호텔(출발) → 장소들 → 종료 호텔(도착), 10개 초과는 최적화 대상에서 제외
6. `itineraries`(route_data는 JSONB) 저장 후 반환

## LLM 규칙

- 백엔드는 LLM을 직접 호출하지 않는다. 반드시 AI Worker를 통한다.
- 공급자 모드: `auto`(기본) / `openai` / `claude`. auto는 OpenAI 우선, 재시도 1회 → 실패 시 Claude, 재시도 1회 → 그래도 실패 시 503(AI_PROVIDER_ERROR).
- LLM 응답은 JSON만 허용 (마크다운/설명/코드블록 금지). 유효하지 않으면 동일 공급자 재시도 1회 → 공급자 전환 → 그래도 실패면 AI_PROVIDER_ERROR.
- LLM은 절대 좌표를 생성하지 않는다. 좌표는 오직 Kakao Maps 지오코딩 결과만 사용.
- 장소 추출 우선순위: transcript > hashtags > description > title. transcript 유래는 타임스탬프 포함, 메타데이터 유래는 `timestampSec = null`.

## 캐싱 전략

- 동일 YouTube URL은 DB(`videos`)에서 즉시 반환, LLM 재호출 금지.
- Redis 캐시 키: `video:{youtubeVideoId}`, TTL 7일, 값은 분석 결과 JSON. Redis는 사용자/북마크/호텔/동선을 저장하지 않는다.
- 조회 순서: Redis → PostgreSQL → AI Worker → 결과를 PostgreSQL과 Redis에 저장.

## 개발 규칙

- **비밀 정보**: API 키·토큰·OAuth 시크릿은 절대 커밋하지 않는다. `.env` 사용, `.gitignore` 확인. 로그에도 JWT/API 키/비밀번호를 남기지 않는다.
- **통신 보안**: 모든 API는 HTTPS. JWT 기반 인증.
- **커밋 메시지**: Conventional Commits(`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `style:`, `chore:`), 간결하게 한글 가능. 기능 단위로 커밋.
- **브랜치**: `main`, `develop`, `feature/*`, `fix/*`
- **주석/문서**: 새 기능 추가 시 요구사항 ID(FR-01 등)를 참조해 추적성 유지.
- 코드 작성 후에는 실제 요구사항(FR/NFR)과 매핑되는지 확인.

## 요구사항 참조

- **FR-01** URL 분석 / **FR-02** 해시태그 탐색 / **FR-03** 장소 카드 / **FR-04** 타임스탬프 이동
- **FR-05** 지도 보기(Kakao) / **FR-06** 북마크 / **FR-07** 시작/종료 호텔 기반 AI 동선(왕복·호텔 간 이동) / **FR-08** 소셜 로그인(Kakao) / **FR-09** 캐싱

## 자주 쓰는 명령어

```bash
# Flutter (travel_youtube_app/)
flutter pub get
cp .env.example .env   # 최초 1회, 실제 키 값 채워넣기 (travel_youtube_app/docs/KAKAO_SETUP.md 참고)
flutter run
flutter analyze
flutter test

# Backend (backend/)
npm install
npm run dev

# AI Worker (ai-worker/)
pip install -r requirements.txt
uvicorn app.main:app --reload
```
