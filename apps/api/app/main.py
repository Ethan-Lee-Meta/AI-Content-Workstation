from fastapi import FastAPI
import os

APP_VERSION = os.getenv("APP_VERSION", "0.1.0")
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./data/app.db")
STORAGE_ROOT = os.getenv("STORAGE_ROOT", "./data/storage")

app = FastAPI(title="AI Content Workstation API", version=APP_VERSION)

# === BATCH-0 OBSERVABILITY FOUNDATIONS (DO NOT EDIT WITHOUT CR) ===
# Contract locks:
# - Ports: web=2000, api=7000
# - /health keys: status, version, db, storage, last_error_summary
# - X-Request-Id in/out (missing -> generated; always echoed back; also on errors)
# - Error envelope keys: error, message, request_id, details
import os, json, uuid, datetime, logging
from typing import Any, Dict, Optional
from fastapi import Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException

_log = logging.getLogger("app")
if not _log.handlers:
    logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))

def _now_iso() -> str:
    return datetime.datetime.utcnow().replace(tzinfo=datetime.timezone.utc).isoformat()

def _emit(level: str, event: str, message: str, request_id: Optional[str], module: str, **extra: Any) -> None:
    payload: Dict[str, Any] = {
        "ts": _now_iso(),
        "level": level.lower(),
        "message": message,
        "request_id": request_id,
        "event": event,
        "module": module,
    }
    payload.update(extra)
    print(json.dumps(payload, ensure_ascii=False), flush=True)

def _err_envelope(error: str, message: str, request_id: Optional[str], details: Any, status_code: int):
    headers = {}
    if request_id:
        headers["X-Request-Id"] = request_id
    return JSONResponse(
        status_code=status_code,
        content={
            "error": error,
            "message": message,
            "request_id": request_id,
            "details": details,
        },
        headers=headers,
    )

@app.middleware("http")
async def _request_id_mw(request: Request, call_next):
    rid = request.headers.get("X-Request-Id") or uuid.uuid4().hex.upper()
    request.state.request_id = rid
    _emit("info", "http.request.start", f"{request.method} {request.url.path}", rid, __name__)
    try:
        resp = await call_next(request)
    except Exception as e:
        _emit("error", "http.request.exception", str(e), rid, __name__)
        raise
    resp.headers["X-Request-Id"] = rid
    _emit("info", "http.request.end", f"{request.method} {request.url.path} -> {getattr(resp,'status_code',None)}", rid, __name__)
    return resp

@app.exception_handler(StarletteHTTPException)
async def _http_exc_handler(request: Request, exc: StarletteHTTPException):
    rid = getattr(request.state, "request_id", None)
    return _err_envelope("http_error", str(exc.detail), rid, {"status_code": exc.status_code}, exc.status_code)

@app.exception_handler(RequestValidationError)
async def _validation_exc_handler(request: Request, exc: RequestValidationError):
    rid = getattr(request.state, "request_id", None)
    return _err_envelope("validation_error", "request validation failed", rid, exc.errors(), 422)

@app.exception_handler(Exception)
async def _unhandled_exc_handler(request: Request, exc: Exception):
    rid = getattr(request.state, "request_id", None)
    return _err_envelope("internal_error", "internal server error", rid, {"type": type(exc).__name__}, 500)
# === END BATCH-0 OBSERVABILITY FOUNDATIONS ===


@app.get("/health")
def health():
    # Contract keys are locked by BATCH-0
    import os
    return {
        'status': 'ok',
        'version': os.getenv('APP_VERSION', '0.1.0'),
        'db': {'status': 'ok', 'kind': os.getenv('DB_KIND', 'sqlite'), 'path': os.getenv('DB_PATH', './data/app.db')},
        'storage': {'status': 'ok', 'root': os.getenv('STORAGE_ROOT', './data/storage')},
        'last_error_summary': None,
    }
