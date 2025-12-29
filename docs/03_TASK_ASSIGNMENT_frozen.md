---
artifact: TASK_ASSIGNMENT
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
  DEVELOPMENT_BATCHES:
    version: 1.0.0
    status: frozen
    sha256: cb1661508a4ad4287525917bc6758fd8fc1a51bf6d27d53aba38754ac1e1f786
sha256: 4b08369fb5f87e53d7e21be866211c28a7500c0d21ca4cdb24fd3e5004a22ef7
---

# TASK_ASSIGNMENT（窗口分配 / 批次执行清单）

> 用途：把 DEVELOPMENT_BATCHES 的批次映射为“一个批次 = 一个开发窗口”，并明确每个窗口的边界、输入、输出、验收与合流规则。  
> 说明：本文件仅用于分工与窗口治理，不包含任何代码实现细节。

---

## 0) 指纹与冻结状态

- Project: **<项目名>**
- Inputs:
  - AI_SPECDIGEST: version **1.0.0**, status **frozen**, sha256 **77b334b8533592dbe7c74adb7d5e5e36a13266c23d95cdc72705c84a319e03cf**
  - ARCH_DIGEST: version **1.0.0**, status **frozen**, sha256 **adfb12f1a7ebc21cf15d5052213532bd3a484ebd19e2ad4e3b782eac11f216ca**
  - MASTER_PLAN: version **1.0.0**, status **frozen**, sha256 **cf659999b6876860413ef12f38f959e0b9dbd8247dba6f39b173299d5ca87345**
  - DEVELOPMENT_BATCHES: version **1.0.0**, status **frozen**, sha256 **cb1661508a4ad4287525917bc6758fd8fc1a51bf6d27d53aba38754ac1e1f786**
- 本文件版本：**1.0.0**, status **frozen**

---

## 1) 总体规则（冻结）

1. **一窗一批次 / 一批次一冲突域**：每个 Dev Window 只做一个 Batch；该 Batch 只允许一个 conflict_domain。  
2. **不跨域改动**：触碰其他域视为“冲突升级”，必须中止并走 PLAN_CHANGE_REQUEST。  
3. **门禁先行**：进入 Batch 前必须满足 entry_criteria；完成后必须通过 exit_criteria 对应 gates。  
4. **证据输出**：每个窗口输出 gate 关键 [ok] 行摘要，作为后续窗口输入。  
5. **回滚优先**：默认 `git revert`；如果实现用了 Feature Flag，优先关开关回滚。  
6. **锁定项**：端口 2000/7000、/health keys、X-Request-Id、错误信封、分页字段属于硬锁，任何变更必须走 CR。

---

## 2) Window 角色分配（建议命名）

### 2.1 计划与治理窗口（已完成/本窗口）
- **Window-1 SpecAnalyst**：冻结 AI_SPECDIGEST（需求 SSOT）
- **Window-2 ChiefArchitect**：冻结 ARCH_DIGEST / ARCH_CONTRACT_SUMMARY（架构 SSOT）
- **Window-3 DevPlanner**：冻结 MASTER_PLAN / DEVELOPMENT_BATCHES / TASK_ASSIGNMENT（计划 SSOT）

### 2.2 执行窗口（每个 Batch 一个）
命名建议：`DEV_B<n>_<conflict_domain>`（示例：DEV_B2_api_contract）

---

## 3) 批次 → 窗口映射（冻结）

| Batch | Phase | conflict_domain | Dev Window | 允许改动范围（路径级） | 必须产出（最小） | 必跑 gates（最小） |
|---|---|---|---|---|---|---|
| BATCH-0 | P0 | infra_runtime | DEV_B0_infra_runtime | scripts/**, docs/**, apps/api(core) | gate_all(preflight), api_smoke | gate_all --mode=preflight; gate_api_smoke |
| BATCH-1 | P0 | data_model | DEV_B1_data_model | apps/api(models+migrations), docs/** | db/storage + models gate 证据 | gate_db_storage; gate_models |
| BATCH-2 | P0 | api_contract | DEV_B2_api_contract | apps/api(modules/**), docs/** | assets/runs/reviews/trash gates 证据 | gate_assets_read; gate_runs_core; gate_reviews; gate_trash |
| BATCH-3 | P0 | ui_routes | DEV_B3_ui_routes | apps/web/**, docs/** | routes + AC-001..004 gates 证据 | gate_web_routes; gate_ac_001..004 |
| BATCH-4 | P0 | infra_runtime | DEV_B4_infra_runtime | scripts/**, docs/** | e2e 证据 + gate_all(full) | gate_all --mode=full |
| BATCH-5 | P1 | ui_routes | DEV_B5_ui_routes | apps/web/**, docs/** | AC-005 + bulk/trash UI gates | gate_ac_005; gate_bulk_actions; gate_trash_ui |
| BATCH-6 | P1 | api_contract | DEV_B6_api_contract | apps/api(modules/shots+links), docs/** | shots API gate | gate_shots_p1 |
| BATCH-7 | P1 | ui_routes | DEV_B7_ui_routes | apps/web/** | shots UI gate | gate_shots_ui_p1 |
| BATCH-8 | P1 | infra_runtime | DEV_B8_infra_runtime | apps/api(provider/export), scripts/**, docs/** | provider + export/import gates | gate_provider_adapter; gate_export_import_p1 |

---

## 4) 每个 Dev Window 的标准输出包（冻结）

每个 DEV_B* 窗口必须在最终回复中提供以下内容（可复制保存）：

1) **Window Envelope**（输入指纹 + 本窗口 Batch/Domain + 允许路径）  
2) **WorkOrder**（按 step 顺序列出：必须做/禁止做/预期改动文件列表上限）  
3) **Verification Log**（对应 gates 命令 + 关键 [ok] 行）  
4) **Rollback Plan**（revert/flag/数据重置的边界）  
5) **Handoff Summary**（交付什么、已知风险、下一 Batch 的 entry_criteria 是否满足）

---

## 5) 失败降级（冻结）

- 若 gate 不稳定：
  - 允许将该 gate 标记为 nightly/optional 的唯一方式：**PLAN_CHANGE_REQUEST**（必须写明降级范围与恢复条件）
- 若出现跨域改动需求：
  - 停止开发，回到 Window-5 进行计划/架构变更评审（CR）

---

## 6) 兼容“分阶段开发”的执行建议

- 先完成 **PHASE-P0（BATCH-0..4）**，达到“可用闭环 + 全绿门禁”。
- 之后按需启用 **PHASE-P1（BATCH-5..8）**，建议采用 Feature Flag 避免回归影响 P0。
