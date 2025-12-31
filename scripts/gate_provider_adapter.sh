#!/usr/bin/env bash
set -e

echo "== gate_provider_adapter: start =="

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"
TMPDIR="tmp/gate_provider_adapter.$$"
mkdir -p "$TMPDIR"

echo "== [info] API_BASE_URL=$API_BASE_URL =="
curl -sS "$API_BASE_URL/openapi.json" >/dev/null
echo "[ok] /openapi.json reachable"

PAYLOAD_FILE="$TMPDIR/payload.json"
cat > "$PAYLOAD_FILE" <<'JSON'
{"run_type":"t2i","prompt_pack":{"prompt":"gate_provider_adapter","params":{}}}
JSON

py_get_json() {
  python - <<'PY' "$1"
import json,sys
p=sys.argv[1]
try:
  txt=open(p,encoding="utf-8-sig").read()
  obj=json.loads(txt)
  print(json.dumps(obj,ensure_ascii=False))
except Exception as e:
  print(f"__JSON_PARSE_ERROR__ {type(e).__name__}: {e}")
PY
}

py_get_field() {
  python - <<'PY' "$1" "$2"
import json,sys
p=sys.argv[1]; k=sys.argv[2]
txt=open(p,encoding="utf-8-sig").read()
obj=json.loads(txt)
v=obj.get(k,"")
print("" if v is None else v)
PY
}

dump_resp() {
  local H="$1"; local B="$2"
  echo "== [dump] status line =="
  head -n 1 "$H" || true
  echo "== [dump] headers (first 30) =="
  sed -n '1,30p' "$H" || true
  echo "== [dump] body bytes =="
  wc -c "$B" || true
  echo "== [dump] body head (first 300 bytes) =="
  head -c 300 "$B" || true
  echo
}

do_post() {
  local label="$1"
  local RID="$2"
  shift 2
  local H="$TMPDIR/$label.headers.txt"
  local B="$TMPDIR/$label.body.txt"

  curl -sS -D "$H" -o "$B" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "X-Request-Id: $RID" \
    "$@" \
    -X POST "$API_BASE_URL/runs" \
    --data-binary @"$PAYLOAD_FILE"

  local J
  J="$(py_get_json "$B")"
  if echo "$J" | grep -q '^__JSON_PARSE_ERROR__'; then
    echo "[err] $label -> response is NOT valid JSON"
    dump_resp "$H" "$B"
    exit 3
  fi

  echo "$J" > "$TMPDIR/$label.body.json"
  echo "[ok] $label -> json ok"
}

# ---------- flag OFF ----------
RID_OFF="$(python - <<'PY'
import uuid; print(str(uuid.uuid4()))
PY
)"
echo "== [case] provider flag OFF =="
do_post "off" "$RID_OFF"

RUN_ID_OFF="$(py_get_field "$TMPDIR/off.body.json" run_id)"
STATUS_OFF="$(py_get_field "$TMPDIR/off.body.json" status)"
test -n "$RUN_ID_OFF"
test -n "$STATUS_OFF"
echo "[ok] flag OFF -> POST /runs ok run_id=$RUN_ID_OFF status=$STATUS_OFF"

G1="$TMPDIR/off.get.json"
curl -sS -o "$G1" "$API_BASE_URL/runs/$RUN_ID_OFF"
python - <<'PY' "$G1"
import json,sys
obj=json.load(open(sys.argv[1],encoding="utf-8-sig"))
assert obj.get("run_id"), "missing run_id"
rr=obj.get("result_refs") or {}
assert isinstance(rr, dict), "result_refs must be dict"
print("[ok] flag OFF -> GET ok status=%s result_refs_keys=%s" % (obj.get("status"), list(rr.keys())))
PY

# ---------- flag ON (success) ----------
RID_ON="$(python - <<'PY'
import uuid; print(str(uuid.uuid4()))
PY
)"
echo "== [case] provider flag ON (success) =="
do_post "on" "$RID_ON" -H "X-Provider-Enabled: 1"

RUN_ID_ON="$(py_get_field "$TMPDIR/on.body.json" run_id)"
STATUS_ON="$(py_get_field "$TMPDIR/on.body.json" status)"
if [ -z "$RUN_ID_ON" ] || [ -z "$STATUS_ON" ]; then
  echo "[err] flag ON -> unexpected JSON shape (expected RunCreateOut with run_id/status)"
  echo "== [dump] HTTP status line (on) =="
  grep -E '^HTTP/' "$TMPDIR/on.headers.txt" | tail -n 1 || true
  echo "== [dump] on.body.json =="
  cat "$TMPDIR/on.body.json" || true
  exit 4
fi
echo "[ok] flag ON -> POST /runs ok run_id=$RUN_ID_ON status=$STATUS_ON"

G2="$TMPDIR/on.get.json"
curl -sS -o "$G2" "$API_BASE_URL/runs/$RUN_ID_ON"
python - <<'PY' "$G2"
import json,sys
obj=json.load(open(sys.argv[1],encoding="utf-8-sig"))
rr=obj.get("result_refs") or {}
refs=(rr.get("refs") or []) if isinstance(rr, dict) else []
assert isinstance(refs, list), "result_refs.refs must be list"
assert len(refs) >= 1, "result_refs.refs must be non-empty when provider succeeds"
print("[ok] flag ON -> GET ok status=%s refs_count=%d" % (obj.get("status"), len(refs)))
PY

# verify artifact exists by /health.storage.root
HEALTH="$TMPDIR/health.json"
curl -sS -o "$HEALTH" "$API_BASE_URL/health"
python - <<'PY' "$HEALTH" "$RUN_ID_ON"
import json,os,sys
health=json.load(open(sys.argv[1],encoding="utf-8-sig"))
root=(health.get("storage") or {}).get("root") or "./data/storage"
run_id=sys.argv[2]
path=os.path.join(root, "runs", run_id, "result.json")
assert os.path.exists(path), f"missing artifact: {path}"
print("[ok] artifact exists:", path)
PY

# ---------- flag ON (forced fail) ----------
RID_FAIL="$(python - <<'PY'
import uuid; print(str(uuid.uuid4()))
PY
)"
echo "== [case] provider flag ON (forced fail) =="
H3="$TMPDIR/fail.headers.txt"
B3="$TMPDIR/fail.body.txt"
curl -sS -D "$H3" -o "$B3" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "X-Request-Id: $RID_FAIL" \
  -H "X-Provider-Enabled: 1" \
  -H "X-Provider-Force-Fail: 1" \
  -X POST "$API_BASE_URL/runs" \
  --data-binary @"$PAYLOAD_FILE"

J3="$(py_get_json "$B3")"
if echo "$J3" | grep -q '^__JSON_PARSE_ERROR__'; then
  echo "[err] forced fail -> response is NOT valid JSON"
  dump_resp "$H3" "$B3"
  exit 3
fi
echo "$J3" > "$TMPDIR/fail.body.json"

python - <<'PY' "$TMPDIR/fail.body.json"
import json,sys
obj=json.load(open(sys.argv[1],encoding="utf-8-sig"))
for k in ("error","message","request_id","details"):
    assert k in obj, f"missing envelope key: {k}"
run_id=(obj.get("details") or {}).get("run_id")
assert run_id, "details.run_id missing"
print("[ok] forced fail -> error_envelope ok request_id=%s run_id=%s" % (obj.get("request_id"), run_id))
PY

RUN_ID_FAIL="$(python - <<'PY' "$TMPDIR/fail.body.json"
import json,sys
obj=json.load(open(sys.argv[1],encoding="utf-8-sig"))
print((obj.get("details") or {}).get("run_id",""))
PY
)"
test -n "$RUN_ID_FAIL"

G3="$TMPDIR/fail.get.json"
curl -sS -o "$G3" "$API_BASE_URL/runs/$RUN_ID_FAIL"
python - <<'PY' "$G3"
import json,sys
obj=json.load(open(sys.argv[1],encoding="utf-8-sig"))
assert obj.get("status") == "failed", "run status must be failed after forced failure"
print("[ok] forced fail -> GET ok status=failed")
PY

echo "== gate_provider_adapter: passed =="
