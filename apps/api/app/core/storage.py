"""
Local filesystem storage contract for BATCH-1.

Defaults (per ARCH):
- STORAGE_ROOT: ./data/storage
"""
from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Dict


def _repo_root() -> Path:
    # apps/api/app/core/storage.py -> repo root = parents[4]
    return Path(__file__).resolve().parents[4]


def get_storage_root() -> Path:
    raw = os.getenv("STORAGE_ROOT", "./data/storage")
    p = Path(raw)
    return ( _repo_root() / p ).resolve() if not p.is_absolute() else p


def ensure_storage_root() -> Path:
    root = get_storage_root()
    root.mkdir(parents=True, exist_ok=True)
    return root


def storage_health() -> Dict[str, Any]:
    try:
        root = ensure_storage_root()
        probe = root / ".probe_write"
        probe.write_text("ok", encoding="utf-8")
        try:
            probe.unlink()
        except Exception:
            pass
        return {"status": "ok", "kind": "local_fs", "root": str(root.as_posix())}
    except Exception as e:
        return {"status": "error", "kind": "local_fs", "root": str(get_storage_root().as_posix()), "error": str(e)}
