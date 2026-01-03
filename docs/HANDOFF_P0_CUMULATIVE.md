# HANDOFF — P0 Cumulative (Standalone, Single-File) — Updated through BATCH-9

本文件是**唯一交接产物**（self-contained）。目标：让接手者在**不额外问问题**的情况下，能完成：
1) 本地启动 API(7000) + Web(2000)；
2) 跑通 gate_all(full)；
3) 理解并继续开发（尤其是 Shots 工作台 UI 与 Links SSOT 关系编排）。

## -1) Quick Index（导航）

- [0) Snapshot](#0-snapshot交接时必须填写)
- [0.1 Hard Locks](#01-hard-locks不可变更项如需变更必须走-cr)
- [1) Backend](#1-backend已交付能力按契约视角)
- [2) Frontend](#2-frontend已交付能力按页面与交互视角)
- [3) Verification Gates](#3-verification-gates门禁与回归)
- [4) 开发续作指南](#4-开发续作指南让新接手者可以直接开干)
- [BATCH-7](#batch-7)
- [BATCH-8](#batch-8-phase-p1--provideradapter-可执行化feature-flag-step-190)
- [BATCH-9](#batch-9)
- [6) 快速上手](#6-快速上手15-分钟-checklist)

> 注：不同 Markdown 渲染器的锚点算法略有差异；如链接不跳转，使用编辑器搜索对应标题即可（例如搜索 “## 3) Verification”）。

## -0) Delta Summary（最新增量：BATCH-9）

- 新增/强化（面向下一窗口的关键差异）：
  - **AC-006 导出/导入目录包（P1 增量 API）**：`/exports` + `/imports`（不改变既有 required_endpoints）
  - **只读 Manifest（无导入预览）**：`GET /exports/{export_id}/manifest`，BATCH-10 UI 直接消费
  - **门禁新增**：`scripts/gate_export_import.sh`（落盘解析，避免 Git Bash 下 `curl | python -` 管道不稳定）
- 产物与可追溯：
  - 导出落盘：`data/exports/{export_id}/`（`manifest.json`, `bundle.json`, `export.json`, 可选 `blobs/`）
  - 导入落盘：`data/imports/{import_id}/import.json`
- 运行时回滚：
  - 首选 `EXPORT_IMPORT_ENABLED=0` 关闭导出/导入端点（不破坏 P0 基线）

(Generated at 2025-12-31T15:20:05Z UTC)

---

## 0) Snapshot（交接时必须填写）

> 在交接当下执行并粘贴输出（用于可追溯定位）

- Branch:
  - `git rev-parse --abbrev-ref HEAD`
- HEAD:
  - `git rev-parse HEAD`
  - `git show -s --format='%ci %s' HEAD`
- Working tree:
  - `git status -sb`

> 交接口径：本文件描述“当前 HEAD 应具备的能力与门禁”。如你 checkout 的 HEAD 不同，以你的 HEAD 为准，但仍需满足 locks 与 gates。

---

## 0.1 Hard Locks（不可变更项；如需变更必须走 CR）

### 端口锁
- Web dev server: `2000`
- API server: `7000`

### 目录契约
- ✅允许编辑：`apps/web/**`, `docs/**`, `scripts/**`
- ❌禁止新增顶层目录：`infra/**`, `services/**`
- ❌禁止编辑：`vendor/**`, `.github/workflows/**`

### UI 架构锁
- App Shell：`Sidebar`, `Topbar`, `MainContent`, `InspectorDrawer`
- 必须存在路由：
  - `/shots`
  - `/shots/:shot_id`
- 不得移除既有 P0 路由；本次及后续只允许补齐/完善 shots 路由内容与交互。

### 交互约束
- Shots 核心任务（选择 shot → 关联资产 → 保存/确认）交互层级 **<= 3**（证据见 `docs/SHOTS_UI_EVIDENCE.md`）。

### API 展示锁
- Request id header: `X-Request-Id`
- Error envelope 必含 keys：`error`, `message`, `request_id`, `details`
- Pagination 响应形态：
  - 顶层：`items`, `page`
  - page：`limit`, `offset`, `total`, `has_more`

### 关系不变量
- `links` 是关系唯一来源（SSOT）
- UI 的“关联/取消关联”必须走 Link API；不得在 UI 侧暗存关系或绕过 Links。

---

## 1) Backend：已交付能力（按契约视角）

### 1.1 可观测性与契约基线
- `GET /health`：
  - 必含 keys：`status`, `version`, `db`, `storage`, `last_error_summary`
- `GET /openapi.json`：可达
- Request tracing：
  - 成功响应会 echo `X-Request-Id`
  - 错误响应为统一 error envelope 且包含 `request_id`

### 1.2 Assets（软删除 + 列表/详情）
- `GET /assets?offset=&limit=&include_deleted=`
  - 默认：不含 deleted
  - `include_deleted=true`：包含软删除资产
  - 默认 limit=50；最大 limit=200
  - 响应：`{ items: [...], page: {limit, offset, total, has_more} }`
- `GET /assets/{id}`
- `DELETE /assets/{id}`：soft delete（幂等）
- 注意：资产主键字段在 list/items 内可能是 `id`（UI/gates 必须兼容）

### 1.3 Trash（清空回收站）
- `POST /trash/empty`：清理所有 soft-deleted 资产（并尝试删除存储文件）
- 清理后：`GET /assets?include_deleted=true` 不应再返回被 purge 的资产

### 1.4 Runs / Reviews（P0/P1 支撑面）
- Runs：创建/查询基本可用（用于链路追踪）
- Reviews：override 必须有 `reason`（前后端都约束）

### 1.5 Shots + Links（P1：引用关系编排的核心）
- `GET /shots?offset=&limit=&project_id?=&series_id?=`
  - 响应：`{ items, page{limit,offset,total,has_more} }`
- `GET /shots/{shot_id}`
  - 至少返回：`shot` + `linked_refs`（linked_refs 必须来自 Links SSOT，且已应用 tombstone）
- `POST /shots/{shot_id}/links`
  - body：`{ dst_type, dst_id, rel }`
  - 成功应返回 `link_id`（供后续 unlink）
- `DELETE /shots/{shot_id}/links/{link_id}`
  - 语义：写入 tombstone（append-only），而非物理删除


### 1.6 Exports / Imports（P1：AC-006 目录包迁移 + 无导入预览 Manifest）
- Additive endpoints（P1 增量契约；一旦实现视为对外契约）：
  - `POST /exports`：创建导出目录包（同步完成为主；落盘）
  - `GET /exports/{export_id}`：导出记录（状态/路径/统计）
  - `GET /exports/{export_id}/manifest`：只读 Manifest（**无需导入即可读取**，供 UI 预览）
  - `POST /imports`：从目录包导入迁移（append-only；默认新 ID）
  - `GET /imports/{import_id}`：导入记录（状态/统计/告警）
- Feature flag（回滚首选）：
  - `EXPORT_IMPORT_ENABLED=0|1`（0：全部禁用；1：启用）
- 本地文件系统落盘（默认）：
  - exports：`data/exports/{export_id}/`（`bundle.json`, `manifest.json`, `export.json`, `blobs/`）
  - imports：`data/imports/{import_id}/import.json`
- 契约约束：
  - 必须 echo `X-Request-Id`
  - 失败必须返回 error envelope：`error,message,request_id,details`


---

## 2) Frontend：已交付能力（按页面与交互视角）

### 2.1 启动方式（dev）
- `cd apps/web && npm i`
- `npm run dev -- --port 2000`
- 打开：
  - `http://127.0.0.1:2000/shots`

### 2.2 API Proxy（浏览器同源转发）
- 前端通过 `/api_proxy/*` 转发到 7000，确保：
  - 避免 CORS 问题
  - 统一 `X-Request-Id` 传递/可追溯
- 相关实现位于：`apps/web/app/api_proxy/**`

### 2.3 Shots 工作台 UI（BATCH-7）
#### `/shots` 列表页
- 分页展示 shots（offset/limit）
- 可选过滤（若后端支持）：project_id / series_id
- 点击条目进入 `/shots/:shot_id`

#### `/shots/:shot_id` 详情/工作台页
- 展示 shot 基本信息（用于契约演进时快速对齐）
- 展示 `linked_refs` 汇总（至少列出关联对象 id + 类型桶）
- Link 编排面板（核心任务 <=3 层）：
  - add link：填写 dst_type/dst_id/rel 后提交
  - remove link：基于 link_id 执行 unlink（若后端可提供）
- 错误处理：
  - 失败时 UI 必须可见 error envelope 片段 + request_id（便于查后端日志）

#### 常见陷阱：Next.js duplicate pages
- 禁止同一路由同时存在 `page.js` 与 `page.tsx`
- 若出现 duplicate warning：必须删除/迁移其中一个版本，保证每个路由只存在一个 page 文件。

---

## 3) Verification：门禁（Gates）与证据（Evidence）

### 3.1 一键回归（推荐）
- `bash scripts/gate_all.sh --mode=full`
- 可选重复跑 N 次（抖动排查）：
  - `bash scripts/gate_all.sh --mode=full --repeat=3`


### 3.3 gate 输出与失败定位（最重要的 runbook）
- 每个 gate 的完整输出会写入：
  - `tmp/_out_gate_<label>.txt`
  - 若 `--repeat=N`：`tmp/_out_gate_<label>__run<i>.txt`
- 当某 gate 失败：
  1) 先看终端最后的 `[err] <label> failed ... (see tmp/_out_gate_...)`
  2) 打开对应 tmp 日志文件定位具体 HTTP/code/envelope

### 3.4 shots_ui 的“确定性”保证（自动 seed + link add/remove）
`bash scripts/gate_shots_ui.sh` 必须满足：
- 先验证 openapi 可达
- 通过 API 取一个 `shot_id`
  - 若 shots 为空：允许尝试调用 `scripts/gate_shots_api.sh` seed 后重试
- 通过 Web 验证页面渲染：
  - `GET http://127.0.0.1:2000/shots` 返回 200
  - `GET http://127.0.0.1:2000/shots/<shot_id>` 返回 200
- 确定性 link add/remove：
  - 先 `GET /assets?offset=0&limit=1`，兼容 items[0].id / items[0].asset_id
  - 若无资产：自动运行 `scripts/gate_assets_read.sh` seed，再取资产
  - `POST /shots/<shot_id>/links` 创建 link（要求返回 link_id）
  - `DELETE /shots/<shot_id>/links/<link_id>` 执行 unlink（tombstone）

> 如 link create/unlink 失败，脚本会打印 headers/body（截断）以便快速定位（例如：契约字段不匹配、后端未返回 link_id、或 error envelope 缺 key）。


### 3.5 gate_export_import（AC-006：导出+manifest+导入+关系校验）
- 运行：
  - `bash scripts/gate_export_import.sh`
- gate 覆盖（最小证据链与契约面）：
  - openapi 含 `/exports` 与 `/imports` 路径
  - `POST /exports` 成功且包含 `X-Request-Id`
  - `GET /exports/{id}/manifest` 可读（**无导入预览**）
  - 负例：manifest not found 必须返回 error envelope + request_id
  - `POST /imports` + `GET /imports/{id}`：status=completed
  - 关系校验：links preserved（若 manifest 期望 links>0，则导入计数必须 >0）
- 失败定位：
  - 本 gate 生成临时目录：`tmp/gate_export_import.<pid>/`，包含每步响应 hdr/json 便于复盘


---

## 4) 开发续作指南（让新接手者可以直接开干）

### 4.1 增加/调整 Shots UI 的推荐方式
- 列表页：只加“展示字段 + 过滤条件 + 分页控制”
- 详情页：优先保证“linked_refs 结构可视化”稳定，再增强交互（例如：选择器 UI）
- 所有关系变更必须走 Links API；禁止在前端缓存关系作为事实来源

### 4.2 新增一个 API Proxy 路由（同源转发）
- 位置：`apps/web/app/api_proxy/<...>/route.js`
- 要求：
  - 转发到 7000
  - 透传 `X-Request-Id`
  - 失败时返回统一 JSON（尽可能透出 error envelope + request_id）

### 4.3 新增一个 gate 并合入 gate_all(full)
- 在 `scripts/` 下新增 `gate_xxx.sh`
- 在 `gate_all.sh` 的 full 分支中加：
  - `run_gate "xxx" "scripts/gate_xxx.sh" "$i" || exit $?`
- 同时把 label 加入证据采集列表（`docs/EVIDENCE_P0_FULL.md` 会抽取 `[ok]` 行）

---

---

## 5) Batch Sections — Standard Template（统一结构）

> 目的：把每个 BATCH 的“交付/契约/门禁/回滚/交接输出”固定成可审计结构，便于跨窗口接力。

每个 BATCH 段落应至少包含：
- `BATCH-X.0 Snapshot`：更新时间、可回滚开关（如有）、本地落盘路径（如有）
- `BATCH-X.1 What shipped`：本批交付能力清单（按用户价值/契约视角）
- `BATCH-X.2 Contract surface`：新增/变化 endpoints、DTO 字段名（仅字段名）、不变量
- `BATCH-X.3 Verification`：可复跑 gates（含关键 [ok] 信号与样例 request_id）
- `BATCH-X.4 Rollback`：优先 feature-flag/off，其次 git revert；并声明数据清理策略
- `BATCH-X.5 Handoff outputs`：下一窗口必须携带的内容（commit SHA / 证据文件 / 入口检查）

(Updated at 2025-12-31T15:20:18Z UTC)

---

## BATCH-7 (PHASE-P1) — Shots UI（Links SSOT 编排 + gate_shots_ui）

### BATCH-7.0 Snapshot
- Updated at (UTC): `2025-12-31T15:20:18Z`
- Key pages:
  - `/shots`
  - `/shots/:shot_id`
- Key gate:
  - `bash scripts/gate_shots_ui.sh`
- Evidence files (if present):
  - `docs/EVIDENCE_P0_FULL.md`
  - `docs/SHOTS_UI_EVIDENCE.md`

### BATCH-7.1 What shipped
交付内容：
- Shots UI 路由可用：`/shots` 与 `/shots/:shot_id`
- 关系可视化：详情页展示 `linked_refs`（来自 Links SSOT）
- 关系编排：通过 Links API 增加/取消关联（tombstone 语义）
- `gate_shots_ui`：确定性门禁（自动 seed assets；完成 link add/remove）
- `gate_all(full)`：已包含 `shots_api` 与 `shots_ui`，并生成 `docs/EVIDENCE_P0_FULL.md`

交接给下一窗口必须携带：
- 当前 HEAD SHA
- `docs/EVIDENCE_P0_FULL.md`
- `docs/SHOTS_UI_EVIDENCE.md`
- `tmp/_out_gate_shots_api*.txt` 与 `tmp/_out_gate_shots_ui*.txt`（若出现问题用于定位）

---

### BATCH-7.2 Contract surface / invariants
- Links 为 SSOT：所有关系增删必须走 Links API（tombstone 语义）
- 前端只展示/编排，不可把关系作为“事实来源”在本地缓存替代后端

### BATCH-7.3 Verification
- `bash scripts/gate_shots_ui.sh`
- （回归）`bash scripts/gate_all.sh --mode=full`

### BATCH-7.4 Rollback
- 推荐：如有 feature-flag 则优先关闭；否则 `git revert <merge_commit_sha>`
- 不强制删除数据/证据文件（避免误删）；开发态清理由 runbook 明确

### BATCH-7.5 Handoff outputs（下一窗口必须携带）
- 当前 HEAD SHA
- `docs/EVIDENCE_P0_FULL.md`（若存在）
- `docs/SHOTS_UI_EVIDENCE.md`（若存在）

## BATCH-8 (PHASE-P1) — ProviderAdapter 可执行化（Feature Flag, STEP-190）

- Branch: `{branch}`
- Head: `{head}`
- Updated at (UTC): `{ts}`

### BATCH-8.2 Contract surface（API 不变；行为增量）
- Endpoints（路径不变）：
  - `POST /runs`
  - `GET /runs/{run_id}`
- Invariants：
  - 不新增 DTO 字段名、不改字段形状
  - 通过 `run_events` append-only 记录状态迁移与结果引用（契约不漂移）

### BATCH-8.1 交付内容（What shipped）
- ProviderAdapter 抽象边界（可插拔）：`apps/api/app/modules/runs/providers/*`
- 最小可运行 Provider：`mock`（写入 storage，并返回稳定 `result_refs` 引用）
- Feature Flag（默认 OFF）：`PROVIDER_ENABLED=0|1`
- Gate（本批次）：`scripts/gate_provider_adapter.sh`
- gate_all(full) 已纳入：`scripts/gate_all.sh` 的 full 模式在 `api_smoke` 后执行 `provider_adapter`
- Append-only 语义兼容：**不 UPDATE runs**；通过 `run_events` 追加事件记录状态迁移与结果引用，并在 `GET /runs/{{id}}` 时覆盖返回（最新事件优先）

### BATCH-8.2 运行时开关（Feature Flag / Headers）
- ENV（默认 OFF）：
  - `PROVIDER_ENABLED=0`：关闭 provider（保持原 stub/queued 行为）
  - `PROVIDER_ENABLED=1`：开启 provider（执行 provider + 事件写入）
- Gate/调试用请求头覆盖（无需重启服务）：
  - `X-Provider-Enabled: 1|0`：强制 ON/OFF（优先级高于 ENV）
  - `X-Provider-Force-Fail: 1`：强制 provider 失败路径（用于验证错误信封与 failed 状态）

### BATCH-8.3 runs 执行语义（契约不漂移前提下的行为摘要）
- API 路径不变：
  - `POST /runs`
  - `GET /runs/{{run_id}}`
- `POST /runs`（provider OFF）：
  - 维持原行为：创建 run，返回 `RunCreateOut`（`status` 通常为 `queued`）
- `POST /runs`（provider ON）：
  - 创建 run 后追加事件：`running -> succeeded|failed`
  - 返回仍为 `RunCreateOut`（不新增字段，不改 DTO 形状）
- `GET /runs/{{run_id}}`：
  - 返回 `RunGetOut`；其中 `status` 与 `result_refs` 若存在 run_events，则以**最新事件覆盖**（append-only）

### BATCH-8.4 result_refs 约定（不改字段名，仅填充内容）
- `RunGetOut.result_refs` 仍为 dict（保持既有 DTO 形状）
- provider 成功时（示例字段）：
  - `asset_ids`: list（兼容保留，P1 可能为空）
  - `provider`: string（如 `mock`）
  - `refs`: list[str]（至少 1 个，例如 `storage://runs/<run_id>/result.json`）
  - 可选：`details`（provider 额外信息）
- provider 失败时（示例字段）：
  - `asset_ids`: list
  - `provider`: string
  - `error`: string（失败原因）

### BATCH-8.5 错误与可观测性（Error envelope / RequestId）
- provider 失败路径必须返回错误信封（keys）：`error, message, request_id, details`
- details 内包含 `run_id`（便于随后 `GET /runs/{{id}}` 验证 `failed` 已落库）
- gate 输出中的 request_id 示例可从 `tmp/_out_gate_provider_adapter.txt` 中提取

### BATCH-8.6 验证（Verification）
- 本批 gate：
  - `bash scripts/gate_provider_adapter.sh`
- 回归 gate：
  - `bash scripts/gate_all.sh --mode=full`

### BATCH-8.7 回滚（Rollback）
- 首选：关闭开关（不破坏 P0）
  - `PROVIDER_ENABLED=0`（或 gate 使用 `X-Provider-Enabled: 0`）
- 必要时：`git revert <merge_commit_sha>`（确保 `/runs` 契约仍可用）

### BATCH-8.8 交接输出（handoff_outputs）
- Head/merge commit SHA：`{head}`
- Feature Flag/默认值：
  - `PROVIDER_ENABLED` 默认 OFF（未设置时视为关闭）
  - Header overrides：`X-Provider-Enabled`, `X-Provider-Force-Fail`
- gate_provider_adapter 关键证据：
  - `tmp/_out_gate_provider_adapter.txt`（含成功/失败路径输出与 request_id）
- 状态迁移与结果引用摘要：
  - 事件序列：`queued (runs)` -> `running (run_events)` -> `succeeded|failed (run_events)`
  - `RunGetOut.result_refs`：dict（成功至少含 `refs`）
- 下一批次 entry_check（建议）：
  - `gate_all --mode=full` 持续全绿
  - `gate_provider_adapter` 持续全绿
  - 若进入后续 provider 强化/导出导入（BATCH-9/STEP-230）：保持 `/runs` DTO/路径不漂移、append-only 不变量不破坏
  
## 6) 快速上手（15 分钟 checklist）

1) 启动 API（7000），确认：
   - `curl -sS http://127.0.0.1:7000/openapi.json | head`
2) 启动 Web（2000）：
   - `cd apps/web && npm run dev -- --port 2000`
3) 跑 full 回归：
   - `bash scripts/gate_all.sh --mode=full`
4) 浏览器验证：
   - 打开 `/shots`，点击任意 shot 进入详情
   - 在详情页做一次 link add/remove（如 UI 有入口）
5) 若失败：
   - 直接打开 `tmp/_out_gate_<label>.txt` 定位

---


---

---

## BATCH-9 (PHASE-P1) — AC-006 Export/Import Directory Package (API)

### BATCH-9.0 Snapshot（填充以便审计）
- Updated at (UTC): `2025-12-31T15:10:19Z`
- Feature flag:
  - `EXPORT_IMPORT_ENABLED=0|1`（回滚首选：设置为 0）
- Storage roots（默认；可通过 env 覆盖）：
  - Exports: `data/exports/`
  - Imports: `data/imports/`
  - DB: `data/app.db`
  - Storage: `data/storage`

### BATCH-9.1 Contract Surface（Additive Endpoints）
- `POST   /exports`
- `GET    /exports/{export_id}`
- `GET    /exports/{export_id}/manifest`
- `POST   /imports`
- `GET    /imports/{import_id}`

**Contract invariants（必须满足）**
- 所有响应必须 echo：`X-Request-Id`
- 失败必须返回 error envelope keys：`error`, `message`, `request_id`, `details`

### BATCH-9.2 Data & Evidence Semantics（核心语义）
- 导出（export）目标：生成“可迁移目录包”，包含：
  - 元数据表快照（以 `bundle.json` 形式按表导出）
  - 关系：`links`（SSOT）
  - 证据链：`prompt_packs` / `runs` / `reviews`（只读快照；用于迁移不丢链）
  - 可选：`projects` / `series` / `shots` / `run_events`（若表存在则一起导出）
- 导入（import）目标：append-only 迁移
  - 默认 `create_new_ids=true`：生成新 ID（避免覆盖与冲突）
  - 不覆盖既有 PromptPack/Run/Review（保持 append-only 不变量）
  - Links 必须可迁移并在导入后可见（最低校验：导入计数 > 0 且与 manifest 期望一致/不为 0）

### BATCH-9.3 On-Disk Package Format（供 UI 预览与迁移）
导出目录：`data/exports/{export_id}/`
- `export.json`：导出记录（状态/路径/统计/告警）
- `manifest.json`：**只读预览输入（无导入预览）**
- `bundle.json`：表快照（tables dump）
- `blobs/`：二进制复制（best-effort；由实现控制范围）

导入目录：`data/imports/{import_id}/`
- `import.json`：导入记录（状态/统计/id_map_size/告警）

### BATCH-9.4 Manifest Schema（字段层级摘要；BATCH-10 UI 直接使用）
`manifest.json`（稳定字段名；UI 以此渲染“无导入预览”）：
- `manifest_version`
- `export_id`
- `created_at`
- `selection`：
  - `asset_ids`（可空）
  - `include_deleted`
  - `include_binaries`
  - `include_proxies`
  - `note`
- `tables`：
  - `resolved_table_names`（logical -> physical table name）
  - `row_counts`（logical -> int）
- `assets_preview[]`（用于列表预览；不保证覆盖全部资产）：
  - `id`
  - `type`
  - `mime`
  - `size_bytes`
- `blobs[]`（若启用二进制复制；best-effort）：
  - `src_ref`
  - `dst_relpath`
  - `size_bytes`
  - `sha256`
  - `ok`
  - `error`（失败时）
- `warnings[]`

### BATCH-9.5 Gates & Evidence（可复跑、可审计）
- `bash scripts/gate_api_smoke.sh`
- `bash scripts/gate_export_import.sh`
- （回归）`bash scripts/gate_all.sh --mode=full`

`gate_export_import` 通过信号（示例）：
- `[ok] openapi has exports/imports paths`
- `[ok] manifest readable (no import)`
- `[ok] import completed`
- `[ok] relationships (links) preserved`

### BATCH-9.6 Failure Runbook（常见故障与定位）
- 若 openapi/manifest 请求异常：
  - 优先检查 API 进程是否稳定（reload 崩溃会导致 curl timeout）
- 若在 Git Bash 出现 `curl: (23) Failure writing output ...`：
  - 避免 `curl | python -` 管道解析；改为 `curl -o <file>` 后由 python 读取（本 gate 已采用落盘策略）
- gate 证据文件：
  - `tmp/gate_export_import.<pid>/` 内含 `*.hdr` 与 `*.json`，可直接对照 request_id 与响应体

### BATCH-9.7 Rollback（推荐顺序）
1) `EXPORT_IMPORT_ENABLED=0`（不破坏 P0；立即止血）
2) `git revert <merge_commit_sha>`（如需彻底移除）

### BATCH-10 Entry Check（无导入预览 + 契约面）
- `/openapi.json` 包含 `/exports` 与 `/imports`
- `GET /exports/{export_id}/manifest` 可读（**无需导入**）
- `gate_export_import` rc=0

---

## BATCH-10 (PHASE-P1) — AC-006 Export Preview UI + Import UI (No-Import Preview)

### BATCH-10.0 Snapshot
- Key page:
  - `/transfer` (supports deep-link: `/transfer?export_id=...`)
- Optional UI flag:
  - `EXPORT_IMPORT_UI_ENABLED=0|1` (0 disables the page rendering)
- Key gate:
  - `bash scripts/gate_export_preview_ui.sh`

### BATCH-10.1 What shipped
- No-Import Preview:
  - Reads `GET /exports/{export_id}/manifest` and renders: assets_preview + row_counts evidence summary
- Controlled Import (<=3 layers):
  - Preview -> Confirm (2nd confirmation) -> Result summary
  - Import request body is built from OpenAPI schema (still backend-validated)
- Error handling:
  - Any failure shows error envelope + request_id (and X-Request-Id when present)

### BATCH-10.2 Verification
- `bash scripts/gate_export_preview_ui.sh`
- Regression:
  - `bash scripts/gate_all.sh --mode=full`

### BATCH-10.3 Rollback
- Preferred:
  - `EXPORT_IMPORT_UI_ENABLED=0`
- Or:
  - `git revert <merge_commit_sha>`
