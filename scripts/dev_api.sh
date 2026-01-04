#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# best-effort venv activate (Windows Git Bash)
if [[ -f ".venv/Scripts/activate" ]]; then
  source ".venv/Scripts/activate"
elif [[ -f "apps/api/.venv/Scripts/activate" ]]; then
  source "apps/api/.venv/Scripts/activate"
fi

export PYTHONPATH="$ROOT/apps/api"
export PROVIDER_ENABLED=1

PY="${PY:-$ROOT/apps/api/.venv/Scripts/python.exe}"

echo "[info] PY=$PY"
echo "[info] PYTHONPATH=$PYTHONPATH"
"$PY" - <<'PY'
import sys, os
print("[info] sys.executable =", sys.executable)
print("[info] cwd =", os.getcwd())
print("[info] sys.path[0:3] =", sys.path[0:3])
import app.main
print("[ok] import app.main succeeded")
PY

exec "$PY" -m uvicorn app.main:app --host 0.0.0.0 --port 7000 --reload