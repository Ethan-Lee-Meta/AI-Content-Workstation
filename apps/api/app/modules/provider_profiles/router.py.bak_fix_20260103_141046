from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query, Request

from app.modules.assets.schemas import PageOut

from .schemas import (
    ProviderTypesOut,
    ProviderProfilesListOut,
    ProviderProfileDTO,
    ProviderProfileCreateIn,
    ProviderProfilePatchIn,
    ProviderProfileDeleteOut,
)
from .service import (
    list_provider_types,
    list_provider_profiles,
    get_provider_profile,
    create_provider_profile,
    patch_provider_profile,
    scrub_provider_profile,
)

router = APIRouter(tags=["provider_profiles"])


def _clamp_limit(raw: int | None) -> int:
    # lock: default=50, max=200
    if raw is None:
        return 50
    try:
        v = int(raw)
    except Exception:
        return 50
    if v <= 0:
        return 50
    if v > 200:
        return 200
    return v


@router.get("/provider_types", response_model=ProviderTypesOut)
def get_provider_types() -> ProviderTypesOut:
    items = list_provider_types()
    return ProviderTypesOut(items=items)


@router.get("/provider_profiles", response_model=ProviderProfilesListOut)
def list_profiles(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> ProviderProfilesListOut:
    limit2 = _clamp_limit(limit)
    items, total = list_provider_profiles(limit=limit2, offset=offset)
    page = PageOut(
        limit=limit2,
        offset=offset,
        total=total,
        has_more=(offset + limit2) < total,
    )
    return ProviderProfilesListOut(items=items, page=page)


@router.post("/provider_profiles", response_model=ProviderProfileDTO)
def create_profile(body: ProviderProfileCreateIn, request: Request) -> ProviderProfileDTO:
    # request_id 由 main.py 注入并在 error envelope 中回写；此处仅作为服务侧可用参数
    _ = getattr(getattr(request, "state", None), "request_id", None)

    out = create_provider_profile(
        name=body.name,
        provider_type=body.provider_type,
        config=body.config or {},
        secrets_redaction_policy=body.secrets_redaction_policy or {},
        set_global_default=bool(body.set_global_default),
    )
    return ProviderProfileDTO(**out)


@router.get("/provider_profiles/{profile_id}", response_model=ProviderProfileDTO)
def get_profile(profile_id: str) -> ProviderProfileDTO:
    p = get_provider_profile(profile_id, redact=True)
    if p is None:
        raise HTTPException(status_code=404, detail=f"ProviderProfile not found: {profile_id}")
    return ProviderProfileDTO(**p)


@router.patch("/provider_profiles/{profile_id}", response_model=ProviderProfileDTO)
def patch_profile(profile_id: str, body: ProviderProfilePatchIn) -> ProviderProfileDTO:
    p = patch_provider_profile(
        profile_id,
        name=body.name,
        config=body.config,
        secrets_redaction_policy=body.secrets_redaction_policy,
        set_global_default=body.set_global_default,
    )
    if p is None:
        raise HTTPException(status_code=404, detail=f"ProviderProfile not found: {profile_id}")
    return ProviderProfileDTO(**p)


@router.delete("/provider_profiles/{profile_id}", response_model=ProviderProfileDeleteOut)
def delete_profile(profile_id: str) -> ProviderProfileDeleteOut:
    p = scrub_provider_profile(profile_id)
    if p is None:
        raise HTTPException(status_code=404, detail=f"ProviderProfile not found: {profile_id}")
    return ProviderProfileDeleteOut(id=p["id"], is_global_default=bool(p.get("is_global_default", False)))
