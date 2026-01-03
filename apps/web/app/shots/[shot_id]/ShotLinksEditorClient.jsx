"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";

function pickLinkId(x) {
  const v = x?.link_id ?? x?.id;
  return typeof v === "string" && v.length > 0 ? v : null;
}

function headerRequestId(res) {
  return res.headers.get("x-request-id") || res.headers.get("X-Request-Id");
}

export default function ShotLinksEditorClient(props) {
  const router = useRouter();

  const [dstType, setDstType] = useState("asset");
  const [dstId, setDstId] = useState("");
  const [rel, setRel] = useState("refs");

  const [busy, setBusy] = useState(false);
  const [lastReqId, setLastReqId] = useState("");
  const [lastOk, setLastOk] = useState("");
  const [lastErr, setLastErr] = useState("");

  const links = useMemo(() => (Array.isArray(props?.initialLinks) ? props.initialLinks : []), [props?.initialLinks]);
  const unlinkCapable = useMemo(() => links.some((l) => !!pickLinkId(l)), [links]);

  async function postJSON(path, body) {
    const reqId = globalThis.crypto?.randomUUID?.() ?? `req_${Date.now()}_${Math.random().toString(16).slice(2)}`;
    setLastReqId(reqId);

    const res = await fetch(path, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Request-Id": reqId },
      body: JSON.stringify(body),
    });

    const rid = headerRequestId(res) ?? reqId;
    setLastReqId(rid);

    const ct = res.headers.get("content-type") || "";
    const isJson = ct.includes("application/json");

    if (!res.ok) {
      let msg = `HTTP ${res.status}`;
      try {
        if (isJson) msg = JSON.stringify(await res.json(), null, 2);
        else msg = await res.text();
      } catch {}
      throw new Error(msg);
    }

    try {
      return isJson ? await res.json() : null;
    } catch {
      return null;
    }
  }

  async function del(path) {
    const reqId = globalThis.crypto?.randomUUID?.() ?? `req_${Date.now()}_${Math.random().toString(16).slice(2)}`;
    setLastReqId(reqId);

    const res = await fetch(path, { method: "DELETE", headers: { "X-Request-Id": reqId } });

    const rid = headerRequestId(res) ?? reqId;
    setLastReqId(rid);

    const ct = res.headers.get("content-type") || "";
    const isJson = ct.includes("application/json");

    if (!res.ok) {
      let msg = `HTTP ${res.status}`;
      try {
        if (isJson) msg = JSON.stringify(await res.json(), null, 2);
        else msg = await res.text();
      } catch {}
      throw new Error(msg);
    }

    try {
      return isJson ? await res.json() : null;
    } catch {
      return null;
    }
  }

  async function onAdd() {
    setLastOk("");
    setLastErr("");

    if (!dstType.trim() || !dstId.trim() || !rel.trim()) {
      setLastErr("dst_type / dst_id / rel are required.");
      return;
    }

    setBusy(true);
    try {
      await postJSON(`/api_proxy/shots/${encodeURIComponent(props.shotId)}/links`, {
        dst_type: dstType.trim(),
        dst_id: dstId.trim(),
        rel: rel.trim(),
      });
      setLastOk("Link created.");
      setDstId("");
      router.refresh();
    } catch (e) {
      setLastErr(String(e?.message ?? e));
    } finally {
      setBusy(false);
    }
  }

  async function onUnlink(linkId) {
    setLastOk("");
    setLastErr("");
    setBusy(true);
    try {
      await del(`/api_proxy/shots/${encodeURIComponent(props.shotId)}/links/${encodeURIComponent(linkId)}`);
      setLastOk("Unlink tombstone written.");
      router.refresh();
    } catch (e) {
      setLastErr(String(e?.message ?? e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div style={{ marginTop: 12, border: "1px solid #e5e7eb", borderRadius: 8, padding: 12 }} data-testid="shot-links-editor">
      <div style={{ display: "flex", justifyContent: "space-between", gap: 12, alignItems: "baseline" }}>
        <div style={{ fontWeight: 700 }}>Link orchestration</div>
        <div style={{ fontSize: 12, opacity: 0.8 }}>
          request_id: <code>{lastReqId || "(none yet)"}</code>
        </div>
      </div>

      <div style={{ marginTop: 10, display: "flex", gap: 12, flexWrap: "wrap", alignItems: "end" }}>
        <div>
          <label style={{ display: "block", fontSize: 12, opacity: 0.8 }}>dst_type</label>
          <input value={dstType} onChange={(e) => setDstType(e.target.value)} style={{ padding: 8, width: 220 }} />
        </div>
        <div>
          <label style={{ display: "block", fontSize: 12, opacity: 0.8 }}>dst_id</label>
          <input value={dstId} onChange={(e) => setDstId(e.target.value)} style={{ padding: 8, width: 360 }} />
        </div>
        <div>
          <label style={{ display: "block", fontSize: 12, opacity: 0.8 }}>rel</label>
          <input value={rel} onChange={(e) => setRel(e.target.value)} style={{ padding: 8, width: 180 }} />
        </div>
        <button type="button" onClick={onAdd} disabled={busy} style={{ padding: "8px 12px" }}>
          {busy ? "Working..." : "Add link"}
        </button>
      </div>

      {lastOk ? <div style={{ marginTop: 10, padding: 10, border: "1px solid #22c55e", borderRadius: 8 }}>{lastOk}</div> : null}

      {lastErr ? (
        <div style={{ marginTop: 10, padding: 10, border: "1px solid #ef4444", borderRadius: 8 }}>
          <div style={{ fontWeight: 700, marginBottom: 6 }}>Error</div>
          <pre style={{ whiteSpace: "pre-wrap" }}>{lastErr}</pre>
        </div>
      ) : null}

      <div style={{ marginTop: 12, fontSize: 12, opacity: 0.85 }}>
        Unlink requires <code>link_id</code>. If backend detail payload does not expose raw links, unlink is add-only in this batch.
      </div>

      <div style={{ marginTop: 10 }}>
        <div style={{ fontWeight: 700 }}>Raw links (optional)</div>
        {links.length === 0 ? (
          <div style={{ marginTop: 6, opacity: 0.8 }}>No raw links provided by API (or empty).</div>
        ) : (
          <table style={{ width: "100%", borderCollapse: "collapse", marginTop: 6 }}>
            <thead>
              <tr style={{ textAlign: "left", borderBottom: "1px solid #e5e7eb" }}>
                <th style={{ padding: 6 }}>link_id</th>
                <th style={{ padding: 6 }}>dst_type</th>
                <th style={{ padding: 6 }}>dst_id</th>
                <th style={{ padding: 6 }}>rel</th>
                <th style={{ padding: 6 }}>action</th>
              </tr>
            </thead>
            <tbody>
              {links.map((l, idx) => {
                const id = pickLinkId(l);
                return (
                  <tr key={idx} style={{ borderBottom: "1px solid #f3f4f6" }}>
                    <td style={{ padding: 6 }}><code>{id ?? ""}</code></td>
                    <td style={{ padding: 6 }}><code>{String(l?.dst_type ?? "")}</code></td>
                    <td style={{ padding: 6 }}><code>{String(l?.dst_id ?? "")}</code></td>
                    <td style={{ padding: 6 }}><code>{String(l?.rel ?? "")}</code></td>
                    <td style={{ padding: 6 }}>
                      {id ? (
                        <button type="button" onClick={() => onUnlink(id)} disabled={busy} style={{ padding: "6px 10px" }}>
                          Unlink
                        </button>
                      ) : (
                        <span style={{ opacity: 0.5 }}>n/a</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}

        {!unlinkCapable && links.length > 0 ? (
          <div style={{ marginTop: 8, fontSize: 12, opacity: 0.8 }}>
            Raw links exist but no <code>link_id</code>/<code>id</code> field detected; unlink disabled.
          </div>
        ) : null}
      </div>
    </div>
  );
}
