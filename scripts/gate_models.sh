#!/usr/bin/env bash
set +e

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$ROOT" ]; then echo "[err] not a git repo"; exit 2; fi
cd "$ROOT" || exit 2

ok()  { echo "[ok] $*"; }
warn(){ echo "[warn] $*"; }
err() { echo "[err] $*"; }

echo "== gate_models: start =="

pushd "$ROOT/apps/api" >/dev/null
export DATABASE_URL="${DATABASE_URL:-sqlite:///./data/app.db}"
python -m alembic -c alembic.ini upgrade head
RC_UP=$?
popd >/dev/null
if [ $RC_UP -ne 0 ]; then
  err "alembic upgrade head failed (rc=$RC_UP)"
  exit 10
fi
ok "alembic upgrade head ok"

python - <<'PY'
from __future__ import annotations
import os
from pathlib import Path
from sqlalchemy import create_engine, text

def repo_root() -> Path:
    return Path(".").resolve()

def resolve_sqlite_file(url: str) -> Path | None:
    if not url.startswith("sqlite:///"):
        return None
    p = url[len("sqlite:///"):]
    if p.startswith("/"):
        return Path(p)
    if len(p) >= 3 and p[1] == ":" and (p[2] == "/" or p[2] == "\\"):
        return Path(p)
    return (repo_root() / p).resolve()

url = os.getenv("DATABASE_URL", "sqlite:///./data/app.db")
connect_args = {}
if url.startswith("sqlite:///"):
    connect_args = {"check_same_thread": False}
    f = resolve_sqlite_file(url)
    if f is not None:
        f.parent.mkdir(parents=True, exist_ok=True)
        url = "sqlite:///" + f.as_posix()

engine = create_engine(url, future=True, connect_args=connect_args)

required_tables = [
    "assets","prompt_packs","runs","reviews","links",
    "projects","series","shots",
]

required_asset_cols = {"id","kind","created_at","deleted_at","project_id","series_id"}

required_triggers = [
    "trg_prompt_packs_no_update","trg_prompt_packs_no_delete",
    "trg_runs_no_update","trg_runs_no_delete",
    "trg_reviews_no_update","trg_reviews_no_delete",
    "trg_links_no_update","trg_links_no_delete",
]

def fetchall(sql: str, **params):
    with engine.connect() as c:
        return list(c.execute(text(sql), params).fetchall())

# tables
rows = fetchall("SELECT name FROM sqlite_master WHERE type='table'")
tables = sorted({r[0] for r in rows})
missing_tables = [t for t in required_tables if t not in tables]
if missing_tables:
    print("[err] missing required tables:", missing_tables)
    raise SystemExit(20)
print("[ok] required tables exist: " + ", ".join(required_tables))

# assets columns + nullable
cols = fetchall("PRAGMA table_info('assets')")
# (cid, name, type, notnull, dflt_value, pk)
asset_info = {r[1]: {"notnull": r[3]} for r in cols}
missing_cols = sorted(list(required_asset_cols - set(asset_info.keys())))
if missing_cols:
    print("[err] assets missing columns:", missing_cols)
    raise SystemExit(21)

if asset_info["project_id"]["notnull"] != 0 or asset_info["series_id"]["notnull"] != 0:
    print("[err] assets.project_id/series_id must be nullable (notnull=0). got:",
          {"project_id_notnull": asset_info["project_id"]["notnull"], "series_id_notnull": asset_info["series_id"]["notnull"]})
    raise SystemExit(22)

print("[ok] assets.deleted_at present")
print("[ok] assets.project_id/series_id nullable (unbound allowed)")

# triggers
trows = fetchall("SELECT name FROM sqlite_master WHERE type='trigger'")
trigs = {r[0] for r in trows}
missing_trigs = [t for t in required_triggers if t not in trigs]
if missing_trigs:
    print("[err] missing append-only triggers:", missing_trigs)
    raise SystemExit(23)
print("[ok] immutability policy enforced (append-only triggers present)")

# nullable columns in optional hierarchy
def check_nullable_col(table: str, col: str):
    rows = fetchall(f"PRAGMA table_info('{table}')")
    info = {r[1]: r[3] for r in rows}
    if col not in info:
        print(f"[err] {table} missing column {col}")
        raise SystemExit(24)
    if info[col] != 0:
        print(f"[err] {table}.{col} must be nullable (notnull=0). got notnull={info[col]}")
        raise SystemExit(25)

check_nullable_col("series", "project_id")
check_nullable_col("shots", "project_id")
check_nullable_col("shots", "series_id")
print("[ok] optional hierarchy nullable columns ok")

print("[ok] gate_models passed")
PY

RC=$?
if [ $RC -ne 0 ]; then
  err "gate_models failed (rc=$RC)"
  exit $RC
fi

ok "gate_models passed"
exit 0
