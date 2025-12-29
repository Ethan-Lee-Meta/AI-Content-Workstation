# BATCH-0 Evidence (PHASE-P0 / infra_runtime)

## Scope
- STEP-000-context-sync: gate entry + baseline runbook
- STEP-010-observability-foundation: /health contract + X-Request-Id + error envelope + openapi reachable

## Commands (Local)
Preflight:
- `bash scripts/gate_all.sh --mode=preflight`

Run API (Windows Git Bash):
- `bash scripts/dev_api.sh`

Smoke:
- `bash scripts/gate_api_smoke.sh`
or
- `bash scripts/gate_all.sh --mode=full`

## Expected Results
- `[ok] /health keys present: status, version, db, storage, last_error_summary`
- `[ok] header present: X-Request-Id (non-empty)` (also on error path)
- `[ok] /openapi.json reachable`
- `[ok] error envelope includes: error, message, request_id, details`
