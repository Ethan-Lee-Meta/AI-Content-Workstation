"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { apiRequest, isBackendNotReady, pickPreviewUrl } from "../../_lib/api";
import ErrorPanel from "../../_components/ErrorPanel";
import BackendNotReady from "../../_components/BackendNotReady";
import Badge from "../../_components/Badge";
import AssetPickerModal from "./AssetPickerModal";
import RefSetCreateModal from "./RefSetCreateModal";
import RequirementsPanel from "./RequirementsPanel";

function pick(v, keys) {
  for (const k of keys) {
    const x = v?.[k];
    if (x !== undefined && x !== null && x !== "") return x;
  }
  return null;
}

function normalizeRefSet(rs) {
  return {
    id: pick(rs, ["id", "ref_set_id", "refSetId"]),
    version: pick(rs, ["version"]) ?? null,
    status: pick(rs, ["status"]) || "unknown",
    created_at: pick(rs, ["created_at", "createdAt"]) || null,
    ref_count: pick(rs, ["ref_count", "refCount", "refs_count"]) ?? null,
    snapshot: pick(rs, ["min_requirements_snapshot_json", "requirements_snapshot", "coverage_snapshot"]) || null,
  };
}

function normalizeCharacter(c) {
  return {
    id: pick(c, ["id"]),
    name: pick(c, ["name"]) || "(unnamed)",
    status: pick(c, ["status"]) || "unknown",
    active_ref_set_id: pick(c, ["active_ref_set_id", "activeRefSetId"]) || null,
    updated_at: pick(c, ["updated_at", "updatedAt"]) || null,
    // optionally embedded ref_sets
    ref_sets: Array.isArray(c?.ref_sets) ? c.ref_sets.map(normalizeRefSet) : null,
  };
}

function normalizeRefsPayload(payload) {
  // Accept several possible shapes:
  // 1) { items: [ { asset: {...} } ] }
  // 2) { refs: [ { asset_id, asset? } ] }
  // 3) { asset_ids: [...] }
  const items = payload?.items || payload?.refs || payload?.references || [];
  if (Array.isArray(items) && items.length > 0) return items;
  const assetIds = payload?.asset_ids || payload?.assetIds || [];
  if (Array.isArray(assetIds) && assetIds.length > 0) return assetIds.map((id) => ({ asset_id: id }));
  return [];
}

export default function CharacterDetailClient({ characterId }) {
  const router = useRouter();
  const sp = useSearchParams();

  const [loading, setLoading] = useState(true);
  const [pageErr, setPageErr] = useState(null);

  const [character, setCharacter] = useState(null);
  const [refSets, setRefSets] = useState([]);
  const [selectedRefSetId, setSelectedRefSetId] = useState(null);

  const [refSetDetail, setRefSetDetail] = useState(null);
  const [refs, setRefs] = useState([]); // normalized list (may contain asset objects or ids)
  const [refAssets, setRefAssets] = useState([]); // resolved asset objects for grid
  const [detailErr, setDetailErr] = useState(null);

  const [busy, setBusy] = useState({}); // keys: load, set_active, create_ref_set, add_refs
  const [pickerOpen, setPickerOpen] = useState(false);
  const [createRefSetOpen, setCreateRefSetOpen] = useState(false);

  const backendReady = useMemo(() => !isBackendNotReady(pageErr), [pageErr]);

  const selectedFromUrl = sp?.get("ref_set_id") || null;

  const canConfirm = useMemo(() => {
    const n = refAssets?.length || refs?.length || refSetDetail?.ref_count || 0;
    return n >= 8;
  }, [refAssets?.length, refs?.length, refSetDetail?.ref_count]);

  const refCount = useMemo(() => {
    const n = refAssets?.length || refs?.length || refSetDetail?.ref_count || 0;
    return Number.isFinite(n) ? n : 0;
  }, [refAssets?.length, refs?.length, refSetDetail?.ref_count]);

  const activeRefSetId = character?.active_ref_set_id || null;

  const loadCharacter = useCallback(async () => {
    if (!characterId) {
      setPageErr({ message: "missing character_id", request_id: null, details: {} });
      setLoading(false);
      return;
    }
    setPageErr(null);
    setBusy((p) => ({ ...(p || {}), load: true }));

    try {
      const r = await apiRequest(`/characters/${characterId}`);
      const c = normalizeCharacter(r.data);
      setCharacter(c);

      // ref_sets list best-effort:
      // try GET /characters/{id}/ref_sets, else fallback to embedded ref_sets in character payload
      let list = [];
      try {
        const rr = await apiRequest(`/characters/${characterId}/ref_sets`);
        const items = rr.data?.items || rr.data?.ref_sets || rr.data?.versions || [];
        list = Array.isArray(items) ? items.map(normalizeRefSet) : [];
      } catch (e) {
        if (e?.status === 404 || e?.status === 405) {
          list = Array.isArray(c.ref_sets) ? c.ref_sets : [];
        } else {
          throw e;
        }
      }

      setRefSets(list);

      // choose selected ref_set:
      const preferred = selectedFromUrl || c.active_ref_set_id || list?.[0]?.id || null;
      setSelectedRefSetId(preferred);
    } catch (e) {
      setPageErr(e);
    } finally {
      setBusy((p) => {
        const n = { ...(p || {}) };
        delete n.load;
        return n;
      });
      setLoading(false);
    }
  }, [characterId, selectedFromUrl]);

  const loadRefSetDetail = useCallback(async (refSetId) => {
    if (!refSetId) {
      setRefSetDetail(null);
      setRefs([]);
      setRefAssets([]);
      return;
    }
    setDetailErr(null);
    setBusy((p) => ({ ...(p || {}), detail: true }));

    try {
      const r = await apiRequest(`/characters/${characterId}/ref_sets/${refSetId}`);
      setRefSetDetail(r.data);

      const refsRaw = normalizeRefsPayload(r.data);
      setRefs(refsRaw);

      // Resolve assets for grid best-effort:
      // - if refs include asset object, use directly
      // - else if refs include asset_id, fetch assets for first N
      const assetsDirect = [];
      const ids = [];
      for (const it of refsRaw) {
        if (it && typeof it === "object") {
          if (it.asset && typeof it.asset === "object") assetsDirect.push(it.asset);
          else if (it.asset_id) ids.push(it.asset_id);
          else if (it.id && (it.type || it.asset_type)) assetsDirect.push(it);
        } else if (typeof it === "string") {
          ids.push(it);
        }
      }

      if (assetsDirect.length > 0) {
        setRefAssets(assetsDirect);
      } else if (ids.length > 0) {
        const N = Math.min(ids.length, 24);
        const out = [];
        for (let i = 0; i < N; i++) {
          try {
            const a = await apiRequest(`/assets/${ids[i]}`);
            out.push(a.data);
          } catch {
            out.push({ id: ids[i], name: ids[i] });
          }
        }
        setRefAssets(out);
      } else {
        setRefAssets([]);
      }
    } catch (e) {
      setDetailErr(e);
      setRefSetDetail(null);
      setRefs([]);
      setRefAssets([]);
    } finally {
      setBusy((p) => {
        const n = { ...(p || {}) };
        delete n.detail;
        return n;
      });
    }
  }, [characterId]);

  useEffect(() => {
    loadCharacter();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [characterId]);

  useEffect(() => {
    if (!selectedRefSetId) return;
    loadRefSetDetail(selectedRefSetId);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedRefSetId]);

  async function setActive(refSetId) {
    if (!refSetId) return;
    setPageErr(null);
    setBusy((p) => ({ ...(p || {}), set_active: true }));
    try {
      await apiRequest(`/characters/${characterId}`, { method: "PATCH", body: { active_ref_set_id: refSetId } });
      await loadCharacter();
    } catch (e) {
      setPageErr(e);
    } finally {
      setBusy((p) => {
        const n = { ...(p || {}) };
        delete n.set_active;
        return n;
      });
    }
  }

  async function createRefSet(payload) {
    // payload: { status, base_ref_set_id? }
    setPageErr(null);
    setBusy((p) => ({ ...(p || {}), create_ref_set: true }));
    try {
      try {
        await apiRequest(`/characters/${characterId}/ref_sets`, { method: "POST", body: payload });
      } catch (e) {
        // fallback: if backend rejects base_ref_set_id, retry without it
        if ((e?.status === 400 || e?.status === 422) && payload?.base_ref_set_id) {
          await apiRequest(`/characters/${characterId}/ref_sets`, {
            method: "POST",
            body: { status: payload.status },
          });
        } else {
          throw e;
        }
      }
      await loadCharacter();
    } finally {
      setBusy((p) => {
        const n = { ...(p || {}) };
        delete n.create_ref_set;
        return n;
      });
    }
  }

  async function addRefs(assetIds) {
    if (!selectedRefSetId) return;
    setDetailErr(null);
    setBusy((p) => ({ ...(p || {}), add_refs: true }));

    const seen = new Set();
    const ids = (assetIds || []).filter((x) => x && !seen.has(x) && (seen.add(x), true));

    let added = 0;
    let failed = 0;
    const failures = [];

    try {
      for (const id of ids) {
        try {
          await apiRequest(`/characters/${characterId}/ref_sets/${selectedRefSetId}/refs`, {
            method: "POST",
            body: { asset_id: id },
          });
          added += 1;
        } catch (e) {
          failed += 1;
          failures.push({ asset_id: id, request_id: e?.request_id || null, message: e?.message || "failed" });
        }
      }

      await loadRefSetDetail(selectedRefSetId);

      if (failed > 0) {
        setDetailErr({
          message: `Add refs completed with failures: added=${added}, failed=${failed}`,
          request_id: failures.find((x) => x.request_id)?.request_id || null,
          details: { failures },
        });
      }
    } finally {
      setBusy((p) => {
        const n = { ...(p || {}) };
        delete n.add_refs;
        return n;
      });
    }
  }

  const selectedRefSet = useMemo(() => refSets.find((x) => x.id === selectedRefSetId) || null, [refSets, selectedRefSetId]);
  const selectedSnapshot = selectedRefSet?.snapshot || refSetDetail?.min_requirements_snapshot_json || null;

  if (loading) {
    return (
      <div className="p-4">
        <div className="text-lg font-semibold">Character</div>
        <div className="mt-2 text-sm text-gray-600">Loading...</div>
      </div>
    );
  }

  if (pageErr && isBackendNotReady(pageErr)) {
    return (
      <div className="p-4">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-lg font-semibold">Character</div>
            <div className="mt-1 text-sm text-gray-600 font-mono">{characterId}</div>
          </div>
          <button
            type="button"
            className="rounded-md border px-2 py-1 text-xs hover:bg-gray-50"
            onClick={() => router.push("/characters")}
          >
            Back
          </button>
        </div>

        <div className="mt-4">
          <BackendNotReady
            title="Character detail unavailable"
            detail="Character/ref_set APIs are not ready (404) or the API server is unreachable."
            onRetry={() => loadCharacter()}
          />
        </div>
      </div>
    );
  }

  return (
    <div className="p-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <div className="text-lg font-semibold">{character?.name || "Character"}</div>
          <div className="mt-1 text-sm text-gray-600 font-mono">{characterId}</div>
          <div className="mt-2 flex flex-wrap items-center gap-2">
            {character?.status === "confirmed" ? <Badge tone="green">confirmed</Badge> :
             character?.status === "draft" ? <Badge tone="amber">draft</Badge> :
             character?.status === "archived" ? <Badge tone="red">archived</Badge> :
             <Badge tone="neutral">{character?.status || "unknown"}</Badge>}
            {activeRefSetId ? (
              <Badge tone="blue">active_ref_set: {activeRefSetId}</Badge>
            ) : (
              <Badge tone="neutral">active_ref_set: (none)</Badge>
            )}
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            type="button"
            className="rounded-md border px-2 py-1 text-xs hover:bg-gray-50"
            onClick={() => router.push("/characters")}
          >
            Back
          </button>
          <button
            type="button"
            className="rounded-md border px-2 py-1 text-xs hover:bg-gray-50 disabled:opacity-50"
            onClick={() => setCreateRefSetOpen(true)}
            disabled={!backendReady || !!busy.create_ref_set}
          >
            {busy.create_ref_set ? "Creating..." : "Create New Version"}
          </button>
        </div>
      </div>

      {pageErr ? (
        <div className="mt-4">
          <ErrorPanel title="Character request failed" error={pageErr} onRetry={() => loadCharacter()} />
        </div>
      ) : null}

      <div className="mt-4 grid gap-4 lg:grid-cols-3">
        <div className="lg:col-span-1">
          <div className="rounded-lg border bg-white">
            <div className="border-b px-3 py-2 text-sm font-semibold">Ref Set Versions</div>

            <div className="divide-y">
              {refSets.length === 0 ? (
                <div className="px-3 py-3 text-sm text-gray-600">No ref_sets.</div>
              ) : (
                refSets.map((rs) => {
                  const selected = rs.id === selectedRefSetId;
                  const isActive = activeRefSetId && rs.id === activeRefSetId;
                  const canSetActive = rs.status === "confirmed";
                  return (
                    <button
                      key={rs.id}
                      type="button"
                      className={`w-full px-3 py-2 text-left hover:bg-gray-50 ${selected ? "bg-gray-50" : ""}`}
                      onClick={() => {
                        setSelectedRefSetId(rs.id);
                        const url = new URL(window.location.href);
                        url.searchParams.set("ref_set_id", rs.id);
                        window.history.replaceState({}, "", url.toString());
                      }}
                    >
                      <div className="flex items-center justify-between gap-2">
                        <div className="text-sm font-medium">
                          v{rs.version ?? "?"} <span className="font-mono text-xs text-gray-500">{rs.id}</span>
                        </div>
                        <div className="flex items-center gap-2">
                          {rs.status === "confirmed" ? <Badge tone="green">confirmed</Badge> :
                           rs.status === "draft" ? <Badge tone="amber">draft</Badge> :
                           <Badge tone="neutral">{rs.status}</Badge>}
                          {isActive ? <Badge tone="blue">active</Badge> : null}
                        </div>
                      </div>

                      <div className="mt-1 flex flex-wrap items-center justify-between gap-2 text-xs text-gray-600">
                        <div>refs: <span className="font-mono">{rs.ref_count ?? "-"}</span></div>
                        <div>{rs.created_at || ""}</div>
                      </div>

                      <div className="mt-2 flex flex-wrap items-center gap-2">
                        {canSetActive ? (
                          <button
                            type="button"
                            className="rounded-md border px-2 py-1 text-[11px] hover:bg-gray-50 disabled:opacity-50"
                            onClick={(e) => { e.stopPropagation(); setActive(rs.id); }}
                            disabled={!!busy.set_active}
                          >
                            {busy.set_active ? "Setting..." : "Set Active"}
                          </button>
                        ) : (
                          <span className="text-[11px] text-gray-500">Set Active only for confirmed</span>
                        )}
                      </div>
                    </button>
                  );
                })
              )}
            </div>
          </div>

          <div className="mt-4">
            <RequirementsPanel refCount={refCount} snapshot={selectedSnapshot} />
          </div>
        </div>

        <div className="lg:col-span-2">
          <div className="rounded-lg border bg-white">
            <div className="flex flex-wrap items-center justify-between gap-2 border-b px-3 py-2">
              <div className="text-sm font-semibold">Reference Assets</div>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  className="rounded-md border px-2 py-1 text-xs hover:bg-gray-50 disabled:opacity-50"
                  onClick={() => setPickerOpen(true)}
                  disabled={!selectedRefSetId || !!busy.add_refs}
                >
                  {busy.add_refs ? "Adding..." : "Add References"}
                </button>
                {selectedRefSet && selectedRefSet.status !== "confirmed" ? (
                  <Badge tone="amber">draft refs are editable</Badge>
                ) : (
                  <Badge tone="neutral">confirmed (policy-dependent)</Badge>
                )}
              </div>
            </div>

            {detailErr ? (
              <div className="p-3">
                <ErrorPanel title="Ref set operation failed" error={detailErr} onRetry={() => loadRefSetDetail(selectedRefSetId)} />
              </div>
            ) : null}

            {!selectedRefSetId ? (
              <div className="p-3 text-sm text-gray-600">Select a ref_set version to view refs.</div>
            ) : busy.detail ? (
              <div className="p-3 text-sm text-gray-600">Loading ref_set...</div>
            ) : (
              <div className="p-3">
                {refAssets.length === 0 ? (
                  <div className="text-sm text-gray-600">No refs yet.</div>
                ) : (
                  <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
                    {refAssets.map((a) => {
                      const id = a.id || a.asset_id || a.assetId;
                      const url = pickPreviewUrl(a);
                      return (
                        <button
                          key={id}
                          type="button"
                          className="rounded-md border p-1 text-left hover:bg-gray-50"
                          onClick={() => id && router.push(`/assets/${id}`)}
                        >
                          <div className="aspect-square w-full overflow-hidden rounded bg-gray-100">
                            {url ? (
                              // eslint-disable-next-line @next/next/no-img-element
                              <img src={url} alt={a.name || id} className="h-full w-full object-cover" />
                            ) : (
                              <div className="flex h-full w-full items-center justify-center text-xs text-gray-500">no preview</div>
                            )}
                          </div>
                          <div className="mt-1 truncate text-xs text-gray-700">{a.name || id}</div>
                          <div className="truncate text-[10px] font-mono text-gray-500">{id}</div>
                        </button>
                      );
                    })}
                  </div>
                )}
              </div>
            )}
          </div>

          <div className="mt-4 rounded-lg border bg-gray-50 p-3 text-xs text-gray-700">
            <div className="font-medium">Notes (append-only ref_set)</div>
            <ul className="ml-4 list-disc">
              <li>We never update existing ref_set status. Confirmed is created as a new version.</li>
              <li>“Create New Version” POSTs a new ref_set (draft/confirmed).</li>
              <li>“Set Active” is offered only for confirmed versions (UI-side constraint).</li>
            </ul>
          </div>
        </div>
      </div>

      <AssetPickerModal
        open={pickerOpen}
        onClose={() => setPickerOpen(false)}
        onConfirm={addRefs}
      />

      <RefSetCreateModal
        open={createRefSetOpen}
        onClose={() => setCreateRefSetOpen(false)}
        onSubmit={createRefSet}
        canConfirm={canConfirm}
        baseRefSetId={selectedRefSetId}
      />
    </div>
  );
}
