#!/usr/bin/env bash
set -u

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"
TMPDIR="${TMPDIR:-}"
if [ -z "${TMPDIR}" ]; then
  TMPDIR="$(mktemp -d 2>/dev/null || echo "tmp/gate_trash.$RANDOM")"
fi
mkdir -p "$TMPDIR"

echo "== gate_trash: start =="
echo "== [info] API_BASE_URL=$API_BASE_URL =="
echo "== [info] TMPDIR=$TMPDIR =="

# pick python (prefer api venv if exists)
PY="python"
if [ -x "apps/api/.venv/Scripts/python.exe" ]; then PY="apps/api/.venv/Scripts/python.exe"; fi
if [ -x "apps/api/.venv/bin/python" ]; then PY="apps/api/.venv/bin/python"; fi
echo "== [info] PY=$PY =="

rc=0

_http() {
  local method="$1"; shift
  local url="$1"; shift
  local body_file="$1"; shift
  local hdr_file="$1"; shift

  # remaining args are curl extra flags
  local code
  code="$(curl -sS -D "$hdr_file" -o "$body_file" -w "%{http_code}" -X "$method" "$url" "$@" || echo "000")"
  echo "$code"
}

_json_get() {
  # $1: file, $2: dotted path (simple), prints value or empty
  "$PY" - <<'PY' "$1" "$2" 2>/dev/null || true
import json,sys
p=sys.argv[2].split(".")
o=json.load(open(sys.argv[1],"r",encoding="utf-8"))
cur=o
for k in p:
  if isinstance(cur, dict) and k in cur:
    cur=cur[k]
  else:
    cur=""
    break
if isinstance(cur, (dict,list)):
  import json as _j
  print(_j.dumps(cur, ensure_ascii=False))
else:
  print(cur)
PY
}

_pick_asset_id() {
  local url="$API_BASE_URL/assets?offset=0&limit=50&include_deleted=true"
  local body="$TMPDIR/assets.list.json"
  local hdr="$TMPDIR/assets.list.headers.txt"
  local code
  code="$(_http GET "$url" "$body" "$hdr")"
  if [ "$code" != "200" ]; then
    echo "[err] GET /assets failed code=$code"
    sed -n '1,200p' "$body" || true
    return 1
  fi
  "$PY" - <<'PY' "$body"
import json,sys
o=json.load(open(sys.argv[1],"r",encoding="utf-8"))
items=o.get("items") or []
# prefer a not-deleted item if possible
for it in items:
  if (it.get("deleted_at") in (None,"")):
    print(it.get("asset_id") or it.get("id") or "")
    raise SystemExit(0)
# fallback: any item
if items:
  it=items[0]
  print(it.get("asset_id") or it.get("id") or "")
else:
  print("")
PY
}

_contains_asset_with_deleted() {
  # $1: asset_id, $2: include_deleted (true/false), $3: expect_deleted (true/false)
  "$PY" - <<'PY' "$1" "$2" "$3" "$TMPDIR/assets.check.json"
import json,sys
aid=sys.argv[1]
include_deleted=(sys.argv[2].lower()=="true")
expect_deleted=(sys.argv[3].lower()=="true")
o=json.load(open(sys.argv[4],"r",encoding="utf-8"))
items=o.get("items") or []
found=False
ok=False
for it in items:
  _id=it.get("asset_id") or it.get("id")
  if _id==aid:
    found=True
    deleted=(it.get("deleted_at") not in (None,""))
    ok = (deleted==expect_deleted)
    break
print("FOUND" if found else "NOT_FOUND", "OK" if ok else "BAD")
PY
}

_fetch_assets_to_tmp() {
  local url="$1"
  curl -sS "$url" > "$TMPDIR/assets.check.json" || true
}

step() { echo; echo "== [step] $* =="; }

ASSET_ID="$(_pick_asset_id || true)"
if [ -z "$ASSET_ID" ]; then
  echo "[err] cannot pick any asset_id from GET /assets (need at least 1 asset in DB)"
  rc=1
else
  echo "[info] picked asset_id=$ASSET_ID"
fi

if [ "$rc" -eq 0 ]; then
  step "soft delete (action=delete default)"
  BODY="$TMPDIR/delete.body.json"
  HDR="$TMPDIR/delete.headers.txt"
  CODE="$(_http DELETE "$API_BASE_URL/assets/$ASSET_ID" "$BODY" "$HDR")"
  if [ "$CODE" != "200" ]; then
    echo "[err] DELETE /assets/{id} failed code=$CODE"
    echo "[err] body:"
    sed -n '1,260p' "$BODY" || true
    rc=1
  else
    echo "[ok] deleted"
  fi
fi

if [ "$rc" -eq 0 ]; then
  step "trash visibility (include_deleted=true -> deleted_at != null)"
  _fetch_assets_to_tmp "$API_BASE_URL/assets?offset=0&limit=100&include_deleted=true"
  RES="$(_contains_asset_with_deleted "$ASSET_ID" true true || true)"
  echo "[info] check=$RES"
  if ! echo "$RES" | grep -q "FOUND OK"; then
    echo "[err] asset not found as deleted in include_deleted list"
    rc=1
  else
    echo "[ok] visible in trash list"
  fi
fi

if [ "$rc" -eq 0 ]; then
  step "restore (DELETE action=restore)"
  BODY="$TMPDIR/restore.body.json"
  HDR="$TMPDIR/restore.headers.txt"
  CODE="$(_http DELETE "$API_BASE_URL/assets/$ASSET_ID?action=restore" "$BODY" "$HDR")"
  if [ "$CODE" != "200" ]; then
    echo "[err] RESTORE failed code=$CODE"
    echo "[err] body:"
    sed -n '1,260p' "$BODY" || true
    rc=1
  else
    echo "[ok] restored"
  fi
fi

if [ "$rc" -eq 0 ]; then
  step "default list visibility (GET /assets -> must include restored asset)"
  _fetch_assets_to_tmp "$API_BASE_URL/assets?offset=0&limit=200"
  RES="$(_contains_asset_with_deleted "$ASSET_ID" false false || true)"
  echo "[info] check=$RES"
  if ! echo "$RES" | grep -q "FOUND OK"; then
    echo "[err] asset not found as not-deleted in default list"
    rc=1
  else
    echo "[ok] visible in default list"
  fi
fi

if [ "$rc" -eq 0 ]; then
  step "delete again (prepare for empty trash)"
  BODY="$TMPDIR/delete2.body.json"
  HDR="$TMPDIR/delete2.headers.txt"
  CODE="$(_http DELETE "$API_BASE_URL/assets/$ASSET_ID" "$BODY" "$HDR")"
  if [ "$CODE" != "200" ]; then
    echo "[err] DELETE(2) failed code=$CODE"
    sed -n '1,260p' "$BODY" || true
    rc=1
  else
    echo "[ok] deleted(2)"
  fi
fi

if [ "$rc" -eq 0 ]; then
  step "empty trash (POST /trash/empty)"
  BODY="$TMPDIR/empty.body.json"
  HDR="$TMPDIR/empty.headers.txt"
  CODE="$(_http POST "$API_BASE_URL/trash/empty" "$BODY" "$HDR" -H "Content-Type: application/json" -d "{}")"
  if [ "$CODE" != "200" ]; then
    echo "[err] POST /trash/empty failed code=$CODE"
    sed -n '1,260p' "$BODY" || true
    rc=1
  else
    DELCNT="$(_json_get "$BODY" "deleted_count" || true)"
    REQID="$(_json_get "$BODY" "request_id" || true)"
    if [ -z "${DELCNT:-}" ]; then
      echo "[err] empty trash response missing deleted_count"
      echo "[err] body:"
      sed -n '1,260p' "$BODY" || true
      rc=1
    elif ! echo "$DELCNT" | grep -Eq '^[0-9]+$'; then
      echo "[err] empty trash deleted_count not numeric: $DELCNT"
      echo "[err] body:"
      sed -n '1,260p' "$BODY" || true
      rc=1
    else
      if [ -z "${REQID:-}" ]; then
      echo "[err] empty trash response missing request_id"
      echo "[err] body:"
      sed -n '1,260p' "$BODY" || true
      rc=1
    else
      echo "[ok] empty trash deleted_count=$DELCNT request_id=$REQID"
    fi
    fi
  fi
fi

if [ "$rc" -eq 0 ]; then
  step "verify asset not in include_deleted list after empty"
  _fetch_assets_to_tmp "$API_BASE_URL/assets?offset=0&limit=200&include_deleted=true"
  "$PY" - <<'PY' "$ASSET_ID" "$TMPDIR/assets.check.json"
import json,sys
aid=sys.argv[1]
o=json.load(open(sys.argv[2],"r",encoding="utf-8"))
items=o.get("items") or []
for it in items:
  _id=it.get("asset_id") or it.get("id")
  if _id==aid:
    print("FOUND")
    raise SystemExit(2)
print("NOT_FOUND")
PY
  if [ "$?" -ne 0 ]; then
    echo "[err] asset still present after empty"
    rc=1
  else
    echo "[ok] asset removed after empty"
  fi
fi

echo
echo "== gate_trash: done rc=$rc =="
exit "$rc"
