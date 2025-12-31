const UPSTREAM_BASE = process.env.NEXT_PUBLIC_API_BASE_URL || "http://127.0.0.1:7000";
// Browser MUST go through same-origin proxy to avoid CORS preflight (OPTIONS 405 on backend)
const API_BASE = (typeof window === "undefined") ? UPSTREAM_BASE : "/api_proxy";

function makeRid() {
  try {
    if (typeof crypto !== "undefined" && crypto.randomUUID) return crypto.randomUUID();
  } catch {}
  return "rid_" + Math.random().toString(16).slice(2) + "_" + Date.now().toString(16);
}

function qs(params) {
  const q = new URLSearchParams();
  Object.entries(params || {}).forEach(([k, v]) => {
    if (v === undefined || v === null || v === "") return;
    q.set(k, String(v));
  });
  const s = q.toString();
  return s ? `?${s}` : "";
}

export function pickPreviewUrl(asset) {
  if (!asset || typeof asset !== "object") return "";
  const c = [
    asset.preview_url,
    asset.thumbnail_url,
    asset.url,
    asset.file_url,
    asset.content_url,
    asset.media_url,
    asset.storage_url,
    asset.public_url
  ].filter(Boolean);
  return c[0] || "";
}

export async function apiFetch(path, { method = "GET", query, body } = {}) {
  const ridIn = makeRid();
  const url = `${API_BASE}${path}${qs(query)}`;

  let res;
  try {
    res = await fetch(url, {
      method,
      headers: { "Content-Type": "application/json", "X-Request-Id": ridIn },
      body: body === undefined ? undefined : JSON.stringify(body)
    });
  } catch (e) {
    const env = {
      error: "NETWORK_ERROR",
      message: `Failed to reach API at ${API_BASE}`,
      request_id: ridIn,
      details: String(e?.message || e)
    };
    return { ok: false, request_id: env.request_id, http_status: 0, error_envelope: env };
  }

  const ridOut = res.headers.get("X-Request-Id") || ridIn;

  let data = null;
  try {
    const t = await res.text();
    data = t ? JSON.parse(t) : null;
  } catch {
    data = null;
  }

  if (res.ok) return { ok: true, request_id: ridOut, data };

  // Normalize to required keys: error/message/request_id/details
  const env0 = data || {};
  let env = null;

  if (env0 && typeof env0.error === "object" && env0.error) {
    env = {
      error: env0.error.code || "HTTP_ERROR",
      message: env0.error.message || `HTTP ${res.status}`,
      request_id: env0.error.request_id || ridOut,
      details: env0.error.details
    };
  } else {
    env = {
      error: env0.error || "HTTP_ERROR",
      message: env0.message || `HTTP ${res.status}`,
      request_id: env0.request_id || ridOut,
      details: env0.details
    };
  }

  return { ok: false, request_id: env.request_id || ridOut, http_status: res.status, error_envelope: env };
}

export async function listAssets({ limit = 20, offset = 0, include_deleted = false } = {}) {
  const query = { limit, offset };
  if (include_deleted) query.include_deleted = "true";
  return apiFetch("/assets", { method: "GET", query });
}

export async function getAsset(assetId) {
  const id = encodeURIComponent(String(assetId || ""));
  return apiFetch(`/assets/${id}`, { method: "GET" });
}
// P1: soft delete helper (compat across backend implementations)
// Tries in order:
//  1) DELETE /assets/{id}
//  2) POST   /assets/{id}/delete
//  3) PATCH  /assets/{id}  with { is_deleted:true, deleted:true }
export async function softDeleteAsset(assetId) {
  const id = encodeURIComponent(String(assetId || ""));
  const attempts = [
    { url: `/assets/${id}`, init: { method: "DELETE" } },
    { url: `/assets/${id}/delete`, init: { method: "POST" } },
    {
      url: `/assets/${id}`,
      init: {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ is_deleted: true, deleted: true }),
      },
    },
  ];

  let last = null;
  for (const a of attempts) {
    const r = await apiFetch(a.url, a.init);
    last = r;
    if (r && r.ok) return r;
  }
  return last;
}
