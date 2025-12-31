"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { apiFetch, listAssets, pickPreviewUrl } from "../_lib/api";

function int(v, d) {
  const n = Number.parseInt(String(v ?? ""), 10);
  return Number.isNaN(n) ? d : n;
}

function isDeleted(a) {
  // tolerant across possible backend shapes
  if (a?.deleted === true) return true;
  if (a?.is_deleted === true) return true;
  if (a?.deleted_at) return true;
  if (a?.deletedAt) return true;
  return false;
}

function idOf(a) {
  return String(a?.asset_id || a?.id || a?.uuid || "unknown");
}

function pickType(a) {
  return String(a?.type || a?.asset_type || "unknown").toLowerCase();
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

export default function TrashClient() {
  const router = useRouter();
  const sp = useSearchParams();

  const limit = Math.min(200, Math.max(1, int(sp.get("limit"), 20)));
  const offset = Math.max(0, int(sp.get("offset"), 0));

  const [loading, setLoading] = useState(false);
  const [items, setItems] = useState([]);
  const [page, setPage] = useState({ limit, offset, total: 0, has_more: false });
  const [lastRid, setLastRid] = useState("—");
  const [errEnv, setErrEnv] = useState(null);

  const [emptyBusy, setEmptyBusy] = useState(false);
  const [emptyReport, setEmptyReport] = useState(null);

  function pushParams(next) {
    const p = new URLSearchParams(sp.toString());
    Object.entries(next).forEach(([k, v]) => {
      if (v === "" || v === null || v === undefined) p.delete(k);
      else p.set(k, String(v));
    });
    router.push(`/trash?${p.toString()}`);
  }

  async function load() {
    setLoading(true);
    setErrEnv(null);

    // Trash view requirement: based on include_deleted=true
    const r = await listAssets({ limit, offset, include_deleted: true });
    if (!r.ok) {
      setLastRid(r.request_id || r.error_envelope?.request_id || "—");
      setErrEnv(r.error_envelope || null);
      setItems([]);
      setPage({ limit, offset, total: 0, has_more: false });
      setLoading(false);
      return;
    }

    const d = r.data || {};
    const raw = Array.isArray(d.items) ? d.items : [];
    setLastRid(r.request_id || "—");
    setItems(raw);
    setPage(d.page || { limit, offset, total: 0, has_more: false });
    setLoading(false);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [limit, offset]);

  const deletedOnly = useMemo(() => {
    return (items || []).filter(isDeleted);
  }, [items]);

  async function emptyTrash() {
    const ok = window.confirm(
      "Empty trash will permanently remove deleted assets from storage.\n\nThis action is HIGH RISK and cannot be undone.\n\nContinue?"
    );
    if (!ok) return;

    setEmptyBusy(true);
    setEmptyReport(null);
    setErrEnv(null);

    const r = await apiFetch("/trash/empty", { method: "POST" });
    const rid = r.request_id || r.error_envelope?.request_id || "—";
    setLastRid(rid);

    if (!r.ok) {
      setErrEnv(r.error_envelope || null);
      setEmptyReport({ ok: false, request_id: rid });
      setEmptyBusy(false);
      return;
    }

    // show audit feedback (at least: success + request_id; include response keys if any)
    const data = r.data || {};
    setEmptyReport({
      ok: true,
      request_id: rid,
      response_keys: Object.keys(data || {}),
    });

    setEmptyBusy(false);
    load();
  }

  return (
    <div className="grid" data-testid="trash-view">
      <section className="card" style={{ gridColumn: "span 12" }}>
        <h1 style={{ margin: 0 }}>Trash</h1>
        <p className="cardHint">
          P1: list deleted assets using <span className="mono">include_deleted=true</span>; empty trash requires confirmation; show request_id for audit.
        </p>
        <div className="kv" style={{ marginTop: 8 }}>
          <span>limit</span><b className="mono">{String(limit)}</b>
          <span>offset</span><b className="mono">{String(offset)}</b>
          <span>last_request_id</span><b className="mono">{String(lastRid)}</b>
          <span>deleted_items_on_page</span><b className="mono">{String(deletedOnly.length)}</b>
        </div>

        <div style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "center", marginTop: 10 }}>
          <button className="btn" onClick={load} disabled={loading}>
            {loading ? "Loading..." : "Refresh"}
          </button>
          <button className="btn" data-testid="trash-empty-btn" onClick={emptyTrash} disabled={emptyBusy}>
            {emptyBusy ? "Emptying..." : "Empty trash"}
          </button>
          {emptyReport ? (
            <span className="badge" data-testid="trash-empty-report">
              ok: <span className="mono">{String(!!emptyReport.ok)}</span> • request_id:{" "}
              <span className="mono">{String(emptyReport.request_id || "—")}</span>
              {emptyReport.ok ? (
                <>
                  {" "}• response_keys: <span className="mono">{(emptyReport.response_keys || []).join(",") || "—"}</span>
                </>
              ) : null}
            </span>
          ) : null}
        </div>
      </section>

      <section className="card" style={{ gridColumn: "span 12" }} data-testid="trash-list">
        <h2 className="cardTitle">Deleted Assets</h2>
        <ErrorPanel env={errEnv} />

        {!errEnv && deletedOnly.length === 0 ? (
          <div className="badge" data-testid="empty-state">
            {loading ? "Loading..." : "No deleted assets found on this page."}
          </div>
        ) : null}

        <div className="grid" style={{ marginTop: 10 }}>
          {deletedOnly.map((a) => {
            const id = idOf(a);
            const t = pickType(a);
            const preview = pickPreviewUrl(a);
            const isVideo = t === "video";

            return (
              <div key={id} style={{ gridColumn: "span 4" }}>
                <div className="card" style={{ padding: 12 }}>
                  <div style={{ display: "flex", justifyContent: "space-between", gap: 10, alignItems: "center" }}>
                    <div style={{ minWidth: 0 }}>
                      <div className="mono" style={{ fontSize: 12, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{id}</div>
                      <div style={{ marginTop: 6, display: "flex", gap: 8 }}>
                        <span className="badge mono">{t || "unknown"}</span>
                        <span className="badge mono">deleted</span>
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
    </div>
  );
}
