"use client";

import { useEffect, useMemo, useRef, useState } from "react";

const TYPES = [
  { key: "t2i", label: "Text → Image (t2i)" },
  { key: "i2i", label: "Image → Image (i2i)" },
  { key: "t2v", label: "Text → Video (t2v)" },
  { key: "i2v", label: "Image → Video (i2v)" },
];

function safeJsonParse(s) {
  try { return { ok: true, v: JSON.parse(s) }; } catch (e) { return { ok: false, err: String(e) }; }
}

function resolveRef(openapi, ref) {
  if (!ref || typeof ref !== "string" || !ref.startsWith("#/")) return null;
  const parts = ref.slice(2).split("/");
  let cur = openapi;
  for (const p of parts) {
    if (!cur || typeof cur !== "object") return null;
    cur = cur[p];
  }
  return cur || null;
}

function pickJsonSchema(openapi) {
  const post = openapi?.paths?.["/runs"]?.post;
  const content = post?.requestBody?.content || {};
  const schema =
    content?.["application/json"]?.schema ||
    content?.["application/*+json"]?.schema ||
    null;
  return schema;
}

// build a minimal example object from JSON schema (best-effort)
function schemaToExample(openapi, schema, depth = 0) {
  if (!schema || depth > 6) return {};
  if (schema.$ref) {
    const resolved = resolveRef(openapi, schema.$ref);
    return schemaToExample(openapi, resolved, depth + 1);
  }
  if (schema.example && typeof schema.example === "object") return schema.example;
  if (Array.isArray(schema.examples) && schema.examples[0]) return schema.examples[0];

  const pickFirst = (arr) => (Array.isArray(arr) && arr.length ? arr[0] : null);
  if (schema.oneOf) return schemaToExample(openapi, pickFirst(schema.oneOf), depth + 1);
  if (schema.anyOf) return schemaToExample(openapi, pickFirst(schema.anyOf), depth + 1);

  const t = schema.type;
  if (t === "object" || schema.properties) {
    const props = schema.properties || {};
    const required = Array.isArray(schema.required) ? schema.required : [];
    const o = {};
    for (const k of required) {
      o[k] = schemaToExample(openapi, props[k] || {}, depth + 1);
    }
    return o;
  }
  if (t === "array") return [];
  if (t === "boolean") return false;
  if (t === "integer" || t === "number") return 0;
  return "";
}

function extractId(obj) {
  if (!obj || typeof obj !== "object") return null;
  return obj.id || obj.run_id || obj.runId || obj?.run?.id || null;
}

// walk any json and collect likely asset ids
function collectAssetIds(node, out = new Set(), depth = 0) {
  if (depth > 6) return out;
  if (node == null) return out;

  if (typeof node === "string") {
    // heuristic: uppercase hex / ulid-ish / guid-ish are all possible; keep permissive
    if (node.length >= 8 && node.length <= 64) out.add(node);
    return out;
  }
  if (Array.isArray(node)) {
    for (const it of node) collectAssetIds(it, out, depth + 1);
    return out;
  }
  if (typeof node === "object") {
    for (const [k, v] of Object.entries(node)) {
      const key = String(k).toLowerCase();
      if (key.includes("asset") || key.includes("assets") || key.includes("result")) {
        collectAssetIds(v, out, depth + 1);
      } else {
        collectAssetIds(v, out, depth + 1);
      }
    }
  }
  return out;
}

export default function GenerateClient({ initialType }) {
  const [inputType, setInputType] = useState(
    TYPES.some(t => t.key === initialType) ? initialType : "t2i"
  );
  const [promptText, setPromptText] = useState("A clean studio shot, high detail.");
  const [sourceAssetId, setSourceAssetId] = useState("");
  const [schemaLoaded, setSchemaLoaded] = useState(false);
  const [schemaHint, setSchemaHint] = useState("");
  const [payloadText, setPayloadText] = useState("");
  const [autoPoll, setAutoPoll] = useState(false);

  const [runs, setRuns] = useState([]); // {id, statusText, lastRequestId}
  const [activeRunId, setActiveRunId] = useState(null);
  const [lastResponse, setLastResponse] = useState(null);
  const [lastError, setLastError] = useState(null);

  const pollTimerRef = useRef(null);

  const api = useMemo(() => ({
    async get(path) {
      const res = await fetch(`/api_proxy${path}`, { method: "GET" });
      const text = await res.text();
      let json = null;
      try { json = JSON.parse(text); } catch (_) {}
      return { res, text, json };
    },
    async post(path, bodyObj, requestId) {
      const res = await fetch(`/api_proxy${path}`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          ...(requestId ? { "x-request-id": requestId } : {}),
        },
        body: JSON.stringify(bodyObj),
      });
      const text = await res.text();
      let json = null;
      try { json = JSON.parse(text); } catch (_) {}
      return { res, text, json };
    },
  }), []);

  function rebuildPayloadFromSchema(openapi, schema) {
    const base = schemaToExample(openapi, schema);
    const o = (base && typeof base === "object" && !Array.isArray(base)) ? { ...base } : {};

    const typeKeys = ["run_type", "generation_type", "input_type", "type", "kind"];

    const hasAny = (keys) => keys.find(k => Object.prototype.hasOwnProperty.call(o, k));
    const typeKey = hasAny(typeKeys) || "run_type";
    o[typeKey] = inputType;

    // Contract-aligned prompt placement:
    // - Prefer RunCreateIn.prompt_pack.{raw_input,final_prompt,assembly_used} when present
    // - Fallback to a top-level prompt-ish field for older schemas
    if (Object.prototype.hasOwnProperty.call(o, "prompt_pack") && o.prompt_pack && typeof o.prompt_pack === "object" && !Array.isArray(o.prompt_pack)) {
      o.prompt_pack = {
        ...o.prompt_pack,
        raw_input: promptText,
        final_prompt: promptText,
        assembly_used: false,
        ...(Object.prototype.hasOwnProperty.call(o.prompt_pack, "assembly_prompt") && !o.prompt_pack.assembly_prompt ? { assembly_prompt: null } : {}),
      };
    } else {
      const promptKeys = ["prompt", "prompt_text", "text", "instruction"];
      const promptKey = hasAny(promptKeys) || "prompt";
      o[promptKey] = promptText;
    }

    // image-based types: best-effort populate a source asset id field if one exists
    if (inputType === "i2i" || inputType === "i2v") {
      const candidates = Object.keys(o).filter(k => {
        const lk = k.toLowerCase();
        return (lk.includes("source") && lk.includes("asset")) || lk.includes("asset_id") || lk.includes("image");
      });
      const k = candidates[0] || "source_asset_id";
      if (!o[k]) o[k] = sourceAssetId || "";
    }

    setPayloadText(JSON.stringify(o, null, 2));
  }

  // load openapi schema once
  useEffect(() => {
    let mounted = true;
    (async () => {
      const { res, json } = await api.get("/openapi.json");
      if (!mounted) return;

      if (!res.ok || !json) {
        setSchemaHint("openapi.json not available via /api_proxy (check API running on 7000).");
        setSchemaLoaded(true);
        setPayloadText(JSON.stringify({ run_type: inputType, prompt_pack: { raw_input: promptText, final_prompt: promptText, assembly_used: false } }, null, 2));
        return;
      }

      const schema = pickJsonSchema(json);
      if (!schema) {
        setSchemaHint("No requestBody schema found for POST /runs in OpenAPI; using minimal payload template.");
        setSchemaLoaded(true);
        setPayloadText(JSON.stringify({ run_type: inputType, prompt_pack: { raw_input: promptText, final_prompt: promptText, assembly_used: false } }, null, 2));
        return;
      }

      setSchemaHint("Payload template is schema-derived (best-effort). You can edit before submit.");
      setSchemaLoaded(true);
      rebuildPayloadFromSchema(json, schema);
    })().catch((e) => {
      setSchemaHint(`OpenAPI load failed: ${String(e)}`);
      setSchemaLoaded(true);
      setPayloadText(JSON.stringify({ run_type: inputType, prompt_pack: { raw_input: promptText, final_prompt: promptText, assembly_used: false } }, null, 2));
    });

    return () => { mounted = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // keep payload consistent when inputType/prompt/source changes (only after schema load)
  useEffect(() => {
    if (!schemaLoaded) return;
    // lightweight patch: edit current payload json if possible
    const p = safeJsonParse(payloadText);
    if (!p.ok || typeof p.v !== "object" || p.v == null) return;

    const obj = { ...p.v };
    const setFirst = (keys, val) => {
      for (const k of keys) {
        if (Object.prototype.hasOwnProperty.call(obj, k)) { obj[k] = val; return true; }
      }
      return false;
    };

    const typeKeys = ["run_type", "generation_type", "input_type", "type", "kind"];

    // Keep run_type aligned with selector
    if (!setFirst(typeKeys, inputType)) obj.run_type = inputType;

    // Keep prompt_pack aligned with editor (contract first)
    if (Object.prototype.hasOwnProperty.call(obj, "prompt_pack") && obj.prompt_pack && typeof obj.prompt_pack === "object" && !Array.isArray(obj.prompt_pack)) {
      obj.prompt_pack = {
        ...obj.prompt_pack,
        raw_input: promptText,
        final_prompt: promptText,
        assembly_used: false,
        ...(Object.prototype.hasOwnProperty.call(obj.prompt_pack, "assembly_prompt") && !obj.prompt_pack.assembly_prompt ? { assembly_prompt: null } : {}),
      };
    } else {
      const promptKeys = ["prompt", "prompt_text", "text", "instruction"];
      if (!setFirst(promptKeys, promptText)) obj.prompt = promptText;
    }
    if (inputType === "i2i" || inputType === "i2v") {
      if ("source_asset_id" in obj) obj.source_asset_id = sourceAssetId || obj.source_asset_id || "";
      if ("asset_id" in obj && !obj.asset_id) obj.asset_id = sourceAssetId || "";
      if ("image_asset_id" in obj && !obj.image_asset_id) obj.image_asset_id = sourceAssetId || "";
    }

    setPayloadText(JSON.stringify(obj, null, 2));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [inputType, promptText, sourceAssetId]);

  async function submitRun() {
    setLastError(null);
    setLastResponse(null);

    const parsed = safeJsonParse(payloadText);
    if (!parsed.ok) {
      setLastError({ error: "INVALID_JSON", message: parsed.err, request_id: null, details: null });
      return;
    }

    const requestId = (typeof crypto !== "undefined" && crypto.randomUUID) ? crypto.randomUUID() : String(Date.now());
    const { res, json, text } = await api.post("/runs", parsed.v, requestId);

    const ridOut = res.headers.get("x-request-id") || (json && json.request_id) || (json && json.error && json.error.request_id) || null;

    if (!res.ok) {
      setLastError(json || { error: "HTTP_ERROR", message: text, request_id: ridOut, details: null });
      return;
    }

    const runId = extractId(json) || (json && json.item && json.item.id) || null;
    const runRow = { id: runId || "(unknown)", statusText: "created", lastRequestId: ridOut || requestId };
    setRuns(prev => [runRow, ...prev].slice(0, 20));
    setActiveRunId(runId || null);
    setLastResponse({ kind: "create_run", request_id: ridOut || requestId, body: json || text });
  }

  async function refreshRun(runId) {
    if (!runId) return;
    setLastError(null);

    const { res, json, text } = await api.get(`/runs/${encodeURIComponent(runId)}`);
    const ridOut = res.headers.get("x-request-id") || (json && json.request_id) || (json && json.error && json.error.request_id) || null;

    if (!res.ok) {
      setLastError(json || { error: "HTTP_ERROR", message: text, request_id: ridOut, details: null });
      return;
    }

    const status =
      (json && (json.status || json.state || json.run_status || json.runState)) ? (json.status || json.state || json.run_status || json.runState) : "ok";

    setRuns(prev => prev.map(r => (r.id === runId ? { ...r, statusText: String(status), lastRequestId: ridOut || r.lastRequestId } : r)));
    setLastResponse({ kind: "get_run", request_id: ridOut, body: json || text });

    // attempt to find result asset ids and show links
    setActiveRunId(runId);
  }

  // autopoll active run
  useEffect(() => {
    if (!autoPoll || !activeRunId) {
      if (pollTimerRef.current) clearInterval(pollTimerRef.current);
      pollTimerRef.current = null;
      return;
    }
    if (pollTimerRef.current) clearInterval(pollTimerRef.current);

    pollTimerRef.current = setInterval(() => {
      refreshRun(activeRunId).catch(() => {});
    }, 1200);

    return () => {
      if (pollTimerRef.current) clearInterval(pollTimerRef.current);
      pollTimerRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autoPoll, activeRunId]);

  const assetLinks = useMemo(() => {
    const s = new Set();
    if (lastResponse && lastResponse.body && typeof lastResponse.body === "object") {
      collectAssetIds(lastResponse.body, s, 0);
    }
    // avoid linking nonsensical placeholders
    return Array.from(s).filter(x => typeof x === "string" && x.length >= 10).slice(0, 10);
  }, [lastResponse]);

  return (
    <div style={{ display: "grid", gap: 12, gridTemplateColumns: "1fr", maxWidth: 980 }}>
      {/* InputTypeSelector */}
      <section style={{ border: "1px solid #ddd", borderRadius: 8, padding: 12 }}>
        <div style={{ fontWeight: 700, marginBottom: 8 }}>InputTypeSelector</div>
        <div style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
          {TYPES.map(t => (
            <label key={t.key} style={{ display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }}>
              <input
                type="radio"
                name="inputType"
                value={t.key}
                checked={inputType === t.key}
                onChange={() => setInputType(t.key)}
              />
              <span>{t.label}</span>
            </label>
          ))}
        </div>
        <div style={{ marginTop: 8, color: "#666" }}>
          Types: <code>t2i</code>, <code>i2i</code>, <code>t2v</code>, <code>i2v</code>
        </div>
      </section>

      {/* PromptEditor */}
      <section style={{ border: "1px solid #ddd", borderRadius: 8, padding: 12 }}>
        <div style={{ fontWeight: 700, marginBottom: 8 }}>PromptEditor</div>
        <div style={{ display: "grid", gap: 8 }}>
          <textarea
            value={promptText}
            onChange={(e) => setPromptText(e.target.value)}
            rows={4}
            style={{ width: "100%", fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace" }}
          />
          {(inputType === "i2i" || inputType === "i2v") && (
            <div style={{ display: "grid", gap: 6 }}>
              <div style={{ color: "#666" }}>Source Asset ID (for i2i/i2v)</div>
              <input
                value={sourceAssetId}
                onChange={(e) => setSourceAssetId(e.target.value)}
                placeholder="Paste an existing asset_id from /library"
                style={{ padding: 8, border: "1px solid #ccc", borderRadius: 6 }}
              />
            </div>
          )}

          <div style={{ color: "#666" }}>
            {schemaHint || "Loading schema..."}
          </div>

          <div style={{ display: "grid", gap: 6 }}>
            <div style={{ color: "#666" }}>Request Payload (editable JSON)</div>
            <textarea
              value={payloadText}
              onChange={(e) => setPayloadText(e.target.value)}
              rows={10}
              style={{ width: "100%", fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace" }}
            />
          </div>

          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
            <button
              onClick={submitRun}
              data-testid="submit-run"
              style={{ padding: "8px 12px", border: "1px solid #333", borderRadius: 8, cursor: "pointer" }}
            >
              Submit Run
            </button>

            <label style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <input type="checkbox" checked={autoPoll} onChange={() => setAutoPoll(v => !v)} />
              Auto Poll (1.2s)
            </label>

            <a href="/library" style={{ padding: "8px 12px", border: "1px solid #999", borderRadius: 8, textDecoration: "none" }}>
              Open Library
            </a>
          </div>
        </div>
      </section>

      {/* RunQueuePanel */}
      <section style={{ border: "1px solid #ddd", borderRadius: 8, padding: 12 }}>
        <div style={{ fontWeight: 700, marginBottom: 8 }}>RunQueuePanel</div>
        {runs.length === 0 ? (
          <div style={{ color: "#666" }}>No runs yet.</div>
        ) : (
          <div style={{ display: "grid", gap: 8 }}>
            {runs.map(r => (
              <div key={r.id} style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap" }}>
                <button
                  onClick={() => { setActiveRunId(r.id); refreshRun(r.id); }}
                  style={{ padding: "4px 8px", border: "1px solid #999", borderRadius: 8, cursor: "pointer" }}
                >
                  Refresh
                </button>
                <span style={{ fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace" }}>
                  run_id: {r.id}
                </span>
                <span style={{ color: "#666" }}>status: {r.statusText}</span>
                {r.lastRequestId ? <span style={{ color: "#666" }}>request_id: {r.lastRequestId}</span> : null}
              </div>
            ))}
          </div>
        )}
      </section>

      {/* ResultsPanel */}
      <section style={{ border: "1px solid #ddd", borderRadius: 8, padding: 12 }}>
        <div style={{ fontWeight: 700, marginBottom: 8 }}>ResultsPanel</div>

        {lastError ? (
          <div style={{ border: "1px solid #f0c", borderRadius: 8, padding: 10 }}>
            <div style={{ fontWeight: 700, marginBottom: 6 }}>Error</div>
            <pre style={{ margin: 0, whiteSpace: "pre-wrap" }}>
{JSON.stringify(lastError, null, 2)}
            </pre>
            <div style={{ marginTop: 6, color: "#666" }}>
              request_id (if any): {lastError.request_id || "(none)"} — required for debugging.
            </div>
          </div>
        ) : null}

        {lastResponse ? (
          <div style={{ border: "1px solid #ccc", borderRadius: 8, padding: 10 }}>
            <div style={{ display: "flex", gap: 10, alignItems: "baseline", flexWrap: "wrap" }}>
              <div style={{ fontWeight: 700 }}>{lastResponse.kind}</div>
              {lastResponse.request_id ? <div style={{ color: "#666" }}>request_id: {lastResponse.request_id}</div> : null}
              {activeRunId ? <div style={{ color: "#666" }}>active_run: {activeRunId}</div> : null}
            </div>
            <pre style={{ marginTop: 8, whiteSpace: "pre-wrap" }}>
{typeof lastResponse.body === "string" ? lastResponse.body : JSON.stringify(lastResponse.body, null, 2)}
            </pre>

            {assetLinks.length > 0 ? (
              <div style={{ marginTop: 10 }}>
                <div style={{ fontWeight: 700, marginBottom: 6 }}>Possible Result Asset Links</div>
                <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                  {assetLinks.map(aid => (
                    <a key={aid} href={`/assets/${encodeURIComponent(aid)}`} style={{ textDecoration: "none", border: "1px solid #999", borderRadius: 999, padding: "4px 10px" }}>
                      /assets/{aid}
                    </a>
                  ))}
                </div>
              </div>
            ) : null}
          </div>
        ) : (
          <div style={{ color: "#666" }}>No results yet.</div>
        )}
      </section>
    </div>
  );
}
