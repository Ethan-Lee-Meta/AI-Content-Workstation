#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
cd "$ROOT"

echo "== gate_ac_001: start =="
mkdir -p tmp

API="http://127.0.0.1:7000"
RID="gate-ac-001-$(date +%s)"

echo "== [info] check api reachable =="
code="$(curl -s -o /dev/null -w "%{http_code}" "$API/openapi.json" || true)"
if [ "$code" != "200" ]; then
  echo "[err] api not reachable at $API (openapi http_code=$code)" >&2
  exit 2
fi
echo "[ok] api reachable: /openapi.json"

echo "== [info] validate /assets response shape (items + page) =="
ASSETS_BODY="tmp/gate_ac_001.assets.body.json"
ASSETS_HDR="tmp/gate_ac_001.assets.headers.txt"
: > "$ASSETS_BODY"
: > "$ASSETS_HDR"

code="$(curl -sS -D "$ASSETS_HDR" -o "$ASSETS_BODY" -w "%{http_code}" \
  -H "X-Request-Id: $RID" \
  "$API/assets?limit=5&offset=0" || true)"

if [ "$code" != "200" ]; then
  echo "[err] GET /assets failed http_code=$code" >&2
  tail -n 80 "$ASSETS_HDR" >&2 || true
  tail -n 200 "$ASSETS_BODY" >&2 || true
  exit 3
fi

node - <<'NODE'
const fs = require("fs");
const j = JSON.parse(fs.readFileSync("tmp/gate_ac_001.assets.body.json","utf8"));
if (!j || typeof j !== "object") throw new Error("response not an object");
if (!("items" in j)) throw new Error("missing key: items");
if (!("page" in j)) throw new Error("missing key: page");
const page = j.page;
for (const k of ["limit","offset","total","has_more"]) {
  if (!(k in page)) throw new Error("page missing key: " + k);
}
if (!Array.isArray(j.items)) throw new Error("items is not array");
console.log("[ok] /assets returns items[] + page{limit,offset,total,has_more}");
NODE

echo "== [info] web routes accessible (includes /library & /assets/:id) =="
bash scripts/gate_web_routes.sh

echo "== [info] verify required page sections markers in source (stable gate) =="
grep -q 'data-testid="filters-bar"' "apps/web/app/library/LibraryClient.js" || { echo "[err] missing FiltersBar marker in LibraryClient.js" >&2; exit 5; }
grep -q 'data-testid="asset-grid"' "apps/web/app/library/LibraryClient.js" || { echo "[err] missing AssetGrid marker in LibraryClient.js" >&2; exit 6; }
grep -q 'data-testid="bulk-action-bar"' "apps/web/app/library/LibraryClient.js" || { echo "[err] missing BulkActionBar marker in LibraryClient.js" >&2; exit 7; }

echo "[ok] /library source contains required sections markers (FiltersBar/AssetGrid/BulkActionBar)"
echo "== gate_ac_001: passed =="
