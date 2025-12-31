# P0 FULL Regression Evidence

- Generated at (UTC): 2025-12-31T13:41:52Z
- Branch: dev/batch8-provider-adapter-p1
- HEAD: 887f984ecc8f59c4c4ddf954fa9366afb8f45bbc
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
[ok] /openapi.json reachable
[ok] off -> json ok
[ok] flag OFF -> POST /runs ok run_id=01KDTA6J47845S0VW3SX7Y345V status=queued
[ok] flag OFF -> GET ok status=queued result_refs_keys=[]
[ok] on -> json ok
[ok] flag ON -> POST /runs ok run_id=01KDTA6KKX8AD2G0AAZCXSB2YX status=succeeded
[ok] flag ON -> GET ok status=succeeded refs_count=1
[ok] artifact exists: ./data/storage\runs\01KDTA6KKX8AD2G0AAZCXSB2YX\result.json
[ok] forced fail -> error_envelope ok request_id=fbef65ec-1b45-4493-b51c-63d5a316fc93 run_id=01KDTA6NS87YA7PV8ZWWWG41ZD
[ok] forced fail -> GET ok status=failed
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
[ok] create run: type=t2i run_id=01KDTA84MV0C54K01NHYZ3DTEG request_id=cc887a21-25bc-41ed-bb52-daf226c81c5f
[ok] refresh run: run_id=01KDTA84MV0C54K01NHYZ3DTEG
[ok] create run: type=i2i run_id=01KDTA84W0QFH60WH59G0NK70H request_id=0feedfdd-4d7b-48fb-a8bf-251222879d52
[ok] refresh run: run_id=01KDTA84W0QFH60WH59G0NK70H
[ok] create run: type=t2v run_id=01KDTA851V98SB6JENAMW4SYPW request_id=21ae70a7-d0d4-4499-9554-a995942ae413
[ok] refresh run: run_id=01KDTA851V98SB6JENAMW4SYPW
[ok] create run: type=i2v run_id=01KDTA8596XH7WQ3A83T5EYXXJ request_id=791c2611-80d6-440a-95c2-89a6968bfde5
[ok] refresh run: run_id=01KDTA8596XH7WQ3A83T5EYXXJ
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
[ok] override missing reason rejected; error envelope ok; request_id=28953902-cf50-47b6-b031-62b21e9ee19a
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
[ok] request_id sample: tmp/_out_gate_ac_003.txt:request_id=cc887a21-25bc-41ed-bb52-daf226c81c5f
[ok] e2e happy path passed
[ok] shots list returns items+page with required keys
[ok] shots detail returns shot + linked_refs summary
[ok] creating link works and appears in linked_refs
[ok] deleting link uses tombstone semantics and effective view is updated
[ok] /openapi.json reachable
[ok] /shots renders (http=200)
[ok] picked shot_id: 00363326BCB248A5B341B04BDF3CE2A6
[ok] /shots/:shot_id renders (http=200)
[ok] link created link_id=9C1FFBB1C0894379AA0D03A7D0659D9E
[ok] link removed (tombstone semantics)
```

## request_id samples (run 1)
```text
tmp/_out_gate_ac_003.txt:request_id=cc887a21-25bc-41ed-bb52-daf226c81c5f
tmp/_out_gate_ac_003.txt:request_id=0feedfdd-4d7b-48fb-a8bf-251222879d52
tmp/_out_gate_ac_003.txt:request_id=21ae70a7-d0d4-4499-9554-a995942ae413
tmp/_out_gate_ac_003.txt:request_id=791c2611-80d6-440a-95c2-89a6968bfde5
tmp/_out_gate_ac_004.txt:request_id=28953902-cf50-47b6-b031-62b21e9ee19a
```

## Raw logs
- tmp/_out_gate_*
