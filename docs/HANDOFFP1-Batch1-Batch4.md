# HANDOFF — AI Content Workstation (Merged) — v1.0 Shipped + v1.1 Batch-1/2/3/4 (SSOT, Single-File)

本文件是**唯一交接产物**（self-contained）。它合并并固化：
- 项目整体分析（架构/模块/数据模型/运行方式/后续指南）
- P0/P1 累积交付（契约锁/门禁/运行手册/批次交付）
- v1.1 Batch-1（STEP-020 Data Model）
- v1.1 Batch-2（ProviderProfiles/Characters/Runs Trace v11）
- v1.1 Batch-3（STEP-080 UI Routes Skeleton / IA Lock：Characters + Settings 路由与导航入口）
- v1.1 Batch-4A（Settings：ProviderProfiles UI 可操作闭环 + gate_settings_ui）
- v1.1 Batch-4B（Characters：角色库 + RefSets/Refs 可操作闭环 + gate_characters_ui）

目标：让接手者在**不额外问问题**的情况下，能完成：
1) 本地启动 API(7000) + Web(2000)；
2) 跑通门禁（至少 `gate_all --mode=preflight`；UI 相关至少 `gate_web_routes.sh` + Batch-4 UI gates）；
3) 理解系统 SSOT/append-only 不变量与导出导入语义；
4) 在 v1.1 基线上继续开发后续批次（Batch-5/6/7/8…），并保持基线不回归。

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
- Branch: `dev/v1_1-batch1-step020-data_model`
- HEAD: `50f08e2deccb94ef1a1eba3e4d326b0d9dafa224`
- Generated at (UTC): `2026-01-04T03:01:01Z`

填充命令（复制执行）：
```bash
git rev-parse --abbrev-ref HEAD
git rev-parse HEAD
date -u +%Y-%m-%dT%H:%M:%SZ
0.2 “至少通过”的关键门禁（本交付闭环）
UI 路由与 IA Lock（Batch-3 基线）：

bash scripts/gate_web_routes.sh => PASS（next build + next start + required routes）

Batch-4 UI 闭环（本次新增）：

bash scripts/gate_settings_ui.sh => PASS（ProviderProfiles：create/list/configured/set_default/delete）

bash scripts/gate_characters_ui.sh => PASS（Characters：create/ref_sets/refs>=8/confirmed/set_active）

数据/契约相关（建议至少 preflight）：

bash scripts/gate_all.sh --mode=preflight

bash scripts/gate_models.sh

bash scripts/gate_append_only_ref_sets.sh

bash scripts/gate_runs_trace_v11.sh

0.1 Hard Locks（不可变更项；如需变更必须走 CR）
端口锁
Web dev server: 2000

API server: 7000

API 契约锁（必须保持）
Request ID header：X-Request-Id

Error envelope 必含 keys：error, message, request_id, details

Pagination 响应形态固定：

顶层：items, page

page：limit, offset, total, has_more

/health 必含 keys：status, version, db, storage, last_error_summary

/openapi.json 必须可达

关系与证据链不变量（必须保持）
links 是跨对象关系的唯一来源（SSOT）

多处 append-only：通过 SQLite triggers 禁止 UPDATE/DELETE（新增证据只可追加）

Links 的“删除”通过 tombstone（unlink::<rel>）语义实现，非物理 delete

不允许提交的内容
.venv/、venv/、__pycache__/、*.pyc 等（必须被 .gitignore 覆盖；若被误加入索引需 git rm -r --cached 清理）

data/、*.db、*.sqlite*（本地状态不得提交）

tmp/ 下的 gate 输出文件默认不提交（如需证据只写入 docs/EVIDENCE，不提交 tmp）

本地 patch 备份文件（建议忽略）：*.bak_* / *.bak.*

0.2 Delta Summary（最新增量与当前窗口交付）
v1.0 已交付（累积）
Assets：列表/详情/软删除；Trash empty

Runs：ProviderAdapter feature flag；run_events 覆盖状态（append-only）

Reviews：override 必须有 reason

Shots + Links：SSOT；tombstone 取消关联

Exports/Imports：目录包；manifest 无导入预览；导入后关系保持

Web：Next.js App Router + API proxy + Shots/Transfer UI

门禁体系：gate_all.sh --mode=preflight/full 与各子 gate

v1.1 Batch-1（STEP-020 Data Model）已交付
新增表：

characters

character_ref_sets（append-only，禁止 UPDATE/DELETE）

provider_profiles（支持“全局默认唯一”）

Alembic 迁移：0004_characters_provider_profiles

门禁：gate_models.sh / gate_append_only_ref_sets.sh 增强与新增

v1.1 Batch-2（Runs Trace v11 + PromptPack 持久化 + Trace chain 修复）
/runs 创建 run 时：

prompt_pack_id 关联写入 runs.prompt_pack_id

prompt_packs.content 写入 JSON payload（包含 raw_input/final_prompt/assembly_used/...）

（如列存在）prompt_packs.digest 写入 sha256（best-effort）

/assets/{asset_id} 的 traceability.chain 可靠生成（run/prompt_pack/provider_profile/characters）

全局 Validation Error 输出 JSON-safe（避免 Pydantic ctx 导致 500）

v1.1 Batch-3（STEP-080 UI Routes Skeleton / IA Lock）已交付
目标：不依赖 Batch-2 API 完整 UI，实现“路由可达 + App Shell + 导航入口 + 骨架占位 + 不触发 Next 构建错误”。

交付能力：

路由（HTTP 200）：

/characters（骨架页 + 轻量占位）

/characters/[character_id]（骨架详情页；展示 character_id；RefSet/Assets 占位）

/settings（ProviderProfiles 占位；secrets 不回显提示；轻量占位）

导航入口（Sidebar）：

Characters → /characters

Settings → /settings

门禁：

bash scripts/gate_web_routes.sh PASS（next build + next start(:2000) + curl 探测 required routes）

Next.js 兼容性处理：

动态 params：/characters/[character_id] 使用 async 并 await params

"use client" 页面不导出 metadata：通过 “server page wrapper + client component” 方式解决

v1.1 Batch-4A（Settings：ProviderProfiles UI 可操作闭环）已交付
目标：在契约锁前提下实现 /settings 的 CRUD+默认闭环，且错误含 request_id、后端未就绪可降级。

交付能力：

/settings：

ProviderProfiles 列表分页（offset/limit + page.total/has_more）

New Profile（创建）

Edit（修改 name/config；secrets write-only 覆盖语义）

Set Default（全局默认唯一）

Delete（删除后刷新列表）

“后端未就绪/404” 显示降级提示，不崩溃；所有后端错误展示 request_id（ErrorPanel）

ProviderProfiles secrets 语义（与契约锁一致）：

secrets 为 write-only（请求体中提交），响应不回显明文

响应提供 configured 状态：secrets_configured、secrets_configured_json

新增/强化门禁：

scripts/gate_settings_ui.sh：create → list(no secret plaintext) → configured=true → set_default → delete

Windows CRLF 兼容：gate 从 /provider_types 取出的 key 会 strip CR，避免尾随 \r 造成 configured 误判

v1.1 Batch-4B（Characters：角色库 + RefSets/Refs 可操作闭环）已交付
目标：/characters 列表与 /characters/:id 详情可完成“创建角色→ref_set 版本→添加 refs≥8→创建 confirmed→设 active”闭环。

交付能力：

/characters：列表页可渲染；创建角色并跳转详情（依赖后端可用时走真实 API；后端未就绪可降级）

/characters/[character_id]：

RefSet 版本化（append-only）：通过 POST 创建 draft/confirmed 版本，不对旧版本做更新

Add refs（>=8）：批量添加资产引用

Set Active（仅 confirmed）：设置 active_ref_set_id

错误展示 request_id

新增/强化门禁：

scripts/gate_characters_ui.sh：create character → create draft ref_set → add 8 refs → create confirmed ref_set → patch active_ref_set_id

1) System Overview（项目定位与核心工作流）
AI Content Workstation 是单机单用户的 AI 内容生成与资产管理平台，覆盖：
生成（runs/provider）→ 入库（assets）→ 审核（reviews）→ 追溯（prompt_packs/runs/links）
→ Shot 编排（shots+links）→ 导出/导入迁移（exports/imports）。

核心差异点：

不可变证据链（append-only）

Links 关系 SSOT（统一关系事实来源）

可携带导出目录包 + manifest（无导入预览）

2) Architecture & Tech Stack
Backend
FastAPI + Uvicorn

SQLite（默认 data/app.db；可用 DATABASE_URL 覆盖）

Alembic（迁移）

Append-only：SQLite triggers 强制

Frontend
Next.js（App Router）

React 18.x

API Proxy：/api_proxy/* → http://127.0.0.1:7000/*

App Shell：apps/web/app/layout.js 统一包裹 AppShell（Sidebar/Topbar/MainContent/InspectorDrawer）

Storage
DB：data/app.db

文件存储：data/storage/

导出：data/exports/{export_id}/

导入：data/imports/{import_id}/

3) Repository Layout
ai-content-workstation/

text
复制代码
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
│           │   ├── ErrorPanel.js
│           │   └── ...
│           ├── characters/
│           │   ├── page.js
│           │   ├── CharactersClient.js
│           │   └── [character_id]/
│           │       ├── page.js
│           │       └── CharacterDetailClient.js
│           └── settings/
│               ├── page.js
│               ├── SettingsClient.js
│               └── ProviderProfileFormModal.js
├── docs/
│   ├── EVIDENCE_P0_FULL.md
│   └── HANDOFFP1.md   (this file)
└── scripts/
    ├── gate_web_routes.sh
    ├── gate_settings_ui.sh
    ├── gate_characters_ui.sh
    └── gate_all.sh
4) Backend Contract Surface（已交付能力按契约视角）
4.1 Observability / Baseline
GET /health：keys 固定 status, version, db, storage, last_error_summary

GET /openapi.json

X-Request-Id：入站可带；出站必回显；错误也必须带

Error envelope（统一格式）：

json
复制代码
{ "error": "...", "message": "...", "request_id": "...", "details": {} }
4.2 Assets（软删除）
GET /assets?offset=&limit=&include_deleted=

GET /assets/{asset_id}：返回 asset + traceability（含 best-effort chain enrichment）

DELETE /assets/{asset_id}：soft delete（幂等）

4.3 Trash
POST /trash/empty：清理 soft-deleted 资产（best-effort 删除文件）

4.4 Provider Types / Provider Profiles（v1.1 Batch-2 + Batch-4A 修正/闭环）
GET /provider_types

返回：items[]（包含 config_hints、secrets_hints 等用于 UI 动态表单渲染的信息）

GET /provider_profiles?offset=&limit=

列表分页形态：{ items, page{limit,offset,total,has_more} }

secrets 永不明文回显

configured 状态：secrets_configured（bool）、secrets_configured_json（dict）

POST /provider_profiles

创建 profile；支持 write-only secrets 输入（字段名以 openapi 为准）

响应不含 secret 明文，但含 configured 状态

PATCH /provider_profiles/{id}

更新 name/config；支持覆盖 secrets（不填则不修改）

POST /provider_profiles/{id}/set_default

设全局默认（唯一）

DELETE /provider_profiles/{id}

删除/清理；删除默认后默认为空（需用户选择新的默认）

备注：本仓库实现将 secrets 视为敏感信息（类似 API key），只允许“写入/覆盖”，不提供明文回显。

4.5 Characters / RefSets（v1.1 Batch-2 + Batch-4B UI 闭环）
GET /characters?offset=&limit=

POST /characters

GET /characters/{id}

PATCH /characters/{id}（含设置 active_ref_set_id；后端应拒绝 draft）

POST /characters/{id}/ref_sets（创建新版本：draft 或 confirmed；append-only）

POST /characters/{id}/ref_sets/{ref_set_id}/refs（追加 refs）

confirmed 最小门槛：refs ≥ 8（失败返回 error envelope + request_id）

4.6 Runs（v1.1 Batch-2：Runs Trace v11）
POST /runs：prompt_pack lock（assembly_used=true 时必须有 assembly_prompt）

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
UI（Batch-3 基线）：

bash
复制代码
bash scripts/gate_web_routes.sh
Batch-4 UI 闭环：

bash
复制代码
bash scripts/gate_settings_ui.sh
bash scripts/gate_characters_ui.sh
Data/Contract（建议至少 preflight）：

bash
复制代码
bash scripts/gate_all.sh --mode=preflight
6.2 Gate 期望（关键输出片段示例）
gate_web_routes.sh：

route ok: /characters, /characters/test-character, /settings

== gate_web_routes: passed ==

gate_settings_ui.sh：

picked provider_type + secret_key

created profile_id

list does not contain dummy secret

configured=true

set_default + delete

== gate_settings_ui: done rc=0 ==

gate_characters_ui.sh：

created character_id

created draft ref_set_id

add refs: added=8 failed=0

created confirmed ref_set_id

patch set active_ref_set_id

== gate_characters_ui: done rc=0 ==

6.3 Evidence
docs/EVIDENCE_P0_FULL.md：持续追加关键变更与门禁输出片段（只贴关键 [ok] 行，不贴大段 HTML）

7) Development Runbook（启动/构建/常见问题）
7.1 启动后端（API :7000）
优先使用仓库脚本，确保使用 venv（避免 pydantic 版本不匹配）：

bash
复制代码
bash scripts/dev_api.sh
验证：

bash
复制代码
curl -sS http://127.0.0.1:7000/health
curl -sS http://127.0.0.1:7000/openapi.json | head
7.2 启动前端（Web :2000）
在 apps/web 下启动（端口 2000 固定）：

bash
复制代码
cd apps/web
npm i
npm run dev -- --port 2000
7.3 UI 路由快速自检
浏览器打开（应 200）：

http://127.0.0.1:2000/characters

http://127.0.0.1:2000/characters/test-character

http://127.0.0.1:2000/settings

7.4 Next.js 常见限制
"use client" 文件不得导出 metadata

动态 params：App Router 下 params/searchParams 可能为 Promise；server page 用 async 并 await params

8) Known Issues / Non-goals
已知问题（Known Issues）
gate_export_import 在数据量较大或环境慢时，可能出现一次性 curl timeout (60s) 的日志，但脚本可能仍判定整体 PASS（以脚本退出码为准）。如需排查：

先复跑 bash scripts/gate_export_import.sh（若存在）或单独复跑 bash scripts/gate_all.sh --mode=preflight

关注对应 tmp 目录下输出与 request_id

Non-goals（当前版本不做）
不在 Batch-4 范围内引入新的核心实体/改端口/改契约字段（必须走 CR）

不提供 secrets 明文回显（安全策略：write-only）

不在本批次修复与 UI 无关的 full 模式环境差异项（以 preflight 为主闭环）

9) Next Steps（后续开发建议）
优先顺序建议：

固化 Snapshot（填入 branch/head/time）并确保 handoff 为 SSOT

若需要继续推进 v1.1 UI 完整化：

Batch-5：Generate 工作台（Prompt 组装/角色选择/Review 联动增强）

Batch-6：Library/AssetDetail 完整化（筛选、批量、回收站体验）

Batch-7/8：门禁与交接收口（全链路可重复验证、Evidence 标准化）

Appendix A — 15-min Onboarding Checklist（接手者 15 分钟上手清单）
检出分支并确认快照

bash
复制代码
git rev-parse --abbrev-ref HEAD
git rev-parse HEAD
启动 API（7000）并确认

bash
复制代码
bash scripts/dev_api.sh
curl -sS http://127.0.0.1:7000/health
curl -sS http://127.0.0.1:7000/openapi.json | head
启动 Web（2000）并打开关键页面

bash
复制代码
cd apps/web
npm i
npm run dev -- --port 2000
打开：

/library /generate /shots /transfer

/characters /characters/test-character /settings

跑门禁（建议顺序）

bash
复制代码
bash scripts/gate_web_routes.sh
bash scripts/gate_settings_ui.sh
bash scripts/gate_characters_ui.sh
bash scripts/gate_all.sh --mode=preflight
若失败优先看

gate 输出（脚本 stdout）

docs/EVIDENCE_P0_FULL.md（证据对照）

Next.js 构建类错误优先排查 "use client" / metadata / params/searchParams Promise 兼容点

yaml
复制代码

---

## 保存后建议你立刻做一次“文档一致性验证”
（确保 handoff 不会再出现“Batch-4 仍在 Next Steps/Non-goals”的陈述冲突）

```bash
(
  set -e
  ROOT="$(git rev-parse --show-toplevel)"
  cd "$ROOT"
  grep -nE "Batch-4A|Batch-4B|gate_settings_ui|gate_characters_ui" docs/HANDOFFP1.md | head -n 50
)
---

## BATCH-5 — Trash (API + UI)

### Delivered Capabilities
- Soft delete: `DELETE /assets/{asset_id}` writes `assets.deleted_at` (idempotent).
- Restore: `DELETE /assets/{asset_id}?action=restore` clears `deleted_at` (idempotent).
- Trash list: `GET /assets?include_deleted=true` supports Trash view (client filters `deleted_at != null`).
- Empty trash: `POST /trash/empty` physically deletes soft-deleted asset rows and returns `deleted_count` + `request_id`.
- Traceability preserved: delete/restore do not rewrite links; post-restore chain remains usable.

### Verification Gates
- `bash scripts/gate_trash.sh` must PASS (delete → trash → restore → delete → empty → verify removed).
- `bash scripts/gate_all.sh --mode=preflight` must PASS (non-regression).

### UI Notes
- `/library` includes view toggle (Library | Trash), row actions (Delete/Restore), bulk actions, and Empty Trash.
- Failures must show error envelope with `request_id`.
