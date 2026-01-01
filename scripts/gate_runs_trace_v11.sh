#!/usr/bin/env bash
set +e

echo "== gate_runs_trace_v11: start =="
API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"
TMPDIR="${TMPDIR:-/tmp}"

echo "== [info] API_BASE_URL=$API_BASE_URL =="
echo "== [info] TMPDIR=$TMPDIR =="

python - <<'PY'
import json, os
from urllib.request import Request, urlopen
from urllib.error import HTTPError

API = os.environ.get("API_BASE_URL","http://127.0.0.1:7000").rstrip("/")

def http(method, path, body=None, headers=None):
    url = API + path
    h = {"Content-Type":"application/json"}
    if headers:
        h.update(headers)
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    req = Request(url, data=data, headers=h, method=method)
    try:
        with urlopen(req, timeout=25) as r:
            b = r.read().decode("utf-8")
            return r.status, (json.loads(b) if b else {})
    except HTTPError as e:
        b = e.read().decode("utf-8")
        try:
            return e.code, (json.loads(b) if b else {})
        except Exception:
            return e.code, {"raw": b}

def items_of(body):
    if isinstance(body, list):
        return body
    if isinstance(body, dict) and isinstance(body.get("items"), list):
        return body["items"]
    return None

# 0) openapi
st,_ = http("GET","/openapi.json")
assert st==200, f"[err] openapi not reachable st={st}"
print("[ok] openapi reachable")

# 1) assets >=8
st, lst = http("GET","/assets?limit=50&offset=0")
assert st==200, f"[err] list assets st={st} body={lst}"
assert isinstance(lst, dict) and isinstance(lst.get("items"), list), f"[err] assets list shape mismatch: {lst}"
items = lst["items"]
assert len(items) >= 8, f"[err] need >=8 assets, got={len(items)}"
asset_ids = [a["id"] for a in items[:8]]
print("[ok] picked assets>=8 for refs")

# 2) provider profile: ensure usable one (prefer global default; else create; else use override)
st, pps_body = http("GET","/provider_profiles?limit=50&offset=0")
assert st==200, f"[err] GET /provider_profiles st={st} body={pps_body}"
pps = items_of(pps_body)
assert pps is not None, f"[err] provider_profiles list shape mismatch: {pps_body}"

def is_scrubbed(pp):
    name = (pp.get("name") or "")
    return isinstance(name, str) and name.startswith("(scrubbed)")

default_id = None
usable_any = None
for r in pps:
    if is_scrubbed(r):
        continue
    usable_any = usable_any or r.get("id")
    if r.get("is_global_default") in (True, 1):
        default_id = r.get("id")
        break

created_id = None
if not default_id and not usable_any:
    # create a usable profile (try set global default on create; if rejected, still usable via override)
    payload = {
        "name": "gate_default_mock",
        "provider_type": "mock",
        "config": {},
        "secrets_redaction_policy": {},
        "is_global_default": True,
    }
    st, cr = http("POST","/provider_profiles", payload)
    if st != 200:
        payload.pop("is_global_default", None)
        st, cr = http("POST","/provider_profiles", payload)
    assert st==200 and cr.get("id"), f"[err] create provider_profile st={st} body={cr}"
    created_id = cr["id"]
    print("[ok] created provider_profile", created_id)

    # re-fetch and try detect default again
    st, pps_body2 = http("GET","/provider_profiles?limit=50&offset=0")
    assert st==200, f"[err] re-GET /provider_profiles st={st} body={pps_body2}"
    pps2 = items_of(pps_body2)
    for r in pps2:
        if is_scrubbed(r):
            continue
        usable_any = usable_any or r.get("id")
        if r.get("is_global_default") in (True, 1):
            default_id = r.get("id")
            break

# If still no default, we will use override_provider_profile_id for run create (gate still passes)
print("[info] provider_profile default_id=", default_id, "usable_any=", usable_any, "created_id=", created_id)

# 3) create character
st, c = http("POST","/characters", {"name":"gate_char_v11","tags":{},"meta":{}})
assert st==200 and c.get("id"), f"[err] create character st={st} body={c}"
cid = c["id"]
print("[ok] created character", cid)

# 4) create draft ref_set
st, rs = http("POST", f"/characters/{cid}/ref_sets", {"status":"draft"})
assert st==200 and rs.get("id"), f"[err] create draft ref_set st={st} body={rs}"
draft_id = rs["id"]
print("[ok] created draft ref_set", draft_id)

# 5) add 8 refs
for aid in asset_ids[:8]:
    st, _ = http("POST", f"/characters/{cid}/ref_sets/{draft_id}/refs", {"asset_id": aid})
    assert st==200, f"[err] add ref failed st={st} asset={aid}"
print("[ok] added 8 refs")

# 6) confirm ref_set (copy-from-draft)
st, rs2 = http("POST", f"/characters/{cid}/ref_sets", {"status":"confirmed","base_ref_set_id": draft_id})
assert st==200 and rs2.get("id"), f"[err] confirm ref_set st={st} body={rs2}"
conf_id = rs2["id"]
print("[ok] created confirmed ref_set", conf_id)

# 7) set active + confirm character
st, _ = http("PATCH", f"/characters/{cid}", {"status":"confirmed","active_ref_set_id": conf_id})
assert st==200, f"[err] set active_ref_set_id st={st}"
print("[ok] set character active_ref_set_id")

# 8) prompt_pack lock: assembly_used=true but no assembly_prompt -> 422/400
bad = {
  "run_type":"t2i",
  "prompt_pack":{"raw_input":"x","final_prompt":"y","assembly_used": True}
}
st, _ = http("POST","/runs", bad, headers={"x-provider-enabled":"1"})
assert st in (400,422), f"[err] expected 400/422 for prompt_pack lock, got st={st}"
print("[ok] prompt_pack lock rejects invalid payload")

# 9) primary invariant: chars provided but no primary -> 400
bad2 = {
  "run_type":"t2i",
  "prompt_pack":{"raw_input":"x","final_prompt":"y","assembly_used": False},
  "characters":[{"character_id": cid, "is_primary": False}]
}
st, body = http("POST","/runs", bad2, headers={"x-provider-enabled":"1"})
assert st==400, f"[err] expected 400 for missing primary, got st={st} body={body}"
print("[ok] primary invariant enforced")

# 10) happy path run -> produced asset -> asset chain
good = {
  "run_type":"t2i",
  "prompt_pack":{"raw_input":"raw","final_prompt":"final","assembly_used": False},
  "characters":[{"character_id": cid, "is_primary": True}],
  "inputs":{"foo":"bar"},
}

# if no global default, force override (gate must be stable)
if not default_id:
    good["override_provider_profile_id"] = (created_id or usable_any)

st, out = http("POST","/runs", good, headers={"x-provider-enabled":"1"})
assert st==200 and out.get("run_id"), f"[err] create run st={st} body={out}"
run_id = out["run_id"]
print("[ok] POST /runs created", run_id)

st, r = http("GET", f"/runs/{run_id}")
assert st==200, f"[err] GET run st={st} body={r}"
rr = (r.get("result_refs") or {})
aids = rr.get("asset_ids") or []
assert aids and isinstance(aids, list), f"[err] expected asset_ids in result_refs; got {rr}"
asset_id = aids[0]
print("[ok] run produced asset", asset_id)

st, ad = http("GET", f"/assets/{asset_id}")
assert st==200 and "traceability" in ad, f"[err] asset detail st={st} body={ad}"
chain = (ad.get("traceability") or {}).get("chain") or {}
assert chain.get("run",{}).get("run_id") == run_id, f"[err] chain missing run_id; chain={chain}"
pp = chain.get("prompt_pack") or {}
assert pp.get("raw_input") == "raw" and pp.get("final_prompt") == "final", f"[err] prompt_pack chain mismatch: {pp}"
chars = chain.get("characters") or []
assert isinstance(chars, list) and len(chars)>=1, f"[err] characters chain missing: {chars}"
print("[ok] asset detail chain ok")

print("== gate_runs_trace_v11: PASS ==")
PY

rc=$?
if [ $rc -ne 0 ]; then
  echo "== gate_runs_trace_v11: FAIL rc=$rc =="
  exit $rc
fi
