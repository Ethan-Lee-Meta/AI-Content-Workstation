from __future__ import annotations

import json
import os
import re
import sqlite3
import hashlib
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


# =========
# Config
# =========

def _repo_root() -> Path:
    p = Path(__file__).resolve()
    for parent in p.parents:
        if (parent / "apps").exists():
            return parent
    return p.parents[5]


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _new_id() -> str:
    return uuid.uuid4().hex.upper()


def _db_path(repo: Path) -> Path:
    return Path(os.getenv("APP_DB_PATH", str(repo / "data" / "app.db")))


def _storage_root(repo: Path) -> Path:
    return Path(os.getenv("APP_STORAGE_ROOT", str(repo / "data" / "storage")))


def _exports_root(repo: Path) -> Path:
    return Path(os.getenv("APP_EXPORTS_ROOT", str(repo / "data" / "exports")))


def _sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _json_safe(v: Any) -> Any:
    if isinstance(v, (datetime,)):
        return v.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
    return v


# =========
# sqlite helpers
# =========

def _conn(repo: Path) -> sqlite3.Connection:
    dbp = _db_path(repo)
    c = sqlite3.connect(str(dbp))
    c.row_factory = sqlite3.Row
    return c


def _list_tables(c: sqlite3.Connection) -> List[str]:
    rows = c.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").fetchall()
    return [r["name"] for r in rows]


def _table_info(c: sqlite3.Connection, table: str) -> List[Dict[str, Any]]:
    rows = c.execute(f"PRAGMA table_info({table})").fetchall()
    return [dict(r) for r in rows]


def _table_cols(c: sqlite3.Connection, table: str) -> List[str]:
    return [r["name"] for r in _table_info(c, table)]


def _pick_pk(c: sqlite3.Connection, table: str) -> str:
    info = _table_info(c, table)
    pks = [r["name"] for r in info if int(r.get("pk") or 0) == 1]
    if len(pks) == 1:
        return pks[0]
    # fallback conventional
    cols = {r["name"] for r in info}
    if "id" in cols:
        return "id"
    if "asset_id" in cols:
        return "asset_id"
    return "id"


def _select_rows(
    c: sqlite3.Connection,
    table: str,
    where_sql: str = "",
    params: Optional[List[Any]] = None,
) -> List[Dict[str, Any]]:
    params = params or []
    sql = f"SELECT * FROM {table}"
    if where_sql:
        sql += " WHERE " + where_sql
    rows = c.execute(sql, params).fetchall()
    out: List[Dict[str, Any]] = []
    for r in rows:
        d = dict(r)
        out.append({k: _json_safe(v) for k, v in d.items()})
    return out


_TABLE_ALIASES: Dict[str, List[str]] = {
    "assets": ["assets", "asset"],
    "links": ["links", "link"],
    "prompt_packs": ["prompt_packs", "prompt_pack"],
    "runs": ["runs", "run"],
    "reviews": ["reviews", "review"],
    "run_events": ["run_events", "run_event"],
    "projects": ["projects", "project"],
    "series": ["series"],
    "shots": ["shots", "shot"],
}


def _resolve_tables(existing: List[str]) -> Dict[str, str]:
    s = set(existing)
    resolved: Dict[str, str] = {}
    for logical, cands in _TABLE_ALIASES.items():
        for cand in cands:
            if cand in s:
                resolved[logical] = cand
                break
    return resolved


# =========
# blobs copy (best-effort)
# =========

def _try_copy_blob(
    storage_root: Path,
    export_blobs_root: Path,
    asset_row: Dict[str, Any],
    warnings: List[str],
) -> List[Dict[str, Any]]:
    candidates = []
    for key in ["storage_ref", "storage_uri", "storage_path", "path", "file_path", "blob_path"]:
        v = asset_row.get(key)
        if isinstance(v, str) and v.strip():
            candidates.append((key, v.strip()))

    results: List[Dict[str, Any]] = []
    if not candidates:
        return results

    for key, ref in candidates:
        src: Optional[Path] = None
        if ref.startswith("storage://"):
            rel = ref[len("storage://") :].lstrip("/").replace("\\", "/")
            src = storage_root / rel
        elif re.match(r"^[A-Za-z]:[\\/]", ref) or ref.startswith("/"):
            src = Path(ref)
        else:
            # treat as relative; prefer storage_root if it looks like a storage-relative path
            src = (storage_root / ref) if ("storage" not in ref.lower()) else (_repo_root() / ref)

        try:
            if src is None or (not src.exists()) or (not src.is_file()):
                warnings.append(f"blob_missing: key={key} ref={ref}")
                results.append({"src_ref": ref, "ok": False, "error": "missing"})
                continue

            aid = str(asset_row.get("id") or asset_row.get("asset_id") or "UNKNOWN")
            dst_rel = Path("blobs") / aid / src.name
            dst = export_blobs_root / aid / src.name
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(src.read_bytes())

            results.append(
                {
                    "src_ref": ref,
                    "dst_relpath": str(dst_rel).replace("\\", "/"),
                    "size_bytes": dst.stat().st_size,
                    "sha256": _sha256_file(dst),
                    "ok": True,
                }
            )
        except Exception as e:
            warnings.append(f"blob_copy_failed: key={key} ref={ref} err={type(e).__name__}")
            results.append({"src_ref": ref, "ok": False, "error": type(e).__name__})

    return results


# =========
# Export API
# =========

def export_create(payload: Dict[str, Any]) -> Tuple[Dict[str, Any], Dict[str, Any]]:
    repo = _repo_root()
    exports_root = _exports_root(repo)
    exports_root.mkdir(parents=True, exist_ok=True)

    export_id = _new_id()
    export_dir = exports_root / export_id
    export_dir.mkdir(parents=True, exist_ok=False)

    created_at = _now_iso()
    warnings: List[str] = []

    bundle: Dict[str, Any] = {"tables": {}, "resolved_table_names": {}}
    counts: Dict[str, int] = {}
    assets_preview: List[Dict[str, Any]] = []
    blobs: List[Dict[str, Any]] = []

    include_deleted = bool(payload.get("include_deleted", False))
    include_binaries = bool(payload.get("include_binaries", True))

    with _conn(repo) as c:
        existing = _list_tables(c)
        resolved = _resolve_tables(existing)
        bundle["resolved_table_names"] = resolved

        if "assets" not in resolved:
            raise RuntimeError("missing_assets_table")

        t_assets = resolved["assets"]
        pk = _pick_pk(c, t_assets)
        cols_assets = set(_table_cols(c, t_assets))

        where = []
        params: List[Any] = []

        asset_ids = payload.get("asset_ids")
        if isinstance(asset_ids, list) and asset_ids:
            where.append(f"{pk} IN ({','.join(['?'] * len(asset_ids))})")
            params.extend(asset_ids)

        if (not include_deleted) and ("deleted_at" in cols_assets):
            where.append("deleted_at IS NULL")

        where_sql = " AND ".join(where)
        rows_assets = _select_rows(c, t_assets, where_sql, params)
        bundle["tables"][t_assets] = rows_assets
        counts["assets"] = len(rows_assets)

        for r in rows_assets[:200]:
            assets_preview.append(
                {
                    "id": r.get("id") or r.get("asset_id"),
                    "type": r.get("type"),
                    "mime": r.get("mime_type") or r.get("mime"),
                    "size_bytes": r.get("size_bytes"),
                }
            )

        # links (best-effort filtered by selected assets)
        if "links" in resolved:
            t_links = resolved["links"]
            cols_links = set(_table_cols(c, t_links))

            selected_ids = [x.get("id") or x.get("asset_id") for x in rows_assets]
            selected_ids = [x for x in selected_ids if isinstance(x, str) and x]

            link_rows: List[Dict[str, Any]] = []
            if selected_ids:
                candidate_cols = [cc for cc in ["src_id", "dst_id", "from_id", "to_id", "asset_id"] if cc in cols_links]
                if candidate_cols:
                    parts = []
                    params2: List[Any] = []
                    for cc in candidate_cols:
                        parts.append(f"{cc} IN ({','.join(['?'] * len(selected_ids))})")
                        params2.extend(selected_ids)
                    link_rows = _select_rows(c, t_links, " OR ".join(parts), params2)
                else:
                    link_rows = _select_rows(c, t_links)
            else:
                link_rows = _select_rows(c, t_links)

            bundle["tables"][t_links] = link_rows
            counts["links"] = len(link_rows)

        # evidence chain & hierarchy tables: dump all rows (P1 minimum)
        for logical in ["prompt_packs", "runs", "reviews", "run_events", "projects", "series", "shots"]:
            if logical in resolved:
                t = resolved[logical]
                rows = _select_rows(c, t)
                bundle["tables"][t] = rows
                counts[logical] = len(rows)

    # copy blobs (best-effort)
    if include_binaries:
        sr = _storage_root(repo)
        blobs_root = export_dir / "blobs"
        # only attempt for first 200 assets to keep export bounded
        for a in bundle["tables"].get(resolved["assets"], [])[:200]:
            blobs.extend(_try_copy_blob(sr, blobs_root, a, warnings))
    else:
        warnings.append("include_binaries=false (no blobs copied)")

    bundle_path = export_dir / "bundle.json"
    manifest_path = export_dir / "manifest.json"
    export_path = export_dir / "export.json"

    bundle_path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2), encoding="utf-8")

    manifest = {
        "manifest_version": "1.0",
        "export_id": export_id,
        "created_at": created_at,
        "selection": {
            "asset_ids": payload.get("asset_ids"),
            "include_deleted": include_deleted,
            "include_binaries": include_binaries,
            "include_proxies": bool(payload.get("include_proxies", False)),
            "note": payload.get("note"),
        },
        "tables": {
            "resolved_table_names": resolved,
            "row_counts": counts,
        },
        "assets_preview": assets_preview,
        "blobs": blobs,
        "warnings": warnings,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    record = {
        "export_id": export_id,
        "status": "completed",
        "created_at": created_at,
        "package_path": str(export_dir).replace("\\", "/"),
        "manifest_path": str(manifest_path).replace("\\", "/"),
        "bundle_path": str(bundle_path).replace("\\", "/"),
        "counts": counts,
        "warnings": warnings,
    }
    export_path.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")

    return record, manifest


def export_get(export_id: str) -> Dict[str, Any]:
    repo = _repo_root()
    export_path = _exports_root(repo) / export_id / "export.json"
    if not export_path.exists():
        raise FileNotFoundError("export_not_found")
    return json.loads(export_path.read_text(encoding="utf-8"))


def export_manifest(export_id: str) -> Dict[str, Any]:
    repo = _repo_root()
    p = _exports_root(repo) / export_id / "manifest.json"
    if not p.exists():
        raise FileNotFoundError("manifest_not_found")
    return json.loads(p.read_text(encoding="utf-8"))


# =========
# Imports API (sqlite3, append-only, new id mapping)
# =========

def _imports_root(repo: Path) -> Path:
    return Path(os.getenv("APP_IMPORTS_ROOT", str(repo / "data" / "imports")))


def _dedupe_row_for_retry(row: Dict[str, Any], suffix: str, cols: set) -> Dict[str, Any]:
    r = dict(row)
    for k in ["slug", "name", "title", "code"]:
        if k in cols and isinstance(r.get(k), str) and r.get(k):
            r[k] = f"{r[k]}-{suffix}"
            return r
    return r


def _table_pk_type(c: sqlite3.Connection, table: str, pk: str) -> str:
    info = _table_info(c, table)
    for r in info:
        if r.get("name") == pk:
            return str(r.get("type") or "")
    return ""


def import_create(payload: Dict[str, Any]) -> Dict[str, Any]:
    repo = _repo_root()
    imports_root = _imports_root(repo)
    imports_root.mkdir(parents=True, exist_ok=True)

    import_id = _new_id()
    import_dir = imports_root / import_id
    import_dir.mkdir(parents=True, exist_ok=False)

    created_at = _now_iso()
    warnings: List[str] = []

    export_id = payload.get("export_id")
    package_path = payload.get("package_path")

    if export_id:
        package_dir = _exports_root(repo) / str(export_id)
    elif package_path:
        package_dir = Path(str(package_path))
    else:
        raise ValueError("missing_source (export_id or package_path)")

    bundle_path = package_dir / "bundle.json"
    manifest_path = package_dir / "manifest.json"

    if not bundle_path.exists():
        raise FileNotFoundError("bundle_not_found")
    bundle = json.loads(bundle_path.read_text(encoding="utf-8"))
    tables: Dict[str, List[Dict[str, Any]]] = bundle.get("tables") or {}
    if not isinstance(tables, dict) or not tables:
        raise ValueError("invalid_bundle_tables")

    create_new_ids = bool(payload.get("create_new_ids", True))

    counts: Dict[str, int] = {}
    idmap: Dict[str, str] = {}

    with _conn(repo) as c:
        existing = set(_list_tables(c))

        # deterministic insert order for better FK mapping
        ordered = [
            "projects", "project",
            "series",
            "assets", "asset",
            "prompt_packs", "prompt_pack",
            "runs", "run",
            "reviews", "review",
            "shots", "shot",
            "links", "link",
            "run_events", "run_event",
        ]

        def norm_name(name: str) -> str:
            return name.lower()

        # build ordered table list: first those in ordered list if present; then the rest
        table_names = list(tables.keys())
        picked: List[str] = []
        for o in ordered:
            for t in table_names:
                if norm_name(t) == o and t not in picked:
                    picked.append(t)
        for t in table_names:
            if t not in picked:
                picked.append(t)

        try:
            c.execute("BEGIN")
            for t in picked:
                if t not in existing:
                    warnings.append(f"skip_missing_table: {t}")
                    continue

                rows = tables.get(t) or []
                if not isinstance(rows, list) or not rows:
                    counts[t] = 0
                    continue

                cols_list = _table_cols(c, t)
                cols = set(cols_list)
                pk = _pick_pk(c, t)
                pk_type = _table_pk_type(c, t, pk).upper()
                pk_is_int = ("INT" in pk_type) or ("INTEGER" in pk_type)

                inserted = 0
                for row in rows:
                    if not isinstance(row, dict):
                        continue
                    r2 = {k: row.get(k) for k in row.keys() if k in cols}

                    # assign new PK (string IDs) when safe
                    old_pk = None
                    if create_new_ids and (pk in cols) and (not pk_is_int):
                        old_pk = r2.get(pk)
                        if isinstance(old_pk, str) and old_pk:
                            new_pk = _new_id()
                            r2[pk] = new_pk
                            idmap[old_pk] = new_pk

                    # rewrite *_id fields using global idmap
                    for k, v in list(r2.items()):
                        if not (isinstance(v, str) and v):
                            continue
                        if k.endswith("_id") or k in ("src_id", "dst_id", "from_id", "to_id"):
                            if v in idmap:
                                r2[k] = idmap[v]

                    if not r2:
                        continue

                    cols_ins = list(r2.keys())
                    vals = [r2[k] for k in cols_ins]
                    ph = ",".join(["?"] * len(cols_ins))
                    sql = f"INSERT INTO {t} ({','.join(cols_ins)}) VALUES ({ph})"

                    try:
                        c.execute(sql, vals)
                        inserted += 1
                    except sqlite3.IntegrityError:
                        # best-effort retry with deduped human-readable fields
                        suffix = f"import{import_id[:6].lower()}"
                        r3 = _dedupe_row_for_retry(r2, suffix, cols)
                        if r3 != r2:
                            cols_ins2 = list(r3.keys())
                            vals2 = [r3[k] for k in cols_ins2]
                            ph2 = ",".join(["?"] * len(cols_ins2))
                            sql2 = f"INSERT INTO {t} ({','.join(cols_ins2)}) VALUES ({ph2})"
                            try:
                                c.execute(sql2, vals2)
                                inserted += 1
                                warnings.append(f"dedup_retry_ok: table={t}")
                            except Exception as e2:
                                warnings.append(f"insert_skip: table={t} err={type(e2).__name__}")
                        else:
                            warnings.append(f"insert_skip: table={t} err=IntegrityError")
                    except Exception as e:
                        warnings.append(f"insert_skip: table={t} err={type(e).__name__}")

                counts[t] = inserted

            c.execute("COMMIT")
            status = "completed"
        except Exception as e:
            try:
                c.execute("ROLLBACK")
            except Exception:
                pass
            status = "failed"
            warnings.append(f"import_failed: {type(e).__name__}")

    record = {
        "import_id": import_id,
        "status": status,
        "created_at": created_at,
        "source": {
            "export_id": export_id,
            "package_path": str(package_dir).replace("\\", "/"),
            "bundle_path": str(bundle_path).replace("\\", "/"),
            "manifest_path": str(manifest_path).replace("\\", "/") if manifest_path.exists() else None,
        },
        "counts": counts,
        "id_map_size": len(idmap),
        "warnings": warnings,
    }

    (import_dir / "import.json").write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
    return record


def import_get(import_id: str) -> Dict[str, Any]:
    repo = _repo_root()
    p = _imports_root(repo) / import_id / "import.json"
    if not p.exists():
        raise FileNotFoundError("import_not_found")
    return json.loads(p.read_text(encoding="utf-8"))
