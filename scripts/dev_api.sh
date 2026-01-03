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

# Windows Python uses ";" as path separator; safest is to set PYTHONPATH explicitly to one path.
export PYTHONPATH="$ROOT/apps/api"

echo "[info] PYTHONPATH=$PYTHONPATH"
python - <<'PY'
import sys, os
print("[info] sys.executable =", sys.executable)
print("[info] cwd =", os.getcwd())
print("[info] sys.path[0:3] =", sys.path[0:3])
try:
    import app.main
    print("[ok] import app.main succeeded")
except Exception as e:
    print("[err] import app.main failed:", repr(e))
    raise
PY

exec python -m uvicorn app.main:app --host 0.0.0.0 --port 7000 --reload
