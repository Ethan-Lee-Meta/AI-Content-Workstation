"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { apiRequest, isBackendNotReady } from "../_lib/api";
import ErrorPanel from "../_components/ErrorPanel";
import BackendNotReady from "../_components/BackendNotReady";
import Pagination from "../_components/Pagination";
import Badge from "../_components/Badge";
import ProviderProfileFormModal from "./ProviderProfileFormModal";

function pickBool(v) {
  if (v === true) return true;
  if (v === false) return false;
  return false;
}

function secretsConfigured(profile) {
  return pickBool(profile?.secrets_configured ?? profile?.secretsConfigured ?? profile?.secrets_configured_bool);
}

function isDefault(profile) {
  return pickBool(profile?.is_global_default ?? profile?.isGlobalDefault ?? profile?.global_default);
}

export default function SettingsClient() {
  // page state
  const [loading, setLoading] = useState(true);
  const [pageErr, setPageErr] = useState(null);

  // provider types
  const [providerTypes, setProviderTypes] = useState([]);

  // list state
  const [items, setItems] = useState([]);
  const [page, setPage] = useState({ limit: 20, offset: 0, total: 0, has_more: false });
  const [fetching, setFetching] = useState(false);

  // modal state
  const [modalOpen, setModalOpen] = useState(false);
  const [modalMode, setModalMode] = useState("create"); // create|edit
  const [editing, setEditing] = useState(null);

  // row action state
  const [rowBusy, setRowBusy] = useState({}); // id -> "set_default" | "delete"

  const backendReady = useMemo(() => !isBackendNotReady(pageErr), [pageErr]);

  const loadAll = useCallback(async ({ offset, limit } = {}) => {
    setPageErr(null);

    const nextOffset = offset ?? page.offset ?? 0;
    const nextLimit = limit ?? page.limit ?? 20;

    setFetching(true);
    try {
      const [pt, pp] = await Promise.all([
        apiRequest("/provider_types"),
        apiRequest("/provider_profiles", { query: { offset: nextOffset, limit: nextLimit } }),
      ]);

      const ptItems = pt?.data?.items || [];
      setProviderTypes(ptItems);

      const listItems = pp?.data?.items || [];
      const pg = pp?.data?.page || { limit: nextLimit, offset: nextOffset, total: listItems.length, has_more: false };
      setItems(listItems);
      setPage(pg);
    } catch (e) {
      setPageErr(e);
    } finally {
      setFetching(false);
      setLoading(false);
    }
  }, [page.offset, page.limit]);

  useEffect(() => {
    loadAll({ offset: 0, limit: 20 });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function openCreate() {
    setEditing(null);
    setModalMode("create");
    setModalOpen(true);
  }

  function openEdit(p) {
    setEditing(p);
    setModalMode("edit");
    setModalOpen(true);
  }

  async function submitCreate(payload) {
    // POST /provider_profiles
    await apiRequest("/provider_profiles", { method: "POST", body: payload });
    await loadAll({ offset: 0, limit: page.limit });
  }

  async function submitEdit(payload) {
    const id = editing?.id;
    if (!id) throw { message: "missing profile id", request_id: null, details: { editing } };

    // PATCH /provider_profiles/{id}
    await apiRequest(`/provider_profiles/${id}`, { method: "PATCH", body: payload });
    await loadAll({ offset: page.offset, limit: page.limit });
  }

  async function doSetDefault(p) {
    const id = p?.id;
    if (!id) return;
    setRowBusy((prev) => ({ ...(prev || {}), [id]: "set_default" }));
    try {
      await apiRequest(`/provider_profiles/${id}/set_default`, { method: "POST" });
      await loadAll({ offset: page.offset, limit: page.limit });
    } catch (e) {
      setPageErr(e);
    } finally {
      setRowBusy((prev) => {
        const n = { ...(prev || {}) };
        delete n[id];
        return n;
      });
    }
  }

  async function doDelete(p) {
    const id = p?.id;
    if (!id) return;

    const ok = window.confirm(`Delete provider profile "${p?.name || id}"?\n\nThis action may be blocked if referenced by trace/runs.`);
    if (!ok) return;

    setRowBusy((prev) => ({ ...(prev || {}), [id]: "delete" }));
    try {
      await apiRequest(`/provider_profiles/${id}`, { method: "DELETE" });
      // If deleting default => default becomes empty; user should choose new default (A5)
      await loadAll({ offset: 0, limit: page.limit });
    } catch (e) {
      setPageErr(e);
    } finally {
      setRowBusy((prev) => {
        const n = { ...(prev || {}) };
        delete n[id];
        return n;
      });
    }
  }

  const header = (
    <div className="flex flex-wrap items-start justify-between gap-2">
      <div>
        <div className="text-lg font-semibold">Settings</div>
        <div className="mt-1 text-sm text-gray-600">
          Provider Profiles (instances) are managed here. Provider Types are controlled by backend registry.
        </div>
      </div>
      <button
        type="button"
        className="rounded-md bg-black px-3 py-2 text-sm text-white hover:bg-black/90 disabled:opacity-50"
        onClick={openCreate}
        disabled={!backendReady}
      >
        New Profile
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
            title="Settings unavailable"
            detail="Provider APIs are not ready (404) or the API server is unreachable."
            onRetry={() => loadAll({ offset: page.offset, limit: page.limit })}
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
          <ErrorPanel title="Failed to load provider settings" error={pageErr} onRetry={() => loadAll({ offset: page.offset, limit: page.limit })} />
        </div>
      ) : null}

      <div className="mt-4 rounded-lg border bg-white">
        <div className="overflow-auto">
          <table className="w-full min-w-[900px] text-left text-sm">
            <thead className="border-b bg-gray-50 text-xs text-gray-600">
              <tr>
                <th className="px-3 py-2">Name</th>
                <th className="px-3 py-2">Provider Type</th>
                <th className="px-3 py-2">Default</th>
                <th className="px-3 py-2">Secrets</th>
                <th className="px-3 py-2">Updated</th>
                <th className="px-3 py-2">Actions</th>
              </tr>
            </thead>
            <tbody>
              {items.length === 0 ? (
                <tr>
                  <td className="px-3 py-3 text-gray-600" colSpan={6}>
                    No provider profiles.
                  </td>
                </tr>
              ) : (
                items.map((p) => {
                  const busy = rowBusy[p.id];
                  return (
                    <tr key={p.id} className="border-b last:border-b-0">
                      <td className="px-3 py-2">
                        <div className="font-medium">{p.name || "(unnamed)"}</div>
                        <div className="text-xs text-gray-500 font-mono">{p.id}</div>
                      </td>
                      <td className="px-3 py-2">
                        <span className="font-mono text-xs">{p.provider_type || p.providerType || "-"}</span>
                      </td>
                      <td className="px-3 py-2">
                        {isDefault(p) ? <Badge tone="blue">default</Badge> : <span className="text-gray-400">—</span>}
                      </td>
                      <td className="px-3 py-2">
                        {secretsConfigured(p) ? <Badge tone="green">configured</Badge> : <Badge tone="amber">not configured</Badge>}
                      </td>
                      <td className="px-3 py-2 text-xs text-gray-600">
                        {p.updated_at || p.updatedAt || "-"}
                      </td>
                      <td className="px-3 py-2">
                        <div className="flex flex-wrap items-center gap-2">
                          <button
                            type="button"
                            className="rounded-md border px-2 py-1 text-xs hover:bg-gray-50 disabled:opacity-50"
                            onClick={() => openEdit(p)}
                            disabled={!!busy}
                          >
                            Edit
                          </button>

                          {!isDefault(p) ? (
                            <button
                              type="button"
                              className="rounded-md border px-2 py-1 text-xs hover:bg-gray-50 disabled:opacity-50"
                              onClick={() => doSetDefault(p)}
                              disabled={busy === "set_default"}
                            >
                              {busy === "set_default" ? "Setting..." : "Set Default"}
                            </button>
                          ) : null}

                          <button
                            type="button"
                            className="rounded-md border border-red-200 px-2 py-1 text-xs text-red-800 hover:bg-red-50 disabled:opacity-50"
                            onClick={() => doDelete(p)}
                            disabled={busy === "delete"}
                          >
                            {busy === "delete" ? "Deleting..." : "Delete"}
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        <div className="border-t p-3">
          <Pagination
            page={page}
            disabled={fetching}
            onChange={({ offset, limit }) => loadAll({ offset, limit })}
          />
        </div>
      </div>

      <ProviderProfileFormModal
        open={modalOpen}
        mode={modalMode}
        providerTypes={providerTypes}
        initialProfile={editing}
        onClose={() => setModalOpen(false)}
        onSubmit={modalMode === "edit" ? submitEdit : submitCreate}
      />
    </div>
  );
}
