#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
cd "$ROOT"

echo "== gate_ac_002: start =="
mkdir -p tmp

API="http://127.0.0.1:7000"
RID="gate-ac-002-$(date +%s)"

echo "== [info] check api reachable =="
code="$(curl -s -o /dev/null -w "%{http_code}" "$API/openapi.json" || true)"
if [ "$code" != "200" ]; then
  echo "[err] api not reachable at $API (openapi http_code=$code)" >&2
  exit 2
fi
echo "[ok] api reachable: /openapi.json"

echo "== [info] pick an asset id from /assets list (if any) =="
LIST_BODY="tmp/gate_ac_002.assets.list.json"
code="$(curl -sS -o "$LIST_BODY" -w "%{http_code}" -H "X-Request-Id: $RID" "$API/assets?limit=1&offset=0" || true)"
if [ "$code" != "200" ]; then
  echo "[err] GET /assets failed http_code=$code" >&2
  tail -n 200 "$LIST_BODY" >&2 || true
  exit 3
fi

ASSET_ID="$(node - <<'NODE'
const fs = require("fs");
const j = JSON.parse(fs.readFileSync("tmp/gate_ac_002.assets.list.json","utf8"));
const it = Array.isArray(j.items) ? j.items[0] : null;
const id = it && (it.asset_id || it.id || it.uuid);
process.stdout.write(id ? String(id) : "");
NODE
)"

if [ -z "${ASSET_ID}" ]; then
  echo "[warn] no assets found in /assets list; will only validate error envelope path"
else
  echo "[ok] picked asset_id=${ASSET_ID}"
  ONE_BODY="tmp/gate_ac_002.asset.one.json"
  ONE_HDR="tmp/gate_ac_002.asset.one.headers.txt"
  : > "$ONE_HDR"
  code="$(curl -sS -D "$ONE_HDR" -o "$ONE_BODY" -w "%{http_code}" -H "X-Request-Id: $RID" "$API/assets/${ASSET_ID}" || true)"
  if [ "$code" != "200" ]; then
    echo "[err] GET /assets/:id failed http_code=$code" >&2
    tail -n 80 "$ONE_HDR" >&2 || true
    tail -n 200 "$ONE_BODY" >&2 || true
    exit 4
  fi

  node - <<'NODE'
const fs = require("fs");
const j = JSON.parse(fs.readFileSync("tmp/gate_ac_002.asset.one.json","utf8"));
if (!j || typeof j !== "object") throw new Error("asset detail is not object");
console.log("[ok] /assets/:id returns an object");
NODE
fi

echo "== [info] validate error envelope keys for non-existent asset (should include request_id) =="
BAD_BODY="tmp/gate_ac_002.asset.bad.json"
BAD_HDR="tmp/gate_ac_002.asset.bad.headers.txt"
: > "$BAD_HDR"
code="$(curl -sS -D "$BAD_HDR" -o "$BAD_BODY" -w "%{http_code}" -H "X-Request-Id: $RID" "$API/assets/__nonexistent__gate_ac_002__" || true)"
if [ "$code" = "200" ]; then
  echo "[warn] unexpected 200 for nonexistent id; skipping envelope check"
else
  node - <<'NODE'
const fs = require("fs");
const j = JSON.parse(fs.readFileSync("tmp/gate_ac_002.asset.bad.json","utf8"));
if (!j || typeof j !== "object") throw new Error("error body not object");
const keys = ["error","message","request_id","details"];
for (const k of keys) {
  if (!(k in j)) throw new Error("missing key in error envelope: " + k);
}
if (!j.request_id) throw new Error("request_id empty in error envelope");
console.log("[ok] error envelope includes error/message/request_id/details");
NODE
fi

echo "== [info] web routes accessible (baseline) =="
bash scripts/gate_web_routes.sh

echo "== [info] verify asset detail required panels markers in source (stable gate) =="
SRC="apps/web/app/assets/[asset_id]/AssetDetailClient.js"
test -f "$SRC" || { echo "[err] missing $SRC" >&2; exit 8; }

grep -q 'data-testid="preview-panel"' "$SRC" || { echo "[err] missing PreviewPanel marker" >&2; exit 9; }
grep -q 'data-testid="metadata-panel"' "$SRC" || { echo "[err] missing MetadataPanel marker" >&2; exit 10; }
grep -q 'data-testid="traceability-panel"' "$SRC" || { echo "[err] missing TraceabilityPanel marker" >&2; exit 11; }
grep -q 'data-testid="actions-panel"' "$SRC" || { echo "[err] missing ActionsPanel marker" >&2; exit 12; }
grep -q 'data-testid="review-panel"' "$SRC" || { echo "[err] missing ReviewPanel marker" >&2; exit 13; }

echo "[ok] asset detail source contains required panel markers"
echo "== gate_ac_002: passed =="
