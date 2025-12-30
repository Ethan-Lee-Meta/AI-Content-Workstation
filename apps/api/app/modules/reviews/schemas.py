from __future__ import annotations

from typing import Any, Dict, Literal, Optional
from pydantic import BaseModel, Field

ReviewType = Literal["sampled", "manual", "override"]
Conclusion = Literal["pass", "fail", "needs_work"]


class ReviewCreateIn(BaseModel):
    review_type: ReviewType = "manual"
    conclusion: Conclusion
    score: Optional[int] = None  # allow None for P0; can be enforced later
    reason: Optional[str] = None
    run_id: Optional[str] = None
    asset_id: Optional[str] = None
    details: Dict[str, Any] = Field(default_factory=dict)


class ReviewCreateOut(BaseModel):
    review_id: str
    status: str = "recorded"
