#!/usr/bin/env bash
set +e

echo "== gate_settings_ui: start =="

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"
WEB_BASE_URL="${WEB_BASE_URL:-http://127.0.0.1:2000}"

# Prefer venv python if available
if [ -z "${PY:-}" ]; then
  if [ -x "apps/api/.venv/Scripts/python.exe" ]; then
    PY="$(pwd)/apps/api/.venv/Scripts/python.exe"
  elif [ -x "apps/api/.venv/bin/python" ]; then
    PY="$(pwd)/apps/api/.venv/bin/python"
  else
    PY="python"
  fi
fi

# Make TMPDIR always be a unique directory (even if env TMPDIR=/tmp)
TMPROOT="${TMPDIR:-$(pwd)/tmp}"
TMPDIR="$TMPROOT/gate_settings_ui.$$"
mkdir -p "$TMPDIR"

echo "== [info] API_BASE_URL=$API_BASE_URL =="
echo "== [info] WEB_BASE_URL=$WEB_BASE_URL =="
echo "== [info] PY=$PY =="
echo "== [info] TMPDIR=$TMPDIR =="

rc=0

echo "== [check] /settings route renders =="
http_code="$(curl -sS -o "$TMPDIR/settings.html" -w "%{http_code}" "$WEB_BASE_URL/settings")"
if [ "$http_code" = "200" ]; then
  echo "[ok] /settings http=200"
else
  echo "[err] /settings http=$http_code"
  rc=10
fi

echo "== [check] openapi reachable =="
curl -sS "$API_BASE_URL/openapi.json" > "$TMPDIR/openapi.json"
if [ $? -ne 0 ] || [ ! -s "$TMPDIR/openapi.json" ]; then
  echo "[warn] openapi not reachable; skipping provider API checks (UI should degrade gracefully)"
  exit $rc
fi
echo "[ok] openapi reachable"

grep -q '"/provider_types"' "$TMPDIR/openapi.json"; HAS_PT=$?
grep -q '"/provider_profiles"' "$TMPDIR/openapi.json"; HAS_PP=$?
if [ $HAS_PT -ne 0 ] || [ $HAS_PP -ne 0 ]; then
  echo "[warn] provider endpoints missing in openapi; skipping provider API checks (UI should degrade gracefully)"
  exit $rc
fi

echo "== [step] GET /provider_types =="
curl -sS "$API_BASE_URL/provider_types" > "$TMPDIR/provider_types.json"
if [ $? -ne 0 ] || [ ! -s "$TMPDIR/provider_types.json" ]; then
  echo "[err] GET /provider_types failed"
  rc=11
  exit $rc
fi

# Correct heredoc argv passing: python - <file> <<'PY' ... PY
read -r PT SK <<<"$("$PY" - "$TMPDIR/provider_types.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1],"r",encoding="utf-8"))
items=p.get("items") or []
pt=None
for it in items:
  if it.get("provider_type")=="mock":
    pt=it; break
if not pt and items:
  pt=items[0]
pt_name=(pt or {}).get("provider_type") or ""
secrets=(pt or {}).get("secrets_hints") or {}
sk=""
if isinstance(secrets,dict) and secrets:
  sk=next(iter(secrets.keys()))
print(pt_name, sk)
PY
)"

if [ -z "$PT" ]; then
  echo "[err] cannot pick provider_type from /provider_types"
  rc=12
  exit $rc
fi
echo "[ok] picked provider_type=$PT secret_key=${SK:-"(none)"}"

NAME="gate-profile-$(date -u +%Y%m%d%H%M%S)"
DUMMY_SECRET="gate_dummy_secret_$(date -u +%s)"

echo "== [step] POST /provider_profiles (create) =="
PT="$PT" NAME="$NAME" SK="$SK" DUMMY_SECRET="$DUMMY_SECRET" "$PY" - <<'PY' > "$TMPDIR/create.body.json"
import json,os
pt=os.environ["PT"]
name=os.environ["NAME"]
sk=os.environ.get("SK","")
dummy=os.environ.get("DUMMY_SECRET","")
payload={"name":name,"provider_type":pt,"config_json":{}}
if sk:
  payload["secrets_json"]={sk:dummy}
print(json.dumps(payload))
PY

curl -sS -D "$TMPDIR/create.headers.txt" -o "$TMPDIR/create.json" \
  -H "content-type: application/json" \
  -X POST "$API_BASE_URL/provider_profiles" \
  --data-binary @"$TMPDIR/create.body.json"

PROFILE_ID="$("$PY" - "$TMPDIR/create.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1],"r",encoding="utf-8"))
print(j.get("id") or "")
PY
)"
if [ -z "$PROFILE_ID" ]; then
  echo "[err] create provider_profile failed (missing id)"
  echo "body=$(cat "$TMPDIR/create.json")"
  rc=13
  exit $rc
fi
echo "[ok] created profile_id=$PROFILE_ID"

echo "== [step] GET /provider_profiles (list) ensure secret not echoed =="
curl -sS "$API_BASE_URL/provider_profiles?offset=0&limit=50" > "$TMPDIR/list.json"
if grep -q "$DUMMY_SECRET" "$TMPDIR/list.json"; then
  echo "[err] secret value was echoed in list response (should be masked)"
  rc=14
else
  echo "[ok] list response does not contain dummy secret"
fi

echo "== [step] POST /provider_profiles/{id}/set_default =="
curl -sS -D "$TMPDIR/setdef.headers.txt" -o "$TMPDIR/setdef.json" \
  -H "content-type: application/json" \
  -X POST "$API_BASE_URL/provider_profiles/$PROFILE_ID/set_default"
if [ $? -ne 0 ]; then
  echo "[err] set_default failed"
  rc=15
fi

echo "== [step] DELETE /provider_profiles/{id} =="
curl -sS -D "$TMPDIR/del.headers.txt" -o "$TMPDIR/del.json" \
  -X DELETE "$API_BASE_URL/provider_profiles/$PROFILE_ID"
if [ $? -ne 0 ]; then
  echo "[err] delete failed"
  rc=16
fi

echo "== gate_settings_ui: done rc=$rc =="
exit $rc
