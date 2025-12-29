"""
DB utilities (sqlite default) for BATCH-1.

Defaults (per ARCH):
- DATABASE_URL: sqlite:///./data/app.db
"""
from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Dict, Optional

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine


def get_database_url() -> str:
    return os.getenv("DATABASE_URL", "sqlite:///./data/app.db")


def _repo_root() -> Path:
    # apps/api/app/core/db.py -> repo root = parents[4]
    return Path(__file__).resolve().parents[4]


def resolve_sqlite_path(database_url: str) -> Optional[Path]:
    if not database_url.startswith("sqlite:///"):
        return None
    p = database_url[len("sqlite:///") :]

    # absolute unix
    if p.startswith("/"):
        return Path(p)

    # absolute windows drive, both C:/ and C:\ forms
    if len(p) >= 3 and p[1] == ":" and (p[2] == "/" or p[2] == "\\"):
        return Path(p)

    # relative -> repo root
    return (_repo_root() / p).resolve()


_engine: Optional[Engine] = None


def get_engine() -> Engine:
    global _engine
    if _engine is not None:
        return _engine

    url = get_database_url()
    connect_args = {}
    if url.startswith("sqlite:///"):
        connect_args = {"check_same_thread": False}

    sp = resolve_sqlite_path(url)
    if sp is not None:
        sp.parent.mkdir(parents=True, exist_ok=True)
        url = "sqlite:///" + sp.as_posix()

    _engine = create_engine(url, future=True, connect_args=connect_args)
    return _engine


def db_health() -> Dict[str, Any]:
    url = get_database_url()
    kind = "sqlite" if url.startswith("sqlite") else "unknown"
    path = None
    sp = resolve_sqlite_path(url)
    path = str(sp.as_posix()) if sp is not None else url

    try:
        eng = get_engine()
        with eng.connect() as conn:
            conn.execute(text("SELECT 1"))
        return {"status": "ok", "kind": kind, "path": path}
    except Exception as e:
        return {"status": "error", "kind": kind, "path": path, "error": str(e)}
