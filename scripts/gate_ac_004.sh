#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
mkdir -p tmp

API="${API_BASE:-http://127.0.0.1:7000}"

echo "== gate_ac_004: start =="

echo "== [info] check api reachable =="
code="$(curl -s -o /dev/null -w "%{http_code}" "$API/openapi.json" || true)"
[ "$code" = "200" ] || { echo "[err] api not reachable (http_code=$code)"; exit 2; }
echo "[ok] api reachable: /openapi.json"

echo "== [info] validate override without reason -> error envelope includes request_id =="
python - <<'PY'
import json, urllib.request, urllib.error, uuid

API="http://127.0.0.1:7000"

def req(method, path, payload=None):
  url = API + path
  headers = {"Accept":"application/json", "X-Request-Id": str(uuid.uuid4())}
  data = None
  if payload is not None:
    data = json.dumps(payload).encode("utf-8")
    headers["Content-Type"]="application/json"
  r = urllib.request.Request(url, data=data, headers=headers, method=method)
  try:
    with urllib.request.urlopen(r, timeout=15) as resp:
      return resp.status, resp.read().decode("utf-8","replace")
  except urllib.error.HTTPError as e:
    return e.code, e.read().decode("utf-8","replace")

def safej(txt):
  try: return json.loads(txt)
  except: return None

# pick any asset_id
st, txt = req("GET", "/assets?limit=1&offset=0")
if st != 200:
  raise SystemExit("[err] cannot list assets to pick asset_id")
j = safej(txt) or {}
items = j.get("items") or []
if not items:
  raise SystemExit("[err] no assets found; cannot test reviews")
asset_id = items[0].get("id") or items[0].get("asset_id")
if not asset_id:
  raise SystemExit("[err] cannot extract asset_id from /assets item")

# create a minimal manual review (best-effort)
manual = {"asset_id": asset_id, "kind": "manual", "score": 0.9, "verdict": "pass", "reasons": ["ok"], "reason": "ok"}
st1, txt1 = req("POST", "/reviews", manual)
if st1 < 200 or st1 >= 300:
  # still acceptable if backend requires different fields; but AC-004 mainly needs override validation.
  # We'll continue with override path.
  pass
else:
  print("[ok] create review (manual)")

# override without reason: reason empty should error envelope
override = dict(manual)
override["kind"] = "override"
override["reason"] = ""  # intentionally empty
st2, txt2 = req("POST", "/reviews", override)
if 200 <= st2 < 300:
  raise SystemExit("[err] override without reason unexpectedly succeeded")

j2 = safej(txt2) or {}
need = ["error","message","request_id","details"]
missing = [k for k in need if k not in j2]
if missing:
  raise SystemExit(f"[err] missing keys in error envelope: {missing}")

rid = j2.get("request_id")
if not rid:
  raise SystemExit("[err] request_id missing/empty in error envelope")

print(f"[ok] override missing reason rejected; error envelope ok; request_id={rid}")
PY

echo "== [info] web routes accessible (baseline) =="
bash scripts/gate_web_routes.sh

echo "== [info] verify Review UI markers in source (stable gate) =="
SRC1="apps/web/app/assets/[asset_id]/ReviewPanelClient.js"
SRC2="apps/web/app/assets/[asset_id]/AssetDetailClient.js"
test -f "$SRC1" || { echo "[err] missing $SRC1"; exit 3; }
test -f "$SRC2" || { echo "[err] missing $SRC2"; exit 4; }

grep -q "ReviewPanel" "$SRC1" || { echo "[err] missing ReviewPanel marker"; exit 5; }
grep -q "override" "$SRC1" || { echo "[err] missing override marker"; exit 6; }
grep -q "request_id" "$SRC1" || { echo "[err] missing request_id marker"; exit 7; }
grep -q "ReviewPanelClient" "$SRC2" || { echo "[err] ReviewPanelClient not wired in AssetDetailClient"; exit 8; }

echo "[ok] Review UI markers present and wired"
echo "== gate_ac_004: passed =="
