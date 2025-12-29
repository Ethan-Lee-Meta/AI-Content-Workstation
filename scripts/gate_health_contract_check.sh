#!/usr/bin/env bash
set -euo pipefail
URL="${API_BASE_URL:-http://localhost:7000}"

TMP_H="$(mktemp)"; TMP_B="$(mktemp)"
trap 'rm -f "$TMP_H" "$TMP_B"' EXIT

echo "== gate_health_contract_check =="
curl -sS -D "$TMP_H" -o "$TMP_B" "$URL/health" >/dev/null

python - "$TMP_B" <<'PY'
import json,sys
p=sys.argv[1]
data=json.load(open(p,encoding="utf-8"))
need=["status","version","db","storage","last_error_summary"]
miss=[k for k in need if k not in data]
if miss:
  raise SystemExit(f"[err] /health missing keys: {miss}")
print("[ok] /health keys present:", ", ".join(need))
PY
