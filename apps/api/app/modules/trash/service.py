import os
import json
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

SAFE_PATH_CANDIDATES = [
    "storage_path",
    "file_path",
    "local_path",
    "path",
    "uri",
    "storage_relpath",
    "relpath",
    "storage_key",
]

def _resolve_sqlite_path(database_url: str) -> str:
    # Supports sqlite:///./data/app.db
    if database_url.startswith("sqlite:///"):
        p = database_url.replace("sqlite:///", "", 1)
        return str(Path(p).resolve())
    if database_url.startswith("sqlite+pysqlite:///"):
        p = database_url.replace("sqlite+pysqlite:///", "", 1)
        return str(Path(p).resolve())
    # fallback: treat as relative file path
    return str(Path(database_url).resolve())

def _pick_path_column(cols: List[str]) -> Optional[str]:
    for c in SAFE_PATH_CANDIDATES:
        if c in cols:
            return c
    return None

def _safe_under_root(root: Path, candidate: str) -> Optional[Path]:
    try:
        p = Path(candidate)
        if not p.is_absolute():
            p = (root / p).resolve()
        else:
            p = p.resolve()
        root_resolved = root.resolve()
        if str(p).startswith(str(root_resolved) + os.sep) or str(p) == str(root_resolved):
            return p
        return None
    except Exception:
        return None

def purge_deleted_assets(storage_root: str, request_id: Optional[str] = None) -> Dict:
    """
    Physically delete DB rows for assets where deleted_at IS NOT NULL.
    IMPORTANT (Batch-5): do NOT delete storage blobs/files in this batch.
    Links are not modified (links remain SSOT for audit/trace).
    """
    db_url = os.getenv("DATABASE_URL", "sqlite:///./data/app.db")
    db_path = _resolve_sqlite_path(db_url)

    if not Path(db_path).exists():
        raise RuntimeError(f"db not found: {db_path}")

    purged_files = 0  # locked: do not delete files in this batch
    conn = sqlite3.connect(db_path)
    try:
        conn.row_factory = sqlite3.Row

        # count first (so response can report deleted_count)
        purged_assets = conn.execute(
            "SELECT COUNT(*) FROM assets WHERE deleted_at IS NOT NULL"
        ).fetchone()[0]

        conn.execute("DELETE FROM assets WHERE deleted_at IS NOT NULL")
        conn.commit()

        deleted_count = int(purged_assets)

        audit = {
            "ts": datetime.utcnow().isoformat() + "Z",
            "level": "audit",
            "event": "trash.empty",
            "action": "trash_empty",
            "request_id": request_id,
            "deleted_count": deleted_count,
            "purged_assets": deleted_count,  # backward compatible key
            "purged_files": int(purged_files),
        }
        print(json.dumps(audit, ensure_ascii=False), flush=True)

        return {
            "status": "ok",
            "deleted_count": deleted_count,  # Batch-5 contract
            "request_id": request_id,        # Batch-5 contract
            "purged_assets": deleted_count,  # backward compatible
            "purged_files": int(purged_files),
            "audit_event": audit,
        }
    finally:
        try:
            conn.close()
        except Exception:
            pass
