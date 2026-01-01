from __future__ import annotations

from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field, model_validator

RunType = Literal["t2i", "i2i", "t2v", "i2v"]


class PromptPackIn(BaseModel):
    # AC-008 lock
    raw_input: str = Field(..., min_length=1)
    final_prompt: str = Field(..., min_length=1)
    assembly_used: bool  # must be explicit bool

    # optional
    assembly_prompt: Optional[str] = None

    # forward-compatible
    extra: Dict[str, Any] = Field(default_factory=dict)

    @model_validator(mode="after")
    def _lock_rules(self) -> "PromptPackIn":
        ap = (self.assembly_prompt or "").strip()
        if not ap:
            # if assembly_prompt missing -> must be false
            if self.assembly_used is True:
                raise ValueError("assembly_prompt missing -> assembly_used must be false")
            self.assembly_prompt = None
        else:
            # if assembly_used true -> assembly_prompt must be present (non-empty)
            if self.assembly_used is True and not ap:
                raise ValueError("assembly_used=true requires non-empty assembly_prompt")
            self.assembly_prompt = ap
        return self


class RunCharacterIn(BaseModel):
    character_id: str = Field(..., min_length=1)
    character_ref_set_id: Optional[str] = None
    is_primary: bool = False


class RunCreateIn(BaseModel):
    run_type: RunType
    prompt_pack: PromptPackIn

    # AC-010 minimal
    override_provider_profile_id: Optional[str] = None

    # AC-007 minimal
    characters: List[RunCharacterIn] = Field(default_factory=list)

    # provider-specific opaque json
    inputs: Dict[str, Any] = Field(default_factory=dict)


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

    # evidence (optional, for trace/debug)
    input_json: Dict[str, Any] = Field(default_factory=dict)
