#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

API_BASE="${API_BASE:-http://127.0.0.1:7000}"

echo "== gate_ac_003: start =="
echo "== [info] check api reachable =="
curl -fsS "${API_BASE}/openapi.json" >/dev/null
echo "[ok] api reachable: /openapi.json"

echo "== [info] create run for each type (t2i/i2i/t2v/i2v) + refresh status =="
node <<'NODE'
const API = process.env.API_BASE || "http://127.0.0.1:7000";

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

function pickJsonSchema(openapi) {
  const post = openapi?.paths?.["/runs"]?.post;
  const content = post?.requestBody?.content || {};
  return content?.["application/json"]?.schema || content?.["application/*+json"]?.schema || null;
}

function schemaToExample(openapi, schema, depth = 0) {
  if (!schema || depth > 6) return {};
  if (schema.$ref) return schemaToExample(openapi, resolveRef(openapi, schema.$ref), depth + 1);
  if (schema.example && typeof schema.example === "object") return schema.example;
  const pickFirst = (arr) => (Array.isArray(arr) && arr.length ? arr[0] : null);
  if (schema.oneOf) return schemaToExample(openapi, pickFirst(schema.oneOf), depth + 1);
  if (schema.anyOf) return schemaToExample(openapi, pickFirst(schema.anyOf), depth + 1);

  const t = schema.type;
  if (t === "object" || schema.properties) {
    const props = schema.properties || {};
    const required = Array.isArray(schema.required) ? schema.required : [];
    const o = {};
    for (const k of required) o[k] = schemaToExample(openapi, props[k] || {}, depth + 1);
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

async function jget(path) {
  const res = await fetch(`${API}${path}`);
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (_) {}
  return { res, text, json };
}

async function jpost(path, body, rid) {
  const res = await fetch(`${API}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", "x-request-id": rid },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (_) {}
  return { res, text, json };
}

function patchPayload(baseObj, typeKey, promptKey, runType, prompt, sourceKey, sourceAssetId) {
  const o = (baseObj && typeof baseObj === "object" && !Array.isArray(baseObj)) ? { ...baseObj } : {};
  o[typeKey] = runType;
  o[promptKey] = prompt;
  if ((runType === "i2i" || runType === "i2v") && sourceKey) {
    if (!(sourceKey in o) || o[sourceKey] === "") o[sourceKey] = sourceAssetId || "";
  }
  return o;
}

(async () => {
  const { res: oRes, json: openapi } = await jget("/openapi.json");
  if (!oRes.ok || !openapi) {
    console.error("[err] cannot load openapi.json");
    process.exit(2);
  }

  const schema = pickJsonSchema(openapi);
  if (!schema) {
    console.error("[err] openapi missing POST /runs requestBody schema");
    process.exit(3);
  }

  // pick an asset id for i2i/i2v if available
  let pickedAssetId = "";
  try {
    const { res, json } = await jget("/assets?limit=1&offset=0");
    if (res.ok && json?.items?.length) pickedAssetId = json.items[0]?.id || "";
  } catch (_) {}

  const baseExample = schemaToExample(openapi, schema);

  const typeKeys = ["generation_type", "input_type", "type", "kind"];
  const promptKeys = ["prompt", "prompt_text", "text", "instruction"];

  const typeKey = typeKeys.find(k => Object.prototype.hasOwnProperty.call(baseExample, k)) || "input_type";
  const promptKey = promptKeys.find(k => Object.prototype.hasOwnProperty.call(baseExample, k)) || "prompt";

  // source asset key best-effort
  const baseKeys = Object.keys(baseExample || {});
  const sourceKey =
    baseKeys.find(k => /source.*asset/i.test(k)) ||
    baseKeys.find(k => /image.*asset/i.test(k)) ||
    baseKeys.find(k => /asset_?id/i.test(k)) ||
    "source_asset_id";

  const types = ["t2i", "i2i", "t2v", "i2v"];
  const created = [];

  for (const t of types) {
    const rid = (globalThis.crypto?.randomUUID?.() || `rid_${Date.now()}_${t}`);
    const payload = patchPayload(
      baseExample,
      typeKey,
      promptKey,
      t,
      `AC-003 gate run (${t})`,
      sourceKey,
      pickedAssetId
    );

    const { res, json, text } = await jpost("/runs", payload, rid);
    const outRid = res.headers.get("x-request-id") || json?.request_id || json?.error?.request_id || "";
    if (!res.ok) {
      console.error(`[err] POST /runs failed for ${t} (request_id=${outRid || rid})`);
      console.error(text);
      process.exit(4);
    }

    const runId = extractId(json);
    if (!runId) {
      console.error(`[err] cannot extract run id from response for ${t}`);
      console.error(JSON.stringify(json, null, 2));
      process.exit(5);
    }
    console.log(`[ok] create run: type=${t} run_id=${runId} request_id=${outRid || rid}`);
    created.push(runId);

    // refresh once
    const g1 = await jget(`/runs/${encodeURIComponent(runId)}`);
    if (!g1.res.ok) {
      console.error(`[err] GET /runs/{id} failed for ${t} run_id=${runId}`);
      console.error(g1.text);
      process.exit(6);
    }
    console.log(`[ok] refresh run: run_id=${runId}`);
  }

  console.log("[ok] create run for each type; status refreshed");
})().catch((e) => {
  console.error("[err] gate node runner exception:", e);
  process.exit(9);
});
NODE

echo "== [info] web routes accessible (baseline) =="
bash scripts/gate_web_routes.sh

echo "== [info] verify /generate contains required sections markers in source (stable gate) =="
GEN_DIR="apps/web/app/generate"
test -d "${GEN_DIR}" || { echo "[err] missing ${GEN_DIR}"; exit 10; }

grep -R --line-number -F "InputTypeSelector" "${GEN_DIR}" >/dev/null || { echo "[err] missing InputTypeSelector marker"; exit 11; }
grep -R --line-number -F "PromptEditor" "${GEN_DIR}" >/dev/null || { echo "[err] missing PromptEditor marker"; exit 12; }
grep -R --line-number -F "RunQueuePanel" "${GEN_DIR}" >/dev/null || { echo "[err] missing RunQueuePanel marker"; exit 13; }
grep -R --line-number -F "ResultsPanel" "${GEN_DIR}" >/dev/null || { echo "[err] missing ResultsPanel marker"; exit 14; }

grep -R --line-number -F "t2i" "${GEN_DIR}" >/dev/null || { echo "[err] missing t2i marker"; exit 15; }
grep -R --line-number -F "i2i" "${GEN_DIR}" >/dev/null || { echo "[err] missing i2i marker"; exit 16; }
grep -R --line-number -F "t2v" "${GEN_DIR}" >/dev/null || { echo "[err] missing t2v marker"; exit 17; }
grep -R --line-number -F "i2v" "${GEN_DIR}" >/dev/null || { echo "[err] missing i2v marker"; exit 18; }

echo "[ok] /generate source contains required section markers (InputTypeSelector/PromptEditor/RunQueuePanel/ResultsPanel)"
echo "== gate_ac_003: passed =="
