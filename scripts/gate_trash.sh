#!/usr/bin/env bash
set +e

cd "$(git rev-parse --show-toplevel)" || exit 1
ROOT="$(pwd)"
PY="./apps/api/.venv/Scripts/python.exe"

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:7000}"
DATABASE_URL="${DATABASE_URL:-sqlite:///./data/app.db}"
STORAGE_ROOT="${STORAGE_ROOT:-./data/storage}"

mkdir -p tmp
TMPDIR="$ROOT/tmp/gate_trash.$$"
mkdir -p "$TMPDIR"

echo "== gate_trash: start =="
echo "[info] API_BASE_URL=$API_BASE_URL"
echo "[info] DATABASE_URL=$DATABASE_URL"
echo "[info] STORAGE_ROOT=$STORAGE_ROOT"
echo "[info] TMPDIR=$TMPDIR"

PID=""
LOG_SELF="tmp/uvicorn_gate_trash.log"

# ---------------------------------------------------------
# Decide whether to reuse an already-running server
# ---------------------------------------------------------
curl -sS "$API_BASE_URL/health" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "[ok] /health reachable (reuse existing uvicorn; do NOT start a new one)"
else
  echo "== start uvicorn (venv python + --app-dir apps/api) =="
  : > "$LOG_SELF"
  "$PY" -m uvicorn app.main:app --app-dir apps/api --host 127.0.0.1 --port 7000 > "$LOG_SELF" 2>&1 &
  PID=$!
  echo "[info] uvicorn PID=$PID (log: $LOG_SELF)"

  echo "== wait /health (up to ~10s) =="
  OK=0
  for i in $(seq 1 40); do
    curl -sS "$API_BASE_URL/health" >/dev/null 2>&1 && OK=1 && break
    sleep 0.25
  done
  if [ $OK -ne 1 ]; then
    echo "[err] cannot reach API /health (need uvicorn running on 127.0.0.1:7000)"
    echo "------------------------------------------------------------"
    tail -n 200 "$LOG_SELF" 2>/dev/null || cat "$LOG_SELF" 2>/dev/null
    echo "------------------------------------------------------------"
    echo "[info] stopping uvicorn PID=$PID"
    kill "$PID" >/dev/null 2>&1
    echo "== gate_trash: fail =="
    exit 2
  fi
  echo "[ok] /health reachable"
fi

# ---------------------------------------------------------
# Seed: 1 active + 1 deleted asset directly in sqlite
# ---------------------------------------------------------
"$PY" - <<'PY' > "$TMPDIR/seed.json"
import os, sqlite3, uuid, datetime, json
from pathlib import Path

def resolve_db_path(url: str) -> str:
    if url.startswith("sqlite:///"):
        return str(Path(url.replace("sqlite:///","",1)).resolve())
    if url.startswith("sqlite+pysqlite:///"):
        return str(Path(url.replace("sqlite+pysqlite:///","",1)).resolve())
    return str(Path(url).resolve())

db_url = os.environ.get("DATABASE_URL","sqlite:///./data/app.db")
db_path = resolve_db_path(db_url)
storage_root = Path(os.environ.get("STORAGE_ROOT","./data/storage")).resolve()
storage_root.mkdir(parents=True, exist_ok=True)

conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
cols = conn.execute("PRAGMA table_info(assets)").fetchall()
col_names = [c["name"] for c in cols]
meta = {c["name"]: {"notnull": int(c["notnull"]), "dflt": c["dflt_value"], "type": (c["type"] or "").upper(), "pk": int(c["pk"])} for c in cols}

def uid():
    return uuid.uuid4().hex.upper()

now = datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"

candidates = ["storage_path","file_path","local_path","path","uri","storage_relpath","relpath","storage_key"]
path_col = next((c for c in candidates if c in col_names), None)

def fill_required(row: dict):
    for name, info in meta.items():
        if name in row:
            continue
        if info["pk"] == 1:
            if "INT" not in info["type"]:
                row[name] = uid()
            continue
        if info["notnull"] == 1 and info["dflt"] is None:
            t = info["type"]
            lname = name.lower()
            if lname.endswith("_id") or lname in ("id","asset_id"):
                row[name] = uid()
            elif lname in ("created_at","updated_at","ts","created_ts","updated_ts"):
                row[name] = now
            elif lname in ("kind","type","asset_type","media_type"):
                row[name] = "image"
            elif "mime" in lname:
                row[name] = "image/png"
            elif lname in ("ext","file_ext","suffix"):
                row[name] = "png"
            elif "sha" in lname or "hash" in lname:
                row[name] = "0"*64
            elif "size" in lname or "bytes" in lname:
                row[name] = 123
            elif lname in ("width","w"):
                row[name] = 1
            elif lname in ("height","h"):
                row[name] = 1
            elif "duration" in lname:
                row[name] = 0
            else:
                if "INT" in t:
                    row[name] = 0
                elif "REAL" in t or "FLOA" in t or "DOUB" in t:
                    row[name] = 0.0
                else:
                    row[name] = ""
    return row

def insert_asset(asset_id: str, deleted: bool):
    row = {}
    if "id" in col_names:
        row["id"] = asset_id
    elif "asset_id" in col_names:
        row["asset_id"] = asset_id

    if "deleted_at" in col_names:
        row["deleted_at"] = (now if deleted else None)

    file_path = None
    if path_col:
        rel = f"gate_trash/{asset_id}.bin"
        row[path_col] = rel
        file_path = str((storage_root / rel).resolve())
        Path(file_path).parent.mkdir(parents=True, exist_ok=True)
        Path(file_path).write_bytes(b"trash-gate")

    fill_required(row)

    keys = list(row.keys())
    q = "INSERT INTO assets (" + ",".join(keys) + ") VALUES (" + ",".join(["?"]*len(keys)) + ")"
    conn.execute(q, [row[k] for k in keys])
    return file_path

active_id = uid()
deleted_id = uid()
active_file = insert_asset(active_id, deleted=False)
deleted_file = insert_asset(deleted_id, deleted=True)
conn.commit()
conn.close()

print(json.dumps({
    "active_id": active_id,
    "deleted_id": deleted_id,
    "path_col": path_col,
    "active_file": active_file,
    "deleted_file": deleted_file,
}, ensure_ascii=False))
PY
SEED_JSON="$(cat "$TMPDIR/seed.json" 2>/dev/null)"
echo "[info] seed: $SEED_JSON"

# ---------------------------------------------------------
# Validate semantics + trash empty (python)
# ---------------------------------------------------------
"$PY" - <<'PY' > "$TMPDIR/validate.out" 2> "$TMPDIR/validate.err"
import json, os, urllib.request, urllib.error, time
from pathlib import Path

base = os.environ.get("API_BASE_URL","http://127.0.0.1:7000").rstrip("/")
seed = json.load(open(Path(os.environ["TMPDIR"]) / "seed.json", "r", encoding="utf-8"))
active_id = seed["active_id"]
deleted_id = seed["deleted_id"]
deleted_file = seed.get("deleted_file")

def req(method, url, body=None, headers=None):
    headers = headers or {}
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r, timeout=10) as resp:
            raw = resp.read().decode("utf-8")
            return resp.status, dict(resp.headers), (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8")
        try:
            j = json.loads(raw) if raw else None
        except Exception:
            j = {"raw": raw}
        return e.code, dict(e.headers), j

st, hdr, j = req("GET", base + "/assets?limit=200")
assert st == 200, (st, j)
items = j.get("items") or []
ids = [it.get("id") for it in items if isinstance(it, dict)]
assert active_id in ids, "active missing from default list"
assert deleted_id not in ids, "deleted must NOT appear in default list"
print("[ok] default excludes deleted")

st, hdr, j = req("GET", base + "/assets?include_deleted=true&limit=200")
assert st == 200, (st, j)
items = j.get("items") or []
ids = [it.get("id") for it in items if isinstance(it, dict)]
assert active_id in ids and deleted_id in ids, "include_deleted must show deleted assets"
print("[ok] include_deleted=true shows soft-deleted assets")

rid = "GATE_TRASH_REQID_001"
st, hdr, j = req("POST", base + "/trash/empty", body={}, headers={"X-Request-Id": rid})
assert st == 200, (st, j)
echo = hdr.get("X-Request-Id") or hdr.get("x-request-id")
assert echo == rid, f"X-Request-Id not echoed: {echo}"
assert j.get("status") == "ok", j
assert int(j.get("purged_assets") or 0) >= 1, j
print("[ok] POST /trash/empty returns ok + purged_assets>=1 and echoes X-Request-Id")

st, hdr, j = req("GET", base + "/assets?include_deleted=true&limit=200")
assert st == 200, (st, j)
items = j.get("items") or []
ids = [it.get("id") for it in items if isinstance(it, dict)]
assert deleted_id not in ids, "deleted must be purged"
assert active_id in ids, "active must remain"
print("[ok] purged deleted assets removed; active remains")

if deleted_file:
    p = Path(deleted_file)
    time.sleep(0.2)
    if p.exists():
        raise AssertionError(f"expected deleted file removed, but still exists: {deleted_file}")
    print("[ok] deleted file removed (best-effort)")
PY
RC=$?
if [ $RC -ne 0 ]; then
  echo "[err] validation failed; see:"
  echo "  - $TMPDIR/validate.out"
  echo "  - $TMPDIR/validate.err"
  echo "  - $TMPDIR/seed.json"
  echo "------------------------------------------------------------"
  cat "$TMPDIR/validate.err" 2>/dev/null
  echo "------------------------------------------------------------"
  if [ -n "$PID" ]; then
    echo "[info] stopping uvicorn PID=$PID"
    kill "$PID" >/dev/null 2>&1
  fi
  echo "== gate_trash: fail =="
  exit 6
fi
cat "$TMPDIR/validate.out" 2>/dev/null

# ---------------------------------------------------------
# Audit event: search in candidate uvicorn logs (supports STEP-A shared log)
# ---------------------------------------------------------
FOUND=0
CANDIDATES=()

# prefer explicit env log if provided
if [ -n "${UVICORN_LOG:-}" ]; then CANDIDATES+=("${UVICORN_LOG}"); fi

# common logs
CANDIDATES+=("tmp/uvicorn_batch2_all_gates.log")
CANDIDATES+=("tmp/uvicorn_gate_trash.log")
CANDIDATES+=("tmp/uvicorn_step090_gate_trash.log")
CANDIDATES+=("$LOG_SELF")

# last resort: any uvicorn*.log
for f in tmp/uvicorn*.log; do
  [ -f "$f" ] && CANDIDATES+=("$f")
done

for f in "${CANDIDATES[@]}"; do
  [ -f "$f" ] || continue
  grep -q "trash.empty" "$f"
  if [ $? -eq 0 ]; then
    FOUND=1
    break
  fi
done

if [ $FOUND -ne 1 ]; then
  echo "[err] missing audit event in uvicorn logs (searched candidates)"
  echo "------------------------------------------------------------"
  for f in "${CANDIDATES[@]}"; do
    [ -f "$f" ] || continue
    echo "[info] tail $f"
    tail -n 120 "$f" 2>/dev/null || true
  done
  echo "------------------------------------------------------------"
  if [ -n "$PID" ]; then
    echo "[info] stopping uvicorn PID=$PID"
    kill "$PID" >/dev/null 2>&1
  fi
  echo "== gate_trash: fail =="
  exit 7
fi
echo "[ok] audit event present in uvicorn log(s)"

if [ -n "$PID" ]; then
  echo "[info] stopping uvicorn PID=$PID"
  kill "$PID" >/dev/null 2>&1
fi

echo "== gate_trash: passed =="
exit 0
