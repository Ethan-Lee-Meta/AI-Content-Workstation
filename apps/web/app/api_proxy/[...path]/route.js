const API_BASE = process.env.API_BASE || "http://127.0.0.1:7000";

function buildUpstreamUrl(req, pathParts) {
  const u = new URL(req.url);
  const joined = (pathParts || []).join("/");
  const upstream = new URL(`${API_BASE.replace(/\/+$/, "")}/${joined}`);
  upstream.search = u.search; // forward querystring
  return upstream.toString();
}

async function proxy(req, ctx) {
  const params = (ctx && ctx.params) ? (await ctx.params) : {};
  const pathParts = (params && params.path) ? params.path : [];
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

  try {
    // Add timeout and better connection handling
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000); // 30 second timeout

    const upstreamRes = await fetch(upstreamUrl, {
      method,
      headers: headersOut,
      body,
      redirect: "manual",
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    const buf = await upstreamRes.arrayBuffer();
    const resHeaders = new Headers();

    // allow client to read request id if present
    const upstreamRid = upstreamRes.headers.get("x-request-id");
    if (upstreamRid) resHeaders.set("x-request-id", upstreamRid);

    const upstreamCT = upstreamRes.headers.get("content-type");
    if (upstreamCT) resHeaders.set("content-type", upstreamCT);

    return new Response(buf, { status: upstreamRes.status, headers: resHeaders });
  } catch (error) {
    // Handle connection errors (ECONNRESET, ECONNREFUSED, timeout, etc.)
    const errorMessage = error instanceof Error ? error.message : String(error);
    const errorCode = error instanceof Error && 'code' in error ? error.code : 'UNKNOWN';
    const isTimeout = error instanceof Error && error.name === 'AbortError';
    
    const errorBody = JSON.stringify({
      error: isTimeout ? "upstream_timeout" : "upstream_connection_error",
      message: isTimeout 
        ? `Request to API server timed out after 30 seconds. The API server may be slow or unresponsive.`
        : `Failed to connect to API server at ${API_BASE}. Please ensure the API server is running on port 7000.`,
      request_id: rid || null,
      details: {
        upstream_url: upstreamUrl,
        error_message: errorMessage,
        error_code: errorCode,
        hint: "Run 'bash scripts/dev_api.sh' to start the API server"
      }
    });

    const resHeaders = new Headers();
    resHeaders.set("content-type", "application/json");
    if (rid) resHeaders.set("x-request-id", rid);

    return new Response(errorBody, {
      status: 502,
      headers: resHeaders,
    });
  }
}

export async function GET(req, ctx) { return proxy(req, ctx); }
export async function POST(req, ctx) { return proxy(req, ctx); }
export async function PUT(req, ctx) { return proxy(req, ctx); }
export async function PATCH(req, ctx) { return proxy(req, ctx); }
export async function DELETE(req, ctx) { return proxy(req, ctx); }

export async function OPTIONS(req, ctx) {
  return proxy(req, ctx);
}
