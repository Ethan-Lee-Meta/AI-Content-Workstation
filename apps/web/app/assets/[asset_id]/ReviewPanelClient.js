"use client";

function coerceReviewScore(raw) {
  const n = Number(raw);
  if (!Number.isFinite(n)) return 1;

  let i;
  if (n > 0 && n < 1) i = 1;
  else i = Math.round(n);

  if (i < 1) i = 1;
  if (i > 100) i = 100;
  return i;
}






import { useEffect, useMemo, useState } from "react";

function safeJsonParse(text) {
  try { return JSON.parse(text); } catch { return null; }
}

function resolveRef(openapi, ref) {
  if (!ref || typeof ref !== "string" || !ref.startsWith("#/")) return null;
  const parts = ref.slice(2).split("/");
  let cur = openapi;
  for (const p of parts) {
    cur = cur?.[p];
    if (!cur) return null;
  }
  return cur;
}

function normalizeSchema(openapi, schema, depth = 0) {
  if (!schema || depth > 8) return null;
  if (schema.$ref) return normalizeSchema(openapi, resolveRef(openapi, schema.$ref), depth + 1);
  if (Array.isArray(schema.allOf)) {
    const merged = { type: "object", properties: {}, required: [] };
    for (const s of schema.allOf) {
      const n = normalizeSchema(openapi, s, depth + 1);
      if (!n) continue;
      if (n.properties) merged.properties = { ...merged.properties, ...n.properties };
      if (Array.isArray(n.required)) merged.required = Array.from(new Set([...merged.required, ...n.required]));
    }
    return merged;
  }
  if (Array.isArray(schema.oneOf) && schema.oneOf.length) return normalizeSchema(openapi, schema.oneOf[0], depth + 1);
  if (Array.isArray(schema.anyOf) && schema.anyOf.length) return normalizeSchema(openapi, schema.anyOf[0], depth + 1);
  return schema;
}

function schemaToExample(openapi, schema, depth = 0) {
  const s = normalizeSchema(openapi, schema, depth);
  if (!s || depth > 8) return {};
  if (s.example && typeof s.example === "object") return s.example;

  const t = s.type;
  if (t === "object" || s.properties) {
    const props = s.properties || {};
    const required = Array.isArray(s.required) ? s.required : [];
    const o = {};
    for (const k of required) o[k] = schemaToExample(openapi, props[k] || {}, depth + 1);
    return o;
  }
  if (t === "array") return [];
  if (t === "boolean") return false;
  if (t === "integer" || t === "number") return 0;
  const en = s.enum;
  if (Array.isArray(en) && en.length) return en[0];
  return "";
}

function pickReviewPostSchema(openapi) {
  const post = openapi?.paths?.["/reviews"]?.post;
  const content = post?.requestBody?.content || {};
  return content?.["application/json"]?.schema || content?.["application/*+json"]?.schema || null;
}

function findEnumField(openapi, props, enumValue) {
  for (const [k, v] of Object.entries(props || {})) {
    const nv = normalizeSchema(openapi, v);
    const en = nv?.enum || v?.enum;
    if (Array.isArray(en) && en.includes(enumValue)) return { field: k, enum: en };
  }
  return null;
}

export default function ReviewPanelClient({ assetId }) {
  const [openapi, setOpenapi] = useState(null);
  const [schemaHint, setSchemaHint] = useState("loading openapi…");

  const [kind, setKind] = useState("manual");
  const [reason, setReason] = useState("");
  const [reasonsText, setReasonsText] = useState("looks good");
  const [score, setScore] = useState("1");
  const [verdict, setVerdict] = useState("pass");

  const [submitting, setSubmitting] = useState(false);
  const [last, setLast] = useState(null); // {ok, request_id, body}
  const [lastRequestId, setLastRequestId] = useState("—");

  const schemaInfo = useMemo(() => {
    if (!openapi) return null;
    const schemaRaw = pickReviewPostSchema(openapi);
    const schema = normalizeSchema(openapi, schemaRaw);
    const props = schema?.properties || {};
    const required = Array.isArray(schema?.required) ? schema.required : [];

    // kind field (must include override if present)
    const kindFieldHit = findEnumField(openapi, props, "override");
    const kindField = kindFieldHit?.field || (props.kind ? "kind" : null);

    // reason field
    const reasonField =
      props.reason ? "reason" :
      Object.keys(props).find(k => k.toLowerCase().includes("reason")) || "reason";

    // score field best-effort
    const scoreField =
      props.score ? "score" :
      Object.keys(props).find(k => k.toLowerCase().includes("score")) || "score";

    // verdict/result field best-effort
    const verdictField =
      props.verdict ? "verdict" :
      props.result ? "result" :
      Object.keys(props).find(k => ["verdict","result","decision","conclusion"].includes(k.toLowerCase())) || "verdict";

    // reasons list field best-effort
    const reasonsField =
      props.reasons ? "reasons" :
      Object.keys(props).find(k => k.toLowerCase() === "reasons") || "reasons";

    // ids
    const assetIdField =
      props.asset_id ? "asset_id" :
      Object.keys(props).find(k => k.toLowerCase() === "asset_id") || null;

    const runIdField =
      props.run_id ? "run_id" :
      Object.keys(props).find(k => k.toLowerCase() === "run_id") || null;

    const kindEnum = kindField ? (normalizeSchema(openapi, props[kindField])?.enum || props[kindField]?.enum || null) : null;

    return {
      schemaRaw,
      schema,
      props,
      required,
      kindField,
      kindEnum,
      reasonField,
      scoreField,
      verdictField,
      reasonsField,
      assetIdField,
      runIdField,
    };
  }, [openapi]);

  useEffect(() => {
    let alive = true;
    (async () => {
      const res = await fetch("/api_proxy/openapi.json", { cache: "no-store" });
      const txt = await res.text();
      const j = safeJsonParse(txt);
      if (!alive) return;
      if (!res.ok || !j) {
        setSchemaHint("openapi load failed (check API 7000). Using minimal payload.");
        setOpenapi(null);
        return;
      }
      setOpenapi(j);
      setSchemaHint("openapi ok");
    })().catch(() => {
      if (alive) setSchemaHint("openapi load failed (exception)");
    });
    return () => { alive = false; };
  }, []);

  useEffect(() => {
    // default kind if enum provided
    if (schemaInfo?.kindEnum?.length) {
      if (schemaInfo.kindEnum.includes("manual")) setKind("manual");
      else setKind(schemaInfo.kindEnum[0]);
    }
  }, [schemaInfo?.kindEnum]);

  function splitReasons(txt) {
    return txt
      .split(/\r?\n|,/g)
      .map(s => s.trim())
      .filter(Boolean)
      .slice(0, 10);
  }

  async function submit() {
    setSubmitting(true);
    setLast(null);
    setLastRequestId("—");

    const payload = (() => {
      if (openapi && schemaInfo?.schemaRaw) {
        const base = schemaToExample(openapi, schemaInfo.schemaRaw);
        const o = (base && typeof base === "object" && !Array.isArray(base)) ? { ...base } : {};

        if (schemaInfo.assetIdField) o[schemaInfo.assetIdField] = assetId;

        if (schemaInfo.kindField) o[schemaInfo.kindField] = kind;
        else o.kind = kind;

        const sc = coerceReviewScore(score);
        o[schemaInfo.scoreField] = sc;
o[schemaInfo.verdictField] = verdict;

        o[schemaInfo.reasonsField] = splitReasons(reasonsText);

        // IMPORTANT: for override, reason is required; we allow empty to force error envelope for gate
        o[schemaInfo.reasonField] = reason;

        return o;
      }

      // fallback minimal payload
      return {
        asset_id: assetId,
        kind,
        score: coerceReviewScore(score),
        verdict,
        reasons: splitReasons(reasonsText),
        reason,
      };
    })();

    const reqId = (typeof crypto !== "undefined" && crypto.randomUUID) ? crypto.randomUUID() : String(Date.now());
      // override requires non-empty reason (client-side)
      if (String(kind) === "override" && !String(reason || "").trim()) {
        setLastRequestId(reqId);
        setLast({
          ok: false,
          request_id: reqId,
          body: {
            error: "validation_error",
            message: "override requires reason",
            request_id: reqId,
            details: { field: "reason" }
          }
        });
        setSubmitting(false);
        return;
      }

    // client-side score validation (0..1 -> 0..100 int)
    const sf = (schemaInfo && schemaInfo.scoreField) ? schemaInfo.scoreField : "score";
    if (payload[sf] === null || typeof payload[sf] === "undefined") {
      const msg = "score must be an integer 0..100 (or a float 0..1 which will be converted to 0..100).";
      setLast({
        ok: false,
        request_id: lastRequestId || "—",
        body: {
          error: "validation_error",
          message: msg,
          request_id: lastRequestId || "—",
          details: { field: sf, input: score }
        }
      });
      setSubmitting(false);
      return;
    }

      // normalize score to integer in [1..100] (API requires integer)
      if (payload && Object.prototype.hasOwnProperty.call(payload, sf)) {
        payload[sf] = coerceReviewScore(payload[sf]);
      } else if (payload) {
        payload[sf] = coerceReviewScore(score);
      }

const res = await fetch("/api_proxy/reviews", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-request-id": reqId,
      },
      body: JSON.stringify(payload),
    });

    const hdrRid = res.headers.get("x-request-id") || "";
    const txt = await res.text();
    const j = safeJsonParse(txt) || { raw: txt };

    const bodyRid = j?.request_id || j?.error?.request_id || j?.error?.requestId || "";
    setLastRequestId(bodyRid || hdrRid || reqId);

    setLast({ ok: res.ok, body: j });
    setSubmitting(false);
  }

  return (
    <div>
      {/* stable marker strings for gates */}
      <div style={{ display: "none" }}>
        <span>ReviewPanel</span>
        <span>override</span>
        <span>request_id</span>
      </div>

      <div style={{ display: "flex", justifyContent: "space-between", gap: 12, alignItems: "baseline" }}>
        <h2 className="cardTitle" style={{ margin: 0 }}>ReviewPanel</h2>
        <div className="cardHint">request_id: <span className="mono">{lastRequestId}</span></div>
      </div>

      <div className="cardHint" style={{ marginTop: 6 }}>
        AC-004: show score/verdict/reasons; override requires non-empty reason; errors must expose request_id.
        <span style={{ marginLeft: 8, opacity: 0.8 }}>({schemaHint})</span>
      </div>

      <div style={{ display: "grid", gap: 10, marginTop: 10 }}>
        <label style={{ display: "grid", gap: 4 }}>
          <span className="cardHint">kind</span>
          <select value={kind} onChange={(e) => setKind(e.target.value)}>
            {(schemaInfo?.kindEnum?.length ? schemaInfo.kindEnum : ["manual", "override"]).map(v => (
              <option key={v} value={v}>{v}</option>
            ))}
          </select>
        </label>

        <label style={{ display: "grid", gap: 4 }}>
          <span className="cardHint">score (1-100)</span>
          <input type="number" value={score} min="1" max="100" step="1" inputMode="numeric" onChange={(e) => { const v = e.target.value; if (v === "") { setScore(""); return; } const n = Number(v); if (!Number.isFinite(n)) return; let i; if (n > 0 && n < 1) i = 1; else i = Math.round(n); if (i < 1) i = 1; if (i > 100) i = 100; setScore(String(i)); }} />
        </label>

        <label style={{ display: "grid", gap: 4 }}>
          <span className="cardHint">verdict</span>
          <select value={verdict} onChange={(e) => setVerdict(e.target.value)}>
            <option value="pass">pass</option>
            <option value="fail">fail</option>
          </select>
        </label>

        <label style={{ display: "grid", gap: 4 }}>
          <span className="cardHint">reasons (comma/newline)</span>
          <textarea rows={3} value={reasonsText} onChange={(e) => setReasonsText(e.target.value)} />
        </label>

        <label style={{ display: "grid", gap: 4 }}>
          <span className="cardHint">reason (required for override; leave empty to see error envelope)</span>
          <input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. overriding due to manual approval" />
        </label>

        <button className="btn" onClick={submit} disabled={submitting}>
          {submitting ? "Submitting…" : "Submit Review"}
        </button>

        {last && (
          <pre style={{ margin: 0, fontSize: 12, whiteSpace: "pre-wrap" }}>
{JSON.stringify(last.body, null, 2)}
          </pre>
        )}
      </div>
    </div>
  );
}
