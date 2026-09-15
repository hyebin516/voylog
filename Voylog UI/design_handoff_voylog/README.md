# Handoff: Voylog — 여행 동선 추천 앱 프로토타입

## Overview
Voylog는 여행 브이로그(YouTube 등) 영상을 AI로 분석해 영상에 등장한 장소를 추출하고,
사용자가 그 장소를 북마크·폴더로 모아 실제 여행 동선(일정)으로 최적화하는 모바일 앱이다.
이 번들은 로그인부터 여행 일정 공유까지 전체 플로우(약 30개 화면)를 담은 인터랙티브 프로토타입이다.

핵심 가치 흐름:
1. 브이로그 URL 입력 → AI 분석 → 장소 카드(장단점 요약 포함)
2. 마음에 드는 장소를 북마크 폴더에 저장
3. 폴더에서 장소를 골라 일자별 동선 생성 → 호텔 기준 최적화
4. 완성된 동선 저장 / 앱 내 다른 사용자에게 추천 / 외부(카카오톡·링크) 공유
5. 홈에서 취향이 비슷한 사용자의 북마크와 공유 동선을 탐색

## About the Design Files
번들에 포함된 HTML 파일은 **HTML로 만든 디자인 레퍼런스**다. 의도한 화면 구성과 동작을
보여주는 프로토타입이며, 그대로 복사해 제품에 넣을 프로덕션 코드가 아니다.
해야 할 일은 이 HTML 디자인을 **대상 코드베이스의 기존 환경(React Native, Flutter, SwiftUI,
Next.js 등)에서 그 코드베이스의 관례와 라이브러리로 다시 구현**하는 것이다.
아직 환경이 없다면 프로젝트에 가장 적합한 프레임워크를 고르고 거기에 구현한다.
(모바일 앱이 최종 타깃이므로 React Native 또는 Flutter를 권장.)

## Fidelity
**High-fidelity (hifi).** 색상·타이포그래피·간격·라운드·그림자·인터랙션이 모두 확정된 값이다.
아래 Design Tokens와 화면 명세의 수치를 그대로 재현할 것. 단, 지도 영역은 의도적으로
플레이스홀더(대각선 스트라이프 패턴)로 처리되어 있으므로 실제 지도 SDK로 대체한다.

## Platform & Frame
- 디자인 기준 프레임: **393 × 852 px** (iPhone 15 기준). 프로토타입에서는 `.phone` 컨테이너로 표현
- 상단 상태바 영역 확보: 화면 헤더는 `padding-top: 56px`
- 하단 탭바가 있는 화면은 콘텐츠 하단 여백 확보
- 모든 텍스트/버튼은 한국어, 폰트는 `M PLUS Rounded 1c` (Google Fonts, weights 400/500/700/800)
  - 실제 앱에서는 동일한 둥근 고딕 계열(예: Pretendard Rounded)로 대체 가능하나 라운드 느낌 유지 필수

## Design Tokens

### Colors
| 역할 | 값 |
|---|---|
| Primary (brand blue) | `#3d9fdb` |
| Primary strong / text on light | `#2f8fd0` |
| Primary gradient (CTA) | `linear-gradient(135deg, #5fc2e8, #2f8fd0)` |
| Text primary | `#1c3f52` |
| Text secondary | `#4a90bb` |
| Text tertiary / caption | `#7fa6bc` |
| Text muted / placeholder | `#9db8c9`, `#a9c5d6` |
| Divider / border | `#e6f2f9`, `#e0eef6` |
| Surface (card) | `#ffffff` |
| Surface tint 1 | `#f7fbfd` |
| Surface tint 2 | `#f2f8fc` |
| Surface tint 3 (selected) | `#eaf6fd` / `#e7f5fc` |
| Selected border | `#bfe0f2` |
| App background (프레임 밖) | `#dcecf5` |
| Accent warm (2일차, 북마크 채워짐) | `#f0a83a` / `#e2a45f` |
| Kakao yellow | `#fee500` (심볼 `#3c1e1e`) |
| Danger (탈퇴/삭제) | `#e2685f` |
| Overlay (시트/모달 배경) | `rgba(20,40,55,.4)` |

### Typography scale (weight size / line-height)
- 화면 타이틀(헤더): 700 17px
- 페이지 대제목: 800 21px / 1.35
- 섹션 제목: 700 15px
- 카드 제목: 700 14px
- 본문: 500 13.5px
- 캡션: 500 12–12.5px
- 마이크로 라벨 / 배지: 600–700 10–11px
- 탭바 라벨: 600 10px
- 10px 미만 사용 금지

### Radius
- 카드: 20px (큰 카드), 18px, 16px
- 인풋/사각 버튼: 14px
- 아이콘 버튼(정사각): 12px, 크기 34–36px
- 알약형 배지/버튼: 999px
- 바텀시트: `28px 28px 0 0`
- 폰 프레임: 44px

### Shadows
- 카드: `0 4px 14px rgba(58,159,216,.07)`
- 떠 있는 아이콘 버튼: `0 3px 8px rgba(58,159,216,.15)`
- 바텀시트: `0 -12px 30px rgba(30,60,80,.15)`

### Spacing
- 화면 좌우 패딩: 20px
- 카드 내부 패딩: 14–15px (작은 카드 10–12px)
- 리스트 아이템 gap: 9–12px
- 섹션 간격: 18–22px

## Navigation model
프로토타입은 단일 `screen` 문자열 상태로 화면을 전환한다. 실제 구현에서는 스택 네비게이션 +
하단 탭 4개(홈 / 북마크 / 여행 / 내 페이지)로 매핑한다.

화면 키 → 라벨:
`login` 로그인 · `signup` 회원가입 · `home` 홈 · `analysis` 분석 · `analysisComplete` 분석 완료 ·
`bookmarkFolders` 북마크 · `folderDetail` 폴더 상세 · `savedRoutes` 저장한 동선 ·
`routeDetail` 저장된 동선 · `tripCreate` 여행 · `tripOverview` 전체 일정 ·
`hotelSelect` 호텔 선택 · `dayPlaceSelect` 북마크 선택 · `dayOptimize` 동선 최적화 ·
`transport` 동선 결과 · `regionSelect` 지역 선택 · `themeSelect` 테마 선택 ·
`durationSelect` 일정 선택 · `recommendedVlogs` 추천 브이로그 · `similarTaste` 취향 맞춤 추천 ·
`nearby` 내 주변 추천 · `nearbySurvey` 취향 알아보기 · `preferences` 취향 설정 ·
`walkingSetup` 뚜벅이 코스 설정 · `walkingCourse` 뚜벅이 코스 · `placeDetail` 장소 상세 ·
`placeSummary` AI 요약 · `myPage` 내 페이지 · `accountSettings` 계정 설정 ·
`notificationSettings` 알림 설정 · `support` 고객센터

화면 전환 시 모든 시트/모달 플래그는 초기화된다(`go(screen)` 참고).

## Screens / Views

### 1. 로그인 (`login`)
- **Purpose**: 카카오 로그인 또는 비회원 둘러보기 진입
- **Layout**: 세로 중앙 정렬 — 로고 → 서비스 한 줄 소개 → 카카오 로그인 버튼 → 비회원 진입 텍스트 버튼
- **Components**: 카카오 버튼 = 배경 `#fee500`, radius 14px, 700 15px, 전체 폭; 비회원 링크 = 600 13px `#7fa6bc`
- **Behavior**: 카카오 로그인 → `isLoggedIn: true` → `home`; 비회원 → `isLoggedIn: false` → `home`

### 2. 홈 (`home`)
- **Purpose**: 브이로그 분석 시작 + 취향 기반 탐색
- **Layout(위→아래, 스크롤)**:
  1. 인사 헤더 + 프로필(`voylog_moon` / `게스트`)
  2. 브이로그 URL 입력 필드 + 분석 버튼(그라데이션 CTA)
  3. 빠른 진입 카드 행: 내 주변 추천 / 뚜벅이 코스 / 취향 설정
  4. **취향이 비슷한 사용자의 북마크** — 3개 카드, 각 카드에 북마크 저장 아이콘 버튼(34×34, radius 12, 배경 `#f2f8fc`). "더보기" → `similarTaste`
  5. **해시태그 브이로그** — 해시태그 칩 + 브이로그 카드 리스트
  6. **다른 유저의 추천 동선** — 서브 카피 "직접 다녀오고 좋았던 동선을 공유한 사람들이에요", 공유 동선 카드 2개(작성자·좋아요 수) → `routeDetail`(kind=shared), 그 아래 점선 버튼 "내 동선 추천하기"(border `2px dashed #bfe0f2`, 배경 `#f7fbfd`) → 공유 시트
- **하단 탭바**: 홈 / 북마크 / 여행 / 내 페이지 (활성 `#3d9fdb`, 비활성 `#a9c5d6`)

### 3. 분석 (`analysis`) / 분석 완료 (`analysisComplete`)
- **Purpose**: URL 분석 진행 표시 → 추출된 장소 목록 제공
- **Components**: 진행 상태 카드(진행률 바 + 단계 텍스트), 완료 후 장소 카드 리스트
- **장소 카드**: 썸네일 플레이스홀더 + 장소명(700 14px) + 카테고리(500 12px `#9db8c9`) + 지도 보기 / 북마크 아이콘 버튼(30×30, radius 999px, 배경 `#f7fbfd`)
- **"더보기"**: 카드 내부에서 인라인 확장되어 장단점 요약을 전체 폭 위젯으로 노출. 확장 시 지도/북마크 버튼이 밀려나지 않아야 함
- **북마크 버튼** → 북마크 저장 바텀시트(폴더 선택 + 새 폴더 만들기)

### 4. 북마크 (`bookmarkFolders`) / 폴더 상세 (`folderDetail`)
- **Purpose**: 저장 장소를 폴더로 관리
- **폴더 목록**: 폴더 카드(이름 + 장소 수) + "새 폴더" 추가 카드
- **폴더 데이터(프로토타입)**: `제주도 여행`(5), `가보고 싶은 맛집`(12), `부산 여행`(8)
- **폴더 상세**: 헤더(뒤로 + 폴더명) + 지도 플레이스홀더 + 장소 리스트(장소명 / 카테고리)
- 폴더 상세는 진입 출처(`folderFrom`)를 기억해 뒤로가기 목적지를 결정

### 5. 여행 (`tripCreate`)
- **Purpose**: 일자별 여행 일정 구성
- **Layout**: 여행 제목/기간 → 일자 섹션(1일차/2일차) → 각 일자에 호텔 선택·북마크에서 장소 선택·동선 최적화 진입 → 상단 우측 "전체 일정" 버튼(700 12.5px `#2f8fd0`, 흰 배경 + `1.5px` 테두리, 좌측 리스트 아이콘 14px)
- **장소 선택**: 폴더 선택 시 폴더 상세 화면(북마크 탭과 동일 UI)으로 전환하며 네비게이션 스택 유지

### 6. 전체 일정 (`tripOverview`)
- **Purpose**: 여행 전체를 일자 탭으로 한눈에 보고 외부로 공유
- **Layout**:
  - 헤더: 뒤로 버튼(36×36, radius 12, 배경 `#f2f8fc`) + 타이틀 "전체 일정"(`flex:1`) + **공유 아이콘 버튼**(36×36, radius 12, 배경 `#f2f8fc`, share/업로드 아이콘 17px `#2f8fd0`)
  - 여행명 `제주도 여행`(800 21px) + 기간 `2026.09.12 – 2026.09.14`(500 13px `#7fa6bc`)
  - 요약 위젯: 배경 `#f7fbfd`, border `1.5px #e6f2f9`, radius 16px, padding `11px 14px`, 경로 아이콘 + 요약 텍스트
  - 일자 탭 2개(1일차/2일차): 선택 시 `#3d9fdb` 테두리·틴트 배경, 미선택 `#f2f8fc`; radius 16px, `2px` 테두리
  - 일자 카드: 일자 배지(알약, 흰 텍스트 — 1일차 `#3d9fdb`, 2일차 `#f0a83a`) + 날짜·메타, 숙소 행(집 아이콘 + 숙소명 + "왕복" 배지), 장소 타임라인(번호 원형 26px `#eaf6fd`/`#2f8fd0` + 세로 연결선 `2px #e6f2f9`), 각 장소에 시간 배지·카테고리·다음 장소까지 이동 정보
  - **거리 총합은 노출하지 않는다**(의도된 결정)
- **공유 시트**: 헤더 우측 아이콘 탭 → 바텀시트
  - 타이틀 "일정 공유하기", 서브 "제주도 여행 · 2026.09.12 – 09.14", 우측 닫기 버튼(30×30 원형)
  - 4열 그리드(gap 12px): 카카오톡(`#fee500` 타일) / 링크 복사 / 메시지 / 이미지 저장 (나머지 타일 배경 `#eaf6fd`, 아이콘 `#2f8fd0`)
  - 타일 54×54, radius 18px; 라벨 600 11px `#5b7f94`
  - 항목 탭 시 시트 닫힘(프로토타입). 실제 구현에서는 카카오 공유 SDK / 클립보드 복사 + 토스트 / OS share sheet / 일정 이미지 렌더링·저장으로 연결
- **여행 일정 데이터(프로토타입)**: 1일차 = 제주공항 렌터카 승차장(10:20) → 애월 카페 오션뷰(11:30) → 한림 해수욕장(14:10), 숙소 제주시 게스트하우스 / 2일차 = 협재 흑돼지 맛집(12:40) → 한담 해변 산책로(15:30) → 협재 해수욕장 노을(18:20), 숙소 애월 오션 호텔

### 7. 호텔 선택 / 북마크 선택 / 동선 최적화 / 동선 결과
- `hotelSelect`: 시작/종료 호텔 토글 → 검색 인풋 → 지도 플레이스홀더(200px) → 숙소 리스트(선택 항목 배경 `#eaf6fd`, border `2px #bfe0f2`, 체크 원형 `#3d9fdb`)
- `dayPlaceSelect`: 폴더/장소 다중 선택
- `dayOptimize`: 선택 장소 순서를 최적화하는 진행 화면
- `transport`: 최적화된 순서 + 이동 수단/시간, "저장하기" → 저장 동선으로 편입

### 8. 저장한 동선 (`savedRoutes`) / 동선 상세 (`routeDetail`)
- 목록: 동선 카드(제목 + "장소 N곳 · 총 X km" + accent 색)
- 상세: 지도 + 저장된 장소 타임라인. **AI 추천 프레이밍 없이** 순수 저장 동선으로 표기
- `routeKind`가 `shared`이면 동일 상세 화면에서 작성자 정보(이니셜 아바타, 닉네임, 좋아요 수)를 함께 표시
- 저장 동선 데이터: 제주도 여행 1일차(3곳·24.6km), 2일차(2곳·11.2km), 부산 여행 1일차(4곳·18.9km)
- 공유 동선 데이터: '제주 서쪽 카페 & 노을 코스'(지호의 여행노트, 좋아요 128), '부산 원도심 하루 걷기 코스'(민서의 뚜벅이 기록, 좋아요 76)

### 9. 취향/추천 화면들
- `similarTaste` 취향 맞춤 추천: 취향이 비슷한 사용자의 북마크 모음
- `nearby` 내 주변 추천 / `walkingSetup`·`walkingCourse` 뚜벅이(도보) 코스
- `nearbySurvey` 취향 알아보기: **20개 분위기 카테고리** 다중 선택 (초기 4개에서 확장됨)
- `regionSelect` / `themeSelect` / `durationSelect`: 지역·테마·기간 선택 스텝

### 10. 내 페이지 / 계정 설정 / 알림 설정 / 고객센터
- `myPage`: 프로필(닉네임 `voylog_moon`, 이메일) + 닉네임 편집 모달 + 메뉴 리스트
- `accountSettings`: 로그아웃, 회원 탈퇴 — **둘 모두 확인 모달 필수**, 확인 시 `login`으로 복귀 및 상태 초기화
- `support`: 확장형 Q&A(아코디언). 주요 답변 내용:
  - 계정을 바꾸면 이전 계정의 일정/북마크는 이전되지 않음
  - 저장한 동선은 링크로 외부(카카오톡·메시지) 공유 가능, 앱 내 사용자 공유도 가능
  - 탈퇴 시 저장 동선·북마크 모두 삭제되며 복구 불가

## Interactions & Behavior
- **바텀시트**: 오버레이 `rgba(20,40,55,.4)` + 하단 정착 패널, 상단 그랩 핸들(44×4, `#e0eef6`, radius 999px). 아래에서 위로 슬라이드(220–260ms, ease-out) 권장
- **모달(확인 다이얼로그)**: 중앙 정렬 카드, 취소/확인 2버튼. 파괴적 동작 확인 버튼 `#e2685f`
- **북마크 토글**: 아이콘 outline(`#c7d9e3`) ↔ filled(`#f0a83a`)
- **선택 상태**: 배경 틴트 + `2px` 테두리 + 체크 원형 아이콘
- **아코디언(FAQ)**: 클릭 시 답변 인라인 확장, 셰브론 회전
- **장소 카드 더보기**: 인라인 확장(높이 애니메이션), 주변 버튼 위치 불변
- **화면 전환**: 모든 시트/모달 상태 초기화
- **로그인 게이트**: 비회원이 저장·북마크 시도 시 "로그인 필요" 모달
- 지도 영역은 전부 플레이스홀더 → 실제 지도 SDK(국내 POI 정확도 위해 카카오맵/네이버맵 권장) 연동 필요
- 터치 타깃 최소 44px 확보(아이콘 버튼 30–36px 시각 크기 + 히트영역 확장)

## State Management
| 변수 | 용도 |
|---|---|
| `screen` | 현재 화면 키 (→ 라우터로 대체) |
| `isLoggedIn` | 로그인 여부, 게이트 및 프로필 표시 |
| `hasAnalyzed` | 브이로그 분석 완료 여부 |
| `nickname`, `nicknameDraft`, `showEditNickname` | 닉네임 표시/편집 |
| `currentDay` | 전체 일정·일정 구성의 활성 일자 |
| `routeIdx`, `sharedIdx`, `routeKind`, `routeFrom` | 동선 상세 대상(저장/공유)과 뒤로가기 목적지 |
| `folderIdx`, `folderFrom` | 폴더 상세 대상과 진입 출처 |
| `hotelChosen` | 호텔 선택 완료 여부(뒤로가기 분기) |
| `showBookmarkSheet` | 북마크 저장 시트 |
| `showShareSheet` | 내 동선 앱 내 추천 시트(홈) |
| `showExportSheet` | 전체 일정 외부 공유 시트 |
| `showSaveRoute`, `showNewFolder`, `showNewRoute`, `showAddPlace` | 각종 생성/저장 시트 |
| `showLoginRequired` | 로그인 필요 모달 |
| `p1`…`p6` | 취향/옵션 토글 |

### 필요한 데이터 페칭
- 브이로그 URL → 장소 추출 결과(장소명, 카테고리, 좌표, 요약 장단점, 썸네일)
- 북마크 폴더 CRUD, 폴더-장소 관계
- 동선 최적화(장소 목록 + 시작/종료 숙소 + 이동수단 → 순서·소요시간·거리)
- 저장 동선 CRUD, 공유 동선 목록(작성자·좋아요), 좋아요 토글
- 취향 프로필(20개 분위기 카테고리) 저장 및 취향 유사 사용자 북마크 추천
- 외부 공유 링크 생성(딥링크), 일정 이미지 렌더링

## Assets
- **폰트**: Google Fonts `M PLUS Rounded 1c` (400/500/700/800)
- **아이콘**: 전부 인라인 SVG(24×24 viewBox, stroke 1.7–2.2, `stroke-linecap="round"`). 동일한 라운드 스트로크 아이콘 세트(Lucide, Phosphor 등)로 대체 가능
- **이미지**: 실사 이미지 없음. 썸네일·지도는 플레이스홀더(`repeating-linear-gradient(45deg,#dcecf5,#dcecf5 10px,#eaf5fb 10px,#eaf5fb 20px)`). 실제 콘텐츠 이미지/지도 타일 필요
- **브랜드**: 카카오 로그인/공유는 카카오 공식 브랜드 가이드(`#fee500`, 심볼 규격) 준수 필요

## Files
| 파일 | 설명 |
|---|---|
| `voylog-prototype-standalone.html` | 의존성 없이 브라우저에서 바로 열어 클릭해볼 수 있는 단일 파일 버전. **동작 확인은 이 파일로** |
| `voylog-prototype-source.dc.html` | 원본 프로토타입 소스. 상단이 마크업(템플릿), 하단 `<script type="text/x-dc">` 블록에 화면 상태·데이터·핸들러 로직. 화면 명세와 목 데이터의 단일 진실 공급원 |

### 소스 읽는 방법
- 각 화면은 `<sc-if value="{{ isXxx }}">` 블록 하나로 감싸져 있다 → 화면별 마크업은 `isTripOverview`처럼 검색
- `<sc-for list="{{ items }}" as="item">`은 리스트 반복
- `{{ name }}`은 로직 클래스 `renderVals()`가 반환한 값/핸들러
- 데이터 메서드 `tripDays()`, `folders()`, `savedRoutes()`, `sharedRoutes()` — 목 데이터의 스키마를 API 응답 설계 참고로 사용 가능
- 스타일은 모두 인라인 `style` 속성 → 값을 그대로 읽어 토큰화하면 된다
- 참고: standalone 파일은 프로토타입 런타임이 인라인된 산출물이므로 로직 파악은 `.dc.html` 소스를 볼 것

## Suggested implementation order
1. 디자인 토큰 + 공용 컴포넌트(카드, 알약 배지, 아이콘 버튼, 바텀시트, 확인 모달, 하단 탭바)
2. 인증(카카오) + 비회원 모드 + 로그인 게이트
3. 홈 3개 탐색 섹션(목 데이터로 먼저)
4. 브이로그 분석 → 장소 카드 → 북마크 폴더
5. 여행 일정 구성 → 호텔/장소 선택 → 최적화 → 저장
6. 전체 일정 + 외부 공유 시트
7. 공유 동선(앱 내 추천/좋아요) + 취향 온보딩
8. 내 페이지/설정/고객센터
