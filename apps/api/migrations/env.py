from __future__ import annotations

import os
import sys
from pathlib import Path
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool
from alembic import context

THIS = Path(__file__).resolve()
API_DIR = THIS.parents[1]  # apps/api
sys.path.insert(0, str(API_DIR))

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# STEP-030: bootstrap only (no metadata yet). STEP-040 will set target_metadata.
target_metadata = None


def _repo_root() -> Path:
    # apps/api/migrations/env.py -> repo root = parents[3]
    return THIS.parents[3]


def _resolve_sqlite_url(url: str) -> str:
    if not url.startswith("sqlite:///"):
        return url
    p = url[len("sqlite:///") :]

    # absolute unix
    if p.startswith("/"):
        return url

    # absolute windows drive
    if len(p) >= 3 and p[1] == ":" and (p[2] == "/" or p[2] == "\\"):
        return url

    abs_path = (_repo_root() / p).resolve()
    abs_path.parent.mkdir(parents=True, exist_ok=True)
    return "sqlite:///" + abs_path.as_posix()


def get_url() -> str:
    url = os.getenv("DATABASE_URL", "sqlite:///./data/app.db")
    return _resolve_sqlite_url(url)


def run_migrations_offline() -> None:
    url = get_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    configuration = config.get_section(config.config_ini_section) or {}
    configuration["sqlalchemy.url"] = get_url()

    connectable = engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
        future=True,
    )

    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
