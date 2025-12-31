from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any, Dict

from .base import ProviderResult


class MockProvider:
    """
    Minimal executable provider for P1:
    - writes a JSON artifact into storage root
    - returns a stable storage ref in result_refs
    """
    name = "mock"

    def __init__(self, storage_root: str | None = None) -> None:
        self.storage_root = storage_root or os.environ.get("STORAGE_ROOT") or "./data/storage"

    def execute(self, *, run_id: str, input: Dict[str, Any], request_id: str) -> ProviderResult:
        if input.get('__force_fail__'):
            raise RuntimeError('forced failure')

        out_dir = Path(self.storage_root) / "runs" / run_id
        out_dir.mkdir(parents=True, exist_ok=True)

        out_file = out_dir / "result.json"
        payload: Dict[str, Any] = {
            "provider": self.name,
            "run_id": run_id,
            "request_id": request_id,
            "ts": time.time(),
            "input": input,
        }
        out_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

        # IMPORTANT: keep ref shape stable and human-readable.
        # If your repo already uses a different ref convention, we'll align in the next step.
        ref = f"storage://runs/{run_id}/result.json"

        return ProviderResult(status="succeeded", result_refs=[ref], details={"path": str(out_file)})
