# Shots UI Evidence (BATCH-7 / STEP-130)

## 1) Core task interaction layers (<= 3)

Core task: **Select shot → Associate asset → Save/confirm**

- Layer 1: `/shots` list page  
  - user selects a `shot_id` by clicking row link

- Layer 2: `/shots/:shot_id` detail page  
  - shows `shot` object + `linked_refs` summary buckets

- Layer 3: On the same detail page, `Link orchestration` panel  
  - user inputs `{dst_type, dst_id, rel}` and clicks **Add link**
  - request goes through `/api_proxy/shots/:shot_id/links` → backend `POST /shots/{shot_id}/links`

No modal / drawer / nested navigation is required for the core task.

## 2) Link (SSOT) compliance

- All relationships shown in UI come from backend-computed `linked_refs` (derived from `links` table).
- UI does not cache/override relationships locally.

## 3) Write orchestration capability / downgrade rule

- Add link is supported via backend `POST /shots/{shot_id}/links`.
- Unlink requires `link_id` (backend `DELETE /shots/{shot_id}/links/{link_id}` writes a tombstone link).
- If the backend detail payload does **not** expose raw link rows (and `link_id`), the UI cannot safely offer unlink for existing refs.
  - In that case, UI behavior is **add-only** and shows a note explaining that unlink needs `link_id` exposure (BATCH-6 / CR candidate).

This document is the evidence artifact required by BATCH-7 exit criteria.
