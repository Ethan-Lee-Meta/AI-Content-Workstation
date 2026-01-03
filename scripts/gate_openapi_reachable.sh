#!/usr/bin/env bash
set -euo pipefail
URL="${API_BASE_URL:-http://localhost:7000}"
echo "== gate_openapi_reachable =="
curl -fsS "$URL/openapi.json" >/dev/null
echo "[ok] /openapi.json reachable"
