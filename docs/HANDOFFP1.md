# HANDOFF — AI Content Workstation (Merged) — v1.0 Shipped + v1.1 STEP-020 Data Model (SSOT, Single-File)

本文件是**唯一交接产物**（self-contained）。它合并了：
- `PROJECT_ANALYSIS.md`（项目整体分析：架构/模块/数据模型/运行方式/后续指南）
- `HANDOFF_P0_CUMULATIVE.md`（P0/P1 累积交接：契约锁/门禁/运行手册/批次交付）

目标：让接手者在**不额外问问题**的情况下，能完成：
1) 本地启动 API(7000) + Web(2000)；
2) 跑通门禁（至少 `gate_all --mode=preflight`；建议 `--mode=full`）；
3) 理解系统的 SSOT/append-only 不变量与导出导入语义；
4) 在 v1.1 的基础上继续开发 **Characters / ProviderProfiles API（Batch-2A/2B）**，并保持基线不回归。

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
- [8) v1.1 Next Steps](#8-v11-next-stepsbatch-2a2b-开发指南)
- [9) Rollback Strategy](#9-rollback-strategy回滚策略)

---

## 0) Snapshot

### 0.1 Current Handoff Head (this window)
- Branch: `dev/v1_1-batch1-step020-data_model`
- HEAD: `7e4ec73042e9a9d4db2e582bd44e74cd923b593f`
- Commit subject: `v1.1 batch1 step020: data model + migration + append-only gates`

### 0.2 Baseline Anchor (last-green before v1.1 step020)
- Code rollback anchor (given): `9dc078cb70dab8dc4d8836caba4bdffad94d07c0`

### 0.3 Local verification (expected)
- `bash scripts/gate_models.sh` => rc=0
- `bash scripts/gate_append_only_ref_sets.sh` => rc=0
- `bash scripts/gate_all.sh --mode=preflight` => rc=0

---

## 0.1 Hard Locks（不可变更项；如需变更必须走 CR）

### 端口锁
- Web dev server: `2000`
- API server: `7000`

### 目录契约（允许/禁止范围）
- ✅允许编辑：`apps/web/**`, `apps/api/**`, `docs/**`, `scripts/**`
- ❌禁止新增顶层目录：`infra/**`, `services/**`（若需新增必须走 CR）
- ❌禁止编辑：`vendor/**`, `.github/workflows/**`

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

---

## 0.2 Delta Summary（最新增量与当前窗口交付）

### v1.0 已交付（累积到 BATCH-10 / BATCH-9）
- Assets（列表/详情/软删除）+ Trash empty
- Runs（ProviderAdapter feature flag；run_events 覆盖状态）
- Reviews（override reason 强约束）
- Shots + Links 编排（SSOT；tombstone 取消关联）
- Exports/Imports（目录包；manifest 无导入预览；导入后关系保持）
- Web（Next.js App Router + API proxy + Shots/Transfer UI 等）
- 门禁体系：`gate_all.sh --mode=preflight/full` 与各子 gate

### v1.1 新增（本窗口：BATCH-1 / STEP-020 Data Model）
目标：在不破坏 v1 基线（preflight PASS）的前提下，引入新数据模型与不变量。
交付摘要：
- 新增三张表：
  - `characters`
  - `character_ref_sets`（append-only，禁止 UPDATE/DELETE）
  - `provider_profiles`（支持“全局默认唯一”）
- Alembic 迁移：
  - revision: `0004_characters_provider_profiles`
  - down_revision: `0003_optional_hierarchy`
- 门禁增强：
  - `scripts/gate_models.sh` 增强（检查新表/索引/触发器）
  - 新增 `scripts/gate_append_only_ref_sets.sh`（行为性验证：append-only + unique + 默认唯一）
- 证据：
  - `docs/EVIDENCE_P0_FULL.md` 已写入 STEP-020 段落（字段清单/迁移 revision/关键 gate 片段/回滚说明）

关键实现决策（强制对齐冻结 ARCH 锁定项）：
- `characters.active_ref_set_id` **本批次不做 FK**（避免循环依赖）；一致性由后续 API（Batch-2B）保证。

---

## 1) System Overview（项目定位与核心工作流）

AI Content Workstation 是一个**单机单用户**的 AI 内容生成与资产管理平台，覆盖：
生成（runs/provider）→ 入库（assets）→ 审核（reviews）→ 追溯（prompt_packs/runs/reviews/links）→ Shot 编排（shots+links）→ 导出/导入迁移（exports/imports）。

核心差异点：
- 不可变证据链（append-only）
- Links 关系 SSOT（统一关系来源，避免多处存关系导致不一致）
- 可携带导出目录包 + 无导入预览 manifest

---

## 2) Architecture & Tech Stack

### 2.1 Backend
- FastAPI + Uvicorn
- SQLite（默认 `data/app.db`）
- SQLAlchemy/SQLModel（模型层）
- Alembic（迁移）
- Append-only 通过 SQLite triggers 强制

### 2.2 Frontend
- Next.js（App Router）
- React 18.x
- 同源 API Proxy：`/api_proxy/*` → 7000

### 2.3 Storage
- DB：`data/app.db`
- 文件存储：`data/storage/`
- 导出：`data/exports/{export_id}/`
- 导入：`data/imports/{import_id}/`

---

## 3) Repository Layout

ai-content-workstation/
├── apps/
│ ├── api/
│ │ ├── app/
│ │ │ ├── main.py
│ │ │ ├── core/
│ │ │ └── modules/
│ │ │ ├── assets/
│ │ │ ├── runs/
│ │ │ ├── reviews/
│ │ │ ├── shots/
│ │ │ ├── trash/
│ │ │ ├── exports_imports/
│ │ │ ├── characters/ # v1.1新增
│ │ │ └── provider_profiles/ # v1.1新增
│ │ └── migrations/
│ │ └── versions/
│ │ ├── 0003_optional_hierarchy.py
│ │ └── 0004_characters_provider_profiles.py
│ └── web/
│ └── app/
│ ├── api_proxy/
│ ├── library/
│ ├── assets/[asset_id]/
│ ├── generate/
│ ├── shots/
│ ├── trash/
│ └── transfer/
├── data/
├── docs/
│ ├── HANDOFF_P0_CUMULATIVE.md
│ └── EVIDENCE_P0_FULL.md
└── scripts/
├── gate_all.sh
├── gate_models.sh
└── gate_append_only_ref_sets.sh # v1.1新增

yaml
复制代码

---

## 4) Backend Contract Surface（已交付能力按契约视角）

### 4.1 Observability / Baseline
- `GET /health`：含 keys `status, version, db, storage, last_error_summary`
- `GET /openapi.json`：可达
- Request tracing：响应 echo `X-Request-Id`
- Error envelope（统一错误格式）：
```json
{ "error": "...", "message": "...", "request_id": "...", "details": {} }
4.2 Assets（软删除）
GET /assets?offset=&limit=&include_deleted=

GET /assets/{id}

DELETE /assets/{id}：soft delete（幂等）

4.3 Trash
POST /trash/empty：清理所有 soft-deleted 资产（best-effort 删除文件）

4.4 Runs / ProviderAdapter
POST /runs

GET /runs/{run_id}

ProviderAdapter Feature Flag（示例）：PROVIDER_ENABLED=0|1

append-only：不 UPDATE runs，状态/result_refs 由 run_events 追加覆盖

4.5 Reviews
override 必须有 reason（门禁已覆盖）

4.6 Shots + Links（SSOT）
GET /shots

GET /shots/{shot_id}（包含 linked_refs，从 Links 计算且应用 tombstone）

POST /shots/{shot_id}/links（创建 link，返回 link_id）

DELETE /shots/{shot_id}/links/{link_id}（取消关联：写入 tombstone）

4.7 Exports / Imports（AC-006）
/exports + /imports（manifest 无导入预览；导入保持 links 关系）

Feature flag（回滚优先）：EXPORT_IMPORT_ENABLED=0|1

5) Data Model & Invariants
5.1 核心不变量（全局）
append-only：关键证据表（以及 character_ref_sets）禁止 UPDATE/DELETE（SQLite triggers）

Links SSOT：跨实体关系只有 Links 作为事实来源

Assets 软删除：deleted_at 存在；Trash empty 才物理清理

5.2 v1.1 新增表（BATCH-1 / STEP-020）
5.2.1 characters
用途：角色实体（角色库）
字段（锁定项）：

id (TEXT, PK)

name (TEXT)

status (TEXT) 值域：draft | confirmed | archived

active_ref_set_id (TEXT, nullable) —— 本批次不做 FK

created_at (TEXT)

updated_at (TEXT)

索引（建议/实现以迁移为准）：

status

name（可选）

5.2.2 character_ref_sets（append-only）
用途：角色参考集版本（可追溯；append-only）
字段（锁定项）：

id (TEXT, PK)

character_id (TEXT, FK → characters.id)

version (INTEGER) 1..n

status (TEXT) 值域：draft | confirmed | archived

min_requirements_snapshot_json (TEXT) —— JSON 文本，记录门槛快照（≥8 推荐12 等）

created_at (TEXT)

强约束（必须实现，已落地）：

append-only triggers（禁止 UPDATE/DELETE）：

trg_character_ref_sets_no_update

trg_character_ref_sets_no_delete

版本唯一（已落地为 DB unique index）：

unique(character_id, version) => uq_character_ref_sets_character_id_version

5.2.3 provider_profiles
用途：ProviderProfile（Settings 可增删改设默认；后续 API 实现）
字段（锁定项）：

id (TEXT, PK)

name (TEXT)

provider_type (TEXT) —— 来自 ProviderType registry（后续 Batch-2A）

config_json (TEXT) —— 可包含 secret；后续 API 永不明文回显

secrets_redaction_policy_json (TEXT) —— JSON：哪些字段为 secret

is_global_default (INTEGER) 0|1（默认 0）

created_at (TEXT)

updated_at (TEXT)

强约束（必须实现，已落地）：

全局默认唯一（partial unique index）：

uq_provider_profiles_global_default WHERE is_global_default = 1

5.3 v1.1 循环引用策略（必须交接给 Batch-2B）
character_ref_sets.character_id 做 FK（已做）

characters.active_ref_set_id 本批次不做 FK（避免环）

后续业务一致性规则（Batch-2B API 必须 enforce）：

active_ref_set_id 若不为空：必须存在 ref_set

且 ref_set.character_id == characters.id

且建议 ref_set.status == confirmed

active_ref_set_id 的写入应在满足“引用资产数量门槛（≥8）且确认”后发生

6) Gates & Evidence（门禁与证据）
6.1 必跑门禁（本 HEAD 必须 PASS）
bash scripts/gate_models.sh

迁移升级 OK

新表存在：characters / character_ref_sets / provider_profiles

unique index 存在：uq_character_ref_sets_character_id_version、uq_provider_profiles_global_default

append-only triggers 存在（至少覆盖 character_ref_sets；全局 immutability policy 输出 ok）

bash scripts/gate_append_only_ref_sets.sh（v1.1 新增）

在 tmpdb 副本上验证：

triggers present

unique index present

UPDATE/DELETE 被 ABORT（日志包含 append-only message）

provider_profiles global default unique 被强制

bash scripts/gate_all.sh --mode=preflight

不回归 baseline：api_smoke + export/import gate 正常

6.2 Evidence（证据）
主要证据文件：docs/EVIDENCE_P0_FULL.md

已包含 BATCH-1 / STEP-020 Data Model & Migrations (v1.1) 段落

包含迁移 revision、字段清单、关键 gate 片段、回滚说明

6.3 重要提醒：preflight 中 export/import 会放大数据量
你当前的 gate_export_import 流程会导入生成新 ID 的数据，导致本地 DB 的 assets/links 计数随重复运行增长。

不影响门禁，但可能影响本地开发库的“可读性/体积”。建议后续将 export/import gate 迁移到 tmpdb 副本执行（类似 gate_append_only_ref_sets）。

7) Development Runbook（启动/构建/常见问题）
7.1 启动后端（API :7000）
建议使用项目既有脚本（若存在）或：

uvicorn app.main:app --host 127.0.0.1 --port 7000 --reload

验证：

curl -sS http://127.0.0.1:7000/health

curl -sS http://127.0.0.1:7000/openapi.json | head

7.2 启动前端（Web :2000）
cd apps/web

npm i

npm run dev -- --port 2000

7.3 常见故障
SQLite “ALTER CONSTRAINT not supported”：

迁移中不要用 op.create_unique_constraint；用 unique index（本批次已修复）

Next.js “searchParams is a Promise”：

App Router 中需要 unwrap/await；请遵循 Next 官方对 sync-dynamic-apis 的要求（历史已踩过坑）

8) v1.1 Next Steps（Batch-2A/2B 开发指南）
本窗口仅完成 data_model / migration / gates；未实现 Characters/ProviderProfiles API 与 UI（明确 out of scope）。

8.1 Batch-2A：ProviderProfiles API（Settings）
目标：对 provider_profiles 提供 CRUD + set default（并保证 secret 脱敏输出）
建议契约要点：

list/get/create/update/delete（若允许 delete，注意是否与审计/append-only 冲突；可采用 soft delete）

set_default：事务性保证唯一（尽管 DB 已 partial unique，也建议在业务层做“先清 1 再置 1”）

config_json：写入可包含 secret，但 API 输出必须脱敏：

使用 secrets_redaction_policy_json 标出 secret key；输出时对这些字段返回 *** 或删除

门禁建议：

gate_provider_profiles_api.sh：

创建 profile（含 secret 字段）

get/list 输出脱敏

set_default 后保证唯一

8.2 Batch-2B：Characters API + RefSets Versioning
目标：对 characters / character_ref_sets 提供创建与版本追加，并 enforce 一致性规则。
建议契约要点：

character create/update status（draft→confirmed→archived）

ref_set append：仅允许 INSERT 新版本（版本 +1 或允许任意但必须唯一；推荐自动递增）

active_ref_set_id：

不做 FK 但必须 enforce：存在、归属一致、建议必须 confirmed

写入时强制满足 min_requirements_snapshot_json 约束（≥8，推荐12）并可 gate 验证

门禁建议：

gate_characters_ref_sets_api.sh：

创建 character

插入 ref_set v1/v2（验证 unique）

尝试 UPDATE/DELETE ref_set（必须失败）

设置 active_ref_set_id（若 API 提供）并验证一致性

9) Rollback Strategy（回滚策略）
9.1 代码回滚
回滚锚点（baseline）：9dc078cb70dab8dc4d8836caba4bdffad94d07c0

推荐方式：新分支 revert 或直接 checkout 到锚点（按你的协作策略）

9.2 DB 回滚
downgrade：alembic downgrade 0003_optional_hierarchy

或恢复 pre-upgrade 的 DB 备份（如存在）

回滚后必须复跑：

bash scripts/gate_all.sh --mode=preflight

Appendix A — Copy/Paste Entry Checklist（接手者 15 分钟上手）
git checkout dev/v1_1-batch1-step020-data_model

启动 API（7000），确认 /health 与 /openapi.json

启动 Web（2000），打开 /shots

跑门禁：

bash scripts/gate_models.sh

bash scripts/gate_append_only_ref_sets.sh

bash scripts/gate_all.sh --mode=preflight

若失败：

查 tmp/_out_gate_*.txt 与 docs/EVIDENCE_P0_FULL.md 对照定位