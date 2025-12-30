const API_BASE = process.env.API_BASE || "http://127.0.0.1:7000";

function buildUpstreamUrl(req, pathParts) {
  const u = new URL(req.url);
  const joined = (pathParts || []).join("/");
  const upstream = new URL(`${API_BASE.replace(/\/+$/, "")}/${joined}`);
  upstream.search = u.search; // forward querystring
  return upstream.toString();
}

async function proxy(req, ctx) {
  const pathParts = (ctx && ctx.params && ctx.params.path) ? ctx.params.path : [];
  const upstreamUrl = buildUpstreamUrl(req, pathParts);

  // forward only necessary headers
  const headersIn = new Headers(req.headers);
  const headersOut = new Headers();
  const contentType = headersIn.get("content-type");
  if (contentType) headersOut.set("content-type", contentType);
  headersOut.set("accept", headersIn.get("accept") || "application/json");

  const rid = headersIn.get("x-request-id");
  if (rid) headersOut.set("x-request-id", rid);

  const method = req.method || "GET";
  const hasBody = !["GET", "HEAD"].includes(method.toUpperCase());
  const body = hasBody ? await req.arrayBuffer() : undefined;

  const upstreamRes = await fetch(upstreamUrl, {
    method,
    headers: headersOut,
    body,
    redirect: "manual",
  });

  const buf = await upstreamRes.arrayBuffer();
  const resHeaders = new Headers();

  // allow client to read request id if present
  const upstreamRid = upstreamRes.headers.get("x-request-id");
  if (upstreamRid) resHeaders.set("x-request-id", upstreamRid);

  const upstreamCT = upstreamRes.headers.get("content-type");
  if (upstreamCT) resHeaders.set("content-type", upstreamCT);

  return new Response(buf, { status: upstreamRes.status, headers: resHeaders });
}

export async function GET(req, ctx) { return proxy(req, ctx); }
export async function POST(req, ctx) { return proxy(req, ctx); }
export async function PUT(req, ctx) { return proxy(req, ctx); }
export async function PATCH(req, ctx) { return proxy(req, ctx); }
export async function DELETE(req, ctx) { return proxy(req, ctx); }
