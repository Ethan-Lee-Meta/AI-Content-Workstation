# Baseline Runbook (BATCH-0 / PHASE-P0)

## Hard Locks (Do Not Change Without CR)
- Ports: web_dev_server=2000, api_server=7000
- /health required keys: status, version, db, storage, last_error_summary
- Request tracking: X-Request-Id in/out (missing -> generated; always echoed back)
- Error envelope (application/json): error, message, request_id, details

## Local Verification
- Preflight (no server required):
  - `bash scripts/gate_all.sh --mode=preflight`
- API smoke (server required at http://localhost:7000):
  - `bash scripts/gate_api_smoke.sh`
