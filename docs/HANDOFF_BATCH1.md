# HANDOFF — BATCH-1 (PHASE-P0 / data_model)

## Freeze / Fingerprints (source of truth: gate_all --mode=preflight)
- AI_SPECDIGEST sha256: `77b334b8533592dbe7c74adb7d5e5e36a13266c23d95cdc72705c84a319e03cf`  (path: E:\01Small_Tools\AI_Content_Generation_Workstation\ai-content-workstation\docs\01_AI_SPECDIGEST.yaml)
- ARCH_DIGEST sha256: `adfb12f1a7ebc21cf15d5052213532bd3a484ebd19e2ad4e3b782eac11f216ca`  (path: E:\01Small_Tools\AI_Content_Generation_Workstation\ai-content-workstation\docs\02_ARCH_DIGEST.yaml)
- MASTER_PLAN sha256: `cf659999b6876860413ef12f38f959e0b9dbd8247dba6f39b173299d5ca87345`  (path: E:\01Small_Tools\AI_Content_Generation_Workstation\ai-content-workstation\docs\03_MASTER_PLAN_frozen.yaml)

## Git
- Branch: `dev/batch1-data-model`
- HEAD: `46b3a7998dea1625106b382042e04a6c3a72a1b8`

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
