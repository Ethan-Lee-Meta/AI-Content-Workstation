"""bootstrap alembic (empty)

Revision ID: 0001_bootstrap
Revises:
Create Date: 2025-12-29
"""
from __future__ import annotations

# revision identifiers, used by Alembic.
revision = "0001_bootstrap"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Empty bootstrap revision; STEP-040 will add real tables.
    pass


def downgrade() -> None:
    pass
