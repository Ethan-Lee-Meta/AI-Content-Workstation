#!/usr/bin/env bash
set -euo pipefail

echo "== gate_shots_api: start =="

API_BASE="${API_BASE:-http://127.0.0.1:7000}"
DB_URL="${DATABASE_URL:-sqlite:///./data/app.db}"

PY="./apps/api/.venv/Scripts/python.exe"
if [ ! -x "$PY" ]; then PY="python"; fi

API_BASE="$API_BASE" DB_URL="$DB_URL" "$PY" - <<'PY'
import os, sqlite3, uuid, json
from datetime import datetime, timezone
from urllib import request as ureq
from urllib import parse as uparse
from urllib.error import HTTPError, URLError

API_BASE = os.getenv("API_BASE", "http://127.0.0.1:7000").rstrip("/")
DB_URL = os.getenv("DB_URL", "sqlite:///./data/app.db")

def db_path(url: str) -> str:
    if url.startswith("sqlite:///"):
        return url[len("sqlite:///"):]
    if url.startswith("sqlite://"):
        return url[len("sqlite://"):]
    raise RuntimeError(f"unsupported DATABASE_URL: {url}")

def utcnow_iso():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00","Z")

def must(cond, msg):
    if not cond:
        raise RuntimeError(msg)

def http_json(method: str, url: str, *, params=None, body=None, headers=None, timeout=10):
    if params:
        qs = uparse.urlencode(params)
        url = url + ("&" if "?" in url else "?") + qs
    data = None
    h = {}
    if headers:
        h.update(headers)
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        h.setdefault("Content-Type", "application/json")
    req = ureq.Request(url, data=data, method=method, headers=h)
    try:
        with ureq.urlopen(req, timeout=timeout) as resp:
            status = getattr(resp, "status", 200)
            resp_headers = dict(resp.headers.items())
            raw = resp.read()
            text = raw.decode("utf-8", errors="replace") if raw else ""
            j = json.loads(text) if text else None
            return status, resp_headers, text, j
    except HTTPError as e:
        raw = e.read()
        text = raw.decode("utf-8", errors="replace") if raw else ""
        try:
            j = json.loads(text) if text else None
        except Exception:
            j = None
        return e.code, dict(e.headers.items()), text, j
    except URLError as e:
        raise RuntimeError(f"network error: {e}") from e

def get(url, **kw):
    rid = uuid.uuid4().hex.upper()
    h = kw.pop("headers", {}) or {}
    h["X-Request-Id"] = rid
    return rid, http_json("GET", url, headers=h, **kw)

def post(url, **kw):
    rid = uuid.uuid4().hex.upper()
    h = kw.pop("headers", {}) or {}
    h["X-Request-Id"] = rid
    return rid, http_json("POST", url, headers=h, **kw)

def delete(url, **kw):
    rid = uuid.uuid4().hex.upper()
    h = kw.pop("headers", {}) or {}
    h["X-Request-Id"] = rid
    return rid, http_json("DELETE", url, headers=h, **kw)

# ---- seed DB rows (shot + asset) ----
path = db_path(DB_URL)
con = sqlite3.connect(path, check_same_thread=False)
con.row_factory = sqlite3.Row
cur = con.cursor()

row = cur.execute("SELECT id FROM shots ORDER BY created_at DESC LIMIT 1").fetchone()
if row is None:
    shot_id = uuid.uuid4().hex.upper()
    cur.execute(
        "INSERT INTO shots (id, project_id, series_id, name, created_at) VALUES (?, ?, ?, ?, ?)",
        (shot_id, None, None, "gate-shot", utcnow_iso()),
    )
    con.commit()
else:
    shot_id = row["id"]

arow = cur.execute("SELECT id FROM assets WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 1").fetchone()
if arow is None:
    asset_id = uuid.uuid4().hex.upper()
    cur.execute(
        "INSERT INTO assets (id, kind, uri, mime_type, sha256, width, height, duration_ms, meta_json, created_at, deleted_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (asset_id, "image", None, None, None, None, None, None, None, utcnow_iso(), None),
    )
    con.commit()
else:
    asset_id = arow["id"]

con.close()

# ---- openapi reachable ----
rid, (st, hdr, txt, j) = get(f"{API_BASE}/openapi.json")
must(st == 200, f"openapi not reachable status={st} rid={rid} body={txt[:200]}")

# ---- list ----
rid, (st, hdr, txt, j) = get(f"{API_BASE}/shots", params={"offset": 0, "limit": 10})
must(st == 200, f"shots list failed status={st} rid={rid} body={txt}")
must(isinstance(j, dict) and "items" in j and "page" in j, "shots list missing items/page")
for k in ["limit","offset","total","has_more"]:
    must(k in j["page"], f"shots list page missing key={k}")
must(any(it.get("shot_id") == shot_id for it in j["items"]), "seeded shot not present in list")

# ---- detail ----
rid, (st, hdr, txt, d) = get(f"{API_BASE}/shots/{shot_id}")
must(st == 200, f"shots detail failed status={st} rid={rid} body={txt}")
must("shot" in d and "linked_refs" in d, "shots detail missing shot/linked_refs")

# ---- error envelope for missing ----
rid, (st, hdr, txt, e) = get(f"{API_BASE}/shots/NO_SUCH_SHOT_ID")
must(st == 404, f"missing shot should 404, got {st} rid={rid}")
for k in ["error","message","request_id","details"]:
    must(isinstance(e, dict) and k in e, f"error envelope missing key={k}")
must(e["request_id"], "error envelope request_id empty")

# ---- create link shot -> asset ----
rid, (st, hdr, txt, o) = post(
    f"{API_BASE}/shots/{shot_id}/links",
    body={"dst_type": "asset", "dst_id": asset_id, "rel": "refs"},
)
must(st == 200, f"create link failed status={st} rid={rid} body={txt}")
link_id = (o or {}).get("link_id")
must(link_id, "create link missing link_id")

# ---- detail should include asset ref ----
rid, (st, hdr, txt, d) = get(f"{API_BASE}/shots/{shot_id}")
must(st == 200, f"detail after link failed status={st} rid={rid} body={txt}")
assets = (d.get("linked_refs") or {}).get("assets") or []
must(any(a.get("asset_id") == asset_id for a in assets), "linked asset not present in linked_refs.assets")

# ---- tombstone delete ----
rid, (st, hdr, txt, dd) = delete(f"{API_BASE}/shots/{shot_id}/links/{link_id}")
must(st == 200, f"delete(tombstone) failed status={st} rid={rid} body={txt}")
must((dd or {}).get("tombstone_link_id"), "tombstone missing tombstone_link_id")

# ---- asset should be removed in effective view ----
rid, (st, hdr, txt, d) = get(f"{API_BASE}/shots/{shot_id}")
must(st == 200, f"detail after tombstone failed status={st} rid={rid} body={txt}")
assets = (d.get("linked_refs") or {}).get("assets") or []
must(not any(a.get("asset_id") == asset_id for a in assets), "tombstoned link still effective")

print("[ok] shots list returns items+page with required keys")
print("[ok] shots detail returns shot + linked_refs summary")
print("[ok] creating link works and appears in linked_refs")
print("[ok] deleting link uses tombstone semantics and effective view is updated")
print("== gate_shots_api: passed ==")
PY
