from __future__ import annotations

import json
import os
import sqlite3
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

DEFAULT_DATABASE_URL = "sqlite:///./data/app.db"
_CROCKFORD32 = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"


def _encode_crockford(value: int, length: int) -> str:
    chars: List[str] = []
    for _ in range(length):
        chars.append(_CROCKFORD32[value & 31])
        value >>= 5
    return "".join(reversed(chars))


def new_ulid() -> str:
    # 48-bit time (ms) + 80-bit randomness
    ms = int(time.time() * 1000) & ((1 << 48) - 1)
    rnd = int.from_bytes(os.urandom(10), "big")
    v = (ms << 80) | rnd
    return _encode_crockford(v, 26)


def _now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _sqlite_path_from_url(url: str) -> str:
    if not url.startswith("sqlite:"):
        raise ValueError(f"Only sqlite supported for now, got DATABASE_URL={url!r}")
    if url.startswith("sqlite:////"):
        return url[len("sqlite:////") - 1 :]  # keep leading '/'
    if url.startswith("sqlite:///"):
        return url[len("sqlite:///") :]
    if url.startswith("sqlite://"):
        return url[len("sqlite://") :]
    raise ValueError(f"Unrecognized sqlite DATABASE_URL format: {url!r}")


def _connect() -> sqlite3.Connection:
    url = os.getenv("DATABASE_URL", DEFAULT_DATABASE_URL)
    path = _sqlite_path_from_url(url)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


def _table_info(conn: sqlite3.Connection, table: str) -> Dict[str, Dict[str, Any]]:
    out: Dict[str, Dict[str, Any]] = {}
    rows = conn.execute(f"PRAGMA table_info({table});").fetchall()
    for r in rows:
        out[r["name"]] = {
            "type": (r["type"] or "").upper(),
            "notnull": int(r["notnull"]),
            "dflt_value": r["dflt_value"],
            "pk": int(r["pk"]),
        }
    return out


def _table_exists(conn: sqlite3.Connection, table: str) -> bool:
    row = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        (table,),
    ).fetchone()
    return row is not None


def _primary_key_name(cols: Dict[str, Dict[str, Any]]) -> Optional[str]:
    for name, info in cols.items():
        if int(info.get("pk", 0)) == 1:
            return name
    if "id" in cols:
        return "id"
    return None


def _fill_required(cols: Dict[str, Dict[str, Any]], base: Dict[str, Any]) -> Dict[str, Any]:
    data = dict(base)
    now = _now_iso()

    pk = _primary_key_name(cols)
    if pk and pk not in data:
        t = (cols.get(pk, {}).get("type") or "").upper()
        # if PK is integer, let DB autoincrement; otherwise generate ULID
        if "INT" not in t:
            data[pk] = new_ulid()

    # timestamps (only if NOT NULL and no default)
    for k in ("created_at", "updated_at", "submitted_at"):
        if k in cols and cols[k]["notnull"] == 1 and cols[k]["dflt_value"] is None and k not in data:
            data[k] = now

    # status default (only if required)
    if "status" in cols and cols["status"]["notnull"] == 1 and cols["status"]["dflt_value"] is None and "status" not in data:
        data["status"] = "queued"

    # final pass: NOT NULL w/o default and still missing
    for name, info in cols.items():
        if info["notnull"] != 1:
            continue
        if info["dflt_value"] is not None:
            continue
        if info["pk"] == 1:
            continue
        if name in data:
            continue

        t = info["type"]
        if name.endswith("_id"):
            data[name] = new_ulid()
        elif "INT" in t:
            data[name] = 0
        elif "REAL" in t or "FLOA" in t or "DOUB" in t:
            data[name] = 0.0
        else:
            data[name] = ""

    return data


def _insert(conn: sqlite3.Connection, table: str, row: Dict[str, Any]) -> str:
    cols = _table_info(conn, table)
    data = _fill_required(cols, row)

    keys = [k for k in data.keys() if k in cols]
    keys.sort()
    sql = f"INSERT INTO {table} ({','.join(keys)}) VALUES ({','.join(['?'] * len(keys))});"
    cur = conn.execute(sql, [data[k] for k in keys])

    pk = _primary_key_name(cols)
    if pk and pk in data:
        return str(data[pk])

    # fallback: lastrowid for integer PKs
    try:
        return str(cur.lastrowid)
    except Exception:
        return ""


def create_run(run_type: str, prompt_pack: Dict[str, Any]) -> Tuple[str, str, str]:
    """
    Append-only: creates PromptPack + Run as two INSERTs.
    Returns (run_id, prompt_pack_id, status)
    """
    conn = _connect()
    try:
        if not _table_exists(conn, "prompt_packs"):
            raise RuntimeError("DB missing table: prompt_packs")
        if not _table_exists(conn, "runs"):
            raise RuntimeError("DB missing table: runs")

        pp_cols = _table_info(conn, "prompt_packs")
        payload = json.dumps({"run_type": run_type, **(prompt_pack or {})}, ensure_ascii=False)

        pp_row: Dict[str, Any] = {}
        # put payload into first matching column
        for k in ("payload_json", "payload", "input_json", "input", "meta_json", "meta", "params_json", "params"):
            if k in pp_cols:
                pp_row[k] = payload
                break
        if "type" in pp_cols:
            pp_row["type"] = run_type
        if "kind" in pp_cols:
            pp_row["kind"] = "prompt_pack"

        prompt_pack_id = _insert(conn, "prompt_packs", pp_row)

        run_cols = _table_info(conn, "runs")
        run_row: Dict[str, Any] = {}

        # FK to prompt_pack (best-effort)
        for k in ("prompt_pack_id", "promptpack_id", "prompt_pack_ulid"):
            if k in run_cols:
                run_row[k] = prompt_pack_id
                break

        if "run_type" in run_cols:
            run_row["run_type"] = run_type
        if "type" in run_cols:
            run_row["type"] = run_type
        if "status" in run_cols:
            run_row["status"] = "queued"

        rr = json.dumps({"asset_ids": []}, ensure_ascii=False)
        for k in ("result_refs_json", "result_refs", "result_json", "result"):
            if k in run_cols:
                run_row[k] = rr
                break

        run_id = _insert(conn, "runs", run_row)

        conn.commit()
        return str(run_id), str(prompt_pack_id), "queued"
    finally:
        conn.close()




def update_run(
    run_id: str,
    *,
    status: Optional[str] = None,
    result_refs: Optional[Dict[str, Any]] = None,
) -> bool:
    """
    Best-effort UPDATE for runs table (P1 provider execution).
    - Does NOT change API shape.
    - Updates only columns that exist.
    Returns True if an UPDATE was attempted (i.e., had at least one field to set).
    """
    conn = _connect()
    try:
        if not _table_exists(conn, "runs"):
            raise RuntimeError("DB missing table: runs")

        cols = _table_info(conn, "runs")
        pk = _primary_key_name(cols)
        id_col = pk if pk else ("id" if "id" in cols else ("run_id" if "run_id" in cols else "id"))

        updates: Dict[str, Any] = {}

        if status is not None and "status" in cols:
            updates["status"] = status

        if result_refs is not None:
            rr_json = json.dumps(result_refs, ensure_ascii=False)
            for k in ("result_refs_json", "result_refs", "result_json", "result"):
                if k in cols:
                    updates[k] = rr_json
                    break

        # timestamps (best effort)
        if "updated_at" in cols:
            updates["updated_at"] = _now_iso()

        if not updates:
            return False

        keys = sorted(updates.keys())
        set_sql = ", ".join([f"{k}=?" for k in keys])
        sql = f"UPDATE runs SET {set_sql} WHERE {id_col}=?;"
        conn.execute(sql, [updates[k] for k in keys] + [run_id])
        conn.commit()
        return True
    finally:
        conn.close()


def get_run(run_id: str) -> Optional[Dict[str, Any]]:
    conn = _connect()
    try:
        if not _table_exists(conn, "runs"):
            raise RuntimeError("DB missing table: runs")

        cols = _table_info(conn, "runs")
        pk = _primary_key_name(cols)
        id_col = pk if pk else ("id" if "id" in cols else ("run_id" if "run_id" in cols else "id"))

        row = conn.execute(f"SELECT * FROM runs WHERE {id_col}=? LIMIT 1;", (run_id,)).fetchone()
        if row is None:
            return None

        prompt_pack_id = ""
        for k in ("prompt_pack_id", "promptpack_id", "prompt_pack_ulid"):
            if k in row.keys() and row[k] is not None:
                prompt_pack_id = str(row[k])
                break

        created_at = None
        for k in ("created_at", "submitted_at"):
            if k in row.keys():
                created_at = row[k]
                break

        status = str(row["status"]) if "status" in row.keys() and row["status"] is not None else ""

        result_refs: Dict[str, Any] = {}
        for k in ("result_refs_json", "result_refs", "result_json", "result"):
            if k in row.keys() and row[k]:
                try:
                    result_refs = json.loads(row[k])
                except Exception:
                    result_refs = {}
                break


        # overlay: latest run_events (append-only transitions)
        ev = _get_latest_run_event(conn, str(row[id_col]))
        if ev:
            if ev.get('status'):
                status = str(ev['status'])
            if isinstance(ev.get('result_refs'), dict):
                result_refs = ev['result_refs']

        return {
            "run_id": str(row[id_col]),
            "prompt_pack_id": prompt_pack_id,
            "status": status,
            "created_at": str(created_at) if created_at is not None else None,
            "result_refs": result_refs if isinstance(result_refs, dict) else {},
        }
    finally:
        conn.close()


def _ensure_run_events_table(conn: sqlite3.Connection) -> None:
    """
    Append-only event log for Run status transitions & results (P1 ProviderAdapter).
    This avoids UPDATE on runs table (runs is append-only).
    """
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS run_events (
            event_id TEXT PRIMARY KEY,
            run_id TEXT NOT NULL,
            status TEXT NOT NULL,
            result_refs_json TEXT,
            request_id TEXT,
            created_at TEXT NOT NULL
        );
        """
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_run_events_run_id_created_at ON run_events(run_id, created_at);"
    )


def append_run_event(
    run_id: str,
    *,
    status: str,
    result_refs: Optional[Dict[str, Any]] = None,
    request_id: Optional[str] = None,
) -> str:
    """
    Append-only insert of a run event.
    Returns event_id.
    """
    conn = _connect()
    try:
        _ensure_run_events_table(conn)
        event_id = new_ulid()
        now = _now_iso()
        rr_json = None
        if result_refs is not None:
            rr_json = json.dumps(result_refs, ensure_ascii=False)
        conn.execute(
            "INSERT INTO run_events (event_id, run_id, status, result_refs_json, request_id, created_at) VALUES (?,?,?,?,?,?);",
            (event_id, run_id, status, rr_json, request_id or "", now),
        )
        conn.commit()
        return event_id
    finally:
        conn.close()


def _get_latest_run_event(conn: sqlite3.Connection, run_id: str) -> Optional[Dict[str, Any]]:
    """
    Read latest event for run_id (best-effort).
    Returns {status, result_refs} or None.
    """
    try:
        _ensure_run_events_table(conn)
        row = conn.execute(
            "SELECT status, result_refs_json, created_at FROM run_events WHERE run_id=? ORDER BY created_at DESC LIMIT 1;",
            (run_id,),
        ).fetchone()
        if row is None:
            return None
        rr: Dict[str, Any] = {}
        if "result_refs_json" in row.keys() and row["result_refs_json"]:
            try:
                rr = json.loads(row["result_refs_json"])
            except Exception:
                rr = {}
        return {"status": row["status"], "result_refs": rr if isinstance(rr, dict) else {}}
    except Exception:
        # If anything goes wrong, do not break GET /runs/{id}.
        return None



# =========================
# v1.1 Batch-2C additions
# =========================

def _json_dumps(v: object) -> str:
    try:
        return json.dumps(v, ensure_ascii=False)
    except Exception:
        return "{}"


def _json_loads(s: str) -> Dict[str, Any]:
    try:
        if not s:
            return {}
        v = json.loads(s)
        return v if isinstance(v, dict) else {}
    except Exception:
        return {}


def _pick_first_present(cols: Dict[str, Dict[str, Any]], keys: Tuple[str, ...]) -> Optional[str]:
    for k in keys:
        if k in cols:
            return k
    return None


def _ensure_links_table(conn: sqlite3.Connection) -> None:
    if _table_exists(conn, "links"):
        return
    # degrade: do not create new tables in batch-2 (no migrations / no implicit DDL)
    raise RuntimeError("DB missing table: links")


def _insert_link(
    conn: sqlite3.Connection,
    *,
    src_type: str,
    src_id: str,
    dst_type: str,
    dst_id: str,
    relation: str,
    meta: Optional[Dict[str, Any]] = None,
) -> str:
    _ensure_links_table(conn)
    cols = _table_info(conn, "links")

    has_src_dst = ("src_type" in cols and "src_id" in cols and "dst_type" in cols and "dst_id" in cols)
    src_type_col = "src_type" if has_src_dst else "source_type"
    src_id_col = "src_id" if has_src_dst else "source_id"
    dst_type_col = "dst_type" if has_src_dst else "target_type"
    dst_id_col = "dst_id" if has_src_dst else "target_id"
    rel_col = "rel" if "rel" in cols else "relation"

    row: Dict[str, Any] = {}
    row[src_type_col] = src_type
    row[src_id_col] = src_id
    row[dst_type_col] = dst_type
    row[dst_id_col] = dst_id
    row[rel_col] = relation

    mj = _pick_first_present(cols, ("meta_json", "metadata_json", "extra_json"))
    if mj:
        row[mj] = _json_dumps(meta or {})

    # if pk column is NOT integer, _fill_required will generate ULID; still set if conventional keys exist
    for k in ("id", "link_id"):
        if k in cols and k not in row:
            row[k] = new_ulid()

    return _insert(conn, "links", row)


def _get_provider_profile_row(conn: sqlite3.Connection, provider_profile_id: str) -> Optional[Dict[str, Any]]:
    if not _table_exists(conn, "provider_profiles"):
        return None
    cols = _table_info(conn, "provider_profiles")
    pk = _primary_key_name(cols)
    id_col = pk if pk else ("id" if "id" in cols else None)
    if not id_col:
        return None
    row = conn.execute(f"SELECT * FROM provider_profiles WHERE {id_col}=?", (provider_profile_id,)).fetchone()
    if not row:
        return None
    return dict(row)


def resolve_provider_profile(override_provider_profile_id: Optional[str]) -> Dict[str, Any]:
    """
    v1.1 Batch-2C:
    selection: override > global default > fallback (latest usable)
    scrubbed rows must NOT be used.
    Returns: {resolved_id, snapshot:{id,name,provider_type,has_config}}
    """
    conn = _connect()
    try:
        if not _table_exists(conn, "provider_profiles"):
            raise ValueError("provider_profile_required")

        cols = _table_info(conn, "provider_profiles")
        pk = _primary_key_name(cols)
        id_col = pk if pk else ("id" if "id" in cols else "id")

        def is_scrubbed(row: Dict[str, Any]) -> bool:
            name = str(row.get("name") or "")
            if name.startswith("(scrubbed)"):
                return True
            cj = row.get("config_json")
            if cj is None:
                return True
            if isinstance(cj, str) and cj.strip() == "":
                return True
            return False

        def snapshot(r: Dict[str, Any]) -> Dict[str, Any]:
            return {
                "id": str(r.get(id_col) or ""),
                "name": str(r.get("name") or ""),
                "provider_type": str(r.get("provider_type") or ""),
                "has_config": bool(str(r.get("config_json") or "").strip()),
            }

        # 1) override
        if override_provider_profile_id:
            row = conn.execute(f"SELECT * FROM provider_profiles WHERE {id_col}=?", (override_provider_profile_id,)).fetchone()
            if not row:
                raise ValueError("provider_profile_not_found")
            r = dict(row)
            if is_scrubbed(r):
                raise ValueError("provider_profile_deleted")
            snap = snapshot(r)
            if not snap["id"]:
                raise ValueError("provider_profile_not_found")
            return {"resolved_id": snap["id"], "snapshot": snap}

        # 2) global default (if column exists)
        if "is_global_default" in cols:
            row = conn.execute(
                "SELECT * FROM provider_profiles WHERE is_global_default=1 ORDER BY updated_at DESC, created_at DESC LIMIT 1"
            ).fetchone()
            if row:
                r = dict(row)
                if not is_scrubbed(r):
                    snap = snapshot(r)
                    if snap["id"]:
                        return {"resolved_id": snap["id"], "snapshot": snap}

        # 3) fallback: latest usable
        row = conn.execute(
            "SELECT * FROM provider_profiles ORDER BY updated_at DESC, created_at DESC LIMIT 50"
        ).fetchall()
        for rr in row:
            r = dict(rr)
            if is_scrubbed(r):
                continue
            snap = snapshot(r)
            if snap["id"]:
                return {"resolved_id": snap["id"], "snapshot": snap}

        raise ValueError("provider_profile_required")
    finally:
        conn.close()


def _get_character_row(conn: sqlite3.Connection, character_id: str) -> Optional[Dict[str, Any]]:
    if not _table_exists(conn, "characters"):
        return None
    cols = _table_info(conn, "characters")
    pk = _primary_key_name(cols)
    id_col = pk if pk else ("id" if "id" in cols else None)
    if not id_col:
        return None
    row = conn.execute(f"SELECT * FROM characters WHERE {id_col}=?", (character_id,)).fetchone()
    return dict(row) if row else None


def _get_ref_set_row(conn: sqlite3.Connection, ref_set_id: str) -> Optional[Dict[str, Any]]:
    if not _table_exists(conn, "character_ref_sets"):
        return None
    cols = _table_info(conn, "character_ref_sets")
    pk = _primary_key_name(cols)
    id_col = pk if pk else ("id" if "id" in cols else None)
    if not id_col:
        return None
    row = conn.execute(f"SELECT * FROM character_ref_sets WHERE {id_col}=?", (ref_set_id,)).fetchone()
    return dict(row) if row else None


def resolve_characters(characters: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    2C.2/2C.5: if provided, must have exactly one primary in router.
    Here we resolve ref_set:
    - use provided character_ref_set_id OR character.active_ref_set_id
    - enforce ownership
    - enforce status=confirmed (quality choice for v1.1 trace stability)
    Returns list of {character_id,is_primary,resolved_ref_set_id}
    """
    if not characters:
        return []

    conn = _connect()
    try:
        out: List[Dict[str, Any]] = []
        for c in characters:
            cid = str(c.get("character_id") or "").strip()
            if not cid:
                raise ValueError("character_not_found")
            crow = _get_character_row(conn, cid)
            if not crow:
                raise ValueError("character_not_found")

            ref_set_id = (c.get("character_ref_set_id") or "").strip()
            if not ref_set_id:
                ref_set_id = str(crow.get("active_ref_set_id") or "").strip()
                if not ref_set_id:
                    raise ValueError("active_ref_set_missing")

            rs = _get_ref_set_row(conn, ref_set_id)
            if not rs:
                raise ValueError("ref_set_not_found")

            owner = str(rs.get("character_id") or "")
            if owner != cid:
                raise ValueError("invalid_ref_set_owner")

            st = str(rs.get("status") or "")
            if st != "confirmed":
                raise ValueError("ref_set_not_confirmed")

            out.append(
                {
                    "character_id": cid,
                    "is_primary": bool(c.get("is_primary")),
                    "resolved_ref_set_id": ref_set_id,
                }
            )
        return out
    finally:
        conn.close()


def create_run_v11(
    *,
    run_type: str,
    prompt_pack: Dict[str, Any],
    override_provider_profile_id: Optional[str],
    characters: List[Dict[str, Any]],
    inputs: Dict[str, Any],
) -> Tuple[str, str, str, Dict[str, Any]]:
    """
    v1.1 create:
    - PromptPack append-only snapshot (AC-008 lock already validated in router)
    - Run append-only insert with input_json evidence:
      {resolved_provider_profile_id, provider_profile_snapshot, characters_resolved, inputs}
    - Links (2C.5 relationship_lock):
      run -> prompt_pack uses_prompt_pack
      run -> character uses_character (0..N)
      run -> character_ref_set uses_character_ref_set (0..N)
      run -> provider_profile uses_provider_profile (optional but recommended)
    Returns: (run_id, prompt_pack_id, status, evidence_input_json_dict)
    """
    pp_lock = dict(prompt_pack or {})

    # resolve provider + characters
    provider = resolve_provider_profile(override_provider_profile_id)
    resolved_chars = resolve_characters(characters)

    evidence: Dict[str, Any] = {
        "run_type": run_type,
        "resolved_provider_profile_id": provider.get("resolved_id"),
        "provider_profile_snapshot": provider.get("snapshot") or {},
        "characters": resolved_chars,
        "inputs": inputs or {},
    }

    conn = _connect()
    try:
        if not _table_exists(conn, "prompt_packs"):
            raise RuntimeError("DB missing table: prompt_packs")
        if not _table_exists(conn, "runs"):
            raise RuntimeError("DB missing table: runs")

        # ---- prompt_packs
        pp_cols = _table_info(conn, "prompt_packs")

        payload = dict(pp_lock)
        payload["run_type"] = run_type
        payload_json = _json_dumps(payload)

        pp_row: Dict[str, Any] = {}
        # put payload into first matching column
        k_payload = _pick_first_present(pp_cols, ("content", "payload_json", "payload", "input_json", "input", "meta_json", "meta", "params_json", "params"))
        if k_payload:
            pp_row[k_payload] = payload_json
        # digest (best-effort)
        if "digest" in pp_cols and "digest" not in pp_row:
            try:
                import hashlib
                pp_row["digest"] = hashlib.sha256(payload_json.encode("utf-8")).hexdigest()
            except Exception:
                pass
        if "type" in pp_cols:
            pp_row["type"] = run_type
        if "kind" in pp_cols:
            pp_row["kind"] = "prompt_pack"

        prompt_pack_id = _insert(conn, "prompt_packs", pp_row)

        # ---- runs
        run_cols = _table_info(conn, "runs")
        run_row: Dict[str, Any] = {}

        # FK to prompt_pack (best-effort)
        for k in ("prompt_pack_id", "promptpack_id", "prompt_pack_ulid"):
            if k in run_cols:
                run_row[k] = prompt_pack_id
                break

        if "run_type" in run_cols:
            run_row["run_type"] = run_type
        if "type" in run_cols:
            run_row["type"] = run_type
        if "status" in run_cols:
            run_row["status"] = "queued"

        # evidence into run input json (best-effort)
        k_in = _pick_first_present(run_cols, ("input_json", "input", "meta_json", "meta", "payload_json", "payload", "params_json", "params"))
        if k_in:
            run_row[k_in] = _json_dumps(evidence)

        # resolved provider_profile_id (best-effort)
        for k in ("provider_profile_id", "resolved_provider_profile_id"):
            if k in run_cols:
                run_row[k] = str(provider.get("resolved_id") or "")
                break

        rr = _json_dumps({"asset_ids": []})
        for k in ("result_refs_json", "result_refs", "result_json", "result"):
            if k in run_cols:
                run_row[k] = rr
                break

        run_id = _insert(conn, "runs", run_row)

        # ---- links (relationship_lock)
        try:
            _insert_link(conn, src_type="run", src_id=str(run_id), dst_type="prompt_pack", dst_id=str(prompt_pack_id), relation="uses_prompt_pack")
            # provider profile (recommended)
            if provider.get("resolved_id"):
                _insert_link(conn, src_type="run", src_id=str(run_id), dst_type="provider_profile", dst_id=str(provider["resolved_id"]), relation="uses_provider_profile")
            # characters + ref_sets
            for c in resolved_chars:
                _insert_link(conn, src_type="run", src_id=str(run_id), dst_type="character", dst_id=str(c["character_id"]), relation="uses_character", meta={"is_primary": bool(c.get("is_primary"))})
                _insert_link(conn, src_type="run", src_id=str(run_id), dst_type="character_ref_set", dst_id=str(c["resolved_ref_set_id"]), relation="uses_character_ref_set", meta={"character_id": str(c["character_id"]), "is_primary": bool(c.get("is_primary"))})
        except Exception:
            # safe degrade: do not fail run creation if links schema differs; router/gates can catch via evidence
            pass

        conn.commit()
        return str(run_id), str(prompt_pack_id), "queued", evidence
    finally:
        conn.close()


def _create_asset_from_storage_ref(conn: sqlite3.Connection, *, storage_ref: str, request_id: str) -> Optional[str]:
    if not _table_exists(conn, "assets"):
        return None
    cols = _table_info(conn, "assets")

    # normalize storage path
    sp = storage_ref
    if storage_ref.startswith("storage://"):
        sp = storage_ref[len("storage://") :].lstrip("/")

    row: Dict[str, Any] = {}
    if "type" in cols:
        row["type"] = "artifact"
    if "storage_path" in cols:
        row["storage_path"] = sp
    if "mime_type" in cols:
        row["mime_type"] = "application/json"

    # preserve request_id if schema supports
    for k in ("request_id", "created_request_id"):
        if k in cols:
            row[k] = request_id or ""
            break

    asset_id = _insert(conn, "assets", row)
    return str(asset_id) if asset_id else None


def link_produced_asset(run_id: str, *, asset_id: str, request_id: str) -> None:
    conn = _connect()
    try:
        if not _table_exists(conn, "links"):
            return
        _insert_link(conn, src_type="run", src_id=str(run_id), dst_type="asset", dst_id=str(asset_id), relation="produced_asset", meta={"request_id": request_id or ""})
        conn.commit()
    finally:
        conn.close()


def get_prompt_pack_payload(prompt_pack_id: str) -> Dict[str, Any]:
    conn = _connect()
    try:
        if not _table_exists(conn, "prompt_packs"):
            return {}
        cols = _table_info(conn, "prompt_packs")
        pk = _primary_key_name(cols)
        id_col = pk if pk else ("id" if "id" in cols else None)
        if not id_col:
            return {}

        row = conn.execute(f"SELECT * FROM prompt_packs WHERE {id_col}=?", (prompt_pack_id,)).fetchone()
        if not row:
            return {}

        d = dict(row)
        k_payload = _pick_first_present(cols, ("content", "payload_json", "payload", "input_json", "input", "meta_json", "meta", "params_json", "params"))
        payload = _json_loads(str(d.get(k_payload) or "")) if k_payload else {}
        return payload
    finally:
        conn.close()
