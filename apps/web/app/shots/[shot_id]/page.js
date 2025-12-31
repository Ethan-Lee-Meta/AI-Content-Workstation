import Link from "next/link";
import ShotLinksEditorClient from "./ShotLinksEditorClient";

async function fetchJSON(path) {
  const apiBase = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://127.0.0.1:7000";
  const reqId = globalThis.crypto?.randomUUID?.() ?? `req_${Date.now()}_${Math.random().toString(16).slice(2)}`;

  let res;
  try {
    res = await fetch(`${apiBase}${path}`, {
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

function renderBucket(title, items) {
  if (!items || items.length === 0) return null;
  return (
    <div style={{ marginTop: 10 }}>
      <div style={{ fontWeight: 700 }}>{title}</div>
      <ul style={{ marginTop: 6 }}>
        {items.map((x, idx) => (
          <li key={`${title}-${idx}`}>
            <code>{typeof x === "string" ? x : JSON.stringify(x)}</code>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default async function ShotDetailPage({ params }) {
  // Next (your version): params may be Promise -> await
  const p = (await Promise.resolve(params)) ?? {};
  const shot_id = p.shot_id;

  const r = await fetchJSON(`/shots/${encodeURIComponent(shot_id)}`);

  return (
    <div style={{ padding: 16 }} data-testid="shot-detail">
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12 }}>
        <div>
          <div style={{ fontSize: 12, opacity: 0.8 }}>
            <Link href="/shots">← Back to Shots</Link>
          </div>
          <h1 style={{ fontSize: 22, fontWeight: 700, marginTop: 6 }}>Shot: {shot_id}</h1>
        </div>
        <div style={{ fontSize: 12, opacity: 0.8 }}>
          api: <code>{r.apiBase}</code> · request_id: <code>{r.requestId}</code>
        </div>
      </div>

      {!r.ok ? (
        <div style={{ marginTop: 12, border: "1px solid #ef4444", borderRadius: 8, padding: 12 }}>
          <div style={{ fontWeight: 700, marginBottom: 8 }}>Failed to load shot detail</div>
          <div style={{ fontSize: 12, opacity: 0.9 }}>status: <code>{r.status}</code></div>
          <pre style={{ marginTop: 8, whiteSpace: "pre-wrap" }}>
{r.data ? JSON.stringify(r.data, null, 2) : (r.errorText ?? "(no body)")}
          </pre>
        </div>
      ) : (
        <>
          <div style={{ marginTop: 12, border: "1px solid #e5e7eb", borderRadius: 8, padding: 12 }}>
            <div style={{ fontWeight: 700, marginBottom: 8 }}>Shot</div>
            <pre style={{ whiteSpace: "pre-wrap" }}>{JSON.stringify(r.data.shot ?? null, null, 2)}</pre>
          </div>

          <div style={{ marginTop: 12, border: "1px solid #e5e7eb", borderRadius: 8, padding: 12 }}>
            <div style={{ fontWeight: 700, marginBottom: 8 }}>Linked refs (computed via Links SSOT)</div>

            {renderBucket("assets", r.data?.linked_refs?.assets ?? [])}
            {renderBucket("runs", r.data?.linked_refs?.runs ?? [])}
            {renderBucket("prompt_packs", r.data?.linked_refs?.prompt_packs ?? [])}
            {renderBucket("series", r.data?.linked_refs?.series ?? [])}
            {renderBucket("projects", r.data?.linked_refs?.projects ?? [])}
            {renderBucket("other", r.data?.linked_refs?.other ?? [])}

            <div style={{ marginTop: 12, fontSize: 12, opacity: 0.8 }}>
              If backend does not expose raw links with <code>link_id</code>, unlink is add-only in this batch.
            </div>
          </div>

          <ShotLinksEditorClient
            shotId={shot_id}
            initialLinks={Array.isArray(r.data?.links) ? r.data.links : []}
          />
        </>
      )}
    </div>
  );
}
