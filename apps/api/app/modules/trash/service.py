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
    db_url = os.getenv("DATABASE_URL", "sqlite:///./data/app.db")
    db_path = _resolve_sqlite_path(db_url)
    storage_root_path = Path(os.getenv("STORAGE_ROOT", storage_root)).resolve()

    if not Path(db_path).exists():
        raise RuntimeError(f"db not found: {db_path}")

    purged_files = 0
    purged_assets = 0

    conn = sqlite3.connect(db_path)
    try:
        conn.row_factory = sqlite3.Row
        cols = [r["name"] for r in conn.execute("PRAGMA table_info(assets)").fetchall()]
        path_col = _pick_path_column(cols)

        rows = conn.execute("SELECT * FROM assets WHERE deleted_at IS NOT NULL").fetchall()

        # try purge files first (best-effort)
        if path_col:
            for r in rows:
                v = r[path_col]
                if not v:
                    continue
                safe_p = _safe_under_root(storage_root_path, str(v))
                if safe_p and safe_p.exists() and safe_p.is_file():
                    try:
                        safe_p.unlink()
                        purged_files += 1
                    except Exception:
                        pass

        purged_assets = conn.execute("SELECT COUNT(*) FROM assets WHERE deleted_at IS NOT NULL").fetchone()[0]
        conn.execute("DELETE FROM assets WHERE deleted_at IS NOT NULL")
        conn.commit()

        audit = {
            "ts": datetime.utcnow().isoformat() + "Z",
            "level": "audit",
            "event": "trash.empty",
            "request_id": request_id,
            "purged_assets": purged_assets,
            "purged_files": purged_files,
        }
        # stdout audit line (capturable in uvicorn log redirection)
        print(json.dumps(audit, ensure_ascii=False), flush=True)

        return {
            "status": "ok",
            "purged_assets": int(purged_assets),
            "purged_files": int(purged_files),
            "audit_event": audit,
        }
    finally:
        try:
            conn.close()
        except Exception:
            pass
