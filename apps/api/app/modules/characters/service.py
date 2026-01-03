from __future__ import annotations

import json
import os
import sqlite3
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from fastapi import HTTPException

from app.modules.runs.service import new_ulid

DEFAULT_DATABASE_URL = "sqlite:///./data/app.db"

# --- constants (relationships) ---
REL_HAS_REF_SET_VERSION = "has_ref_set_version"
REL_INCLUDES_REFERENCE_ASSET = "includes_reference_asset"

TYPE_CHARACTER = "character"
TYPE_REF_SET = "character_ref_set"
TYPE_ASSET = "asset"

MIN_REFS_CONFIRMED = 8


# --- db helpers ---
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
    conn = sqlite3.connect(path, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn


def _table_exists(conn: sqlite3.Connection, table: str) -> bool:
    row = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        (table,),
    ).fetchone()
    return row is not None


def _columns(conn: sqlite3.Connection, table: str) -> List[str]:
    rows = conn.execute(f"PRAGMA table_info({table});").fetchall()
    return [r["name"] for r in rows]


def _safe_json_loads(v: Any) -> Dict[str, Any]:
    if not v:
        return {}
    if isinstance(v, dict):
        return v
    try:
        return json.loads(v)
    except Exception:
        return {}


def _primary_key_name(conn: sqlite3.Connection, table: str) -> str:
    rows = conn.execute(f"PRAGMA table_info({table});").fetchall()
    for r in rows:
        if int(r["pk"]) == 1:
            return str(r["name"])
    # fallback
    cols = [r["name"] for r in rows]
    if "id" in cols:
        return "id"
    return cols[0] if cols else "id"


def _insert(conn: sqlite3.Connection, table: str, row: Dict[str, Any]) -> str:
    cols = set(_columns(conn, table))
    pk = _primary_key_name(conn, table)

    data = dict(row)
    now = _now_iso()

    if pk in cols and pk not in data:
        data[pk] = new_ulid()

    if "created_at" in cols and "created_at" not in data:
        data["created_at"] = now
    if "updated_at" in cols and "updated_at" not in data:
        data["updated_at"] = now

    keys = [k for k in data.keys() if k in cols]
    keys.sort()
    sql = f"INSERT INTO {table} ({','.join(keys)}) VALUES ({','.join(['?'] * len(keys))});"
    conn.execute(sql, [data[k] for k in keys])

    return str(data.get(pk, ""))


# --- links column mapping (src/dst OR source/target) ---
def _links_spec(conn: sqlite3.Connection) -> Dict[str, Optional[str]]:
    cols = set(_columns(conn, "links"))

    has_src_dst = {"src_type", "src_id", "dst_type", "dst_id"}.issubset(cols)
    has_source_target = {"source_type", "source_id", "target_type", "target_id"}.issubset(cols)

    if has_src_dst:
        src_col = "src_type"
        src_id_col = "src_id"
        dst_col = "dst_type"
        dst_id_col = "dst_id"
        rel_col = "rel" if "rel" in cols else ("relation" if "relation" in cols else None)
    elif has_source_target:
        src_col = "source_type"
        src_id_col = "source_id"
        dst_col = "target_type"
        dst_id_col = "target_id"
        rel_col = "relation" if "relation" in cols else ("rel" if "rel" in cols else None)
    else:
        raise HTTPException(status_code=500, detail={"error": "internal_error", "message": "links schema not supported"})

    tombstone_col = "tombstone" if "tombstone" in cols else None
    created_at_col = "created_at" if "created_at" in cols else None
    id_col = "id" if "id" in cols else None

    return {
        "src_col": src_col,
        "src_id_col": src_id_col,
        "dst_col": dst_col,
        "dst_id_col": dst_id_col,
        "rel_col": rel_col,
        "tombstone_col": tombstone_col,
        "created_at_col": created_at_col,
        "id_col": id_col,
    }


def _where_alive(spec: Dict[str, Optional[str]]) -> str:
    if spec.get("tombstone_col"):
        return f" AND {spec['tombstone_col']}=0"
    return ""


def _insert_link(
    conn: sqlite3.Connection,
    *,
    src_type: str,
    src_id: str,
    rel: str,
    dst_type: str,
    dst_id: str,
    tombstone: int = 0,
) -> str:
    spec = _links_spec(conn)
    cols = set(_columns(conn, "links"))
    row: Dict[str, Any] = {}

    if spec.get("id_col") in cols:
        row[str(spec["id_col"])] = new_ulid()

    row[str(spec["src_col"])] = src_type
    row[str(spec["src_id_col"])] = src_id
    row[str(spec["dst_col"])] = dst_type
    row[str(spec["dst_id_col"])] = dst_id

    if spec.get("rel_col"):
        row[str(spec["rel_col"])] = rel

    if spec.get("tombstone_col"):
        row[str(spec["tombstone_col"])] = int(tombstone)

    if spec.get("created_at_col"):
        row[str(spec["created_at_col"])] = _now_iso()

    return _insert(conn, "links", row)


# -------------------------
# Characters
# -------------------------
def _row_to_character(row: sqlite3.Row) -> Dict[str, Any]:
    d = dict(row)
    d["tags"] = _safe_json_loads(d.get("tags_json"))
    d["meta"] = _safe_json_loads(d.get("meta_json"))
    d.pop("tags_json", None)
    d.pop("meta_json", None)
    # normalize status if empty
    if not d.get("status"):
        d["status"] = "draft"
    return d


def list_characters(limit: int, offset: int, status: Optional[str] = None) -> Tuple[List[Dict[str, Any]], int]:
    conn = _connect()
    try:
        where = ""
        args: List[Any] = []
        if status:
            where = "WHERE status=?"
            args.append(status)

        total = conn.execute(f"SELECT COUNT(1) AS n FROM characters {where};", args).fetchone()["n"]
        rows = conn.execute(
            f"SELECT * FROM characters {where} ORDER BY updated_at DESC, created_at DESC LIMIT ? OFFSET ?;",
            args + [limit, offset],
        ).fetchall()
        return ([_row_to_character(r) for r in rows], int(total))
    finally:
        conn.close()


def get_character(character_id: str) -> Dict[str, Any]:
    conn = _connect()
    try:
        row = conn.execute("SELECT * FROM characters WHERE id=?;", (character_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail={"error": "not_found", "message": "character not found"})
        return _row_to_character(row)
    finally:
        conn.close()


def create_character(name: str, tags: Dict[str, Any], meta: Dict[str, Any]) -> Dict[str, Any]:
    conn = _connect()
    try:
        now = _now_iso()
        cid = _insert(
            conn,
            "characters",
            {
                "id": new_ulid(),
                "name": name,
                "status": "draft",
                "active_ref_set_id": None,
                "tags_json": json.dumps(tags or {}, ensure_ascii=False),
                "meta_json": json.dumps(meta or {}, ensure_ascii=False),
                "created_at": now,
                "updated_at": now,
            },
        )
        conn.commit()
        return get_character(cid)
    finally:
        conn.close()


# -------------------------
# RefSets
# -------------------------
def _row_to_ref_set(row: sqlite3.Row) -> Dict[str, Any]:
    d = dict(row)
    d["min_requirements_snapshot"] = _safe_json_loads(d.get("min_requirements_snapshot_json"))
    d.pop("min_requirements_snapshot_json", None)
    if not d.get("status"):
        d["status"] = "draft"
    return d


def list_ref_sets(character_id: str) -> List[Dict[str, Any]]:
    conn = _connect()
    try:
        rows = conn.execute(
            "SELECT * FROM character_ref_sets WHERE character_id=? ORDER BY version DESC, created_at DESC;",
            (character_id,),
        ).fetchall()
        return [_row_to_ref_set(r) for r in rows]
    finally:
        conn.close()


def _get_ref_set_row(conn: sqlite3.Connection, character_id: str, ref_set_id: str) -> sqlite3.Row:
    row = conn.execute(
        "SELECT * FROM character_ref_sets WHERE id=? AND character_id=?;",
        (ref_set_id, character_id),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail={"error": "not_found", "message": "ref_set not found"})
    return row


def _refs_count(conn: sqlite3.Connection, ref_set_id: str) -> int:
    spec = _links_spec(conn)
    alive = _where_alive(spec)
    sql = (
        f"SELECT COUNT(1) AS n FROM links "
        f"WHERE {spec['src_col']}=? AND {spec['src_id_col']}=? AND {spec['dst_col']}=? AND {spec['rel_col']}=?"
        f"{alive};"
    )
    row = conn.execute(sql, (TYPE_REF_SET, ref_set_id, TYPE_ASSET, REL_INCLUDES_REFERENCE_ASSET)).fetchone()
    return int(row["n"] if row else 0)


def _validate_active_ref_set(conn: sqlite3.Connection, character_id: str, ref_set_id: str) -> None:
    rs = _get_ref_set_row(conn, character_id, ref_set_id)
    if (rs["status"] or "") != "confirmed":
        raise HTTPException(status_code=400, detail={"error": "invalid_active_ref_set", "message": "active_ref_set must be confirmed"})
    n = _refs_count(conn, ref_set_id)
    if n < MIN_REFS_CONFIRMED:
        raise HTTPException(
            status_code=400,
            detail={"error": "insufficient_refs", "message": f"need >= {MIN_REFS_CONFIRMED} refs to activate", "details": {"refs": n}},
        )


def get_ref_set_detail(character_id: str, ref_set_id: str) -> Dict[str, Any]:
    conn = _connect()
    try:
        rs = _get_ref_set_row(conn, character_id, ref_set_id)
        spec = _links_spec(conn)
        alive = _where_alive(spec)

        sql = (
            f"SELECT {spec['dst_id_col']} AS asset_id "
            f"FROM links "
            f"WHERE {spec['src_col']}=? AND {spec['src_id_col']}=? AND {spec['dst_col']}=? AND {spec['rel_col']}=?"
            f"{alive} "
            f"ORDER BY rowid ASC;"
        )
        rows = conn.execute(sql, (TYPE_REF_SET, ref_set_id, TYPE_ASSET, REL_INCLUDES_REFERENCE_ASSET)).fetchall()
        refs = [str(r["asset_id"]) for r in rows]

        return {"ref_set": _row_to_ref_set(rs), "refs": refs, "refs_count": len(refs)}
    finally:
        conn.close()


def create_ref_set(
    character_id: str,
    status: str = "draft",
    base_ref_set_id: Optional[str] = None,
    min_requirements_snapshot: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    if status not in ("draft", "confirmed", "archived"):
        raise HTTPException(status_code=400, detail={"error": "bad_request", "message": "invalid status"})

    conn = _connect()
    try:
        conn.execute("BEGIN;")

        c = conn.execute("SELECT id FROM characters WHERE id=?;", (character_id,)).fetchone()
        if not c:
            raise HTTPException(status_code=404, detail={"error": "not_found", "message": "character not found"})

        base_refs: List[str] = []
        if base_ref_set_id:
            _ = _get_ref_set_row(conn, character_id, base_ref_set_id)
            spec = _links_spec(conn)
            alive = _where_alive(spec)
            sql = (
                f"SELECT {spec['dst_id_col']} AS asset_id "
                f"FROM links "
                f"WHERE {spec['src_col']}=? AND {spec['src_id_col']}=? AND {spec['dst_col']}=? AND {spec['rel_col']}=?"
                f"{alive} "
                f"ORDER BY rowid ASC;"
            )
            rows = conn.execute(sql, (TYPE_REF_SET, base_ref_set_id, TYPE_ASSET, REL_INCLUDES_REFERENCE_ASSET)).fetchall()
            base_refs = [str(r["asset_id"]) for r in rows]

        if status == "confirmed":
            if not base_ref_set_id:
                raise HTTPException(status_code=400, detail={"error": "bad_request", "message": "confirmed requires base_ref_set_id"})
            if len(base_refs) < MIN_REFS_CONFIRMED:
                raise HTTPException(
                    status_code=400,
                    detail={"error": "insufficient_refs", "message": f"need >= {MIN_REFS_CONFIRMED} refs to confirm", "details": {"refs": len(base_refs)}},
                )

        row = conn.execute(
            "SELECT COALESCE(MAX(version), 0) AS v FROM character_ref_sets WHERE character_id=?;",
            (character_id,),
        ).fetchone()
        next_ver = int(row["v"]) + 1

        now = _now_iso()
        ref_set_id = _insert(
            conn,
            "character_ref_sets",
            {
                "id": new_ulid(),
                "character_id": character_id,
                "version": next_ver,
                "status": status,
                "min_requirements_snapshot_json": json.dumps(min_requirements_snapshot or {}, ensure_ascii=False),
                "created_at": now,
            },
        )

        # link: character -> ref_set_version
        _insert_link(
            conn,
            src_type=TYPE_CHARACTER,
            src_id=character_id,
            rel=REL_HAS_REF_SET_VERSION,
            dst_type=TYPE_REF_SET,
            dst_id=ref_set_id,
            tombstone=0,
        )

        # copy refs (base -> new)
        for asset_id in base_refs:
            _insert_link(
                conn,
                src_type=TYPE_REF_SET,
                src_id=ref_set_id,
                rel=REL_INCLUDES_REFERENCE_ASSET,
                dst_type=TYPE_ASSET,
                dst_id=asset_id,
                tombstone=0,
            )

        if status == "confirmed":
            _validate_active_ref_set(conn, character_id, ref_set_id)
            conn.execute(
                "UPDATE characters SET active_ref_set_id=?, updated_at=? WHERE id=?;",
                (ref_set_id, _now_iso(), character_id),
            )

        conn.commit()

        rs = conn.execute("SELECT * FROM character_ref_sets WHERE id=?;", (ref_set_id,)).fetchone()
        return _row_to_ref_set(rs)
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(
            status_code=500,
            detail={"error": "internal_error", "message": "internal server error", "details": {"type": type(e).__name__}},
        )
    finally:
        conn.close()


def add_ref(character_id: str, ref_set_id: str, asset_id: str) -> Tuple[str, bool]:
    conn = _connect()
    try:
        conn.execute("BEGIN;")

        rs = _get_ref_set_row(conn, character_id, ref_set_id)
        if (rs["status"] or "") != "draft":
            raise HTTPException(status_code=409, detail={"error": "conflict", "message": "can only add refs to draft ref_set"})

        a = conn.execute("SELECT * FROM assets WHERE id=?;", (asset_id,)).fetchone()
        if not a:
            raise HTTPException(status_code=404, detail={"error": "not_found", "message": "asset not found"})
        if "deleted_at" in a.keys() and a["deleted_at"]:
            raise HTTPException(status_code=400, detail={"error": "bad_request", "message": "cannot reference soft-deleted asset"})

        spec = _links_spec(conn)
        alive = _where_alive(spec)

        sql = (
            f"SELECT id FROM links "
            f"WHERE {spec['src_col']}=? AND {spec['src_id_col']}=? "
            f"AND {spec['dst_col']}=? AND {spec['dst_id_col']}=? "
            f"AND {spec['rel_col']}=?"
            f"{alive} "
            f"ORDER BY rowid DESC LIMIT 1;"
        )
        existing = conn.execute(sql, (TYPE_REF_SET, ref_set_id, TYPE_ASSET, asset_id, REL_INCLUDES_REFERENCE_ASSET)).fetchone()
        if existing:
            conn.commit()
            return (str(existing["id"]), True)

        link_id = _insert_link(
            conn,
            src_type=TYPE_REF_SET,
            src_id=ref_set_id,
            rel=REL_INCLUDES_REFERENCE_ASSET,
            dst_type=TYPE_ASSET,
            dst_id=asset_id,
            tombstone=0,
        )

        conn.commit()
        return (link_id, False)
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(
            status_code=500,
            detail={"error": "internal_error", "message": "internal server error", "details": {"type": type(e).__name__}},
        )
    finally:
        conn.close()


def patch_character(character_id: str, patch: Dict[str, Any]) -> Dict[str, Any]:
    conn = _connect()
    try:
        row = conn.execute("SELECT * FROM characters WHERE id=?;", (character_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail={"error": "not_found", "message": "character not found"})

        sets: List[str] = []
        args: List[Any] = []

        if "name" in patch and patch["name"] is not None:
            sets.append("name=?")
            args.append(str(patch["name"]))

        if "tags" in patch and patch["tags"] is not None:
            sets.append("tags_json=?")
            args.append(json.dumps(patch["tags"], ensure_ascii=False))

        if "meta" in patch and patch["meta"] is not None:
            sets.append("meta_json=?")
            args.append(json.dumps(patch["meta"], ensure_ascii=False))

        if "active_ref_set_id" in patch and patch["active_ref_set_id"] is not None:
            _validate_active_ref_set(conn, character_id, str(patch["active_ref_set_id"]))
            sets.append("active_ref_set_id=?")
            args.append(str(patch["active_ref_set_id"]))

        if "status" in patch and patch["status"] is not None:
            st = str(patch["status"])
            if st not in ("draft", "confirmed", "archived"):
                raise HTTPException(status_code=400, detail={"error": "bad_request", "message": "invalid status"})
            if st == "confirmed":
                ar = patch.get("active_ref_set_id") or row["active_ref_set_id"]
                if not ar:
                    raise HTTPException(status_code=400, detail={"error": "bad_request", "message": "confirm requires active_ref_set_id"})
                _validate_active_ref_set(conn, character_id, str(ar))
            sets.append("status=?")
            args.append(st)

        if not sets:
            return _row_to_character(row)

        sets.append("updated_at=?")
        args.append(_now_iso())

        args.append(character_id)
        conn.execute(f"UPDATE characters SET {', '.join(sets)} WHERE id=?;", args)
        conn.commit()

        row2 = conn.execute("SELECT * FROM characters WHERE id=?;", (character_id,)).fetchone()
        return _row_to_character(row2)
    finally:
        conn.close()
