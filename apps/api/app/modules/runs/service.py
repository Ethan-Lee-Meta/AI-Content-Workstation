from __future__ import annotations

import json
import os
import sqlite3
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

DEFAULT_DATABASE_URL = "sqlite:///./data/app.db"
_CROCKFORD32 = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"


def _encode_crockford(value: int, length: int) -> str:
    chars: List[str] = []
    for _ in range(length):
        chars.append(_CROCKFORD32[value & 31])
        value >>= 5
    return "".join(reversed(chars))


def new_ulid() -> str:
    # 48-bit time (ms) + 80-bit randomness
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
        return url[len("sqlite:////") - 1 :]  # keep leading '/'
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


def _table_exists(conn: sqlite3.Connection, table: str) -> bool:
    row = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        (table,),
    ).fetchone()
    return row is not None


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
        # if PK is integer, let DB autoincrement; otherwise generate ULID
        if "INT" not in t:
            data[pk] = new_ulid()

    # timestamps (only if NOT NULL and no default)
    for k in ("created_at", "updated_at", "submitted_at"):
        if k in cols and cols[k]["notnull"] == 1 and cols[k]["dflt_value"] is None and k not in data:
            data[k] = now

    # status default (only if required)
    if "status" in cols and cols["status"]["notnull"] == 1 and cols["status"]["dflt_value"] is None and "status" not in data:
        data["status"] = "queued"

    # final pass: NOT NULL w/o default and still missing
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

    # fallback: lastrowid for integer PKs
    try:
        return str(cur.lastrowid)
    except Exception:
        return ""


def create_run(run_type: str, prompt_pack: Dict[str, Any]) -> Tuple[str, str, str]:
    """
    Append-only: creates PromptPack + Run as two INSERTs.
    Returns (run_id, prompt_pack_id, status)
    """
    conn = _connect()
    try:
        if not _table_exists(conn, "prompt_packs"):
            raise RuntimeError("DB missing table: prompt_packs")
        if not _table_exists(conn, "runs"):
            raise RuntimeError("DB missing table: runs")

        pp_cols = _table_info(conn, "prompt_packs")
        payload = json.dumps({"run_type": run_type, **(prompt_pack or {})}, ensure_ascii=False)

        pp_row: Dict[str, Any] = {}
        # put payload into first matching column
        for k in ("payload_json", "payload", "input_json", "input", "meta_json", "meta", "params_json", "params"):
            if k in pp_cols:
                pp_row[k] = payload
                break
        if "type" in pp_cols:
            pp_row["type"] = run_type
        if "kind" in pp_cols:
            pp_row["kind"] = "prompt_pack"

        prompt_pack_id = _insert(conn, "prompt_packs", pp_row)

        run_cols = _table_info(conn, "runs")
        run_row: Dict[str, Any] = {}

        # FK to prompt_pack (best-effort)
        for k in ("prompt_pack_id", "promptpack_id", "prompt_pack_ulid"):
            if k in run_cols:
                run_row[k] = prompt_pack_id
                break

        if "run_type" in run_cols:
            run_row["run_type"] = run_type
        if "type" in run_cols:
            run_row["type"] = run_type
        if "status" in run_cols:
            run_row["status"] = "queued"

        rr = json.dumps({"asset_ids": []}, ensure_ascii=False)
        for k in ("result_refs_json", "result_refs", "result_json", "result"):
            if k in run_cols:
                run_row[k] = rr
                break

        run_id = _insert(conn, "runs", run_row)

        conn.commit()
        return str(run_id), str(prompt_pack_id), "queued"
    finally:
        conn.close()




def update_run(
    run_id: str,
    *,
    status: Optional[str] = None,
    result_refs: Optional[Dict[str, Any]] = None,
) -> bool:
    """
    Best-effort UPDATE for runs table (P1 provider execution).
    - Does NOT change API shape.
    - Updates only columns that exist.
    Returns True if an UPDATE was attempted (i.e., had at least one field to set).
    """
    conn = _connect()
    try:
        if not _table_exists(conn, "runs"):
            raise RuntimeError("DB missing table: runs")

        cols = _table_info(conn, "runs")
        pk = _primary_key_name(cols)
        id_col = pk if pk else ("id" if "id" in cols else ("run_id" if "run_id" in cols else "id"))

        updates: Dict[str, Any] = {}

        if status is not None and "status" in cols:
            updates["status"] = status

        if result_refs is not None:
            rr_json = json.dumps(result_refs, ensure_ascii=False)
            for k in ("result_refs_json", "result_refs", "result_json", "result"):
                if k in cols:
                    updates[k] = rr_json
                    break

        # timestamps (best effort)
        if "updated_at" in cols:
            updates["updated_at"] = _now_iso()

        if not updates:
            return False

        keys = sorted(updates.keys())
        set_sql = ", ".join([f"{k}=?" for k in keys])
        sql = f"UPDATE runs SET {set_sql} WHERE {id_col}=?;"
        conn.execute(sql, [updates[k] for k in keys] + [run_id])
        conn.commit()
        return True
    finally:
        conn.close()


def get_run(run_id: str) -> Optional[Dict[str, Any]]:
    conn = _connect()
    try:
        if not _table_exists(conn, "runs"):
            raise RuntimeError("DB missing table: runs")

        cols = _table_info(conn, "runs")
        pk = _primary_key_name(cols)
        id_col = pk if pk else ("id" if "id" in cols else ("run_id" if "run_id" in cols else "id"))

        row = conn.execute(f"SELECT * FROM runs WHERE {id_col}=? LIMIT 1;", (run_id,)).fetchone()
        if row is None:
            return None

        prompt_pack_id = ""
        for k in ("prompt_pack_id", "promptpack_id", "prompt_pack_ulid"):
            if k in row.keys() and row[k] is not None:
                prompt_pack_id = str(row[k])
                break

        created_at = None
        for k in ("created_at", "submitted_at"):
            if k in row.keys():
                created_at = row[k]
                break

        status = str(row["status"]) if "status" in row.keys() and row["status"] is not None else ""

        result_refs: Dict[str, Any] = {}
        for k in ("result_refs_json", "result_refs", "result_json", "result"):
            if k in row.keys() and row[k]:
                try:
                    result_refs = json.loads(row[k])
                except Exception:
                    result_refs = {}
                break


        # overlay: latest run_events (append-only transitions)
        ev = _get_latest_run_event(conn, str(row[id_col]))
        if ev:
            if ev.get('status'):
                status = str(ev['status'])
            if isinstance(ev.get('result_refs'), dict):
                result_refs = ev['result_refs']

        return {
            "run_id": str(row[id_col]),
            "prompt_pack_id": prompt_pack_id,
            "status": status,
            "created_at": str(created_at) if created_at is not None else None,
            "result_refs": result_refs if isinstance(result_refs, dict) else {},
        }
    finally:
        conn.close()


def _ensure_run_events_table(conn: sqlite3.Connection) -> None:
    """
    Append-only event log for Run status transitions & results (P1 ProviderAdapter).
    This avoids UPDATE on runs table (runs is append-only).
    """
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS run_events (
            event_id TEXT PRIMARY KEY,
            run_id TEXT NOT NULL,
            status TEXT NOT NULL,
            result_refs_json TEXT,
            request_id TEXT,
            created_at TEXT NOT NULL
        );
        """
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_run_events_run_id_created_at ON run_events(run_id, created_at);"
    )


def append_run_event(
    run_id: str,
    *,
    status: str,
    result_refs: Optional[Dict[str, Any]] = None,
    request_id: Optional[str] = None,
) -> str:
    """
    Append-only insert of a run event.
    Returns event_id.
    """
    conn = _connect()
    try:
        _ensure_run_events_table(conn)
        event_id = new_ulid()
        now = _now_iso()
        rr_json = None
        if result_refs is not None:
            rr_json = json.dumps(result_refs, ensure_ascii=False)
        conn.execute(
            "INSERT INTO run_events (event_id, run_id, status, result_refs_json, request_id, created_at) VALUES (?,?,?,?,?,?);",
            (event_id, run_id, status, rr_json, request_id or "", now),
        )
        conn.commit()
        return event_id
    finally:
        conn.close()


def _get_latest_run_event(conn: sqlite3.Connection, run_id: str) -> Optional[Dict[str, Any]]:
    """
    Read latest event for run_id (best-effort).
    Returns {status, result_refs} or None.
    """
    try:
        _ensure_run_events_table(conn)
        row = conn.execute(
            "SELECT status, result_refs_json, created_at FROM run_events WHERE run_id=? ORDER BY created_at DESC LIMIT 1;",
            (run_id,),
        ).fetchone()
        if row is None:
            return None
        rr: Dict[str, Any] = {}
        if "result_refs_json" in row.keys() and row["result_refs_json"]:
            try:
                rr = json.loads(row["result_refs_json"])
            except Exception:
                rr = {}
        return {"status": row["status"], "result_refs": rr if isinstance(rr, dict) else {}}
    except Exception:
        # If anything goes wrong, do not break GET /runs/{id}.
        return None
