#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
cd "$ROOT"

echo "== gate_web_routes: start =="

if [ ! -f "apps/web/package.json" ]; then
  echo "[err] missing apps/web/package.json" >&2
  exit 2
fi

# Build (fast failure if routes/components break)
echo "== [info] next build =="
npm --prefix apps/web run build

mkdir -p tmp
LOG="tmp/gate_web_routes.web.log"
: > "$LOG"

echo "== [info] starting next (2000) =="
npm --prefix apps/web run start >"$LOG" 2>&1 &
PID=$!

cleanup() {
  set +e
  if kill -0 "$PID" >/dev/null 2>&1; then
    kill "$PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

BASE="http://127.0.0.1:2000"

echo "== [info] wait for server =="
for i in $(seq 1 40); do
  code="$(curl -s -o /dev/null -w "%{http_code}" "$BASE/" || true)"
  if [ "$code" = "200" ]; then
    echo "[ok] server ready ($BASE)"
    break
  fi
  sleep 0.5
done

code="$(curl -s -o /dev/null -w "%{http_code}" "$BASE/" || true)"
if [ "$code" != "200" ]; then
  echo "[err] server not ready; last http_code=$code" >&2
  echo "== [debug] last logs ==" >&2
  tail -n 120 "$LOG" >&2 || true
  exit 3
fi

check_route () {
  local path="$1"
  local url="${BASE}${path}"
  local code
  code="$(curl -s -o /dev/null -w "%{http_code}" "$url" || true)"
  if [ "$code" != "200" ]; then
    echo "[err] route failed: $path http_code=$code" >&2
    echo "== [debug] last logs ==" >&2
    tail -n 120 "$LOG" >&2 || true
    exit 4
  fi
  echo "[ok] route ok: $path"
}

echo "== [info] probing required routes =="
check_route "/"
check_route "/library"
check_route "/assets/test-asset"
check_route "/generate"
check_route "/projects"
check_route "/projects/test-project"
check_route "/series"
check_route "/series/test-series"
check_route "/shots"
check_route "/shots/test-shot"
check_route "/characters"
check_route "/characters/test-character"
check_route "/settings"

echo "[ok] routes accessible: /, /library, /assets/:id, /generate, /characters, /settings (+ placeholders)"
echo "== gate_web_routes: passed =="
