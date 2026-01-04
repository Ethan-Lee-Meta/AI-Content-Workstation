from typing import Optional
from pydantic import BaseModel

class TrashEmptyResponse(BaseModel):
    status: str

    # Batch-5 contract
    deleted_count: int
    request_id: Optional[str] = None

    # backward compatible fields
    purged_assets: int
    purged_files: int

    audit_event: Optional[dict] = None

