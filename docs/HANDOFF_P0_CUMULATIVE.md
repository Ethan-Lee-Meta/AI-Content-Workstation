# HANDOFF — P0 Cumulative (Standalone, Single-File)

This document is **self-contained** and intended to be the **only** handoff artifact passed to the next window.
It describes the **current shipped capabilities**, **API surface**, **verification gates**, and **how to continue development**.

---

## 0) Snapshot

- Repo: `AI-Content-Workstation`
- Branch (at generation): `dev/batch5-ui-p1`
- HEAD (at generation): `0a066f9663c9ad8b90f8078bbda84c3c2d37113e`
- Generated (UTC): `2025-12-31T05:59:22Z`
- Stable locator (tag): `handoff-p0-cumulative-20251231_055922`  (created & pushed by the finalize script)

### Fixed runtime expectations (P0 locks)
- Backend: FastAPI on `127.0.0.1:7000`
- Frontend dev server (expected): `127.0.0.1:2000`

---

## 1) What is implemented now (Backend)

### 1.1 Observability & contracts
- `GET /health` returns required keys: `status, version, db, storage, last_error_summary`
- Request tracing:
  - Incoming `X-Request-Id` is supported and echoed on success responses
  - Error responses use a unified error envelope and include `request_id`
- `GET /openapi.json` is reachable

### 1.2 Assets (read + soft delete mutation)
- `GET /assets`
  - Pagination: `offset`, `limit` with `items[]` and `page{limit,offset,total,has_more}`
  - Defaults: `limit=50`, max `limit=200`
  - Default excludes soft-deleted assets
  - `include_deleted=true` includes soft-deleted assets
- `GET /assets/{asset_id}`
  - Returns asset details including traceability references
- `DELETE /assets/{asset_id}` (**soft delete; idempotent**)
  - Soft delete sets `assets.deleted_at = <UTC timestamp>` (no physical delete)
  - Idempotent: repeated soft delete returns success and signals `already_deleted` (must not 500)
  - Missing asset returns `404` using unified error envelope + `request_id`

### 1.3 Runs (core contract)
- `POST /runs` returns `run_id`, `prompt_pack_id`, `status`; evidence append-only
- `GET /runs/{run_id}` returns status + result refs; missing run returns error envelope + request_id

### 1.4 Reviews
- `POST /reviews` supports manual + override
- Override requires non-empty `reason`; otherwise rejected with error envelope + request_id

### 1.5 Trash (purge + audit)
- `POST /trash/empty`
  - Purges only soft-deleted assets (`deleted_at IS NOT NULL`)
  - Best-effort removes related storage files
  - Returns: success + `X-Request-Id`, and an `audit_event` containing at least:
    - `event="trash.empty"`, `action="trash_empty"`, `request_id`, `purged_count`, `ts`
  - After purge: `GET /assets?include_deleted=true` no longer returns purged assets

### 1.6 Storage/DB defaults
- SQLite: `DATABASE_URL=sqlite:///./data/app.db`
- Storage: `STORAGE_ROOT=./data/storage`

---

## 2) What is implemented now (Frontend)

- Frontend code lives under `apps/web/app` (Next.js App Router).
- Runtime expectations (P0 locks):
  - Web: `http://127.0.0.1:2000`
  - API: `http://127.0.0.1:7000` (UI uses same-origin proxy to avoid CORS preflight)

### 2.1 P1 UI additions shipped in BATCH-5
- AC-005 interaction depth guard:
  - Core task path “Home → Generate → Result” stays within ≤3 interaction layers (validated by `gate_ac_005`).
- `/library` (Asset grid + bulk actions):
  - Asset grid loads via `/api_proxy/assets?...` (browser requests avoid direct `:7000` to prevent OPTIONS/405).
  - Bulk select + “Soft delete selected” (soft delete via API; list updates to hide deleted by default).
  - Failures render the unified error envelope (`error,message,request_id,details`) and explicitly display `request_id`.
- `/trash` (Trash view):
  - Lists deleted assets using `include_deleted=true`.
  - “Empty trash” triggers `POST /trash/empty` with a second confirmation.
  - Success/failure feedback surfaces `request_id` (and audit details if returned).
- Sidebar navigation:
  - Adds `Trash` entry pointing to `/trash`.
- Asset Detail Review UI hardening:
  - `score` is integer 1–100 (label: `score (1-100)`; input restricted `min=1 max=100 step=1`; client-side coercion).
  - `kind=override` requires non-empty `reason` (client-side validation prevents avoidable server 400s).

### 2.2 How to run the frontend (dev)
From repo root:

- `cd apps/web && npm i`
- `npm run dev -- --port 2000`

Notes:
- Browser calls should go through `/api_proxy/*` (same-origin). Server-side calls may use `NEXT_PUBLIC_API_BASE_URL` (default `http://127.0.0.1:7000`).

---

## 3) Verification (Gates) — re-check quickly

Run from repo root (API on `127.0.0.1:7000`):

- `bash scripts/gate_all.sh --mode=full`          # regression: P0 must stay green
- `bash scripts/gate_web_routes.sh`              # if present
- `bash scripts/gate_ac_005.sh`                  # interaction depth ≤ 3
- `bash scripts/gate_bulk_actions.sh`            # bulk select + bulk soft delete
- `bash scripts/gate_trash_ui.sh`                # trash list + empty trash confirm

## 4) How to run backend (Windows Git Bash safe)
- `./apps/api/.venv/Scripts/python.exe -m uvicorn app.main:app --app-dir apps/api --host 127.0.0.1 --port 7000`

Common fix:
- Port bind error (`[Errno 10048]`): stop existing uvicorn before starting another.

---

## 5) Command Protocol (for next window)
- Commands should be provided in a single fenced code block.
- Prefer: generate a script under `tmp/` then run `bash tmp/<script>.sh`.
  - Avoid pasting top-level `exit` chains into the interactive shell (can kill VSCode terminal).
- Never commit: `tmp/`, `*.bak.*`.
- If unrelated files change (example: `apps/web/package-lock.json`), revert before staging.
