# HANDOFF — P0 Cumulative (Standalone, Single-File)

This document is **self-contained** and intended to be the **only** handoff artifact passed to the next window.
It describes the **current shipped capabilities**, **API surface**, **verification gates**, and **how to continue development**.

---

## 0) Snapshot

- Repo: `AI-Content-Workstation`
- Branch: `dev/batch2-api-contract__20251229_211207`
- Code baseline commit (gates green): `cbf524e6faa87e18144c5bb5e2b1b0879c078da5`
- Generated at (UTC): `2025-12-30T07:06:54Z`

### Fixed runtime expectations (P0 locks)
- Backend: FastAPI on `127.0.0.1:7000`
- Frontend dev server (expected): `127.0.0.1:2000`
  - This batch introduced **no frontend changes**; existing UI (if any) may not yet call the new endpoints.

---

## 1) What is implemented now (Backend)

### 1.1 Observability & contracts (baseline)
- `GET /health` returns required keys: `status, version, db, storage, last_error_summary`
- Request tracing:
  - Incoming `X-Request-Id` is supported and echoed on success responses
  - Error responses include an error envelope and contain `request_id`
- `GET /openapi.json` is reachable

### 1.2 Assets (read contract)
- `GET /assets`
  - Pagination: `offset`, `limit` with `items[]` and `page{limit,offset,total,has_more}`
  - Defaults: `limit=50`, max `limit=200`
  - Default excludes soft-deleted assets
  - `include_deleted=true` includes soft-deleted assets
- `GET /assets/{asset_id}`
  - Returns asset details including traceability references
- Note:
  - No public delete endpoint is exposed in the current API surface (trash purge exists; see below).

### 1.3 Runs (core contract)
- `POST /runs`
  - Returns: `run_id`, `prompt_pack_id`, `status`
  - Evidence is append-only: repeated submission creates a new Run (no in-place mutation)
- `GET /runs/{run_id}`
  - Returns run status and result references
  - Missing run returns error envelope (with `request_id`)

### 1.4 Reviews
- `POST /reviews`
  - Supports `manual` review and `override`
  - Override requires a non-empty `reason`; missing reason is rejected with error envelope (`request_id` present)

### 1.5 Trash (purge contract)
- `POST /trash/empty`
  - Purges soft-deleted assets (and best-effort deletes their storage files)
  - Emits an audit signal `trash.empty` (verified via uvicorn logs)

### 1.6 Storage/DB defaults
- SQLite default: `DATABASE_URL=sqlite:///./data/app.db`
- Local filesystem storage default: `STORAGE_ROOT=./data/storage`

---

## 2) What is implemented now (Frontend)

- No new frontend wiring was added in this slice.
- To inspect current UI status locally (if the web app exists in repo):
  - `cd apps/web && npm i && npm run dev -- --port 2000`
  - Open `http://127.0.0.1:2000`

---

## 3) Verification (Gates) — how to re-check quickly

### 3.1 Gate scripts delivered in repo
Run from repo root:

- `bash scripts/gate_assets_read.sh`
- `bash scripts/gate_runs_core.sh`
- `bash scripts/gate_reviews.sh`
- `bash scripts/gate_trash.sh`

### 3.2 OpenAPI snapshot (trace only; not a lock)
- `sha256(openapi_batch2.json)=cfd38ce0b22688355b81d85c1373a2b188e4d9fc642b80c962c62262ef7eb16c`

---

## 4) How to run the backend locally (Windows Git Bash safe)

### 4.1 Correct uvicorn command (prevents `ModuleNotFoundError: No module named 'app'`)
From repo root:

- Ensure `--app-dir apps/api` is used (this is the key on Windows/Git Bash).
- Example:

`./apps/api/.venv/Scripts/python.exe -m uvicorn app.main:app --app-dir apps/api --host 127.0.0.1 --port 7000`

### 4.2 Common failure modes & fixes
- Port bind error (`[Errno 10048] ... address already in use`):
  - A process is already using 7000. Stop the prior uvicorn process before starting another.
- If a gate script starts uvicorn in background, do **not** start a second server in parallel on the same port.

---

## 5) Command Protocol (for next window) — rules when providing “copy/paste” Git Bash commands

These rules exist to prevent copy errors, terminal crashes, and accidental forbidden changes.

### 5.1 Output formatting rules
- Provide commands in **one single fenced code block** (no extra characters before/after the block).
- Avoid mixing “explanations” inside the command block; use `echo` headers instead.
- Each step must be **short** and **atomic**. Prefer multiple small blocks over one risky mega-script.

### 5.2 Terminal-stability rules (prevents VSCode terminal from exiting)
- Wrap multi-line command batches in a **subshell**: `( ... )`
  - Inside the subshell, `exit 1` will **not** close your interactive terminal; it only ends the subshell block.
- Use `set +e` (do not use `set -e` in copy/paste scripts; it hides which line failed).
- Print and check return codes explicitly:
  - `cmd; echo "[rc] name=$?"`
  - If non-zero, stop and do **not** run subsequent steps.

### 5.3 Safety & reproducibility rules
- For any file edits:
  - Create backups with timestamp suffixes (`.bak.YYYYMMDD_HHMMSS`) before overwriting.
  - Never stage/commit `*.bak.*` backup files.
- Never stage/commit `tmp/` outputs.
- Guard unrelated changes:
  - If unrelated files change (example: `apps/web/package-lock.json`), revert them before staging.
- Here-doc correctness:
  - Use `<<'EOF'` (single-quoted delimiter) unless you intentionally need variable expansion.
  - The closing delimiter must be on its own line with **no indentation**.

### 5.4 Background process hygiene (ports)
- If you start uvicorn in background, capture PID and stop it at the end.
- Avoid nested scripts that start a second uvicorn on the same port; prefer “reuse existing server” semantics.

---

## 6) Next development starts here (suggested)
- Add missing write endpoints (e.g., asset create/update) consistent with:
  - error envelope + request id propagation
  - pagination conventions
  - immutable evidence chain constraints (append-only where applicable)
- Extend gates first, then expand API surface.
- Wire UI only after API contracts remain stable across at least one full gate cycle.
