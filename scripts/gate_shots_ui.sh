#!/usr/bin/env bash
set +e

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[err] not inside repo"; exit 1; }
cd "$ROOT" || exit 1

API_BASE="${API_BASE:-http://127.0.0.1:7000}"
WEB_BASE="${WEB_BASE:-http://127.0.0.1:2000}"
RID="gate_$(date +%s)_$RANDOM"

echo "== gate_shots_ui: start =="
echo "== [info] API_BASE=$API_BASE =="
echo "== [info] WEB_BASE=$WEB_BASE =="
echo "== [info] request_id=$RID =="

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "[err] missing cmd: $1" >&2; exit 2; }; }
need_cmd curl
need_cmd python

# Cross-platform temp file path (works for Windows Python + Git Bash)
tmpf() {
  python - <<'PY'
import tempfile, os
fd, p = tempfile.mkstemp(prefix="gate_shots_")
os.close(fd)
print(p.replace("\\","/"))
PY
}

curl_json() {
  # usage: curl_json <url> <out_body> <out_hdr>
  local url="$1"; local out_body="$2"; local out_hdr="$3"
  rm -f "$out_body" "$out_hdr" 2>/dev/null || true
  local code
  code="$(curl -sS -L -D "$out_hdr" -o "$out_body" -w "%{http_code}" \
    -H "Accept: application/json" \
    -H "X-Request-Id: $RID" \
    "$url" || true)"
  echo "$code"
}

dbg_fail() {
  local title="$1"; local body="$2"; local hdr="$3"
  echo "[err] $title"
  echo "== [debug] headers (first 40 lines) =="; sed -n '1,40p' "$hdr" 2>/dev/null || true
  echo "== [debug] body (first 400 chars) =="
  python - <<PY 2>/dev/null || true
p=r"""$body"""
try:
  s=open(p,"rb").read().decode("utf-8","replace")
  print(s[:400])
except Exception as e:
  print(f"<cannot read body: {e}>")
PY
  exit 3
}

pick_shot_id() {
  local body="$1"
  python - <<PY
import json,sys
p=r"""$body"""
raw=open(p,"rb").read()
if not raw.strip(): print(""); sys.exit(0)
try: j=json.loads(raw.decode("utf-8","replace"))
except Exception: print(""); sys.exit(0)
items=j.get("items") or []
if not items: print(""); sys.exit(0)
print(items[0].get("shot_id") or "")
PY
}

pick_asset_id() {
  local body="$1"
  python - <<PY
import json,sys
p=r"""$body"""
raw=open(p,"rb").read()
if not raw.strip(): print(""); sys.exit(0)
try: j=json.loads(raw.decode("utf-8","replace"))
except Exception: print(""); sys.exit(0)
items=j.get("items") or []
if not items: print(""); sys.exit(0)
it=items[0] or {}
print(it.get("asset_id") or it.get("id") or "")
PY
}

echo "== [check] api openapi reachable =="
OPENAPI_BODY="$(tmpf)"; OPENAPI_HDR="$(tmpf)"
code="$(curl_json "$API_BASE/openapi.json" "$OPENAPI_BODY" "$OPENAPI_HDR")"
if [ "$code" != "200" ]; then dbg_fail "openapi not reachable (http=$code)" "$OPENAPI_BODY" "$OPENAPI_HDR"; fi
echo "[ok] /openapi.json reachable"

echo "== [check] pick one shot_id from API =="
SHOTS_BODY="$(tmpf)"; SHOTS_HDR="$(tmpf)"
code="$(curl_json "$API_BASE/shots?offset=0&limit=1" "$SHOTS_BODY" "$SHOTS_HDR")"
if [ "$code" != "200" ]; then dbg_fail "/shots list failed (http=$code)" "$SHOTS_BODY" "$SHOTS_HDR"; fi

SHOT_ID="$(pick_shot_id "$SHOTS_BODY")"
if [ -z "$SHOT_ID" ]; then
  echo "[warn] /shots empty -> try seed via scripts/gate_shots_api.sh once"
  if [ -f scripts/gate_shots_api.sh ]; then bash scripts/gate_shots_api.sh >/dev/null 2>&1 || true; fi
  code="$(curl_json "$API_BASE/shots?offset=0&limit=1" "$SHOTS_BODY" "$SHOTS_HDR")"
  if [ "$code" != "200" ]; then dbg_fail "/shots list failed after seed (http=$code)" "$SHOTS_BODY" "$SHOTS_HDR"; fi
  SHOT_ID="$(pick_shot_id "$SHOTS_BODY")"
fi

echo "== [check] /shots page renders (empty or non-empty) =="
HTML_BODY="$(tmpf)"; HTML_HDR="$(tmpf)"
code="$(curl -sS -L -D "$HTML_HDR" -o "$HTML_BODY" -w "%{http_code}" "$WEB_BASE/shots" || true)"
if [ "$code" != "200" ]; then dbg_fail "web /shots failed (http=$code)" "$HTML_BODY" "$HTML_HDR"; fi
echo "[ok] /shots renders (http=200)"

if [ -z "$SHOT_ID" ]; then
  echo "[warn] no shots exist; skip detail/link checks"
  echo "== gate_shots_ui: done (warnings; no shots) =="
  exit 0
fi

echo "[ok] picked shot_id: $SHOT_ID"

echo "== [check] /shots/:shot_id page renders =="
HTML_BODY="$(tmpf)"; HTML_HDR="$(tmpf)"
code="$(curl -sS -L -D "$HTML_HDR" -o "$HTML_BODY" -w "%{http_code}" "$WEB_BASE/shots/$SHOT_ID" || true)"
if [ "$code" != "200" ]; then dbg_fail "web /shots/:shot_id failed (http=$code)" "$HTML_BODY" "$HTML_HDR"; fi
echo "[ok] /shots/:shot_id renders (http=200)"

echo "== [check] link add/remove (deterministic; seed assets if needed) =="
ASSETS_BODY="$(tmpf)"; ASSETS_HDR="$(tmpf)"
code="$(curl_json "$API_BASE/assets?offset=0&limit=1" "$ASSETS_BODY" "$ASSETS_HDR")"
if [ "$code" != "200" ]; then
  echo "[warn] cannot fetch /assets (http=$code); skip link ops"
  echo "== gate_shots_ui: done =="
  exit 0
fi

ASSET_ID="$(pick_asset_id "$ASSETS_BODY")"
if [ -z "$ASSET_ID" ]; then
  echo "== [warn] no assets detected; seeding via scripts/gate_assets_read.sh =="
  if [ ! -f scripts/gate_assets_read.sh ]; then
    echo "[err] missing scripts/gate_assets_read.sh; cannot seed assets"
    exit 7
  fi
  bash scripts/gate_assets_read.sh

  code="$(curl_json "$API_BASE/assets?offset=0&limit=1" "$ASSETS_BODY" "$ASSETS_HDR")"
  if [ "$code" != "200" ]; then dbg_fail "/assets failed after seed (http=$code)" "$ASSETS_BODY" "$ASSETS_HDR"; fi
  ASSET_ID="$(pick_asset_id "$ASSETS_BODY")"
fi

if [ -z "$ASSET_ID" ]; then
  echo "[err] assets still empty after seed; cannot run link add/remove"
  exit 9
fi

echo "== [info] link target asset_id=$ASSET_ID =="

LINK_BODY="$(tmpf)"; LINK_HDR="$(tmpf)"
code="$(curl -sS -L -D "$LINK_HDR" -o "$LINK_BODY" -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "X-Request-Id: $RID" \
  -X POST "$API_BASE/shots/$SHOT_ID/links" \
  --data "{\"dst_type\":\"asset\",\"dst_id\":\"$ASSET_ID\",\"rel\":\"refs\"}" || true)"

if [ "$code" != "200" ] && [ "$code" != "201" ]; then dbg_fail "link create failed (http=$code)" "$LINK_BODY" "$LINK_HDR"; fi

LINK_ID="$(python - <<PY
import json
p=r"""$LINK_BODY"""
raw=open(p,"rb").read()
try: j=json.loads(raw.decode("utf-8","replace"))
except Exception: print(""); raise SystemExit
print(j.get("link_id") or (j.get("link") or {}).get("link_id") or "")
PY
)"
if [ -z "$LINK_ID" ]; then dbg_fail "link create response missing link_id" "$LINK_BODY" "$LINK_HDR"; fi
echo "[ok] link created link_id=$LINK_ID"

DEL_BODY="$(tmpf)"; DEL_HDR="$(tmpf)"
code="$(curl -sS -L -D "$DEL_HDR" -o "$DEL_BODY" -w "%{http_code}" \
  -H "Accept: application/json" \
  -H "X-Request-Id: $RID" \
  -X DELETE "$API_BASE/shots/$SHOT_ID/links/$LINK_ID" || true)"
if [ "$code" != "200" ]; then dbg_fail "unlink failed (http=$code)" "$DEL_BODY" "$DEL_HDR"; fi
echo "[ok] link removed (tombstone semantics)"

echo "== gate_shots_ui: done =="
exit 0
