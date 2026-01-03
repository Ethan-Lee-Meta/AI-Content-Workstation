"use client";

import Link from "next/link";
import { useMemo, useState } from "react";

const SEED = [
  { id: "test-character", name: "Test Character", status: "active" },
  { id: "demo", name: "Demo", status: "draft" },
  { id: "arch-001", name: "Archived One", status: "archived" },
];

export default function CharactersClient() {
  const [status, setStatus] = useState("all");
  const [q, setQ] = useState("");
  const [page, setPage] = useState(1);
  const pageSize = 10;

  const filtered = useMemo(() => {
    const qq = q.trim().toLowerCase();
    return SEED.filter((x) => {
      if (status !== "all" && x.status !== status) return false;
      if (!qq) return true;
      return x.id.toLowerCase().includes(qq) || x.name.toLowerCase().includes(qq);
    });
  }, [status, q]);

  return (
    <div style={{ padding: 16, display: "grid", gap: 12 }}>
      <header style={{ display: "grid", gap: 6 }}>
        <h1 style={{ margin: 0 }}>Characters</h1>
        <p style={{ margin: 0, opacity: 0.75 }}>
          Skeleton page (v1.1 STEP-080). Full management will be delivered in later batches.
        </p>
      </header>

      <section style={{ border: "1px solid rgba(255,255,255,0.12)", borderRadius: 12, padding: 12 }}>
        <h2 style={{ margin: "0 0 8px 0", fontSize: 16 }}>Filters</h2>

        <div style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "center" }}>
          <label style={{ fontSize: 12, opacity: 0.85 }}>
            Status{" "}
            <select value={status} onChange={(e) => setStatus(e.target.value)}>
              <option value="all">all</option>
              <option value="draft">draft</option>
              <option value="active">active</option>
              <option value="archived">archived</option>
            </select>
          </label>

          <label style={{ fontSize: 12, opacity: 0.85 }}>
            Search{" "}
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="name / id"
              style={{ padding: "4px 6px" }}
            />
          </label>

          <span style={{ fontSize: 12, opacity: 0.7 }}>
            pagination: page={page} size={pageSize}
          </span>
        </div>

        <div style={{ marginTop: 8, fontSize: 12, opacity: 0.7 }}>
          Future API (via api_proxy): <code>/api_proxy/characters?offset=0&amp;limit=20</code>
        </div>
      </section>

      <section style={{ border: "1px solid rgba(255,255,255,0.12)", borderRadius: 12, padding: 12 }}>
        <h2 style={{ margin: "0 0 8px 0", fontSize: 16 }}>List</h2>

        {filtered.length === 0 ? (
          <div style={{ fontSize: 12, opacity: 0.75 }}>
            Empty state: No characters match current filters.
          </div>
        ) : (
          <ul style={{ margin: 0, paddingLeft: 16 }}>
            {filtered.slice(0, pageSize).map((x) => (
              <li key={x.id} style={{ marginBottom: 6 }}>
                <Link href={`/characters/${x.id}`}>{x.name}</Link>{" "}
                <span style={{ opacity: 0.7, fontSize: 12 }}>({x.status})</span>
              </li>
            ))}
          </ul>
        )}

        <div style={{ marginTop: 10, display: "flex", gap: 8 }}>
          <button type="button" onClick={() => setPage((p) => Math.max(1, p - 1))}>
            Prev
          </button>
          <button type="button" onClick={() => setPage((p) => p + 1)}>
            Next
          </button>
        </div>
      </section>

      <section style={{ border: "1px dashed rgba(255,255,255,0.25)", borderRadius: 12, padding: 12 }}>
        <h2 style={{ margin: "0 0 8px 0", fontSize: 16 }}>Error (placeholder)</h2>
        <div style={{ fontSize: 12, opacity: 0.85 }}>
          If an API call fails, show the error envelope and request_id here. Provide request_id when reporting issues.
        </div>
        <div style={{ marginTop: 6, fontSize: 12, opacity: 0.75 }}>
          request_id: <code>__REQUEST_ID__</code>
        </div>
      </section>
    </div>
  );
}
