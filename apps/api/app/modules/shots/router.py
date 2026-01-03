from __future__ import annotations

import os
import uuid
import sqlite3
from datetime import datetime, timezone
from typing import Any, Dict, List, Tuple

from fastapi import APIRouter, Query, Path, Body, Request, Response
from fastapi.responses import JSONResponse

from app.modules.shots.schemas import (
    ShotsListOut,
    ShotListItem,
    ShotDetailOut,
    ShotOut,
    LinkedRefsSummary,
    ShotLinkCreateIn,
    ShotLinkCreateOut,
    ShotLinkDeleteOut,
)

router = APIRouter(tags=["shots"])


# -------------------------
# Small utilities (local)
# -------------------------
LIMIT_DEFAULT = 50
LIMIT_MAX = 200
UNLINK_PREFIX = "unlink::"


def _utcnow_iso() -> str:
    # ISO-8601 with Z; lexicographically sortable.
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _request_id(request: Request) -> str:
    rid = request.headers.get("X-Request-Id")
    if rid and rid.strip():
        return rid.strip()
    return uuid.uuid4().hex.upper()


def _err(rid: str, status: int, error: str, message: str, details: Any = None) -> JSONResponse:
    return JSONResponse(
        status_code=status,
        content={
            "error": error,
            "message": message,
            "request_id": rid,
            "details": details if details is not None else {},
        },
        headers={"X-Request-Id": rid},
    )


def _sqlite_path_from_url(url: str) -> str:
    # Expected default: sqlite:///./data/app.db
    if url.startswith("sqlite:///"):
        return url[len("sqlite:///") :]
    if url.startswith("sqlite://"):
        return url[len("sqlite://") :]
    raise ValueError(f"unsupported DATABASE_URL scheme: {url}")


def _conn() -> sqlite3.Connection:
    url = os.getenv("DATABASE_URL", "sqlite:///./data/app.db")
    path = _sqlite_path_from_url(url)
    c = sqlite3.connect(path, check_same_thread=False)
    c.row_factory = sqlite3.Row
    return c


def _clamp_limit(limit: int) -> int:
    if limit <= 0:
        return LIMIT_DEFAULT
    if limit > LIMIT_MAX:
        return LIMIT_MAX
    return limit


def _normalize_type(t: str) -> str:
    return (t or "").strip().lower()


TYPE_TO_TABLE = {
    "asset": "assets",
    "assets": "assets",
    "run": "runs",
    "runs": "runs",
    "prompt_pack": "prompt_packs",
    "prompt_packs": "prompt_packs",
    "project": "projects",
    "projects": "projects",
    "series": "series",
    "shot": "shots",
    "shots": "shots",
}

DSTTYPE_TO_BUCKET = {
    "asset": ("assets", "asset_id"),
    "assets": ("assets", "asset_id"),
    "run": ("runs", "run_id"),
    "runs": ("runs", "run_id"),
    "prompt_pack": ("prompt_packs", "prompt_pack_id"),
    "prompt_packs": ("prompt_packs", "prompt_pack_id"),
    "series": ("series", "series_id"),
    "project": ("projects", "project_id"),
    "projects": ("projects", "project_id"),
}


def _shot_exists(cur: sqlite3.Cursor, shot_id: str) -> bool:
    row = cur.execute("SELECT 1 FROM shots WHERE id=? LIMIT 1", (shot_id,)).fetchone()
    return row is not None


def _target_exists(cur: sqlite3.Cursor, dst_type: str, dst_id: str) -> bool:
    t = _normalize_type(dst_type)
    table = TYPE_TO_TABLE.get(t)
    if not table:
        # Unknown dst_type: allow (link can be an external reference)
        return True
    row = cur.execute(f"SELECT 1 FROM {table} WHERE id=? LIMIT 1", (dst_id,)).fetchone()
    return row is not None


def _effective_links(rows: List[sqlite3.Row]) -> List[Dict[str, str]]:
    """
    Apply append-only 'tombstone' semantics:
    - Normal link: rel = <rel>
    - Tombstone:  rel = unlink::<rel>
    Effective edge is kept only if the latest event for (dst_type,dst_id,base_rel) is NOT tombstone.
    """
    latest: Dict[Tuple[str, str, str], Tuple[str, str]] = {}
    # key -> (created_at, rel)
    for r in rows:
        rel = (r["rel"] or "").strip()
        created_at = (r["created_at"] or "").strip()
        dst_type = (r["dst_type"] or "").strip()
        dst_id = (r["dst_id"] or "").strip()

        if not dst_type or not dst_id or not rel:
            continue

        if rel.startswith(UNLINK_PREFIX):
            base_rel = rel[len(UNLINK_PREFIX) :]
        else:
            base_rel = rel

        k = (dst_type, dst_id, base_rel)

        prev = latest.get(k)
        if prev is None or created_at >= prev[0]:
            latest[k] = (created_at, rel)

    out: List[Dict[str, str]] = []
    for (dst_type, dst_id, base_rel), (created_at, rel) in latest.items():
        if rel.startswith(UNLINK_PREFIX):
            continue
        out.append({"dst_type": dst_type, "dst_id": dst_id, "rel": base_rel})
    return out


@router.get("/shots", response_model=ShotsListOut)
def shots_list(
    request: Request,
    response: Response,
    offset: int = Query(0, ge=0),
    limit: int = Query(LIMIT_DEFAULT, ge=1),
    project_id: str | None = Query(default=None),
    series_id: str | None = Query(default=None),
):
    rid = _request_id(request)
    response.headers["X-Request-Id"] = rid

    lim = _clamp_limit(limit)

    where = []
    args: List[Any] = []

    if project_id is not None and project_id != "":
        where.append("project_id = ?")
        args.append(project_id)

    if series_id is not None and series_id != "":
        where.append("series_id = ?")
        args.append(series_id)

    where_sql = ("WHERE " + " AND ".join(where)) if where else ""

    try:
        con = _conn()
        cur = con.cursor()

        total = cur.execute(f"SELECT COUNT(1) AS c FROM shots {where_sql}", tuple(args)).fetchone()["c"]
        rows = cur.execute(
            f"""
            SELECT id, project_id, series_id, name, created_at
            FROM shots
            {where_sql}
            ORDER BY created_at DESC
            LIMIT ? OFFSET ?
            """,
            tuple(args + [lim, offset]),
        ).fetchall()

        items = [
            ShotListItem(
                shot_id=r["id"],
                project_id=r["project_id"],
                series_id=r["series_id"],
                name=r["name"],
                created_at=r["created_at"],
            )
            for r in rows
        ]

        has_more = (offset + lim) < int(total)

        return {
            "items": items,
            "page": {"limit": lim, "offset": offset, "total": int(total), "has_more": bool(has_more)},
        }
    except Exception as e:
        return _err(rid, 500, "internal_error", "internal server error", {"type": type(e).__name__})
    finally:
        try:
            con.close()  # type: ignore
        except Exception:
            pass


@router.get("/shots/{shot_id}", response_model=ShotDetailOut)
def shots_detail(
    request: Request,
    response: Response,
    shot_id: str = Path(..., min_length=1),
):
    rid = _request_id(request)
    response.headers["X-Request-Id"] = rid

    try:
        con = _conn()
        cur = con.cursor()

        s = cur.execute(
            "SELECT id, project_id, series_id, name, created_at FROM shots WHERE id=? LIMIT 1",
            (shot_id,),
        ).fetchone()

        if s is None:
            return _err(rid, 404, "not_found", "shot not found", {"shot_id": shot_id})

        link_rows = cur.execute(
            """
            SELECT id, dst_type, dst_id, rel, created_at
            FROM links
            WHERE src_type=? AND src_id=?
            ORDER BY created_at ASC
            """,
            ("shot", shot_id),
        ).fetchall()

        effective = _effective_links(link_rows)

        buckets = LinkedRefsSummary()
        for it in effective:
            t = _normalize_type(it["dst_type"])
            dst_id = it["dst_id"]

            if t in DSTTYPE_TO_BUCKET:
                bucket_name, id_key = DSTTYPE_TO_BUCKET[t]
                getattr(buckets, bucket_name).append({id_key: dst_id})
            else:
                buckets.other.append({"dst_type": it["dst_type"], "dst_id": dst_id})

        return {
            "shot": ShotOut(
                shot_id=s["id"],
                project_id=s["project_id"],
                series_id=s["series_id"],
                name=s["name"],
                created_at=s["created_at"],
            ),
            "linked_refs": buckets,
        }
    except Exception as e:
        return _err(rid, 500, "internal_error", "internal server error", {"type": type(e).__name__})
    finally:
        try:
            con.close()  # type: ignore
        except Exception:
            pass


@router.post("/shots/{shot_id}/links", response_model=ShotLinkCreateOut)
def shot_link_create(
    request: Request,
    response: Response,
    shot_id: str = Path(..., min_length=1),
    payload: ShotLinkCreateIn = Body(...),
):
    rid = _request_id(request)
    response.headers["X-Request-Id"] = rid

    dst_type = (payload.dst_type or "").strip()
    dst_id = (payload.dst_id or "").strip()
    rel = (payload.rel or "").strip()

    if not dst_type or not dst_id or not rel:
        return _err(rid, 400, "bad_request", "dst_type/dst_id/rel are required", {"field": "payload"})

    if rel.startswith(UNLINK_PREFIX):
        return _err(rid, 400, "bad_request", "rel cannot start with reserved prefix 'unlink::'", {"rel": rel})

    try:
        con = _conn()
        cur = con.cursor()

        if not _shot_exists(cur, shot_id):
            return _err(rid, 404, "not_found", "shot not found", {"shot_id": shot_id})

        if not _target_exists(cur, dst_type, dst_id):
            return _err(rid, 404, "not_found", "target not found", {"dst_type": dst_type, "dst_id": dst_id})

        link_id = uuid.uuid4().hex.upper()
        created_at = _utcnow_iso()

        cur.execute(
            """
            INSERT INTO links (id, src_type, src_id, dst_type, dst_id, rel, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (link_id, "shot", shot_id, dst_type, dst_id, rel, created_at),
        )
        con.commit()

        return {
            "link_id": link_id,
            "src_type": "shot",
            "src_id": shot_id,
            "dst_type": dst_type,
            "dst_id": dst_id,
            "rel": rel,
            "created_at": created_at,
        }
    except Exception as e:
        # Note: links are append-only (no update/delete). Inserts should succeed; if not, surface envelope.
        return _err(rid, 500, "internal_error", "internal server error", {"type": type(e).__name__})
    finally:
        try:
            con.close()  # type: ignore
        except Exception:
            pass


@router.delete("/shots/{shot_id}/links/{link_id}", response_model=ShotLinkDeleteOut)
def shot_link_delete_tombstone(
    request: Request,
    response: Response,
    shot_id: str = Path(..., min_length=1),
    link_id: str = Path(..., min_length=1),
):
    """
    Delete semantics under append-only policy:
    - DO NOT delete from links table (SQLite trigger forbids DELETE).
    - Create a tombstone link: rel = unlink::<original_rel>, same dst_type/dst_id.
    """
    rid = _request_id(request)
    response.headers["X-Request-Id"] = rid

    try:
        con = _conn()
        cur = con.cursor()

        row = cur.execute(
            """
            SELECT id, src_type, src_id, dst_type, dst_id, rel
            FROM links
            WHERE id=? LIMIT 1
            """,
            (link_id,),
        ).fetchone()

        if row is None:
            return _err(rid, 404, "not_found", "link not found", {"link_id": link_id})

        if row["src_type"] != "shot" or row["src_id"] != shot_id:
            return _err(
                rid,
                404,
                "not_found",
                "link not found for this shot",
                {"shot_id": shot_id, "link_id": link_id},
            )

        original_rel = (row["rel"] or "").strip()
        if not original_rel:
            return _err(rid, 409, "conflict", "invalid link rel", {"link_id": link_id})

        if original_rel.startswith(UNLINK_PREFIX):
            return _err(rid, 409, "conflict", "cannot tombstone a tombstone link", {"link_id": link_id})

        tombstone_rel = f"{UNLINK_PREFIX}{original_rel}"
        tombstone_id = uuid.uuid4().hex.upper()
        created_at = _utcnow_iso()

        cur.execute(
            """
            INSERT INTO links (id, src_type, src_id, dst_type, dst_id, rel, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (tombstone_id, "shot", shot_id, row["dst_type"], row["dst_id"], tombstone_rel, created_at),
        )
        con.commit()

        return {
            "target_link_id": link_id,
            "tombstone_link_id": tombstone_id,
            "tombstone_rel": tombstone_rel,
            "created_at": created_at,
        }
    except Exception as e:
        return _err(rid, 500, "internal_error", "internal server error", {"type": type(e).__name__})
    finally:
        try:
            con.close()  # type: ignore
        except Exception:
            pass
