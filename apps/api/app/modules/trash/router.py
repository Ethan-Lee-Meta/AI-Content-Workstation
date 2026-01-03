from fastapi import APIRouter, Request
from .schemas import TrashEmptyResponse
from .service import purge_deleted_assets

router = APIRouter(prefix="/trash", tags=["trash"])

@router.post("/empty", response_model=TrashEmptyResponse)
def trash_empty(request: Request):
    rid = getattr(getattr(request, "state", None), "request_id", None)
    # storage_root default aligns with BATCH-1 contract
    return purge_deleted_assets(storage_root="./data/storage", request_id=rid)
