from __future__ import annotations

from fastapi import HTTPException
from datetime import datetime

import os
import sqlite3
from typing import Any, Dict, List, Optional, Tuple

DEFAULT_DATABASE_URL = "sqlite:///./data/app.db"


def _sqlite_path_from_url(url: str) -> str:
    # Supports:
    # - sqlite:///./data/app.db
    # - sqlite:////absolute/path/app.db
    if not url.startswith("sqlite:"):
        raise ValueError(f"Only sqlite is supported for now, got DATABASE_URL={url!r}")
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


def _table_exists(conn: sqlite3.Connection, table: str) -> bool:
    row = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        (table,),
    ).fetchone()
    return row is not None


def _columns(conn: sqlite3.Connection, table: str) -> List[str]:
    rows = conn.execute(f"PRAGMA table_info({table})").fetchall()
    return [r["name"] for r in rows]


def _order_by_expr(cols: List[str]) -> str:
    if "created_at" in cols:
        return "created_at DESC"
    if "id" in cols:
        return "id DESC"
    return "rowid DESC"


def _row_to_asset_dict(row: sqlite3.Row, cols: List[str]) -> Dict[str, Any]:
    # Only fields known by schemas.AssetDTO (avoid unknown keys causing drift)
    keep = [
        "id",
        "type",
        "created_at",
        "deleted_at",
        "project_id",
        "series_id",
        "storage_path",
        "mime_type",
        "width",
        "height",
        "duration_ms",
    ]
    out: Dict[str, Any] = {}
    for k in keep:
        if k in cols:
            out[k] = row[k]

    # best-effort legacy mappings (if present)
    if "storage_uri" in cols and "storage_path" not in out:
        out["storage_path"] = row["storage_uri"]
    if "path" in cols and "storage_path" not in out:
        out["storage_path"] = row["path"]

    return out


def list_assets(limit: int, offset: int, include_deleted: bool) -> Tuple[List[Dict[str, Any]], int]:
    conn = _connect()
    try:
        if not _table_exists(conn, "assets"):
            raise RuntimeError("DB missing table: assets")

        cols = _columns(conn, "assets")

        where = ""
        params: List[Any] = []
        if (not include_deleted) and ("deleted_at" in cols):
            where = "WHERE deleted_at IS NULL"

        total = conn.execute(f"SELECT COUNT(1) AS c FROM assets {where}", params).fetchone()["c"]

        order_by = _order_by_expr(cols)
        rows = conn.execute(
            f"SELECT * FROM assets {where} ORDER BY {order_by} LIMIT ? OFFSET ?",
            (*params, limit, offset),
        ).fetchall()
        items = [_row_to_asset_dict(r, cols) for r in rows]
        return items, int(total)
    finally:
        conn.close()


def get_asset(asset_id: str) -> Optional[Dict[str, Any]]:
    conn = _connect()
    try:
        if not _table_exists(conn, "assets"):
            raise RuntimeError("DB missing table: assets")
        cols = _columns(conn, "assets")
        row = conn.execute("SELECT * FROM assets WHERE id = ? LIMIT 1", (asset_id,)).fetchone()
        if row is None:
            return None
        return _row_to_asset_dict(row, cols)
    finally:
        conn.close()


def traceability_for_asset(asset_id: str) -> Dict[str, Any]:
    """
    Minimal traceability summary:
    - links: up to 200 rows from links table that reference this asset
    - related: id map (best-effort) extracted from link endpoints
    Degrades safely if links table/schema not present.
    """
    conn = _connect()
    try:
        if not _table_exists(conn, "links"):
            return {"links": [], "related": {}}

        cols = _columns(conn, "links")
        # Check for actual column names used in the database (src_type/dst_type or source_type/target_type)
        has_src_dst = {"src_type", "src_id", "dst_type", "dst_id"}.issubset(set(cols))
        has_source_target = {"source_type", "source_id", "target_type", "target_id"}.issubset(set(cols))
        
        if not has_src_dst and not has_source_target:
            return {"links": [], "related": {}}

        # Use the correct column names based on what's in the database
        if has_src_dst:
            src_col = "src_type"
            src_id_col = "src_id"
            dst_col = "dst_type"
            dst_id_col = "dst_id"
            rel_col = "rel"
        else:
            src_col = "source_type"
            src_id_col = "source_id"
            dst_col = "target_type"
            dst_id_col = "target_id"
            rel_col = "relation"

        rows = conn.execute(
            f"""
            SELECT * FROM links
            WHERE ({src_col} = ? AND {src_id_col} = ?)
               OR ({dst_col} = ? AND {dst_id_col} = ?)
            ORDER BY rowid DESC
            LIMIT 200
            """,
            ("asset", asset_id, "asset", asset_id),
        ).fetchall()

        links: List[Dict[str, Any]] = []
        related: Dict[str, List[str]] = {}

        def add_related(t: str, i: str) -> None:
            key = f"{t}_ids"
            arr = related.setdefault(key, [])
            if i not in arr:
                arr.append(i)

        for r in rows:
            d: Dict[str, Any] = {}
            # Map to output format (always use source/target in output for consistency)
            for k in ["id", "created_at"]:
                if k in cols:
                    d[k] = r[k]
            
            # Map src/dst to source/target in output
            if has_src_dst:
                d["source_type"] = r[src_col]
                d["source_id"] = r[src_id_col]
                d["target_type"] = r[dst_col]
                d["target_id"] = r[dst_id_col]
                d["relation"] = r[rel_col]
            else:
                d["source_type"] = r[src_col]
                d["source_id"] = r[src_id_col]
                d["target_type"] = r[dst_col]
                d["target_id"] = r[dst_id_col]
                d["relation"] = r[rel_col]
            
            links.append(d)

            # Extract values for related items
            st = r[src_col]
            sid = r[src_id_col]
            tt = r[dst_col]
            tid = r[dst_id_col]
            if st and sid:
                add_related(st, sid)
            if tt and tid:
                add_related(tt, tid)

        return {"links": links, "related": related}
    finally:
        conn.close()

def soft_delete_asset(asset_id: str, request_id: Optional[str] = None, action: str = "delete") -> dict:
    """
    Soft delete / restore (idempotent), without changing links:
    - action=delete: set assets.deleted_at = <UTC ISO8601 'Z'> if NULL
    - action=restore: set assets.deleted_at = NULL if not NULL
    Notes:
    - request_id is accepted for logging/threading but not required in success payload
    """
    act = (action or "delete").strip().lower()
    if act not in ("delete", "restore"):
        raise HTTPException(status_code=400, detail=f"Invalid action: {action!r}. Expected 'delete' or 'restore'.")

    conn = _connect()
    try:
        if not _table_exists(conn, "assets"):
            raise RuntimeError("DB missing table: assets")

        cols = _columns(conn, "assets")

        # Pick id column defensively
        if "id" in cols:
            id_col = "id"
        elif "asset_id" in cols:
            id_col = "asset_id"
        else:
            raise RuntimeError("assets table missing id column (id/asset_id)")

        if "deleted_at" not in cols:
            raise RuntimeError("assets table missing deleted_at (soft delete invariant broken)")

        row = conn.execute(
            f"SELECT deleted_at FROM assets WHERE {id_col} = ? LIMIT 1",
            (asset_id,),
        ).fetchone()

        if row is None:
            raise HTTPException(status_code=404, detail=f"Asset not found: {asset_id}")

        existing = row["deleted_at"]

        if act == "delete":
            already = existing is not None
            if not already:
                ts = datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
                conn.execute(
                    f"UPDATE assets SET deleted_at = ? WHERE {id_col} = ?",
                    (ts, asset_id),
                )
                conn.commit()
                deleted_at = ts
            else:
                deleted_at = existing
            return {
                "asset_id": asset_id,
                "deleted_at": deleted_at,
                "already_deleted": already,
                "status": "deleted",
            }

        # act == "restore"
        already = existing is None
        if not already:
            conn.execute(
                f"UPDATE assets SET deleted_at = NULL WHERE {id_col} = ?",
                (asset_id,),
            )
            conn.commit()

        return {
            "asset_id": asset_id,
            "deleted_at": None,
            # 兼容旧字段名：这里表示“已在目标态(未删除)”的幂等 no-op
            "already_deleted": already,
            "status": "restored",
        }
    finally:
        conn.close()
