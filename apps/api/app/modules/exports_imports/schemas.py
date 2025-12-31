from __future__ import annotations

from pydantic import BaseModel, Field
from typing import Any, Dict, List, Literal, Optional


# ---------- Exports ----------

class ExportCreateIn(BaseModel):
    asset_ids: Optional[List[str]] = None
    include_deleted: bool = False
    include_binaries: bool = True
    include_proxies: bool = False
    note: Optional[str] = None


class ExportGetOut(BaseModel):
    export_id: str
    status: Literal["completed", "failed"]
    created_at: str
    package_path: str
    manifest_path: str
    bundle_path: str
    counts: Dict[str, int] = Field(default_factory=dict)
    warnings: List[str] = Field(default_factory=list)


class ExportCreateOut(ExportGetOut):
    pass


class ExportManifestOut(BaseModel):
    manifest_version: str
    export_id: str
    created_at: str
    selection: Dict[str, Any] = Field(default_factory=dict)
    tables: Dict[str, Any] = Field(default_factory=dict)
    assets_preview: List[Dict[str, Any]] = Field(default_factory=list)
    blobs: List[Dict[str, Any]] = Field(default_factory=list)
    warnings: List[str] = Field(default_factory=list)


# ---------- Imports ----------

class ImportCreateIn(BaseModel):
    # prefer export_id (same machine export dir)
    export_id: Optional[str] = None
    # alternatively specify an absolute/local package dir
    package_path: Optional[str] = None

    create_new_ids: bool = True
    note: Optional[str] = None


class ImportGetOut(BaseModel):
    import_id: str
    status: Literal["completed", "failed"]
    created_at: str
    source: Dict[str, Any] = Field(default_factory=dict)
    counts: Dict[str, int] = Field(default_factory=dict)
    id_map_size: int = 0
    warnings: List[str] = Field(default_factory=list)


class ImportCreateOut(ImportGetOut):
    pass
