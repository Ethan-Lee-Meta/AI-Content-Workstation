#!/usr/bin/env bash
set -euo pipefail

echo "== gate_export_preview_ui: start =="

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"
WEB_BASE_URL="${WEB_BASE_URL:-http://127.0.0.1:2000}"

TMPDIR="${TMPDIR:-$(pwd)/tmp/gate_export_preview_ui.$$}"
mkdir -p "$TMPDIR"

echo "== [info] API_BASE_URL=$API_BASE_URL =="
echo "== [info] WEB_BASE_URL=$WEB_BASE_URL =="
echo "== [info] TMPDIR=$TMPDIR =="

# 1) openapi has exports/imports paths
curl -sS "$API_BASE_URL/openapi.json" -o "$TMPDIR/openapi.json"
python - "$TMPDIR/openapi.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1],'r',encoding='utf-8'))
paths=p.get("paths") or {}
need=["/exports","/imports"]
miss=[x for x in need if x not in paths]
if miss:
  raise SystemExit(f"[err] openapi missing paths: {miss}")
print("[ok] openapi has exports/imports paths")
PY

# 2) create export
curl -sS -D "$TMPDIR/export_create.hdr" -o "$TMPDIR/export_create.json" \
  -H 'Content-Type: application/json' \
  -X POST "$API_BASE_URL/exports" \
  -d '{}'

python - "$TMPDIR/export_create.json" "$TMPDIR/export_id.txt" <<'PY'
import json,sys
j=json.load(open(sys.argv[1],'r',encoding='utf-8'))
eid=j.get("export_id") or j.get("id")
if not eid:
  raise SystemExit("[err] export create response missing export_id/id")
open(sys.argv[2],'w',encoding='utf-8').write(eid)
print(f"[ok] export created export_id={eid}")
PY

EXPORT_ID="$(cat "$TMPDIR/export_id.txt")"

# 3) read manifest (no import)
curl -sS -D "$TMPDIR/manifest.hdr" -o "$TMPDIR/manifest.json" \
  "$API_BASE_URL/exports/$EXPORT_ID/manifest"

python - "$TMPDIR/manifest.json" <<'PY'
import json,sys
m=json.load(open(sys.argv[1],'r',encoding='utf-8'))
need=["manifest_version","export_id","created_at","selection","tables","assets_preview","warnings"]
miss=[k for k in need if k not in m]
if miss:
  raise SystemExit(f"[err] manifest missing keys: {miss}")
rc=((m.get("tables") or {}).get("row_counts") or {})
print(f"[ok] manifest readable (no import); assets_preview={len(m.get('assets_preview') or [])}; links={rc.get('links','NA')}")
PY

# 4) web route reachable
CODE="$(curl -sS -o "$TMPDIR/transfer.html" -w '%{http_code}' \
  "$WEB_BASE_URL/transfer?export_id=$EXPORT_ID")"
if [ "$CODE" != "200" ]; then
  echo "[err] web /transfer not reachable: http_code=$CODE" >&2
  exit 10
fi

grep -q "No-Import Preview" "$TMPDIR/transfer.html" && echo "[ok] transfer page contains No-Import Preview" || {
  echo "[warn] transfer page did not contain marker text (still http 200)"; }

echo "[ok] gate_export_preview_ui passed"
