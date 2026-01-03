from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Protocol


@dataclass(frozen=True)
class ProviderResult:
    """
    Internal execution result returned by provider implementations.

    NOTE:
    - status must map to existing Run status strings (we will use: queued/running/succeeded/failed).
    - result_refs must be compatible with RunGetOut.result_refs (list[str]).
    """
    status: str
    result_refs: List[str]
    details: Optional[Dict[str, Any]] = None


class ProviderAdapter(Protocol):
    """
    ProviderAdapter is a pluggable execution interface for Runs.
    Keep it minimal in P1; do NOT introduce external infra here.
    """
    name: str

    def execute(self, *, run_id: str, input: Dict[str, Any], request_id: str) -> ProviderResult:
        ...
