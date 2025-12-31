#!/usr/bin/env bash
set -e

echo "== gate_api_p1_caps_strict: start =="

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"
API_BASE_URL="${API_BASE_URL%/}"

PY="${PY:-./apps/api/.venv/Scripts/python.exe}"

"$PY" - <<'PY'
import json, os, urllib.request, urllib.error

base = os.environ.get("API_BASE_URL","http://127.0.0.1:7000").rstrip("/")

def fetch(url: str):
    req = urllib.request.Request(url, method="GET")
    with urllib.request.urlopen(req, timeout=10) as resp:
        return resp.status, resp.read().decode("utf-8"), dict(resp.headers)

# 1) /health reachable
st, body, _ = fetch(base + "/health")
if st != 200:
    raise SystemExit(f"[err] /health status={st}")
print("[ok] /health reachable (reuse existing uvicorn)")

# 2) openapi reachable
st, raw, _ = fetch(base + "/openapi.json")
if st != 200:
    raise SystemExit(f"[err] /openapi.json status={st}")
doc = json.loads(raw)
paths = doc.get("paths") or {}

def has_method(path: str, method: str) -> bool:
    p = paths.get(path) or {}
    return method.lower() in (k.lower() for k in p.keys())

# required endpoints
if not has_method("/assets", "get"):
    raise SystemExit("[err] missing GET /assets in openapi")
if not has_method("/trash/empty", "post"):
    raise SystemExit("[err] missing POST /trash/empty in openapi")
print("[ok] required endpoints present")

# include_deleted param present on GET /assets
assets_get = (paths.get("/assets") or {}).get("get") or {}
params = assets_get.get("parameters") or []
names = [p.get("name") for p in params if isinstance(p, dict)]
if "include_deleted" not in names:
    raise SystemExit("[err] missing include_deleted query param on GET /assets")
print("[ok] include_deleted query param present on GET /assets")

# /assets* must have a mutation (any non-GET)
mutations = []
for path, spec in paths.items():
    if not isinstance(path, str) or not path.startswith("/assets"):
        continue
    if not isinstance(spec, dict):
        continue
    for m in spec.keys():
        ml = str(m).lower()
        if ml not in ("get", "head", "options"):
            mutations.append(f"{ml.upper()} {path}")
if not mutations:
    raise SystemExit("[err] missing /assets* mutation endpoints (need DELETE/PATCH/POST)")
print("[ok] found /assets* mutation endpoints: " + ", ".join(sorted(set(mutations))))

print("== gate_api_p1_caps_strict: passed ==")
PY

