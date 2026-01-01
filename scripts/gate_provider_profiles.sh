#!/usr/bin/env bash
set +e

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
PY_CAND="$ROOT/apps/api/.venv/Scripts/python.exe"
PY="${PY:-}"
if [ -z "$PY" ]; then
  if [ -f "$PY_CAND" ]; then PY="$PY_CAND"; else PY="python"; fi
fi

TMPDIR="${TMPDIR:-$ROOT/tmp/gate_provider_profiles.$$}"
mkdir -p "$TMPDIR" >/dev/null 2>&1 || true

rc=0
echo "== gate_provider_profiles: start =="
echo "== [info] API_BASE_URL=$API_BASE_URL =="
echo "== [info] PY=$PY =="
echo "== [info] TMPDIR=$TMPDIR =="

curl -fsS "$API_BASE_URL/openapi.json" -o "$TMPDIR/openapi.json"
if [ $? -ne 0 ]; then
  echo "[err] openapi not reachable"
  rc=1
fi

# 1) provider_types items>=1
curl -fsS "$API_BASE_URL/provider_types" -o "$TMPDIR/provider_types.json"
if [ $? -ne 0 ]; then
  echo "[err] GET /provider_types failed"
  rc=1
else
  "$PY" - <<'PY' "$TMPDIR/provider_types.json" || exit 13
import json,sys
p=sys.argv[1]
j=json.load(open(p,"r",encoding="utf-8"))
items=j.get("items") or []
assert isinstance(items,list) and len(items)>=1
print("[ok] GET /provider_types returns items>=1")
PY
  if [ $? -ne 0 ]; then
    echo "[err] /provider_types schema check failed"
    rc=1
  fi
fi

# 2) create provider_profile with secret-like key; ensure not echoed
cat > "$TMPDIR/create.json" <<'JSON'
{
  "name": "pp-secret-test",
  "provider_type": "mock",
  "config": { "api_key": "SECRET_VALUE_SHOULD_NOT_ECHO", "endpoint": "http://example.invalid" },
  "secrets_redaction_policy": { "redact_keys": ["api_key"] },
  "set_global_default": true
}
JSON

curl -fsS -X POST "$API_BASE_URL/provider_profiles" -H "content-type: application/json" --data-binary @"$TMPDIR/create.json" -o "$TMPDIR/created.json" -D "$TMPDIR/created.headers"
if [ $? -ne 0 ]; then
  echo "[err] POST /provider_profiles failed"
  rc=1
else
  "$PY" - <<'PY' "$TMPDIR/created.json" || exit 13
import json,sys
j=json.load(open(sys.argv[1],"r",encoding="utf-8"))
pid=j["id"]
cfg=j.get("config") or {}
assert cfg.get("api_key") != "SECRET_VALUE_SHOULD_NOT_ECHO"
assert cfg.get("api_key") == "<redacted>"
assert j.get("is_global_default") in (True, False)  # bool
print(f"[ok] POST /provider_profiles created; secret not echoed; id={pid}")
PY
  if [ $? -ne 0 ]; then
    echo "[err] create response redaction check failed"
    rc=1
  fi
fi

# 3) list redaction ok
curl -fsS "$API_BASE_URL/provider_profiles?limit=50&offset=0" -o "$TMPDIR/list.json"
if [ $? -ne 0 ]; then
  echo "[err] GET /provider_profiles failed"
  rc=1
else
  "$PY" - <<'PY' "$TMPDIR/list.json" || exit 13
import json,sys
j=json.load(open(sys.argv[1],"r",encoding="utf-8"))
items=j.get("items") or []
assert isinstance(items,list)
for it in items:
  cfg=(it.get("config") or {})
  if "api_key" in cfg:
    assert cfg["api_key"] != "SECRET_VALUE_SHOULD_NOT_ECHO"
print("[ok] GET /provider_profiles redaction ok (no secrets)")
PY
  if [ $? -ne 0 ]; then
    echo "[err] list redaction check failed"
    rc=1
  fi
fi

# 4) delete scrub ok (idempotent shape)
PID="$("$PY" - <<'PY' "$TMPDIR/created.json"
import json,sys
print(json.load(open(sys.argv[1],"r",encoding="utf-8"))["id"])
PY
)"
if [ -n "$PID" ]; then
  curl -fsS -X DELETE "$API_BASE_URL/provider_profiles/$PID" -o "$TMPDIR/deleted.json"
  if [ $? -ne 0 ]; then
    echo "[err] DELETE /provider_profiles/{id} failed"
    rc=1
  else
    curl -fsS "$API_BASE_URL/provider_profiles/$PID" -o "$TMPDIR/get_after_delete.json"
    "$PY" - <<'PY' "$TMPDIR/get_after_delete.json" || exit 13
import json,sys
j=json.load(open(sys.argv[1],"r",encoding="utf-8"))
cfg=j.get("config") or {}
assert cfg.get("api_key") in (None, "<redacted>")
assert j.get("is_global_default") is False
print("[ok] delete scrub ok (config cleared; no default)")
PY
    if [ $? -ne 0 ]; then
      echo "[err] scrub verification failed"
      rc=1
    fi
  fi
fi

if [ $rc -eq 0 ]; then
  echo "== gate_provider_profiles: PASS =="
else
  echo "== gate_provider_profiles: FAIL rc=$rc =="
fi
exit $rc
