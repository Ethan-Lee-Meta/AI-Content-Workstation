# P0 FULL Regression Evidence

- Generated at (UTC): 2025-12-31T05:48:11Z
- Branch: dev/batch5-ui-p1
- HEAD: b2b5d55147a8dee29e5a26fa5f926dcca470d63d
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
[ok] picked asset_id=E8307BDFB7544A658CFC3BF9B5A71516
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
[ok] create run: type=t2i run_id=01KDSF5AJ08CJH1SCNQBZ40HP4 request_id=c65e1316-2bea-48c0-9687-f1284becf82c
[ok] refresh run: run_id=01KDSF5AJ08CJH1SCNQBZ40HP4
[ok] create run: type=i2i run_id=01KDSF5AQFWDSHNT8TR04XV746 request_id=c681be62-286b-447b-bd26-ec2f8e2d16d7
[ok] refresh run: run_id=01KDSF5AQFWDSHNT8TR04XV746
[ok] create run: type=t2v run_id=01KDSF5AZR515TWBHDMSFBGJJE request_id=a7878eff-2b13-4828-9f27-79df76dfe481
[ok] refresh run: run_id=01KDSF5AZR515TWBHDMSFBGJJE
[ok] create run: type=i2v run_id=01KDSF5B5WTTBWJKYPD6CRV879 request_id=9b640d72-339e-4c0d-8799-fb074fe46ca6
[ok] refresh run: run_id=01KDSF5B5WTTBWJKYPD6CRV879
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
[ok] override missing reason rejected; error envelope ok; request_id=64aa962d-d969-49a7-81cf-b9a68414eed4
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
[ok] request_id sample: tmp/_out_gate_ac_003.txt:request_id=c65e1316-2bea-48c0-9687-f1284becf82c
[ok] e2e happy path passed
```

## request_id samples (run 1)
```text
tmp/_out_gate_ac_003.txt:request_id=c65e1316-2bea-48c0-9687-f1284becf82c
tmp/_out_gate_ac_003.txt:request_id=c681be62-286b-447b-bd26-ec2f8e2d16d7
tmp/_out_gate_ac_003.txt:request_id=a7878eff-2b13-4828-9f27-79df76dfe481
tmp/_out_gate_ac_003.txt:request_id=9b640d72-339e-4c0d-8799-fb074fe46ca6
tmp/_out_gate_ac_004.txt:request_id=64aa962d-d969-49a7-81cf-b9a68414eed4
```

## Raw logs
- tmp/_out_gate_*
