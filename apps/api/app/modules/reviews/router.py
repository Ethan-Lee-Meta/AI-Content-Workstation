from __future__ import annotations

from fastapi import APIRouter, HTTPException
from .schemas import ReviewCreateIn, ReviewCreateOut
from .service import create_review

router = APIRouter(tags=["reviews"])


@router.post("/reviews", response_model=ReviewCreateOut)
def post_review(payload: ReviewCreateIn) -> ReviewCreateOut:
    # Rule: override must have reason
    if payload.review_type == "override" and (payload.reason is None or str(payload.reason).strip() == ""):
        raise HTTPException(status_code=400, detail="override requires reason")

    try:
        review_id = create_review(payload.model_dump())
        return ReviewCreateOut(review_id=review_id, status="recorded")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"INTERNAL_ERROR: {e}")
