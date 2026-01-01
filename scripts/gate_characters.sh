#!/usr/bin/env bash
set -euo pipefail

echo "== gate_characters: start =="
API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"
PY="${PY:-python}"
TMPDIR="${TMPDIR:-/tmp}"

echo "== [info] API_BASE_URL=$API_BASE_URL =="
echo "== [info] PY=$PY =="
echo "== [info] TMPDIR=$TMPDIR =="

# seed assets if possible (need >=8 assets to confirm)
if [ -f "scripts/gate_assets_read.sh" ]; then
  echo "== [info] try seed assets via gate_assets_read.sh (best effort) =="
  ( set +e; bash scripts/gate_assets_read.sh; true )
fi

"$PY" - <<'PY'
import json, sys, urllib.request, urllib.error

API = "http://127.0.0.1:7000"
try:
    import os
    API = os.environ.get("API_BASE_URL", API)
except Exception:
    pass

def req(method, path, body=None):
    url = API + path
    data = None
    headers = {"Content-Type": "application/json"}
    if body is not None:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r, timeout=10) as resp:
            raw = resp.read().decode("utf-8")
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8")
        try:
            j = json.loads(raw)
        except Exception:
            j = {"raw": raw}
        return e.code, j

# 1) list assets (need >=8)
st, j = req("GET", "/assets?limit=20&offset=0")
assert st == 200, (st, j)
assets = [it.get("id") for it in (j.get("items") or []) if it.get("id")]
assert len(assets) >= 8, f"need >=8 assets for confirm test; got={len(assets)}"

# 2) create character
st, c = req("POST", "/characters", {"name": "gate-character", "tags": {"k": "v"}, "meta": {"purpose": "gate"}})
assert st == 200, (st, c)
cid = c["id"]
print("[ok] created character", cid)

# 3) create draft ref_set
st, rs1 = req("POST", f"/characters/{cid}/ref_sets", {"status": "draft", "min_requirements_snapshot": {"min_refs": 8}})
assert st == 200, (st, rs1)
rs1_id = rs1["id"]
print("[ok] created draft ref_set", rs1_id, "ver", rs1["version"])

# 4) add 8 refs to draft
for a in assets[:8]:
    st, out = req("POST", f"/characters/{cid}/ref_sets/{rs1_id}/refs", {"asset_id": a})
    assert st == 200, (st, out)
print("[ok] added 8 refs to draft ref_set")

# 5) create confirmed ref_set from base (copy refs + set active_ref_set_id)
st, rs2 = req("POST", f"/characters/{cid}/ref_sets", {"status": "confirmed", "base_ref_set_id": rs1_id, "min_requirements_snapshot": {"min_refs": 8}})
assert st == 200, (st, rs2)
rs2_id = rs2["id"]
print("[ok] created confirmed ref_set", rs2_id, "ver", rs2["version"])

# 6) get character detail -> active_ref_set should match + refs_count==8
st, detail = req("GET", f"/characters/{cid}")
assert st == 200, (st, detail)
assert detail["character"]["active_ref_set_id"] == rs2_id, detail["character"]
assert detail["active_ref_set"]["refs_count"] == 8, detail["active_ref_set"]
print("[ok] character detail active_ref_set ok")

# 7) negative: cannot set active_ref_set_id to draft
st, bad = req("PATCH", f"/characters/{cid}", {"active_ref_set_id": rs1_id})
assert st in (400, 409), (st, bad)
print("[ok] reject draft active_ref_set_id")
PY

echo "== gate_characters: PASS =="
