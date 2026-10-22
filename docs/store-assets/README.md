# 스토어 등록 자료

- `play-icon-512.png` — Play 아이콘(512x512, 알파 없음). `travel_youtube_app/tool/make_app_icon.py`가
  만드는 런처 아이콘과 같은 그림이다. 아이콘을 바꾸면 이 파일도 다시 뽑을 것.
- `play-feature-graphic-1024x500.png` — 피처 그래픽.
- `screenshots/` — 실기기에서 `adb exec-out screencap -p`로 찍은 화면.

문구와 설문 답변은 `../PLAY_LISTING.md`.

## 스크린샷 (2026-10-22, SM-A750N 실기기)

| 파일 | 화면 |
| --- | --- |
| `01-intro.png` | 온보딩 — 서비스가 뭘 하는지 한 장에 |
| `02-home.png` | 홈 — URL 입력, 내 주변/뚜벅이 코스 진입 |
| `03-nearby.png` | 내 주변 추천 — 거리와 이유가 붙은 장소 목록 |
| `04-analysis.png` | 영상 분석 결과 — 장소 20곳, 타임스탬프 |
| `05-course-setup.png` | 뚜벅이 코스 — 지역·분위기·시간 고르기 |
| `06-walking-course.png` | 생성된 코스 — 지도, 경로, 구간별 도보 시간 |

Play는 24비트 PNG(알파 없음) 또는 JPEG만 받는다. `adb exec-out screencap -p`는
RGBA로 저장하므로 RGB로 바꿔서 넣었다.
