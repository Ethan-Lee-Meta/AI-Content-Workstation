# HANDOFF — BATCH-4 (PHASE-P0 / infra_runtime)

## 0) Snapshot
- Branch: `dev/batch3-ui-ac003-generate`
- HEAD: `a392c5b7398f3caf4d42a2b5d36c3557fd653639`
- Evidence: `docs/EVIDENCE_P0_FULL.md`
- Sample request_id: `6ff11baf-be9d-44c7-a2d7-d11d3991061c`

## 1) What BATCH-4 delivers
- Single entry for P0 full regression:
  - `bash scripts/gate_all.sh --mode=full`
  - (optional) `bash scripts/gate_all.sh --mode=full --repeat=3`
- Required gates chained (min set):
  - gate_api_smoke
  - gate_openapi_reachable
  - gate_health_contract_check
  - gate_request_id_propagation_check
  - gate_ac_001
  - gate_ac_002
  - gate_ac_003
  - gate_ac_004
  - gate_e2e_happy_path
- Auditable outputs:
  - `docs/EVIDENCE_P0_FULL.md` (key [ok] lines + request_id samples)
  - Raw per-gate logs: `tmp/_out_gate_*.txt` (not curated in this batch)

## 2) Failure定位策略（快速）
- 入口失败：看控制台提示的 `(see tmp/_out_gate_<label>*.txt)`
- e2e 汇总失败：看 `tmp/_out_gate_e2e_happy_path*.txt`
- 证据文档生成失败：检查 `docs/` 写入权限与 `docs/EVIDENCE_P0_FULL.md`

## 3) DoD (Exit Criteria) checklist
- [x] `gate_all --mode=full` 可执行
- [x] required_gates_min_set 全绿
- [x] `docs/EVIDENCE_P0_FULL.md` 已生成
- [x] (optional) repeat=3 全绿

## 4) Next window inputs
- Provide:
  - Merge/HEAD SHA
  - `docs/EVIDENCE_P0_FULL.md`
  - This file: `docs/HANDOFF_BATCH4.md`
