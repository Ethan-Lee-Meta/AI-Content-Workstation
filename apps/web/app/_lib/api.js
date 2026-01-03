/**
 * Unified API helper (Batch-3 compat + Batch-4 apiRequest).
 * - Calls backend through /api_proxy/*
 * - Normalizes error envelope { error, message, request_id, details }
 * - Provides legacy exports used by existing pages (Library/Trash/etc)
 */
const API_PREFIX = "/api_proxy";

function joinUrl(path) {
  if (!path) return API_PREFIX;
  if (path.startsWith(API_PREFIX)) return path;
  if (!path.startsWith("/")) return `${API_PREFIX}/${path}`;
  return `${API_PREFIX}${path}`;
}

function withQuery(url, query) {
  if (!query) return url;
  const usp = new URLSearchParams();
  for (const [k, v] of Object.entries(query)) {
    if (v === undefined || v === null || v === "") continue;
    usp.set(k, String(v));
  }
  const qs = usp.toString();
  return qs ? `${url}?${qs}` : url;
}

async function readJsonSafe(resp) {
  const ct = resp.headers.get("content-type") || "";
  if (!ct.includes("application/json")) return null;
  try {
    return await resp.json();
  } catch {
    return null;
  }
}

function normalizeError({ status, body, requestIdFallback }) {
  if (body && typeof body === "object" && (body.error || body.message || body.request_id)) {
    return {
      status,
      error: body.error || "error",
      message: body.message || `HTTP ${status}`,
      request_id: body.request_id || requestIdFallback || null,
      details: body.details || null,
    };
  }
  return {
    status,
    error: status ? "http_error" : "network_error",
    message: body?.message || (status ? `HTTP ${status}` : "network error"),
    request_id: requestIdFallback || null,
    details: body || null,
  };
}

export function isBackendNotReady(err) {
  if (!err) return false;
  const s = err?.status;
  return s === 404 || s === 0 || s === undefined || s === null;
}

/**
 * New canonical helper (Batch-4 Settings uses this).
 * Returns: { ok, status, request_id, data }
 * Throws normalized error on failure.
 */
export async function apiRequest(path, { method = "GET", query, body, headers } = {}) {
  const url = withQuery(joinUrl(path), query);

  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), 15000);

  try {
    const resp = await fetch(url, {
      method,
      headers: {
        "content-type": "application/json",
        ...(headers || {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: controller.signal,
    });

    const reqIdHeader = resp.headers.get("x-request-id") || resp.headers.get("X-Request-Id");
    const json = await readJsonSafe(resp);

    if (!resp.ok) {
      throw normalizeError({
        status: resp.status,
        body: json,
        requestIdFallback: reqIdHeader || (json && json.request_id) || null,
      });
    }

    return {
      ok: true,
      status: resp.status,
      request_id: (json && json.request_id) || reqIdHeader || null,
      data: json,
    };
  } catch (e) {
    if (e && typeof e === "object" && ("error" in e || "message" in e || "request_id" in e)) {
      throw e;
    }
    const msg = e?.name === "AbortError" ? "request timeout" : (e?.message || "network error");
    throw normalizeError({ status: 0, body: { message: msg }, requestIdFallback: null });
  } finally {
    clearTimeout(t);
  }
}

/* ---------------------------
 * Batch-3 compatibility exports
 * ---------------------------
 * These keep existing pages compiling without changing their imports.
 */

export async function apiFetch(path, opts) {
  const r = await apiRequest(path, opts);
  return r.data;
}

// Assets
export async function listAssets(query) {
  return await apiFetch("/assets", { method: "GET", query: query || {} });
}

export async function getAsset(assetId) {
  return await apiFetch(`/assets/${assetId}`, { method: "GET" });
}

export async function softDeleteAsset(assetId, reasonOrBody) {
  let body = undefined;
  if (typeof reasonOrBody === "string" && reasonOrBody.trim()) body = { reason: reasonOrBody.trim() };
  else if (reasonOrBody && typeof reasonOrBody === "object") body = reasonOrBody;

  return await apiFetch(`/assets/${assetId}`, {
    method: "DELETE",
    ...(body ? { body } : {}),
  });
}

export function pickPreviewUrl(asset) {
  if (!asset || typeof asset !== "object") return null;

  // common direct fields
  const direct =
    asset.preview_url ||
    asset.previewUrl ||
    asset.thumbnail_url ||
    asset.thumbnailUrl ||
    asset.thumb_url ||
    asset.thumbUrl ||
    asset.url ||
    asset.media_url ||
    asset.mediaUrl;

  if (direct) return direct;

  // common nested shapes
  const files = asset.files || asset.file || asset.variants || null;
  if (files && typeof files === "object") {
    const candidates = [
      files.preview?.url,
      files.preview_url,
      files.thumbnail?.url,
      files.thumbnail_url,
      files.thumb?.url,
      files.thumb_url,
      files.original?.url,
      files.original_url,
    ].filter(Boolean);
    if (candidates.length > 0) return candidates[0];
  }

  return null;
}

// Provider (used by Settings; also usable elsewhere)
export async function listProviderTypes() {
  return await apiFetch("/provider_types", { method: "GET" });
}
export async function listProviderProfiles(query) {
  return await apiFetch("/provider_profiles", { method: "GET", query: query || {} });
}
export async function createProviderProfile(payload) {
  return await apiFetch("/provider_profiles", { method: "POST", body: payload });
}
export async function patchProviderProfile(id, payload) {
  return await apiFetch(`/provider_profiles/${id}`, { method: "PATCH", body: payload });
}
export async function deleteProviderProfile(id) {
  return await apiFetch(`/provider_profiles/${id}`, { method: "DELETE" });
}
export async function setDefaultProviderProfile(id) {
  return await apiFetch(`/provider_profiles/${id}/set_default`, { method: "POST" });
}
