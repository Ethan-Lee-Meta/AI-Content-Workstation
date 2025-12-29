# REQ_CONTRACT_SUMMARY（需求契约摘要 / 下游注入包）

> 用途：供 Window-02（ARCH）/ Window-03（PLAN）/ Dev Windows 快速注入与对齐  
> 约束：本摘要不包含任何技术实现细节（无 DB 表结构/库版本/API 字段名/路由设计）

---

## 0) 指纹与冻结状态（必须填写）
- Project: **<project_name>**
- AI_SPECDIGEST:
  - version: **<spec_version>**
  - status: **<draft|frozen>**
  - sha256: **<spec_sha256_or_placeholder>**
  - created_at: **<ISO8601>**
- 变更规则：冻结后仅允许通过 **CR-L1（SPEC_CHANGE_REQUEST）→ Change Coordinator（Window-5）** 版本化更新

---

## 1) 三句概括（强约束、可复述）
- **核心价值**：<一句话描述系统为用户带来的核心价值>
- **用户画像**：<一句话描述主要用户与使用场景>
- **关键差异**：<一句话描述与现有方案相比的关键优势（必须能落到验收或指标）>

---

## 2) 范围边界（scope.in / scope.out）
### 2.1 scope.in（必做清单，按优先级）
> 只列 P0/P1 的范围项；每项都必须对应至少一个 Workflow 与 AC（见第4/5节）

- **P0**
  - S1: <name> —— <一句话解释>
  - S2: <name> —— <一句话解释>
  - S3: <name> —— <一句话解释>

- **P1**
  - S4: <name> —— <一句话解释>

### 2.2 scope.out（明确不做清单）
- O1: <name>（理由：<reason>）
- O2: <name>（理由：<reason>）
- O3: <name>（理由：<reason>）

### 2.3 未来可能扩展（当前不承诺）
- F1: <future_candidate>
- F2: <future_candidate>

---

## 3) 核心概念与术语（glossary，低歧义）
> 下游所有实现与文档必须使用这些术语，不得私自替换定义

- **Asset**：<definition>
- **Prompt**：<definition>
- **Run**：<definition>
- **Review**：<definition>
- **Evidence Chain**：<definition>
- （可选）Project / Series：<definition + 是否必填的决策见第6节>

---

## 4) 核心用户流程（Workflows：Happy Path + 关键异常）
### 4.1 WF1（Happy Path）：<name>
- Trigger：<触发>
- Preconditions：<前置条件>
- Steps（4–8步）：
  1. ...
  2. ...
- Postconditions（完成后必须成立）：
  - ...
- Exceptions（必须覆盖的关键异常）：
  - EX1: <condition> → <expected_handling>
  - EX2: <condition> → <expected_handling>

### 4.2 WF2：<name>
（同上结构）

### 4.3 WF3：<name>（如适用）
（同上结构）

---

## 5) 验收标准（Acceptance Criteria：下游“不可争辩”的验收口径）
> 只列 P0 必验的 AC（通常 3–6 条）。每条必须可验证（手工/接口/端到端）

- **AC-001（P0 / functional）**：<title>  
  - Given：<前提>  
  - When：<操作>  
  - Then：<预期>  
  - Verification：<方法：手工走查/端到端流程/接口返回包含概念字段等（不写字段名）>

- **AC-002（P0 / functional）**：<title>  
  - Given：...
  - When：...
  - Then：...
  - Verification：...

- **AC-003（P0 / functional）**：<title>  
  - Given：...
  - When：...
  - Then：...
  - Verification：...

（可选 P1：不超过 2 条）

---

## 6) 默认决策（Decisions：减少反复确认、控制漂移）
> 下游必须按“confirmed”的决策执行；pending 的决策不得自行假设（需回到 Window-1 或走 CR）

| Decision ID | Topic | Default | Status | Impact (需求层) |
|---|---|---|---|---|
| D-001 | <topic> | <default> | confirmed/pending | <影响到哪些范围/验收/流程> |
| D-002 | <topic> | <default> | confirmed/pending | ... |
| D-003 | <topic> | <default> | confirmed/pending | ... |

---

## 7) 非功能性需求（NFR：必须有“目标或默认阈值/假设”）
> 需求层表达，不涉及实现细节。无法量化时必须写默认阈值或假设（quantification_status）

- **Observability（必须）**
  - NFR-OBS-001：<must_have>
  - NFR-OBS-002：<must_have>（/health 概念存在，响应键由 ARCH 锁定）
  - NFR-OBS-003：<must_have>（request_id 概念存在，header名由 ARCH 定义）

- **Performance（目标或默认阈值）**
  - NFR-PERF-001：<scenario> → <target/default_threshold/assumption>

- **Reliability（必须）**
  - NFR-REL-001：<must_have>

- **Usability（与“浅层交互/批处理”强绑定）**
  - NFR-UX-001：核心任务交互层级 ≤ 3（目标）
  - NFR-UX-002：高频操作支持批处理（必须）

- **Security（默认假设）**
  - NFR-SEC-001：<assumption>

---

## 8) 追溯矩阵（最小版：scope ↔ workflow ↔ acceptance）
> 下游出现争议时，以此矩阵快速定位“需求承诺点”

- S1 → WF2 → AC-001/AC-002
- S2 → WF1 → AC-003
- S3 → WF1/WF2 → AC-002/AC-003
- S4 → WF3 → AC-005（如适用）

---

## 9) 未决问题（open_questions：冻结时必须为空）
- Q-001：<question>（Owner：<who>）
- Q-002：<question>（Owner：<who>）

---

## 10) 下游窗口工作指令（只写契约，不写实现）
- Window-02（ARCH）：基于本摘要与 AI_SPECDIGEST 冻结版，锁定技术栈/目录/契约/可观测性，并输出 ARCH_DIGEST + ARCH_CONTRACT_SUMMARY
- Window-03（PLAN）：将 scope/workflows/AC 映射成可并行 steps，并输出 MASTER_PLAN + 批次与分配
- DEV Windows：不得变更 scope/out/AC/decisions（confirmed）与 NFR；如需变更走 CR
