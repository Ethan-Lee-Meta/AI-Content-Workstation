from __future__ import annotations

from sqlmodel import SQLModel, Field


class ProviderProfile(SQLModel, table=True):
    __tablename__ = "provider_profiles"

    id: str = Field(primary_key=True)
    name: str
    provider_type: str
    config_json: str
    secrets_redaction_policy_json: str

    # 0|1; at most one row can be 1 (DB partial unique index in migration)
    is_global_default: int = Field(default=0)

    created_at: str
    updated_at: str
