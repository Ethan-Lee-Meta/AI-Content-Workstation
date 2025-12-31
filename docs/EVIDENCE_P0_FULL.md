# P0 FULL Regression Evidence

- Generated at (UTC): 2025-12-31T15:39:33Z
- Branch: dev/batch8-provider-adapter-p1
- HEAD: 338436ae898a4a1fad5260825a773f7991d7c227
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
[ok] flag OFF -> POST /runs ok run_id=01KDTGY7SX7N2SCZJ3KWQHTWD8 status=queued
[ok] flag OFF -> GET ok status=queued result_refs_keys=[]
[ok] on -> json ok
[ok] flag ON -> POST /runs ok run_id=01KDTGY9B6B104J502PDM56BTP status=succeeded
[ok] flag ON -> GET ok status=succeeded refs_count=1
[ok] artifact exists: ./data/storage\runs\01KDTGY9B6B104J502PDM56BTP\result.json
[ok] forced fail -> error_envelope ok request_id=c02c96f4-d15a-4b08-9b8d-aed134351c0e run_id=01KDTGYBG84HC5E566JBY9WGZW
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
[ok] create run: type=t2i run_id=01KDTGZV3JW55HM2CT811N5Y0J request_id=40408e70-9623-44c5-b04c-672f5c56c213
[ok] refresh run: run_id=01KDTGZV3JW55HM2CT811N5Y0J
[ok] create run: type=i2i run_id=01KDTGZVBBQX39ZC4FERS4MDMQ request_id=a7ff32f1-22f8-4166-8b5e-ff021e825bd7
[ok] refresh run: run_id=01KDTGZVBBQX39ZC4FERS4MDMQ
[ok] create run: type=t2v run_id=01KDTGZVHXVXK6Z3SM7B9JHC15 request_id=0088a3a4-6b29-4f66-9c08-158be144cd8a
[ok] refresh run: run_id=01KDTGZVHXVXK6Z3SM7B9JHC15
[ok] create run: type=i2v run_id=01KDTGZVR7Q9X1PCTYYYRZB85D request_id=c446af1b-4d89-40e7-8f25-6024db6a28ee
[ok] refresh run: run_id=01KDTGZVR7Q9X1PCTYYYRZB85D
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
[ok] override missing reason rejected; error envelope ok; request_id=c6078ff7-5e05-432b-928a-d179888b9c7e
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
[ok] request_id sample: tmp/_out_gate_ac_003.txt:request_id=40408e70-9623-44c5-b04c-672f5c56c213
[ok] e2e happy path passed
[ok] shots list returns items+page with required keys
[ok] shots detail returns shot + linked_refs summary
[ok] creating link works and appears in linked_refs
[ok] deleting link uses tombstone semantics and effective view is updated
[ok] /openapi.json reachable
[ok] /shots renders (http=200)
[ok] picked shot_id: 00363326BCB248A5B341B04BDF3CE2A6
[ok] /shots/:shot_id renders (http=200)
[ok] link created link_id=32EC8CD68A59470783F68B10A38F9ED3
[ok] link removed (tombstone semantics)
```

## request_id samples (run 1)
```text
tmp/_out_gate_ac_003.txt:request_id=40408e70-9623-44c5-b04c-672f5c56c213
tmp/_out_gate_ac_003.txt:request_id=a7ff32f1-22f8-4166-8b5e-ff021e825bd7
tmp/_out_gate_ac_003.txt:request_id=0088a3a4-6b29-4f66-9c08-158be144cd8a
tmp/_out_gate_ac_003.txt:request_id=c446af1b-4d89-40e7-8f25-6024db6a28ee
tmp/_out_gate_ac_004.txt:request_id=c6078ff7-5e05-432b-928a-d179888b9c7e
```

## Raw logs
- tmp/_out_gate_*
