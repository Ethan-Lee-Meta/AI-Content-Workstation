"""optional hierarchy v0 (Project/Series/Shot) + nullable bindings on Asset (defensive)

Revision ID: 0003_optional_hierarchy
Revises: 0002_core_entities
Create Date: 2025-12-29
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0003_optional_hierarchy"
down_revision = "0002_core_entities"
branch_labels = None
depends_on = None


def _table_exists(conn, name: str) -> bool:
    rows = conn.execute(sa.text("SELECT name FROM sqlite_master WHERE type='table' AND name=:n"), {"n": name}).fetchall()
    return len(rows) > 0


def _index_exists(conn, name: str) -> bool:
    rows = conn.execute(sa.text("SELECT name FROM sqlite_master WHERE type='index' AND name=:n"), {"n": name}).fetchall()
    return len(rows) > 0


def _column_exists(conn, table: str, col: str) -> bool:
    rows = conn.execute(sa.text(f"PRAGMA table_info('{table}')")).fetchall()
    # (cid, name, type, notnull, dflt_value, pk)
    return any(r[1] == col for r in rows)


def upgrade() -> None:
    conn = op.get_bind()

    # --- projects ---
    if not _table_exists(conn, "projects"):
        op.execute("""
        CREATE TABLE projects (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT,
          created_at TEXT NOT NULL
        );
        """)
    if not _index_exists(conn, "ix_projects_name"):
        op.execute("CREATE INDEX IF NOT EXISTS ix_projects_name ON projects (name);")

    # --- series ---
    if not _table_exists(conn, "series"):
        op.execute("""
        CREATE TABLE series (
          id TEXT NOT NULL PRIMARY KEY,
          project_id TEXT,
          name TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY(project_id) REFERENCES projects(id)
        );
        """)
    if not _index_exists(conn, "ix_series_project_id"):
        op.execute("CREATE INDEX IF NOT EXISTS ix_series_project_id ON series (project_id);")
    if not _index_exists(conn, "ix_series_name"):
        op.execute("CREATE INDEX IF NOT EXISTS ix_series_name ON series (name);")

    # --- shots ---
    if not _table_exists(conn, "shots"):
        op.execute("""
        CREATE TABLE shots (
          id TEXT NOT NULL PRIMARY KEY,
          project_id TEXT,
          series_id TEXT,
          name TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY(project_id) REFERENCES projects(id),
          FOREIGN KEY(series_id) REFERENCES series(id)
        );
        """)
    if not _index_exists(conn, "ix_shots_project_id"):
        op.execute("CREATE INDEX IF NOT EXISTS ix_shots_project_id ON shots (project_id);")
    if not _index_exists(conn, "ix_shots_series_id"):
        op.execute("CREATE INDEX IF NOT EXISTS ix_shots_series_id ON shots (series_id);")

    # --- assets optional bindings (must remain nullable) ---
    if not _column_exists(conn, "assets", "project_id"):
        op.add_column("assets", sa.Column("project_id", sa.Text(), sa.ForeignKey("projects.id"), nullable=True))
    if not _column_exists(conn, "assets", "series_id"):
        op.add_column("assets", sa.Column("series_id", sa.Text(), sa.ForeignKey("series.id"), nullable=True))

    # indexes on assets bindings
    if not _index_exists(conn, "ix_assets_project_id"):
        op.execute("CREATE INDEX IF NOT EXISTS ix_assets_project_id ON assets (project_id);")
    if not _index_exists(conn, "ix_assets_series_id"):
        op.execute("CREATE INDEX IF NOT EXISTS ix_assets_series_id ON assets (series_id);")


def downgrade() -> None:
    # Best-effort downgrade (SQLite drop-column is non-trivial; keep minimal safety)
    conn = op.get_bind()
    # drop indexes
    op.execute("DROP INDEX IF EXISTS ix_assets_series_id;")
    op.execute("DROP INDEX IF EXISTS ix_assets_project_id;")
    op.execute("DROP INDEX IF EXISTS ix_shots_series_id;")
    op.execute("DROP INDEX IF EXISTS ix_shots_project_id;")
    op.execute("DROP INDEX IF EXISTS ix_series_name;")
    op.execute("DROP INDEX IF EXISTS ix_series_project_id;")
    op.execute("DROP INDEX IF EXISTS ix_projects_name;")

    # drop tables
    op.execute("DROP TABLE IF EXISTS shots;")
    op.execute("DROP TABLE IF EXISTS series;")
    op.execute("DROP TABLE IF EXISTS projects;")
