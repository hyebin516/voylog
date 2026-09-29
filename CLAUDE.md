# CLAUDE.md

이 파일은 Claude Code가 본 프로젝트에서 작업할 때 참고하는 최상위 가이드입니다. 각 서비스 디렉토리(`travel_youtube_app/`, `backend/`, `ai-worker/`, `database/`)에는 해당 계층 전용 CLAUDE.md가 별도로 있으니 그쪽 작업 시 함께 참고하세요.

## 프로젝트 개요

**여행 유튜브 요약 서비스** — 유튜브 여행·브이로그 영상을 분석하여 영상 속 등장 장소를 자동 추출하고, 사용자가 만든 "여행(trip)" 아래 여러 날짜(1일차, 2일차...)로 나눠 각 날짜마다 시작/종료 호텔을 기준으로 북마크한 장소들을 순회하는 최적 동선(왕복 또는 호텔 간 이동)을 AI가 계획해주는 여행 일정 플래너 서비스. Clean Architecture(계층 분리)를 따른다.

- **팀명**: 럭키비키 (팀장: 김혜빈 / 팀원: 최나경)
- **문서 버전**: v2.8 (여행 공유 링크·동선 공유 피드 — FR-20/FR-21 반영)

### 핵심 사용자 흐름
1. 유튜브 URL 입력 또는 해시태그로 브이로그 탐색
2. 자막 추출 → LLM 장소 파싱(카테고리·영업시간·세부 태그 추정 포함) → Kakao Maps 좌표 변환 → 장소 임베딩 생성·캐싱 → 장소 카드 목록 제공
3. 타임스탬프 클릭(영상 이동), 지도 보기, 북마크
4. 여행(trip) 생성 후, 날짜(1일차, 2일차...)마다 Kakao Maps로 시작 호텔·종료 호텔 선택 (같은 호텔을 선택하면 왕복, 다른 호텔이면 호텔 간 이동 — 날짜마다 다르게 선택 가능, 예: 1일차 A호텔→B호텔, 2일차 B호텔→B호텔)
5. 북마크된 장소(2~10개) 기반 AI 동선 최적화 (해당 날짜의 시작 호텔 → 장소들 → 종료 호텔), 날짜별로 반복하여 하나의 여행에 누적 저장
6. (선택) 마이페이지에서 고정 태그 목록 중 취향 태그를 선택하면 취향 임베딩 생성(건너뛰기/초기화 가능) — 같은 태그 목록이 장소 태그 추출과 취향 설문에 공통으로 쓰여 매칭이 가능
7. (선택) "내 주변 추천" — 현재 위치·시각 기반으로 반경 내 기존 places를 거리/시간대/영업여부(추정) + (취향 설정 시) 임베딩 유사도·세부 태그 일치도로 정렬해 추천. 로그인 불필요 — 비회원·취향 미설정 사용자는 상황 기반으로만 정렬, 신호가 있을 때만 가중치에 반영(없는 신호의 비중은 나머지 신호로 재분배)

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
| GET | `/api/v1/videos/search` | 불필요 | 해시태그로 브이로그 탐색 (FR-02). query: `?hashtag=`. AI Worker의 YouTube Data API 검색 결과(영상 후보 목록)를 그대로 전달, DB 저장 없음 |
| POST | `/api/v1/videos/recommendations` | 불필요 | 지역/테마/기간 선택 기반 브이로그 추천 마법사. body: `{ regions[], themes[], duration }` (`duration`은 `당일치기 / 1박 2일 / 2박 3일 / 3박 4일 / 4박 5일 이상` 중 하나). 서버가 지역+테마+기간을 하나의 검색어로 조합해 AI Worker의 YouTube Data API 키워드 검색(`/search-videos`)을 호출 — 해시태그 탐색과 동일한 검색 인프라 재사용, 응답 형식도 동일(`{ videos: [] }`), DB 저장 없음 |
| POST | `/api/v1/bookmarks` | 필수 (JWT) | 북마크 저장. body: `{ placeId }` |
| GET/DELETE | `/api/v1/bookmarks`, `/api/v1/bookmarks/:id` | 필수 (JWT) | 북마크 조회/삭제 |
| POST/GET | `/api/v1/bookmark-folders` | 필수 (JWT) | 북마크 폴더 생성 body: `{ name }` / 내 폴더 목록 조회 (각 폴더에 `bookmarkCount` 포함) |
| DELETE | `/api/v1/bookmark-folders/:id` | 필수 (JWT) | 폴더 삭제(소프트 삭제, 소속 북마크 자체는 삭제되지 않음) |
| GET | `/api/v1/bookmark-folders/:id/bookmarks` | 필수 (JWT) | 폴더에 담긴 북마크(장소) 목록 조회 |
| POST | `/api/v1/bookmark-folders/:id/bookmarks` | 필수 (JWT) | 폴더에 북마크 추가. body: `{ bookmarkId }`. 북마크 하나가 여러 폴더에 동시에 속할 수 있음(다대다 태그 방식) |
| DELETE | `/api/v1/bookmark-folders/:id/bookmarks/:bookmarkId` | 필수 (JWT) | 폴더에서 북마크 제거(북마크 자체는 유지) |
| POST | `/api/v1/bookmark-folders/:id/route` | 필수 (JWT) | 폴더에 담긴 북마크 장소만으로 **호텔 없이** 최소 이동시간 동선 생성. body 없음. 좌표가 있는 장소만 사용(최대 10곳), 2곳 미만이면 400 INVALID_REQUEST. AI Worker `/optimize-place-route`가 **열린 경로**(첫·마지막 장소도 최적화 대상, 중심점 왕복 없음)로 순서를 정하고, **구간마다 도보 15분 이하면 도보, 넘으면 버스**(`WALK_LEG_MAX_SEC`, Kakao 대중교통 경로 — 별도 버스 데이터 불필요) — 무조건 도보로 짜면 폴더 장소 사이에 도보 61분 구간이 나왔음. 버스 경로는 도보가 긴 구간만 조회하고, 버스가 걷기보다 느리면 도보 유지(직선거리로 지어낸 버스 구간은 만들지 않음). **버스가 아예 없는 긴 구간은 자동차로 떨어진다** — 도보 15분을 넘긴 시점에 이미 "걷기엔 먼 구간"으로 판정했는데 버스가 없다고 도보로 되돌리면, 서로 다른 도시의 북마크 사이에서 `도보 3393분`(56시간)이 나왔다(카카오 도보·대중교통 조회가 둘 다 실패해 직선거리를 도보 속도로 나눈 값). 자동차 조회는 **버스가 없는 구간에만** 하고(호출 수 절약), 자동차마저 실패하면 그때는 도보 추정치를 그대로 둔다(지어낸 주행 구간보다 눈에 띄게 이상한 숫자가 낫다). 응답은 뚜벅이 코스와 같은 `{ course, recommendations: [] }` 형태(`routeType: "placeToPlace"`, `transportMode`는 전 구간 도보면 `walk`, 아니면 `mixed`, 각 지점에 `legTransportMode`(walk/transit/car), 버스 구간이면 `legGuidance`, 그리고 **실제 도로를 따라가는 좌표 배열 `legPath`**(`[[위도, 경도], ...]`)("614번 · 점등이 → 온양온천역 입구"))라 `WalkingCourseResultScreen`을 그대로 재사용(구간별 "도보 N분" / "버스 N분 · 614번 · …"). `recommendations`는 항상 빈 배열(사용자가 직접 고른 장소). "내 코스"로 저장·피드 게시 가능(마이그레이션 028) |
| POST/GET/PUT/DELETE | `/api/v1/hotels`, `/api/v1/hotels/:id` | 필수 (JWT) | 호텔 CRUD |
| POST/GET | `/api/v1/trips` | 필수 (JWT) | 여행 생성 body: `{ name }` / 내 여행 목록 조회 (각 여행에 `dayCount` 포함) |
| GET/DELETE | `/api/v1/trips/:id` | 필수 (JWT) | 여행 상세(날짜별 동선 목록 `days[]`) 조회 / 여행 삭제(소속 날짜 동선도 함께 소프트 삭제) |
| POST | `/api/v1/itineraries` | 필수 (JWT) | 여행의 특정 날짜 동선 생성. body: `{ tripId, dayNumber, startHotelId, endHotelId, placeIds[], transportMode? }` (장소 최소 2개, 최대 10개). `tripId`는 요청 사용자 소유 여행이어야 하고, 같은 `tripId`+`dayNumber` 조합은 하나만 존재 가능(중복 시 409 DAY_EXISTS). `startHotelId == endHotelId`면 왕복(roundTrip), 다르면 호텔 간 이동(hotelToHotel)으로 서버가 자동 판별 — 날짜마다 독립적으로 판별되므로 같은 여행 안에서도 날짜별로 다를 수 있음. `transportMode`는 `car`(기본) | `walk` | `transit` 중 하나(생략 시 `car`) — 이동수단에 따라 AI Worker가 다른 Kakao 경로 API로 시간·거리를 계산. 구버전 호환: `{ hotelId }`만 오면 `startHotelId = endHotelId = hotelId`로 취급 |
| GET/PUT | `/api/v1/notification-settings` | 필수 (JWT) | 알림 설정 조회(저장된 값이 없으면 기본값 반환) / 수정. body(PUT): `{ tripStartAlerts, routeCompleteAlerts, marketingAlerts, nightSilent }` (모두 boolean 필수). "전체 알림" 마스터 토글은 별도 DB 컬럼 없이 프론트에서 4개 값이 전부 켜져 있는지로만 판단하는 UI 전용 파생 상태(두 개의 진실 공급원이 생기는 걸 방지). 이 설정값은 실제 푸시 발송 시 `push.service.js`가 매번 확인함(아래 "푸시 알림" 참고) |
| POST | `/api/v1/device-tokens` | 필수 (JWT) | FR-12 푸시 대상 기기 등록. body: `{ token, platform }`(`platform`은 `android` \| `ios`). 같은 token이 이미 있으면 **user_id를 새 사용자로 옮김**(한 휴대폰에 다른 계정이 로그인하면 이전 사용자의 알림이 그 기기로 가면 안 됨) |
| DELETE | `/api/v1/device-tokens/:token` | 필수 (JWT) | 로그아웃/회원탈퇴 시 해당 기기 등록 해제. 토큰은 URL 인코딩해서 보냄(FCM 토큰에 `:`·`/`가 들어감) |
| POST | `/api/v1/recommendations/nearby` | 선택 (JWT, 미인증도 허용) | 위치·시간 기반 주변 장소 추천. body: `{ latitude, longitude, localTime, radiusMeters?, limit?, categoryGroup? }` (`localTime`은 ISO 8601, 기기의 로컬 시각 그대로 — 시간대 변환 없이 요일/시각 판단에 사용). `categoryGroup`(`restaurant`=restaurant/dessert/bar | `cafe`=cafe/bakery | `play`=attraction/museum/gallery/shopping/beach/night_view/other)은 화면의 음식점/카페/놀거리 탭 — **점수화 전에 서버가 후보를 거름**(클라이언트가 상위 20개만 받아 거르면 저녁엔 시간대 가중치로 음식점만 올라와 카페·놀거리 탭이 비어 버림). 서버가 로그인 사용자면 먼저 `recommendation_behaviors`에서 hide/not_interested 처리한 장소 id를 조회해 후보에서 제외하고, `places`에서 반경 내 나머지 후보(임베딩·태그 포함)를 조회, `user_preference_embeddings`(임베딩+`tag_scores` — 학습된 값이 없으면 `source_tags`를 1.0으로 대체)도 함께 조회해 AI Worker(`/recommendations/nearby-score`)로 전달 — 거리/시간대/영업여부(LLM 추정) + (양쪽에 임베딩이 있을 때만) 코사인 유사도 + (양쪽에 태그가 있을 때만) 학습된 선호도 가중 태그 일치도를 결합해 점수·정렬·매칭된 태그 목록·추천 이유(템플릿 문장) 계산. 각 신호는 있을 때만 가중치에 포함되고 없는 신호의 비중은 나머지 신호로 자동 재분배. 정렬 후 상위 N개를 자르기 전에 **같은 곳의 다른 표기(300m 이내·같은 카테고리·이름 포함/앞부분 겹침, `app/utils/place_similarity.py`)는 한 장만 남김** — 뚜벅이 코스와 같은 규칙. 각 추천 항목은 `address`·`businessHours`·`businessHoursIsEstimated`·`tags`도 함께 반환 — 카드를 누르면 여는 장소 상세 화면이 재조회 없이 그대로 채워짐(예전엔 이름과 좌표만 넘겨 주소·카테고리·영업시간 칸이 비어 있었음). `/recommendations/similar-taste`도 같은 이유로 `address` 포함 |
| POST | `/api/v1/recommendations/behaviors` | 필수 (JWT) | 추천 장소에 대한 사용자 행동 기록(FR-15 행동 기반 자동 학습). body: `{ placeId, action, screen?, distanceMeters? }` — `action`은 `view_detail`(+1)/`map_view`(+2)/`share`(+3)/`bookmark`(+4)/`add_to_itinerary`(+5)/`like`(+5)/`hide`(-4)/`not_interested`(-5) 중 하나(가중치는 `backend/src/services/behavior-scoring-policy.js`에 고정). `recommendation_behaviors`에 원본 이벤트를 남긴 뒤, 장소 임베딩·태그를 가중치(같은 사용자·장소·행동 반복 시 `1/sqrt(과거횟수+1)`로 감쇠) 적용해 AI Worker(`/embeddings/update-preference`)로 사용자 선호 임베딩을 갱신하고 `tag_scores`(태그별 학습된 선호 강도, [-2, 2] 클램프)도 함께 갱신. hide/not_interested는 이후 `/recommendations/nearby`에서 해당 장소를 아예 후보에서 제외(스코어 감점이 아닌 필수 필터). 위도/경도·이동 경로는 저장하지 않음(반경 버킷만) |
| GET | `/api/v1/taste-preferences` | 필수 (JWT) | 내 취향 태그 조회. 저장된 값이 없으면 `{ tags: [] }` 반환(설문을 건너뛴 상태) |
| PUT | `/api/v1/taste-preferences` | 필수 (JWT) | 취향 태그 설정/수정. body: `{ tags: string[] }` (1개 이상). 서버가 태그를 하나의 문장으로 합쳐 AI Worker(`/embeddings/generate`)로 임베딩을 생성해 `user_preference_embeddings`에 저장 |
| DELETE | `/api/v1/taste-preferences` | 필수 (JWT) | 취향 설정 초기화(행 삭제) — 이후 추천은 다시 비개인화 상태로 동작 |
| POST | `/api/v1/recommendations/walking-course` | 선택 (JWT, 미인증도 허용) | 지역 기반 도보 코스 자동 생성(FR-17). body: `{ region, localTime, mood?, walkDuration?, hotelId? }` (`region`은 프론트 고정 지역 목록 중 하나). 서버가 AI Worker(`/geocode`)로 지역 중심 좌표를 구한 뒤, `places`에서 그 좌표 반경 내 **전체 사용자의 북마크된 장소**만 후보로 조회(`bookmarkedOnly`, 특정 사용자가 아님 — 콜드스타트 대응)하고, 로그인 사용자면 취향 임베딩/`tag_scores`도 함께 AI Worker(`/recommendations/walking-course`)로 전달 — AI Worker가 Kakao 상권 검색(카페/음식점/관광명소) 후보를 보강하고, `/recommendations/nearby-score`와 동일한 점수화 로직으로 전체 후보 점수를 매긴 뒤 점수 높은 순으로 훑으며 이미 선택된 장소와 도보 거리(1.2km) 이내인 것만 채택하는 그리디 클러스터링으로 2~10개를 뽑아 walk 모드 `/optimize-route`로 순서를 최적화해 반환. `hotelId`(선택, 로그인 사용자의 소유 호텔이어야 하며 아니면 404 HOTEL_NOT_FOUND)를 주면 그 호텔을 시작=종료 지점으로 쓰고, 주지 않으면 지역 중심점을 시작=종료 **가상** 지점(`hotelId: "region-center"`, 이름은 지역명)으로 씀 — 실제 `hotels` 테이블에 저장하지 않는 임시 값이라 프론트는 이 sentinel로 "호텔 미선택"을 구분해 코스 카드/마커에서 숨기고 호텔 선택 안내를 띄운다. 서로 도보 거리인 장소가 2개 미만이면 `course: null` + 점수화된 후보 목록만 반환(에러 아님) |
| POST/GET | `/api/v1/walking-courses` | 필수 (JWT) | 위 도보 코스 생성 결과를 "내 코스 목록"에 저장. body(POST): `{ region, routeType, transportMode, totalDistanceM?, totalDurationSec?, routeData[] }` — trip/hotel과 무관한 독립적인 스냅샷 저장(Kakao 상권 후보처럼 `places` 테이블에 없는 장소도 `routeData`에 그대로 저장 가능, FK 제약 없음) / 내 저장 코스 목록 조회 |
| DELETE | `/api/v1/walking-courses/:id` | 필수 (JWT) | 저장한 코스 삭제(소프트 삭제). 요청 사용자 소유가 아니면 404 SAVED_COURSE_NOT_FOUND |
| POST | `/api/v1/walking-courses/:id/publish` | 필수 (JWT) | FR-21 저장한 뚜벅이 코스를 공개 피드에 게시. body: `{ title }`(1~100자). 요청 사용자 소유가 아니면 404 SAVED_COURSE_NOT_FOUND, 이미 게시된 코스면 409 ALREADY_PUBLISHED(재게시 불가 — 멱등하지 않게 중복 행이 쌓이는 걸 막음). `shared_routes`에 새 행 생성(호텔 포인트는 원래 없음 — 지역 중심 가상 좌표라 그대로도 안전) |
| POST | `/api/v1/itineraries/:id/publish` | 필수 (JWT) | FR-21 여행의 특정 날짜 동선을 공개 피드에 게시. body: `{ title }`(1~100자). 요청 사용자 소유가 아니면 404 ITINERARY_NOT_FOUND, 이미 게시된 동선이면 409 ALREADY_PUBLISHED. `route_data`에서 호텔 포인트(실제 숙소 주소 FK)를 통째로 제거하고 남은 장소들만 재정렬·leg 재계산한 스냅샷을 `shared_routes`에 저장(`buildPublicRouteSnapshot`, `backend/src/utils/route-snapshot.js`) |
| GET | `/api/v1/routes/shared` | 선택 (JWT, 미인증도 허용) | FR-21 공개 동선 피드 조회. query: `?limit?`(기본 20, 최대 50). **본인이 게시한 동선도 피드에 그대로 포함**(로그인 사용자면 각 행에 `isOwner` 포함 — 프론트가 이 값으로 본인 카드는 수정/삭제 UI, 남의 카드는 좋아요 UI를 분기). 작성자별 `matchPercent`(요청 사용자 ↔ 작성자의 취향 임베딩 코사인 유사도 — 둘 다 취향 설정이 있을 때만, AI Worker `/embeddings/similarity`로 일괄 계산, 본인 카드는 자기 자신과 비교하지 않으므로 항상 `null`)를 함께 반환. 좋아요 수는 `route_likes` 테이블 COUNT로 항상 실시간 계산(별도 카운터 컬럼 없음) |
| POST/DELETE | `/api/v1/routes/:id/like` | 필수 (JWT) | FR-21 공개 동선 좋아요/좋아요 취소. 존재하지 않는 동선이면 404 SHARED_ROUTE_NOT_FOUND, 본인이 게시한 동선이면 400 INVALID_REQUEST(좋아요만 해당, 취소는 멱등). **좋아요는 그 동선에 담긴 각 장소(`route_data[].placeId`)에 대해 FR-15 행동 기반 학습(`POST /recommendations/behaviors`)의 `like` 액션을 그대로 재사용해 좋아요 누른 사용자의 취향 임베딩·`tag_scores`를 갱신**(장소마다 `recommendation_behaviors` 행도 함께 남음, `screen: 'shared_route_feed'`) — **좋아요 취소 시 이 취향 갱신도 함께 되돌림**(가장 최근 매칭 행동 로그 행을 삭제한 뒤 같은 유효 가중치를 음수로 다시 적용, `behaviorService.reverseScopedBehavior`) — 단, 정확한 취소를 보장하진 않음(그사이 다른 행동으로 취향 벡터가 또 갱신됐으면 근사치, 임베딩 정규화가 비선형이라 완벽한 역산은 원래 불가능) |
| PATCH | `/api/v1/routes/:id` | 필수 (JWT) | FR-21 게시한 동선 제목 수정. body: `{ title }`(1~100자). 요청 사용자 소유가 아니면 404 SHARED_ROUTE_NOT_FOUND |
| DELETE | `/api/v1/routes/:id` | 필수 (JWT) | FR-21 게시 취소(소프트 삭제). 요청 사용자 소유가 아니면 404 SHARED_ROUTE_NOT_FOUND |
| GET | `/api/v1/trips/:id/share` | 불필요 | FR-20 여행 공유 링크가 여는 공개 조회 페이지. 인증 없이 누구나 열람 가능한 서버 렌더링 HTML(JSON 아님) 반환 — 존재하지 않는 여행이면 404 TRIP_NOT_FOUND(JSON 에러). 날짜별 동선을 순서대로 보여주되 호텔은 **이름만**(주소·좌표 제외) 노출 — 공개 피드(FR-21)보다 좁은 배포 범위(링크를 받은 특정 사람만 앎)라 프라이버시 기준이 다름 |
| GET | `/api/v1/recommendations/similar-taste` | 필수 (JWT) | 취향이 비슷한 사용자가 북마크한 장소 추천(FR-18). query: `?limit?`(기본 20, 최대 50). 요청 사용자의 `user_preference_embeddings`가 없으면 `{ recommendations: [], hasPreference: false }` 반환(에러 아님 — 프론트가 취향 설정 화면으로 안내). 있으면 다른 모든 사용자의 임베딩을 조회해 AI Worker(`/recommendations/similar-taste-score`)로 전달, 코사인 유사도 0.3 이상인 사용자들의 북마크만 신호로 채택(유사도 합산으로 장소 점수 계산, 여러 유사 사용자가 북마크했을수록 점수↑) — 요청 사용자가 이미 북마크했거나 숨긴 장소는 후보에서 제외 |
| GET | `/api/v1/places/:id/summary` | 불필요 | 여러 브이로그를 참고한 장소 장단점 한 줄 요약(FR-19). 존재하지 않는 `placeId`면 404 PLACE_NOT_FOUND. 좌표를 반올림(소수점 4자리, ~11m)해 같은 실좌표를 공유하는 다른 영상 유래 `places` 행들(=같은 실제 장소를 언급한 다른 영상)을 모아 `mention_note`가 있는 것만 모으고, 서로 다른 `video_id` 개수가 2 미만이면 `{ available: false, pros: null, cons: null, sourceCount }` 반환(에러 아님 — 아직 비교할 다른 영상이 부족함). 2개 이상이면 캐시(`places.pros_summary`/`cons_summary`/`summary_source_count`) 유효성을 확인(라이브 소스 개수와 캐시된 개수가 다르면 무효화)해, 무효하거나 없으면 AI Worker(`/places/summarize`)로 각 노트를 종합한 장점/단점 한 줄 요약을 생성해 해당 `place_id` 행에 캐싱 후 반환 |
| POST | `/api/v1/support-inquiries` | 선택 (JWT, 미인증도 허용) | FR-13 고객센터 문의 접수. body: `{ email, category, message }` — `category`는 `analysis` \| `route` \| `account` \| `bug` \| `other`, `message`는 1~2000자(앞뒤 공백 제거 후 저장). **로그인하지 않아도 보낼 수 있다**(로그인이 안 되는 사람이야말로 문의가 필요함). 로그인 상태면 `user_id`도 함께 저장. `email`은 로그인 여부와 무관하게 항상 필수 — 카카오 계정은 이메일 동의항목이 없으면 주소가 없어 답장할 곳이 없기 때문. 저장을 먼저 하고 그 다음 `SUPPORT_EMAIL`로 메일 전달(전달 실패는 로그만 남기고 접수는 성공 — 메일 장애로 사용자가 쓴 내용을 잃지 않음), 메일의 `replyTo`는 문의자 주소라 답장이 곧 답변 |
| GET | `/api/v1/support-inquiries` | 필수 (JWT) | 내 문의 내역 조회(최신순). 비회원 문의는 조회 경로가 없음(소유자를 증명할 수단이 없음) |
| POST | `/api/v1/auth/kakao` | 불필요 | Kakao OAuth 로그인 → JWT 발급. 계정을 처음 만드는 경우 카카오 프로필 닉네임이 이미 다른 사용자가 쓰는 닉네임이면(카카오 닉네임은 앱 내에서 유니크가 보장되지 않음, 원탭 로그인이라 사용자에게 다른 닉네임을 고르게 할 수도 없음) 뒤에 숫자를 붙여(`닉네임2`, `닉네임3`, ...) 자동으로 유니크한 닉네임을 만들어 가입시킴. 이미 가입된 사용자로 다시 로그인하면 카카오가 준 **이메일만** 최신 값으로 갱신(동의항목을 나중에 추가한 경우 그때부터 채워짐) — **닉네임과 프로필 사진은 갱신하지 않음**. 닉네임은 가입 후 앱에서 바꾼 이름이 우선이고, 프로필 사진은 사용자가 자기 앨범에서 직접 고른 것이라 카카오 사진으로 덮으면 매 로그인마다 되돌아간다(카카오 사진은 **최초 가입 시 초기값**으로만 쓰임). 카카오가 동의를 못 받은 항목은 200 응답에서 필드가 그냥 빠지는데, 이건 "그 계정에 값이 없음"과 구분되지 않으므로 함께 오는 `<필드>_needs_agreement` 플래그를 읽어 경고 로그를 남긴다(선택 동의 항목은 기존 사용자에게 재로그인만으로는 다시 묻지 않음 — `loginWithNewScopes` 또는 앱 연결 해제 후 재동의가 필요). 갱신 실패(예: 그 이메일을 쓰는 다른 계정)는 로그만 남기고 로그인은 그대로 진행 |
| GET | `/api/v1/auth/check-nickname` | 불필요 | 회원가입 화면의 닉네임 중복확인. query: `?nickname=`. 응답 `{ available: boolean }`(에러 아님, 사용 중이어도 200) |
| POST | `/api/v1/auth/signup/request-otp` | 불필요 | 네이티브 회원가입 1단계: body `{ email }`. 이미 가입된 이메일이면 409 EMAIL_EXISTS. 6자리 인증코드를 생성해 SMTP로 이메일 발송(5분 유효) |
| POST | `/api/v1/auth/signup/verify-otp` | 불필요 | 네이티브 회원가입 2단계: body `{ email, code }` (`code`는 6자리 숫자). 코드 불일치 시 400 OTP_INVALID(시도 횟수 누적), 만료·시도 초과·미발급 시 400 OTP_EXPIRED |
| POST | `/api/v1/auth/signup` | 불필요 | 네이티브 회원가입 3단계: body `{ email, password, nickname }` (`password` 8자 이상). 이미 가입된 이메일이면 409 EMAIL_EXISTS, 이미 쓰이는 닉네임이면 409 NICKNAME_EXISTS. 직전에 verify-otp로 인증된 이메일(15분 이내)이 없으면 400 OTP_NOT_VERIFIED. 성공 시 `users`(`provider='email'`)에 저장, 사용한 인증코드 삭제, JWT 발급(카카오 로그인과 동일 응답 형태: `{ token, user }`) |
| POST | `/api/v1/auth/login` | 불필요 | 네이티브 이메일/비밀번호 로그인. body `{ email, password }`. 일치하는 계정이 없거나 비밀번호 불일치(카카오 전용 계정 포함, `password_hash`가 없는 경우) 시 401 INVALID_CREDENTIALS |
| GET | `/api/v1/auth/profile` | 필수 (JWT) | 내 정보 조회. 응답에 `provider`(kakao \| email) 포함 — 프론트가 이 값으로 "카카오 계정 연동" 표시 여부·비밀번호 변경 UI 노출 여부를 판단 |
| PATCH | `/api/v1/auth/profile` | 필수 (JWT) | 닉네임 변경. body: `{ nickname }`(1~100자, 공백만은 불가). 다른 사용자가 이미 쓰는 닉네임이면 409 NICKNAME_EXISTS |
| PATCH | `/api/v1/auth/password` | 필수 (JWT) | 비밀번호 변경. body: `{ currentPassword, newPassword }`(`newPassword` 8자 이상). 카카오 전용 계정(`password_hash` 없음)이면 400 NO_PASSWORD_SET, `currentPassword`가 일치하지 않으면 401 INVALID_CREDENTIALS |
| POST | `/api/v1/auth/password/reset/request-otp` | 불필요 | 비밀번호 찾기 1단계(로그인 화면 "비밀번호를 잊으셨나요?"). body: `{ email }`. 가입되지 않은 이메일이면 404 EMAIL_NOT_FOUND, 카카오 전용 계정(`password_hash` 없음)이면 400 NO_PASSWORD_SET. 회원가입과 동일한 `email_otps` 인프라로 6자리 코드를 메일 발송(5분 유효) |
| POST | `/api/v1/auth/password/reset/verify-otp` | 불필요 | 비밀번호 찾기 2단계: body `{ email, code }`. 검증 로직은 회원가입 OTP와 동일(`verifyOtpCode` 공용) — 불일치 400 OTP_INVALID, 만료·시도초과 400 OTP_EXPIRED |
| POST | `/api/v1/auth/password/reset` | 불필요 | 비밀번호 찾기 3단계: body `{ email, newPassword }`(8자 이상). 직전에 verify-otp로 인증된 이메일(15분 이내)이 없으면 400 OTP_NOT_VERIFIED. 성공 시 `password_hash` 교체 + 해당 이메일의 인증코드 삭제. 현재 비밀번호를 묻지 않는다는 점이 `PATCH /auth/password`와 다름(잊어버린 사용자용) |
| PUT | `/api/v1/auth/profile/image` | 필수 (JWT) | 프로필 사진 업로드. `multipart/form-data`의 `image` 필드 하나(jpeg/png/webp, 최대 5MB). 앱이 기기에서 512px로 줄여 올리므로 실제로는 수십 KB. 파일은 `backend/uploads/profile-images/<userId>-<랜덤8바이트>.<확장자>`에 저장하고 `users.profile_image`에 `/uploads/...` 경로를 기록, 이전 파일은 DB를 먼저 갱신한 뒤 삭제(중간에 죽으면 고아 파일이 남을 뿐 아바타가 404가 되지는 않음). 확장자는 MIME에서 정하고 클라이언트가 보낸 파일명은 쓰지 않음(경로 조작 방지) |
| DELETE | `/api/v1/auth/profile/image` | 필수 (JWT) | 프로필 사진 삭제(기본 아바타로 복귀). 파일도 함께 지우며, 이미 없어도 성공 |
| DELETE | `/api/v1/auth/profile` | 필수 (JWT) | 회원 탈퇴 (users 소프트 삭제) |

고객센터의 FAQ는 여전히 프론트엔드 하드코딩(`lib/core/constants/customer_service_content.dart`)이고, **문의하기만 백엔드가 있다**(아래 두 엔드포인트). FAQ를 DB로 옮기지 않은 이유는 관리자 화면이 없어 수정 경로가 결국 배포뿐이기 때문.

### 주요 오류 코드
- `400` INVALID_URL / 유효하지 않은 요청 / 장소 2개 미만
- `401` JWT_INVALID / 미인증
- `403` JWT_EXPIRED
- `404` TRIP_NOT_FOUND (요청 사용자 소유가 아니거나 존재하지 않는 여행 — `GET /trips/:id/share`는 소유권과 무관하게 존재 여부만 확인) / FOLDER_NOT_FOUND (요청 사용자 소유가 아니거나 존재하지 않는 북마크 폴더) / SAVED_COURSE_NOT_FOUND (요청 사용자 소유가 아니거나 존재하지 않는 저장 도보 코스) / ITINERARY_NOT_FOUND (요청 사용자 소유가 아니거나 존재하지 않는 여행 동선 — 현재 게시 엔드포인트만 사용) / SHARED_ROUTE_NOT_FOUND (요청 사용자 소유가 아니거나 존재하지 않는 공개 동선) / PLACE_NOT_FOUND (존재하지 않는 장소) / EMAIL_NOT_FOUND (비밀번호 찾기에서 가입되지 않은 이메일) / HOTEL_NOT_FOUND (요청 사용자 소유가 아니거나 존재하지 않는 호텔)
- `400` OTP_INVALID / OTP_EXPIRED / OTP_NOT_VERIFIED (네이티브 회원가입 이메일 인증 관련) / NO_PASSWORD_SET (카카오 전용 계정으로 비밀번호 변경 시도 — 애초에 비밀번호가 없음)
- `401` INVALID_CREDENTIALS (네이티브 로그인 이메일/비밀번호 불일치, 또는 비밀번호 변경 시 현재 비밀번호 불일치)
- `409` BOOKMARK_EXISTS / DAY_EXISTS (해당 여행에 이미 존재하는 날짜) / EMAIL_EXISTS (이미 가입된 이메일로 회원가입 시도) / NICKNAME_EXISTS (다른 사용자가 이미 쓰는 닉네임으로 회원가입/닉네임 변경 시도) / ALREADY_PUBLISHED (해당 뚜벅이 코스/여행 동선이 이미 공개 피드에 게시돼 있음 — 같은 소스를 다시 게시 시도)
- `422` TRANSCRIPT_NOT_FOUND (자막 없는 영상)
- `500` 내부 오류
- `503` AI_TIMEOUT / AI_PROVIDER_ERROR / GEOCODING_FAILED / YOUTUBE_SEARCH_FAILED (외부 API 실패)

## DB 스키마 (핵심 테이블)

모든 PK는 UUID, 모든 테이블에 `created_at`/`updated_at`(TIMESTAMPTZ) 포함, 하드 삭제 대신 `deleted_at` 소프트 삭제 원칙.

- **users**: `profile_image`은 두 가지 형태를 가진다 — 카카오 CDN 절대 URL(가입 시 받은 것) 또는 `/uploads/profile-images/...` 상대 경로(사용자가 올린 것). API 응답은 상대 경로만 요청 호스트 기준 절대 URL로 바꿔 내보낸다(`profile-image.service.js`의 `toPublicUrl`) — 기기에서는 `adb reverse`의 localhost, 배포에서는 실제 호스트가 된다. `user_id(PK)`, `provider`(kakao | email), `provider_id`(kakao는 카카오 회원번호, email 계정은 `email`과 동일한 값 — email·nickname과 같이 `deleted_at IS NULL` 범위의 UNIQUE 부분 인덱스(마이그레이션 027). 001의 테이블 레벨 UNIQUE를 그대로 두면 탈퇴(소프트 삭제) 행이 남아 **같은 계정으로 재가입이 23505로 실패**했음 — 로그아웃은 DB를 건드리지 않으므로 무관), `email`(nullable — email 계정은 UNIQUE 부분 인덱스로 중복 가입 방지), `password_hash`(nullable — email 계정만 bcrypt 해시 보유, kakao 계정은 null), `nickname`(email·password와 동일하게 `deleted_at IS NULL` 범위의 UNIQUE 부분 인덱스로 중복 방지 — 탈퇴한 계정의 옛 닉네임은 다시 사용 가능), `profile_image`, `created_at`, `updated_at`
- **email_otps**: `otp_id(PK)`, `email`, `code_hash`(6자리 코드의 SHA-256 해시, 평문 미저장), `expires_at`(발급 5분 후), `verified_at`(nullable), `attempts`(기본 0, 5회 초과 시 만료 취급), `created_at` — 네이티브 회원가입 이메일 인증용. `POST /auth/signup` 성공 시 해당 이메일의 행을 모두 삭제(소프트 삭제 대상 아님, 단기 토큰성 데이터)
- **videos**: `video_id(PK)`, `youtube_url`(UNIQUE), `title`, `description`, `thumbnail_url`, `channel_name`, `published_at`, `duration_sec`, `language`, `is_analyzed`, `analysis_version`, `created_at`, `updated_at`
- **places**: `place_id(PK)`, `video_id(FK, nullable — 공공데이터 장소는 영상이 없음)`, `external_id`(VARCHAR, nullable — 공공데이터 원본 id, `(source, external_id)` UNIQUE로 재적재 시 중복 대신 갱신. `video_id`와 `external_id` 중 하나는 반드시 존재), `name`, `address`, `latitude`, `longitude`, `timestamp_sec`, `source`(transcript/on_screen_text/hashtags/description/title — 영상 유래, tour_api/semas — 공공데이터 유래, kakao_local — 뚜벅이 코스가 카카오 키워드 검색으로 찾은 장소를 사용자가 코스로 **보관할 때** 적재한 것(마이그레이션 032, 아래 "카카오 검색 장소 적재" 참고), 아래 "공공데이터 장소" 참고), `confidence`(0~1), `category`(nullable — LLM이 장소 추출 시점에 함께 추정, cafe/bakery/restaurant 등 자유 텍스트), `business_hours`(JSONB, nullable — LLM이 자막/설명에 명시된 영업시간만 추출, 언급 없으면 null이며 절대 추측하지 않음), `business_hours_is_estimated`(boolean, 기본 false — Kakao Local API는 영업시간을 제공하지 않아 항상 LLM 추정치임을 표시), `tags`(JSONB, nullable — `[{code, confidence}]` 배열, `code`는 `ai-worker/app/constants/tag_catalog.py`의 고정 목록 중 하나만 허용(새 태그마다 컬럼 추가하지 않기 위한 MVP 설계), 취향 설정 화면의 태그 목록과 동일한 어휘를 공유해야 매칭이 성립), `mention_note`(TEXT, nullable — 장소 추출 시점에 LLM이 자막에서 이 장소에 대한 실제 코멘트/반응을 1문장으로 뽑은 것, 의견이 없으면 null이며 절대 지어내지 않음. FR-19 장단점 요약의 원재료), `pros_summary`/`cons_summary`(TEXT, nullable — FR-19 캐시), `summary_source_count`(INTEGER, nullable — 캐시 생성 시점에 반영된 서로 다른 영상 개수, 캐시 무효화 판단에 사용), `summary_generated_at`(TIMESTAMPTZ, nullable), `created_at`, `updated_at`
- **hotels**: `hotel_id(PK)`, `user_id(FK)`, `name`, `address`, `latitude`, `longitude`(NOT NULL — Kakao Maps 검색으로만 저장), `created_at`, `updated_at`
- **bookmarks**: `bookmark_id(PK)`, `user_id(FK)`, `place_id(FK)`, `created_at`, UNIQUE(`user_id`, `place_id`)
- **bookmark_folders**: `folder_id(PK)`, `user_id(FK)`, `name`, `created_at`, `updated_at`, `deleted_at` — 사용자가 만드는 북마크 폴더
- **bookmark_folder_items**: `folder_id(FK → bookmark_folders.folder_id)`, `bookmark_id(FK → bookmarks.bookmark_id)`, `created_at`, PK(`folder_id`, `bookmark_id`) — 폴더↔북마크 다대다 조인 테이블(북마크 하나가 여러 폴더에 동시에 속할 수 있음, 태그 방식)
- **trips**: `trip_id(PK)`, `user_id(FK)`, `name`, `start_date`/`end_date`(DATE, nullable), `start_alert_sent_at`(TIMESTAMPTZ, nullable — FR-12 여행 시작 D-1 알림을 보낸 시각. 하루에도 여러 번 도는 스윕이 같은 여행을 다시 알리지 않도록 하는 표시), `created_at`, `updated_at` — 여러 날짜(itineraries)를 묶는 상위 "여행" 단위
- **device_tokens**: `token(PK — FCM 등록 토큰)`, `user_id(FK → users.user_id)`, `platform`(android | ios), `created_at`, `updated_at` — FR-12 푸시 대상 기기. PK가 토큰이라 한 사용자가 여러 기기를 가질 수 있고, 한 기기는 항상 마지막으로 로그인한 사용자 한 명에게만 속함
- **video_analysis_watchers**: `user_id(FK)`, `video_id(FK → videos.video_id)`, `created_at`, PK(`user_id`, `video_id`) — 백그라운드 보강이 끝났을 때 알려줄 사람. 알림을 보내면 그 영상 행들은 삭제됨(단기 큐라 소프트 삭제 대상 아님)
- **itineraries**: `itinerary_id(PK)`, `user_id(FK)`, `trip_id(FK → trips.trip_id, NOT NULL)`, `day_number(INTEGER, NOT NULL, > 0)` — 여행 내 몇 일차인지, `(trip_id, day_number)` UNIQUE(소프트 삭제 제외), `start_hotel_id(FK → hotels.hotel_id)`, `end_hotel_id(FK → hotels.hotel_id)`, `route_type`(roundTrip | hotelToHotel, `start_hotel_id == end_hotel_id`일 때 roundTrip), `optimization_priority`(duration), `transport_mode`(car | walk | transit, 기본 car — `route_type`과 독립적인 축, 이동수단에 따라 이동 시간·거리 계산 API가 달라짐), `total_distance_m`, `total_duration_sec`, `route_data`(JSONB), `created_at`, `updated_at`
- **notification_settings**: `user_id(PK, FK → users.user_id)`, `trip_start_alerts`(boolean, 기본 true — "여행 시작 알림", 마이그레이션 030에서 `new_vlog_alerts`를 이름만 바꿔 재사용. "새 브이로그 추천"은 사용자별로 매일 YouTube 키워드 검색을 돌려야 하고 "새 영상"의 기준도 없어서 드롭했고, 여행 시작일은 이미 `trips.start_date`에 있어 D-1 알림은 새 데이터가 필요 없음), `route_complete_alerts`(boolean, 기본 true — "동선 생성 완료"), `marketing_alerts`(boolean, 기본 false — "이벤트 및 마케팅 정보"), `night_silent`(boolean, 기본 false — "야간 알림 받지 않기"), `created_at`, `updated_at` — 사용자당 1행, 저장된 행이 없으면 API가 기본값을 즉석에서 반환(레코드 미리 생성 안 함)
- **place_embeddings**: `place_id(PK, FK → places.place_id)`, `embedding`(JSONB — float 배열, pgvector 미사용), `model`, `dimensions`, `source_text_hash`(재생성 필요 여부 판단용), `created_at`, `updated_at` — 장소 분석(영상 분석) 시점에 이름+카테고리+주소를 합친 텍스트로 자동 생성·캐싱, 임베딩 실패는 best-effort(전체 영상 분석을 막지 않음). 공공데이터 장소는 적재 시 임베딩을 만들지 않고, `/recommendations/nearby`에서 **취향 임베딩이 있는 사용자에게 후보로 뽑혔을 때만** AI Worker `/embeddings/generate-batch`로 한 번에 생성해 캐싱(`place-embedding.service.js`의 `ensurePlaceEmbeddings`, 수십만 건×1536차원을 미리 만들면 수십 GB·비용 낭비)
- **user_preference_embeddings**: `user_id(PK, FK → users.user_id)`, `embedding`(JSONB), `source_tags`(JSONB — 취향 설문에서 선택한 태그 원본), `source_text`, `model`, `dimensions`, `tag_scores`(JSONB, nullable — `{code: score}` 형태, 설문 선택 시 1.0으로 초기화되고 이후 행동 기록마다 가중치만큼 오르내림, [-2, 2] 클램프), `created_at`, `updated_at` — 사용자당 1행. 설문(`PUT /taste-preferences`) 또는 행동 기록(`POST /recommendations/behaviors`) 어느 쪽이든 최초 1회 생성될 수 있음(설문을 건너뛰어도 행동만으로 임베딩이 생성될 수 있음). 행이 없으면 "취향 미설정"으로 간주해 추천이 임베딩 없이 상황 기반으로만 동작
- **recommendation_behaviors**: `behavior_id(PK)`, `user_id(FK)`, `place_id(FK)`, `action`(view_detail | map_view | share | bookmark | add_to_itinerary | like | hide | not_interested), `screen`(nullable — 행동이 발생한 화면), `distance_bucket`(nullable — 원본 위/경도 대신 버킷 문자열만 저장, 예: `0-200m`), `model_version`(nullable), `created_at` — FR-15 행동 기반 자동 학습(phase 5)의 원본 로그. 위/경도·이동 경로는 저장하지 않음(개인정보 최소 수집 원칙)
- **saved_walking_courses**: `saved_course_id(PK)`, `user_id(FK)`, `region`, `route_type`(roundTrip | hotelToHotel | placeToPlace — 북마크 폴더 동선, 마이그레이션 028), `transport_mode`(car | walk | transit | mixed — 구간별 도보/버스, 기본 walk), `total_distance_m`, `total_duration_sec`, `route_data`(JSONB — 최적화된 경로 스냅샷), `created_at`, `updated_at` — FR-17 도보 코스 저장. `hotels`/`places`에 대한 FK가 없는 독립 스냅샷(Kakao 상권 검색으로 찾은, `places`에 없는 장소도 그대로 저장 가능하기 때문)
- **shared_routes**: `shared_route_id(PK)`, `user_id(FK)`, `source_type`(saved_walking_course | itinerary — 다형 출처, `source_id`는 표시용 메타일 뿐 FK 아님), `source_id`, `title`(1~100자, 게시 시 사용자가 직접 입력, `PATCH`로 수정 가능), `transport_mode`(car | walk | transit | mixed), `total_distance_m`, `total_duration_sec`, `place_count`, `route_data`(JSONB — 공개용으로 정제된 스냅샷: 호텔 포인트(이름·좌표·hotelId) 전부 제거, 장소는 `{order, type:'place', placeId, name, latitude, longitude, legDistanceM, legDurationSec}` — 장소 좌표는 공개된 장소라 유지하며 홈 피드 카드를 누르면 여는 **동선 상세 화면**(`SharedRouteDetailScreen`, 지도+장소 순서)에 쓰임. 좌표를 빼던 시절에 게시된 동선은 `node scripts/backfill-shared-route-coordinates.js`로 원본 코스/장소에서 채움), `created_at`, `updated_at`, `deleted_at` — FR-21 공개 동선 피드. `saved_walking_courses`/`itineraries`의 `route_data`를 그대로 공개하지 않고 게시 시점에 스냅샷을 새로 떠서 저장(원본이 나중에 바뀌거나 삭제돼도 피드에 영향 없음). `placeId`를 남겨두는 이유는 FR-21의 좋아요 → 취향 가중치 반영(FR-15 재사용)에 필요해서
- **support_inquiries**: `inquiry_id(PK)`, `user_id(FK → users.user_id, nullable — 비회원 문의)`, `email`(NOT NULL — 답변받을 주소), `category`(analysis | route | account | bug | other), `message`(TEXT), `created_at`, `updated_at`, `deleted_at` — FR-13 문의 접수 내역. 관리자 화면은 없고, 답변은 전달된 메일에 회신하는 방식
- **route_likes**: `user_id(FK)`, `shared_route_id(FK → shared_routes.shared_route_id)`, `created_at`, PK(`user_id`, `shared_route_id`) — 좋아요 수는 이 테이블 COUNT로 항상 계산(증감 동기화 버그 방지를 위해 카운터 컬럼을 별도로 두지 않음)

### 카카오 검색 장소 적재 (마이그레이션 032)

뚜벅이 코스(FR-17)는 카카오 키워드 검색으로 찾은 장소를 후보에 섞는데, 이들은 `places`에 행이 없어 코스 스냅샷에 `placeId: "kakao:<id>"`로 들어간다. `saved_walking_courses`/`shared_routes`는 FK가 없어 그대로 저장됐지만, **진짜 장소를 전제로 하는 기능이 전부 조용히 실패**했다 —
- 북마크는 `bookmark.validator.js`의 `isUuid(placeId)`에서 400으로 거절됐고, `BookmarkButton`은 실패를 표시하지 않아 **아이콘이 안 채워지는 게 전부**였다(공유 동선 상세에서 북마크가 "안 되는" 증상의 원인)
- 공개 동선 좋아요는 `shared-route.service.js`가 UUID가 아닌 id를 걸러내므로, 카카오 장소만으로 된 코스는 좋아요를 눌러도 **취향 임베딩·`tag_scores`가 하나도 갱신되지 않았다**

그래서 사용자가 코스를 **보관하는 시점**(`POST /walking-courses` 저장, `POST /walking-courses/:id/publish` 게시)에 그 코스의 카카오 장소를 `places`에 적재하고 스냅샷의 id를 새 UUID로 바꾼다(`kakao-place.service.js`의 `materializeRoutePlaces`, `kakao-place.repository.js`). 생성할 때가 아니라 보관할 때인 이유는 아무도 저장하지 않은 코스까지 `places`를 늘릴 이유가 없어서다(뚜벅이 코스 결과 화면에는 북마크 버튼 자체가 없다). `(source, external_id)` UNIQUE를 공공데이터와 똑같이 재사용해 멱등하고, 좌표가 없는 장소는 적재하지 않고 `kakao:` id를 그대로 둔다.
- 스냅샷에 카테고리·주소가 없어 적재되는 행은 **이름+좌표만** 채워진다(`category`/`address` null). 북마크·좋아요 학습에는 충분하지만, 내 주변 추천의 카테고리 탭에는 잡히지 않는다 — 카테고리까지 넣으려면 AI Worker `RoutePoint`에 필드를 추가해야 함
- 이전에 저장·게시된 코스는 `node scripts/backfill-kakao-places.js`로 정리(`--dry-run` 지원, 재실행 안전)
- 앱 쪽 안전망: `isBookmarkablePlaceId`(`lib/utils/place_id.dart`)가 UUID가 아닌 id면 `BookmarkButton`을 아예 그리지 않고, 북마크 실패는 스낵바로 알린다(조용히 아무 일도 안 일어나는 버튼을 없앰)
- 월 1회 공공데이터 갱신의 삭제는 `source`로 범위가 잡혀 있어 `kakao_local` 행은 지워지지 않는다. 다만 중복 제거(`removeDuplicateDatasetPlaces`)는 `external_id IS NOT NULL`인 모든 행이 대상이라 tour_api 중복으로 판정되면 소프트 삭제될 수 있음(북마크된 장소는 제외)

### 공공데이터 장소 (FR-15/FR-17 콜드 스타트, 마이그레이션 025)

영상 분석으로만 장소가 쌓이면 분석한 적 없는 지역에선 "내 주변 추천"이 비어 있음(테스트 위치 기준 가장 가까운 장소가 10.7km). 그래서 두 공공데이터를 `places`에 일괄 적재한다 — 둘 다 공공누리 제1유형(출처표시), 이미지는 항목별 저작권이 달라 적재하지 않음.
- **tour_api** — 한국관광공사 TourAPI(KorService2 `areaBasedList2`, 전국, 관광지/문화시설/쇼핑/음식점 콘텐츠타입). 목록 항목의 구 분류(cat1~3)는 비어 있고 신분류체계 `lclsSystm1~3`만 채워져 있어 이 코드로 분류. `node scripts/import-tour-api.js`(키는 `backend/.env`의 `TOUR_API_KEY`)
- **semas** — 소상공인시장진흥공단 상가(상권)정보 CSV(현재 서울·경기). 원본 zip은 `database/seed-data/`(gitignore)에 두고 필요한 지역 CSV를 압축 해제한 뒤 `node scripts/import-semas.js <csv...>`
- 분류는 `backend/src/services/public-place-classification.js`의 **허용 목록** 방식(목록에 없는 업종은 제외 — 병원·학원·유흥주점·노래방·대형마트·숙박 등). 상가정보 비음식 업종(볼링장·수상레저·서점·예술품·기념품점)은 더 엄격해서 **표준산업분류코드도 일치**해야 하고 **회사식 이름**(~코퍼레이션/컴퍼니/상사/유통/인터내셔널 등)은 제외 — "킴스코퍼레이션"이 볼링장으로 등록돼 놀거리로 추천됐었음. 전자 게임장·기타 오락장(오락실·뽑기방·홀덤·PC방이 대부분)은 아예 제외. `import-semas.js`를 다시 돌리면 현재 규칙에 안 맞게 된 기존 장소도 삭제됨. 카테고리는 AI Worker 점수화가 아는 값(cafe/bakery/restaurant/dessert/bar/museum/gallery/attraction/shopping/beach/night_view)만, 태그는 분류 자체가 뒷받침하는 경우에만 `tag_catalog.py` 코드로 부여(이름으로 추측하지 않음)
- 적재 후 중복 제거: 정규화한 이름이 같고 ~50m 이내면 우선순위 낮은 쪽을 소프트 삭제(영상 장소 > tour_api > semas, 북마크된 장소는 삭제 안 함). 두 스크립트 모두 재실행 안전
- `/recommendations/nearby`의 후보 조회(`recommendation.repository.js` `findNearby`)는 바운딩박스로 먼저 좁힌 뒤 **카테고리별로 돌아가며**(각 카테고리 1순위 → 2순위 …) 최대 100개를 뽑음 — 가게 데이터가 촘촘해 단순 가까운 순이면 도심에선 반경 수십 m의 음식점·카페만 채워져 800m 떨어진 미술관은 점수화 대상에도 못 들어가기 때문
- 뚜벅이 코스(FR-17)도 북마크 장소 외에 중심 반경 3km 내 저장 장소(영상+공공데이터) 최대 150개를 `placeCandidates`로 함께 보냄. AI Worker는 북마크 > 저장 장소 > Kakao 순으로 합친 뒤 **정규화 이름이 같고 300m 이내면 같은 장소로 보고 하나만 남김**(경복궁처럼 넓은 곳은 Kakao와 TourAPI 좌표가 수백 m 차이). 선택한 분위기 태그를 가진 저장 장소 중 **놀거리 카테고리만** Kakao 키워드 결과와 같은 분위기 보너스를 받음(생맥주집도 활기찬 태그라 술집만 이어지는 코스가 나왔음)
- 한 코스에 식사 장소(restaurant·bar)는 최대 1곳, 반나절(8시간)만 2곳(점심·저녁) — 상가정보로 후보 대부분이 음식점이 되면서 식당이 연달아 나와 배불러 코스를 건너뛰게 됐기 때문(`MAX_MEAL_STOPS`, `_DURATION_PROFILES[...]["maxMealStops"]`). 카페·베이커리·디저트는 기존대로 합쳐서 최대 2곳
- 한 코스에 **이름이 겹치는 가까운 같은 종류 장소**는 하나만(`_same_spot_as_selected`): 300m 이내 + 같은 카테고리 + 한 이름이 다른 이름을 포함("케이락"/"케이락볼링장", 짧은 쪽이 긴 쪽의 절반 이상)하거나 앞부분 4자 이상·짧은 이름의 절반 이상이 같음("제주동문시장"/"제주동문공설시장"/"제주동문수산시장" — 시장 목록이 코스를 채웠었음). 카테고리가 다르면 묶지 않음(시장 안 카페, "경복궁"과 "한복남 경복궁점")
- 한 코스에 같은 브랜드의 다른 지점("한복남 경복궁점"·"한복남 프리미엄점")은 하나만 — 끝 단어가 `~점`이면 떼어낸 이름이 같으면 같은 브랜드로 보고, 코스 선택 순위가 높은 지점만 남김(`_same_brand_as_selected`). 공공데이터·Kakao 모두 평점 정보가 없어 평점 대신 코스 점수로 고름
- 원본에서 잘린 이름(짝 없는 괄호 "비어링(세계맥", 끝에 남은 연결 기호 "분식·", 한 글자 지점명 "스타벅스 대")은 적재 시 제외(`isBrokenPlaceName`/`isBrokenBranchName`), 이미 적재된 것은 `node scripts/remove-broken-place-names.js --apply`로 정리. "별"·"강릉의 밤"·"모주체험 여" 같은 짧은 이름은 실제 이름이라 유지
- **월 1회 자동 갱신**(마이그레이션 026, `public_data_refreshes`): 백엔드가 서버 시작 1분 뒤와 하루 한 번 "마지막 성공이 30일 지났는지" 확인해 지났으면 별도 프로세스로 `scripts/refresh-public-places.js` 실행(80만 건 적재가 API를 멈추지 않도록). 고정된 날짜(매월 1일) 방식이면 그날 서버가 꺼져 있을 때 그 달을 통째로 건너뛰므로 "마지막 실행 기준"으로 판단. `PUBLIC_DATA_REFRESH_ENABLED=false`로 끌 수 있음(인스턴스가 여럿일 때)
  - TourAPI는 매번 다시 적재(약 20초), 상가정보는 `database/seed-data/`에 **더 새 판(파일명 `..._YYYYMMDD.zip`)이 있을 때만** 적재 — 분기마다 data.go.kr에서 수동으로 받아 넣어야 하고, 넣은 직후 바로 반영하려면 스크립트를 직접 실행. zip은 풀지 않고 16개 지역 CSV를 스트리밍으로 읽음(1.5GB 압축 해제 불필요, 약 80초)
  - 적재 후 **이번 실행에서 갱신되지 않은 행은 삭제**(폐업·목록에서 빠진 곳). 단, 이번에 쓴 건수가 기존 활성 건수의 절반 미만이면 삭제를 건너뜀 — API 장애로 일부만 받아온 날 데이터가 통째로 지워지는 걸 막기 위함. 북마크된 장소는 삭제 안 함
- 상가정보는 전국 17개 시도 적재 완료(상가정보 약 82만 건 + TourAPI 약 3만 건, DB 334MB)
- **장소 상세의 "카카오맵에서 보기"**: 카카오맵 앱(`kakaomap://` — 카카오 검색 장소는 place?id, 그 외는 이름+좌표 검색)을 열고, 앱이 없으면 map.kakao.com 웹으로 엶(`lib/services/kakao_map_launcher.dart`, url_launcher; AndroidManifest `<queries>`·iOS `LSApplicationQueriesSchemes`에 kakaomap 등록). 동선 카드(`RouteSummaryCard` — 저장한 코스·여행 동선·공유 동선)의 장소별 **지도 버튼도 같은 방식으로 카카오맵에서 그 장소를 엶**(앱 안 지도 시트 대신). 앱에서 지도 버튼을 누르면 `kakaomap://search?q=<이름>&p=<위도>,<경도>` 인텐트가 실제로 발사되는 것까지 실기기 확인(2026-09-21)
- **동선을 카카오맵 길찾기로 열기**(`kakaoMapLauncher.openRoute`): 두 링크를 쓴다 — 받는 값이 서로 다르다(2026-09-29 실기기 전수 확인).
  - `kakaomap://route?sp=<위도,경도>&ep=<위도,경도>&by=FOOT|PUBLICTRANSIT|CAR` — **정확히 2지점만**. 경유지 파라미터가 아예 없다(`wp`/`via`/`wpp`/`viaPoints` 4개 모두 조용히 무시, 2026-09-21). 대신 설치된 앱이 곧바로 열린다(선택 대화상자 없음). 세 모드 다 실제 경로가 뜨는 것 확인: 도보 52분 / 버스 31분·614번·정류장까지 / 자동차 9분·택시요금
  - `https://map.kakao.com/link/by/{walk|traffic|car|bicycle}/<이름>,<위도>,<경도>/...` — **경유지를 받는다(최대 5개 = 7지점)**. 이름도 그대로 들어가 카카오맵 "경유지 입력" 칸에 표시됨. 단 ① **8번째 지점은 말없이 버려진다**(7지점과 거리·시간이 완전히 동일, 마지막 장소만 사라짐) ② **`traffic`(대중교통)은 경유지를 아예 무시**하고 앞 2지점만 남긴다 ③ https라서 안드로이드가 "연결 프로그램(Chrome/카카오맵)"을 물을 수 있다(사용자가 "항상" 선택 가능)
  - 그래서 UI는 두 갈래: **구간 라벨을 누르면 그 구간만**(`legTransportMode` 그대로 → 도보/버스/차량 각각의 길찾기로 열림 — 이동수단이 섞인 동선의 버스 구간이 카카오맵에 닿는 유일한 경로), **전체 코스 버튼은 조건부**(`KakaoMapLauncher.canOpenWholeRoute` — 지점 2~7개 + `transportMode`가 `transit`/`mixed`가 아닐 때만 노출). 조건을 못 맞추면 버튼을 숨긴다 — 잘린 동선을 "전체"라고 보여주지 않기 위함. 이전 문서에 "웹 링크도 중간 장소가 빠진다"고 적혀 있었는데 **이는 오류였다**(`/link/to/`만 확인하고 `/link/by/`를 안 봤음)
- **출처표시**: 공공데이터 장소가 나올 수 있는 목록(내 주변 추천, 뚜벅이 코스 결과) 하단에 `DataSourceAttribution` 한 줄, 고객센터에 "데이터 출처" 섹션(`lib/core/constants/public_data_sources.dart`)

인덱스: `youtube_url`, `provider_id`, `video_id`, `user_id`, `place_id`, `hotel_id`, `start_hotel_id`, `end_hotel_id`, `trip_id`, `bookmark_folders.user_id`, `bookmark_folder_items.bookmark_id`, `places.category`, `places(latitude, longitude)`(주변 검색 바운딩박스용, 부분 인덱스), `places(source, external_id)`(UNIQUE, 부분 인덱스), `created_at`, `saved_walking_courses.user_id` + 복합 인덱스 `(user_id, place_id)`, `(video_id, timestamp_sec)`, `(trip_id, day_number)`, `(recommendation_behaviors.user_id, place_id, action)`.

## 핵심 처리 로직

### 영상 분석 (7단계)
1. URL 수신·유효성 검증 (실패 시 400)
2. `videos` 캐시 조회 (`is_analyzed = true`면 3~6 건너뜀)
3. `youtube-transcript-api`로 자막 추출 (없으면 422)
4. 자막+메타데이터(제목/설명/해시태그) → LLM 파싱(장소명·카테고리·영업시간·태그와 함께, 자막에 실제 코멘트가 있으면 `mentionNote` 1문장도 추출 — FR-19 재료) (실패 시 재시도 후 503)
5. Kakao Local API로 좌표 변환 (실패 시 lat/lng/address = null, 전체 분석은 중단하지 않음)
6. `videos`, `places` 저장 및 `is_analyzed = true`
7. 결과 반환

### 영상 플레이어 (FR-04)
- WebView가 플레이어 페이지를 **나중에 다시 로드**하는 경우가 있음(실기기에서 영상이 뜬 27초 뒤 빈 플레이어로 재로드 — `getVideoUrl()`에 영상 id가 없는 cued 상태 = 흰 화면). 그래서 `_PlayerLoader`(`lib/repositories/video_player_repository.dart`)는 영상이 뜬 뒤에도 2초마다 확인해, 영상이 사라지면 로딩 표시로 돌아가 다시 불러옴. "영상에서 보기"는 플레이어가 비어 있으면 `loadVideoById({startSeconds})`로 그 시점부터 바로 불러옴. 재생 시작 순간의 `-1`(unstarted)은 영상 id가 있으면 정상으로 봄(끊긴 것으로 보면 사용자가 누른 재생을 멈춰버림)
- 분석 탭은 마지막 분석 결과를 보여주며, 홈에서 분석하면 결과는 분석 탭으로 넘어가고 홈 입력칸은 비워짐(`AppShellProvider`). 다른 영상을 분석하면 `ValueKey(videoId)`로 화면을 새로 만들어 이전 영상의 플레이어를 재사용하지 않음

### 여행(trip)·날짜(day) 구조
- 동선은 항상 "여행" 하나에 소속된 "며칠째(day_number)" 단위로 생성된다. 먼저 `POST /trips`로 여행을 만들고, 그 아래에 `POST /itineraries`로 날짜별 동선을 하나씩 추가한다.
- 같은 여행 안에서도 날짜마다 시작/종료 호텔이 다를 수 있다 (예: 1일차 A호텔 → B호텔, 2일차 B호텔 → B호텔 왕복). 각 날짜의 호텔 기반 동선 최적화 로직 자체는 서로 독립적이며 아래 로직을 날짜마다 그대로 반복한다.
- 같은 `tripId`+`dayNumber` 조합으로 다시 생성을 시도하면 409 DAY_EXISTS.

### 동선 최적화 (여행의 특정 날짜, 시작/종료 호텔 기반)
1. `tripId`가 요청 사용자 소유 여행인지 확인 (아니면 404 TRIP_NOT_FOUND), 해당 `tripId`+`dayNumber` 조합이 이미 존재하는지 확인 (있으면 409 DAY_EXISTS)
2. `startHotelId`, `endHotelId` + `placeIds` 최소 2개, 최대 10개 검증. 둘 다 요청 사용자 소유 호텔이어야 함
3. `route_type`을 서버에서 자동 판별: `startHotelId == endHotelId` → `roundTrip`, 다르면 → `hotelToHotel` (클라이언트가 보낸 routeType은 신뢰하지 않음). `transportMode`(car|walk|transit, 기본 car)는 클라이언트가 선택한 값을 그대로 사용(자동 판별 대상 아님)
4. 시작 호텔·종료 호텔·각 장소 좌표 조회 (좌표 없는 장소는 제외)
5. `transportMode`에 따라 이동 시간 계산 API가 다름 — `car`는 Kakao Mobility(자동차 길찾기, `apis-navi.kakaomobility.com/v1/directions`), `walk`는 Kakao 도보 경로 조회(`dapi.kakao.com/v2/routing/walk`), `transit`은 Kakao 대중교통 경로 조회(`dapi.kakao.com/v2/routing/publictraffic` — 여러 경로 옵션 중 소요시간이 가장 짧은 것을 선택. `totalTime`은 탑승 + 정류장까지 도보를 포함하고 **정류장 대기시간은 미포함**(2026-09-17 실측: 총 1253초 = 버스 654초 + 비탑승 648m). 응답에 버스 번호(`vehicles`)·정류장(`stops`)·요금·환승 수가 있음). 세 경우 모두 실패 시 각 이동수단의 평균 속도(자동차 ~30km/h, 도보 ~4km/h, 대중교통 ~15km/h) 기준 Haversine 직선거리로 대체
6. 시작 호텔과 종료 호텔을 고정 양 끝점으로 유지한 채 장소들의 방문 순서만 TSP 스타일로 최적화: 시작 호텔(출발) → 장소들 → 종료 호텔(도착), 10개 초과는 최적화 대상에서 제외 (최적화 알고리즘 자체는 이동수단과 무관하게 동일 — 어느 매트릭스를 쓰느냐만 다름)
7. `itineraries`(`trip_id`, `day_number` 포함, `route_data`는 JSONB) 저장 후 반환

## LLM 규칙

- 백엔드는 LLM을 직접 호출하지 않는다. 반드시 AI Worker를 통한다.
- 공급자 모드: `auto`(기본) / `openai` / `claude`. auto는 OpenAI 우선, 재시도 1회 → 실패 시 Claude, 재시도 1회 → 그래도 실패 시 503(AI_PROVIDER_ERROR).
- LLM 응답은 JSON만 허용 (마크다운/설명/코드블록 금지). 유효하지 않으면 동일 공급자 재시도 1회 → 공급자 전환 → 그래도 실패면 AI_PROVIDER_ERROR.
- LLM은 절대 좌표를 생성하지 않는다. 좌표는 오직 Kakao Maps 지오코딩 결과만 사용.
- 장소 추출 우선순위: transcript > on_screen_text > hashtags > description > title. transcript 유래는 타임스탬프 포함, on_screen_text·메타데이터 유래는 `timestampSec = null`.
- **자동 생성 자막(유튜브 음성인식) 처리**: `/extract-transcript`가 `captionsAutoGenerated`를 알려주고 백엔드가 `/extract-places`에 `transcriptAutoGenerated`로 넘김. 자동자막은 어디를 언제 갔는지·코멘트는 믿을 만하지만 가게 이름을 소리 나는 대로 틀림("소베"→"소배", "보흔바"→"보음바") — 그래서 이름은 **후보로 두고 확인**: ① 자막 이름으로 카카오 검색·LLM 확인이 되면 그대로 ② 안 되면 제목·설명·해시태그·화면 글자에 있는 같은 장소의 다른 표기(LLM이 `alternativeNames`로 제시 + 자모 단위 발음 유사도로 찾은 단어, `app/utils/korean_similarity.py`)로 재검색해 찾은 표기로 표시 ③ 어디서도 안 되면 위치 없이 이름만(자동자막이면 사람이 쓴 표기를 우선). 추출 대상은 영상 뒷부분의 구매품 소개·다음날 시식에서 언급된 곳까지 포함, 지나가기만 한 곳·못 들어간 곳은 제외
- **장소 추출 모델**: 1차(사용자가 기다리는 분석)와 백그라운드 보강 모두 `gpt-4.1-mini`. 4o-mini보다 장소를 더 찾음(25분 영상 기준 14~15곳 → 19곳, 위치 확인 9 → 12~13곳) 대신 8~10초 느림(15~17초 → 23~27초) — 그래서 백엔드의 1차 `/extract-places` 한도는 60초(`FIRST_PASS_EXTRACTION_TIMEOUT_MS`), 앱의 분석 요청 수신 한도는 100초(`VideoRepository.analyzeReceiveTimeout`, 앱 전체 기본 30초로는 긴 영상이 끊김). 백그라운드 보강 한도는 5분(`ENRICHMENT_TIMEOUT_MS`, 실측 2분 7초~3분 1초, 앱이 결과를 기다리는 20초×15회와 동일)
- **레이트 리밋 재시도**: OCR 단계가 OpenAI 분당 토큰 한도를 다 써서 직후의 장소 매칭 호출이 429로 모두 실패하던 문제(= 백그라운드 보강 장소가 조용히 위치 없이 저장됨) — 429면 제공자가 알려준 시간만큼(최소 1초·최대 20초, 총 60초 한도) 기다렸다 재시도(`llm_service._retry`). Claude 폴백 모델은 `claude-opus-5`(`_CLAUDE_MODEL`) — 이전 값 `claude-3-5-sonnet-latest`는 2025-10-28에 은퇴해서 폴백에 도달한 호출이 전부 404였다. Claude 호출은 테스트에서 항상 목으로 대체되므로 아무도 눈치채지 못했고, 실제 키를 넣고 OpenAI를 강제로 실패시켜보고야 발견했다(2026-09-22 검증 완료). 요즘 모델은 기본으로 thinking을 하므로 `response.content[0]`이 빈 thinking 블록인 경우가 있어 `_first_text_block()`으로 text 블록을 골라 읽는다. 추출은 추론이 아니라 자막 읽기라 `effort: low`로 호출한다
- **보강 결과 병합**: 백그라운드 OCR 보강 결과를 기존 장소와 이름 같음 또는 같은 순간(±5초·같은 카테고리)으로 매칭 — 기존 장소가 위치가 없고 보강이 찾았으면 **같은 place_id의 이름·위치를 갱신**(북마크 유지, `videoRepository.locatePlace`), 매칭 안 되는 것만 새로 추가. 이미 위치가 있는 장소는 건드리지 않음
- **화면 속 번인 텍스트 폴백(on_screen_text)**: 공식 자막(transcript)이 없는 영상이면 항상(메타데이터로 장소를 이미 찾았어도) AI Worker가 영상을 저해상도로 내려받아(yt-dlp) 영상 길이 기준 30초에 1장씩(`FRAME_SAMPLING_INTERVAL_SECONDS`, 영상 5%~95% 구간에서 균등 샘플링, 최대 24장 상한 `FRAME_SAMPLING_MAX_FRAMES`)을 프레임 샘플링하고(OpenCV) 비전 LLM(OpenAI→Claude 폴백)으로 화면에 보이는 텍스트(번인 자막/장소명 오버레이)를 읽어 장소 추출 프롬프트에 추가 소스로 재투입한다 — 메타데이터만으로는 화면에만 나오는 장소를 놓칠 수 있기 때문. 실패해도 예외를 던지지 않고 그냥 메타데이터 기반 결과로 진행. `ai-worker/app/services/frame_extraction_service.py`, `llm_service.extract_screen_text()`.

### 푸시 알림 (FR-12, 마이그레이션 029·030)

두 종류만 보낸다 — 둘 다 이미 서버가 아는 사실에서 나오고, 새 외부 API나 스케줄러를 요구하지 않는다.
- **영상 분석 완료**(`analysisComplete` → `route_complete_alerts`): 로그인 상태로 `POST /videos/analyze`를 부르면(optionalAuth — 비회원도 분석은 되지만 알림 대상이 아님) 보강이 아직 돌고 있을 때만 `video_analysis_watchers`에 기록해두고, 백그라운드 보강이 끝나는 순간 "장소 N곳을 더 찾았어요"를 보낸 뒤 그 영상의 watcher 행을 지운다. 알림 실패는 보강을 실패로 만들지 않는다(로그만)
- **여행 시작 D-1**(`tripStart` → `trip_start_alerts`): `jobs/trip-start-alert.job.js`가 **매시간** `start_date`가 "내일"(Asia/Seoul 기준)이고 `start_alert_sent_at`이 비어 있는 여행을 찾아 보낸다. 하루 한 번이 아니라 매시간인 이유는 발송 시각에 서버가 꺼져 있었어도 그날 안에 나가게 하기 위함이고, 중복은 `start_alert_sent_at`으로 막는다. 발송 창은 **KST 10~21시** — 야간 침묵 설정이 켜진 사용자를 "보냄"으로 표시하고 조용히 버리는 걸 막기 위해 처음부터 낮에만 돈다. 끄기로 한 사용자·기기 없는 사용자는 보낸 것으로 표시하고(매일 다시 볼 이유 없음), Firebase 미설정·오류처럼 **시도조차 못 한 경우만** 표시하지 않고 다음 스윕에 넘긴다

발송은 `backend/src/services/push.service.js`(firebase-admin `sendEachForMulticast`) 한 곳을 거치며, 매 발송마다 ① 해당 종류의 설정 토글 ② 야간 침묵(22:00~08:00 **Asia/Seoul** — 서버 시간대가 아님)을 확인한다. `sendToUser`는 절대 throw하지 않고 `{sent, skipped}`를 돌려준다(알림 때문에 그걸 만든 작업이 실패하면 안 됨). FCM이 "등록되지 않은 토큰"이라고 답한 기기는 그 자리에서 `device_tokens`에서 지운다(앱을 지운 기기가 영원히 재시도 대상으로 남지 않게).

`FIREBASE_SERVICE_ACCOUNT_PATH`(backend/.env)가 없거나 그 경로에 파일이 없으면 **경고 한 줄 남기고 전부 no-op** — Firebase 프로젝트가 없는 개발 머신에서도 나머지 기능(무엇보다 영상 분석)은 똑같이 동작해야 하기 때문. 앱 쪽도 같은 원칙이라 `google-services.json`이 없으면 Gradle이 google-services 플러그인을 아예 적용하지 않고(`android/app/build.gradle.kts`의 `if (file(...).exists())`), `FirebasePushMessagingService`가 초기화 실패를 삼켜 알림만 꺼진 채로 실행된다. 두 파일 모두 gitignore.

앱은 로그인·세션 복원 직후 `PushRegistrationService`로 권한을 묻고 FCM 토큰을 `POST /device-tokens`에 등록하며, FCM이 토큰을 회전시키면 다시 보낸다. 로그아웃·회원탈퇴 시에는 **JWT를 지우기 전에** 해제한다(요청에 토큰이 필요하고, 계정이 떠난 기기가 그 계정의 알림을 계속 받으면 안 됨).

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
- **FR-05** 지도 보기(Kakao) / **FR-06** 북마크 / **FR-07** 시작/종료 호텔 기반 AI 동선(왕복·호텔 간 이동, 자동차/도보/대중교통 이동수단 선택) / **FR-08** 소셜 로그인(Kakao) / **FR-09** 캐싱
- **FR-10** 지역/테마/기간 추천 마법사 / **FR-11** 북마크 폴더(다대다 태그, 폴더 장소만으로 호텔 없는 도보 동선 즉시 생성) / **FR-12** 알림 설정 + 푸시 발송(FCM — 영상 분석 완료, 여행 시작 D-1. 위 "푸시 알림" 참고) / **FR-13** 고객센터(정적 FAQ + 앱 내 문의 접수 — 저장 후 메일 전달, 내 문의 내역 조회)
- **FR-14** 네이티브 회원가입/로그인(이메일+비밀번호, OTP 이메일 인증) — 카카오 소셜 로그인(FR-08)과 별개의 로그인 수단, 두 provider 모두 동일한 JWT 발급 흐름을 공유
- **FR-15** 내 주변 추천 — 위치·현지 시각·반경 내 기존 `places` 기반 거리/시간대/영업여부(LLM 추정) + (취향 설정 또는 행동 이력 존재 시) 임베딩 유사도·학습된 태그 선호도 하이브리드 정렬 + 행동 기반 자동 학습(조회/북마크/일정추가/공유/좋아요는 선호 강화, 숨김/관심없음은 약화 및 향후 추천에서 완전 제외). 콜드 스타트 전용 로직, Two-Tower 확장 모델은 후속 단계(미구현) — 자세한 단계별 로드맵은 세션 기록 참고
- **FR-16** 취향 설정(선택형 임베딩 + 태그) — 고정 태그 목록에서 선택하면 사전학습 임베딩 모델로 취향 벡터를 생성하고, 선택한 태그 자체도 `source_tags`로 저장해 FR-15의 세부 태그 일치도 계산에 함께 사용. 건너뛰기/초기화 가능, 미설정 시 FR-15는 상황 기반으로만 동작
- **FR-17** 지역 기반 도보 코스 자동 생성 및 저장 — 지역 선택 시 (전체 사용자의 북마크된 장소 + Kakao 상권 검색 실시간 데이터) 하이브리드 후보 풀을 FR-15와 동일한 점수화 로직으로 평가하고, 서로 도보 거리(1.2km) 이내인 장소끼리만 그리디 클러스터링해 2~10개를 뽑아 도보 동선을 자동 구성(FR-07의 walk 모드 재사용). 북마크가 없는 지역에서도 Kakao 상권 검색으로 콜드스타트 대응. 생성된 코스는 trip/hotel과 무관한 독립 스냅샷(`saved_walking_courses`)으로 저장 가능
- **FR-18** 비슷한 취향 추천(협업 필터링) — 내 취향 임베딩과 다른 모든 사용자의 취향 임베딩 간 코사인 유사도를 계산해, 유사도 0.3 이상인 사용자들이 북마크한 장소를 유사도 합산 점수로 정렬해 추천. 여러 유사 사용자가 겹쳐서 북마크한 장소일수록 점수가 높아짐(`contributorCount`로 몇 명이 겹쳤는지 함께 제공). 취향 미설정 사용자에게는 "먼저 취향 설정을 해보세요" 안내(FR-16과 연동), 아직 유사한 취향의 사용자가 없으면 빈 목록 반환(에러 아님)
- **FR-19** 여러 브이로그 기반 장소 장단점 요약 — 같은 실제 장소가 서로 다른 영상에서 언급될 때(좌표 반올림으로 매칭), 각 영상 추출 시점에 뽑아둔 `mention_note`(그 영상에서 이 장소에 대해 실제로 언급된 코멘트 1문장)를 모아 LLM이 장점/단점을 각각 한 줄로 종합. 최소 2개 영상의 언급이 있어야 생성(그 미만이면 "아직 비교할 다른 영상이 부족함" — 에러 아님). 장소 상세 조회 시점에 지연 생성(lazy) 후 `places` 행에 캐싱, 이후 같은 좌표에 새 영상 언급이 추가될 때만 재생성
- **FR-20** 여행 공유 링크 — 여행 전체 일정 화면의 "링크 복사"로 `GET /trips/:id/share`(비로그인 공개 조회, 서버 렌더링 HTML) 링크를 생성. 여행 소유자가 받는 사람을 직접 골라 링크를 전달하는 좁은 배포 범위이므로 호텔 **이름**까지는 노출(주소/좌표는 제외) — FR-21의 공개 피드보다 완화된 프라이버시 기준
- **FR-21** 동선 공유 피드 — 저장한 뚜벅이 코스(FR-17) 또는 여행의 날짜별 동선(FR-07)을 제목을 붙여 공개 피드에 게시(`POST .../publish`), 홈 화면 "다른 유저의 추천 동선"에서 좋아요·취향 일치율(게시자 ↔ 조회자의 취향 임베딩 코사인 유사도, FR-16 설정 필요)과 함께 노출. **본인이 게시한 동선도 같은 피드에 그대로 보이며**(`isOwner`로 구분) 제목 수정(`PATCH`)·게시 취소(`DELETE`)가 가능. 여행 동선을 게시할 때는 `start_hotel_id`/`end_hotel_id`가 가리키는 실제 숙소 정보를 스냅샷에서 통째로 제거하고 중간 장소들의 동선만 남김(FR-20과 달리 전체 앱 사용자에게 공개되는 넓은 배포 범위라 더 엄격한 기준) — 이 무해화 처리 때문에 뚜벅이 코스와 달리 총 이동거리/시간도 게시 시점에 재계산됨. 다만 각 장소의 `placeId`는 스냅샷에 남겨둠(이름 있는 공개 장소라 프라이버시 문제 없음) — 다른 사용자가 이 동선에 좋아요를 누르면 FR-15 행동 기반 학습 파이프라인을 재사용해 그 장소들을 "좋아요"한 것과 동일하게 좋아요 누른 사용자 본인의 취향 임베딩·`tag_scores`에 반영(본인 동선에는 좋아요 불가)

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
node scripts/import-tour-api.js                  # 공공데이터 장소 적재 (재실행 안전)
node scripts/import-semas.js ../database/seed-data/<지역>.csv
node scripts/refresh-public-places.js            # 월 1회 갱신을 지금 실행 (새 상가정보 zip을 넣은 직후 등)
node scripts/backfill-kakao-places.js --dry-run  # 예전에 저장/게시된 코스의 kakao: 장소를 places에 적재 (재실행 안전)

# AI Worker (ai-worker/)
pip install -r requirements.txt
uvicorn app.main:app --reload
```
