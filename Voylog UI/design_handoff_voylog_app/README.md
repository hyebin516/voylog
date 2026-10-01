# Handoff: Voylog — 브이로그 기반 여행 동선 앱 (v2)

## Overview
Voylog는 YouTube 여행 브이로그 링크를 넣으면 AI가 영상 속 장소를 찾아 **여행 동선(Route)** 으로 정리해 주는 모바일 앱입니다.
이 번들은 온보딩 → 로그인 → 홈 → 분석 → 북마크/여행 일정/마이페이지까지 **총 34개 화면**으로 된 인터랙티브 프로토타입과, 구현에 필요한 스펙을 담고 있습니다.

### About the Design Files
번들 안의 HTML 파일은 **HTML로 만든 디자인 레퍼런스**입니다. 의도한 외형과 동작을 보여주는 프로토타입이며, 그대로 배포할 프로덕션 코드가 아닙니다.
구현할 때는 대상 코드베이스의 기존 환경(React Native, Flutter, SwiftUI, React 등)과 그 패턴·라이브러리로 **다시 구현**해야 합니다. 아직 환경이 없다면 모바일 앱에 가장 적합한 프레임워크(예: React Native + Expo)를 골라 구현하세요.

## Fidelity
**High-fidelity (hi-fi).** 색상, 타이포그래피, 간격, 라운드, 그림자, 인터랙션이 최종값입니다. 아래 토큰과 화면 명세대로 픽셀 단위로 재현하세요.
예외(플레이스홀더):
- 사줄 무늬 박스(`지도 영역`, `장소 사진`, `썸네일`, `YOUTUBE PLAYER`)는 실제 지도 SDK·이미지·영상 플레이어로 바꿔야 할 자리입니다.
- 온보딩 일러스트의 사진(`assets/*.png`)은 스크린샷에서 잘라낸 저해상도 임시 이미지입니다. 원본 에셋으로 교체하세요.

---

## Platform & Frame
| 항목 | 값 |
|---|---|
| 플랫폼 | 모바일 앱 (iOS / Android), 세로 고정 |
| 기준 프레임 | **375 × 812 px** (iPhone X/11 Pro 논리 해상도) |
| 프로토타입 외곽 | 폰 목업 radius 44px, shadow `0 20px 50px rgba(20,110,120,.18)` (구현 불필요) |
| 상단 안전영역 | 화면 헤더 상단 padding **56px** (상태바 포함) |
| 하단 탭바 | 높이 약 **70px** (padding 9px 6px 14px), 상단 radius 28px |
| 스크롤 | 콘텐츠 영역만 세로 스크롤, **스크롤바는 숨김** (`scrollbar-width:none`) |
| 가로 스크롤 | 홈 “취향이 비슷한 사람들의 북마크” 캐러셀만 사용 (scroll-snap) |

> 프로토타입 상단의 `화면: ○○ · 로그인됨 · 처음으로` 검정 필은 **데모용 디버그 바**이므로 구현하지 않습니다.

---

## Design Tokens

### Colors
**Brand / Primary (Teal)**
| Token | Hex | 용도 |
|---|---|---|
| `primary-900` | `#0f3440` | 제목·본문 기본 텍스트(ink) |
| `primary-700` | `#127c85` | 홈 헤더 `분석하기` 버튼 |
| `primary-600` | `#158a92` | Primary 버튼, 활성 탭, 링크 |
| `primary-550` | `#148a90` | 칩 텍스트, 아이콘 선 |
| `primary-500` | `#169aa4` | 브랜드 기본(아이콘·배지·강조) |
| `primary-400` | `#2bb3b8` | 번호 원형 배지(분석 장소 번호) |
| `primary-300` | `#85b5b8` | 보조 아이콘 선 |
| `primary-200` | `#bde2e1` | 점선 테두리(추가 버튼), 강조 카드 테두리 |
| `primary-150` | `#d6ecec` | 입력/칩 테두리 |
| `primary-100` | `#e6f5f4` | 활성 탭 필, 배지 배경 |
| `primary-75`  | `#e8f6f5` | 아이콘 박스 배경 |
| `primary-50`  | `#eef8f8` | 해시태그 칩 배경 |
| `surface-tint`| `#f1f8f8` | 보조 버튼/필드 배경 |
| `surface-subtle` | `#f7fbfb` | 리스트 카드 배경 |
| `surface-page` | `#f8fbfb` | 화면 배경, 시트 배경 |
| `surface` | `#ffffff` | 카드, 탭바 |

**Neutral (Teal-gray)**
| Token | Hex | 용도 |
|---|---|---|
| `text-secondary` | `#2f7f86` | 보조 텍스트(강조 가능한 2순위) |
| `text-tertiary` | `#5f7f85` | 설명/서브 텍스트 |
| `text-muted` | `#8ea6ab` | 캡션, 메타 정보 |
| `text-disabled` | `#a3bcc0` | 비활성 탭 아이콘·라벨 |
| `border-strong` | `#c5d8da` | 비활성 아이콘 선 |
| `border` | `#e5f1f1` | 카드 테두리 1.5px |
| `divider` | `#e2eeef` | 구분선 1px |
| `bg-app` | `#e9eef0` | 프로토타입 외부 배경 / 줄무늬 플레이스홀더 |

**Semantic**
| Token | Hex | 용도 |
|---|---|---|
| `danger` | `#e2554f` | 좋아요(활성 하트), 삭제(휴지통), 에러 |
| `danger-bg` | `#fdf1f0` | 휴지통 버튼 배경 |
| `warning-icon` | `#e8a13a` | 안내 배너 아이콘, 저장 수 북마크 |
| `warning-bg` | `#fff4d6` | 안내 배너 / 저장 수 칩 배경 |
| `warning-text` | `#8a5d14` | 안내 배너 텍스트 |
| `success` | `#5fc2a0` | `영업중` 배지 |
| `accent-orange` | `#f0a83a` | 2일차 색, 북마크 채움 아이콘 |
| `accent-coral` | `#d9784f` / bg `#fdf1ea` | 단점 배지, 보조 아바타 |
| `kakao` | `#FEE500` / text `#3a2b1a` | 카카오 로그인 버튼 |
| `scrim` | `rgba(20,40,55,.4)` | 바텀시트/모달 딤 |
| `toast` | `#0f3440` | 토스트 배경 |

**Gradients**
| 이름 | 값 |
|---|---|
| 온보딩 배경 | `linear-gradient(160deg, #169eab 0%, #1fa8b3 45%, #3bb9be 100%)` + 우상단 radial glow `rgba(120,220,210,.45)→0` (260×260, top −60 right −80) |
| 홈 헤더 | `linear-gradient(160deg, #28abb5 0%, #1f9ca6 60%, #1b919b 100%)` + radial glow `rgba(120,220,210,.35)→0` (260×260, top −80 right −90) |
| 분석 중 배경 | `linear-gradient(180deg, #14939d 0%, #0f7a84 55%, #0b5f67 100%)` |
| 플레이스홀더 줄무늬 | `repeating-linear-gradient(45deg, #e9eef0 0 10px, #eaf5f4 10px 20px)` |

### Typography
- **Family:** `Pretendard Variable` (번들 `assets/fonts/PretendardVariable.woff2`, weight 45–920), fallback `Pretendard, sans-serif`
- **보조 폰트 (온보딩 전용):** 로고 워드마크 `Poppins 700`, 손글씨 캡션 `Caveat 500` (Google Fonts)
- 별도 표기가 없으면 line-height는 **normal(≈1.2)**, letter-spacing은 **0**

| Style | Weight | Size | Line-height | Letter-spacing | 사용처 |
|---|---|---|---|---|---|
| Display | 800 | 33px | 1.3 | −1px | 온보딩 헤드라인 |
| H1 | 800 | 29px | 1.35 | −0.8px | 홈 헤더 타이틀 |
| H2 | 800 | 24px | normal | −0.6px | 분석 중 타이틀 |
| H3 | 800 | 20px | normal | 0 | 탭 루트 화면 타이틀(여행 등) |
| H3-alt | 700 | 20px | 1.4 | 0 | 장소 상세 이름, 온보딩 서브 화면 |
| Sheet title | 800 | 18px | normal | 0 | 바텀시트 제목 |
| Section | 800 | 17px | normal | −0.4px | 홈 섹션 제목 |
| Header | 700 | 17px | normal | 0 | 하위 화면 헤더 타이틀 |
| Title-L | 700 | 16px | normal | −0.3px | 홈 리스트 행 제목 |
| Button-L | 700 | 16px / 15.5px | normal | −0.3px | 주요 CTA |
| Title-M | 700 | 15px | normal | 0 | 카드 섹션 제목 |
| Body-L | 500 | 14.5px | 1.6 | −0.2~−0.3px | 헤더 설명문 |
| Title-S | 700 | 14 / 14.5px | normal | 0 | 카드 제목 |
| Body | 500 | 14px | 1.5 | 0 | 본문 |
| Label | 600/700 | 13.5px | normal | 0 | 버튼·배너·행 라벨 |
| Body-S | 500 | 13px | normal | 0 | 행 서브텍스트 |
| Chip | 700 | 12.5px | normal | 0 | 해시태그 칩 |
| Caption | 500 | 12 / 12.5px | normal (요약문 1.55) | 0 | 메타, 설명 |
| Badge | 600/700 | 11 / 11.5px | normal | 0 | 태그, 시간 배지 |
| Badge-S | 700 | 10.5px | 1 | 0 | 취향 일치 배지 |
| Tab label | 600 (활성 700) | 11px | normal | 0 | 하단 탭바 |

### Radius
| Token | px | 용도 |
|---|---|---|
| `r-pill` | 999px | 칩, 배지, 원형 버튼, 필 버튼 |
| `r-sheet` | 28px 28px 0 0 | 바텀시트, 홈 흰색 시트, 탭바 상단 |
| `r-intro-sheet` | 26px 26px 0 0 | 온보딩 하단 시트 |
| `r-cta` | 24–26px | 전폭 CTA (높이 48–52px, 높이/2) |
| `r-xl` | 22px | `.btn-primary`, `.btn-kakao`, `.btn-ghost` |
| `r-card` | 20px | 카드, 입력 필드(`.field`) |
| `r-lg` | 18px | 지도 박스, 점선 추가 버튼 |
| `r-md` | 16px | 안내 배너, 카드 썸네일(64px) |
| `r-sm` | 14px | 탭 활성 필(60×36), 여행 파일 아이콘, 입력칸 |
| `r-xs` | 12px | 36px 뒤로가기 버튼, 해시태그 칩, 아이콘 박스 |
| `r-2xs` | 10px | 30px 아이콘 버튼(연필/휴지통) |

### Shadows
| Token | 값 | 용도 |
|---|---|---|
| `sh-card` | `0 4px 14px rgba(22,154,164,.10)` | 기본 카드 |
| `sh-card-soft` | `0 4px 14px rgba(22,154,164,.07)` | 리스트 카드 |
| `sh-field` | `0 3px 10px rgba(22,154,164,.08)` | 입력 필드 |
| `sh-icon-btn` | `0 3px 8px rgba(22,154,164,.15)` | 원형 아이콘 버튼(지도/북마크) |
| `sh-back-btn` | `0 4px 12px rgba(22,154,164,.12)` | 흰색 뒤로가기 버튼 |
| `sh-primary` | `0 6px 14px rgba(21,138,146,.28)` | Primary 소형 버튼 |
| `sh-cta` | `0 10px 20px rgba(21,138,146,.25)` / `.btn-primary` `0 10px 22px rgba(21,138,146,.35)` | 전폭 CTA |
| `sh-fab` | `0 12px 24px rgba(21,138,146,.40)` | 홈 FAB |
| `sh-hero-input` | `0 10px 24px rgba(0,50,60,.18)` | 홈 헤더 링크 입력 카드 |
| `sh-float-card` | `0 10px 24px rgba(0,50,60,.28)` | 온보딩 떠 있는 카드 |
| `sh-tabbar` | `0 -6px 20px rgba(22,154,164,.08)` | 하단 탭바 |
| `sh-sheet` | `0 -12px 30px rgba(30,60,80,.15)` | 바텀시트 |
| `sh-toast` | `0 8px 20px rgba(0,0,0,.20)` | 토스트 |

### Spacing
기본 4px 그리드. 자주 쓰는 값: **4 · 6 · 8 · 10 · 12 · 14 · 16 · 18 · 20 · 22 · 24 · 28 · 30 · 36 · 56px**
| 용도 | 값 |
|---|---|
| 화면 좌우 여백 | **20px** (홈 시트·헤더 **24px**, 온보딩 시트 **30px**) |
| 헤더 상단 | 56px (홈 헤더 58px) |
| 카드 내부 padding | 12px / 14px 16px / 14px 15px |
| 리스트 행 padding | 14px 0 (구분선 1px `#e5eeee`) |
| 섹션 간 간격 | 26px (섹션 제목 margin 26px 0 12px) |
| 카드 간 gap | 12px (리스트), 10px (날짜 카드), 8px (칩) |
| 요소 내부 gap | 4 / 6 / 8 / 10 / 12 / 14px |
| 바텀시트 padding | 22px 22px 28–30px, 핸들 38×5px radius 3px `#e1eeee`, 핸들 아래 18px |

### 공통 컴포넌트 치수
- **하단 탭바:** 5탭(홈·분석·북마크·여행·내 페이지). 아이콘 **24px**, 아이콘 컨테이너 60×36px radius 14px (활성 배경 `#e6f5f4`), 라벨 11px. 활성 색 `#158a92`, 비활성 색 `#a3bcc0`, 아이콘 선 1.8–2px.
- **뒤로가기 버튼:** 36×36px, radius 12px, 흰색 또는 `#f1f8f8`, chevron 17px `#2f7f86` stroke 2.2px.
- **Primary CTA:** 높이 48–52px, radius 높이/2, `#158a92`, 흰 텍스트 700 15.5–16px, hover `#117a81`, active scale .98. 비활성 `#b8cfd1`(여행 만들기) / `#b8cfd1` 계열.
- **원형 아이콘 버튼:** 32–34px, 흰색, `sh-icon-btn`, 아이콘 15px `#5f7f85` stroke 1.8px.
- **칩/배지:** radius 999px, padding 3–5px 8–12px.

---

## Navigation model
- **단일 스택 + 탭** 구조. 프로토타입은 `state.screen` 문자열 하나로 화면을 전환합니다(`go(screen)`), 화면 전환 시 모든 시트/모달 플래그를 닫습니다.
- **시작 화면:** `intro`(온보딩) → `login`.
- **하단 탭(루트):** `home` · `analysis` · `bookmarkFolders` · `tripList` · `myPage`. 탭 이동은 스택 초기화(replace)로 구현하세요.
- **복귀 경로를 기억하는 화면** (진입 화면으로 돌아감):
  - `placeDetail` ← `placeFrom`
  - `routeDetail` ← `routeFrom`
  - `folderDetail` ← `folderFrom`
  - `similarTaste` ← `similarFrom` (`myPage`에서 왔으면 myPage, 그 외 home)
- **흐름 요약**
```
intro ─(동선 만들기 시작)→ login ─┬→ home
                                  ├→ signup → emailVerify → home
                                  └(비회원)→ home
home ─(분석하기)→ analyzing ─(자동, 약 4초)→ analysis → analysisComplete → transport
home ─ 내 주변 추천 → nearbySurvey → nearby
home ─ 뚜벅이 코스 → walkingSetup → walkingCourse
home ─ 해시태그 더보기 → regionSelect → themeSelect → durationSelect → recommendedVlogs
home ─ 북마크 전체보기 → similarTaste ;  카드 → placeDetail → placeSummary
home ─ 추천 동선 카드 → routeDetail(shared) ;  FAB → savedRoutes → routeDetail(saved)
tripList ─(+ / 파일)→ tripCreate → hotelSelect → dayPlaceSelect → dayOptimize → transport
                         └ 전체 일정 → tripOverview (공유 시트)
myPage → accountSettings / preferences / similarTaste / notificationSettings / support
```

---

## Screens & Views
표기: 크기는 px, 색은 hex. “공통 헤더”는 padding 56px 20px 14px, 뒤로가기 버튼 + 제목(700 17px `#0f3440`), gap 12px.

### 01. 온보딩 `intro` — **신규**
- **목적:** 앱 가치 소개, 시작 CTA.
- **배경:** 온보딩 그라디언트(전면).
- **로고 (top 44, 가로 중앙, gap 10):** 흰색 42×42 radius 11 박스(shadow `0 4px 12px rgba(0,60,70,.18)`) 안에 동선 아이콘(점 3개를 곡선으로 이은 모양, `#169aa4`, 30×27) + 워드마크 “Voylog” Poppins 700 38px 흰색, letter-spacing −0.5px.
- **일러스트 그룹 (전체 scale .86, origin 50% 240px):**
  - 영상 카드: left 36 top 152, 162×104, rotate −7°, 흰 테두리 5px radius 10, `sh-float-card`. 썸네일 위에 반투명 재생 버튼(30×22 radius 6 `rgba(255,255,255,.7)`, ▶ `#3aa6b0`), 우하단 “12:34”(500 8px), 진행바(2px, 32%).
  - YouTube 배지: 36×30 흰 radius 8 안에 26×19 `#f00` radius 5 + 흰 ▶.
  - 지도 카드: left 208 top 224, 160×112, rotate 3.5°, padding 6 gap 6. 좌측 86px 지도 이미지, 우측 썸네일 26×27 radius 4 ×3 + 시간(01:12 / 04:36 / 08:20, 500 7.5px `#1a8f99`).
  - 손글씨: “From / Vlog”(Caveat 500 21px, rotate −12°), “To / Travel Route”(Caveat 500 19px, rotate −11°), 흰색 곡선 화살표 3개, 반짝임 선 2세트.
- **풍경 이미지:** top 336, 높이 176, cover, 위쪽 34%를 투명→불투명 마스크로 페이드.
- **하단 시트:** top 474 ~ bottom, `#f8fbfb`, radius 26 26 0 0, padding 36px 30px 0, **가운데 정렬**.
  - 헤드라인 Display: “브이로그가 / **여행 일정**이 되는 순간”. “여행 일정”은 `#149aa3`, 아래 손그림 밑줄(2.5px `#1a9aa3`).
  - 설명 Body-L `#3a4a50`, margin-top 24: “유튜브 영상 링크 하나만 넣어보세요. / AI가 영상 속 장소를 찾아 동선으로 정리해드려요.”
  - CTA margin-top 30, 전폭, 높이 48, radius 24, `#158a92`, “동선 만들기 시작” 700 15.5px **정중앙**, → 화살표는 오른쪽 22px에 absolute. shadow `sh-cta`.

### 02. 로그인 `login`
- 로고 + “반가워요! / 로그인하고 일정을 이어가요”, 이메일·비밀번호 `.field`(radius 20, `#f1f8f8`, padding 15px 18px), “비밀번호를 잊으셨나요?” 링크, `로그인`(.btn-primary), `카카오로 3초만에 로그인`(.btn-kakao), `비회원으로 둘러보기`(.btn-ghost), 하단 “Voylog가 처음이신가요? 회원가입”.

### 03. 회원가입 `signup` / 04. 이메일 인증 `emailVerify`
- 닉네임(중복확인, 에러 “이미 사용 중인 닉네임이에요…” `#e2554f`), 이메일(인증하기), 비밀번호/확인(불일치 에러), 약관 동의 체크, `가입하기`.
- 이메일 인증: 6자리 코드 박스, “재전송 (0:47)”, `인증 완료`.

### 05. 홈 `home` — **크게 재구성**
- **헤더 (스크롤 영역 안, padding 58px 24px 56px, 홈 헤더 그라디언트):**
  - H1 흰색 “영상 한 편이면, / 여행 동선 완성”
  - Body-L `rgba(255,255,255,.92)`, margin-top 12: “YouTube 링크만 붙여넣으세요. / 장소 추출부터 동선까지 AI가 해드려요”
  - 링크 입력 카드 (margin-top 26): 바깥 링 padding 5px radius 26 `rgba(255,255,255,.22)` → 안쪽 흰 카드 radius 21, padding 7px 7px 7px 14px, gap 10, `sh-hero-input`. 링크 아이콘 18px `#148a90` / 입력(placeholder “YouTube 링크 붙여넣기”, 500 14px, letter-spacing −0.3px) / `분석하기 →` 버튼(높이 46, padding 0 13px, radius 15, `#127c85`, 700 15px, hover `#0f6c74`).
- **흰 시트 (margin-top −26, radius 28 28 0 0, padding 24px 24px 0):**
  1. 안내 배너: `#fff4d6` radius 16 padding 14px 18px, ⚠ 아이콘 `#e8a13a` 16px + “현재는 국내 여행 브이로그만 분석이 가능해요” 700 13.5px `#8a5d14`.
  2. 리스트 행 2개(margin-top 8): 원형 아이콘 38×38 `#e6f4f3`(아이콘 17px) · 제목 Title-L · 서브 Body-S `#5f7f85` · chevron 9×14 `#9fb2b5`. 행 padding 14px 0, gap 12, 첫 행 아래 구분선 1px `#e5eeee`.
     - `내 주변 추천` / “지금 근처 갈 만한 곳” (핀 아이콘 `#148a90`)
     - `뚜벅이 코스` / “걸어서 도는 코스” (걷는 사람 아이콘 `#2f6b5c`)
  3. 섹션 “해시태그로 브이로그 찾아보기”(Section 17px) + 우측 `더보기`(700 13px `#148a90`). 칩 5개(#제주도 #부산여행 #서울맛집 #강릉바다 #경주): 700 12.5px `#148a90`, bg `#eef8f8`, border 1px `#d6ecec`, radius 12, padding 7px 12px, gap 8.
  4. 섹션 “취향이 비슷한 사람들의 북마크” + `전체보기`, 설명 “나와 취향 일치율이 높은 사용자가 저장한 장소예요”. **가로 캐러셀:** 좌우 −24 margin으로 풀블리드, padding 2px 24px 24px, gap 12, scroll-snap x mandatory. 카드 272px 고정, radius 20, border 1.5px `#e5f1f1`, padding 12, `sh-card-soft`: 64×64 radius 16 사진 · 제목 700 14px(말줄임) · “카페 · 제주 애월” 500 12px `#8ea6ab` · 배지 “취향 일치 94%”(700 10.5px `#158a92`/`#e6f5f4`, 높이 20, 텍스트 **수직·수평 중앙**) · 우측 34×34 radius 12 북마크 버튼(`#f1f8f8`).
     - 카드 데이터: 애월 오션뷰 카페 놀(94%, 저장 12) / 감천문화마을 골목(88%, 31) / 경포 해변 노을 산책로(85%, 9). **저장 수는 홈에서 표시하지 않고 장소 상세에서만 표시.**
  5. 섹션 “다른 유저의 추천 동선”, 설명 “직접 다녀오고 좋았던 동선을 공유한 사람들이에요”. 카드(radius 20, padding 14px 15px): 아바타 28px 원 · 작성자 600 12px `#5f7f85` · **좋아요 버튼**(빈 하트 16px, 아래 인터랙션 참고) · 제목 700 14.5px · 메타 500 12px · 태그 칩(600 11px `#2f7f86`/`#f1f8f8`).
     - 내가 추천한 동선 카드: border 1.5px `#bde2e1`, 아바타 `#158a92` 흰 이니셜, “내 추천” 배지, 제목 옆 **연필(제목 수정)** 30×30 radius 10 `#f1f8f8` / **휴지통(추천 취소)** 30×30 radius 10 `#fdf1f0`, 아이콘 `#e2554f`.
     - 하단 `+ 내 동선 추천하기` 점선 버튼(2px dashed `#bde2e1`, radius 18, padding 14, bg `#f7fbfb`).
- **FAB:** right 24 bottom 104, 56×56 radius 20, `#158a92`, `sh-fab`, 동선 아이콘 → `savedRoutes`.
- **토스트:** bottom 100, 가운데, “추천 동선에 추가됐어요” 600 13px, padding 11px 18px, pill, 1.8초 후 사라짐.
- **바텀시트:** 내 동선 추천하기(저장 동선 목록 + `추천`/`추천됨` 버튼), 북마크 저장(폴더 선택/새 폴더).

### 06. 분석 중 `analyzing` — **신규**
- 전체 `분석 중 배경` 그라디언트, 세로·가로 중앙, 좌우 padding 40.
- 아이콘 130×130: 흰 핀(80×104) 안에 ▶ `#0f7a84`, 아래 타원 링 2개(외곽 `rgba(255,255,255,.18)`, 내부 `.55`, stroke 2px).
- 타이틀 H2 흰색 “영상을 분석하고 있어요” (margin-top 34)
- 서브 500 14px `rgba(255,255,255,.8)` “잠시만 기다려 주세요 · 약 {N}초” (N = 20→1 카운트다운)
- 진행바 margin-top 26, 전폭, 높이 8, radius 4, 트랙 `rgba(255,255,255,.25)`, 채움 흰색(width 트랜지션 .12s linear)
- 단계 리스트 margin-top 22, gap 14, 600 15px: `자막 불러오기` → `장소 후보 추출` → `지도 좌표 매칭` → `결과 정리`. 상태 아이콘: 완료 `✓`(흰색), 진행 중 `◔`(흰색), 대기 `○`(`rgba(255,255,255,.45)`, 텍스트도 동일).

### 07. 동선 분석 `analysis` — **일부 변경**
- 공통 헤더 “동선 분석”. 16:9 영상 플레이어(radius 20) + “15:47”. 제목 “제주도 2박 3일 완벽 동선 브이로그” 700 16px/1.4, “등장 순서대로 정리된 장소 6곳”.
- 장소 카드 6개(bg `#f7fbfb`, radius 20, padding 12px 14px, gap 12): 번호 원 28px `#2bb3b8` · 이름 700 14px · 타임스탬프 배지(600 11px `#2f7f86`/`#e6f5f4`) · 카테고리 · `더보기 ⌄` 토글(장점/단점 AI 요약 패널, 배지 `#158a92`/`#e6f5f4`, `#d9784f`/`#fdf1ea`) · 우측 지도/북마크 원형 버튼 34px.
- **1일차/2일차 구분 헤더는 삭제됨** — 장소 카드만 연속 표시.

### 08. AI 추천 동선 `analysisComplete` / 09. 동선 결과 `transport`
- 지도 영역(220px) + 순서 리스트, 이동수단 선택(자동차/도보/대중교통), `동선 저장하기`(저장 시트: 폴더 선택).
- transport: 요약(총 이동시간 51분 · 32.6km), H(호텔) → 1 → 2 … 타임라인, 구간별 “차로 11분 · 6.4km”.

### 10. 북마크 `bookmarkFolders` / 11. 폴더 상세 `folderDetail`
- 폴더 카드 3개(제주도 여행 5곳, 가보고 싶은 맛집 12곳, 부산 여행 8곳). 폴더 상세: 장소 리스트, `장소 추가하기`(검색 시트), `AI 동선 생성하기`(비회원이면 로그인 필요 모달).

### 12. 저장한 동선 `savedRoutes` / 13. 동선 상세 `routeDetail` — **일부 변경**
- 저장 동선 리스트 + `생성`(새 동선 시트).
- 동선 상세: 지도 영역(196px) + “저장된 순서” 리스트. 공유 동선이면 작성자/좋아요 헤더.
- **변경:** 장소 행 우측의 카테고리 태그(교통/카페 등)를 제거하고 **지도 버튼 + 북마크 버튼**(32×32 원형, `sh-icon-btn`)으로 교체.

### 14–17. 해시태그 탐색 `regionSelect` → `themeSelect` → `durationSelect` → `recommendedVlogs`
- 다중 선택 칩 그리드 + 하단 `다음 (N개 선택됨)`. 추천 브이로그: 썸네일 카드 + `분석` 버튼 → analysis.

### 18. 내 페이지 `myPage` / 19–21. 설정
- 프로필(닉네임 수정 시트), 통계(저장한 동선 3, 북마크 폴더 3), 메뉴(계정 설정·취향 설정·취향 맞춤 추천·알림 설정·고객센터), 로그아웃/회원탈퇴 확인 모달.
- `accountSettings`, `notificationSettings`(토글), `support`(FAQ 아코디언).

### 22–23. 뚜벅이 `walkingSetup` → `walkingCourse`
- 지역/분위기/걷는 시간 선택 → 도보 코스(4곳, 약 2시간 40분) 타임라인.

### 24. 장소 상세 `placeDetail` — **일부 변경** / 25. AI 요약 `placeSummary`
- 상단 220px 사진 + 뒤로/북마크 버튼(36px radius 12). 이름(**진입한 카드 이름으로 동적**), 주소, 태그 칩, **“N명이 저장” 칩**(홈 북마크 카드에서 진입 시에만: 600 11.5px `#8a5d14` / `#fff4d6`, 북마크 아이콘 11px `#e8a13a`), 영업시간(`영업중` `#5fc2a0`), 전화, 지도(130px), “이 장소가 언급된 영상”, `내 여행에 추가`.

### 26. 취향 설정 `preferences` / 27. 취향 알아보기 `nearbySurvey` / 28. 내 주변 추천 `nearby`
- 칩 다중 선택(3개 이상 권장, `건너뛰기`). nearby: 카테고리 필터 + 거리/영업 상태 카드 + 북마크 시트.

### 29. 여행 목록 `tripList` — **신규**
- 헤더 padding 56px 20px 18px: “여행” H3 + 우측 **+ 버튼**(40×40 radius 14 `#158a92`, 흰 + 18px stroke 2.4, `sh-primary`, hover `#117a81`).
- “내 여행 파일 N개” 500 13px `#5f7f85`.
- 파일 카드(gap 12): 흰색 radius 20 padding 14px 16px `sh-card`, 폴더 아이콘 박스 46×46 radius 14 `#e6f5f4`, 이름 700 15.5px, 기간 “2026.09.12 – 2026.09.14” 500 12.5px `#5f7f85`, chevron.
- 기본 데이터: `제주도 여행` 2026-09-12 ~ 2026-09-14.
- **새 여행 만들기 시트:** 제목 800 18px · “여행 이름” 입력(높이 48, radius 14, border 1.5px `#d6ecec`) · “여행 날짜” 시작/종료 date 입력 2개(– 구분) · **두 날짜가 모두 선택되면 지도 박스(190px, radius 18) 표시**, 좌상단 흰 필 배지에 “N박 N+1일”(같은 날이면 “당일치기”) · `여행 만들기` CTA(52px, 이름·날짜 다 채우면 `#158a92`, 아니면 `#b8cfd1`).

### 30. 여행 일정 `tripCreate` — **일부 변경**
- **변경:** 헤더에 뒤로가기(→ tripList) 추가, 여행 이름·기간을 선택한 파일 데이터로 표시, 날짜 필드 아래 **지도 박스(150px, radius 18)** 추가.
- 날짜 카드(1일차 `#169aa4`, 2일차 `#f0a83a` 배지): 날짜, 삭제(휴지통 `#e2554f`), 숙소 행(“왕복” 배지), “저장된 장소 3곳 · 51분 · 32.6km”. `+ 날짜 추가`. 우상단 `전체 일정` → tripOverview.

### 31–33. `hotelSelect` → `dayPlaceSelect` → `dayOptimize`
- 시작/종료 호텔 선택(왕복 토글), 북마크 폴더 선택(2~10곳), 이동수단 다중 선택 + 장소 순서 → transport.

### 34. 전체 일정 `tripOverview`
- 여행 전체 타임라인 + `일정 공유하기` 시트(카카오톡 / 링크 복사 / 메시지 / 이미지 저장).

### 35. 취향 맞춤 추천 `similarTaste` — **동작 변경**
- 칩 필터 + 장소 리스트(“취향 89% 일치 · 24명 저장”). **뒤로가기는 진입 화면으로**(홈에서 왔으면 홈, 내 페이지에서 왔으면 내 페이지).

---

## Interactions & Behavior
| 트리거 | 동작 |
|---|---|
| 온보딩 `동선 만들기 시작` | → login |
| 홈 `분석하기` | → analyzing. 50ms마다 진행률 +1.25%(총 ≈4초). 25/50/75/100%에서 단계 완료 처리. 100% 도달 400ms 후 → analysis (`hasAnalyzed=true`). 실제 구현에서는 **서버 분석 진행 이벤트**로 대체 |
| 탭바 `분석` | 분석 중 화면 없이 바로 analysis |
| 추천 동선 **하트** | 빈 하트(stroke `#8ea6ab` 1.8px, fill none) ↔ 빨간 하트(fill/stroke `#e2554f`), 숫자 +1/−1(128↔129, 76↔77). 카드 클릭(상세 이동)과 **이벤트 전파 차단** |
| `+ 내 동선 추천하기` | 시트 열기 → 저장 동선별 `추천` 클릭 시 목록에 추가, 시트 닫힘, 토스트 1.8초. 이미 추천한 항목은 `추천됨`(bg `#e6f5f4`, text `#158a92`), 비활성 |
| 내 추천 카드 **연필** | 제목이 입력창(높이 34, border 1.5px `#169aa4`, radius 10) + `저장` 버튼으로 전환. 빈 값 저장 시 기존 제목 유지 |
| 내 추천 카드 **휴지통** | 추천 목록에서 제거. 해당 동선 상세를 보고 있던 인덱스는 0으로 리셋(크래시 방지) |
| 북마크 캐러셀 | 가로 스와이프, snap start, 스크롤바 숨김 |
| 북마크 카드 탭 | placeDetail(이름·저장 수 전달) |
| 여행 탭 | tripList. `+` → 새 여행 시트. 시작일 변경 시 종료일이 더 빠르면 종료일=시작일로 보정. `여행 만들기` → 목록 추가 + 해당 여행의 tripCreate |
| 바텀시트 | 딤(`rgba(20,40,55,.4)`) 탭으로 닫힘, 시트 내부 탭은 전파 차단 |
| Hover/Active | Primary 버튼 hover `#117a81` / `분석하기` hover `#0f6c74` / CTA active scale(.98) |
| 로그인 필요 | 비회원이 `AI 동선 생성하기` 탭 → 로그인 필요 모달(로그인하기/회원가입하기/다음에 할게요) |

애니메이션: 진행바 width `.12s linear`, 입력 border-color `.2s`. 그 외 화면 전환은 네이티브 기본 push/pop을 권장합니다.

---

## State Management
| 상태 | 타입 | 설명 |
|---|---|---|
| `screen` | string | 현재 화면 키(위 목록). 기본 `'intro'` |
| `isLoggedIn` | bool | 회원/비회원 |
| `nickname`, `nicknameDraft` | string | 기본 `voylog_moon` |
| `hasAnalyzed` | bool | 분석 결과 존재 여부(빈 상태 분기) |
| `anProg` | number 0–100 | 분석 진행률 → `anRemain = ceil(20·(1−p/100))` |
| `p1…p6` | bool | 분석 장소 카드 더보기 펼침 |
| `liked0`, `liked1` | bool | 추천 동선 좋아요 |
| `mySharedIdxs` | number[] | 내가 추천한 저장 동선 인덱스 |
| `sharedTitles` | {idx: string} | 내 추천 동선 제목 오버라이드 |
| `editingShared`, `sharedDraft` | number / string | 제목 편집 상태 |
| `shareToast` | bool | 토스트 표시 |
| `sharedIdx`, `routeIdx`, `routeKind` | number / `'saved'\|'shared'` | 동선 상세 대상 |
| `trips` | `{name,start,end}[]` | 여행 파일(ISO 날짜) |
| `tripIdx` | number | 선택한 여행 |
| `newTripName/Start/End`, `showTripNew` | string / bool | 새 여행 시트 |
| `currentDay`, `hotelChosen` | number / bool | 일정 편집 |
| `pdName`, `pdSaves` | string / number | 장소 상세 동적 값 |
| `placeFrom`, `routeFrom`, `folderFrom`, `similarFrom` | string | 뒤로가기 복귀 화면 |
| `show*` | bool | 각 바텀시트/모달(`showShareSheet`, `showBookmarkSheet`, `showNewFolder`, `showSaveRoute`, `showLoginRequired`, `showAddPlace`, `showNewRoute`, `showExportSheet`, `showEditNickname`, `showLogoutConfirm`, `showWithdrawConfirm`) |

**API가 필요한 곳(프로토타입은 목업 데이터):** 링크 분석(작업 생성 + 진행 이벤트), 장소 검색/좌표, 동선 최적화(이동시간·거리), 북마크/폴더 CRUD, 여행 파일 CRUD, 추천 동선 공유/좋아요/수정/삭제, 취향 기반 추천, 인증(이메일·카카오).

---

## 이전 버전 대비 달라진 점
기준: `reference/voylog-prototype-source-previous.dc.html` (블루 계열, M PLUS Rounded 1c).

### 전역
- **컬러:** 블루(`#3d9fdb`, `#2f8fd0`, `#5fc2e8`, `#1c3f52` …) → 틸(`#169aa4`, `#158a92`, `#2bb3b8`, `#0f3440` …)로 전체 교체. 블루 그라디언트 버튼은 단색 `#158a92`로 바꿈.
- **폰트:** M PLUS Rounded 1c → **Pretendard Variable**.
- **배경 장식:** 화면 뒤 원형 블롭(`.blob`) 전부 제거, 화면 배경은 `#f8fbfb` 단색.
- **탭바:** 아이콘 18→**24px**, 라벨 10→**11px**, 활성 필 38×30 radius 13 → **60×36 radius 14**. 여행 탭 진입 화면이 tripCreate → **tripList**로 바뀜.
- **스크롤바:** 모든 화면에서 숨김.

### 겉모습만 바뀐 화면 (전역 스타일만 적용, 구조 동일)
login, signup, emailVerify, analysisComplete, bookmarkFolders, folderDetail, savedRoutes, regionSelect, themeSelect, durationSelect, recommendedVlogs, myPage, accountSettings, notificationSettings, support, walkingSetup, walkingCourse, placeSummary, preferences, nearbySurvey, nearby, tripOverview, hotelSelect, dayPlaceSelect, dayOptimize, transport

### 크게 재구성된 화면
- **홈 (`home`)**
  - 로고 + 좌측 정렬 타이틀 → **틸 그라디언트 헤더** + 흰 링크 카드(`분석하기` 텍스트 버튼)
  - 2열 카드(내 주변 추천/뚜벅이) → **아이콘 + chevron 리스트 행**
  - 해시태그 칩 스타일 변경, `더보기`를 섹션 제목 오른쪽으로 옮김
  - 취향 북마크: 세로 리스트 → **가로 캐러셀**, `더보기`→`전체보기`, “N명이 저장” 제거
  - 추천 동선: 채워진 하트 → **토글형 빈 하트**, 내 동선 추천이 실제로 추가·수정·삭제됨
  - `분석하기`는 분석 중 화면을 거치게 됨

### 부분 변경된 화면
- **analysis:** 1일차/2일차 구분 헤더 삭제
- **routeDetail:** 장소 행의 카테고리 태그 → 지도·북마크 아이콘 버튼
- **tripCreate:** 뒤로가기 추가, 이름·기간 동적 표시, 지도 박스 추가
- **placeDetail:** 이름 동적, “N명이 저장” 칩 추가
- **similarTaste:** 뒤로가기가 진입 화면(홈/내 페이지)으로 돌아감

## 새로 추가된 화면
| 화면 | 진입 위치 | 보여주는 것 |
|---|---|---|
| **온보딩 `intro`** | 앱 첫 실행(시작 화면), 디버그 바 `처음으로` | 브랜드 로고, “From Vlog → To Travel Route” 일러스트, 헤드라인 “브이로그가 여행 일정이 되는 순간”, `동선 만들기 시작` → 로그인 |
| **분석 중 `analyzing`** | 홈 헤더 링크 카드의 `분석하기` 버튼 | 핀+재생 아이콘, “영상을 분석하고 있어요”, 남은 시간(약 20초), 진행바, 4단계 체크리스트. 완료 후 자동으로 동선 분석 화면 |
| **여행 목록 `tripList`** | 하단 탭바 `여행` (모든 화면), tripCreate의 뒤로가기 | 내 여행 파일 목록. 우상단 `+` → 새 여행 시트(이름·날짜 입력, 날짜 선택 시 지도와 “N박 N일” 표시) → `여행 만들기` 누르면 해당 여행의 일정 화면 |
| **바텀시트/오버레이 추가** | 홈 | 추천 완료 토스트, 내 추천 카드 제목 인라인 편집 |

---

## Assets
| 파일 | 설명 | 비고 |
|---|---|---|
| `assets/fonts/PretendardVariable.woff2` | 본문 폰트 | 사용자 제공 (SIL OFL) |
| `assets/landscape.png` | 온보딩 해안 풍경 | 레퍼런스 스크린샷에서 잘라냄 → **원본 교체 필요** |
| `assets/video-sea-clean2.png` | 온보딩 영상 카드 썸네일 | 스크린샷 잘라냄 + 리터치 → 교체 필요 |
| `assets/map-clean.png` | 온보딩 지도 카드 | 스크린샷 잘라냄 → 교체 필요 |
| `assets/t1.png`, `t2.png`, `t3.png` | 지도 카드 썸네일 | 스크린샷 잘라냄 → 교체 필요 |
| 아이콘 | 모두 인라인 SVG(24 viewBox, stroke 1.8–2.2px, round cap/join) | Lucide 등 라인 아이콘 세트로 대체 가능 |
| Google Fonts | Poppins 700(로고), Caveat 500(손글씨) | 온보딩 전용 |

## Screenshots
`screenshots/` 폴더에 화면별 캡처(375×812 프레임, 약 0.58배 축소)가 있어요. 파일명은 `번호-화면키.png`이고, 화면키는 위 Screens & Views의 키와 같아요. `32-tripList-newTripSheet.png`는 새 여행 시트에서 날짜를 고른 뒤 지도가 보이는 상태예요. 캡처는 레이아웃 참고용이고, 정확한 값은 위 토큰과 명세를 따르세요.

## Files
| 파일 | 설명 |
|---|---|
| `Voylog App v2.dc.html` | **프로토타입 소스**(마크업 + `class Component` 로직). `support.js`와 같은 폴더에서 브라우저로 열기 |
| `support.js` | 프로토타입 런타임(구현 불필요) |
| `voylog-prototype-standalone.html` | 오프라인으로 열 수 있는 단일 파일 번들(모든 에셋 포함) |
| `assets/` | 이미지·폰트 |
| `reference/voylog-prototype-source-previous.dc.html` | 이전 버전(비교용) |
| `screenshots/` | 화면별 캡처 36장 |
