set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

BR="$(git rev-parse --abbrev-ref HEAD)"
TS_TAG="$(date -u +%Y%m%d_%H%M%S 2>/dev/null || echo 20251231_000000)"
HANDOFF_TAG="handoff-p0-cumulative-${TS_TAG}"

echo "== [info] root=$(pwd) =="
echo "== [info] branch=$BR =="
echo "== [info] handoff_tag=$HANDOFF_TAG =="

mkdir -p docs tmp

# ---------------------------------------------------------
# 0) best-effort cleanup: never commit backups/tmp artifacts
# ---------------------------------------------------------
echo "== 0) cleanup backups (best-effort) =="
find apps/api/app -type f -name "*.bak.*" -delete 2>/dev/null || true
find scripts     -type f -name "*.bak.*" -delete 2>/dev/null || true

# ---------------------------------------------------------
# 1) rewrite SINGLE handoff (self-contained, no other-doc refs)
# ---------------------------------------------------------
echo "== 1) write docs/HANDOFF_P0_CUMULATIVE.md =="
TS_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo NA)"
SHA_NOW="$(git rev-parse HEAD)"

cat > docs/HANDOFF_P0_CUMULATIVE.md <<MD
# HANDOFF — P0 Cumulative (Standalone, Single-File)

This document is **self-contained** and intended to be the **only** handoff artifact passed to the next window.
It describes the **current shipped capabilities**, **API surface**, **verification gates**, and **how to continue development**.

---

## 0) Snapshot

- Repo: \`AI-Content-Workstation\`
- Branch (at generation): \`${BR}\`
- HEAD (at generation): \`${SHA_NOW}\`
- Generated (UTC): \`${TS_UTC}\`
- Stable locator (tag): \`${HANDOFF_TAG}\`  (created & pushed by the finalize script)

### Fixed runtime expectations (P0 locks)
- Backend: FastAPI on \`127.0.0.1:7000\`
- Frontend dev server (expected): \`127.0.0.1:2000\`

---

## 1) What is implemented now (Backend)

### 1.1 Observability & contracts
- \`GET /health\` returns required keys: \`status, version, db, storage, last_error_summary\`
- Request tracing:
  - Incoming \`X-Request-Id\` is supported and echoed on success responses
  - Error responses use a unified error envelope and include \`request_id\`
- \`GET /openapi.json\` is reachable

### 1.2 Assets (read + soft delete mutation)
- \`GET /assets\`
  - Pagination: \`offset\`, \`limit\` with \`items[]\` and \`page{limit,offset,total,has_more}\`
  - Defaults: \`limit=50\`, max \`limit=200\`
  - Default excludes soft-deleted assets
  - \`include_deleted=true\` includes soft-deleted assets
- \`GET /assets/{asset_id}\`
  - Returns asset details including traceability references
- \`DELETE /assets/{asset_id}\` (**soft delete; idempotent**)
  - Soft delete sets \`assets.deleted_at = <UTC timestamp>\` (no physical delete)
  - Idempotent: repeated soft delete returns success and signals \`already_deleted\` (must not 500)
  - Missing asset returns \`404\` using unified error envelope + \`request_id\`

### 1.3 Runs (core contract)
- \`POST /runs\` returns \`run_id\`, \`prompt_pack_id\`, \`status\`; evidence append-only
- \`GET /runs/{run_id}\` returns status + result refs; missing run returns error envelope + request_id

### 1.4 Reviews
- \`POST /reviews\` supports manual + override
- Override requires non-empty \`reason\`; otherwise rejected with error envelope + request_id

### 1.5 Trash (purge + audit)
- \`POST /trash/empty\`
  - Purges only soft-deleted assets (\`deleted_at IS NOT NULL\`)
  - Best-effort removes related storage files
  - Returns: success + \`X-Request-Id\`, and an \`audit_event\` containing at least:
    - \`event="trash.empty"\`, \`action="trash_empty"\`, \`request_id\`, \`purged_count\`, \`ts\`
  - After purge: \`GET /assets?include_deleted=true\` no longer returns purged assets

### 1.6 Storage/DB defaults
- SQLite: \`DATABASE_URL=sqlite:///./data/app.db\`
- Storage: \`STORAGE_ROOT=./data/storage\`

---

## 2) What is implemented now (Frontend)
- Frontend code lives under \`apps/web/app\` (Next.js App Router).
- Run dev (from repo root):
  - \`cd apps/web && npm i && npm run dev -- --port 2000\`
- Note: UI bulk soft-delete + trash view wiring may still be pending, but backend now provides the required soft-delete + purge loop.

---

## 3) Verification (Gates) — re-check quickly

Run from repo root (API on \`127.0.0.1:7000\`):

- \`bash scripts/gate_api_p1_caps_strict.sh\`
- \`bash scripts/gate_assets_read.sh\`
- \`bash scripts/gate_runs_core.sh\`
- \`bash scripts/gate_reviews.sh\`
- \`bash scripts/gate_trash.sh\` (soft delete → include_deleted visible → trash empty purge)

---

## 4) How to run backend (Windows Git Bash safe)
- \`./apps/api/.venv/Scripts/python.exe -m uvicorn app.main:app --app-dir apps/api --host 127.0.0.1 --port 7000\`

Common fix:
- Port bind error (\`[Errno 10048]\`): stop existing uvicorn before starting another.

---

## 5) Command Protocol (for next window)
- Commands should be provided in a single fenced code block.
- Prefer: generate a script under \`tmp/\` then run \`bash tmp/<script>.sh\`.
  - Avoid pasting top-level \`exit\` chains into the interactive shell (can kill VSCode terminal).
- Never commit: \`tmp/\`, \`*.bak.*\`.
- If unrelated files change (example: \`apps/web/package-lock.json\`), revert before staging.
MD

# ---------------------------------------------------------
# 2) start uvicorn once + run gates (reuse if scripts support it)
# ---------------------------------------------------------
echo "== 2) start uvicorn + run gates =="

PYBIN="./apps/api/.venv/Scripts/python.exe"
LOG="tmp/uvicorn_finalize_softdelete.log"

"$PYBIN" -m uvicorn app.main:app --app-dir apps/api --host 127.0.0.1 --port 7000 >"$LOG" 2>&1 &
PID="$!"
echo "[info] uvicorn PID=$PID (log: $LOG)"

"$PYBIN" - <<'PY'
import time, urllib.request
url="http://127.0.0.1:7000/health"
for _ in range(40):
    try:
        with urllib.request.urlopen(url, timeout=1.5) as r:
            if r.status == 200:
                print("[ok] /health reachable")
                raise SystemExit(0)
    except Exception:
        time.sleep(0.25)
raise SystemExit(2)
PY

set +e
bash scripts/gate_api_p1_caps_strict.sh; RC1=$?
bash scripts/gate_assets_read.sh;       RC2=$?
bash scripts/gate_runs_core.sh;         RC3=$?
bash scripts/gate_reviews.sh;           RC4=$?
bash scripts/gate_trash.sh;             RC5=$?
set -e

echo "[rc] gate_api_p1_caps_strict=$RC1"
echo "[rc] gate_assets_read=$RC2"
echo "[rc] gate_runs_core=$RC3"
echo "[rc] gate_reviews=$RC4"
echo "[rc] gate_trash=$RC5"

kill "$PID" >/dev/null 2>&1 || true
wait "$PID" >/dev/null 2>&1 || true
echo "[ok] uvicorn stopped"

if [ "$RC1" -ne 0 ] || [ "$RC2" -ne 0 ] || [ "$RC3" -ne 0 ] || [ "$RC4" -ne 0 ] || [ "$RC5" -ne 0 ]; then
  echo "[err] gates failed; NOT committing"
  exit 10
fi

# ---------------------------------------------------------
# 3) stage allow-list only + guard forbidden paths
# ---------------------------------------------------------
echo "== 3) stage allow-list only =="

git reset >/dev/null

# best-effort revert common forbidden accidental change
git restore --source=HEAD -- apps/web/package-lock.json 2>/dev/null || true

git add -A apps/api/app scripts docs/HANDOFF_P0_CUMULATIVE.md

echo "== staged files =="
git diff --cached --name-only

BAD="$(git diff --cached --name-only | grep -E '(^tmp/|\.bak\.|^apps/web/package-lock\.json$)' || true)"
if [ -n "$BAD" ]; then
  echo "[err] forbidden staged paths detected:"
  echo "$BAD"
  exit 11
fi
echo "[ok] staged paths within allow-list"

# ---------------------------------------------------------
# 4) commit + tag + push
# ---------------------------------------------------------
echo "== 4) commit + tag + push =="

git diff --cached --quiet && {
  echo "[info] no staged changes; skipping commit/tag/push"
  exit 0
}

git commit -m "batch2: soft delete completion (assets mutation) + trash audit + gates + single-file handoff"

git tag -a "$HANDOFF_TAG" -m "P0 cumulative single-file handoff"

git log -1 --oneline --decorate

git push -u origin "$BR"
git push origin "$HANDOFF_TAG"

echo "[ok] done; handoff tag=$HANDOFF_TAG"
