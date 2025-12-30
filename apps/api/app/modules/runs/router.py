from __future__ import annotations

import sqlite3
from fastapi import APIRouter, HTTPException
from .schemas import RunCreateIn, RunCreateOut, RunGetOut
from .service import create_run as _create_run, get_run as _get_run

router = APIRouter(tags=["runs"])


@router.post("/runs", response_model=RunCreateOut)
def create_run(payload: RunCreateIn) -> RunCreateOut:
    try:
        run_id, prompt_pack_id, status = _create_run(
            run_type=payload.run_type,
            prompt_pack=payload.prompt_pack.model_dump(),
        )
        return RunCreateOut(run_id=run_id, prompt_pack_id=prompt_pack_id, status=status)
    except sqlite3.IntegrityError as e:
        raise HTTPException(status_code=409, detail=f"CONFLICT: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"INTERNAL_ERROR: {e}")


@router.get("/runs/{run_id}", response_model=RunGetOut)
def get_run(run_id: str) -> RunGetOut:
    row = _get_run(run_id)
    if not row:
        raise HTTPException(status_code=404, detail="NOT_FOUND: run")
    return RunGetOut(
        run_id=row["run_id"],
        prompt_pack_id=row["prompt_pack_id"],
        status=row["status"],
        result_refs=row["result_refs"],
        created_at=row["created_at"],
    )
