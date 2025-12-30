from __future__ import annotations

from typing import Any, Dict, List, Literal, Optional
from pydantic import BaseModel, Field

RunType = Literal["t2i", "i2i", "t2v", "i2v"]


class PromptPackIn(BaseModel):
    # Flexible payload for P0. ProviderAdapter will normalize later.
    kind: Optional[str] = None
    prompt: Optional[str] = None
    negative_prompt: Optional[str] = None
    params: Dict[str, Any] = Field(default_factory=dict)
    references: List[Dict[str, Any]] = Field(default_factory=list)
    extra: Dict[str, Any] = Field(default_factory=dict)


class RunCreateIn(BaseModel):
    run_type: RunType = "t2i"
    prompt_pack: PromptPackIn


class RunCreateOut(BaseModel):
    run_id: str
    prompt_pack_id: str
    status: str


class RunGetOut(BaseModel):
    run_id: str
    prompt_pack_id: str
    status: str
    result_refs: Dict[str, Any] = Field(default_factory=dict)
    created_at: Optional[str] = None
