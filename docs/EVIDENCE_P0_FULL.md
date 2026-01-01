# P0 FULL Regression Evidence

- Generated at (UTC): 2025-12-31T16:26:08Z
- Branch: dev/batch8-provider-adapter-p1
- HEAD: 9dc078cb70dab8dc4d8836caba4bdffad94d07c0
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
[ok] flag OFF -> POST /runs ok run_id=01KDTKKM6VSN0K578PG3ZQX489 status=queued
[ok] flag OFF -> GET ok status=queued result_refs_keys=[]
[ok] on -> json ok
[ok] flag ON -> POST /runs ok run_id=01KDTKKNRX6HQF7CZ0AYRWE05S status=succeeded
[ok] flag ON -> GET ok status=succeeded refs_count=1
[ok] artifact exists: ./data/storage\runs\01KDTKKNRX6HQF7CZ0AYRWE05S\result.json
[ok] forced fail -> error_envelope ok request_id=95afba86-f203-4701-bb24-72483c19e1a2 run_id=01KDTKKQT1N3ZHQN6KAV85NN23
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
[ok] picked asset_id=EA89F56409A04B87B5CDA7FA64D605C2
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
[ok] create run: type=t2i run_id=01KDTKMZ9CJAXHNRMECF6ZRH3V request_id=94570dad-7e7f-406b-a577-2a489eebb67a
[ok] refresh run: run_id=01KDTKMZ9CJAXHNRMECF6ZRH3V
[ok] create run: type=i2i run_id=01KDTKMZGP5ST95NQND02200QX request_id=fa49da17-9e5b-4640-9bc6-86734e6c4f3c
[ok] refresh run: run_id=01KDTKMZGP5ST95NQND02200QX
[ok] create run: type=t2v run_id=01KDTKMZQS9AMWDWMX03JP88BY request_id=ccb9539f-9708-4f6f-9761-e5f35e3b9c82
[ok] refresh run: run_id=01KDTKMZQS9AMWDWMX03JP88BY
[ok] create run: type=i2v run_id=01KDTKMZXKDBNRVKT4TE9Z87ZG request_id=e7c04825-5684-4ee1-a74c-8346ec113ea9
[ok] refresh run: run_id=01KDTKMZXKDBNRVKT4TE9Z87ZG
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
[ok] override missing reason rejected; error envelope ok; request_id=2b255ca8-4174-4ee7-b2f7-eb5020fcf5c9
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
[ok] request_id sample: tmp/_out_gate_ac_003.txt:request_id=94570dad-7e7f-406b-a577-2a489eebb67a
[ok] e2e happy path passed
[ok] shots list returns items+page with required keys
[ok] shots detail returns shot + linked_refs summary
[ok] creating link works and appears in linked_refs
[ok] deleting link uses tombstone semantics and effective view is updated
[ok] /openapi.json reachable
[ok] /shots renders (http=200)
[ok] picked shot_id: 00363326BCB248A5B341B04BDF3CE2A6
[ok] /shots/:shot_id renders (http=200)
[ok] link created link_id=1BC19897051840E787F802B5E5649758
[ok] link removed (tombstone semantics)
```

## request_id samples (run 1)
```text
tmp/_out_gate_ac_003.txt:request_id=94570dad-7e7f-406b-a577-2a489eebb67a
tmp/_out_gate_ac_003.txt:request_id=fa49da17-9e5b-4640-9bc6-86734e6c4f3c
tmp/_out_gate_ac_003.txt:request_id=ccb9539f-9708-4f6f-9761-e5f35e3b9c82
tmp/_out_gate_ac_003.txt:request_id=e7c04825-5684-4ee1-a74c-8346ec113ea9
tmp/_out_gate_ac_004.txt:request_id=2b255ca8-4174-4ee7-b2f7-eb5020fcf5c9
```

## Raw logs
- tmp/_out_gate_*
