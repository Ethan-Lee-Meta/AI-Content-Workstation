from __future__ import annotations

import json
import os
import sqlite3
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

DEFAULT_DATABASE_URL = "sqlite:///./data/app.db"
_CROCKFORD32 = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"


def _encode_crockford(value: int, length: int) -> str:
    chars: List[str] = []
    for _ in range(length):
        chars.append(_CROCKFORD32[value & 31])
        value >>= 5
    return "".join(reversed(chars))


def new_ulid() -> str:
    ms = int(time.time() * 1000) & ((1 << 48) - 1)
    rnd = int.from_bytes(os.urandom(10), "big")
    v = (ms << 80) | rnd
    return _encode_crockford(v, 26)


def _now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _sqlite_path_from_url(url: str) -> str:
    if not url.startswith("sqlite:"):
        raise ValueError(f"Only sqlite supported for now, got DATABASE_URL={url!r}")
    if url.startswith("sqlite:////"):
        return url[len("sqlite:////") - 1 :]
    if url.startswith("sqlite:///"):
        return url[len("sqlite:///") :]
    if url.startswith("sqlite://"):
        return url[len("sqlite://") :]
    raise ValueError(f"Unrecognized sqlite DATABASE_URL format: {url!r}")


def _connect() -> sqlite3.Connection:
    url = os.getenv("DATABASE_URL", DEFAULT_DATABASE_URL)
    path = _sqlite_path_from_url(url)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


def _table_exists(conn: sqlite3.Connection, table: str) -> bool:
    row = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        (table,),
    ).fetchone()
    return row is not None


def _table_info(conn: sqlite3.Connection, table: str) -> Dict[str, Dict[str, Any]]:
    out: Dict[str, Dict[str, Any]] = {}
    rows = conn.execute(f"PRAGMA table_info({table});").fetchall()
    for r in rows:
        out[r["name"]] = {
            "type": (r["type"] or "").upper(),
            "notnull": int(r["notnull"]),
            "dflt_value": r["dflt_value"],
            "pk": int(r["pk"]),
        }
    return out


def _primary_key_name(cols: Dict[str, Dict[str, Any]]) -> Optional[str]:
    for name, info in cols.items():
        if int(info.get("pk", 0)) == 1:
            return name
    if "id" in cols:
        return "id"
    return None


def _fill_required(cols: Dict[str, Dict[str, Any]], base: Dict[str, Any]) -> Dict[str, Any]:
    data = dict(base)
    now = _now_iso()

    pk = _primary_key_name(cols)
    if pk and pk not in data:
        t = (cols.get(pk, {}).get("type") or "").upper()
        if "INT" not in t:
            data[pk] = new_ulid()

    for k in ("created_at", "updated_at", "submitted_at"):
        if k in cols and cols[k]["notnull"] == 1 and cols[k]["dflt_value"] is None and k not in data:
            data[k] = now

    # Any remaining NOT NULL with no default
    for name, info in cols.items():
        if info["notnull"] != 1:
            continue
        if info["dflt_value"] is not None:
            continue
        if info["pk"] == 1:
            continue
        if name in data:
            continue

        t = info["type"]
        if name.endswith("_id"):
            data[name] = new_ulid()
        elif "INT" in t:
            data[name] = 0
        elif "REAL" in t or "FLOA" in t or "DOUB" in t:
            data[name] = 0.0
        else:
            data[name] = ""
    return data


def _insert(conn: sqlite3.Connection, table: str, row: Dict[str, Any]) -> str:
    cols = _table_info(conn, table)
    data = _fill_required(cols, row)

    keys = [k for k in data.keys() if k in cols]
    keys.sort()
    sql = f"INSERT INTO {table} ({','.join(keys)}) VALUES ({','.join(['?'] * len(keys))});"
    cur = conn.execute(sql, [data[k] for k in keys])

    pk = _primary_key_name(cols)
    if pk and pk in data:
        return str(data[pk])
    try:
        return str(cur.lastrowid)
    except Exception:
        return ""


def create_review(payload: Dict[str, Any]) -> str:
    """
    Append-only: creates Review row via INSERT.
    Schema-flexible: maps provided fields into existing columns where possible.
    """
    conn = _connect()
    try:
        if not _table_exists(conn, "reviews"):
            raise RuntimeError("DB missing table: reviews")

        cols = _table_info(conn, "reviews")
        row: Dict[str, Any] = {}

        # map common fields (only if the column exists)
        mapping = {
            "review_type": ["type", "review_type", "kind"],
            "conclusion": ["conclusion", "verdict", "decision"],
            "score": ["score", "rating"],
            "reason": ["reason", "note", "comment"],
            "run_id": ["run_id", "run_ulid", "run_fk", "target_run_id"],
            "asset_id": ["asset_id", "asset_ulid", "target_asset_id"],
        }

        for src, targets in mapping.items():
            val = payload.get(src)
            if val is None:
                continue
            for col in targets:
                if col in cols:
                    row[col] = val
                    break

        # details -> JSON columns
        details = payload.get("details") or {}
        details_json = json.dumps(details, ensure_ascii=False)
        for col in ("details_json", "details", "payload_json", "payload", "meta_json", "meta"):
            if col in cols:
                row[col] = details_json
                break

        review_id = _insert(conn, "reviews", row)
        conn.commit()
        return str(review_id)
    finally:
        conn.close()
