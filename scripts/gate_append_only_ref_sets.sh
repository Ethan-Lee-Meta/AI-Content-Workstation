#!/usr/bin/env bash
set +e

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$ROOT" ]; then
  echo "[err] not inside a git repo"
  exit 1
fi
cd "$ROOT" || exit 1

PY="$ROOT/apps/api/.venv/Scripts/python.exe"
if [ ! -f "$PY" ]; then PY="python"; fi

DB="$ROOT/data/app.db"
if [ ! -f "$DB" ]; then
  echo "[err] missing db: $DB"
  exit 2
fi

TMPDIR="$ROOT/tmp/gate_append_only_ref_sets.$RANDOM"
mkdir -p "$TMPDIR" || exit 3
cp -f "$DB" "$TMPDIR/app.db" || exit 4

echo "== gate_append_only_ref_sets: start =="
echo "== [info] tmpdb=$TMPDIR/app.db =="

"$PY" - <<'PY'
from __future__ import annotations
import sqlite3, uuid, json
from datetime import datetime
from pathlib import Path

db = Path("tmp").glob("gate_append_only_ref_sets.*")
# take the newest one (this run)
tmpdb = sorted([p for p in db], key=lambda p: p.stat().st_mtime)[-1] / "app.db"
print(f"== [info] using tmpdb={tmpdb} ==")

con = sqlite3.connect(str(tmpdb))
cur = con.cursor()
cur.execute("PRAGMA foreign_keys=ON")

def has_trigger(name: str) -> bool:
    cur.execute("SELECT 1 FROM sqlite_master WHERE type='trigger' AND name=? LIMIT 1", (name,))
    return cur.fetchone() is not None

def has_index(name: str) -> bool:
    cur.execute("SELECT 1 FROM sqlite_master WHERE type='index' AND name=? LIMIT 1", (name,))
    return cur.fetchone() is not None

# presence (defensive)
for t in ["trg_character_ref_sets_no_update", "trg_character_ref_sets_no_delete"]:
    if not has_trigger(t):
        raise SystemExit(f"[err] missing trigger: {t}")
print("[ok] triggers present (tmpdb)")

if not has_index("uq_character_ref_sets_character_id_version"):
    raise SystemExit("[err] missing unique index: uq_character_ref_sets_character_id_version")
print("[ok] unique index present (tmpdb): uq_character_ref_sets_character_id_version")

if not has_index("uq_provider_profiles_global_default"):
    raise SystemExit("[err] missing unique index: uq_provider_profiles_global_default")
print("[ok] unique index present (tmpdb): uq_provider_profiles_global_default")

now = datetime.utcnow().replace(microsecond=0).isoformat() + "Z"

# seed character + ref_set
character_id = uuid.uuid4().hex.upper()
ref_id = uuid.uuid4().hex.upper()

cur.execute(
    "INSERT INTO characters(id,name,status,active_ref_set_id,created_at,updated_at) VALUES(?,?,?,?,?,?)",
    (character_id, "gate_test_character", "draft", None, now, now),
)

cur.execute(
    "INSERT INTO character_ref_sets(id,character_id,version,status,min_requirements_snapshot_json,created_at) VALUES(?,?,?,?,?,?)",
    (ref_id, character_id, 1, "draft", json.dumps({"min_assets": 8, "recommended": 12, "note": "gate_test"}), now),
)
con.commit()
print("[ok] inserted gate_test rows")

# unique(character_id, version) should reject second insert with same version
try:
    cur.execute(
        "INSERT INTO character_ref_sets(id,character_id,version,status,min_requirements_snapshot_json,created_at) VALUES(?,?,?,?,?,?)",
        (uuid.uuid4().hex.upper(), character_id, 1, "draft", "{}", now),
    )
    con.commit()
    raise SystemExit("[err] expected unique constraint failure for (character_id, version)")
except sqlite3.Error as e:
    msg = str(e)
    print("[ok] unique constraint enforced:", msg.splitlines()[0][:120])

# UPDATE should abort (append-only)
try:
    cur.execute("UPDATE character_ref_sets SET status='confirmed' WHERE id=?", (ref_id,))
    con.commit()
    raise SystemExit("[err] expected abort on UPDATE (append-only)")
except sqlite3.Error as e:
    msg = str(e)
    if "append-only" not in msg:
        raise SystemExit(f"[err] UPDATE failed but missing 'append-only' marker: {msg}")
    print("[ok] append-only UPDATE blocked:", msg.splitlines()[0][:120])

# DELETE should abort (append-only)
try:
    cur.execute("DELETE FROM character_ref_sets WHERE id=?", (ref_id,))
    con.commit()
    raise SystemExit("[err] expected abort on DELETE (append-only)")
except sqlite3.Error as e:
    msg = str(e)
    if "append-only" not in msg:
        raise SystemExit(f"[err] DELETE failed but missing 'append-only' marker: {msg}")
    print("[ok] append-only DELETE blocked:", msg.splitlines()[0][:120])

# provider_profiles global default unique (partial unique index)
pid1 = uuid.uuid4().hex.upper()
pid2 = uuid.uuid4().hex.upper()

cur.execute(
    "INSERT INTO provider_profiles(id,name,provider_type,config_json,secrets_redaction_policy_json,is_global_default,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?)",
    (pid1, "gate_test_default_1", "dummy", "{}", '{"secret_fields":[]}', 1, now, now),
)
con.commit()
print("[ok] inserted provider_profiles default=1 row")

try:
    cur.execute(
        "INSERT INTO provider_profiles(id,name,provider_type,config_json,secrets_redaction_policy_json,is_global_default,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?)",
        (pid2, "gate_test_default_2", "dummy", "{}", '{"secret_fields":[]}', 1, now, now),
    )
    con.commit()
    raise SystemExit("[err] expected unique failure for second global default")
except sqlite3.Error as e:
    print("[ok] global default unique enforced:", str(e).splitlines()[0][:120])

con.close()
print("[ok] gate_append_only_ref_sets passed")
PY

rc=$?
if [ $rc -ne 0 ]; then
  echo "[err] gate_append_only_ref_sets failed (rc=$rc)"
  exit 10
fi

echo "== gate_append_only_ref_sets: passed =="
exit 0
