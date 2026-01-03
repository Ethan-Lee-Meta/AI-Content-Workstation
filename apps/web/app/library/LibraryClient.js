"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { apiFetch, listAssets, pickPreviewUrl, softDeleteAsset } from "../_lib/api";

function int(v, d) {
  const n = Number.parseInt(String(v ?? ""), 10);
  return Number.isNaN(n) ? d : n;
}

function ErrorPanel({ env }) {
  if (!env) return null;
  return (
    <div className="notice" data-testid="error-panel">
      <div style={{ fontWeight: 700, marginBottom: 6 }}>Request failed</div>
      <div className="kv">
        <span>error</span><b className="mono">{String(env.error || "—")}</b>
        <span>message</span><b>{String(env.message || "—")}</b>
        <span>request_id</span><b className="mono">{String(env.request_id || "—")}</b>
        <span>details</span><b className="mono" style={{ whiteSpace: "pre-wrap" }}>{String(env.details || "—")}</b>
      </div>
    </div>
  );
}

export default function LibraryClient() {
  const router = useRouter();
  const sp = useSearchParams();

  const limit = Math.min(200, Math.max(1, int(sp.get("limit"), 20)));
  const offset = Math.max(0, int(sp.get("offset"), 0));

  const [type, setType] = useState(sp.get("type") || "all");
  const [q, setQ] = useState(sp.get("q") || "");
  const [includeDeleted, setIncludeDeleted] = useState(sp.get("include_deleted") === "true");

  const [loading, setLoading] = useState(false);
  const [items, setItems] = useState([]);
  const [page, setPage] = useState({ limit, offset, total: 0, has_more: false });
  const [lastRid, setLastRid] = useState("—");
  const [errEnv, setErrEnv] = useState(null);

  // STEP-105: bulk selection + bulk soft delete
  const [selected, setSelected] = useState({});
  const [bulkBusy, setBulkBusy] = useState(false);
  const [bulkReport, setBulkReport] = useState(null);

  function pushParams(next) {
    const p = new URLSearchParams(sp.toString());
    Object.entries(next).forEach(([k, v]) => {
      if (v === "" || v === null || v === undefined) p.delete(k);
      else p.set(k, String(v));
    });
    router.push(`/library?${p.toString()}`);
  }

  function idOf(a) {
    return String(a?.asset_id || a?.id || a?.uuid || "unknown");
  }

  function pickType(a) {
    return String(a?.type || a?.asset_type || "unknown").toLowerCase();
  }

  async function load() {
    setLoading(true);
    setErrEnv(null);

    const r = await listAssets({ limit, offset, include_deleted: includeDeleted });
    if (!r.ok) {
      setLastRid(r.request_id || r.error_envelope?.request_id || "—");
      setErrEnv(r.error_envelope || null);
      setItems([]);
      setPage({ limit, offset, total: 0, has_more: false });
      setLoading(false);
      return;
    }

    const d = r.data || {};
    setLastRid(r.request_id || "—");
    setItems(Array.isArray(d.items) ? d.items : []);
    setPage(d.page || { limit, offset, total: 0, has_more: false });
    setLoading(false);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [limit, offset, includeDeleted]);

  const filtered = useMemo(() => {
    const qq = q.trim().toLowerCase();
    return (items || []).filter((a) => {
      const id = idOf(a).toLowerCase();
      const t = pickType(a);
      if (type !== "all" && t !== type) return false;
      if (qq && !id.includes(qq)) return false;
      return true;
    });
  }, [items, type, q]);

  const selectedIds = useMemo(() => {
    return Object.keys(selected || {}).filter((k) => selected[k]);
  }, [selected]);

  const selectedCount = selectedIds.length;

  function setOneSelected(id, checked) {
    setSelected((m) => ({ ...(m || {}), [id]: !!checked }));
  }

  function clearSelection() {
    setSelected({});
    setBulkReport(null);
  }

  function selectAllOnPage() {
    const next = {};
    filtered.forEach((a) => {
      const id = idOf(a);
      if (id && id !== "unknown") next[id] = true;
    });
    setSelected(next);
    setBulkReport(null);
  }

  async function bulkSoftDelete() {
    const ids = selectedIds.slice(0);
    if (ids.length === 0) return;

    setBulkBusy(true);
    setBulkReport(null);
    setErrEnv(null);

    let ok = 0;
    let fail = 0;
    let last = "—";
    const okSet = new Set();
    let firstFailEnv = null;

    for (const id of ids) {
      const r = await softDeleteAsset(id);
      last = r.request_id || r.error_envelope?.request_id || last;

      if (r.ok) {
        ok += 1;
        okSet.add(id);
      } else {
        fail += 1;
        if (!firstFailEnv) firstFailEnv = r.error_envelope || null;
      }
    }

    // optimistic remove successes from current list (default list excludes deleted)
    if (okSet.size > 0) {
      setItems((prev) => (Array.isArray(prev) ? prev.filter((a) => !okSet.has(idOf(a))) : prev));
    }

    // keep failed selected for retry; clear if all ok
    if (fail === 0) setSelected({});
    else {
      setSelected((prev) => {
        const next = {};
        ids.forEach((id) => {
          if (!okSet.has(id) && prev?.[id]) next[id] = true;
        });
        return next;
      });
    }

    setLastRid(last);
    setBulkReport({ requested: ids.length, ok, fail, last_request_id: last });

    if (firstFailEnv) setErrEnv(firstFailEnv);

    setBulkBusy(false);

    // if all succeeded, refresh from server truth
    if (fail === 0) load();
  }

  return (
    <div className="grid">
      <section className="card" style={{ gridColumn: "span 12" }}>
        <h1 style={{ margin: 0 }}>Library</h1>
        <p className="cardHint">
          AC-001: list image+video assets (single entry), pagination, open detail; error shows request_id.
        </p>
        <div className="kv" style={{ marginTop: 8 }}>
          <span>limit</span><b className="mono">{String(limit)}</b>
          <span>offset</span><b className="mono">{String(offset)}</b>
          <span>last_request_id</span><b className="mono">{String(lastRid)}</b>
        </div>
      </section>

      <section className="card" style={{ gridColumn: "span 12" }} data-testid="filters-bar">
        <h2 className="cardTitle">FiltersBar</h2>
        <div style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "center" }}>
          <label className="badge" style={{ display: "inline-flex", gap: 8, alignItems: "center" }}>
            type
            <select
              value={type}
              onChange={(e) => setType(e.target.value)}
              style={{ background: "transparent", border: "none", color: "var(--text)" }}
            >
              <option value="all">all</option>
              <option value="image">image</option>
              <option value="video">video</option>
            </select>
          </label>

          <label className="badge" style={{ display: "inline-flex", gap: 8, alignItems: "center" }}>
            include_deleted
            <input
              type="checkbox"
              checked={includeDeleted}
              onChange={(e) => setIncludeDeleted(e.target.checked)}
            />
          </label>

          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="search by id (client-side)"
            style={{
              padding: "9px 10px",
              borderRadius: 12,
              background: "rgba(18,24,38,.9)",
              border: "1px solid rgba(36,48,69,.9)",
              color: "var(--text)",
              minWidth: 240
            }}
          />

          <button
            className="btn"
            onClick={() => pushParams({ type: type === "all" ? "" : type, q: q.trim() ? q.trim() : "", include_deleted: includeDeleted ? "true" : "" })}
          >
            Apply
          </button>
          <button className="btn" onClick={load} disabled={loading}>{loading ? "Loading..." : "Refresh"}</button>
        </div>
      </section>

      <section className="card" style={{ gridColumn: "span 12" }} data-testid="asset-grid">
        <h2 className="cardTitle">AssetGrid</h2>
        <ErrorPanel env={errEnv} />

        {!errEnv && filtered.length === 0 ? (
          <div className="badge" data-testid="empty-state">{loading ? "Loading..." : "Empty list."}</div>
        ) : null}

        <div className="grid" style={{ marginTop: 10 }}>
          {filtered.map((a) => {
            const id = idOf(a);
            const t = pickType(a);
            const preview = pickPreviewUrl(a);
            const isVideo = t === "video";
            const checked = !!selected?.[id];

            return (
              <div key={id} style={{ gridColumn: "span 4" }}>
                <div className="card" style={{ padding: 12 }}>
                  <div style={{ display: "flex", justifyContent: "space-between", gap: 10, alignItems: "center" }}>
                    <div style={{ display: "flex", gap: 10, alignItems: "center", minWidth: 0 }}>
                      <input
                        data-testid="bulk-item-checkbox"
                        type="checkbox"
                        checked={checked}
                        onChange={(e) => setOneSelected(id, e.target.checked)}
                        aria-label={`select ${id}`}
                      />
                      <div style={{ minWidth: 0 }}>
                        <div className="mono" style={{ fontSize: 12, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{id}</div>
                        <div style={{ marginTop: 6, display: "flex", gap: 8 }}>
                          <span className="badge mono">{t || "unknown"}</span>
                        </div>
                      </div>
                    </div>
                    <Link className="btn" href={`/assets/${encodeURIComponent(id)}`} prefetch={false}>Open</Link>
                  </div>

                  <div style={{ marginTop: 10 }}>
                    {preview ? (
                      isVideo ? (
                        <video src={preview} controls style={{ width: "100%", borderRadius: 12, border: "1px solid rgba(36,48,69,.9)" }} />
                      ) : (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={preview} alt={id} style={{ width: "100%", borderRadius: 12, border: "1px solid rgba(36,48,69,.9)" }} />
                      )
                    ) : (
                      <div style={{ height: 120, borderRadius: 12, border: "1px dashed rgba(36,48,69,.9)", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--muted)" }}>
                        No preview URL
                      </div>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        <div style={{ marginTop: 12, display: "flex", justifyContent: "space-between", gap: 10, alignItems: "center" }}>
          <div className="badge">
            total: <span className="mono">{String(page?.total ?? 0)}</span> • has_more: <span className="mono">{String(!!page?.has_more)}</span>
          </div>
          <div style={{ display: "flex", gap: 10 }}>
            <button className="btn" onClick={() => pushParams({ offset: Math.max(0, offset - limit), limit })} disabled={loading || offset <= 0}>Prev</button>
            <button className="btn" onClick={() => pushParams({ offset: offset + limit, limit })} disabled={loading || !page?.has_more}>Next</button>
          </div>
        </div>
      </section>

      <section className="card" style={{ gridColumn: "span 12" }} data-testid="bulk-action-bar">
        <h2 className="cardTitle">BulkActionBar</h2>

        <div style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "center" }}>
          <span className="badge" data-testid="bulk-selected-count">
            selected: <span className="mono">{String(selectedCount)}</span>
          </span>

          <button className="btn" data-testid="bulk-select-all" onClick={selectAllOnPage} disabled={bulkBusy || filtered.length === 0}>
            Select all (this page)
          </button>

          <button className="btn" data-testid="bulk-clear-selection" onClick={clearSelection} disabled={bulkBusy || selectedCount === 0}>
            Clear selection
          </button>

          <button className="btn" data-testid="bulk-soft-delete" onClick={bulkSoftDelete} disabled={bulkBusy || selectedCount === 0}>
            {bulkBusy ? "Deleting..." : "Soft delete selected"}
          </button>

          {bulkReport ? (
            <span className="badge" data-testid="bulk-report">
              requested: <span className="mono">{String(bulkReport.requested)}</span> • ok: <span className="mono">{String(bulkReport.ok)}</span> • fail: <span className="mono">{String(bulkReport.fail)}</span> • last_request_id: <span className="mono">{String(bulkReport.last_request_id || "—")}</span>
            </span>
          ) : null}
        </div>

        <p className="cardHint" style={{ marginTop: 10 }}>
          P1: bulk select + bulk soft delete. Failure must show error envelope + request_id (see ErrorPanel).
        </p>
      </section>
    </div>
  );
}
