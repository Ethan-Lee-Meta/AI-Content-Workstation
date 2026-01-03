#!/usr/bin/env bash
set -euo pipefail

echo "== gate_settings_ui: start =="

ROOT="$(git rev-parse --show-toplevel)"
API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"
WEB_BASE_URL="${WEB_BASE_URL:-http://127.0.0.1:2000}"

# Prefer venv python if present
PY="${PY:-$ROOT/apps/api/.venv/Scripts/python.exe}"
if [ ! -x "$PY" ]; then
  PY="python"
fi

# IMPORTANT: enforce repo-local tmp (./tmp), ignore external TMPDIR
TMPDIR="$ROOT/tmp/gate_settings_ui.$$"
mkdir -p "$TMPDIR"

echo "== [info] API_BASE_URL=$API_BASE_URL =="
echo "== [info] WEB_BASE_URL=$WEB_BASE_URL =="
echo "== [info] PY=$PY =="
echo "== [info] TMPDIR=$TMPDIR =="

echo "== [check] /settings route renders =="
code="$(curl -sS -o /dev/null -w "%{http_code}" "$WEB_BASE_URL/settings")"
if [ "$code" != "200" ]; then
  echo "[err] $WEB_BASE_URL/settings http=$code"
  exit 10
fi
echo "[ok] $WEB_BASE_URL/settings http=200"

echo "== [check] openapi reachable =="
curl -sS "$API_BASE_URL/openapi.json" -o "$TMPDIR/openapi.json"
echo "[ok] openapi reachable"

echo "== [step] GET /provider_types =="
curl -sS "$API_BASE_URL/provider_types" -o "$TMPDIR/provider_types.json"

read -r PT SK < <(
  TMPDIR="$TMPDIR" "$PY" - <<'PY'
import json, os
tmp=os.environ["TMPDIR"]
j=json.load(open(f"{tmp}/provider_types.json","r",encoding="utf-8"))
items=j.get("items") or []
pt=None
for it in items:
  if it.get("provider_type")=="mock":
    pt=it; break
if not pt and items:
  pt=items[0]
pt_name=(pt or {}).get("provider_type") or ""
h=(pt or {}).get("secrets_hints") or {}
sk=""
if isinstance(h, dict) and h:
  sk = "redact_keys_example" if "redact_keys_example" in h else list(h.keys())[0]
print(str(pt_name).strip(), str(sk).strip())
PY
)

PT="${PT//$'\r'/}"
SK="${SK//$'\r'/}"
if [ -z "${PT:-}" ] || [ -z "${SK:-}" ]; then
  echo "[err] cannot pick provider_type/secret_key from /provider_types"
  exit 12
fi
echo "[ok] picked provider_type=$PT secret_key=$SK"

echo "== [step] POST /provider_profiles (create) =="
NAME="gate-pp-$(date -u +%Y%m%d%H%M%S)"
DUMMY="dummy_secret_$(date -u +%s)"

PT="$PT" SK="$SK" NAME="$NAME" DUMMY="$DUMMY" TMPDIR="$TMPDIR" "$PY" - <<'PY'
import json, os
pt=os.environ["PT"]; sk=os.environ["SK"]; name=os.environ["NAME"]; dummy=os.environ["DUMMY"]
tmp=os.environ["TMPDIR"]
payload={
  "name": name,
  "provider_type": pt,
  "config": {},
  "secrets_json": { sk: dummy },
  "secrets_redaction_policy": {},
  "set_global_default": False
}
open(f"{tmp}/create.body.json","w",encoding="utf-8").write(json.dumps(payload, ensure_ascii=False))
PY

curl -sS -H "content-type: application/json" \
  -X POST "$API_BASE_URL/provider_profiles" \
  --data-binary @"$TMPDIR/create.body.json" \
  -o "$TMPDIR/create.resp.json"

PID="$(
  TMPDIR="$TMPDIR" "$PY" - <<'PY'
import json, os
tmp=os.environ["TMPDIR"]
j=json.load(open(f"{tmp}/create.resp.json","r",encoding="utf-8"))
print(j.get("id",""))
PY
)"

if [ -z "$PID" ]; then
  echo "[err] create provider_profile failed (missing id)"
  cat "$TMPDIR/create.resp.json" || true
  exit 13
fi
echo "[ok] created profile_id=$PID"

echo "== [step] GET /provider_profiles (list) ensure secret not echoed + configured true =="
curl -sS "$API_BASE_URL/provider_profiles?offset=0&limit=200" -o "$TMPDIR/list.json"

PID="$PID" SK="$SK" DUMMY="$DUMMY" TMPDIR="$TMPDIR" "$PY" - <<'PY'
import json, os, sys
pid=os.environ["PID"]; sk=os.environ["SK"]; dummy=os.environ["DUMMY"]; tmp=os.environ["TMPDIR"]
raw=open(f"{tmp}/list.json","r",encoding="utf-8").read()
if dummy in raw:
  print("[err] secret leaked in list response"); sys.exit(21)
j=json.loads(raw)
for it in (j.get("items") or []):
  if it.get("id")==pid:
    sc=it.get("secrets_configured")
    scj=it.get("secrets_configured_json") or {}
    if sc is not True:
      print("[err] secrets_configured not true:", sc); sys.exit(22)
    if scj.get(sk) is not True:
      print("[err] secrets_configured_json missing/false:", scj); sys.exit(23)
    print("[ok] list response does not contain dummy secret; configured=true; configured_json ok")
    break
else:
  print("[err] created profile not found in list"); sys.exit(24)
PY

echo "== [step] POST /provider_profiles/{id}/set_default =="
curl -sS -X POST "$API_BASE_URL/provider_profiles/$PID/set_default" -o "$TMPDIR/set_default.json" || true

echo "== [step] DELETE /provider_profiles/{id} =="
curl -sS -X DELETE "$API_BASE_URL/provider_profiles/$PID" -o "$TMPDIR/delete.json" || true

echo "== gate_settings_ui: done rc=0 =="
