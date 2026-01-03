from __future__ import annotations

from typing import Dict, List, Optional, Any

from pydantic import BaseModel, Field


class PageOut(BaseModel):
    limit: int = Field(..., ge=1)
    offset: int = Field(..., ge=0)
    total: int = Field(..., ge=0)
    has_more: bool


class AssetDTO(BaseModel):
    id: str
    type: Optional[str] = None
    created_at: Optional[str] = None
    deleted_at: Optional[str] = None

    project_id: Optional[str] = None
    series_id: Optional[str] = None

    storage_path: Optional[str] = None
    mime_type: Optional[str] = None
    width: Optional[int] = None
    height: Optional[int] = None
    duration_ms: Optional[int] = None


class AssetListOut(BaseModel):
    items: List[AssetDTO]
    page: PageOut


class TraceabilityOut(BaseModel):
    # placeholder; service degrades safely if links schema not present
    links: List[Dict] = Field(default_factory=list)
    related: Dict[str, List[str]] = Field(default_factory=dict)
    chain: Dict[str, Any] = Field(default_factory=dict)


class AssetDetailOut(BaseModel):
    asset: AssetDTO
    traceability: TraceabilityOut


class AssetDeleteResponse(BaseModel):
    asset_id: str
    deleted_at: Optional[str] = None
    already_deleted: bool = False
    status: str = "deleted"
