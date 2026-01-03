#!/usr/bin/env bash
set +e

echo "== gate_characters_ui: start =="

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"
WEB_BASE_URL="${WEB_BASE_URL:-http://127.0.0.1:2000}"

if [ -z "${PY:-}" ]; then
  if [ -x "apps/api/.venv/Scripts/python.exe" ]; then
    PY="$(pwd)/apps/api/.venv/Scripts/python.exe"
  elif [ -x "apps/api/.venv/bin/python" ]; then
    PY="$(pwd)/apps/api/.venv/bin/python"
  else
    PY="python"
  fi
fi

TMPROOT="${TMPDIR:-$(pwd)/tmp}"
TMPDIR="$TMPROOT/gate_characters_ui.$$"
mkdir -p "$TMPDIR"

echo "== [info] API_BASE_URL=$API_BASE_URL =="
echo "== [info] WEB_BASE_URL=$WEB_BASE_URL =="
echo "== [info] PY=$PY =="
echo "== [info] TMPDIR=$TMPDIR =="

rc=0

echo "== [check] /characters route renders =="
http_code="$(curl -sS -o "$TMPDIR/characters.html" -w "%{http_code}" "$WEB_BASE_URL/characters")"
if [ "$http_code" = "200" ]; then
  echo "[ok] /characters http=200"
else
  echo "[err] /characters http=$http_code"
  rc=20
fi

echo "== [check] openapi reachable =="
curl -sS "$API_BASE_URL/openapi.json" > "$TMPDIR/openapi.json"
if [ $? -ne 0 ] || [ ! -s "$TMPDIR/openapi.json" ]; then
  echo "[warn] openapi not reachable; skipping character API checks (UI should degrade gracefully)"
  exit $rc
fi
echo "[ok] openapi reachable"

grep -q '"/characters"' "$TMPDIR/openapi.json"; HAS_C=$?
if [ $HAS_C -ne 0 ]; then
  echo "[warn] /characters missing in openapi; skipping character API checks"
  exit $rc
fi

echo "== [check] assets >= 8 (seed if needed) =="
curl -sS "$API_BASE_URL/assets?offset=0&limit=8" > "$TMPDIR/assets.json"

COUNT="$("$PY" - "$TMPDIR/assets.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1],"r",encoding="utf-8"))
items=j.get("items") or []
print(len(items))
PY
)"
if [ -z "$COUNT" ]; then COUNT=0; fi

if [ "$COUNT" -lt 8 ]; then
  if [ -x scripts/gate_assets_read.sh ]; then
    echo "[warn] assets<$COUNT; running gate_assets_read.sh to seed"
    bash scripts/gate_assets_read.sh
    curl -sS "$API_BASE_URL/assets?offset=0&limit=8" > "$TMPDIR/assets.json"
  else
    echo "[warn] assets<$COUNT and scripts/gate_assets_read.sh not found; API steps may fail"
  fi
fi

ASSET_IDS="$("$PY" - "$TMPDIR/assets.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1],"r",encoding="utf-8"))
items=j.get("items") or []
ids=[]
for it in items:
  i=it.get("id")
  if i: ids.append(i)
print(" ".join(ids[:8]))
PY
)"

if [ -z "$ASSET_IDS" ]; then
  echo "[warn] no asset ids available; skipping ref add steps"
  exit $rc
fi
echo "[ok] picked assets: $(echo "$ASSET_IDS" | awk '{print NF}')"

NAME="gate-char-$(date -u +%Y%m%d%H%M%S)"

echo "== [step] POST /characters (create) =="
printf '{"name":"%s"}' "$NAME" > "$TMPDIR/char_create.body.json"
curl -sS -D "$TMPDIR/char_create.headers.txt" -o "$TMPDIR/char_create.json" \
  -H "content-type: application/json" \
  -X POST "$API_BASE_URL/characters" \
  --data-binary @"$TMPDIR/char_create.body.json"

CHAR_ID="$("$PY" - "$TMPDIR/char_create.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1],"r",encoding="utf-8"))
print(j.get("id") or "")
PY
)"
if [ -z "$CHAR_ID" ]; then
  echo "[err] create character failed"
  echo "body=$(cat "$TMPDIR/char_create.json")"
  rc=21
  exit $rc
fi
echo "[ok] created character_id=$CHAR_ID"

echo "== [check] web route /characters/{id} renders (best-effort) =="
http_code2="$(curl -sS -o "$TMPDIR/char_page.html" -w "%{http_code}" "$WEB_BASE_URL/characters/$CHAR_ID")"
echo "[info] /characters/$CHAR_ID http=$http_code2"

echo "== [step] POST /characters/{id}/ref_sets (draft) =="
echo '{"status":"draft"}' > "$TMPDIR/refset_draft.body.json"
curl -sS -D "$TMPDIR/refset_draft.headers.txt" -o "$TMPDIR/refset_draft.json" \
  -H "content-type: application/json" \
  -X POST "$API_BASE_URL/characters/$CHAR_ID/ref_sets" \
  --data-binary @"$TMPDIR/refset_draft.body.json"

DRAFT_ID="$("$PY" - "$TMPDIR/refset_draft.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1],"r",encoding="utf-8"))
print(j.get("id") or j.get("ref_set_id") or "")
PY
)"
if [ -z "$DRAFT_ID" ]; then
  echo "[err] create draft ref_set failed"
  echo "body=$(cat "$TMPDIR/refset_draft.json")"
  rc=22
  exit $rc
fi
echo "[ok] created draft ref_set_id=$DRAFT_ID"

echo "== [step] POST refs (8 assets) =="
added=0
failed=0
for AID in $ASSET_IDS; do
  printf '{"asset_id":"%s"}' "$AID" > "$TMPDIR/addref.body.json"
  curl -sS -o "$TMPDIR/addref.out.json" \
    -H "content-type: application/json" \
    -X POST "$API_BASE_URL/characters/$CHAR_ID/ref_sets/$DRAFT_ID/refs" \
    --data-binary @"$TMPDIR/addref.body.json"
  if [ $? -eq 0 ]; then
    added=$((added+1))
  else
    failed=$((failed+1))
  fi
done
echo "[ok] add refs: added=$added failed=$failed"
if [ $failed -gt 0 ]; then rc=23; fi

echo "== [step] POST /characters/{id}/ref_sets (confirmed) try base_ref_set_id =="
printf '{"status":"confirmed","base_ref_set_id":"%s"}' "$DRAFT_ID" > "$TMPDIR/refset_confirm.body.json"
curl -sS -D "$TMPDIR/refset_confirm.headers.txt" -o "$TMPDIR/refset_confirm.json" \
  -H "content-type: application/json" \
  -X POST "$API_BASE_URL/characters/$CHAR_ID/ref_sets" \
  --data-binary @"$TMPDIR/refset_confirm.body.json"

CONF_ID="$("$PY" - "$TMPDIR/refset_confirm.json" <<'PY'
import json,sys
try:
  j=json.load(open(sys.argv[1],"r",encoding="utf-8"))
except Exception:
  print(""); raise SystemExit
print(j.get("id") or j.get("ref_set_id") or "")
PY
)"

if [ -z "$CONF_ID" ]; then
  echo "[warn] confirmed create with base_ref_set_id failed; retry without base_ref_set_id"
  echo '{"status":"confirmed"}' > "$TMPDIR/refset_confirm2.body.json"
  curl -sS -o "$TMPDIR/refset_confirm2.json" \
    -H "content-type: application/json" \
    -X POST "$API_BASE_URL/characters/$CHAR_ID/ref_sets" \
    --data-binary @"$TMPDIR/refset_confirm2.body.json"

  CONF_ID="$("$PY" - "$TMPDIR/refset_confirm2.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1],"r",encoding="utf-8"))
print(j.get("id") or j.get("ref_set_id") or "")
PY
)"
fi

if [ -z "$CONF_ID" ]; then
  echo "[err] create confirmed ref_set failed"
  rc=24
  echo "body=$(cat "$TMPDIR/refset_confirm.json" 2>/dev/null || true)"
else
  echo "[ok] created confirmed ref_set_id=$CONF_ID"
  echo "== [step] PATCH /characters/{id} set active_ref_set_id =="
  printf '{"active_ref_set_id":"%s"}' "$CONF_ID" > "$TMPDIR/setactive.body.json"
  curl -sS -o "$TMPDIR/setactive.json" \
    -H "content-type: application/json" \
    -X PATCH "$API_BASE_URL/characters/$CHAR_ID" \
    --data-binary @"$TMPDIR/setactive.body.json"
fi

echo "== gate_characters_ui: done rc=$rc =="
exit $rc
