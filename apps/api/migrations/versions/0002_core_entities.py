"""core entities v0 (Asset/PromptPack/Run/Review/Link) + append-only triggers

Revision ID: 0002_core_entities
Revises: 0001_bootstrap
Create Date: 2025-12-29
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "0002_core_entities"
down_revision = "0001_bootstrap"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ---- tables ----
    op.create_table(
        "assets",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("kind", sa.Text(), nullable=False),
        sa.Column("uri", sa.Text(), nullable=True),
        sa.Column("mime_type", sa.Text(), nullable=True),
        sa.Column("sha256", sa.Text(), nullable=True),
        sa.Column("width", sa.Integer(), nullable=True),
        sa.Column("height", sa.Integer(), nullable=True),
        sa.Column("duration_ms", sa.Integer(), nullable=True),
        sa.Column("meta_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.Text(), nullable=False),
        sa.Column("deleted_at", sa.Text(), nullable=True),
    )
    op.create_index("ix_assets_kind", "assets", ["kind"], unique=False)
    op.create_index("ix_assets_sha256", "assets", ["sha256"], unique=False)

    op.create_table(
        "prompt_packs",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("name", sa.Text(), nullable=True),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("digest", sa.Text(), nullable=True),
        sa.Column("created_at", sa.Text(), nullable=False),
    )
    op.create_index("ix_prompt_packs_digest", "prompt_packs", ["digest"], unique=False)

    op.create_table(
        "runs",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("prompt_pack_id", sa.Text(), sa.ForeignKey("prompt_packs.id"), nullable=False),
        sa.Column("status", sa.Text(), nullable=False),
        sa.Column("input_json", sa.Text(), nullable=True),
        sa.Column("output_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.Text(), nullable=False),
    )
    op.create_index("ix_runs_prompt_pack_id", "runs", ["prompt_pack_id"], unique=False)
    op.create_index("ix_runs_status", "runs", ["status"], unique=False)

    op.create_table(
        "reviews",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("run_id", sa.Text(), sa.ForeignKey("runs.id"), nullable=False),
        sa.Column("rating", sa.Integer(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.Text(), nullable=False),
    )
    op.create_index("ix_reviews_run_id", "reviews", ["run_id"], unique=False)

    op.create_table(
        "links",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("src_type", sa.Text(), nullable=False),
        sa.Column("src_id", sa.Text(), nullable=False),
        sa.Column("dst_type", sa.Text(), nullable=False),
        sa.Column("dst_id", sa.Text(), nullable=False),
        sa.Column("rel", sa.Text(), nullable=False),
        sa.Column("created_at", sa.Text(), nullable=False),
    )
    op.create_index("ix_links_src", "links", ["src_type", "src_id"], unique=False)
    op.create_index("ix_links_dst", "links", ["dst_type", "dst_id"], unique=False)
    op.create_index("ix_links_rel", "links", ["rel"], unique=False)

    # ---- append-only invariants (SQLite triggers) ----
    # Policy: PromptPack / Run / Review append-only (no UPDATE / no DELETE)
    # Note: We also apply to Link to keep relationship evidence stable.
    op.execute("""
    CREATE TRIGGER IF NOT EXISTS trg_prompt_packs_no_update
    BEFORE UPDATE ON prompt_packs
    BEGIN
      SELECT RAISE(ABORT, 'append-only: prompt_packs cannot be updated');
    END;
    """)
    op.execute("""
    CREATE TRIGGER IF NOT EXISTS trg_prompt_packs_no_delete
    BEFORE DELETE ON prompt_packs
    BEGIN
      SELECT RAISE(ABORT, 'append-only: prompt_packs cannot be deleted');
    END;
    """)

    op.execute("""
    CREATE TRIGGER IF NOT EXISTS trg_runs_no_update
    BEFORE UPDATE ON runs
    BEGIN
      SELECT RAISE(ABORT, 'append-only: runs cannot be updated');
    END;
    """)
    op.execute("""
    CREATE TRIGGER IF NOT EXISTS trg_runs_no_delete
    BEFORE DELETE ON runs
    BEGIN
      SELECT RAISE(ABORT, 'append-only: runs cannot be deleted');
    END;
    """)

    op.execute("""
    CREATE TRIGGER IF NOT EXISTS trg_reviews_no_update
    BEFORE UPDATE ON reviews
    BEGIN
      SELECT RAISE(ABORT, 'append-only: reviews cannot be updated');
    END;
    """)
    op.execute("""
    CREATE TRIGGER IF NOT EXISTS trg_reviews_no_delete
    BEFORE DELETE ON reviews
    BEGIN
      SELECT RAISE(ABORT, 'append-only: reviews cannot be deleted');
    END;
    """)

    op.execute("""
    CREATE TRIGGER IF NOT EXISTS trg_links_no_update
    BEFORE UPDATE ON links
    BEGIN
      SELECT RAISE(ABORT, 'append-only: links cannot be updated');
    END;
    """)
    op.execute("""
    CREATE TRIGGER IF NOT EXISTS trg_links_no_delete
    BEFORE DELETE ON links
    BEGIN
      SELECT RAISE(ABORT, 'append-only: links cannot be deleted');
    END;
    """)


def downgrade() -> None:
    # drop triggers first
    op.execute("DROP TRIGGER IF EXISTS trg_links_no_delete;")
    op.execute("DROP TRIGGER IF EXISTS trg_links_no_update;")
    op.execute("DROP TRIGGER IF EXISTS trg_reviews_no_delete;")
    op.execute("DROP TRIGGER IF EXISTS trg_reviews_no_update;")
    op.execute("DROP TRIGGER IF EXISTS trg_runs_no_delete;")
    op.execute("DROP TRIGGER IF EXISTS trg_runs_no_update;")
    op.execute("DROP TRIGGER IF EXISTS trg_prompt_packs_no_delete;")
    op.execute("DROP TRIGGER IF EXISTS trg_prompt_packs_no_update;")

    op.drop_index("ix_links_rel", table_name="links")
    op.drop_index("ix_links_dst", table_name="links")
    op.drop_index("ix_links_src", table_name="links")
    op.drop_table("links")

    op.drop_index("ix_reviews_run_id", table_name="reviews")
    op.drop_table("reviews")

    op.drop_index("ix_runs_status", table_name="runs")
    op.drop_index("ix_runs_prompt_pack_id", table_name="runs")
    op.drop_table("runs")

    op.drop_index("ix_prompt_packs_digest", table_name="prompt_packs")
    op.drop_table("prompt_packs")

    op.drop_index("ix_assets_sha256", table_name="assets")
    op.drop_index("ix_assets_kind", table_name="assets")
    op.drop_table("assets")
