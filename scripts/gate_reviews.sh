#!/usr/bin/env bash
set +e

cd "$(git rev-parse --show-toplevel)" || exit 1
ROOT="$(pwd)"
mkdir -p tmp

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"
TMPDIR="$ROOT/tmp/gate_reviews.$$"
mkdir -p "$TMPDIR"

echo "== gate_reviews: start =="
echo "[info] API_BASE_URL=$API_BASE_URL"
echo "[info] TMPDIR=$TMPDIR"

cleanup() { rm -rf "$TMPDIR" >/dev/null 2>&1; }
trap cleanup EXIT

# reachability
curl -sS -D "$TMPDIR/health.h" "$API_BASE_URL/health" -o "$TMPDIR/health.json" >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] cannot reach API /health (need uvicorn running on 127.0.0.1:7000)"
  echo "== gate_reviews: fail =="
  exit 2
fi

# helper: parse json keys via python
py_has_keys() {
  local file="$1"
  shift
  python -c "import json,sys; j=json.load(open(sys.argv[1],'r',encoding='utf-8')); \
ks=set(sys.argv[2:]); \
missing=[k for k in ks if k not in j]; \
assert not missing, 'missing keys: '+','.join(missing)" "$file" "$@" 2>/dev/null
}

# -----------------------------
# (1) POST /reviews manual -> review_id + status ; request-id echo
# -----------------------------
RID1="RID_REV_MANUAL_$(date +%s)"
cat > "$TMPDIR/r1_in.json" <<'JSON'
{"review_type":"manual","conclusion":"pass","score":90,"reason":"gate manual","details":{"src":"gate_reviews","case":"manual"}}
JSON

HTTP1="$(curl -sS \
  -H "Content-Type: application/json" \
  -H "X-Request-Id: $RID1" \
  -D "$TMPDIR/r1.h" \
  -X POST "$API_BASE_URL/reviews" \
  --data-binary @"$TMPDIR/r1_in.json" \
  -o "$TMPDIR/r1.json" \
  -w "%{http_code}")"

HDR_RID1="$(grep -i '^x-request-id:' "$TMPDIR/r1.h" | head -n 1 | awk -F': ' '{print $2}' | tr -d '\r')"
if [ "$HDR_RID1" != "$RID1" ]; then
  echo "[err] request-id echo mismatch on POST /reviews: sent=$RID1 got=$HDR_RID1"
  echo "== gate_reviews: fail =="
  exit 3
fi
if [ "$HTTP1" -lt 200 ] || [ "$HTTP1" -ge 300 ]; then
  echo "[err] POST /reviews manual expected 2xx, got $HTTP1; see $TMPDIR/r1.json"
  echo "== gate_reviews: fail =="
  exit 4
fi

py_has_keys "$TMPDIR/r1.json" review_id status
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] manual response missing keys; see $TMPDIR/r1.json"
  echo "== gate_reviews: fail =="
  exit 5
fi
echo "[ok] POST /reviews manual returns review_id + status"

# -----------------------------
# (2) override without reason -> 4xx + error_envelope + request_id
# -----------------------------
RID2="RID_REV_OVERRIDE_NO_REASON_$(date +%s)"
cat > "$TMPDIR/r2_in.json" <<'JSON'
{"review_type":"override","conclusion":"pass","details":{"src":"gate_reviews","case":"override_no_reason"}}
JSON

HTTP2="$(curl -sS \
  -H "Content-Type: application/json" \
  -H "X-Request-Id: $RID2" \
  -D "$TMPDIR/r2.h" \
  -X POST "$API_BASE_URL/reviews" \
  --data-binary @"$TMPDIR/r2_in.json" \
  -o "$TMPDIR/r2.json" \
  -w "%{http_code}")"

HDR_RID2="$(grep -i '^x-request-id:' "$TMPDIR/r2.h" | head -n 1 | awk -F': ' '{print $2}' | tr -d '\r')"
if [ "$HDR_RID2" != "$RID2" ]; then
  echo "[err] request-id echo mismatch on override 4xx: sent=$RID2 got=$HDR_RID2"
  echo "== gate_reviews: fail =="
  exit 6
fi
if [ "$HTTP2" -lt 400 ] || [ "$HTTP2" -ge 500 ]; then
  echo "[err] override without reason expected 4xx, got $HTTP2; see $TMPDIR/r2.json"
  echo "== gate_reviews: fail =="
  exit 7
fi

RID2="$RID2" python -c "import os,json,sys; rid=os.environ['RID2']; j=json.load(open(sys.argv[1],'r',encoding='utf-8')); \
assert all(k in j for k in ('error','message','request_id','details')); \
assert j.get('request_id')==rid; \
print('[ok] override without reason rejected with error_envelope (request_id present)')" "$TMPDIR/r2.json" 2>/dev/null
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] override error envelope invalid; see $TMPDIR/r2.json"
  echo "== gate_reviews: fail =="
  exit 8
fi

# -----------------------------
# (3) override with reason -> 2xx
# -----------------------------
RID3="RID_REV_OVERRIDE_OK_$(date +%s)"
cat > "$TMPDIR/r3_in.json" <<'JSON'
{"review_type":"override","conclusion":"pass","reason":"gate override ok","details":{"src":"gate_reviews","case":"override_ok"}}
JSON

HTTP3="$(curl -sS \
  -H "Content-Type: application/json" \
  -H "X-Request-Id: $RID3" \
  -D "$TMPDIR/r3.h" \
  -X POST "$API_BASE_URL/reviews" \
  --data-binary @"$TMPDIR/r3_in.json" \
  -o "$TMPDIR/r3.json" \
  -w "%{http_code}")"

HDR_RID3="$(grep -i '^x-request-id:' "$TMPDIR/r3.h" | head -n 1 | awk -F': ' '{print $2}' | tr -d '\r')"
if [ "$HDR_RID3" != "$RID3" ]; then
  echo "[err] request-id echo mismatch on override ok: sent=$RID3 got=$HDR_RID3"
  echo "== gate_reviews: fail =="
  exit 9
fi
if [ "$HTTP3" -lt 200 ] || [ "$HTTP3" -ge 300 ]; then
  echo "[err] override with reason expected 2xx, got $HTTP3; see $TMPDIR/r3.json"
  echo "== gate_reviews: fail =="
  exit 10
fi

py_has_keys "$TMPDIR/r3.json" review_id status
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] override ok response missing keys; see $TMPDIR/r3.json"
  echo "== gate_reviews: fail =="
  exit 11
fi
echo "[ok] POST /reviews override with reason accepted"

echo "== gate_reviews: passed =="
exit 0
