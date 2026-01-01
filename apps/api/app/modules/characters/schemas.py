from __future__ import annotations

from typing import Any, Dict, List, Literal, Optional
from pydantic import BaseModel, Field

CharacterStatus = Literal["draft", "confirmed", "archived"]
RefSetStatus = Literal["draft", "confirmed", "archived"]


class PageOut(BaseModel):
    offset: int
    limit: int
    total: int
    has_more: bool


class CharacterCreateIn(BaseModel):
    name: str = Field(min_length=1)
    tags: Dict[str, Any] = Field(default_factory=dict)
    meta: Dict[str, Any] = Field(default_factory=dict)


class CharacterPatchIn(BaseModel):
    name: Optional[str] = None
    status: Optional[CharacterStatus] = None
    active_ref_set_id: Optional[str] = None
    tags: Optional[Dict[str, Any]] = None
    meta: Optional[Dict[str, Any]] = None


class CharacterOut(BaseModel):
    id: str
    name: str
    status: CharacterStatus
    active_ref_set_id: Optional[str] = None
    tags: Dict[str, Any] = Field(default_factory=dict)
    meta: Dict[str, Any] = Field(default_factory=dict)
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class CharactersListOut(BaseModel):
    items: List[CharacterOut]
    page: PageOut


class CharacterRefSetCreateIn(BaseModel):
    status: RefSetStatus = "draft"
    base_ref_set_id: Optional[str] = None
    min_requirements_snapshot: Dict[str, Any] = Field(default_factory=dict)


class CharacterRefSetOut(BaseModel):
    id: str
    character_id: str
    version: int
    status: RefSetStatus
    min_requirements_snapshot: Dict[str, Any] = Field(default_factory=dict)
    created_at: Optional[str] = None


class CharacterRefSetDetailOut(BaseModel):
    ref_set: CharacterRefSetOut
    refs: List[str] = Field(default_factory=list)  # asset_id list
    refs_count: int = 0


class CharacterDetailOut(BaseModel):
    character: CharacterOut
    ref_sets: List[CharacterRefSetOut] = Field(default_factory=list)
    active_ref_set: Optional[CharacterRefSetDetailOut] = None


class RefAddIn(BaseModel):
    asset_id: str = Field(min_length=1)


class RefAddOut(BaseModel):
    link_id: str
    already_linked: bool = False
