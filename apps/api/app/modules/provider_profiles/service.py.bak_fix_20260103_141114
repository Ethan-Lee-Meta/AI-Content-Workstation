from __future__ import annotations

import json
import os
import sqlite3
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from app.modules.runs.service import new_ulid

DEFAULT_DATABASE_URL = "sqlite:///./data/app.db"


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


def _table_exists(conn: sqlite3.Connection, table: str) -> bool:
    row = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        (table,),
    ).fetchone()
    return row is not None


def _columns(conn: sqlite3.Connection, table: str) -> List[str]:
    rows = conn.execute(f"PRAGMA table_info({table})").fetchall()
    return [r["name"] for r in rows]


def _safe_json_loads(s: Any) -> Dict[str, Any]:
    if not s:
        return {}
    if isinstance(s, dict):
        return s
    try:
        return json.loads(str(s))
    except Exception:
        return {}


def _redact_config(config: Dict[str, Any], policy: Dict[str, Any]) -> Dict[str, Any]:
    """
    Very small, deterministic redaction:
    - policy: {"redact_keys":[...]}
    - key match applies recursively on dict nodes
    """
    redact_keys = policy.get("redact_keys") or []
    if not isinstance(redact_keys, list):
        redact_keys = []

    def walk(v: Any) -> Any:
        if isinstance(v, dict):
            out: Dict[str, Any] = {}
            for k, vv in v.items():
                if k in redact_keys:
                    out[k] = "<redacted>"
                else:
                    out[k] = walk(vv)
            return out
        if isinstance(v, list):
            return [walk(x) for x in v]
        return v

    return walk(config) if isinstance(config, dict) else {}


def list_provider_types() -> List[Dict[str, Any]]:
    # 后端控制：最少包含 mock（当前 repo 已内置 mock provider）
    return [
        {
            "provider_type": "mock",
            "label": "Mock Provider",
            "config_hints": {
                "note": "用于本地验证与门禁；不依赖外部 API",
            },
            "secrets_hints": {
                "redact_keys_example": ["api_key", "token"],
            },
        }
    ]


def _row_to_profile(conn: sqlite3.Connection, r: sqlite3.Row, *, redact: bool) -> Dict[str, Any]:
    cols = r.keys()
    config = _safe_json_loads(r["config_json"] if "config_json" in cols else "{}")
    policy = _safe_json_loads(
        r["secrets_redaction_policy_json"] if "secrets_redaction_policy_json" in cols else "{}"
    )
    view_config = _redact_config(config, policy) if redact else config

    return {
        "id": str(r["id"]),
        "name": str(r["name"]),
        "provider_type": str(r["provider_type"]),
        "config": view_config if isinstance(view_config, dict) else {},
        "secrets_redaction_policy": policy if isinstance(policy, dict) else {},
        "is_global_default": bool(int(r["is_global_default"])) if "is_global_default" in cols else False,
        "created_at": str(r["created_at"]) if "created_at" in cols and r["created_at"] is not None else None,
        "updated_at": str(r["updated_at"]) if "updated_at" in cols and r["updated_at"] is not None else None,
    }


def list_provider_profiles(limit: int, offset: int) -> Tuple[List[Dict[str, Any]], int]:
    conn = _connect()
    try:
        if not _table_exists(conn, "provider_profiles"):
            raise RuntimeError("DB missing table: provider_profiles")

        total = conn.execute("SELECT COUNT(1) AS c FROM provider_profiles").fetchone()["c"]
        rows = conn.execute(
            "SELECT * FROM provider_profiles ORDER BY updated_at DESC, id DESC LIMIT ? OFFSET ?",
            (limit, offset),
        ).fetchall()
        items = [_row_to_profile(conn, r, redact=True) for r in rows]
        return items, int(total)
    finally:
        conn.close()


def get_provider_profile(profile_id: str, *, redact: bool = True) -> Optional[Dict[str, Any]]:
    conn = _connect()
    try:
        if not _table_exists(conn, "provider_profiles"):
            raise RuntimeError("DB missing table: provider_profiles")
        row = conn.execute(
            "SELECT * FROM provider_profiles WHERE id=? LIMIT 1",
            (profile_id,),
        ).fetchone()
        if row is None:
            return None
        return _row_to_profile(conn, row, redact=redact)
    finally:
        conn.close()


def get_global_default_provider_profile(*, redact: bool = False) -> Optional[Dict[str, Any]]:
    conn = _connect()
    try:
        if not _table_exists(conn, "provider_profiles"):
            return None
        row = conn.execute(
            "SELECT * FROM provider_profiles WHERE is_global_default=1 ORDER BY updated_at DESC LIMIT 1"
        ).fetchone()
        if row is None:
            return None
        return _row_to_profile(conn, row, redact=redact)
    finally:
        conn.close()


def _set_global_default(conn: sqlite3.Connection, profile_id: str) -> None:
    # 事务内：先清零再置 1，避免唯一约束冲突
    conn.execute("UPDATE provider_profiles SET is_global_default=0;")
    conn.execute(
        "UPDATE provider_profiles SET is_global_default=1, updated_at=? WHERE id=?;",
        (_now_iso(), profile_id),
    )


def create_provider_profile(
    *,
    name: str,
    provider_type: str,
    config: Dict[str, Any],
    secrets_redaction_policy: Dict[str, Any],
    set_global_default: bool,
) -> Dict[str, Any]:
    conn = _connect()
    try:
        if not _table_exists(conn, "provider_profiles"):
            raise RuntimeError("DB missing table: provider_profiles")

        pid = new_ulid()
        now = _now_iso()
        conn.execute(
            """
            INSERT INTO provider_profiles
            (id, name, provider_type, config_json, secrets_redaction_policy_json, is_global_default, created_at, updated_at)
            VALUES (?,?,?,?,?,?,?,?);
            """,
            (
                pid,
                name,
                provider_type,
                json.dumps(config or {}, ensure_ascii=False),
                json.dumps(secrets_redaction_policy or {}, ensure_ascii=False),
                0,
                now,
                now,
            ),
        )
        if set_global_default:
            _set_global_default(conn, pid)

        conn.commit()
        return get_provider_profile(pid, redact=True) or {"id": pid, "name": name, "provider_type": provider_type}
    finally:
        conn.close()


def patch_provider_profile(
    profile_id: str,
    *,
    name: Optional[str],
    config: Optional[Dict[str, Any]],
    secrets_redaction_policy: Optional[Dict[str, Any]],
    set_global_default: Optional[bool],
) -> Optional[Dict[str, Any]]:
    conn = _connect()
    try:
        if not _table_exists(conn, "provider_profiles"):
            raise RuntimeError("DB missing table: provider_profiles")

        row = conn.execute("SELECT * FROM provider_profiles WHERE id=? LIMIT 1;", (profile_id,)).fetchone()
        if row is None:
            return None

        updates: List[Tuple[str, Any]] = []
        if name is not None:
            updates.append(("name", name))
        if config is not None:
            updates.append(("config_json", json.dumps(config or {}, ensure_ascii=False)))
        if secrets_redaction_policy is not None:
            updates.append(
                ("secrets_redaction_policy_json", json.dumps(secrets_redaction_policy or {}, ensure_ascii=False))
            )

        # updated_at always on patch
        updates.append(("updated_at", _now_iso()))

        if updates:
            set_sql = ", ".join([f"{k}=?" for (k, _) in updates])
            conn.execute(f"UPDATE provider_profiles SET {set_sql} WHERE id=?;", [v for (_, v) in updates] + [profile_id])

        if set_global_default is True:
            _set_global_default(conn, profile_id)
        elif set_global_default is False:
            conn.execute(
                "UPDATE provider_profiles SET is_global_default=0, updated_at=? WHERE id=?;",
                (_now_iso(), profile_id),
            )

        conn.commit()
        return get_provider_profile(profile_id, redact=True)
    finally:
        conn.close()


def scrub_provider_profile(profile_id: str) -> Optional[Dict[str, Any]]:
    """
    delete → scrub（不硬删）：
    - config_json / secrets_redaction_policy_json 清空
    - is_global_default 置 0
    - name 打标（保留可追溯性）
    """
    conn = _connect()
    try:
        if not _table_exists(conn, "provider_profiles"):
            raise RuntimeError("DB missing table: provider_profiles")

        row = conn.execute("SELECT id FROM provider_profiles WHERE id=? LIMIT 1;", (profile_id,)).fetchone()
        if row is None:
            return None

        now = _now_iso()
        conn.execute(
            """
            UPDATE provider_profiles
               SET config_json=?,
                   secrets_redaction_policy_json=?,
                   is_global_default=0,
                   name=?,
                   updated_at=?
             WHERE id=?;
            """,
            (
                "{}",
                "{}",
                f"(scrubbed) {profile_id}",
                now,
                profile_id,
            ),
        )
        conn.commit()
        return get_provider_profile(profile_id, redact=True)
    finally:
        conn.close()
