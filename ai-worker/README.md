# AI Worker (Python/FastAPI)

## 로컬 개발 환경 (이 머신 기준)

가상환경(venv)은 **한글 없는 경로**에 만들었습니다 (이 계정 사용자명이 한글이라
`pip` 캐시 등에서 문제가 생길 수 있어 미리 피함 — `backend/README.md`와 같은 이유).

| 항목 | 값 |
| --- | --- |
| venv 위치 | `C:\ai-worker-venv` |
| pip 캐시 | `C:\pip-cache` (`PIP_CACHE_DIR` 환경변수) |
| 서버 주소 | `http://localhost:8000` |

**중요**: 이 프로세스도 Windows 서비스가 아닌 **일반 프로세스**라서, PC를 재시작하면
꺼집니다. 다시 쓰려면 아래 명령으로 매번 켜야 합니다.

### 최초 1회 설정

```bash
python -m venv "C:/ai-worker-venv"

export PIP_CACHE_DIR="C:/pip-cache"
"/c/ai-worker-venv/Scripts/python.exe" -m pip install --upgrade pip
"/c/ai-worker-venv/Scripts/python.exe" -m pip install -r requirements.txt

cp .env.example .env   # 이미 만들어져 있음 (.gitignore 처리됨)
# .env를 열어 OPENAI_API_KEY / ANTHROPIC_API_KEY / KAKAO_REST_API_KEY / YOUTUBE_API_KEY 채우기
```

### 서버 시작/중지

```bash
# 시작 (ai-worker/ 디렉터리에서 실행해야 app.main:app 경로가 맞음)
cd ai-worker
"/c/ai-worker-venv/Scripts/python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8000

# 코드 변경 시 자동 재시작하려면 --reload 추가
"/c/ai-worker-venv/Scripts/python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 상태 확인
curl http://localhost:8000/health   # {"status":"ok"} 나오면 정상

# 중지: 실행 중인 터미널에서 Ctrl+C, 또는 백그라운드로 띄웠다면 프로세스 종료
```

### 동작 확인 (curl 스모크 테스트)

```bash
curl http://localhost:8000/health

curl -X POST http://localhost:8000/extract-transcript \
  -H "Content-Type: application/json" \
  -d '{"youtubeUrl":"https://www.youtube.com/watch?v=<영상ID>"}'
```

`OPENAI_API_KEY`/`ANTHROPIC_API_KEY`를 안 채웠으면 `/extract-places`는
`503 AI_PROVIDER_ERROR`로 정상 실패합니다 (코드 문제 아님 — 실제 LLM 키가 있어야
동작).

### 테스트

```bash
cd ai-worker
"/c/ai-worker-venv/Scripts/python.exe" -m pytest -v
```

`pytest`로 구성되어 있고, OpenAI/Claude/Kakao/YouTube 등 외부 API는 전부
`monkeypatch`로 대체하기 때문에 **실제 API 키 없이도, 네트워크 없이도** 실행됩니다.
`tests/` 아래 구성:

- `test_llm_service.py` — OpenAI→Claude 폴백 및 재시도(1회) 로직
- `test_route_optimization_service.py` — 시작/종료 호텔 고정 + 장소 순서 최적화
  (nearest-neighbor + 2-opt), Kakao Mobility 실패 시 Haversine 폴백
- `test_transcript_service.py` — youtube-transcript-api 1.x 연동, 자막 없음 처리
- `test_geocoding_service.py`, `test_place_extraction_service.py` — Kakao 지오코딩,
  LLM 후보와 지오코딩 결과 결합
- `test_main.py`, `test_route_router.py` — FastAPI 라우터 단(`TestClient`), 에러 매핑
  (`AiWorkerError` → `{code, message}` + 상태 코드), 장소 개수 2~10개 검증

### 전체 로컬 스택 재시작 순서 (PC 재부팅 후)

`backend/README.md`와 합쳐서:

1. PostgreSQL 시작
2. Redis 시작
3. `cd backend && npm run dev`
4. `cd ai-worker && "/c/ai-worker-venv/Scripts/python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8000`

### youtube-transcript-api 버전

`requirements.txt`는 `youtube-transcript-api==1.2.4`로 고정되어 있습니다. 처음
`0.6.2`로 스캐폴딩했을 때는 실제 YouTube 요청에서 자막 파싱이 실패했는데
(`TRANSCRIPT_NOT_FOUND` — XML 파싱 에러), 1.x로 올리고 나서 실제 영상으로 정상
추출까지 확인했습니다. 1.x는 API가 바뀌어서 코드도 같이 수정했습니다
(`YouTubeTranscriptApi.get_transcript(...)` 정적 메서드 →
`YouTubeTranscriptApi().fetch(...)` 인스턴스 메서드, 반환값도 dict가 아닌
`FetchedTranscriptSnippet` 객체라 `.text`/`.start` 속성으로 접근하도록 변경 —
[app/services/transcript_service.py](app/services/transcript_service.py) 참고).

YouTube가 또 내부 API를 바꿔서 다시 깨지면, 최신 버전으로 재업그레이드 후
라이브러리의 새 API에 맞게 `transcript_service.py`를 다시 확인하세요:

```bash
"/c/ai-worker-venv/Scripts/python.exe" -m pip install --upgrade youtube-transcript-api
```
