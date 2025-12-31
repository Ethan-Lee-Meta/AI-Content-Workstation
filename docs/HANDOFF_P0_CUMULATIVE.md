# HANDOFF — P0 Cumulative (Standalone, Single-File) — Updated through BATCH-7

本文件是**唯一交接产物**（self-contained）。目标：让接手者在**不额外问问题**的情况下，能完成：
1) 本地启动 API(7000) + Web(2000)；
2) 跑通 gate_all(full)；
3) 理解并继续开发（尤其是 Shots 工作台 UI 与 Links SSOT 关系编排）。

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

### 3.2 gate_all(full) 的执行顺序（精确；用于定位回归失败）
full 模式依次执行（任何一步失败即停止并返回非 0）：
1) `gate_health_contract_check`
2) `gate_request_id_propagation_check`
3) `gate_openapi_reachable`
4) `gate_api_smoke`
5) `gate_provider_adapter`
6) `gate_web_routes`
7) `gate_ac_001`
8) `gate_ac_002`
9) `gate_ac_003`
10) `gate_ac_004`
11) `gate_ac_005`
12) `gate_bulk_actions`
13) `gate_trash_ui`
14) `gate_shots_api`
15) `gate_shots_ui`
16) `gate_e2e_happy_path`
17) 生成证据：`docs/EVIDENCE_P0_FULL.md`

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

## 5) 本次（BATCH-7）交付点摘要（给下一窗口/开发者的最小必要信息）

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
