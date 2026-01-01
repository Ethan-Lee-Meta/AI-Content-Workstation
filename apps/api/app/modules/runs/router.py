from __future__ import annotations

import os
from typing import Any, Dict

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import JSONResponse

from .schemas import RunCreateIn, RunCreateOut, RunGetOut
from .service import (
    append_run_event as _append_run_event,
    create_run_v11 as _create_run_v11,
    get_prompt_pack_payload,
    get_run as _get_run,
    link_produced_asset,
)
from .providers import get_provider

router = APIRouter(tags=["runs"])


def _parse_bool(v: str) -> bool:
    vv = (v or "").strip().lower()
    return vv in ("1", "true", "yes", "y", "on")


def _request_id(request: Request) -> str:
    st = getattr(request, "state", None)
    rid = getattr(st, "request_id", None) if st is not None else None
    return str(rid) if rid else ""


def _provider_enabled(request: Request) -> bool:
    # prefer request override for gates; fallback to env
    hv = request.headers.get("x-provider-enabled")
    if hv is not None:
        return _parse_bool(hv)
    return _parse_bool(os.getenv("PROVIDER_ENABLED", ""))


@router.post("/runs", response_model=RunCreateOut)
def create_run(payload: RunCreateIn, request: Request) -> Any:
    rid = _request_id(request)

    # ---- 2C.2 invariants: primary exactly 1 if characters provided
    chars_in = [c.model_dump() for c in (payload.characters or [])]
    if chars_in:
        prim = [c for c in chars_in if c.get("is_primary") is True]
        if len(prim) == 0:
            raise HTTPException(status_code=400, detail="primary_character_required")
        if len(prim) > 1:
            raise HTTPException(status_code=400, detail="multiple_primary_characters")

    # ---- 2C.3 PromptPack lock is already validated by Pydantic
    pp = payload.prompt_pack.model_dump()

    try:
        run_id, prompt_pack_id, status0, evidence = _create_run_v11(
            run_type=payload.run_type,
            prompt_pack=pp,
            override_provider_profile_id=payload.override_provider_profile_id,
            characters=chars_in,
            inputs=payload.inputs or {},
        )
    except ValueError as e:
        msg = str(e)
        # map to DoD errors (simple string codes)
        code_map = {
            "provider_profile_not_found": (404, "provider_profile_not_found"),
            "provider_profile_deleted": (409, "provider_profile_deleted"),
            "provider_profile_required": (400, "provider_profile_required"),
            "character_not_found": (404, "character_not_found"),
            "active_ref_set_missing": (400, "active_ref_set_missing"),
            "ref_set_not_found": (404, "ref_set_not_found"),
            "invalid_ref_set_owner": (400, "invalid_ref_set_owner"),
            "ref_set_not_confirmed": (400, "ref_set_not_confirmed"),
        }
        st, detail = code_map.get(msg, (400, msg or "bad_request"))
        raise HTTPException(status_code=st, detail=detail)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"internal_error: {e}")

    # flag OFF -> legacy stub behavior
    if not _provider_enabled(request):
        return RunCreateOut(run_id=run_id, prompt_pack_id=prompt_pack_id, status=status0)

    # ---- flag ON: sync execution (append-only via run_events)
    _append_run_event(run_id, status="running", request_id=rid)

    provider = get_provider()
    inp: Dict[str, Any] = {}
    inp["run_type"] = payload.run_type
    inp["prompt_pack"] = pp
    inp["evidence"] = evidence
    inp["inputs"] = payload.inputs or {}

    # gate hook: force fail
    if request.headers.get("x-provider-force-fail") is not None and _parse_bool(request.headers.get("x-provider-force-fail") or ""):
        inp["__force_fail__"] = True

    try:
        res = provider.execute(run_id=run_id, input=inp, request_id=rid)

        # provider result refs: start with provider-returned refs
        rr: Dict[str, Any] = {
            "asset_ids": [],
            "provider": getattr(provider, "name", "unknown"),
            "storage_refs": list(res.result_refs or []),
        }
        if res.details:
            rr["details"] = res.details

        # assetize first storage ref (best-effort)
        asset_id = None
        if rr["storage_refs"]:
            try:
                from .service import _connect, _create_asset_from_storage_ref  # local import to avoid API surface changes
                conn = _connect()
                try:
                    asset_id = _create_asset_from_storage_ref(conn, storage_ref=rr["storage_refs"][0], request_id=rid)
                    if asset_id:
                        rr["asset_ids"] = [asset_id]
                        conn.commit()
                finally:
                    conn.close()
            except Exception:
                asset_id = None

        final_status = res.status or "succeeded"
        _append_run_event(run_id, status=final_status, result_refs=rr, request_id=rid)

        # produced_asset link
        if asset_id:
            try:
                link_produced_asset(run_id, asset_id=asset_id, request_id=rid)
            except Exception:
                pass

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
            "details": {"type": type(e).__name__, "msg": str(e)},
        }
        return JSONResponse(status_code=500, content=body)


@router.get("/runs/{run_id}", response_model=RunGetOut)
def get_run(run_id: str) -> Any:
    r = _get_run(run_id)
    if not r:
        raise HTTPException(status_code=404, detail="run_not_found")

    # attach input_json if present
    inp = {}
    for k in ("input_json", "input", "meta_json", "meta", "payload_json", "payload"):
        if k in r and isinstance(r.get(k), (dict,)):
            inp = r.get(k) or {}
            break
        if k in r and isinstance(r.get(k), str):
            try:
                import json
                v = json.loads(r.get(k) or "")
                if isinstance(v, dict):
                    inp = v
                    break
            except Exception:
                pass

    return RunGetOut(
        run_id=r.get("run_id") or run_id,
        prompt_pack_id=r.get("prompt_pack_id") or "",
        status=r.get("status") or "",
        result_refs=r.get("result_refs") or {},
        created_at=r.get("created_at"),
        input_json=inp,
    )
