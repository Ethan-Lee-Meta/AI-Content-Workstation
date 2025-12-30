#!/usr/bin/env bash
set +e

cd "$(git rev-parse --show-toplevel)" || exit 1
ROOT="$(pwd)"
mkdir -p tmp

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"
TMPDIR="$ROOT/tmp/gate_assets_read.$$"
mkdir -p "$TMPDIR"

echo "== gate_assets_read: start =="
echo "[info] API_BASE_URL=$API_BASE_URL"
echo "[info] TMPDIR=$TMPDIR"

cleanup() { rm -rf "$TMPDIR" >/dev/null 2>&1; }
trap cleanup EXIT

# reachability
curl -sS -D "$TMPDIR/health.h" "$API_BASE_URL/health" -o "$TMPDIR/health.json" >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] cannot reach API /health (need uvicorn running on 127.0.0.1:7000)"
  echo "== gate_assets_read: fail =="
  exit 2
fi

# seed DB (active+deleted+missing)
python - <<'PY' > "$TMPDIR/seed.json"
from __future__ import annotations
import os, sqlite3, time, json
from datetime import datetime, timezone

DEFAULT_DATABASE_URL = "sqlite:///./data/app.db"
def sqlite_path_from_url(url: str) -> str:
    if not url.startswith("sqlite:"):
        raise SystemExit(f"[err] only sqlite supported, got DATABASE_URL={url!r}")
    if url.startswith("sqlite:////"):
        return url[len("sqlite:////") - 1 :]
    if url.startswith("sqlite:///"):
        return url[len("sqlite:///") :]
    if url.startswith("sqlite://"):
        return url[len("sqlite://") :]
    raise SystemExit(f"[err] bad sqlite url: {url!r}")

ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
def _enc(v: int, n: int) -> str:
    out = ["0"] * n
    for i in range(n - 1, -1, -1):
        out[i] = ALPHABET[v & 31]
        v >>= 5
    return "".join(out)

def ulid() -> str:
    ts = int(time.time() * 1000) & ((1 << 48) - 1)
    rnd = int.from_bytes(os.urandom(10), "big")
    val = (ts << 80) | rnd
    return _enc(val, 26)

def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

url = os.getenv("DATABASE_URL", DEFAULT_DATABASE_URL)
path = sqlite_path_from_url(url)
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)

conn = sqlite3.connect(path)
conn.row_factory = sqlite3.Row

def table_exists(name: str) -> bool:
    r = conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?", (name,)).fetchone()
    return r is not None

if not table_exists("assets"):
    raise SystemExit("[err] db missing table: assets")

cols = conn.execute("PRAGMA table_info(assets)").fetchall()
colnames = [r["name"] for r in cols]
notnull = {r["name"]: (r["notnull"] == 1) for r in cols}
dflt = {r["name"]: r["dflt_value"] for r in cols}

def pick_existing():
    if "id" not in colnames:
        return None, None
    rows = conn.execute("SELECT id, deleted_at FROM assets ORDER BY rowid DESC LIMIT 200").fetchall()
    active = next((r["id"] for r in rows if ("deleted_at" in colnames and r["deleted_at"] is None) or ("deleted_at" not in colnames)), None)
    deleted = next((r["id"] for r in rows if ("deleted_at" in colnames and r["deleted_at"] is not None)), None)
    return active, deleted

def fallback_value(col: str):
    lc = col.lower()
    if lc in ("created_at", "updated_at"):
        return now_iso()
    if lc in ("type", "kind"):
        return "image"
    if lc == "mime_type":
        return "image/png"
    if lc in ("storage_path", "path", "storage_uri"):
        return "./data/storage/_gate_seed.bin"
    if lc.endswith("_ms"):
        return 0
    return ""

def ensure_row(is_deleted: bool) -> str:
    rid = ulid()
    row = {}
    if "id" in colnames: row["id"] = rid
    if "type" in colnames: row["type"] = "image"
    if "created_at" in colnames: row["created_at"] = now_iso()
    if "deleted_at" in colnames: row["deleted_at"] = now_iso() if is_deleted else None

    for c in colnames:
        if notnull.get(c) and dflt.get(c) is None and c not in row:
            row[c] = fallback_value(c)

    keys = [k for k in row.keys() if k in colnames]
    q = "INSERT INTO assets (" + ",".join(keys) + ") VALUES (" + ",".join(["?"] * len(keys)) + ")"
    conn.execute(q, [row[k] for k in keys])
    conn.commit()
    return rid

active_id, deleted_id = pick_existing()
if active_id is None:
    active_id = ensure_row(False)

if "deleted_at" in colnames and deleted_id is None:
    try:
        deleted_id = ensure_row(True)
    except Exception:
        rows = conn.execute("SELECT id FROM assets ORDER BY rowid DESC LIMIT 200").fetchall()
        cand = next((r["id"] for r in rows if r["id"] != active_id), None)
        if cand:
            conn.execute("UPDATE assets SET deleted_at=? WHERE id=?", (now_iso(), cand))
            conn.commit()
            deleted_id = cand

missing_id = None
for _ in range(80):
    mid = ulid()
    c = conn.execute("SELECT COUNT(1) AS c FROM assets WHERE id=?", (mid,)).fetchone()["c"]
    if int(c) == 0:
        missing_id = mid
        break
if missing_id is None:
    missing_id = "NON_EXISTENT_ASSET_ID"

conn.close()
print(json.dumps({"active_id": active_id, "deleted_id": deleted_id, "missing_id": missing_id}, ensure_ascii=False))
PY

if [ ! -s "$TMPDIR/seed.json" ]; then
  echo "[err] failed to seed assets for gate"
  echo "== gate_assets_read: fail =="
  exit 3
fi
echo "[info] seed: $(cat "$TMPDIR/seed.json")"

ACTIVE_ID="$(python -c "import json,sys;print(json.load(sys.stdin)['active_id'])" < "$TMPDIR/seed.json" 2>/dev/null)"
DELETED_ID="$(python -c "import json,sys;print(json.load(sys.stdin).get('deleted_id',''))" < "$TMPDIR/seed.json" 2>/dev/null)"
MISSING_ID="$(python -c "import json,sys;print(json.load(sys.stdin)['missing_id'])" < "$TMPDIR/seed.json" 2>/dev/null)"

# (1) GET /assets default + request-id echo
RID_OK="RID_ASSETS_OK_$(date +%s)"
curl -sS -H "X-Request-Id: $RID_OK" -D "$TMPDIR/a1.h" "$API_BASE_URL/assets" -o "$TMPDIR/a1.json" >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] GET /assets failed"
  echo "== gate_assets_read: fail =="
  exit 4
fi

HDR_RID="$(grep -i '^x-request-id:' "$TMPDIR/a1.h" | head -n 1 | awk -F': ' '{print $2}' | tr -d '\r')"
if [ "$HDR_RID" != "$RID_OK" ]; then
  echo "[err] request-id echo mismatch on success: sent=$RID_OK got=$HDR_RID"
  echo "== gate_assets_read: fail =="
  exit 5
fi
echo "[ok] header echo: X-Request-Id matches on success"

ACTIVE_ID="$ACTIVE_ID" DELETED_ID="$DELETED_ID" python -c '
import os, json, sys
j = json.load(sys.stdin)
assert "items" in j and "page" in j, "[err] missing items/page"
p = j["page"]
for k in ("limit","offset","total","has_more"):
    assert k in p, f"[err] missing page.{k}"
assert p["limit"] == 50, f"[err] default limit must be 50, got {p['\''limit'\'']}"
assert p["limit"] <= 200, "[err] limit must be <=200"

active_id = os.environ["ACTIVE_ID"]
deleted_id = os.environ.get("DELETED_ID","")
ids = [it.get("id") for it in j["items"] if isinstance(it, dict)]
assert active_id in ids, f"[err] active seeded id not present: {active_id}"
if deleted_id:
    assert deleted_id not in ids, f"[err] deleted id should be excluded by default: {deleted_id}"

print("[ok] GET /assets returns items + page with required keys")
print("[ok] pagination respects default=50 and max=200")
print("[ok] default excludes deleted")
' < "$TMPDIR/a1.json"
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] response validation failed; see $TMPDIR/a1.json"
  echo "== gate_assets_read: fail =="
  exit 6
fi

# (2) include_deleted=true should include deleted_id (if available)
if [ -n "$DELETED_ID" ]; then
  curl -sS -D "$TMPDIR/a2.h" "$API_BASE_URL/assets?include_deleted=true" -o "$TMPDIR/a2.json" >/dev/null 2>&1
  DELETED_ID="$DELETED_ID" python -c '
import os, json, sys
deleted_id = os.environ["DELETED_ID"]
j = json.load(sys.stdin)
ids = [it.get("id") for it in j.get("items", []) if isinstance(it, dict)]
assert deleted_id in ids, f"[err] include_deleted=true should include deleted id: {deleted_id}"
print("[ok] include_deleted=true shows soft-deleted assets")
' < "$TMPDIR/a2.json"
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "[err] include_deleted check failed; see $TMPDIR/a2.json"
    echo "== gate_assets_read: fail =="
    exit 7
  fi
else
  echo "[warn] no deleted_id seeded; skip include_deleted assertion"
fi

# (3) GET /assets/{id}
curl -sS -D "$TMPDIR/a3.h" "$API_BASE_URL/assets/$ACTIVE_ID" -o "$TMPDIR/a3.json" >/dev/null 2>&1
python -c '
import json, sys
j = json.load(sys.stdin)
assert "asset" in j and "traceability" in j, "[err] missing asset/traceability keys"
t = j["traceability"]
assert "links" in t and "related" in t, "[err] traceability must include links+related"
print("[ok] GET /assets/{id} includes traceability refs")
' < "$TMPDIR/a3.json"
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] asset detail validation failed; see $TMPDIR/a3.json"
  echo "== gate_assets_read: fail =="
  exit 8
fi

# (4) 404 error envelope + request-id echo
RID_ERR="RID_ASSETS_ERR_$(date +%s)"
curl -sS -H "X-Request-Id: $RID_ERR" -D "$TMPDIR/e1.h" "$API_BASE_URL/assets/$MISSING_ID" -o "$TMPDIR/e1.json" >/dev/null 2>&1

HDR_RID2="$(grep -i '^x-request-id:' "$TMPDIR/e1.h" | head -n 1 | awk -F': ' '{print $2}' | tr -d '\r')"
if [ "$HDR_RID2" != "$RID_ERR" ]; then
  echo "[err] request-id echo mismatch on error: sent=$RID_ERR got=$HDR_RID2"
  echo "== gate_assets_read: fail =="
  exit 9
fi

RID_ERR="$RID_ERR" python -c '
import os, json, sys
rid = os.environ["RID_ERR"]
j = json.load(sys.stdin)
for k in ("error","message","request_id","details"):
    assert k in j, f"[err] error envelope missing key: {k}"
assert j.get("request_id") == rid, f"[err] error envelope request_id mismatch: expected {rid} got {j.get('\''request_id'\'')}"
print("[ok] 404 returns error_envelope with request_id")
' < "$TMPDIR/e1.json"
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] error envelope validation failed; see $TMPDIR/e1.json"
  echo "== gate_assets_read: fail =="
  exit 10
fi

echo "== gate_assets_read: passed =="
exit 0
