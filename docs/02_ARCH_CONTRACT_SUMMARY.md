# ARCH_CONTRACT_SUMMARY（架构契约摘要 / 下游注入包）

> 状态：**frozen**（用于实际开发的架构层 SSOT）。冻结后任何改动必须走 **CR-L2（Window-5 / Change Coordinator）**。

## 0) 指纹与冻结状态
- AI_SPECDIGEST：v1.0.0 / frozen / sha256=<SPEC_SHA256_TBD>
- REQ_CONTRACT_SUMMARY：present=true / sha256=<OPTIONAL_SHA256_OR_NA>
- ARCH_DIGEST：v1.0.0 / **frozen** / sha256=<ARCH_SHA256_TBD>

## 1) 范围对齐（P0 / P1）
- P0（必须交付）
  - **全量资产总览**：至少一个页面（`/` 或 `/library`）可展示全部图片与视频资产（无需先选 Project/Series），并可进入详情（AC-001）。
  - **资产详情追溯**：详情页展示预览/元数据/审核，并提供 PromptPack/Run/Review/Project/Series/Shot/Link 等追溯入口（AC-002）。
  - **四类生成入口**：t2i/i2i/t2v/i2v 可发起生成；结果默认入库可追溯（AC-003）。
  - **量化审核与留痕**：输出 face/style/quality 分数、overall_pass、reasons[]；支持自动通过+抽检；人工覆写必须理由并审计（AC-004）。
- P1（预留契约）
  - Shot 编排（仅引用关系）+ **加密导出目录包** + 无导入预览 + 导入迁移（不做剪辑渲染/NLE）。

## 2) 冻结默认决策（从 spec 继承，ARCH 执行层落地为契约）
- Project/Series：**允许为空**（必须支持“展示全部资产”与后续归档）。
- 审核：**自动通过 + 抽检**；抽检默认 **5%**（新角色/新风格可提高）。
- 通过规则：overall_pass = (face>=0.80) AND (style>=0.80) AND (quality>=0.70)。
- 删除：默认 **软删除（回收站）** + 可清空。
- 无导入预览最低能力：缩略图/代理预览 + 元数据与关系/证据链只读浏览；视频封面抽帧。

## 3) 架构锁定（最关键的“不可改”契约）
### 3.1 技术栈与运行形态（stack_lock / runtime_and_env）
- 单机单用户；**Web UI（Next.js/React）+ API（FastAPI）+ SQLite + 本地文件存储**。
- provider 不锁定：通过 **ProviderAdapter** 隔离（HTTP / 本地 runner / hybrid）。
- 端口锁定：web=2000，api=7000。

### 3.2 可机检契约（api_contract_addendum + observability）
- Request Tracking：请求/响应必须回显 `X-Request-Id`；缺失则服务端生成；贯穿日志。
- /health：必须存在且响应 key **稳定**：`status/version/db/storage/last_error_summary`。
- 错误信封：统一 error envelope（含 `request_id`）。
- 分页：`offset+limit`（默认 20，max 200）；响应必须包含 `page{limit,offset,total,has_more}`。

### 3.3 数据与证据链（data_model_lock）
- PromptPack（输入快照）、Run（执行记录）、Review（审核记录）均为 **append-only**；禁止静默覆盖。
- Link 为跨实体关系的唯一来源；Asset 支持软删除（deleted_at）。
- 导出安全：导出目录包必须可加密；密钥不得明文与包同放（契约级约束）。

### 3.4 UI 契约（ui_contract）
- 必备路由：`/`、`/library`、`/assets/:asset_id`、`/generate`（projects/series 可选）。
- 页面骨架：Library（Toolbar/Grid/Filters/BulkActionBar）、Detail（Preview/Metadata/Traceability/Actions/ReviewPanel）、Generate（InputForm/RunStatus/Results）。

## 4) 集成与并行合流策略（integration_strategy）
- 开发顺序启发式：O1 可观测/门禁 → O2 数据模型 → O3 API 契约 → O4 最小垂直切片 → O5 扩展。
- 冲突域：api_contract / data_model / ui_routes / infra_runtime。
- 并行策略：用 Feature Flags 隔离未完成模块；合流前必须通过 gates（契约、health、request_id）。

## 5) 冻结验证（必须满足）
- lock 区块齐全且可机检：stack/ports/dirs/runtime/data/api/ui/observability/integration/self_validation。
- P0 AC + NFR 意图对齐（observability/performance/reliability/security/usability/compatibility）。
- 冲突域与并行合流策略明确；未包含实现代码或补丁命令。
