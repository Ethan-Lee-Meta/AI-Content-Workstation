from __future__ import annotations

from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field

# Prefer reusing the canonical PageOut from assets to avoid pagination drift.
try:
    from app.modules.assets.schemas import PageOut  # type: ignore
except Exception:
    class PageOut(BaseModel):
        limit: int
        offset: int
        total: int
        has_more: bool


class ShotListItem(BaseModel):
    shot_id: str
    project_id: Optional[str] = None
    series_id: Optional[str] = None
    name: Optional[str] = None
    created_at: str


class ShotsListOut(BaseModel):
    items: List[ShotListItem]
    page: PageOut


class LinkedRefsSummary(BaseModel):
    assets: List[Dict[str, str]] = Field(default_factory=list)        # [{"asset_id": "..."}]
    runs: List[Dict[str, str]] = Field(default_factory=list)          # [{"run_id": "..."}]
    prompt_packs: List[Dict[str, str]] = Field(default_factory=list)  # [{"prompt_pack_id": "..."}]
    series: List[Dict[str, str]] = Field(default_factory=list)        # [{"series_id": "..."}]
    projects: List[Dict[str, str]] = Field(default_factory=list)      # [{"project_id": "..."}]
    other: List[Dict[str, str]] = Field(default_factory=list)         # [{"dst_type": "...", "dst_id": "..."}]


class ShotOut(BaseModel):
    shot_id: str
    project_id: Optional[str] = None
    series_id: Optional[str] = None
    name: Optional[str] = None
    created_at: str


class ShotDetailOut(BaseModel):
    shot: ShotOut
    linked_refs: LinkedRefsSummary


class ShotLinkCreateIn(BaseModel):
    dst_type: str = Field(..., min_length=1)
    dst_id: str = Field(..., min_length=1)
    rel: str = Field(default="refs", min_length=1)


class ShotLinkCreateOut(BaseModel):
    link_id: str
    src_type: str
    src_id: str
    dst_type: str
    dst_id: str
    rel: str
    created_at: str


class ShotLinkDeleteOut(BaseModel):
    target_link_id: str
    tombstone_link_id: str
    tombstone_rel: str
    created_at: str
