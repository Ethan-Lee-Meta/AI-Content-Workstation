from typing import Optional
from pydantic import BaseModel

class TrashEmptyResponse(BaseModel):
    status: str
    purged_assets: int
    purged_files: int
    audit_event: Optional[dict] = None
