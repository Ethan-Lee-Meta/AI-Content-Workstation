from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query, Request

from .schemas import AssetDeleteResponse, AssetDetailOut, AssetListOut, PageOut
from .service import get_asset, list_assets, soft_delete_asset, traceability_for_asset
from app.modules.runs.service import get_prompt_pack_payload
from app.modules.runs.service import resolve_provider_profile
from app.modules.runs.service import _connect as _runs_connect

router = APIRouter(tags=["assets"])


def _clamp_limit(raw: int | None) -> int:
    # lock: default=50, max=200
    if raw is None:
        return 50
    try:
        v = int(raw)
    except Exception:
        return 50
    if v < 1:
        v = 1
    if v > 200:
        v = 200
    return v


def _clamp_offset(raw: int | None) -> int:
    if raw is None:
        return 0
    try:
        v = int(raw)
    except Exception:
        return 0
    return max(v, 0)


@router.get("/assets", response_model=AssetListOut)
def get_assets(
    limit: int | None = Query(None, description="Max items to return (default 50, max 200)"),
    offset: int | None = Query(None, description="Offset from start (default 0)"),
    include_deleted: bool = Query(False, description="Include soft-deleted assets"),
) -> AssetListOut:
    lim = _clamp_limit(limit)
    off = _clamp_offset(offset)

    items, total = list_assets(limit=lim, offset=off, include_deleted=include_deleted)
    has_more = (off + lim) < total

    return AssetListOut(
        items=items,  # Pydantic will coerce dict -> AssetDTO
        page=PageOut(limit=lim, offset=off, total=total, has_more=has_more),
    )


@router.get("/assets/{asset_id}", response_model=AssetDetailOut)
def get_asset_detail(asset_id: str) -> AssetDetailOut:
    asset = get_asset(asset_id)
    if asset is None:
        # main.py should wrap HTTPException into error_envelope
        raise HTTPException(status_code=404, detail=f"Asset not found: {asset_id}")

    trace = traceability_for_asset(asset_id)

    # ---- 2C.7 trace chain enrichment (best-effort; never fail the endpoint)
    try:
        import json, sqlite3
    
        # find produced_asset link -> run_id (from traceability_for_asset output shape)
        run_id = None
        for lk in (trace.get("links") or []):
            rel = lk.get("relation") or lk.get("rel")
            if rel != "produced_asset":
                continue
            if lk.get("source_type") == "run" and lk.get("target_type") == "asset" and lk.get("target_id") == asset_id:
                run_id = lk.get("source_id")
                break
            if lk.get("target_type") == "run" and lk.get("source_type") == "asset" and lk.get("source_id") == asset_id:
                run_id = lk.get("target_id")
                break
    
        if run_id:
            conn = _runs_connect()
            try:
                def _table_info(table: str):
                    cur = conn.execute(f"PRAGMA table_info({table});")
                    rows = cur.fetchall() or []
                    # rows: (cid, name, type, notnull, dflt_value, pk)
                    cols = [r[1] for r in rows]
                    pk = None
                    for r in rows:
                        if len(r) >= 6 and r[5] == 1:
                            pk = r[1]
                            break
                    return cols, pk
    
                def _fetch_one_dict(sql: str, params: tuple):
                    cur = conn.execute(sql, params)
                    row = cur.fetchone()
                    if row is None:
                        return {}
                    if isinstance(row, sqlite3.Row):
                        return dict(row)
                    # tuple row -> dict via cursor.description
                    return {cur.description[i][0]: row[i] for i in range(len(cur.description))}
    
                # --- runs row (robust id column)
                run_cols, run_pk = _table_info("runs")
                run_id_col = run_pk or ("id" if "id" in run_cols else ("run_id" if "run_id" in run_cols else None))
                run_row = _fetch_one_dict(f"SELECT * FROM runs WHERE {run_id_col}=? LIMIT 1", (run_id,)) if run_id_col else {}
                run_status = run_row.get("status")
    
                # --- links by run (src/dst vs source/target)
                link_cols, _ = _table_info("links")
                has_src_dst = {"src_type","src_id","dst_type","dst_id","rel"}.issubset(set(link_cols))
                if has_src_dst:
                    src_type, src_id, dst_type, dst_id, rel_col = "src_type","src_id","dst_type","dst_id","rel"
                else:
                    src_type, src_id, dst_type, dst_id, rel_col = "source_type","source_id","target_type","target_id","relation"
    
                cur = conn.execute(
                    f"SELECT * FROM links WHERE {src_type}=? AND {src_id}=? ORDER BY rowid DESC LIMIT 200",
                    ("run", run_id),
                )
                ldicts = []
                for row in (cur.fetchall() or []):
                    if isinstance(row, sqlite3.Row):
                        ldicts.append(dict(row))
                    else:
                        ldicts.append({cur.description[i][0]: row[i] for i in range(len(cur.description))})
    
                # --- prompt_pack_id: from run row or links
                prompt_pack_id = ""
                for k in ("prompt_pack_id","promptpack_id","prompt_pack_ulid"):
                    if run_row.get(k):
                        prompt_pack_id = str(run_row.get(k))
                        break
                if not prompt_pack_id:
                    for lr in ldicts:
                        if str(lr.get(rel_col)) == "uses_prompt_pack" and str(lr.get(dst_type)) == "prompt_pack":
                            prompt_pack_id = str(lr.get(dst_id) or "")
                            break
    
                # --- characters: from links (no meta_json in schema; keep minimal)
                characters = []
                seen = set()
                for lr in ldicts:
                    if str(lr.get(rel_col)) == "uses_character" and str(lr.get(dst_type)) == "character":
                        cid = str(lr.get(dst_id) or "")
                        if cid and cid not in seen:
                            seen.add(cid)
                            characters.append({"character_id": cid})
    
                # --- provider profile snapshot (best-effort)
                provider_snapshot = {}
                prov_id = ""
                for lr in ldicts:
                    if str(lr.get(rel_col)) == "uses_provider_profile" and str(lr.get(dst_type)) == "provider_profile":
                        prov_id = str(lr.get(dst_id) or "")
                        break
                if prov_id:
                    pp_cols, pp_pk = _table_info("provider_profiles")
                    pp_id_col = pp_pk or ("id" if "id" in pp_cols else None)
                    prow = _fetch_one_dict(f"SELECT * FROM provider_profiles WHERE {pp_id_col}=? LIMIT 1", (prov_id,)) if pp_id_col else {}
                    provider_snapshot = {
                        "id": prov_id,
                        "name": prow.get("name") or "",
                        "provider_type": prow.get("provider_type") or "",
                    }
    
                # --- prompt pack payload (v1.1): use runs.service.get_prompt_pack_payload()
    
                prompt_pack = get_prompt_pack_payload(prompt_pack_id) if prompt_pack_id else {}

    
                trace["chain"] = {
                    "run": {"run_id": run_id, "status": run_status},
                    "prompt_pack": {
                        "raw_input": prompt_pack.get("raw_input"),
                        "assembly_prompt": prompt_pack.get("assembly_prompt"),
                        "final_prompt": prompt_pack.get("final_prompt"),
                        "assembly_used": prompt_pack.get("assembly_used"),
                    },
                    "provider_profile": provider_snapshot,
                    "characters": characters,
                }
            finally:
                try:
                    conn.close()
                except Exception:
                    pass
    except Exception:
        pass

    return AssetDetailOut(asset=asset, traceability=trace)


@router.delete("/assets/{asset_id}", response_model=AssetDeleteResponse)
def delete_asset(asset_id: str, request: Request, action: str = Query("delete", description="Action: delete|restore")) -> AssetDeleteResponse:
    """Soft delete (idempotent)."""
    rid = getattr(getattr(request, "state", None), "request_id", None)
    return soft_delete_asset(asset_id=asset_id, request_id=rid, action=action)
