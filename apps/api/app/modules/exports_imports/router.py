from __future__ import annotations

import os
from typing import Any, Dict, Optional

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

from .schemas import (
    ExportCreateIn, ExportCreateOut, ExportGetOut, ExportManifestOut,
    ImportCreateIn, ImportCreateOut, ImportGetOut,
)
from . import service


router = APIRouter()

# Feature flag (rollback preferred)
def _enabled(request: Request) -> bool:
    v = os.getenv("EXPORT_IMPORT_ENABLED", "1")
    return v == "1"


def _rid(request: Request) -> str:
    return (
        getattr(getattr(request, "state", None), "request_id", None)
        or request.headers.get("X-Request-Id")
        or "NA"
    )


def _err(request: Request, status: int, code: str, message: str, details: Optional[Dict[str, Any]] = None):
    return JSONResponse(
        status_code=status,
        content={
            "error": code,
            "message": message,
            "request_id": _rid(request),
            "details": details or {},
        },
    )


# ---------- Exports ----------

@router.post("/exports", response_model=ExportCreateOut, tags=["exports"])
def exports_create(payload: ExportCreateIn, request: Request):
    if not _enabled(request):
        return _err(request, 503, "export_import_disabled", "EXPORT_IMPORT_ENABLED=0", {})
    try:
        record, _manifest = service.export_create(payload.model_dump())
        return record
    except Exception as e:
        return _err(request, 500, "export_create_failed", "internal server error", {"type": type(e).__name__})


@router.get("/exports/{export_id}", response_model=ExportGetOut, tags=["exports"])
def exports_get(export_id: str, request: Request):
    if not _enabled(request):
        return _err(request, 503, "export_import_disabled", "EXPORT_IMPORT_ENABLED=0", {})
    try:
        return service.export_get(export_id)
    except FileNotFoundError:
        return _err(request, 404, "export_not_found", "export not found", {"export_id": export_id})
    except Exception as e:
        return _err(request, 500, "export_get_failed", "internal server error", {"type": type(e).__name__})


@router.get("/exports/{export_id}/manifest", response_model=ExportManifestOut, tags=["exports"])
def exports_manifest(export_id: str, request: Request):
    if not _enabled(request):
        return _err(request, 503, "export_import_disabled", "EXPORT_IMPORT_ENABLED=0", {})
    try:
        return service.export_manifest(export_id)
    except FileNotFoundError:
        return _err(request, 404, "manifest_not_found", "manifest not found", {"export_id": export_id})
    except Exception as e:
        return _err(request, 500, "export_manifest_failed", "internal server error", {"type": type(e).__name__})


# ---------- Imports ----------

@router.post("/imports", response_model=ImportCreateOut, tags=["imports"])
def imports_create(payload: ImportCreateIn, request: Request):
    if not _enabled(request):
        return _err(request, 503, "export_import_disabled", "EXPORT_IMPORT_ENABLED=0", {})
    try:
        return service.import_create(payload.model_dump())
    except FileNotFoundError as e:
        code = str(e) if str(e) else "import_source_not_found"
        return _err(request, 404, "import_source_not_found", "import source not found", {"type": code})
    except ValueError as e:
        return _err(request, 400, "bad_request", str(e), {})
    except Exception as e:
        return _err(request, 500, "import_create_failed", "internal server error", {"type": type(e).__name__})


@router.get("/imports/{import_id}", response_model=ImportGetOut, tags=["imports"])
def imports_get(import_id: str, request: Request):
    if not _enabled(request):
        return _err(request, 503, "export_import_disabled", "EXPORT_IMPORT_ENABLED=0", {})
    try:
        return service.import_get(import_id)
    except FileNotFoundError:
        return _err(request, 404, "import_not_found", "import not found", {"import_id": import_id})
    except Exception as e:
        return _err(request, 500, "import_get_failed", "internal server error", {"type": type(e).__name__})
