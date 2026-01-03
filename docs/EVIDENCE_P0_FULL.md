# P0 FULL Regression Evidence

- Generated at (UTC): 2025-12-31T16:26:08Z
- Branch: dev/batch8-provider-adapter-p1
- HEAD: 9dc078cb70dab8dc4d8836caba4bdffad94d07c0
- Command: bash scripts/gate_all.sh --mode=full

## Required gates (min set) + e2e
- gate_api_smoke
- gate_openapi_reachable
- gate_health_contract_check
- gate_request_id_propagation_check
- gate_ac_001
- gate_ac_002
- gate_ac_003
- gate_ac_004
- gate_e2e_happy_path

## Key [ok] lines (run 1)
```text
[ok] /health keys present: status, version, db, storage, last_error_summary
[ok] header present: X-Request-Id (non-empty)
[ok] /openapi.json reachable
[ok] /health keys present: status, version, db, storage, last_error_summary
[ok] header present: X-Request-Id (non-empty)
[ok] /openapi.json reachable
[ok] error path header present: X-Request-Id (non-empty)
[ok] error envelope includes request_id and required keys
[ok] gate_api_smoke passed
[ok] /openapi.json reachable
[ok] off -> json ok
[ok] flag OFF -> POST /runs ok run_id=01KDTKKM6VSN0K578PG3ZQX489 status=queued
[ok] flag OFF -> GET ok status=queued result_refs_keys=[]
[ok] on -> json ok
[ok] flag ON -> POST /runs ok run_id=01KDTKKNRX6HQF7CZ0AYRWE05S status=succeeded
[ok] flag ON -> GET ok status=succeeded refs_count=1
[ok] artifact exists: ./data/storage\runs\01KDTKKNRX6HQF7CZ0AYRWE05S\result.json
[ok] forced fail -> error_envelope ok request_id=95afba86-f203-4701-bb24-72483c19e1a2 run_id=01KDTKKQT1N3ZHQN6KAV85NN23
[ok] forced fail -> GET ok status=failed
[ok] server ready (http://127.0.0.1:2000)
[ok] route ok: /
[ok] route ok: /library
[ok] route ok: /assets/test-asset
[ok] route ok: /generate
[ok] route ok: /projects
[ok] route ok: /projects/test-project
[ok] route ok: /series
[ok] route ok: /series/test-series
[ok] route ok: /shots
[ok] route ok: /shots/test-shot
[ok] routes accessible: /, /library, /assets/:id, /generate (+ placeholders)
[ok] api reachable: /openapi.json
[ok] /assets returns items[] + page{limit,offset,total,has_more}
[ok] server ready (http://127.0.0.1:2000)
[ok] route ok: /
[ok] route ok: /library
[ok] route ok: /assets/test-asset
[ok] route ok: /generate
[ok] route ok: /projects
[ok] route ok: /projects/test-project
[ok] route ok: /series
[ok] route ok: /series/test-series
[ok] route ok: /shots
[ok] route ok: /shots/test-shot
[ok] routes accessible: /, /library, /assets/:id, /generate (+ placeholders)
[ok] /library source contains required sections markers (FiltersBar/AssetGrid/BulkActionBar)
[ok] api reachable: /openapi.json
[ok] picked asset_id=EA89F56409A04B87B5CDA7FA64D605C2
[ok] /assets/:id returns an object
[ok] error envelope includes error/message/request_id/details
[ok] server ready (http://127.0.0.1:2000)
[ok] route ok: /
[ok] route ok: /library
[ok] route ok: /assets/test-asset
[ok] route ok: /generate
[ok] route ok: /projects
[ok] route ok: /projects/test-project
[ok] route ok: /series
[ok] route ok: /series/test-series
[ok] route ok: /shots
[ok] route ok: /shots/test-shot
[ok] routes accessible: /, /library, /assets/:id, /generate (+ placeholders)
[ok] asset detail source contains required panel markers
[ok] api reachable: /openapi.json
[ok] create run: type=t2i run_id=01KDTKMZ9CJAXHNRMECF6ZRH3V request_id=94570dad-7e7f-406b-a577-2a489eebb67a
[ok] refresh run: run_id=01KDTKMZ9CJAXHNRMECF6ZRH3V
[ok] create run: type=i2i run_id=01KDTKMZGP5ST95NQND02200QX request_id=fa49da17-9e5b-4640-9bc6-86734e6c4f3c
[ok] refresh run: run_id=01KDTKMZGP5ST95NQND02200QX
[ok] create run: type=t2v run_id=01KDTKMZQS9AMWDWMX03JP88BY request_id=ccb9539f-9708-4f6f-9761-e5f35e3b9c82
[ok] refresh run: run_id=01KDTKMZQS9AMWDWMX03JP88BY
[ok] create run: type=i2v run_id=01KDTKMZXKDBNRVKT4TE9Z87ZG request_id=e7c04825-5684-4ee1-a74c-8346ec113ea9
[ok] refresh run: run_id=01KDTKMZXKDBNRVKT4TE9Z87ZG
[ok] create run for each type; status refreshed
[ok] server ready (http://127.0.0.1:2000)
[ok] route ok: /
[ok] route ok: /library
[ok] route ok: /assets/test-asset
[ok] route ok: /generate
[ok] route ok: /projects
[ok] route ok: /projects/test-project
[ok] route ok: /series
[ok] route ok: /series/test-series
[ok] route ok: /shots
[ok] route ok: /shots/test-shot
[ok] routes accessible: /, /library, /assets/:id, /generate (+ placeholders)
[ok] /generate source contains required section markers (InputTypeSelector/PromptEditor/RunQueuePanel/ResultsPanel)
[ok] api reachable: /openapi.json
[ok] override missing reason rejected; error envelope ok; request_id=2b255ca8-4174-4ee7-b2f7-eb5020fcf5c9
[ok] server ready (http://127.0.0.1:2000)
[ok] route ok: /
[ok] route ok: /library
[ok] route ok: /assets/test-asset
[ok] route ok: /generate
[ok] route ok: /projects
[ok] route ok: /projects/test-project
[ok] route ok: /series
[ok] route ok: /series/test-series
[ok] route ok: /shots
[ok] route ok: /shots/test-shot
[ok] routes accessible: /, /library, /assets/:id, /generate (+ placeholders)
[ok] Review UI markers present and wired
[ok] request_id sample: tmp/_out_gate_ac_003.txt:request_id=94570dad-7e7f-406b-a577-2a489eebb67a
[ok] e2e happy path passed
[ok] shots list returns items+page with required keys
[ok] shots detail returns shot + linked_refs summary
[ok] creating link works and appears in linked_refs
[ok] deleting link uses tombstone semantics and effective view is updated
[ok] /openapi.json reachable
[ok] /shots renders (http=200)
[ok] picked shot_id: 00363326BCB248A5B341B04BDF3CE2A6
[ok] /shots/:shot_id renders (http=200)
[ok] link created link_id=1BC19897051840E787F802B5E5649758
[ok] link removed (tombstone semantics)
```

## request_id samples (run 1)
```text
tmp/_out_gate_ac_003.txt:request_id=94570dad-7e7f-406b-a577-2a489eebb67a
tmp/_out_gate_ac_003.txt:request_id=fa49da17-9e5b-4640-9bc6-86734e6c4f3c
tmp/_out_gate_ac_003.txt:request_id=ccb9539f-9708-4f6f-9761-e5f35e3b9c82
tmp/_out_gate_ac_003.txt:request_id=e7c04825-5684-4ee1-a74c-8346ec113ea9
tmp/_out_gate_ac_004.txt:request_id=2b255ca8-4174-4ee7-b2f7-eb5020fcf5c9
```

## Raw logs
- tmp/_out_gate_*

## BATCH-1 / STEP-020 Data Model & Migrations (v1.1)

### Snapshot
- last-green baseline (given): `9dc078cb70dab8dc4d8836caba4bdffad94d07c0`
- branch: `dev/v1_1-batch1-step020-data_model`
- head: `e26bf410fe890a843a40a6bad8897a922b71ca22`
- recorded_at_utc: `2026-01-01T06:05:54Z`
- migration:
  - revision: `0004_characters_provider_profiles`
  - down_revision: `0003_optional_hierarchy`

### Data Model Lock Alignment

#### characters
- id (TEXT, PK)
- name (TEXT)
- status (TEXT) values: draft|confirmed|archived
- active_ref_set_id (TEXT, nullable) — **no FK in Batch-1** (avoid cycle); enforce in Batch-2B
- created_at (TEXT)
- updated_at (TEXT)

#### character_ref_sets (append-only)
- id (TEXT, PK)
- character_id (TEXT, FK → characters.id)
- version (INTEGER, NOT NULL)
- status (TEXT) values: draft|confirmed|archived
- min_requirements_snapshot_json (TEXT, NOT NULL)
- created_at (TEXT)
- invariants:
  - unique(character_id, version): `uq_character_ref_sets_character_id_version` (unique index)
  - append-only triggers:
    - `trg_character_ref_sets_no_update`
    - `trg_character_ref_sets_no_delete`

#### provider_profiles
- id (TEXT, PK)
- name (TEXT)
- provider_type (TEXT)
- config_json (TEXT) — may contain secrets; APIs must never echo secrets in plaintext (Batch-2A)
- secrets_redaction_policy_json (TEXT)
- is_global_default (INTEGER 0|1, default 0)
- created_at (TEXT)
- updated_at (TEXT)
- invariants:
  - at most one global default via partial unique index:
    - `uq_provider_profiles_global_default` WHERE is_global_default = 1

### Verification Evidence (excerpts)

#### gate_models (schema presence)
~~~text
== gate_models: start ==
[ok] alembic upgrade head ok
[ok] required tables exist: assets, prompt_packs, runs, reviews, links, projects, series, shots, characters, character_ref_sets, provider_profiles
[ok] assets.deleted_at present
[ok] assets.project_id/series_id nullable (unbound allowed)
[ok] immutability policy enforced (append-only triggers present)
[ok] unique index present: character_ref_sets(character_id, version)
[ok] unique index present: uq_provider_profiles_global_default
[ok] optional hierarchy nullable columns ok
[ok] gate_models passed
[ok] gate_models passed
~~~

#### gate_append_only_ref_sets (behavior; runs on tmp db copy)
~~~text
== gate_append_only_ref_sets: start ==
== [info] tmpdb=E:/01Small_Tools/AI_Content_Generation_Workstation/ai-content-workstation/tmp/gate_append_only_ref_sets.28120/app.db ==
== [info] using tmpdb=tmp\gate_append_only_ref_sets.28120\app.db ==
[ok] triggers present (tmpdb)
[ok] unique index present (tmpdb): uq_character_ref_sets_character_id_version
[ok] unique index present (tmpdb): uq_provider_profiles_global_default
[ok] inserted gate_test rows
[ok] unique constraint enforced: UNIQUE constraint failed: character_ref_sets.character_id, character_ref_sets.version
[ok] append-only UPDATE blocked: append-only: character_ref_sets cannot be updated
[ok] append-only DELETE blocked: append-only: character_ref_sets cannot be deleted
[ok] inserted provider_profiles default=1 row
[ok] global default unique enforced: UNIQUE constraint failed: provider_profiles.is_global_default
[ok] gate_append_only_ref_sets passed
== gate_append_only_ref_sets: passed ==
~~~

#### gate_all --mode=preflight (no regression)
~~~text
== gate_all: start ==
== [info] mode=preflight repeat=1 ts=20260101_055643 ==
== [info] branch=dev/v1_1-batch1-step020-data_model head=e26bf410fe890a843a40a6bad8897a922b71ca22 ==
== [run] 1/1 ==
== api_smoke: start ==
== gate_api_smoke: start ==
== gate_health_contract_check ==
[ok] /health keys present: status, version, db, storage, last_error_summary
== gate_request_id_propagation_check ==
[ok] header present: X-Request-Id (non-empty)
== gate_openapi_reachable ==
[ok] /openapi.json reachable
== gate_error_envelope_check ==
[ok] error path header present: X-Request-Id (non-empty)
[ok] error envelope includes request_id and required keys
[ok] gate_api_smoke passed
== api_smoke: passed ==
== gate_export_import: start ==
== [info] API_BASE_URL=http://127.0.0.1:7000 ==
== [info] PY=E:/01Small_Tools/AI_Content_Generation_Workstation/ai-content-workstation/apps/api/.venv/Scripts/python.exe ==
== [info] TMPDIR=E:/01Small_Tools/AI_Content_Generation_Workstation/ai-content-workstation/tmp/gate_export_import.2086 ==
[ok] openapi has exports/imports paths
[ok] export create request_id=85D526E7BC404160BDA229040FB1EC27
[ok] export_id=2E119840188641EFB4648E27565B9775
[ok] manifest readable (no import); request_id=5C440B7C398B4B218FAB6E6BD6F94BCD
== [info] asset_table=assets expected=376 ==
== [info] link_table=links expected=5184 ==
[ok] bad manifest returns error envelope + request_id
[ok] import create request_id=3B223B63063B42009579FD0CC60B2CD4
[ok] import_id=FA305B425C054CAD89F57D54FADC4FE1
[ok] import completed
[ok] relationships (links) preserved: imported=5184
== gate_export_import: done ==
== gate_all: passed ==
~~~

### Rollback Notes
- Code rollback anchor: `9dc078cb70dab8dc4d8836caba4bdffad94d07c0`
- DB rollback: `alembic downgrade 0003_optional_hierarchy` (or restore a pre-upgrade DB backup)


## BATCH-4A Settings UI (ProviderProfiles)

### Manual Acceptance (UI)
- Open: `/settings`
- Create profile (with secret) → List shows **configured status** (no secret plaintext)
- Set Default → Only one default visible
- Edit profile: leave secret empty → configured should NOT flip to false
- Delete profile → List refreshed; on failure show message + request_id

### Automated Gate (Optional)
- `bash scripts/gate_settings_ui.sh`
  - Captured key request_id(s):
    - create: `<request_id>`
    - set_default: `<request_id>`
    - delete: `<request_id>`


## BATCH-4B Characters UI (RefSets/Refs)

### Manual Acceptance (UI)
- Open: `/characters`
- New Character → Open detail
- Create draft ref_set → Add ≥8 refs via Asset Picker
- Create confirmed version (append-only) → Set Active (only confirmed)
- Refresh page → active_ref_set_id stays consistent
- Any error must show message + request_id

### Automated Gate (Optional)
- `bash scripts/gate_characters_ui.sh`
  - Captured key request_id(s):
    - create character: `<request_id>`
    - create draft ref_set: `<request_id>`
    - add refs: `<request_id>`
    - create confirmed ref_set: `<request_id>`
    - set active: `<request_id>`
