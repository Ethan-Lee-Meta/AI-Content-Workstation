#!/usr/bin/env bash
set -euo pipefail

echo "== gate_export_import: start =="

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY || true
export NO_PROXY="127.0.0.1,localhost"
export API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"

PY="$ROOT/apps/api/.venv/Scripts/python.exe"
if [ ! -x "$PY" ]; then PY="python"; fi

TMPDIR="$ROOT/tmp/gate_export_import.$$"
mkdir -p "$TMPDIR"
export TMPDIR
cleanup() { rm -rf "$TMPDIR" 2>/dev/null || true; }
trap cleanup EXIT

echo "== [info] API_BASE_URL=$API_BASE_URL =="
echo "== [info] PY=$PY =="
echo "== [info] TMPDIR=$TMPDIR =="

# ---- openapi reachable + paths
curl -4 -fsS --connect-timeout 2 --max-time 15 \
  -D "$TMPDIR/openapi.hdr" \
  -o "$TMPDIR/openapi.json" \
  "$API_BASE_URL/openapi.json"

"$PY" - <<'PY'
import json, os
p=os.path.join(os.environ["TMPDIR"], "openapi.json")
o=json.load(open(p,"r",encoding="utf-8"))
paths=o.get("paths",{})
need=["/exports","/exports/{export_id}","/exports/{export_id}/manifest","/imports","/imports/{import_id}"]
missing=[x for x in need if x not in paths]
if missing:
    raise SystemExit("[err] openapi missing: " + ", ".join(missing))
print("[ok] openapi has exports/imports paths")
PY

# ---- create export
curl -4 -fsS --connect-timeout 2 --max-time 30 \
  -D "$TMPDIR/export_create.hdr" \
  -o "$TMPDIR/export_create.json" \
  -X POST "$API_BASE_URL/exports" \
  -H "Content-Type: application/json" \
  -d '{}'

REQID_EXPORT="$(grep -i '^x-request-id:' "$TMPDIR/export_create.hdr" | head -n 1 | awk '{print $2}' | tr -d '\r')"
[ -n "${REQID_EXPORT:-}" ] || { echo "[err] missing X-Request-Id on POST /exports"; exit 11; }
echo "[ok] export create request_id=$REQID_EXPORT"

EXPORT_ID="$("$PY" - <<'PY'
import json, os
p=os.path.join(os.environ["TMPDIR"], "export_create.json")
o=json.load(open(p,"r",encoding="utf-8"))
print(o["export_id"])
PY
)"
echo "[ok] export_id=$EXPORT_ID"

# ---- read manifest
curl -4 -fsS --connect-timeout 2 --max-time 15 \
  -D "$TMPDIR/manifest.hdr" \
  -o "$TMPDIR/manifest.json" \
  "$API_BASE_URL/exports/$EXPORT_ID/manifest"

REQID_MANIFEST="$(grep -i '^x-request-id:' "$TMPDIR/manifest.hdr" | head -n 1 | awk '{print $2}' | tr -d '\r')"
[ -n "${REQID_MANIFEST:-}" ] || { echo "[err] missing X-Request-Id on GET /exports/{id}/manifest"; exit 12; }
echo "[ok] manifest readable (no import); request_id=$REQID_MANIFEST"

# extract expected counts + table names
eval "$("$PY" - <<'PY'
import json, os
p=os.path.join(os.environ["TMPDIR"], "manifest.json")
m=json.load(open(p,"r",encoding="utf-8"))
res=(m.get("tables") or {}).get("resolved_table_names") or {}
rc=(m.get("tables") or {}).get("row_counts") or {}
def q(s): return "'" + str(s).replace("'","'\"'\"'") + "'"
print("ASSET_TABLE="+q(res.get("assets","")))
print("LINK_TABLE="+q(res.get("links","")))
print("ASSET_EXPECTED="+str(int(rc.get("assets",0) or 0)))
print("LINK_EXPECTED="+str(int(rc.get("links",0) or 0)))
PY
)"
echo "== [info] asset_table=$ASSET_TABLE expected=$ASSET_EXPECTED =="
echo "== [info] link_table=$LINK_TABLE expected=$LINK_EXPECTED =="

# ---- negative path: bogus manifest -> error envelope
curl -4 -sS --connect-timeout 2 --max-time 10 \
  -D "$TMPDIR/bad_manifest.hdr" \
  -o "$TMPDIR/bad_manifest.json" \
  "$API_BASE_URL/exports/NO_SUCH_EXPORT_ID/manifest" || true

REQID_BAD="$(grep -i '^x-request-id:' "$TMPDIR/bad_manifest.hdr" | head -n 1 | awk '{print $2}' | tr -d '\r')"
[ -n "${REQID_BAD:-}" ] || { echo "[err] missing X-Request-Id on bad manifest path"; exit 13; }

"$PY" - <<'PY'
import json, os
p=os.path.join(os.environ["TMPDIR"], "bad_manifest.json")
o=json.load(open(p,"r",encoding="utf-8"))
need=["error","message","request_id","details"]
miss=[k for k in need if k not in o]
if miss:
    raise SystemExit("[err] error envelope missing keys: "+",".join(miss))
print("[ok] bad manifest returns error envelope + request_id")
PY

# ---- create import
curl -4 -fsS --connect-timeout 2 --max-time 60 \
  -D "$TMPDIR/import_create.hdr" \
  -o "$TMPDIR/import_create.json" \
  -X POST "$API_BASE_URL/imports" \
  -H "Content-Type: application/json" \
  -d "{\"export_id\":\"$EXPORT_ID\"}"

REQID_IMPORT="$(grep -i '^x-request-id:' "$TMPDIR/import_create.hdr" | head -n 1 | awk '{print $2}' | tr -d '\r')"
[ -n "${REQID_IMPORT:-}" ] || { echo "[err] missing X-Request-Id on POST /imports"; exit 14; }
echo "[ok] import create request_id=$REQID_IMPORT"

IMPORT_ID="$("$PY" - <<'PY'
import json, os
p=os.path.join(os.environ["TMPDIR"], "import_create.json")
o=json.load(open(p,"r",encoding="utf-8"))
print(o["import_id"])
PY
)"
echo "[ok] import_id=$IMPORT_ID"

# ---- get import record
curl -4 -fsS --connect-timeout 2 --max-time 15 \
  -D "$TMPDIR/import_get.hdr" \
  -o "$TMPDIR/import_get.json" \
  "$API_BASE_URL/imports/$IMPORT_ID"

"$PY" - <<'PY'
import json, os
p=os.path.join(os.environ["TMPDIR"], "import_get.json")
o=json.load(open(p,"r",encoding="utf-8"))
st=o.get("status")
if st!="completed":
    raise SystemExit("[err] import status != completed: "+str(st))
print("[ok] import completed")
PY

# ---- relationships preservation (minimum)
if [ "${LINK_EXPECTED:-0}" -gt 0 ] && [ -n "${LINK_TABLE:-}" ]; then
  export LINK_TABLE
  LINK_IMPORTED="$("$PY" -c "import json,os; lt=os.environ.get('LINK_TABLE',''); p=os.path.join(os.environ['TMPDIR'],'import_get.json'); o=json.load(open(p,'r',encoding='utf-8')); print(int((o.get('counts') or {}).get(lt,0) or 0))")"

  case "${LINK_IMPORTED:-}" in
    ''|*[!0-9]*)
      echo "[err] invalid LINK_IMPORTED='${LINK_IMPORTED:-}' (LINK_TABLE=$LINK_TABLE)"
      exit 22
      ;;
  esac

  if [ "$LINK_IMPORTED" -le 0 ]; then
    echo "[err] links not preserved: expected>0 but imported=$LINK_IMPORTED (table=$LINK_TABLE)"
    exit 21
  fi
  echo "[ok] relationships (links) preserved: imported=$LINK_IMPORTED"
else
  echo "[warn] skip links preservation check (no links expected or no links table)"
fi

echo "== gate_export_import: done =="

