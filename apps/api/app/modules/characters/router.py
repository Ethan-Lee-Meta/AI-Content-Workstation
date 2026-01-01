from __future__ import annotations

from fastapi import APIRouter, Query, Path
from .schemas import (
    CharactersListOut,
    CharacterCreateIn,
    CharacterDetailOut,
    CharacterOut,
    CharacterPatchIn,
    CharacterRefSetCreateIn,
    CharacterRefSetDetailOut,
    CharacterRefSetOut,
    PageOut,
    RefAddIn,
    RefAddOut,
)
from .service import (
    add_ref,
    create_character,
    create_ref_set,
    get_character,
    get_ref_set_detail,
    list_characters,
    list_ref_sets,
    patch_character,
)

router = APIRouter(tags=["characters"])


def _clamp_limit(raw: int | None) -> int:
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


@router.get("/characters", response_model=CharactersListOut)
def api_list_characters(
    limit: int | None = Query(None),
    offset: int | None = Query(None),
    status: str | None = Query(None, description="draft|confirmed|archived"),
) -> CharactersListOut:
    lim = _clamp_limit(limit)
    off = _clamp_offset(offset)
    items, total = list_characters(limit=lim, offset=off, status=status)
    has_more = (off + lim) < total
    return CharactersListOut(items=items, page=PageOut(offset=off, limit=lim, total=total, has_more=has_more))


@router.post("/characters", response_model=CharacterOut)
def api_create_character(body: CharacterCreateIn) -> CharacterOut:
    return create_character(name=body.name, tags=body.tags, meta=body.meta)


@router.get("/characters/{character_id}", response_model=CharacterDetailOut)
def api_get_character(character_id: str = Path(...)) -> CharacterDetailOut:
    c = get_character(character_id)
    ref_sets = list_ref_sets(character_id)
    active = None
    if c.get("active_ref_set_id"):
        active = get_ref_set_detail(character_id, c["active_ref_set_id"])
    return CharacterDetailOut(character=c, ref_sets=ref_sets, active_ref_set=active)


@router.patch("/characters/{character_id}", response_model=CharacterOut)
def api_patch_character(character_id: str, body: CharacterPatchIn) -> CharacterOut:
    return patch_character(character_id, body.model_dump(exclude_unset=True))


@router.post("/characters/{character_id}/ref_sets", response_model=CharacterRefSetOut)
def api_create_ref_set(character_id: str, body: CharacterRefSetCreateIn) -> CharacterRefSetOut:
    return create_ref_set(
        character_id=character_id,
        status=body.status,
        base_ref_set_id=body.base_ref_set_id,
        min_requirements_snapshot=body.min_requirements_snapshot,
    )


@router.get("/characters/{character_id}/ref_sets/{ref_set_id}", response_model=CharacterRefSetDetailOut)
def api_get_ref_set_detail(character_id: str, ref_set_id: str) -> CharacterRefSetDetailOut:
    d = get_ref_set_detail(character_id, ref_set_id)
    return CharacterRefSetDetailOut(**d)


@router.post("/characters/{character_id}/ref_sets/{ref_set_id}/refs", response_model=RefAddOut)
def api_add_ref(character_id: str, ref_set_id: str, body: RefAddIn) -> RefAddOut:
    link_id, already = add_ref(character_id=character_id, ref_set_id=ref_set_id, asset_id=body.asset_id)
    return RefAddOut(link_id=link_id, already_linked=already)
