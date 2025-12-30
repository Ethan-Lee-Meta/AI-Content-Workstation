# HANDOFF — BATCH-2 (PHASE-P0 / api_contract)

- Branch: dev/batch2-api-contract__20251229_211207
- HEAD: (run: git rev-parse HEAD)

## Delivered endpoints (min set)
- GET /assets
- GET /assets/{asset_id}
- POST /runs
- GET /runs/{run_id}
- POST /reviews
- POST /trash/empty

## Contract notes
- Pagination: offset/limit; response `items` + `page{limit,offset,total,has_more}`; default limit=50; max=200
- Assets list: default excludes deleted; `include_deleted=true` supported
- Error envelope on 4xx/5xx: `error,message,request_id,details` and echoes `X-Request-Id`
- Evidence chain: PromptPack/Run/Review append-only; retry creates new Run
- Trash: `/trash/empty` purges soft-deleted assets and emits `trash.empty` audit event

## Gates
- gate_api_smoke: pass
- gate_assets_read: pass
- gate_runs_core: pass
- gate_reviews: pass
- gate_trash: pass
