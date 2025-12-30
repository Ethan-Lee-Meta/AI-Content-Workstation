from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query


from .schemas import AssetDetailOut, AssetListOut, PageOut

from .service import get_asset, list_assets, traceability_for_asset


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
    return AssetDetailOut(asset=asset, traceability=trace)

