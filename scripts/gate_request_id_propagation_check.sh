#!/usr/bin/env bash
set -euo pipefail
URL="${API_BASE_URL:-http://localhost:7000}"

TMP_H="$(mktemp)"; TMP_B="$(mktemp)"
trap 'rm -f "$TMP_H" "$TMP_B"' EXIT

echo "== gate_request_id_propagation_check =="
curl -sS -D "$TMP_H" -o "$TMP_B" "$URL/health" >/dev/null

python - "$TMP_H" <<'PY'
import sys,re
h=open(sys.argv[1],encoding="utf-8",errors="ignore").read().splitlines()
rid=None
for line in h:
  if line.lower().startswith("x-request-id:"):
    rid=line.split(":",1)[1].strip()
    break
if not rid:
  raise SystemExit("[err] missing X-Request-Id response header")
print("[ok] header present: X-Request-Id (non-empty)")
PY
