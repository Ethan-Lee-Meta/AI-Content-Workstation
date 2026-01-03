# HANDOFF — PHASE P0 (Standalone)

> 交接原则：下一个窗口只拿本文件即可继续开发；不依赖/不引用任何其它 handoff 文档。

## 0) Identity / Fingerprints
- Generated (UTC): 2025-12-30T06:31:32Z
- Branch: dev/batch2-api-contract__20251229_211207
- HEAD: 1dbbd21d82ce310412a08093cd5a90dcb69b0a2a

### Frozen inputs (sha256)
- AI_SPECDIGEST: 77b334b8533592dbe7c74adb7d5e5e36a13266c23d95cdc72705c84a319e03cf
- ARCH_DIGEST: adfb12f1a7ebc21cf15d5052213532bd3a484ebd19e2ad4e3b782eac11f216ca
- MASTER_PLAN (frozen): d0da8fd4f392a77639da02347c96d32309366a28deb28fc88f8597f9b91e054a
- DEVELOPMENT_BATCHES (frozen): ef2fcc316b7d2fdbaa098f061c638577e3a560d135e2a5b929d3c38d123d414b
- TASK_ASSIGNMENT (frozen): 41a68c71e0adc90aeedb5ffd60fa4e9e3d6068ab80c3724de61a9c6fada30b76

### Local OpenAPI artifact (optional; not required to proceed)
- tmp/openapi_batch2.json sha256: cfd38ce0b22688355b81d85c1373a2b188e4d9fc642b80c962c62262ef7eb16c

## 1) Runtime locks (do not change without Change Request)
- API host/port: `127.0.0.1:7000`
- Web dev server port (reserved by architecture): `2000`
- Request ID header: `X-Request-Id`
- Error envelope keys (on 4xx/5xx): `error`, `message`, `request_id`, `details`
- Health endpoint: `/health` top-level keys MUST include: `status`, `version`, `db`, `storage`, `last_error_summary`

## 2) What is implemented (P0 API Contract Slice)
本阶段已跑通“最小可用垂直切片”与门禁脚本，具备给前端直接调用/联调的 API 基础能力：

### 2.1 Assets (read path + soft-delete support)
- `GET /assets`
  - Query: `offset` (default 0), `limit` (default 50, max 200), `include_deleted` (default false)
  - Response:
    - `items: Asset[]`
    - `page: { limit, offset, total, has_more }`
- `GET /assets/{asset_id}`
  - Response includes:
    - Asset fields
    - traceability refs (用于后续关联 PromptPack / Run / Review 等证据链)

> 说明：资产当前支持“软删除字段”语义（deleted_at 等），列表默认不含 deleted，`include_deleted=true` 可查看。

### 2.2 Runs (append-only evidence)
- `POST /runs`
  - Creates a new Run (evidence is append-only; retry creates a NEW Run id)
  - Response includes at least:
    - `run_id`
    - `prompt_pack_id`
    - `status`
- `GET /runs/{run_id}`
  - Response includes:
    - `status`
    - result refs (为后续生成结果/资产链接预留)

### 2.3 Reviews (manual + override w/ reason)
- `POST /reviews`
  - Supports manual review
  - Supports override, but **override must include reason** (否则应返回 error envelope)

### 2.4 Trash (purge deleted assets)
- `POST /trash/empty`
  - Purges soft-deleted assets (物理清理 deleted 的资产记录/文件，active 保留)
  - Must:
    - return ok + `purged_assets >= 1` (当存在可清理项时)
    - echo `X-Request-Id`
    - emit audit event `trash.empty` (通过 uvicorn log 可观测)

## 3) Cross-cutting behavior (must keep stable)
- Request ID:
  - If request missing `X-Request-Id`, server generates one
  - Server echoes `X-Request-Id` on success AND on error responses
- Error envelope:
  - 404/validation errors etc return JSON with keys: `error,message,request_id,details`
- Health:
  - `/health` always has stable top-level keys and includes db/storage detail objects

## 4) How to run (dev)
### 4.1 Start API (Windows Git Bash)
From repo root:
- `./apps/api/.venv/Scripts/python.exe -m uvicorn app.main:app --app-dir apps/api --host 127.0.0.1 --port 7000`

Env defaults (if not set):
- `APP_VERSION=0.1.0`
- `DATABASE_URL=sqlite:///./data/app.db`
- `STORAGE_ROOT=./data/storage`

### 4.2 Quick check
- `curl -s http://127.0.0.1:7000/health`

## 5) Gates (must stay green)
Gate scripts (repo root):
- `bash scripts/gate_api_smoke.sh`
- `bash scripts/gate_assets_read.sh`
- `bash scripts/gate_runs_core.sh`
- `bash scripts/gate_reviews.sh`
- `bash scripts/gate_trash.sh`

Batch-2 all-gates runner（如果你已有 tmp/step-a.sh，也可继续使用；否则以上逐个执行即可）：
- 期望：全部返回 rc=0

## 6) Where to continue coding (next window guidance)
### 6.1 Add a new module
Pattern:
- Create folder: `apps/api/app/modules/<module_name>/`
- Files (suggested):
  - `__init__.py`
  - `schemas.py`
  - `service.py`
  - `router.py`
- Wire router in: `apps/api/app/main.py` via `app.include_router(...)`

### 6.2 Recommended next steps (typical)
- Assets write path（上传/创建/更新）与更多字段校验
- Runs ↔ Assets 的结果落库与 Link 关系（证据链更完整）
- Reviews 状态机更细化（审批/拒绝/回滚策略）
- 前端（apps/web）调用上述 endpoints，形成最小 UI 闭环（列表/详情/触发 Run/Review/Trash）

## 7) Known operational notes
- On Windows, Git may warn `LF will be replaced by CRLF` — these warnings do not block execution.
- If port 7000 is occupied, uvicorn will fail to bind; stop existing process or change nothing and free the port (port is locked by architecture).
