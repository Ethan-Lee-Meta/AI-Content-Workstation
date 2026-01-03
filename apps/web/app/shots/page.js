import Link from "next/link";

function toInt(v, dflt) {
  const n = Number(v);
  return Number.isFinite(n) ? Math.max(0, Math.trunc(n)) : dflt;
}
function clamp(n, min, max) {
  return Math.max(min, Math.min(max, n));
}
function qs(params) {
  const sp = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v === undefined || v === "") continue;
    sp.set(k, String(v));
  }
  const s = sp.toString();
  return s ? `?${s}` : "";
}

async function fetchJSON(pathWithQuery) {
  const apiBase = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://127.0.0.1:7000";
  const reqId = globalThis.crypto?.randomUUID?.() ?? `req_${Date.now()}_${Math.random().toString(16).slice(2)}`;

  let res;
  try {
    res = await fetch(`${apiBase}${pathWithQuery}`, {
      cache: "no-store",
      headers: { "X-Request-Id": reqId },
    });
  } catch (e) {
    return { ok: false, apiBase, requestId: reqId, status: 0, data: null, errorText: String(e?.message ?? e) };
  }

  const hdrReqId = res.headers.get("x-request-id") || res.headers.get("X-Request-Id") || reqId;
  const ct = res.headers.get("content-type") || "";
  const isJson = ct.includes("application/json");

  if (!res.ok) {
    let env = null;
    let txt = null;
    try {
      if (isJson) env = await res.json();
      else txt = await res.text();
    } catch {}
    return { ok: false, apiBase, requestId: hdrReqId, status: res.status, data: env, errorText: txt };
  }

  const data = isJson ? await res.json() : null;
  return { ok: true, apiBase, requestId: hdrReqId, status: res.status, data, errorText: null };
}

export default async function ShotsPage({ searchParams }) {
  // Next (your version): searchParams is Promise -> must await
  const sp = (await Promise.resolve(searchParams)) ?? {};

  const offset = toInt(sp.offset, 0);
  const limit = clamp(toInt(sp.limit, 50), 1, 200);

  const project_id = typeof sp.project_id === "string" ? sp.project_id : undefined;
  const series_id = typeof sp.series_id === "string" ? sp.series_id : undefined;

  const query = qs({ offset, limit, project_id, series_id });
  const r = await fetchJSON(`/shots${query}`);

  return (
    <div style={{ padding: 16 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Shots</h1>
        <div style={{ fontSize: 12, opacity: 0.8 }}>
          api: <code>{r.apiBase}</code> · request_id: <code>{r.requestId}</code>
        </div>
      </div>

      <div style={{ marginTop: 12, padding: 12, border: "1px solid #e5e7eb", borderRadius: 8 }}>
        <form action="/shots" method="get" style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "end" }}>
          <div>
            <label style={{ display: "block", fontSize: 12, opacity: 0.8 }}>project_id (optional)</label>
            <input name="project_id" defaultValue={project_id ?? ""} style={{ padding: 8, width: 280 }} />
          </div>
          <div>
            <label style={{ display: "block", fontSize: 12, opacity: 0.8 }}>series_id (optional)</label>
            <input name="series_id" defaultValue={series_id ?? ""} style={{ padding: 8, width: 280 }} />
          </div>
          <div>
            <label style={{ display: "block", fontSize: 12, opacity: 0.8 }}>limit</label>
            <input name="limit" type="number" min={1} max={200} defaultValue={limit} style={{ padding: 8, width: 120 }} />
          </div>
          <input type="hidden" name="offset" value="0" />
          <button type="submit" style={{ padding: "8px 12px" }}>Apply</button>
        </form>
      </div>

      <div style={{ marginTop: 12 }} data-testid="shots-list">
        {!r.ok ? (
          <div style={{ border: "1px solid #ef4444", borderRadius: 8, padding: 12 }}>
            <div style={{ fontWeight: 700, marginBottom: 8 }}>Failed to load /shots</div>
            <div style={{ fontSize: 12, opacity: 0.9 }}>status: <code>{r.status}</code></div>
            <pre style={{ marginTop: 8, whiteSpace: "pre-wrap" }}>
{r.data ? JSON.stringify(r.data, null, 2) : (r.errorText ?? "(no body)")}
            </pre>
          </div>
        ) : (
          <>
            <div style={{ fontSize: 12, opacity: 0.8, marginBottom: 8 }}>
              total: <b>{r.data.page.total}</b> · offset: <b>{r.data.page.offset}</b> · limit: <b>{r.data.page.limit}</b> · has_more:{" "}
              <b>{String(r.data.page.has_more)}</b>
            </div>

            {r.data.items.length === 0 ? (
              <div style={{ padding: 12, border: "1px solid #e5e7eb", borderRadius: 8 }}>Empty. No shots found.</div>
            ) : (
              <table style={{ width: "100%", borderCollapse: "collapse" }}>
                <thead>
                  <tr style={{ textAlign: "left", borderBottom: "1px solid #e5e7eb" }}>
                    <th style={{ padding: 8 }}>shot_id</th>
                    <th style={{ padding: 8 }}>name</th>
                    <th style={{ padding: 8 }}>project_id</th>
                    <th style={{ padding: 8 }}>series_id</th>
                    <th style={{ padding: 8 }}>created_at</th>
                  </tr>
                </thead>
                <tbody>
                  {r.data.items.map((s) => (
                    <tr key={s.shot_id} style={{ borderBottom: "1px solid #f3f4f6" }}>
                      <td style={{ padding: 8 }}>
                        <Link href={`/shots/${encodeURIComponent(s.shot_id)}`}>{s.shot_id}</Link>
                      </td>
                      <td style={{ padding: 8 }}>{s.name ?? ""}</td>
                      <td style={{ padding: 8 }}>{s.project_id ?? ""}</td>
                      <td style={{ padding: 8 }}>{s.series_id ?? ""}</td>
                      <td style={{ padding: 8 }}>{s.created_at ?? ""}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            <div style={{ display: "flex", gap: 12, marginTop: 12 }}>
              {offset > 0 ? (
                <Link href={`/shots${qs({ offset: Math.max(0, offset - limit), limit, project_id, series_id })}`}>Prev</Link>
              ) : (
                <span style={{ opacity: 0.4 }}>Prev</span>
              )}
              {r.data.page.has_more ? (
                <Link href={`/shots${qs({ offset: offset + limit, limit, project_id, series_id })}`}>Next</Link>
              ) : (
                <span style={{ opacity: 0.4 }}>Next</span>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
