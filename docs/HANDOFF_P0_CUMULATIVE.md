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

---

## BATCH-3 (PHASE-P0 / ui_routes) — UI Vertical Slice (AC-001..AC-004)

- Branch: `dev/batch3-ui-ac003-generate`
- Feature commit (BATCH-3): `830a46d1fa10920639a4019ecdc25f914dfd47a6`
- Appended at (UTC): `2025-12-30T11:54:30Z`

### Scope delivered
- App Shell + required routes skeleton (Next.js App Router under `apps/web/app`)
- AC-001: Library overview lists image+video assets with pagination; opens Asset Detail
- AC-002: Asset detail shows required panels markers (Preview/Metadata/Traceability/Actions/Review)
- AC-003: Generate supports 4 input types (t2i/i2i/t2v/i2v) submit run; refresh status; show results markers
- AC-004: Review UI shows score/verdict/reasons and supports override; missing reason triggers error envelope w/ `request_id`

### Implemented UI endpoints & contract behaviors
- Proxy: `/api_proxy/[...path]` forwards requests to API server `127.0.0.1:7000`
- Pagination contract (UI expects): `{ items: [...], page: { limit, offset, total, has_more } }`
- Error envelope keys required: `error, message, request_id, details`
- UI surfaces `request_id` in Review panel (prefers body `request_id`, then response header `x-request-id`, else generated request id)

### Gates (P0)
Run from repo root:

```bash
bash scripts/gate_api_smoke.sh
bash scripts/gate_web_routes.sh
bash scripts/gate_ac_001.sh
bash scripts/gate_ac_002.sh
bash scripts/gate_ac_003.sh
bash scripts/gate_ac_004.sh
```

Expected signals:
- `[ok] routes accessible: /, /library, /assets/:id, /generate (+ placeholders)`
- `[ok] /library source contains required sections markers (FiltersBar/AssetGrid/BulkActionBar)`
- `[ok] asset detail source contains required panel markers`
- `[ok] create run for each type; status refreshed`
- `[ok] override missing reason rejected; error envelope ok; request_id=...`

### Files added/updated (key)
- `apps/web/app/assets/[asset_id]/ReviewPanelClient.js` (AC-004 Review UI, request_id visibility, override behavior)
- `apps/web/app/assets/[asset_id]/AssetDetailClient.js` (wired ReviewPanelClient; preserves AC-002 markers)
- `scripts/gate_ac_004.sh` (AC-004 gate: API behavior + stable source markers + web routes baseline)

### Known limitations / risks
- Review payload composition is **openapi best-effort** (derived from `/api_proxy/openapi.json` when available). If backend `/reviews` schema evolves, field mapping may need updates.
- Some gate runs may generate artifacts under `tmp/`. If those are tracked in git, consider cleaning strategy via a Change Request (outside `apps/web/**, docs/**, scripts/**` allowlist).


### Gate evidence (latest run; extracted [ok] lines)

- Evidence run at (UTC): `2025-12-30T11:59:03Z`
- Branch: `dev/batch3-ui-ac003-generate`
- HEAD: `830a46d1fa10920639a4019ecdc25f914dfd47a6`

```text
== gate_web_routes ==
[ok] route ok: /
[ok] route ok: /library
[ok] route ok: /assets/test-asset
[ok] route ok: /generate
[ok] route ok: /projects
[ok] route ok: /projects/test-project
[ok] route ok: /series
[ok] route ok: /series/test-series
[ok] route ok: /shots
[ok] route ok: /shots/test-shot
[ok] routes accessible: /, /library, /assets/:id, /generate (+ placeholders)

== gate_ac_001 ==
[ok] /assets returns items[] + page{limit,offset,total,has_more}
[ok] /library source contains required sections markers (FiltersBar/AssetGrid/BulkActionBar)
== gate_ac_001: passed ==

== gate_ac_002 ==
[ok] picked asset_id=5FBA8D5F46254AF9819D359F83726558
[ok] /assets/:id returns an object
[ok] error envelope includes error/message/request_id/details
[ok] asset detail source contains required panel markers
== gate_ac_002: passed ==

== gate_ac_003 ==
[ok] create run: type=t2i run_id=01KDQJ1J2R4TE0TRQHBPM6CEFH request_id=155b18b3-94c0-4c13-8f08-68b3454cea21
[ok] refresh run: run_id=01KDQJ1J2R4TE0TRQHBPM6CEFH
[ok] create run: type=i2i run_id=01KDQJ1J80HS5YFV0MTZ7NSGXK request_id=113dda7a-a773-4a0d-a608-05b1bbd1ca92
[ok] refresh run: run_id=01KDQJ1J80HS5YFV0MTZ7NSGXK
[ok] create run: type=t2v run_id=01KDQJ1JD47WQXZBB04JZBVG86 request_id=5fc108c8-084e-4617-b775-18eff1f00fc5
[ok] refresh run: run_id=01KDQJ1JD47WQXZBB04JZBVG86
[ok] create run: type=i2v run_id=01KDQJ1JJD8DJ8ZEM69E63AWW2 request_id=ea561801-d1b6-421a-9b4d-39ad0e187f5f
[ok] refresh run: run_id=01KDQJ1JJD8DJ8ZEM69E63AWW2
[ok] /generate source contains required section markers (InputTypeSelector/PromptEditor/RunQueuePanel/ResultsPanel)
== gate_ac_003: passed ==

== gate_ac_004 ==
[ok] override missing reason rejected; error envelope ok; request_id=679de0e7-2393-48cc-9baf-4ffa65b8e578
[ok] Review UI markers present and wired
== gate_ac_004: passed ==
```



### Gate key parameters (latest run)

- Evidence run at (UTC): `2025-12-30T12:05:27Z`
- Branch: `dev/batch3-ui-ac003-generate`
- HEAD: `9409924ccb24d9768c8ff8aeac391da507bef73f`

#### Routes (gate_web_routes)
- [ok] `/`
- [ok] `/library`
- [ok] `/assets/test-asset`
- [ok] `/generate`
- [ok] `/projects`
- [ok] `/projects/test-project`
- [ok] `/series`
- [ok] `/series/test-series`
- [ok] `/shots`
- [ok] `/shots/test-shot`

#### AC-001 (library overview)
- Pagination shape ok: `True`  (expects items[] + page{limit,offset,total,has_more})
- Library markers ok: `True`  (FiltersBar/AssetGrid/BulkActionBar)

#### AC-002 (asset detail)
- picked asset_id: `5FBA8D5F46254AF9819D359F83726558`
- non-existent asset error envelope ok: `True`  (error/message/request_id/details)
- detail panel markers ok: `True`

#### AC-003 (generate runs)
- type `t2i`: run_id `01KDQJBHQPG7DKPJBGTD4QQJEB` ; request_id `a71d7a12-c74e-4e62-89a6-df4b52fb05c3`
- type `i2i`: run_id `01KDQJBHWCYK741FSZ1AR3MTYN` ; request_id `d97aa873-77cf-49cf-9752-f3536a0d0cf7`
- type `t2v`: run_id `01KDQJBJ184NYQ28JK3G60BS35` ; request_id `050e2197-05d2-4986-a797-be3741f1af00`
- type `i2v`: run_id `01KDQJBJ69B81323XC9M1Q0XWF` ; request_id `fad5e45d-e926-4958-a871-007b24a04837`

#### AC-004 (review override)
- override missing reason request_id: `478366c6-3a0e-4adb-8d87-4c483b3b11a7`
- Review UI markers wired: `True`

#### Raw logs (local paths)
- `tmp/_out_gate_web_routes.txt`
- `tmp/_out_gate_ac_001.txt`
- `tmp/_out_gate_ac_002.txt`
- `tmp/_out_gate_ac_003.txt`
- `tmp/_out_gate_ac_004.txt`
