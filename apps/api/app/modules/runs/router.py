from __future__ import annotations

from typing import Any, Dict

from fastapi import APIRouter, Request, HTTPException
from fastapi.responses import JSONResponse

from .schemas import RunCreateIn, RunCreateOut, RunGetOut
from .service import create_run as _create_run, get_run as _get_run, append_run_event as _append_run_event
from .providers import get_provider, is_provider_enabled

router = APIRouter(tags=["runs"])


def _parse_bool(v: str) -> bool:
    vv = (v or "").strip().lower()
    return vv not in ("0", "false", "no", "off", "")


def _provider_enabled(request: Request) -> bool:
    # header override for deterministic gates (no server restart needed)
    hv = request.headers.get("x-provider-enabled")
    if hv is not None:
        return _parse_bool(hv)
    return is_provider_enabled(default=False)


def _request_id(request: Request) -> str:
    rid = request.headers.get("x-request-id")
    if rid:
        return str(rid)
    st = getattr(request, "state", None)
    rid2 = getattr(st, "request_id", None) if st is not None else None
    return str(rid2) if rid2 else ""


@router.post("/runs", response_model=RunCreateOut)
def create_run(payload: RunCreateIn, request: Request) -> Any:
    rid = _request_id(request)

    run_id, prompt_pack_id, status0 = _create_run(
        run_type=payload.run_type,
        prompt_pack=payload.prompt_pack.model_dump(),
    )

    if not _provider_enabled(request):
        # flag OFF: preserve legacy stub behavior (P0 regression safety)
        return RunCreateOut(run_id=run_id, prompt_pack_id=prompt_pack_id, status=status0)

    # flag ON: sync execution (P1 minimal), but MUST remain append-only (no UPDATE on runs)
    _append_run_event(run_id, status="running", request_id=rid)

    provider = get_provider()
    inp: Dict[str, Any] = payload.prompt_pack.model_dump()
    inp["run_type"] = payload.run_type

    # gate hook: force provider failure without changing DTO
    if request.headers.get("x-provider-force-fail") is not None and _parse_bool(request.headers.get("x-provider-force-fail") or ""):
        inp["__force_fail__"] = True

    try:
        res = provider.execute(run_id=run_id, input=inp, request_id=rid)
        rr: Dict[str, Any] = {
            "asset_ids": [],
            "provider": getattr(provider, "name", "unknown"),
            "refs": res.result_refs,
        }
        if res.details:
            rr["details"] = res.details
        final_status = res.status or "succeeded"
        _append_run_event(run_id, status=final_status, result_refs=rr, request_id=rid)
        return RunCreateOut(run_id=run_id, prompt_pack_id=prompt_pack_id, status=final_status)
    except Exception as e:
        rr_fail: Dict[str, Any] = {
            "asset_ids": [],
            "provider": getattr(provider, "name", "unknown"),
            "error": str(e),
        }
        _append_run_event(run_id, status="failed", result_refs=rr_fail, request_id=rid)
        body = {
            "error": "internal_error",
            "message": "provider execution failed",
            "request_id": rid,
            "details": {"run_id": run_id, "type": type(e).__name__, "provider": getattr(provider, "name", "unknown")},
        }
        return JSONResponse(status_code=500, content=body, headers={"X-Request-Id": rid} if rid else None)


@router.get("/runs/{run_id}", response_model=RunGetOut)
def get_run(run_id: str) -> RunGetOut:
    row = _get_run(run_id)
    if not row:
        return JSONResponse(
            status_code=404,
            content={
                "error": "not_found",
                "message": "NOT_FOUND: run",
                "request_id": "",
                "details": {"run_id": run_id},
            },
        )
    return RunGetOut(
        run_id=row["run_id"],
        prompt_pack_id=row["prompt_pack_id"],
        status=row["status"],
        result_refs=row["result_refs"],
        created_at=row["created_at"],
    )
