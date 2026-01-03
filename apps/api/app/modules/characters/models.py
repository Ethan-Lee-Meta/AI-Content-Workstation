from __future__ import annotations

from typing import Optional
from sqlmodel import SQLModel, Field


# v1.1 lock: draft|confirmed|archived
class Character(SQLModel, table=True):
    __tablename__ = "characters"

    id: str = Field(primary_key=True)
    name: str
    status: str  # draft|confirmed|archived
    active_ref_set_id: Optional[str] = Field(default=None)

    created_at: str
    updated_at: str


# append-only (enforced by SQLite triggers in migration)
class CharacterRefSet(SQLModel, table=True):
    __tablename__ = "character_ref_sets"

    id: str = Field(primary_key=True)
    character_id: str = Field(foreign_key="characters.id")
    version: int
    status: str  # draft|confirmed|archived
    min_requirements_snapshot_json: str
    created_at: str
