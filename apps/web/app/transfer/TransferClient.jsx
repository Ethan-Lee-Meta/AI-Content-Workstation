"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";

function pick(obj, keys) {
  for (const k of keys) {
    if (obj && obj[k] !== undefined && obj[k] !== null && obj[k] !== "") return obj[k];
  }
  return null;
}

async function fetchJson(url, opts) {
  const res = await fetch(url, {
    cache: "no-store",
    ...opts,
    headers: {
      "Content-Type": "application/json",
      ...(opts && opts.headers ? opts.headers : {}),
    },
  });

  const rid =
    res.headers.get("X-Request-Id") ||
    res.headers.get("x-request-id") ||
    "";

  const raw = await res.text();
  let data = null;
  try {
    data = raw ? JSON.parse(raw) : null;
  } catch {
    data = { error: "invalid_json", message: "response is not json", request_id: rid, details: { raw } };
  }

  if (!res.ok) {
    const envelope =
      (data && typeof data === "object" && data.error && data.message && data.request_id)
        ? data
        : { error: "http_error", message: `HTTP ${res.status}`, request_id: rid, details: data };
    const err = new Error(envelope.message || "request failed");
    err.status = res.status;
    err.request_id = envelope.request_id || rid;
    err.envelope = envelope;
    throw err;
  }

  return { data, rid };
}

// Minimal $ref resolver for OpenAPI components
function resolveRef(doc, ref) {
  if (!ref || typeof ref !== "string" || !ref.startsWith("#/")) return null;
  const parts = ref.replace(/^#\//, "").split("/");
  let cur = doc;
  for (const p of parts) {
    cur = cur ? cur[p] : null;
  }
  return cur || null;
}

function buildImportBodyFromOpenApi(openapi, exportId, createNewIds, exportDirInput) {
  const post = openapi?.paths?.["/imports"]?.post;
  const schema0 =
    post?.requestBody?.content?.["application/json"]?.schema ||
    post?.requestBody?.content?.["application/*+json"]?.schema ||
    null;

  const schema = schema0?.$ref ? resolveRef(openapi, schema0.$ref) : schema0;
  const props = schema?.properties ? Object.keys(schema.properties) : [];

  // Heuristics: pick the "export reference" field
  const exportIdKey = props.includes("export_id") ? "export_id" : null;
  const exportDirKey = props.includes("export_dir") ? "export_dir"
    : props.includes("export_path") ? "export_path"
    : props.includes("path") ? "path"
    : null;

  // Heuristics: pick create_new_ids field
  const cniKey = props.includes("create_new_ids") ? "create_new_ids"
    : props.includes("create_new") ? "create_new"
    : props.includes("new_ids") ? "new_ids"
    : null;

  const body = {};

  if (exportIdKey) body[exportIdKey] = exportId;
  else if (exportDirKey) body[exportDirKey] = exportDirInput || `data/exports/${exportId}`;
  else {
    // last resort (still backend-validated)
    body["export_id"] = exportId;
  }

  if (cniKey) body[cniKey] = !!createNewIds;
  else body["create_new_ids"] = !!createNewIds;

  return body;
}

function ErrorBox({ err }) {
  if (!err) return null;
  const envelope = err.envelope || { error: "error", message: err.message, request_id: err.request_id, details: {} };
  return (
    <div style={{ border: "1px solid #f3c2c2", padding: 12, borderRadius: 8, marginTop: 12 }}>
      <div style={{ fontWeight: 700, marginBottom: 6 }}>Request failed</div>
      <div style={{ fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace", fontSize: 12, whiteSpace: "pre-wrap" }}>
        {JSON.stringify(envelope, null, 2)}
      </div>
      {envelope?.request_id ? (
        <div style={{ marginTop: 6, fontSize: 12 }}>
          request_id: <code>{envelope.request_id}</code>
        </div>
      ) : null}
    </div>
  );
}

export default function TransferClient({ initialExportId }) {
  const [exportId, setExportId] = useState(initialExportId || "");
  const [manifest, setManifest] = useState(null);
  const [step, setStep] = useState("preview"); // preview -> confirm -> result
  const [createNewIds, setCreateNewIds] = useState(true);
  const [exportDirInput, setExportDirInput] = useState("");
  const [importResult, setImportResult] = useState(null);

  const [loading, setLoading] = useState(false);
  const [rid, setRid] = useState("");
  const [err, setErr] = useState(null);

  const evidenceSummary = useMemo(() => {
    const rc = manifest?.tables?.row_counts || {};
    const keys = ["links", "prompt_packs", "runs", "reviews", "shots", "run_events", "assets"];
    const out = [];
    for (const k of keys) {
      if (rc[k] !== undefined) out.push({ k, v: rc[k] });
    }
    return out;
  }, [manifest]);

  async function onCreateExport() {
    setLoading(true); setErr(null);
    try {
      const { data, rid } = await fetchJson("/api_proxy/exports", { method: "POST", body: JSON.stringify({}) });
      setRid(rid || "");
      const id = pick(data, ["export_id", "id"]);
      if (!id) throw new Error("export created but export_id missing");
      setExportId(id);
      await onLoadManifest(id);
    } catch (e) {
      setErr(e);
    } finally {
      setLoading(false);
    }
  }

  async function onLoadManifest(id0) {
    const id = (id0 || exportId || "").trim();
    if (!id) return;
    setLoading(true); setErr(null);
    try {
      const { data, rid } = await fetchJson(`/api_proxy/exports/${encodeURIComponent(id)}/manifest`, { method: "GET" });
      setRid(rid || "");
      setManifest(data);
      setStep("preview");
    } catch (e) {
      setErr(e);
      setManifest(null);
    } finally {
      setLoading(false);
    }
  }

  async function onConfirmImport() {
    const id = (exportId || "").trim();
    if (!id) return;

    setLoading(true); setErr(null);
    try {
      // Read OpenAPI to build a backend-compatible request body (still validated server-side).
      const { data: openapi, rid: rid0 } = await fetchJson("/api_proxy/openapi.json", { method: "GET" });
      setRid(rid0 || "");

      const body = buildImportBodyFromOpenApi(openapi, id, createNewIds, exportDirInput);

      const { data: created, rid: rid1 } = await fetchJson("/api_proxy/imports", {
        method: "POST",
        body: JSON.stringify(body),
      });
      setRid(rid1 || "");

      const importId = pick(created, ["import_id", "id"]);
      if (!importId) {
        setImportResult({ created, note: "import created but import_id missing; showing raw response" });
        setStep("result");
        return;
      }

      const { data: got, rid: rid2 } = await fetchJson(`/api_proxy/imports/${encodeURIComponent(importId)}`, { method: "GET" });
      setRid(rid2 || "");
      setImportResult(got);
      setStep("result");
    } catch (e) {
      setErr(e);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (initialExportId) onLoadManifest(initialExportId);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initialExportId]);

  const assetsPreview = Array.isArray(manifest?.assets_preview) ? manifest.assets_preview : [];

  return (
    <div style={{ display: "grid", gap: 12, maxWidth: 1100 }}>
      <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap" }}>
        <button disabled={loading} onClick={onCreateExport}>
          Create Export
        </button>

        <span style={{ fontSize: 12, opacity: 0.8 }}>or</span>

        <input
          value={exportId}
          onChange={(e) => setExportId(e.target.value)}
          placeholder="export_id (UUID/ULID)"
          style={{ minWidth: 360 }}
        />
        <button disabled={loading} onClick={() => onLoadManifest()}>
          Load Manifest
        </button>

        {rid ? (
          <span style={{ fontSize: 12, opacity: 0.8 }}>
            X-Request-Id: <code>{rid}</code>
          </span>
        ) : null}
      </div>

      <ErrorBox err={err} />

      {manifest ? (
        <div style={{ border: "1px solid #e5e7eb", padding: 12, borderRadius: 8 }}>
          <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>
            <div>
              <div style={{ fontWeight: 800 }}>No-Import Preview (manifest)</div>
              <div style={{ fontSize: 12, opacity: 0.8 }}>
                export_id: <code>{manifest.export_id || exportId}</code>
              </div>
              <div style={{ fontSize: 12, opacity: 0.8 }}>
                manifest_version: <code>{manifest.manifest_version}</code> · created_at:{" "}
                <code>{manifest.created_at}</code>
              </div>
            </div>

            <div style={{ display: "flex", gap: 8 }}>
              {step !== "confirm" ? (
                <button disabled={loading} onClick={() => setStep("confirm")}>
                  Proceed to Import
                </button>
              ) : (
                <button disabled={loading} onClick={() => setStep("preview")}>
                  Back to Preview
                </button>
              )}
            </div>
          </div>

          <div style={{ marginTop: 12 }}>
            <div style={{ fontWeight: 700, marginBottom: 6 }}>Evidence / Relationship Summary (from row_counts)</div>
            {evidenceSummary.length ? (
              <ul style={{ margin: 0, paddingLeft: 18 }}>
                {evidenceSummary.map((x) => (
                  <li key={x.k}>
                    <code>{x.k}</code>: {String(x.v)}
                  </li>
                ))}
              </ul>
            ) : (
              <div style={{ fontSize: 12, opacity: 0.8 }}>row_counts not present</div>
            )}
          </div>

          <div style={{ marginTop: 12 }}>
            <div style={{ fontWeight: 700, marginBottom: 6 }}>Assets Preview (click-through for image/video preview)</div>
            {assetsPreview.length ? (
              <div style={{ display: "grid", gap: 8 }}>
                {assetsPreview.slice(0, 20).map((a, idx) => (
                  <div key={`${a.id || idx}`} style={{ display: "flex", gap: 12, alignItems: "baseline", flexWrap: "wrap" }}>
                    <code style={{ minWidth: 260 }}>{a.id}</code>
                    <span style={{ fontSize: 12, opacity: 0.8 }}>
                      type=<code>{a.type}</code> mime=<code>{a.mime}</code> size_bytes=<code>{a.size_bytes}</code>
                    </span>
                    {a.id ? (
                      <Link href={`/assets/${encodeURIComponent(a.id)}`}>Open Asset Detail</Link>
                    ) : null}
                  </div>
                ))}
                {assetsPreview.length > 20 ? (
                  <div style={{ fontSize: 12, opacity: 0.8 }}>
                    showing 20 / {assetsPreview.length}
                  </div>
                ) : null}
              </div>
            ) : (
              <div style={{ fontSize: 12, opacity: 0.8 }}>assets_preview empty</div>
            )}
          </div>

          {step === "confirm" ? (
            <div style={{ marginTop: 16, borderTop: "1px solid #eee", paddingTop: 12 }}>
              <div style={{ fontWeight: 800 }}>Controlled Import (requires confirmation)</div>
              <ul style={{ margin: "8px 0 0 0", paddingLeft: 18, fontSize: 13 }}>
                <li>Import is append-only; UI never writes DB directly.</li>
                <li>Default: create new IDs to avoid conflicts.</li>
                <li>Only import trusted packages.</li>
              </ul>

              <div style={{ display: "flex", gap: 12, alignItems: "center", flexWrap: "wrap", marginTop: 10 }}>
                <label style={{ display: "flex", gap: 8, alignItems: "center" }}>
                  <input
                    type="checkbox"
                    checked={createNewIds}
                    onChange={(e) => setCreateNewIds(e.target.checked)}
                  />
                  create_new_ids (recommended)
                </label>

                <input
                  value={exportDirInput}
                  onChange={(e) => setExportDirInput(e.target.value)}
                  placeholder="optional: export_dir/export_path (if OpenAPI requires it)"
                  style={{ minWidth: 420 }}
                />

                <button disabled={loading} onClick={onConfirmImport}>
                  Confirm Import (2nd confirmation)
                </button>
              </div>
            </div>
          ) : null}

          {step === "result" && importResult ? (
            <div style={{ marginTop: 16, borderTop: "1px solid #eee", paddingTop: 12 }}>
              <div style={{ fontWeight: 800 }}>Import Result Summary</div>
              <div style={{ fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace", fontSize: 12, whiteSpace: "pre-wrap", marginTop: 8 }}>
                {JSON.stringify(importResult, null, 2)}
              </div>
            </div>
          ) : null}
        </div>
      ) : null}

      <div style={{ fontSize: 12, opacity: 0.8 }}>
        Tips: you can deep-link directly: <code>/transfer?export_id=...</code>
      </div>
    </div>
  );
}
