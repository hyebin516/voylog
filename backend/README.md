# Backend (Node.js/Express)

## 로컬 개발 환경 (이 머신 기준)

PostgreSQL 17과 Redis는 설치 프로그램 없이 **zip 바이너리를 한글 없는 경로에 풀어서**
실행 중입니다 (이 계정의 사용자명이 한글이라 EnterpriseDB EXE 설치 프로그램과 MSI
설치 프로그램 둘 다 `%TEMP%` 관련 문제로 설치가 안 됐습니다 — 자세한 원인은
[../travel_youtube_app/docs/TESTING_GUIDE.md](../travel_youtube_app/docs/TESTING_GUIDE.md)의
한글 경로 이슈들과 같은 계열입니다).

**중요**: 둘 다 Windows 서비스로 등록되어 있지 않은 **일반 프로세스**라서, PC를
재시작하거나 그냥 종료되면 꺼집니다. 다시 쓰려면 아래 명령으로 매번 켜야 합니다.

| 항목 | 값 |
| --- | --- |
| PostgreSQL 설치 위치 | `C:\PostgreSQL17\pgsql` |
| PostgreSQL 데이터 디렉터리 | `C:\PostgreSQL17\data` |
| PostgreSQL 접속 정보 | `localhost:5432`, DB `travel_youtube`, user `postgres` / password `postgres` |
| Redis 설치 위치 | `C:\Redis` |
| Redis 접속 정보 | `localhost:6379` (인증 없음) |

### PostgreSQL 시작/중지/상태 확인

```bash
# 시작
"C:/PostgreSQL17/pgsql/bin/pg_ctl.exe" -D "C:/PostgreSQL17/data" -l "C:/PostgreSQL17/logfile.txt" start

# 상태 확인
"C:/PostgreSQL17/pgsql/bin/pg_isready.exe" -h localhost -p 5432

# 접속 (psql)
PGPASSWORD=postgres "C:/PostgreSQL17/pgsql/bin/psql.exe" -h localhost -p 5432 -U postgres -d travel_youtube

# 중지
"C:/PostgreSQL17/pgsql/bin/pg_ctl.exe" -D "C:/PostgreSQL17/data" stop
```

### Redis 시작/중지/상태 확인

```bash
# 시작 (백그라운드)
"C:/Redis/redis-server.exe" "C:/Redis/redis.windows.conf" > "C:/Redis/redis.log" 2>&1 &

# 상태 확인
"C:/Redis/redis-cli.exe" ping   # PONG이 나오면 정상

# 중지
"C:/Redis/redis-cli.exe" shutdown
```

### 마이그레이션 (최초 1회, 또는 DB를 새로 만들었을 때)

```bash
# DB 생성 (이미 생성되어 있으면 생략)
PGPASSWORD=postgres "C:/PostgreSQL17/pgsql/bin/psql.exe" -h localhost -p 5432 -U postgres -c "CREATE DATABASE travel_youtube;"

# 마이그레이션 순서대로 적용
for f in ../database/migrations/*.sql; do
  PGPASSWORD=postgres "C:/PostgreSQL17/pgsql/bin/psql.exe" -h localhost -p 5432 -U postgres -d travel_youtube -v ON_ERROR_STOP=1 -f "$f"
done
```

### 백엔드 서버 실행

```bash
cd backend
npm install        # 최초 1회 또는 package.json 변경 시
cp .env.example .env   # 최초 1회 (이미 만들어져 있음 — .gitignore 처리됨, 로컬 DB/Redis 값 채워진 상태)
npm run dev         # nodemon으로 실행, 코드 변경 시 자동 재시작
# 또는: node src/server.js  (nodemon 없이 1회성 실행)
```

정상 기동하면 콘솔에 `Backend server listening on port 4000`이 출력됩니다.

### 동작 확인 (curl 스모크 테스트)

```bash
# 인증 미들웨어 확인 (401 예상)
curl http://localhost:4000/api/v1/auth/profile

# validator 확인 (400 예상)
curl -X POST http://localhost:4000/api/v1/videos/analyze \
  -H "Content-Type: application/json" -d '{"youtubeUrl":"not-a-url"}'

# DB/Redis 캐시 조회까지 실제로 타는지 확인 (AI Worker가 안 떠 있으면 503 AI_PROVIDER_ERROR가 정상)
curl -X POST http://localhost:4000/api/v1/videos/analyze \
  -H "Content-Type: application/json" \
  -d '{"youtubeUrl":"https://www.youtube.com/watch?v=dQw4w9WgXcQ"}'
```

### 테스트

```bash
cd backend
npm test
```

`jest`(단위 테스트) + `supertest`(라우트 와이어링 테스트)로 구성되어 있고,
전부 리포지토리/설정을 모킹해서 돌기 때문에 **PostgreSQL/Redis/AI Worker가
꺼져 있어도** 실행됩니다. `test/` 아래에 `src/`와 동일한 구조로 있습니다:

- `test/services/*.test.js` — 핵심 비즈니스 로직 (예: `itinerary.service.test.js`는
  `route_type` 서버 자동 판별을, `video.service.test.js`는 Redis/DB 캐시 3단계
  분기별 `isCached` 값을 검증)
- `test/validators/*.test.js`, `test/middlewares/*.test.js` — 입력 검증/인증 미들웨어
- `test/app.test.js` — 라우트 연결과 미들웨어 순서(인증 없이 보호된 라우트 호출 시 401 등)

### 전체 재시작 순서 (PC 재부팅 후)

1. PostgreSQL 시작 (위 명령)
2. Redis 시작 (위 명령)
3. `cd backend && npm run dev`
4. (필요 시) AI Worker 시작 — `ai-worker/README.md` 참고

### 나중에 Windows 서비스로 등록하고 싶다면

매번 수동 시작이 번거로우면:

- PostgreSQL: `pg_ctl register -D "C:\PostgreSQL17\data" -N postgresql-17` (관리자 권한 필요)
- Redis: `redis-server --service-install "C:\Redis\redis.windows-service.conf"` (관리자 권한 필요)

지금은 로컬 개발용이라 등록하지 않고 수동 실행 방식으로 두었습니다.
