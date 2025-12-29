# DEVELOPMENT_BATCHES（开发批次指南 / 并行与合流手册）

> 用途：把 MASTER_PLAN.yaml 的 steps 按依赖与冲突域组织成可并行的批次（Batch），并定义合流节奏与门禁  
> 输入：MASTER_PLAN.yaml（steps + depends_on + conflict_domain）、ARCH_CONTRACT_SUMMARY.md（锁定项）  
> 输出：本文件仅指导“怎么并行、怎么合流、怎么验收”，不包含任何代码实现细节

---

## 0) 指纹与冻结状态（必须填写）

- Project: **<project_name>**
- Inputs:
  - AI_SPECDIGEST: version **<spec_version>**, status **<draft|frozen>**, sha256 **<spec_sha256>**
  - ARCH_DIGEST: version **<arch_version>**, status **<draft|frozen>**, sha256 **<arch_sha256>**
  - MASTER_PLAN: version **<plan_version>**, status **<draft|frozen>**, sha256 **<plan_sha256_or_placeholder>**
- 本文件版本：
  - DEVELOPMENT_BATCHES.md sha256: **<optional>**
- 变更规则：批次/分配调整不改变 spec/arch 锁，但必须版本化并通知 Window-4/Dev（通过 Window-5 传播）

---

## 1) 批处理机制总览（Batching Overview）

### 1.1 设计目标

- **最大化并行**：在不破坏契约锁的前提下，提高吞吐
- **最小化合流冲突**：以冲突域（conflict_domain）隔离并行工作
- **可控合流节奏**：每个 Batch 结束必须达到可验证的“稳定基线”
- **失败可回滚**：每个 Batch 都有明确的回滚策略与降级路径（以 feature flag / revert 为主）

### 1.2 批次原则（强规则）

- Batch 内 steps 必须满足依赖闭包（depends_on 已完成）
- Batch 内并行 steps 必须尽量落在 **不同 conflict_domain**
- Batch 完成必须通过 **Batch Gate**（见第 4 节），否则不得进入下一批次
- 冻结锁（ports/health keys/request-id/error/pagination/routes）不允许在 Dev 批次内被改动

---

## 2) 冲突域（Conflict Domains）与并行策略

> 用于“谁能并行、谁不能并行”的决策依据

- **infra_runtime**：运行方式/脚本/环境变量/容器与本地启动路径
- **observability_contract**：health/logging/request-id/metrics（强门禁，优先稳定）
- **data_model**：核心实体边界/不可变性/存储抽象（影响面大，优先集中处理）
- **api_contract**：错误信封/分页/核心 API 切片（前后端对齐的核心冲突域）
- **ui_routes**：路由/页面骨架/导航结构（前端合流核心冲突域）
- **ui_components**：组件层（可较高并行度，但要遵守 UI 契约）
- **integration_tests**：端到端脚本/门禁/回归（最后收口）

并行指导：

- 同一时间段尽量让不同窗口分别占据不同冲突域
- 若必须多人改同一冲突域：设置“领域负责人（Domain Owner）”并采用串行合流

---

## 3) 批次清单（Batches）

> 以 MASTER_PLAN.steps 为准，此处只做组织与节奏定义

### Batch-0：Foundations & Gates（基础门禁与可观测性基线）

- **目标**：建立可运行基线与硬门禁，确保后续开发不漂移
- **包含 Steps（示例）**：
  - STEP-000-context-sync
  - STEP-010-observability-foundation
  - STEP-020-api-core-contracts
- **并行度**：低（建议串行或极少并行）
- **关键产出**：
  - gates 可运行（scripts/gate_all.sh 等）
  - /health key 锁稳定
  - X-Request-Id 传播稳定
  - 错误信封/分页规范已固化
- **Batch Gate（必须通过）**：见第 4 节

---

### Batch-1：Data & Storage Skeleton（数据层与存储骨架）

- **目标**：建立核心实体边界与存储抽象，为 API/UI 提供稳定底座
- **包含 Steps**：
  - STEP-030-data-model-skeleton
- **并行度**：低（建议集中处理）
- **关键产出**：
  - 核心实体边界与不变量落地
  - 存储抽象可支撑资产落盘与引用
  - 证据链不可静默覆盖策略可表达
- **Batch Gate**：见第 4 节

---

### Batch-2：API Slices（业务 API 切片）

- **目标**：在契约稳定前提下，提供 UI 需要的最小 API 闭环
- **包含 Steps**：
  - STEP-035-api-assets-read
  - STEP-038-api-generate-run
  - STEP-025-review-contract
- **并行度**：中（可并行，但需隔离改动面）
- **并行建议**：
  - A窗口：assets read（api_contract）
  - B窗口：generate/run（api_contract）
  - C窗口：review（data_model）
- **关键产出**：
  - assets list/detail + traceability view
  - run create/status/result registration（最小闭环）
  - review 记录与策略占位（支持自动通过+抽检）
- **Batch Gate**：见第 4 节

---

### Batch-3：UI Slices（前端路由与页面骨架）

- **目标**：实现 UI 契约（routes + skeletons）并对接 API
- **包含 Steps**：
  - STEP-040-ui-library
  - STEP-045-ui-asset-detail
  - STEP-050-ui-generate
- **并行度**：中高（可并行，但要遵守 routes/skeleton 约束）
- **并行建议**：
  - A窗口：/library 页骨架 + 批处理栏（ui_routes）
  - B窗口：/assets/:id 详情骨架（ui_routes）
  - C窗口：/generate 骨架（ui_routes）
- **关键产出**：
  - 核心任务交互层级 ≤ 3
  - Library/Detail/Generate 的 must_have_sections 全具备
- **Batch Gate**：见第 4 节

---

### Batch-4：Integration & E2E（集成收口与端到端验证）

- **目标**：跑通最小闭环端到端流程并固化回归门禁
- **包含 Steps**：
  - STEP-060-e2e-happy-path
- **并行度**：低（收口为主）
- **关键产出**：
  - 端到端验证脚本可运行
  - gates 全绿
  - P0 AC 覆盖证据（日志/截图/输出摘要）
- **Batch Gate**：见第 4 节

---

## 4) Batch Gate（批次门禁定义）

> 每个 Batch 结束必须通过对应门禁，否则不得进入下一批次  
> 注意：门禁命令名示例可替换为你仓库实际脚本名；但门禁“意图”必须满足 ARCH_DIGEST 锁

### 4.1 通用门禁（所有批次通用）

- **Health Contract**：
  - `GET /health` 必须包含 keys：`status, version, db, storage, last_error_summary`
- **Request ID**：
  - 入/出站均有 `X-Request-Id`（缺失时服务端生成）
  - 日志中有 `request_id`
- **OpenAPI**：
  - `/openapi.json` 可访问
- **Error Envelope + Pagination**：
  - 错误响应符合 error envelope（含 request_id）
  - 列表接口符合分页 shape（items/next_cursor/total）

### 4.2 Batch-0 门禁（Foundations）

- 必须通过：
  - 运行总门禁（例如：`scripts/gate_all.sh` 或等价）
  - 运行 API 冒烟（例如：`scripts/gate_api_smoke.sh` 或等价）
- 必须产出：
  - “门禁通过证据”记录（见第 6 节）

### 4.3 Batch-1 门禁（Data Skeleton）

- 必须通过：
  - API 单测（例如：`pytest -q` 或等价）
  - health/openapi/request-id 连续通过（不得回归）

### 4.4 Batch-2 门禁（API Slices）

- 必须通过：
  - assets list/detail 可访问（按计划接口）
  - run create/status 可访问（按计划接口）
  - 错误信封/分页规范对新接口生效

### 4.5 Batch-3 门禁（UI Slices）

- 必须通过：
  - 页面可访问：`/library`, `/assets/:id`, `/generate`
  - must_have_sections 具备（手工走查或自动化检查）
  - 关键交互 ≤ 3 层（按 spec NFR）

### 4.6 Batch-4 门禁（E2E）

- 必须通过：
  - 端到端 Happy Path（生成->审核->入库->展示->追溯）
  - 全量 gates（包含回归）

---

## 5) 合流节奏（Merge Cadence）与分支策略

### 5.1 合流策略（推荐）

- 每个 Batch 使用一个集成分支：`batch/<id>-<name>`
- Batch 内每个 step 对应一个功能分支：`feat/<step-id>`
- 合流顺序：
  1) 先合流 Batch 内基础契约/公共改动（若有）
  2) 再合流并行步骤（冲突域尽量隔离）
  3) 最后跑 Batch Gate，合到主干/集成分支

### 5.2 冲突处理规则

- 冲突域文件由该域 Owner 决策最终合并版本
- 冲突涉及“锁定项”时：立即停止并走 CR（Window-5）

---

## 6) 证据与报告（Evidence & Reporting）

> 为 Window-4（Validator）提供可审计材料；每批次至少提交一次证据摘要

### 6.1 最小证据包（每批次必需）

- 输入指纹：spec/arch/plan sha256
- 门禁执行日志摘要：
  - 通过/失败
  - 失败原因（若失败）
- 关键输出（示例）：
  - health 响应示例（仅展示 keys + status）
  - request-id 头示例（仅展示是否存在）
  - UI 手工走查清单（Batch-3）

### 6.2 建议格式（可复制）

    BATCH_EVIDENCE:
      batch_id: "BATCH-2"
      inputs:
        spec_sha256: "<...>"
        arch_sha256: "<...>"
        plan_sha256: "<...>"
      gates:
        - name: "gate_api_smoke"
          result: "pass"
          evidence_ref: "<log_snippet_or_file>"
      notes:
        - "<回归风险/已知限制>"

---

## 7) 变更传播机制（Change Propagation）

- 若变更影响 spec：走 **CR-L1（SPEC_CHANGE_REQUEST）→ Window-5**
- 若变更影响 arch locks：走 **CR-L2（ARCH_CHANGE_REQUEST）→ Window-5**
- 若仅调整计划/批次/任务分配：走 **PLAN_CHANGE_REQUEST → Window-5**

Window-5 批准后必须执行：

- bump version + 更新 sha256
- 通知 Window-3/4/Dev（以摘要 + 指纹为准）

---

## 8) 常见风险与应对（Risk Playbook）

- 风险：并行开发导致契约漂移  
  - 应对：Batch-0 先固化 locks + gate；后续任何锁变更走 CR
- 风险：同一冲突域多人并行造成合流成本爆炸  
  - 应对：域 Owner + 串行合流，或拆分更细的接口边界
- 风险：UI 先行导致 API 反复改  
  - 应对：严格 O1~O4，API 契约稳定后再推进 UI

---

## 9) 附录：批次-步骤映射（填表）

- BATCH-0
  - Steps: **<STEP-000/010/020>**
  - 并行度：**低**
  - 主要冲突域：**observability/api**
  - Batch Gate：**gate_all + api_smoke**
- BATCH-1
  - Steps: **<STEP-030>**
  - 并行度：**低**
  - 主要冲突域：**data_model**
  - Batch Gate：**pytest + health/openapi**
- BATCH-2
  - Steps: **<STEP-035/038/025>**
  - 并行度：**中**
  - 主要冲突域：**api/data**
  - Batch Gate：**api_smoke + endpoints**
- BATCH-3
  - Steps: **<STEP-040/045/050>**
  - 并行度：**中高**
  - 主要冲突域：**ui_routes**
  - Batch Gate：**page access + skeleton**
- BATCH-4
  - Steps: **<STEP-060>**
  - 并行度：**低**
  - 主要冲突域：**integration**
  - Batch Gate：**e2e + full gates**
......
- BATCH-N
......