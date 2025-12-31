# CR — BATCH-2 Soft Delete API Completion (Required by BATCH-5)

## 0) CR Metadata
- CR ID: `CR-BATCH2-SoftDelete-001`
- Requester: `BATCH-5 UI (Bulk soft delete + Trash view)`
- Priority: High (blocks P1 usability)
- Conflict domain: `api_routes / delete_policy`
- Date: `2025-12-31`

## 1) Motivation (Why)
BATCH-5 requires:
- Library bulk soft delete (assets disappear from default list)
- Trash view lists deleted assets via `include_deleted=true`

Current backend OpenAPI evidence shows only:
- `GET /assets`
- `GET /assets/{asset_id}`
No soft delete endpoint exists, causing UI calls to return `404/405`.

## 2) Hard Locks (must keep)
- delete_is_soft: `true`
- list_default_excludes_deleted: `true`
- include_deleted flag: `include_deleted=true`
- trash_empty endpoint: `/trash/empty`
- request-id header: `X-Request-Id` (propagate + log)
- error envelope keys: `error, message, request_id, details`
- Ports: web `2000`, api `7000`

## 3) Proposed Change (Minimal API additions)
### 3.1 Add soft delete endpoint
- Add: `DELETE /assets/{asset_id}`
- Semantics: Soft delete only (mark deleted), MUST NOT hard-delete.
- Response:
  - 200: standard success payload (either deleted asset snapshot or `{ok:true}`), but MUST include `X-Request-Id` header.
  - 404: error envelope if asset not found
  - 409/422 (optional): error envelope for invalid state

### 3.2 Enforce list semantics (confirm existing behavior)
- `GET /assets`:
  - Default: excludes deleted assets
  - When `include_deleted=true`: includes deleted assets
- `GET /assets/{asset_id}`:
  - Define whether deleted assets are fetchable:
    - Preferred: return deleted asset unless `include_deleted=false` and deleted -> 404 with error envelope
  - Must be documented in OpenAPI.

### 3.3 Trash empty (confirm existing)
- Keep: `POST /trash/empty`
- Behavior: removes deleted assets from storage (high risk), return success with request_id

## 4) Acceptance Criteria (Definition of Done)
- API:
  - `DELETE /assets/{asset_id}` exists in `/openapi.json`
  - Delete performs soft delete (asset disappears from default `GET /assets`)
  - `GET /assets?include_deleted=true` returns deleted assets
- Observability:
  - All paths return `X-Request-Id`
  - Errors use error envelope with required keys
- Regression:
  - Existing gates (P0) remain green

## 5) Verification / Gates
- Add/Update:
  - `scripts/gate_delete_soft.sh`
    - create asset -> DELETE /assets/{id} -> confirm removed from default list
    - confirm appears when include_deleted=true
  - Ensure `scripts/gate_all.sh --mode=full` remains green
- Manual smoke:
  - UI: /library bulk soft delete succeeds (no 404/405), deleted appears in /trash

## 6) Rollback Plan
- `git revert <merge_commit_sha>`
- Post-rollback: run `bash scripts/gate_all.sh --mode=full`

## 7) Notes / Non-Goals
- No change to core routing or App Shell
- No hard delete introduction
- No CORS changes required if frontend uses `/api_proxy` (same-origin)
