export function getApiBase() {
  return process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://127.0.0.1:7000";
}

export function getOrMakeRequestId(req) {
  const h = req.headers;
  const rid = h.get("x-request-id") || h.get("X-Request-Id");
  if (rid && rid.trim().length > 0) return rid.trim();
  return globalThis.crypto?.randomUUID?.() ?? `req_${Date.now()}_${Math.random().toString(16).slice(2)}`;
}

export async function forwardToApi(req, apiPath, init) {
  const apiBase = getApiBase();
  const reqId = getOrMakeRequestId(req);

  const headers = new Headers(init.headers || {});
  headers.set("X-Request-Id", reqId);

  const upstream = await fetch(`${apiBase}${apiPath}`, {
    ...init,
    headers,
    cache: "no-store",
  });

  const upstreamRid = upstream.headers.get("x-request-id") || upstream.headers.get("X-Request-Id") || reqId;

  const body = await upstream.arrayBuffer();
  const outHeaders = new Headers();
  const ct = upstream.headers.get("content-type");
  if (ct) outHeaders.set("content-type", ct);
  outHeaders.set("x-request-id", upstreamRid);

  return new Response(body, { status: upstream.status, headers: outHeaders });
}
