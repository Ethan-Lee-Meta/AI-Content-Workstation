# P0 FULL Regression Evidence

- Generated at (UTC): 2025-12-31T03:47:40Z
- Branch: dev/batch5-ui-p1
- HEAD: 08149c3a348f1d0dc4e8ac0ce74753e2a58e3c49
- Command: bash scripts/gate_all.sh --mode=full

## Required gates (min set) + e2e
- gate_api_smoke
- gate_openapi_reachable
- gate_health_contract_check
- gate_request_id_propagation_check
- gate_ac_001
- gate_ac_002
- gate_ac_003
- gate_ac_004
- gate_e2e_happy_path

## Key [ok] lines (run 1)
```text
[ok] /health keys present: status, version, db, storage, last_error_summary
[ok] header present: X-Request-Id (non-empty)
[ok] /openapi.json reachable
[ok] /health keys present: status, version, db, storage, last_error_summary
[ok] header present: X-Request-Id (non-empty)
[ok] /openapi.json reachable
[ok] error path header present: X-Request-Id (non-empty)
[ok] error envelope includes request_id and required keys
[ok] gate_api_smoke passed
[ok] server ready (http://127.0.0.1:2000)
[ok] route ok: /
[ok] route ok: /library
[ok] route ok: /assets/test-asset
[ok] route ok: /generate
[ok] route ok: /projects
[ok] route ok: /projects/test-project
[ok] route ok: /series
[ok] route ok: /series/test-series
[ok] route ok: /shots
[ok] route ok: /shots/test-shot
[ok] routes accessible: /, /library, /assets/:id, /generate (+ placeholders)
[ok] api reachable: /openapi.json
[ok] /assets returns items[] + page{limit,offset,total,has_more}
[ok] server ready (http://127.0.0.1:2000)
[ok] route ok: /
[ok] route ok: /library
[ok] route ok: /assets/test-asset
[ok] route ok: /generate
[ok] route ok: /projects
[ok] route ok: /projects/test-project
[ok] route ok: /series
[ok] route ok: /series/test-series
[ok] route ok: /shots
[ok] route ok: /shots/test-shot
[ok] routes accessible: /, /library, /assets/:id, /generate (+ placeholders)
[ok] /library source contains required sections markers (FiltersBar/AssetGrid/BulkActionBar)
[ok] api reachable: /openapi.json
[ok] picked asset_id=5FBA8D5F46254AF9819D359F83726558
[ok] /assets/:id returns an object
[ok] error envelope includes error/message/request_id/details
[ok] server ready (http://127.0.0.1:2000)
[ok] route ok: /
[ok] route ok: /library
[ok] route ok: /assets/test-asset
[ok] route ok: /generate
[ok] route ok: /projects
[ok] route ok: /projects/test-project
[ok] route ok: /series
[ok] route ok: /series/test-series
[ok] route ok: /shots
[ok] route ok: /shots/test-shot
[ok] routes accessible: /, /library, /assets/:id, /generate (+ placeholders)
[ok] asset detail source contains required panel markers
[ok] api reachable: /openapi.json
[ok] create run: type=t2i run_id=01KDS88FYDH93NABJTKEPBSXY8 request_id=8de36e37-8796-419f-895b-adbe989f9f9d
[ok] refresh run: run_id=01KDS88FYDH93NABJTKEPBSXY8
[ok] create run: type=i2i run_id=01KDS88G54CSJZ72BZ3CS63YRC request_id=203c4189-b990-48ef-94fc-a72e072cee72
[ok] refresh run: run_id=01KDS88G54CSJZ72BZ3CS63YRC
[ok] create run: type=t2v run_id=01KDS88GCE10XCNR25VPMZMAVB request_id=595f4b13-7abb-45e8-84b5-1ab200934dea
[ok] refresh run: run_id=01KDS88GCE10XCNR25VPMZMAVB
[ok] create run: type=i2v run_id=01KDS88GK6RRP3RBW5HWQ4T2GG request_id=38c69b8a-6e29-4592-93a0-e64e8a493096
[ok] refresh run: run_id=01KDS88GK6RRP3RBW5HWQ4T2GG
[ok] create run for each type; status refreshed
[ok] server ready (http://127.0.0.1:2000)
[ok] route ok: /
[ok] route ok: /library
[ok] route ok: /assets/test-asset
[ok] route ok: /generate
[ok] route ok: /projects
[ok] route ok: /projects/test-project
[ok] route ok: /series
[ok] route ok: /series/test-series
[ok] route ok: /shots
[ok] route ok: /shots/test-shot
[ok] routes accessible: /, /library, /assets/:id, /generate (+ placeholders)
[ok] /generate source contains required section markers (InputTypeSelector/PromptEditor/RunQueuePanel/ResultsPanel)
[ok] api reachable: /openapi.json
[ok] override missing reason rejected; error envelope ok; request_id=cfac5c7e-a121-49df-b396-6d4e01ba682a
[ok] server ready (http://127.0.0.1:2000)
[ok] route ok: /
[ok] route ok: /library
[ok] route ok: /assets/test-asset
[ok] route ok: /generate
[ok] route ok: /projects
[ok] route ok: /projects/test-project
[ok] route ok: /series
[ok] route ok: /series/test-series
[ok] route ok: /shots
[ok] route ok: /shots/test-shot
[ok] routes accessible: /, /library, /assets/:id, /generate (+ placeholders)
[ok] Review UI markers present and wired
[ok] request_id sample: tmp/_out_gate_ac_003.txt:request_id=8de36e37-8796-419f-895b-adbe989f9f9d
[ok] e2e happy path passed
```

## request_id samples (run 1)
```text
tmp/_out_gate_ac_003.txt:request_id=8de36e37-8796-419f-895b-adbe989f9f9d
tmp/_out_gate_ac_003.txt:request_id=203c4189-b990-48ef-94fc-a72e072cee72
tmp/_out_gate_ac_003.txt:request_id=595f4b13-7abb-45e8-84b5-1ab200934dea
tmp/_out_gate_ac_003.txt:request_id=38c69b8a-6e29-4592-93a0-e64e8a493096
tmp/_out_gate_ac_004.txt:request_id=cfac5c7e-a121-49df-b396-6d4e01ba682a
```

## Raw logs
- tmp/_out_gate_*
