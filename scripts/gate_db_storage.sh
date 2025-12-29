#!/usr/bin/env bash
set +e

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$ROOT" ]; then echo "[err] not a git repo"; exit 2; fi
cd "$ROOT" || exit 2

API_HOST="${API_HOST:-127.0.0.1}"
API_PORT="${API_PORT:-7000}"
BASE="http://${API_HOST}:${API_PORT}"

ok()  { echo "[ok] $*"; }
warn(){ echo "[warn] $*"; }
err() { echo "[err] $*"; }

STARTED=0
PID=""

start_api_bg() {
  export PYTHONPATH="$ROOT/apps/api"
  export DATABASE_URL="${DATABASE_URL:-sqlite:///./data/app.db}"
  export STORAGE_ROOT="${STORAGE_ROOT:-./data/storage}"

  mkdir -p "$ROOT/tmp" 2>/dev/null
  python -m uvicorn app.main:app --host "$API_HOST" --port "$API_PORT" > "$ROOT/tmp/gate_db_storage_uvicorn.log" 2>&1 &
  PID="$!"
  STARTED=1
  ok "started api (pid=$PID) for gate_db_storage"
}

stop_api_bg() {
  if [ "$STARTED" -eq 1 ] && [ -n "$PID" ]; then
    kill "$PID" 2>/dev/null
    ok "stopped api (pid=$PID)"
  fi
}

trap stop_api_bg EXIT

probe_health() {
  curl -sS -m 3 "${BASE}/health" 2>/dev/null
}

wait_ready() {
  i=0
  while [ $i -lt 40 ]; do
    out="$(probe_health)"
    if [ $? -eq 0 ] && [ -n "$out" ]; then
      return 0
    fi
    i=$((i+1))
    sleep 0.25
  done
  return 1
}

echo "== gate_db_storage: start =="

probe_health >/dev/null
if [ $? -ne 0 ]; then
  warn "api not reachable at ${BASE}; starting a temporary uvicorn..."
  start_api_bg
  wait_ready
  if [ $? -ne 0 ]; then
    err "api still not reachable; see tmp/gate_db_storage_uvicorn.log"
    exit 3
  fi
else
  ok "api reachable at ${BASE}"
fi

HEALTH_JSON="$(probe_health)"

python - <<'PY' "$HEALTH_JSON"
import json, sys
raw = sys.argv[1]
try:
    data = json.loads(raw)
except Exception as e:
    print("[err] /health is not valid json:", e)
    raise SystemExit(4)

required_top = ["status","version","db","storage","last_error_summary"]
missing = [k for k in required_top if k not in data]
if missing:
    print("[err] /health missing top keys:", missing)
    raise SystemExit(5)

db = data.get("db") or {}
st = data.get("storage") or {}

if db.get("status") != "ok":
    print("[err] /health.db.status not ok:", db)
    raise SystemExit(6)
if db.get("kind") != "sqlite":
    print("[err] /health.db.kind expected sqlite:", db)
    raise SystemExit(7)
if not db.get("path"):
    print("[err] /health.db.path missing:", db)
    raise SystemExit(8)

if st.get("status") != "ok":
    print("[err] /health.storage.status not ok:", st)
    raise SystemExit(9)
if not st.get("root"):
    print("[err] /health.storage.root missing:", st)
    raise SystemExit(10)

print("[ok] /health keys present: " + ", ".join(required_top))
print(f"[ok] /health.db.status=ok kind=sqlite path={db.get('path')}")
print(f"[ok] /health.storage.status=ok root={st.get('root')}")
PY
RC_HEALTH=$?

pushd "$ROOT/apps/api" >/dev/null
python -m alembic -c alembic.ini upgrade head
RC_UP=$?
python -m alembic -c alembic.ini current
RC_CUR=$?
popd >/dev/null

if [ $RC_UP -eq 0 ] && [ $RC_CUR -eq 0 ]; then
  ok "migrations runnable (alembic upgrade/current ok)"
else
  err "migrations not runnable (upgrade rc=$RC_UP, current rc=$RC_CUR)"
fi

RC=0
if [ $RC_HEALTH -ne 0 ]; then RC=20; fi
if [ $RC_UP -ne 0 ] || [ $RC_CUR -ne 0 ]; then RC=21; fi

if [ $RC -eq 0 ]; then
  ok "gate_db_storage passed"
else
  err "gate_db_storage failed (rc=$RC)"
fi

exit $RC
