---
artifact: DEVELOPMENT_BATCHES
version: 1.0.0
status: frozen
created_at: '2025-12-28T22:00:00+09:00'
sha256_rule: sha256(utf-8(body_without_frontmatter), LF)
inputs:
  AI_SPECDIGEST:
    version: 1.0.0
    status: frozen
    sha256: 77b334b8533592dbe7c74adb7d5e5e36a13266c23d95cdc72705c84a319e03cf
  ARCH_DIGEST:
    version: 1.0.0
    status: frozen
    sha256: adfb12f1a7ebc21cf15d5052213532bd3a484ebd19e2ad4e3b782eac11f216ca
  MASTER_PLAN:
    version: 1.0.0
    status: frozen
    sha256: cf659999b6876860413ef12f38f959e0b9dbd8247dba6f39b173299d5ca87345
sha256: cb1661508a4ad4287525917bc6758fd8fc1a51bf6d27d53aba38754ac1e1f786
---

# DEVELOPMENT_BATCHES（开发批次指南 / 并行与合流手册）

> 用途：把 MASTER_PLAN.yaml 的 steps 按依赖与冲突域组织成**可合流、可验收、可回滚**的批次（Batch），并定义节奏与门禁。  
> 输入：MASTER_PLAN.yaml（steps + depends_on + conflict_domain）、ARCH_CONTRACT_SUMMARY.md（锁定项）  
> 输出：本文件仅指导“怎么分批、怎么合流、怎么验收”，不包含任何代码实现细节

---

## 0) 指纹与冻结状态

- Project: **<项目名>**
- Inputs:
  - AI_SPECDIGEST: version **1.0.0**, status **frozen**, sha256 **77b334b8533592dbe7c74adb7d5e5e36a13266c23d95cdc72705c84a319e03cf**
  - ARCH_DIGEST: version **1.0.0**, status **frozen**, sha256 **adfb12f1a7ebc21cf15d5052213532bd3a484ebd19e2ad4e3b782eac11f216ca**
  - MASTER_PLAN: version **1.0.0**, status **frozen**, sha256 **cf659999b6876860413ef12f38f959e0b9dbd8247dba6f39b173299d5ca87345**
- 本文件版本：**1.0.0**, status **frozen**

---

## 1) 批次策略（本计划的关键优化点）

### 1.1 One-Batch-One-Conflict-Domain（本轮冻结策略）
- **每个 Batch 只允许一个冲突域（conflict_domain）**。
- **每个 Batch 由一个 Dev Window 独占负责**（一窗一批次 / 一窗一冲突域）。
- **Batch 内不并行**（parallelizable=false）；并行度通过“分阶段（Phase）+ 串行批次”控制。
- 目的：最小化合流冲突与窗口漂移风险；为后续分阶段开发提供稳定节奏。

### 1.2 合流节奏（建议）
- 每个 Batch 完成后必须：
  1) 通过该 Batch 的 gates（见下文“验收命令”）
  2) 输出证据摘要（gate 输出关键 [ok] 行）
  3) 合流主分支/集成分支（按项目流程）
- 禁止“跨 Batch 偷跑”合流：若未满足 entry_criteria，不得进入下一 Batch。

---

## 2) 冲突域定义（冻结）

| conflict_domain | 定义 | 允许改动范围（示例） | 典型冲突 |
|---|---|---|---|
| infra_runtime | 运行时/门禁/可观测性/集成脚本/CI | apps/api(core), scripts, docs | 中间件/健康检查/门禁脚本并发修改 |
| data_model | DB 模型/迁移/存储契约 | apps/api(models+migrations) | 迁移冲突、字段重命名、约束变化 |
| api_contract | API 路由/DTO/服务层（契约面） | apps/api(modules/**) + openapi | 路由/字段名冲突、错误信封/分页格式漂移 |
| ui_routes | 前端路由与页面交互 | apps/web | 路由结构、状态管理与 API client 冲突 |

---

## 3) 批次清单（Batches）

> 以 MASTER_PLAN.batching_guidance 为准；此处强调“窗口边界/节奏/验收/回滚”。

### BATCH-0：P0 Foundations & Gates（infra_runtime）
- **包含 Steps**：STEP-000-context-sync, STEP-010-foundations-observability
- **Entry**：存在 frozen spec/arch 指纹；端口锁 2000/7000
- **Exit**：/health keys 固定；X-Request-Id 贯穿；错误信封固定；openapi 可达；required_gates 可运行
- **验收命令（示例）**：
  - `bash scripts/gate_all.sh --mode=preflight`
  - `bash scripts/gate_api_smoke.sh`
- **回滚策略**：revert 合并提交；保留 ports_lock 检查为硬门禁

### BATCH-1：P0 Data/Storage Skeleton（data_model）
- **包含 Steps**：STEP-030-data-storage-skeleton, STEP-040-core-entities, STEP-050-optional-hierarchy-entities
- **Entry**：BATCH-0 通过 required_gates
- **Exit**：迁移可运行；核心实体就绪；“未归档资产”允许（Project/Series 可空）
- **验收命令（示例）**：
  - `bash scripts/gate_db_storage.sh`
  - `bash scripts/gate_models.sh`
- **回滚策略**：revert；必要时仅 dev 环境允许重置本地 db（必须记录在 runbook）

### BATCH-2：P0 API Contract Slices（api_contract）
- **包含 Steps**：STEP-060-api-assets-read, STEP-070-api-runs-core, STEP-080-api-reviews-core, STEP-090-api-delete-trash
- **Entry**：BATCH-1 合流；/health 契约稳定
- **Exit**：assets/runs/reviews/trash 端点可用；分页/错误信封不漂移；软删除语义成立
- **验收命令（示例）**：
  - `bash scripts/gate_assets_read.sh`
  - `bash scripts/gate_runs_core.sh`
  - `bash scripts/gate_reviews.sh`
  - `bash scripts/gate_trash.sh`
- **回滚策略**：revert；危险操作（trash empty）允许增加保护但不得改 endpoint path

### BATCH-3：P0 UI Slices（ui_routes）
- **包含 Steps**：STEP-100-ui-shell-routes, STEP-110-ui-library, STEP-120-ui-asset-detail, STEP-130-ui-generate, STEP-140-ui-review
- **Entry**：BATCH-2 合流（API 可用）
- **Exit**：AC-001..AC-004 满足；UI 不崩溃；关键路径可走通
- **验收命令（示例）**：
  - `bash scripts/gate_web_routes.sh`
  - `bash scripts/gate_ac_001.sh`
  - `bash scripts/gate_ac_002.sh`
  - `bash scripts/gate_ac_003.sh`
  - `bash scripts/gate_ac_004.sh`
- **回滚策略**：revert；保持 routes skeleton 不被删除

### BATCH-4：P0 Integration & E2E（infra_runtime）
- **包含 Steps**：STEP-150-e2e-happy-path
- **Entry**：BATCH-3 合流；AC-001..AC-004 gates 通过
- **Exit**：e2e happy path 证据输出；`gate_all --mode=full` 全绿
- **验收命令（示例）**：
  - `bash scripts/gate_all.sh --mode=full`
- **回滚策略**：revert；若需降级为 nightly 必须走 PLAN_CHANGE_REQUEST

---

## 4) Phase-P1（后续阶段，冻结为计划但实现可延后）

> P1 批次在 P0 稳定后执行；仍遵循一窗一批次、一批次一冲突域。

### BATCH-5：P1 UX & Library Ops（ui_routes）
- Steps：STEP-160-ui-ux-depth-limit, STEP-170-ui-bulk-actions-p1, STEP-180-ui-trash-view-p1
- 验收：`bash scripts/gate_ac_005.sh` + bulk/trash UI gates

### BATCH-6：P1 Shots API（api_contract）
- Steps：STEP-200-api-shots-p1
- 验收：`bash scripts/gate_shots_p1.sh`

### BATCH-7：P1 Shots UI（ui_routes）
- Steps：STEP-210-ui-shots-p1
- 验收：`bash scripts/gate_shots_ui_p1.sh`

### BATCH-8：P1 Providers + Export/Import（infra_runtime）
- Steps：STEP-190-provider-adapter-p1, STEP-230-export-import-p1
- 验收：`bash scripts/gate_provider_adapter.sh` + `bash scripts/gate_export_import_p1.sh`

---

## 5) 统一合流门禁建议（面向 CI）

- P0 最小门槛（合流必跑）：
  - `bash scripts/gate_api_smoke.sh`
  - `bash scripts/gate_db_storage.sh`
  - `bash scripts/gate_assets_read.sh`
  - `bash scripts/gate_runs_core.sh`
  - `bash scripts/gate_reviews.sh`
  - `bash scripts/gate_web_routes.sh`
  - `bash scripts/gate_ac_001.sh` ~ `gate_ac_004.sh`
- P0 完整门槛（发布/里程碑）：
  - `bash scripts/gate_all.sh --mode=full`

---

## 6) 回滚原则（冻结）

- 默认：`git revert <merge_commit>`（保持历史可追溯）
- 若引入 Feature Flag：回滚优先“关开关”，其次 revert
- 数据回滚：仅 dev 环境允许重置本地 sqlite；必须在 runbook 留痕
