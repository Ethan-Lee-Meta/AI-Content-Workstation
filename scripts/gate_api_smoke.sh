#!/usr/bin/env bash
set -euo pipefail
echo "== gate_api_smoke: start =="

bash scripts/gate_health_contract_check.sh
bash scripts/gate_request_id_propagation_check.sh
bash scripts/gate_openapi_reachable.sh
bash scripts/gate_error_envelope_check.sh

echo "[ok] gate_api_smoke passed"
