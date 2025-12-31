# P0 FULL Regression Evidence

- Generated at (UTC): 2025-12-31T13:24:05Z
- Branch: dev/batch8-provider-adapter-p1
- HEAD: b9be994836aface4a8c8a0710f1768a9794d92c2
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
[warn] missing log: tmp/_out_gate_provider_adapter.txt
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
[ok] picked asset_id=AACADF2B93B344EE93AF656AB5EBE57D
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
[ok] create run: type=t2i run_id=01KDT97N5R77P43JE5HBTWJ3ZV request_id=607d67aa-6f1f-4f58-b3f5-3db801cbdac6
[ok] refresh run: run_id=01KDT97N5R77P43JE5HBTWJ3ZV
[ok] create run: type=i2i run_id=01KDT97NC76H8KBCZCMTXBHHYG request_id=0465e976-717d-4831-a993-989d68edceac
[ok] refresh run: run_id=01KDT97NC76H8KBCZCMTXBHHYG
[ok] create run: type=t2v run_id=01KDT97NJBBRHN8J4JVXQ7A58F request_id=834273a9-aa94-48aa-9189-a7c66a131257
[ok] refresh run: run_id=01KDT97NJBBRHN8J4JVXQ7A58F
[ok] create run: type=i2v run_id=01KDT97NSSQGN930RF06Y8874F request_id=e982e698-0e2f-4f44-9201-8bb5cd91107c
[ok] refresh run: run_id=01KDT97NSSQGN930RF06Y8874F
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
[ok] override missing reason rejected; error envelope ok; request_id=c8c231ef-666a-46c1-9356-eff716aa5021
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
[ok] request_id sample: tmp/_out_gate_ac_003.txt:request_id=607d67aa-6f1f-4f58-b3f5-3db801cbdac6
[ok] e2e happy path passed
[ok] shots list returns items+page with required keys
[ok] shots detail returns shot + linked_refs summary
[ok] creating link works and appears in linked_refs
[ok] deleting link uses tombstone semantics and effective view is updated
[ok] /openapi.json reachable
[ok] /shots renders (http=200)
[ok] picked shot_id: 00363326BCB248A5B341B04BDF3CE2A6
[ok] /shots/:shot_id renders (http=200)
[ok] link created link_id=0295C0C9001F447283430DAF0D7FC7E5
[ok] link removed (tombstone semantics)
```

## request_id samples (run 1)
```text
tmp/_out_gate_ac_003.txt:request_id=607d67aa-6f1f-4f58-b3f5-3db801cbdac6
tmp/_out_gate_ac_003.txt:request_id=0465e976-717d-4831-a993-989d68edceac
tmp/_out_gate_ac_003.txt:request_id=834273a9-aa94-48aa-9189-a7c66a131257
tmp/_out_gate_ac_003.txt:request_id=e982e698-0e2f-4f44-9201-8bb5cd91107c
tmp/_out_gate_ac_004.txt:request_id=c8c231ef-666a-46c1-9356-eff716aa5021
```

## Raw logs
- tmp/_out_gate_*
