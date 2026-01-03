#!/usr/bin/env bash
set -euo pipefail
URL="${API_BASE_URL:-http://localhost:7000}"

TMP_H="$(mktemp)"; TMP_B="$(mktemp)"
trap 'rm -f "$TMP_H" "$TMP_B"' EXIT

echo "== gate_error_envelope_check =="
curl -sS -D "$TMP_H" -o "$TMP_B" "$URL/__gate_error_envelope_probe__" >/dev/null || true

python - "$TMP_H" <<'PY'
import sys
h=open(sys.argv[1],encoding="utf-8",errors="ignore").read().splitlines()
rid=None
for line in h:
    if line.lower().startswith("x-request-id:"):
        rid=line.split(":",1)[1].strip()
        break
if not rid:
    raise SystemExit("[err] missing X-Request-Id response header on error path")
print("[ok] error path header present: X-Request-Id (non-empty)")
PY

python - "$TMP_B" <<'PY'
import json,sys
p=sys.argv[1]
try:
    data=json.load(open(p,encoding="utf-8"))
except Exception as e:
    raise SystemExit(f"[err] error response is not JSON: {e}")
need=["error","message","request_id","details"]
miss=[k for k in need if k not in data]
if miss:
    raise SystemExit(f"[err] error envelope missing keys: {miss}; got keys={list(data.keys())}")
if not data.get("request_id"):
    raise SystemExit("[err] error envelope request_id is empty")
print("[ok] error envelope includes request_id and required keys")
PY
