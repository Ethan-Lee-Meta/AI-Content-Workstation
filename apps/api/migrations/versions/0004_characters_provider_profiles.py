"""v1.1: characters + character_ref_sets (append-only) + provider_profiles

- Adds:
  - characters
  - character_ref_sets (append-only: no UPDATE/DELETE)
  - provider_profiles (at most one global default)

Downstream APIs are implemented in later batches.
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0004_characters_provider_profiles"
down_revision = "0003_optional_hierarchy"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- characters ---
    op.create_table(
        "characters",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("status", sa.Text(), nullable=False),  # draft|confirmed|archived
        sa.Column("active_ref_set_id", sa.Text(), nullable=True),
        sa.Column("created_at", sa.Text(), nullable=False),
        sa.Column("updated_at", sa.Text(), nullable=False),
    )
    op.create_index("ix_characters_status", "characters", ["status"])
    op.create_index("ix_characters_name", "characters", ["name"])

    # --- character_ref_sets (append-only) ---
    op.create_table(
        "character_ref_sets",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("character_id", sa.Text(), sa.ForeignKey("characters.id"), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("status", sa.Text(), nullable=False),  # draft|confirmed|archived
        sa.Column("min_requirements_snapshot_json", sa.Text(), nullable=False),
        sa.Column("created_at", sa.Text(), nullable=False),
    )
    op.create_index(
        "uq_character_ref_sets_character_id_version",
        "character_ref_sets",
        ["character_id", "version"],
        unique=True,
    )
    op.create_index("ix_character_ref_sets_character_id", "character_ref_sets", ["character_id"])
    op.create_index("ix_character_ref_sets_status", "character_ref_sets", ["status"])

    # append-only triggers (SQLite)
    op.execute(
        """
        CREATE TRIGGER IF NOT EXISTS trg_character_ref_sets_no_update
        BEFORE UPDATE ON character_ref_sets
        BEGIN
          SELECT RAISE(ABORT, 'append-only: character_ref_sets cannot be updated');
        END;
        """
    )
    op.execute(
        """
        CREATE TRIGGER IF NOT EXISTS trg_character_ref_sets_no_delete
        BEFORE DELETE ON character_ref_sets
        BEGIN
          SELECT RAISE(ABORT, 'append-only: character_ref_sets cannot be deleted');
        END;
        """
    )

    # --- provider_profiles ---
    op.create_table(
        "provider_profiles",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("provider_type", sa.Text(), nullable=False),
        sa.Column("config_json", sa.Text(), nullable=False),
        sa.Column("secrets_redaction_policy_json", sa.Text(), nullable=False),
        sa.Column("is_global_default", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.Text(), nullable=False),
        sa.Column("updated_at", sa.Text(), nullable=False),
    )
    op.create_index("ix_provider_profiles_provider_type", "provider_profiles", ["provider_type"])
    op.create_index("ix_provider_profiles_is_global_default", "provider_profiles", ["is_global_default"])
    op.create_index("ix_provider_profiles_name", "provider_profiles", ["name"])

    # at most one global default (partial unique index)
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS uq_provider_profiles_global_default
        ON provider_profiles(is_global_default)
        WHERE is_global_default = 1;
        """
    )


def downgrade() -> None:
    # provider_profiles
    op.execute("DROP INDEX IF EXISTS uq_provider_profiles_global_default;")
    op.drop_index("ix_provider_profiles_name", table_name="provider_profiles")
    op.drop_index("ix_provider_profiles_is_global_default", table_name="provider_profiles")
    op.drop_index("ix_provider_profiles_provider_type", table_name="provider_profiles")
    op.drop_table("provider_profiles")

    # character_ref_sets (drop triggers first)
    op.execute("DROP TRIGGER IF EXISTS trg_character_ref_sets_no_update;")
    op.execute("DROP TRIGGER IF EXISTS trg_character_ref_sets_no_delete;")
    op.drop_index("ix_character_ref_sets_status", table_name="character_ref_sets")
    op.drop_index("uq_character_ref_sets_character_id_version", table_name="character_ref_sets")
    op.drop_index("ix_character_ref_sets_character_id", table_name="character_ref_sets")
    # unique constraint is dropped with table in SQLite; keep downgrade resilient:
    op.drop_table("character_ref_sets")

    # characters
    op.drop_index("ix_characters_name", table_name="characters")
    op.drop_index("ix_characters_status", table_name="characters")
    op.drop_table("characters")
