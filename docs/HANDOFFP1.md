# HANDOFF — AI Content Workstation (Merged) — v1.0 Shipped + v1.1 Batch-1/2/3 (SSOT, Single-File)

本文件是**唯一交接产物**（self-contained）。它合并并固化：
- 项目整体分析（架构/模块/数据模型/运行方式/后续指南）
- P0/P1 累积交付（契约锁/门禁/运行手册/批次交付）
- v1.1 Batch-1（STEP-020 Data Model）
- v1.1 Batch-2（ProviderProfiles/Characters/Runs Trace v11）
- v1.1 Batch-3（STEP-080 UI Routes Skeleton / IA Lock：Characters + Settings 路由与导航入口）

目标：让接手者在**不额外问问题**的情况下，能完成：
1) 本地启动 API(7000) + Web(2000)；
2) 跑通门禁（至少 `gate_all --mode=preflight`；UI 相关至少 `gate_web_routes.sh`）；
3) 理解系统 SSOT/append-only 不变量与导出导入语义；
4) 在 v1.1 基线上继续开发后续批次（UI / ProviderProfiles / Characters / ProviderAdapter 等），并保持基线不回归。

---

## -1) Quick Index（导航）
- [0) Snapshot](#0-snapshot)
- [0.1 Hard Locks](#01-hard-locks不可变更项如需变更必须走-cr)
- [0.2 Delta Summary](#02-delta-summary最新增量与当前窗口交付)
- [1) System Overview](#1-system-overview项目定位与核心工作流)
- [2) Architecture & Tech Stack](#2-architecture--tech-stack)
- [3) Repository Layout](#3-repository-layout)
- [4) Backend Contract Surface](#4-backend-contract-surface已交付能力按契约视角)
- [5) Data Model & Invariants](#5-data-model--invariants)
- [6) Gates & Evidence](#6-gates--evidence门禁与证据)
- [7) Development Runbook](#7-development-runbook启动构建与常见问题)
- [8) Known Issues / Non-goals](#8-known-issues--non-goals)
- [9) Next Steps](#9-next-steps后续开发建议)
- [Appendix A — 15-min Onboarding Checklist](#appendix-a--15-min-onboarding-checklist接手者-15-分钟上手清单)

---

## 0) Snapshot

> 本节需要在“提交完成后”由维护者用下列命令填入；交接者应确保快照与仓库一致。

### 0.1 Current Handoff Head (this window)
- Branch: `<git rev-parse --abbrev-ref HEAD>`
- HEAD: `<git rev-parse HEAD>`
- Generated at (UTC): `<date -u +%Y-%m-%dT%H:%M:%SZ>`

填充命令（复制执行）：
- `git rev-parse --abbrev-ref HEAD`
- `git rev-parse HEAD`
- `date -u +%Y-%m-%dT%H:%M:%SZ`

### 0.2 “至少通过”的关键门禁（本交付闭环）
- UI 路由与 IA Lock：
  - `bash scripts/gate_web_routes.sh` => PASS（Batch-3 必须）
- 数据/契约相关（建议至少 preflight）：
  - `bash scripts/gate_all.sh --mode=preflight`
  - `bash scripts/gate_models.sh`
  - `bash scripts/gate_append_only_ref_sets.sh`
  - `bash scripts/gate_runs_trace_v11.sh`

---

## 0.1 Hard Locks（不可变更项；如需变更必须走 CR）

### 端口锁
- Web dev server: `2000`
- API server: `7000`

### API 契约锁（必须保持）
- Request ID header：`X-Request-Id`
- Error envelope 必含 keys：`error`, `message`, `request_id`, `details`
- Pagination 响应形态固定：
  - 顶层：`items`, `page`
  - page：`limit`, `offset`, `total`, `has_more`
- `/health` 必含 keys：`status`, `version`, `db`, `storage`, `last_error_summary`
- `/openapi.json` 必须可达

### 关系与证据链不变量（必须保持）
- `links` 是跨对象关系的唯一来源（SSOT）
- 多处 append-only：通过 SQLite triggers 禁止 UPDATE/DELETE（新增证据只可追加）
- Links 的“删除”通过 tombstone（`unlink::<rel>`）语义实现，非物理 delete

### 不允许提交的内容
- `.venv/`、`venv/`、`__pycache__/`、`*.pyc` 等（必须被 `.gitignore` 覆盖；若被误加入索引需 `git rm -r --cached` 清理）
- `data/`、`*.db`、`*.sqlite*`（本地状态不得提交）
- `tmp/` 下的 gate 输出文件默认不提交（如需证据只写入 docs/EVIDENCE，不提交 tmp）

---

## 0.2 Delta Summary（最新增量与当前窗口交付）

### v1.0 已交付（累积）
- Assets：列表/详情/软删除；Trash empty
- Runs：ProviderAdapter feature flag；run_events 覆盖状态（append-only）
- Reviews：override 必须有 reason
- Shots + Links：SSOT；tombstone 取消关联
- Exports/Imports：目录包；manifest 无导入预览；导入后关系保持
- Web：Next.js App Router + API proxy + Shots/Transfer UI
- 门禁体系：`gate_all.sh --mode=preflight/full` 与各子 gate

### v1.1 Batch-1（STEP-020 Data Model）已交付
- 新增表：
  - `characters`
  - `character_ref_sets`（append-only，禁止 UPDATE/DELETE）
  - `provider_profiles`（支持“全局默认唯一”）
- Alembic 迁移：`0004_characters_provider_profiles`
- 门禁：`gate_models.sh` / `gate_append_only_ref_sets.sh` 增强与新增

### v1.1 Batch-2（Runs Trace v11 + PromptPack 持久化 + Trace chain 修复）
- `/runs` 创建 run 时：
  - `prompt_pack_id` 关联写入 `runs.prompt_pack_id`
  - `prompt_packs.content` 写入 JSON payload（包含 raw_input/final_prompt/assembly_used/...）
  - （如列存在）`prompt_packs.digest` 写入 sha256（best-effort）
- `/assets/{asset_id}` 的 `traceability.chain` 可靠生成（run/prompt_pack/provider_profile/characters）
- 全局 Validation Error 输出 JSON-safe（避免 Pydantic v2 ctx 导致 500）

### v1.1 Batch-3（STEP-080 UI Routes Skeleton / IA Lock）已交付
目标：不依赖 Batch-2 API 完整 UI，实现“路由可达 + App Shell + 导航入口 + 骨架占位 + 不触发 Next 构建错误”。

交付能力：
- 路由（HTTP 200）：
  - `/characters`（骨架页 + 轻量交互占位）
  - `/characters/[character_id]`（骨架详情页；展示 character_id；RefSet/Assets 占位）
  - `/settings`（ProviderProfiles 占位；secrets 不回显提示；轻量交互占位）
- 导航入口（Sidebar）：
  - Characters → `/characters`
  - Settings → `/settings`
- 门禁：
  - `bash scripts/gate_web_routes.sh` PASS（包含 next build + next start + curl 探测）
- Next.js 兼容性处理：
  - 避免 `searchParams is a Promise` 风险：新页面不依赖 searchParams
  - 动态 params 兼容：`/characters/[character_id]` 使用 `async` 并 `await params`
  - `"use client"` 页面不得导出 `metadata`：通过 “server page wrapper + client component” 方式解决

本次 next build 路由摘要（示例）：
- `○ /characters`（Static）
- `ƒ /characters/[character_id]`（Dynamic）
- `○ /settings`（Static）

本次 gate_web_routes 关键输出（示例）：
- `[ok] route ok: /characters`
- `[ok] route ok: /characters/test-character`
- `[ok] route ok: /settings`
- `== gate_web_routes: passed ==`

合并单元（Batch-3 期望 touched files ≤ 10）：
- apps/web/app/characters/page.js
- apps/web/app/characters/CharactersClient.js
- apps/web/app/characters/[character_id]/page.js
- apps/web/app/settings/page.js
- apps/web/app/settings/SettingsClient.js
- apps/web/app/_components/Sidebar.js
- scripts/gate_web_routes.sh

---

## 1) System Overview（项目定位与核心工作流）
AI Content Workstation 是单机单用户的 AI 内容生成与资产管理平台，覆盖：
生成（runs/provider）→ 入库（assets）→ 审核（reviews）→ 追溯（prompt_packs/runs/links）
→ Shot 编排（shots+links）→ 导出/导入迁移（exports/imports）。

核心差异点：
- 不可变证据链（append-only）
- Links 关系 SSOT（统一关系事实来源）
- 可携带导出目录包 + manifest（无导入预览）

---

## 2) Architecture & Tech Stack

### Backend
- FastAPI + Uvicorn
- SQLite（默认 `data/app.db`；可用 `DATABASE_URL` 覆盖）
- Alembic（迁移）
- Append-only：SQLite triggers 强制

### Frontend
- Next.js（App Router）
- React 18.x
- API Proxy：`/api_proxy/*` → `http://127.0.0.1:7000/*`
- App Shell：`apps/web/app/layout.js` 统一包裹 `AppShell`（Sidebar/Topbar/MainContent/InspectorDrawer）

### Storage
- DB：`data/app.db`
- 文件存储：`data/storage/`
- 导出：`data/exports/{export_id}/`
- 导入：`data/imports/{import_id}/`

---

## 3) Repository Layout

ai-content-workstation/
├── apps/
│   ├── api/
│   │   ├── app/
│   │   │   ├── main.py
│   │   │   ├── core/
│   │   │   └── modules/
│   │   │       ├── assets/
│   │   │       ├── runs/
│   │   │       ├── reviews/
│   │   │       ├── shots/
│   │   │       ├── trash/
│   │   │       ├── exports_imports/
│   │   │       ├── characters/
│   │   │       └── provider_profiles/
│   │   └── migrations/
│   │       └── versions/
│   └── web/
│       └── app/
│           ├── layout.js
│           ├── _components/
│           │   ├── AppShell.*
│           │   ├── Sidebar.js
│           │   └── ...
│           ├── characters/
│           │   ├── page.js
│           │   ├── CharactersClient.js
│           │   └── [character_id]/page.js
│           └── settings/
│               ├── page.js
│               └── SettingsClient.js
├── docs/
└── scripts/
    └── gate_web_routes.sh

---

## 4) Backend Contract Surface（已交付能力按契约视角）

### 4.1 Observability / Baseline
- `GET /health`：keys 固定 `status, version, db, storage, last_error_summary`
- `GET /openapi.json`
- `X-Request-Id`：入站可带；出站必回显；错误也必须带
- Error envelope（统一格式）：
```json
{ "error": "...", "message": "...", "request_id": "...", "details": {} }
4.2 Assets（软删除）
GET /assets?offset=&limit=&include_deleted=

GET /assets/{asset_id}：返回 asset + traceability（含 best-effort chain enrichment）

DELETE /assets/{asset_id}：soft delete（幂等）

4.3 Trash
POST /trash/empty：清理 soft-deleted 资产（best-effort 删除文件）

4.4 Provider Types / Provider Profiles（v1.1 Batch-2）
GET /provider_types

GET /provider_profiles

POST /provider_profiles：创建；secret 不回显（redaction）

DELETE /provider_profiles/{id}：删除/清理；不得残留默认

全局默认唯一：DB partial unique + API 层保证一致性

4.5 Characters / RefSets（v1.1 Batch-2）
POST /characters

POST /characters/{id}/ref_sets（draft ver=1 起）

POST /characters/{id}/ref_sets/{ref_set_id}/refs（追加 refs）

POST /characters/{id}/ref_sets/{ref_set_id}/confirm（draft → confirmed；ver+1）

PATCH /characters/{id}（或等价）：设置 active_ref_set_id（必须拒绝 draft）

4.6 Runs（v1.1 Batch-2：Runs Trace v11）
POST /runs

prompt_pack lock：assembly_used=true 时必须有 assembly_prompt

产出：run + produced asset + links(run -> produced_asset -> asset)

GET /runs/{run_id}

5) Data Model & Invariants
5.1 全局不变量
append-only：关键证据表禁止 UPDATE/DELETE（SQLite triggers）

Links SSOT：跨实体关系只有 links 作为事实来源

Assets 软删除：deleted_at；Trash empty 才物理清理

5.2 v1.1 Batch-1 新增表（锁定项）
characters：id/name/status/active_ref_set_id/created_at/updated_at

character_ref_sets（append-only）：id/character_id/version/status/min_requirements_snapshot_json/created_at；triggers 禁止 UPDATE/DELETE

provider_profiles：id/name/provider_type/config_json/secrets_redaction_policy_json/is_global_default/created_at/updated_at

5.3 PromptPacks（v1.1 Batch-2）
prompt_packs(id, name, content, digest, created_at)

约定：content 存 JSON 字符串；digest best-effort sha256(content)

6) Gates & Evidence（门禁与证据）
6.1 必跑门禁（建议顺序）
UI（Batch-3）：

bash scripts/gate_web_routes.sh

内含：next build + next start(:2000) + curl required routes

期望包含：

[ok] route ok: /characters

[ok] route ok: /characters/test-character

[ok] route ok: /settings

== gate_web_routes: passed ==

Data/Contract（建议）：

bash scripts/gate_models.sh

bash scripts/gate_append_only_ref_sets.sh

bash scripts/gate_provider_profiles.sh

bash scripts/gate_characters.sh

bash scripts/gate_runs_trace_v11.sh

bash scripts/gate_all.sh --mode=preflight

6.2 Evidence
docs/EVIDENCE_P0_FULL.md：应持续追加关键变更与门禁输出片段（只贴关键 [ok] 行，不贴大段 HTML）

建议为 Batch-3 追加最小证据段落：

新增路由清单（/characters /characters/[id] /settings）

gate_web_routes 的 3 条新增 [ok] 行

记录一次 Next.js 限制："use client" + export metadata 会 build error（已通过 server wrapper 修复）

7) Development Runbook（启动/构建/常见问题）
7.1 启动后端（API :7000）
bash
复制代码
cd apps/api
python -m uvicorn app.main:app --host 0.0.0.0 --port 7000 --reload
验证：

curl -sS http://127.0.0.1:7000/health

curl -sS http://127.0.0.1:7000/openapi.json | head

7.2 启动前端（Web :2000）
bash
复制代码
cd apps/web
npm i
npm run dev -- --port 2000
7.3 UI 路由快速自检（不依赖后端）
浏览器打开（应 200）：

http://127.0.0.1:2000/characters

http://127.0.0.1:2000/characters/test-character

http://127.0.0.1:2000/settings

7.4 常见故障排查（Batch-3 相关）
构建报错：You are attempting to export "metadata" from a component marked with "use client"

规则："use client" 文件不能 export const metadata

解决：page 保持 server（导出 metadata），交互逻辑放入 *Client.js 并由 page import 渲染

Next sync-dynamic-apis 兼容：

尽量不读 searchParams（骨架阶段最安全）

动态路由读取 params：使用 async function Page({ params }) { const p = await params; ... }

8) Known Issues / Non-goals
Batch-3 明确不做：

Characters 完整 CRUD / RefSet 管理（后续 Batch-4B + Batch-2B 配合）

ProviderProfiles 完整 CRUD UI（后续 Batch-4A + Batch-2A 配合）

任意后端 API 变更

gate_all --mode=full 可能包含环境/feature flag 强相关项（例如 provider_adapter）；full 失败不等于 Batch-3 未完成，Batch-3 以 gate_web_routes PASS 为闭环。

9) Next Steps（后续开发建议）
优先顺序建议：

提交本文件 snapshot（填入 branch/head/time）并固化到 docs/（作为唯一交接件）

将 Batch-3 的 PASS 片段补到 docs/EVIDENCE_P0_FULL.md

Batch-4A：Settings → ProviderProfiles UI（列表/新增/设默认/删除；secrets redaction）

Batch-4B：Characters UI（列表/详情/RefSet 切换/引用资产选择）

若要求 full 全绿：集中修复 provider_adapter gate 与 full 模式失败项，并把原因写入 evidence

Appendix A — 15-min Onboarding Checklist（接手者 15 分钟上手清单）
检出分支并确认快照

git checkout <handoff-branch>

git rev-parse --abbrev-ref HEAD && git rev-parse HEAD

启动 API（7000）并确认

/health keys 正确

/openapi.json 可达

启动 Web（2000）并打开关键页面

/library /generate /shots /transfer

Batch-3 新增：/characters /characters/test-character /settings

跑门禁（建议顺序）

bash scripts/gate_web_routes.sh

bash scripts/gate_models.sh

bash scripts/gate_append_only_ref_sets.sh

bash scripts/gate_provider_profiles.sh

bash scripts/gate_characters.sh

bash scripts/gate_runs_trace_v11.sh

（建议）bash scripts/gate_all.sh --mode=preflight

若失败优先看

tmp/_out_gate_*.txt（脚本输出）

docs/EVIDENCE_P0_FULL.md（证据对照）

Next.js 构建类错误优先排查 "use client" / metadata / params/searchParams Promise 兼容点