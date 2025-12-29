# HANDOFF — BATCH-1 (PHASE-P0 / data_model)

## Freeze / Fingerprints
- AI_SPECDIGEST sha256: `NA`
- ARCH_DIGEST sha256: `NA`
- MASTER_PLAN sha256: `NA`

## Git
- Branch: `dev/batch1-data-model`
- HEAD: `b39e511bbc8b70e43694136686ccdcf8db250cb2`

## What was delivered
### STEP-020/030 — DB/Storage skeleton
- SQLite default: `DATABASE_URL=sqlite:///./data/app.db`
- local_fs default: `STORAGE_ROOT=./data/storage`
- /health top-level keys preserved: `status, version, db, storage, last_error_summary`
- Added db/storage detail reporting in /health.db and /health.storage
- Alembic runnable; bootstrap revision exists

### STEP-040 — Core entities v0 (evidence chain)
- Tables: `assets, prompt_packs, runs, reviews, links`
- Invariants:
  - `assets.deleted_at` exists (soft delete placeholder)
  - Append-only enforced via SQLite triggers (no UPDATE/DELETE) for: `prompt_packs, runs, reviews, links`

### STEP-050 — Optional hierarchy entities
- Tables: `projects, series, shots`
- `assets.project_id` and `assets.series_id` are **nullable** (unbound assets allowed)
- Nullable relationship columns:
  - `series.project_id` nullable
  - `shots.project_id` nullable
  - `shots.series_id` nullable

## Migrations
- Alembic current: `0003_optional_hierarchy (head)`

## Gates (expected to pass)
- `bash scripts/gate_models.sh`
- `bash scripts/gate_db_storage.sh`
- `bash scripts/gate_api_smoke.sh` (requires API running on 127.0.0.1:7000; can be started via uvicorn)

## Notes / Risks
- Append-only is enforced at DB-level via SQLite triggers for the listed tables. Any future API layer must avoid UPDATE/DELETE on those tables; retries should create new rows (new Run/Review/PromptPack versions).
