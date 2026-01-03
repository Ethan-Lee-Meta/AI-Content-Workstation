"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { apiRequest, isBackendNotReady } from "../_lib/api";
import ErrorPanel from "../_components/ErrorPanel";
import BackendNotReady from "../_components/BackendNotReady";
import Pagination from "../_components/Pagination";
import Badge from "../_components/Badge";
import CharacterCreateModal from "./CharacterCreateModal";

function pick(v, alts) {
  for (const k of alts) {
    const x = v?.[k];
    if (x !== undefined && x !== null && x !== "") return x;
  }
  return null;
}

function normalizeCharacter(c) {
  return {
    id: pick(c, ["id"]),
    name: pick(c, ["name"]),
    status: pick(c, ["status"]) || "unknown",
    active_ref_set_id: pick(c, ["active_ref_set_id", "activeRefSetId"]) || null,
    updated_at: pick(c, ["updated_at", "updatedAt"]) || null,
  };
}

async function fetchCharacters({ offset, limit, status, q }) {
  // Best-effort: try with filters; if backend rejects unknown query, retry without and let UI local-filter.
  const query = { offset, limit };
  if (status) query.status = status;
  if (q) query.q = q;

  try {
    const r = await apiRequest("/characters", { query });
    return { mode: "server", data: r.data };
  } catch (e) {
    if ((e?.status === 400 || e?.status === 422) && (status || q)) {
      const r2 = await apiRequest("/characters", { query: { offset, limit } });
      return { mode: "local", data: r2.data };
    }
    throw e;
  }
}

export default function CharactersClient() {
  const router = useRouter();

  // page state
  const [loading, setLoading] = useState(true);
  const [pageErr, setPageErr] = useState(null);

  // list state
  const [items, setItems] = useState([]);
  const [page, setPage] = useState({ limit: 20, offset: 0, total: 0, has_more: false });
  const [fetching, setFetching] = useState(false);

  // filters
  const [status, setStatus] = useState(""); // "", "draft", "confirmed", "archived"
  const [q, setQ] = useState("");
  const [filterMode, setFilterMode] = useState("server"); // server|local (informational)

  // create modal
  const [createOpen, setCreateOpen] = useState(false);

  const backendReady = useMemo(() => !isBackendNotReady(pageErr), [pageErr]);

  const loadList = useCallback(async ({ offset, limit } = {}) => {
    setPageErr(null);
    const nextOffset = offset ?? page.offset ?? 0;
    const nextLimit = limit ?? page.limit ?? 20;

    setFetching(true);
    try {
      const r = await fetchCharacters({
        offset: nextOffset,
        limit: nextLimit,
        status: status || undefined,
        q: q.trim() || undefined,
      });

      const listItems = (r?.data?.items || []).map(normalizeCharacter);
      const pg = r?.data?.page || { limit: nextLimit, offset: nextOffset, total: listItems.length, has_more: false };

      // local filter if backend doesn't support query params
      let finalItems = listItems;
      if (r.mode === "local") {
        if (status) finalItems = finalItems.filter((x) => x.status === status);
        if (q.trim()) {
          const qq = q.trim().toLowerCase();
          finalItems = finalItems.filter((x) => (x.name || "").toLowerCase().includes(qq));
        }
      }

      setFilterMode(r.mode);
      setItems(finalItems);
      setPage(pg);
    } catch (e) {
      setPageErr(e);
    } finally {
      setFetching(false);
      setLoading(false);
    }
  }, [page.offset, page.limit, status, q]);

  useEffect(() => {
    loadList({ offset: 0, limit: 20 });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function submitCreate(payload) {
    await apiRequest("/characters", { method: "POST", body: payload });
    await loadList({ offset: 0, limit: page.limit });
  }

  const header = (
    <div className="flex flex-wrap items-start justify-between gap-2">
      <div>
        <div className="text-lg font-semibold">Characters</div>
        <div className="mt-1 text-sm text-gray-600">
          Character library with versioned ref_sets (managed in detail).
        </div>
      </div>

      <button
        type="button"
        className="rounded-md bg-black px-3 py-2 text-sm text-white hover:bg-black/90 disabled:opacity-50"
        onClick={() => setCreateOpen(true)}
        disabled={!backendReady}
      >
        New Character
      </button>
    </div>
  );

  if (loading) {
    return (
      <div className="p-4">
        {header}
        <div className="mt-4 text-sm text-gray-600">Loading...</div>
      </div>
    );
  }

  if (pageErr && isBackendNotReady(pageErr)) {
    return (
      <div className="p-4">
        {header}
        <div className="mt-4">
          <BackendNotReady
            title="Characters unavailable"
            detail="Character APIs are not ready (404) or the API server is unreachable."
            onRetry={() => loadList({ offset: page.offset, limit: page.limit })}
          />
        </div>
      </div>
    );
  }

  return (
    <div className="p-4">
      {header}

      {pageErr ? (
        <div className="mt-4">
          <ErrorPanel title="Failed to load characters" error={pageErr} onRetry={() => loadList({ offset: page.offset, limit: page.limit })} />
        </div>
      ) : null}

      <div className="mt-4 rounded-lg border bg-white p-3">
        <div className="flex flex-wrap items-center gap-3">
          <div className="flex items-center gap-2">
            <label className="text-xs text-gray-600">Status</label>
            <select
              className="rounded-md border px-2 py-1 text-sm"
              value={status}
              onChange={(e) => setStatus(e.target.value)}
            >
              <option value="">All</option>
              <option value="draft">draft</option>
              <option value="confirmed">confirmed</option>
              <option value="archived">archived</option>
            </select>
          </div>

          <div className="flex items-center gap-2">
            <label className="text-xs text-gray-600">Search</label>
            <input
              className="w-64 rounded-md border px-2 py-1 text-sm"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="name contains..."
            />
          </div>

          <button
            type="button"
            className="rounded-md border px-2 py-1 text-xs hover:bg-gray-50 disabled:opacity-50"
            onClick={() => loadList({ offset: 0, limit: page.limit })}
            disabled={fetching}
          >
            Apply
          </button>

          {filterMode === "local" ? (
            <div className="text-xs text-amber-800">
              <Badge tone="amber">local filter</Badge> Backend may not support status/q query params.
            </div>
          ) : null}
        </div>
      </div>

      <div className="mt-4 rounded-lg border bg-white">
        <div className="overflow-auto">
          <table className="w-full min-w-[900px] text-left text-sm">
            <thead className="border-b bg-gray-50 text-xs text-gray-600">
              <tr>
                <th className="px-3 py-2">Name</th>
                <th className="px-3 py-2">Status</th>
                <th className="px-3 py-2">Active Ref Set</th>
                <th className="px-3 py-2">Updated</th>
                <th className="px-3 py-2">Actions</th>
              </tr>
            </thead>
            <tbody>
              {items.length === 0 ? (
                <tr>
                  <td className="px-3 py-3 text-gray-600" colSpan={5}>
                    No characters.
                  </td>
                </tr>
              ) : (
                items.map((c) => (
                  <tr key={c.id} className="border-b last:border-b-0">
                    <td className="px-3 py-2">
                      <div className="font-medium">{c.name || "(unnamed)"}</div>
                      <div className="text-xs text-gray-500 font-mono">{c.id}</div>
                    </td>
                    <td className="px-3 py-2">
                      {c.status === "confirmed" ? <Badge tone="green">confirmed</Badge> :
                       c.status === "draft" ? <Badge tone="amber">draft</Badge> :
                       c.status === "archived" ? <Badge tone="red">archived</Badge> :
                       <Badge tone="neutral">{c.status}</Badge>}
                    </td>
                    <td className="px-3 py-2">
                      {c.active_ref_set_id ? (
                        <span className="font-mono text-xs">{c.active_ref_set_id}</span>
                      ) : (
                        <span className="text-gray-400">—</span>
                      )}
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-600">
                      {c.updated_at || "-"}
                    </td>
                    <td className="px-3 py-2">
                      <button
                        type="button"
                        className="rounded-md border px-2 py-1 text-xs hover:bg-gray-50"
                        onClick={() => router.push(`/characters/${c.id}`)}
                      >
                        Open
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        <div className="border-t p-3">
          <Pagination
            page={page}
            disabled={fetching}
            onChange={({ offset, limit }) => loadList({ offset, limit })}
          />
        </div>
      </div>

      <CharacterCreateModal
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        onSubmit={submitCreate}
      />
    </div>
  );
}
