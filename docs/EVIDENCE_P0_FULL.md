# P0 FULL Regression Evidence

- Generated at (UTC): 2025-12-30T12:41:21Z
- Branch: dev/batch3-ui-ac003-generate
- HEAD: e9dc5e999a3f9c5eac33ea5fa042f9d5cbdb7bde
- Command: bash scripts/gate_all.sh --mode=full --repeat=3

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

## Key [ok] lines (run 3)
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
[ok] create run: type=t2i run_id=01KDQMD95R0SH2YQ8196XT6QE5 request_id=6ff11baf-be9d-44c7-a2d7-d11d3991061c
[ok] refresh run: run_id=01KDQMD95R0SH2YQ8196XT6QE5
[ok] create run: type=i2i run_id=01KDQMD99Y34QQC723D5DAEC27 request_id=0acfbec0-cd52-4c6f-8fd2-cbcf8f3c7c4a
[ok] refresh run: run_id=01KDQMD99Y34QQC723D5DAEC27
[ok] create run: type=t2v run_id=01KDQMD9EHWMTMFV8ZYYB8KQJ2 request_id=ce01deda-1ee7-439a-9e80-c3616a8a0cbd
[ok] refresh run: run_id=01KDQMD9EHWMTMFV8ZYYB8KQJ2
[ok] create run: type=i2v run_id=01KDQMD9KHGD679QVVAE78H4QC request_id=7ef1268e-7afd-4eea-9568-4dcc4171968d
[ok] refresh run: run_id=01KDQMD9KHGD679QVVAE78H4QC
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
[ok] override missing reason rejected; error envelope ok; request_id=8faff360-eed1-4402-9ac9-8b3a27c2fd0a
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
[ok] request_id sample: tmp/_out_gate_ac_003__run3.txt:request_id=6ff11baf-be9d-44c7-a2d7-d11d3991061c
[ok] e2e happy path passed
```

## request_id samples (run 3)
```text
tmp/_out_gate_ac_003__run3.txt:request_id=6ff11baf-be9d-44c7-a2d7-d11d3991061c
tmp/_out_gate_ac_003__run3.txt:request_id=0acfbec0-cd52-4c6f-8fd2-cbcf8f3c7c4a
tmp/_out_gate_ac_003__run3.txt:request_id=ce01deda-1ee7-439a-9e80-c3616a8a0cbd
tmp/_out_gate_ac_003__run3.txt:request_id=7ef1268e-7afd-4eea-9568-4dcc4171968d
tmp/_out_gate_ac_004__run3.txt:request_id=8faff360-eed1-4402-9ac9-8b3a27c2fd0a
```

## Raw logs
- tmp/_out_gate_*
