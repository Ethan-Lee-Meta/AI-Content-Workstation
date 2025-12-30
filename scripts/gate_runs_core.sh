#!/usr/bin/env bash
set +e

cd "$(git rev-parse --show-toplevel)" || exit 1
ROOT="$(pwd)"
mkdir -p tmp

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"
TMPDIR="$ROOT/tmp/gate_runs_core.$$"
mkdir -p "$TMPDIR"

echo "== gate_runs_core: start =="
echo "[info] API_BASE_URL=$API_BASE_URL"
echo "[info] TMPDIR=$TMPDIR"

cleanup() { rm -rf "$TMPDIR" >/dev/null 2>&1; }
trap cleanup EXIT

# reachability
curl -sS -D "$TMPDIR/health.h" "$API_BASE_URL/health" -o "$TMPDIR/health.json" >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] cannot reach API /health (need uvicorn running on 127.0.0.1:7000)"
  echo "== gate_runs_core: fail =="
  exit 2
fi

# -----------------------------
# (1) POST /runs -> run_id + prompt_pack_id + status ; request-id echo
# -----------------------------
RID1="RID_RUNS_CREATE_$(date +%s)"
cat > "$TMPDIR/create.json" <<'JSON'
{"run_type":"t2i","prompt_pack":{"prompt":"gate_runs_core create","params":{"seed":1}}}
JSON

curl -sS \
  -H "Content-Type: application/json" \
  -H "X-Request-Id: $RID1" \
  -D "$TMPDIR/r1.h" \
  -X POST "$API_BASE_URL/runs" \
  --data-binary @"$TMPDIR/create.json" \
  -o "$TMPDIR/r1.json" >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] POST /runs failed"
  echo "== gate_runs_core: fail =="
  exit 3
fi

HDR_RID1="$(grep -i '^x-request-id:' "$TMPDIR/r1.h" | head -n 1 | awk -F': ' '{print $2}' | tr -d '\r')"
if [ "$HDR_RID1" != "$RID1" ]; then
  echo "[err] request-id echo mismatch on POST /runs: sent=$RID1 got=$HDR_RID1"
  echo "== gate_runs_core: fail =="
  exit 4
fi

RUN_ID_1="$(python -c "import json,sys; j=json.load(sys.stdin); \
print(j.get('run_id',''))" < "$TMPDIR/r1.json" 2>/dev/null)"
PP_ID_1="$(python -c "import json,sys; j=json.load(sys.stdin); \
print(j.get('prompt_pack_id',''))" < "$TMPDIR/r1.json" 2>/dev/null)"
STATUS_1="$(python -c "import json,sys; j=json.load(sys.stdin); \
print(j.get('status',''))" < "$TMPDIR/r1.json" 2>/dev/null)"

if [ -z "$RUN_ID_1" ] || [ -z "$PP_ID_1" ] || [ -z "$STATUS_1" ]; then
  echo "[err] POST /runs response missing keys; see $TMPDIR/r1.json"
  echo "== gate_runs_core: fail =="
  exit 5
fi
echo "[ok] POST /runs returns run_id + prompt_pack_id + status"

# -----------------------------
# (2) Retry rule: POST again should create NEW run_id (append-only)
# -----------------------------
RID2="RID_RUNS_RETRY_$(date +%s)"
curl -sS \
  -H "Content-Type: application/json" \
  -H "X-Request-Id: $RID2" \
  -D "$TMPDIR/r2.h" \
  -X POST "$API_BASE_URL/runs" \
  --data-binary @"$TMPDIR/create.json" \
  -o "$TMPDIR/r2.json" >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] retry POST /runs failed"
  echo "== gate_runs_core: fail =="
  exit 6
fi

RUN_ID_2="$(python -c "import json,sys; j=json.load(sys.stdin); print(j.get('run_id',''))" < "$TMPDIR/r2.json" 2>/dev/null)"
if [ -z "$RUN_ID_2" ]; then
  echo "[err] retry POST /runs missing run_id; see $TMPDIR/r2.json"
  echo "== gate_runs_core: fail =="
  exit 7
fi
if [ "$RUN_ID_2" = "$RUN_ID_1" ]; then
  echo "[err] retry must create new Run (run_id should differ). run_id=$RUN_ID_1"
  echo "== gate_runs_core: fail =="
  exit 8
fi
echo "[ok] evidence is append-only (retry creates new Run)"

# -----------------------------
# (3) GET /runs/{id} -> status + echo request-id
# -----------------------------
RID3="RID_RUNS_GET_$(date +%s)"
curl -sS -H "X-Request-Id: $RID3" -D "$TMPDIR/g1.h" \
  "$API_BASE_URL/runs/$RUN_ID_1" -o "$TMPDIR/g1.json" >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] GET /runs/{id} failed"
  echo "== gate_runs_core: fail =="
  exit 9
fi

HDR_RID3="$(grep -i '^x-request-id:' "$TMPDIR/g1.h" | head -n 1 | awk -F': ' '{print $2}' | tr -d '\r')"
if [ "$HDR_RID3" != "$RID3" ]; then
  echo "[err] request-id echo mismatch on GET /runs/{id}: sent=$RID3 got=$HDR_RID3"
  echo "== gate_runs_core: fail =="
  exit 10
fi

python -c "import json,sys; j=json.load(sys.stdin); \
assert j.get('run_id')=='$RUN_ID_1'; \
assert 'status' in j; \
assert 'result_refs' in j; \
print('[ok] GET /runs/{id} returns status + result refs')" < "$TMPDIR/g1.json" 2>/dev/null
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] GET /runs/{id} response invalid; see $TMPDIR/g1.json"
  echo "== gate_runs_core: fail =="
  exit 11
fi

# -----------------------------
# (4) Missing id -> error envelope + request_id
# -----------------------------
RID4="RID_RUNS_404_$(date +%s)"
MISSING_ID="01KDPHZZZZZZZZZZZZZZZZZZZZ"  # unlikely ULID; ok for gate
curl -sS -H "X-Request-Id: $RID4" -D "$TMPDIR/e1.h" \
  "$API_BASE_URL/runs/$MISSING_ID" -o "$TMPDIR/e1.json" >/dev/null 2>&1

HDR_RID4="$(grep -i '^x-request-id:' "$TMPDIR/e1.h" | head -n 1 | awk -F': ' '{print $2}' | tr -d '\r')"
if [ "$HDR_RID4" != "$RID4" ]; then
  echo "[err] request-id echo mismatch on 404: sent=$RID4 got=$HDR_RID4"
  echo "== gate_runs_core: fail =="
  exit 12
fi

RID4="$RID4" python -c "import os,json,sys; rid=os.environ['RID4']; j=json.load(sys.stdin); \
 \
assert all(k in j for k in ('error','message','request_id','details')); \
assert j.get('request_id')==rid; \
print('[ok] missing run returns error_envelope (request_id present)')" < "$TMPDIR/e1.json" 2>/dev/null
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] error envelope invalid; see $TMPDIR/e1.json"
  echo "== gate_runs_core: fail =="
  exit 13
fi

echo "== gate_runs_core: passed =="
exit 0
