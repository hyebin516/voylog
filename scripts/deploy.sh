#!/usr/bin/env bash
#
# 서버에서 배포를 한 줄로:
#
#   ./scripts/deploy.sh                # 전부
#   ./scripts/deploy.sh ai-worker      # 한 서비스만
#   ./scripts/deploy.sh ai-worker --no-cache
#
# git pull -> 빌드 -> 재시작 -> 확인까지 한다. 중간에 하나라도 실패하면
# 거기서 멈춘다(set -e) -- 빌드가 실패했는데 "배포 끝"이라고 말하는 쪽이
# 훨씬 나쁘다.
#
# pull이 아이디/토큰을 물어서 번거롭다면 한 번만:
#   git config --global credential.helper store && git pull
set -euo pipefail

cd "$(dirname "$0")/.."

no_cache=()
services=()
for arg in "$@"; do
  case "$arg" in
    --no-cache) no_cache=(--no-cache) ;;
    *) services+=("$arg") ;;
  esac
done

branch=$(git branch --show-current)
before=$(git rev-parse --short HEAD)
echo "== 현재: $branch @ $before"

git pull --ff-only
after=$(git rev-parse --short HEAD)

if [ "$before" = "$after" ]; then
  echo "== 새 커밋 없음 ($after). 그래도 다시 빌드한다."
else
  echo "== 갱신: $before -> $after"
  git --no-pager log --oneline "$before..$after"
fi

echo
echo "== 빌드"
docker compose build "${no_cache[@]+"${no_cache[@]}"}" "${services[@]+"${services[@]}"}"

echo
echo "== 재시작"
docker compose up -d "${services[@]+"${services[@]}"}"

echo
docker compose ps

# 컨테이너가 떴다고 백엔드가 응답하는 것은 아니다. DB 연결이나 환경변수
# 문제는 여기서만 드러난다.
domain=$(grep -E '^DOMAIN=' backend/.env 2>/dev/null | cut -d= -f2- | tr -d '\r"' || true)
if [ -n "$domain" ]; then
  echo
  echo -n "== https://$domain/health "
  for _ in $(seq 1 15); do
    if curl -fsS --max-time 5 "https://$domain/health" >/dev/null 2>&1; then
      echo "-> ok"
      exit 0
    fi
    echo -n "."
    sleep 2
  done
  echo
  echo "!! 30초 동안 응답이 없다. 로그: docker compose logs --tail 50 backend"
  exit 1
fi
