# HANDOFF — BATCH-0 (PHASE-P0 / infra_runtime)

## 1) Summary
- Batch: BATCH-0
- Phase: PHASE-P0
- Conflict domain: infra_runtime
- Completed steps:
  - STEP-000-context-sync: unified gates entry + baseline runbook
  - STEP-010-observability-foundation: /health contract + X-Request-Id propagation + structured logs + error envelope + /openapi.json reachable
- Status: gate_api_smoke PASSED

## 2) Global hard locks (do not change without CR)
- Ports: web_dev_server=2000, api_server=7000
- /health endpoint: GET /health
  - required keys: status, version, db, storage, last_error_summary
- OpenAPI endpoint: GET /openapi.json
- Request-Id:
  - header in: X-Request-Id
  - header out: X-Request-Id (must be present; missing-in generates one)
  - must also be present on error responses
- Error envelope (application/json):
  - required keys: error, message, request_id, details

## 3) Repo touchpoints (where the work landed)
API (FastAPI)
- Entry file: apps/api/app/main.py
  - Injected foundations:
    - middleware: request id generation + propagation (X-Request-Id)
    - exception handlers: wrap errors into required envelope and echo X-Request-Id on errors
    - /health contract response keys fixed

Gate scripts
- scripts/gate_all.sh (supports --mode=preflight|full)
- scripts/gate_api_smoke.sh
- scripts/gate_health_contract_check.sh
- scripts/gate_request_id_propagation_check.sh
- scripts/gate_openapi_reachable.sh
- scripts/gate_error_envelope_check.sh (checks JSON envelope + X-Request-Id header on error path)

Dev run scripts (Windows Git Bash compatible)
- scripts/dev_api.sh
  - Important: PYTHONPATH is set to a single path:
    - export PYTHONPATH="$ROOT/apps/api"
  - Startup:
    - python -m uvicorn app.main:app --host 0.0.0.0 --port 7000 --reload

## 4) How to verify (receiver must run)
4.1 Preflight (no server required)
    bash scripts/gate_all.sh --mode=preflight

4.2 Start API (server required, uses port 7000)
    bash scripts/dev_api.sh

4.3 Smoke gate (server required)
    bash scripts/gate_api_smoke.sh

Expected outputs include:
- [ok] /health keys present: status, version, db, storage, last_error_summary
- [ok] header present: X-Request-Id (non-empty)
- [ok] /openapi.json reachable
- [ok] error path header present: X-Request-Id (non-empty)
- [ok] error envelope includes request_id and required keys
- [ok] gate_api_smoke passed

## 5) Known pitfalls (must remember)
- Windows PYTHONPATH separator:
  - do NOT append with ":"; Windows uses ";"
  - safest approach is current implementation: set PYTHONPATH to a single directory ($ROOT/apps/api)
  - symptom when broken: ModuleNotFoundError: No module named 'app'

## 6) Directory contract reminder
- Allowed edit paths: apps/web/**, apps/api/**, docs/**, scripts/**
- Forbidden new top-level dirs: infra/**, services/**
- Forbidden edit paths: .git/**, vendor/generated paths

## 7) Rollback
If committed:
    git log -1 --oneline
    git revert <commit_sha>

If not committed:
    git checkout -- apps/api/app/main.py scripts docs

## 8) Frozen inputs that must remain available to all windows
- 01_AI_SPECDIGEST.yaml
- 02_ARCH_DIGEST.yaml
- 03_MASTER_PLAN_frozen.yaml
- Recommended:
  - 01_REQ_CONTRACT_SUMMARY.md
  - 02_ARCH_CONTRACT_SUMMARY.md
  - 03_DEVELOPMENT_BATCHES_frozen.md
  - 03_TASK_ASSIGNMENT_frozen.md
