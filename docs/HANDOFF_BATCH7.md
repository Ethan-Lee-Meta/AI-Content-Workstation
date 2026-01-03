# HANDOFF — BATCH-7 (PHASE-P1 / Shots Workbench UI)

## 0) Scope delivered
- Routes:
  - `/shots` list (pagination + optional filters: project_id/series_id)
  - `/shots/:shot_id` detail (shot info + linked refs summary)
- Relationship SSOT:
  - Linked refs displayed as backend-computed summary buckets (derived from Links SSOT)
  - Link orchestration UI panel present on detail page
- Error handling:
  - Any API failure surfaces error envelope body (if JSON) and visible `request_id`
- Interaction depth evidence:
  - See `docs/SHOTS_UI_EVIDENCE.md` (core task within <=3 layers)

## 1) Files changed / added
- `apps/web/app/shots/page.js`
- `apps/web/app/shots/[shot_id]/page.js`
- `apps/web/app/shots/[shot_id]/ShotLinksEditorClient.jsx`
- `apps/web/app/api_proxy/_lib.js`
- `apps/web/app/api_proxy/shots/[shot_id]/links/route.js`
- `apps/web/app/api_proxy/shots/[shot_id]/links/[link_id]/route.js`
- `scripts/gate_shots_ui.sh`
- `docs/SHOTS_UI_EVIDENCE.md`

## 2) Contract dependencies (BATCH-6)
- `GET /shots?offset&limit` returns `{ items, page{limit,offset,total,has_more} }`
- `GET /shots/{shot_id}` returns `{ shot, linked_refs, (optional) links[] }`
- Link orchestration (optional validation in gate):
  - `POST /shots/{shot_id}/links` (create)
  - `DELETE /shots/{shot_id}/links/{link_id}` (tombstone/unlink)
Notes:
- UI can always do “add link” via POST.
- “unlink existing ref” requires `link_id`. If backend does not expose `link_id` (either via create response or detail payload), unlink is add-only (UI displays a note).

## 3) Verification
Run:
- `bash scripts/gate_shots_ui.sh`

Expected:
- `[ok] /shots renders (http=200)`
- `[ok] picked shot_id: <...>`
- `[ok] /shots/:shot_id renders (http=200)`
- Optional: link add/remove exercised if at least one asset exists. Otherwise gate prints:
  - `[warn] no assets exist; skip link ops`

## 4) Next recommended follow-ups
- If unlink must be fully supported in UI:
  - ensure backend exposes `link_id` for existing refs (either in `GET /shots/{shot_id}` as `links[]` rows or dedicated link list endpoint), or ensure `POST` returns created `link_id`.
