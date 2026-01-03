from __future__ import annotations

import os
from typing import Optional

from .base import ProviderAdapter
from .mock_provider import MockProvider


def is_provider_enabled(*, default: bool = False) -> bool:
    """
    Feature flag (rollback-first):
      PROVIDER_ENABLED=0 -> off
      PROVIDER_ENABLED=1 -> on
    Default is OFF unless explicitly enabled.
    """
    v = os.environ.get("PROVIDER_ENABLED")
    if v is None:
        return default
    v = v.strip().lower()
    return v not in ("0", "false", "no", "")


def get_provider(name: Optional[str] = None) -> ProviderAdapter:
    """
    Registry entry point.
    P1 only ships "mock". Future: route by name/config.
    """
    _ = name  # reserved
    return MockProvider()
