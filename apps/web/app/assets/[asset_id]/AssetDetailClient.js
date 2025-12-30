"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { getAsset, pickPreviewUrl } from "../../_lib/api";

function normalizeId(a, fallback) {
  return String(a?.asset_id || a?.id || a?.uuid || fallback || "unknown");
}
function normalizeType(a) {
  return String(a?.type || a?.asset_type || "unknown").toLowerCase();
}
function normalizeStatus(a) {
  return String(a?.status || a?.state || "unknown");
}
function normalizeCreatedAt(a) {
  return String(a?.created_at || a?.createdAt || a?.ts || "");
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

function PreviewPanel({ asset }) {
  const t = normalizeType(asset);
  const preview = pickPreviewUrl(asset);
  const isVideo = t === "video";

  return (
    <section className="card" style={{ gridColumn: "span 7" }} data-testid="preview-panel">
      <h2 className="cardTitle">PreviewPanel</h2>
      <p className="cardHint">type: <span className="mono">{t}</span></p>

      {preview ? (
        isVideo ? (
          <video
            src={preview}
            controls
            style={{ width: "100%", borderRadius: 12, border: "1px solid rgba(36,48,69,.9)" }}
          />
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={preview}
            alt={normalizeId(asset, "asset")}
            style={{ width: "100%", borderRadius: 12, border: "1px solid rgba(36,48,69,.9)" }}
          />
        )
      ) : (
        <div
          style={{
            height: 220,
            borderRadius: 12,
            border: "1px dashed rgba(36,48,69,.9)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            color: "var(--muted)"
          }}
        >
          No preview URL (P0 placeholder)
        </div>
      )}
    </section>
  );
}

function MetadataPanel({ asset, assetId }) {
  const id = normalizeId(asset, assetId);
  const t = normalizeType(asset);
  const st = normalizeStatus(asset);
  const created = normalizeCreatedAt(asset);

  return (
    <section className="card" style={{ gridColumn: "span 5" }} data-testid="metadata-panel">
      <h2 className="cardTitle">MetadataPanel</h2>
      <p className="cardHint">Minimal required metadata for P0.</p>
      <div className="kv">
        <span>id</span><b className="mono">{id}</b>
        <span>type</span><b className="mono">{t}</b>
        <span>status</span><b className="mono">{st}</b>
        <span>created_at</span><b className="mono">{created || "—"}</b>
      </div>

      <div style={{ marginTop: 12 }}>
        <div className="cardHint">Raw keys preview (first 20 keys):</div>
        <pre style={{ margin: "8px 0 0 0", fontSize: 12, color: "var(--muted)", whiteSpace: "pre-wrap" }}>
          {asset ? JSON.stringify(Object.keys(asset).slice(0, 20), null, 2) : "—"}
        </pre>
      </div>
    </section>
  );
}

function TraceabilityPanel({ asset }) {
  const refs = useMemo(() => {
    if (!asset) return [];
    const keys = ["run_id", "prompt_id", "prompt_version_id", "series_id", "project_id", "links", "runs", "reviews"];
    const out = [];
    for (const k of keys) {
      if (asset[k] !== undefined && asset[k] !== null) out.push([k, asset[k]]);
    }
    return out;
  }, [asset]);

  return (
    <section className="card" style={{ gridColumn: "span 7" }} data-testid="traceability-panel">
      <h2 className="cardTitle">TraceabilityPanel</h2>
      <p className="cardHint">P0: show trace refs if present; otherwise safe placeholder.</p>

      {refs.length === 0 ? (
        <div className="badge">No trace refs available (placeholder)</div>
      ) : (
        <div className="kv">
          {refs.map(([k, v]) => (
            <div key={k} style={{ display: "contents" }}>
              <span>{k}</span>
              <b className="mono" style={{ whiteSpace: "pre-wrap" }}>{typeof v === "string" ? v : JSON.stringify(v)}</b>
            </div>
          ))}
        </div>
      )}
    </section>
  );
}

function ActionsPanel({ assetId }) {
  return (
    <section className="card" style={{ gridColumn: "span 5" }} data-testid="actions-panel">
      <h2 className="cardTitle">ActionsPanel</h2>
      <p className="cardHint">P0 navigation and next actions.</p>
      <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
        <Link className="btn" href="/library">Back to Library</Link>
        <Link className="btn" href="/generate">Go to Generate</Link>
        <a className="btn" href={`/library?q=${encodeURIComponent(assetId || "")}`}>Find in Library</a>
      </div>
    </section>
  );
}

function ReviewPanelPlaceholder() {
  return (
    <section className="card" style={{ gridColumn: "span 12" }} data-testid="review-panel">
      <h2 className="cardTitle">ReviewPanel</h2>
      <p className="cardHint">AC-004 will load reviews + override. P0 placeholder.</p>
      <div className="badge">No reviews loaded</div>
    </section>
  );
}

export default function AssetDetailClient({ assetId }) {
  const [loading, setLoading] = useState(false);
  const [asset, setAsset] = useState(null);
  const [lastRid, setLastRid] = useState("—");
  const [errEnv, setErrEnv] = useState(null);

  async function load() {
    setLoading(true);
    setErrEnv(null);

    const r = await getAsset(assetId);
    if (!r.ok) {
      setLastRid(r.request_id || r.error_envelope?.request_id || "—");
      setErrEnv(r.error_envelope || null);
      setAsset(null);
      setLoading(false);
      return;
    }

    setLastRid(r.request_id || "—");
    setAsset(r.data || null);
    setLoading(false);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [assetId]);

  return (
    <div className="grid">
      <section className="card" style={{ gridColumn: "span 12" }}>
        <h1 style={{ margin: 0 }}>Asset Detail</h1>
        <p className="cardHint">
          AC-002: preview + metadata + traceability entry. Error must show request_id.
        </p>
        <div className="kv" style={{ marginTop: 8 }}>
          <span>asset_id</span><b className="mono">{String(assetId)}</b>
          <span>last_request_id</span><b className="mono">{String(lastRid)}</b>
          <span>state</span><b className="mono">{loading ? "loading" : (asset ? "loaded" : (errEnv ? "error" : "empty"))}</b>
        </div>

        <div style={{ marginTop: 10 }}>
          <button className="btn" onClick={load} disabled={loading}>
            {loading ? "Loading..." : "Refresh"}
          </button>
        </div>
      </section>

      <ErrorPanel env={errEnv} />

      <PreviewPanel asset={asset} />
      <MetadataPanel asset={asset} assetId={assetId} />

      <TraceabilityPanel asset={asset} />
      <ActionsPanel assetId={assetId} />

      <ReviewPanelPlaceholder />
    </div>
  );
}
