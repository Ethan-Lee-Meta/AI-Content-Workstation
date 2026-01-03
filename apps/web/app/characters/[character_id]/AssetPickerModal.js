"use client";

import { useEffect, useMemo, useState } from "react";
import Modal from "../../_components/Modal";
import ErrorPanel from "../../_components/ErrorPanel";
import Pagination from "../../_components/Pagination";
import Badge from "../../_components/Badge";
import { apiRequest, pickPreviewUrl } from "../../_lib/api";

function normalizeAssets(resp) {
  const items = resp?.items || [];
  const page = resp?.page || { limit: 24, offset: 0, total: items.length, has_more: false };
  return { items, page };
}

export default function AssetPickerModal({ open, onClose, onConfirm }) {
  const [fetching, setFetching] = useState(false);
  const [err, setErr] = useState(null);

  const [items, setItems] = useState([]);
  const [page, setPage] = useState({ limit: 24, offset: 0, total: 0, has_more: false });

  const [onlyImages, setOnlyImages] = useState(true);
  const [selected, setSelected] = useState({}); // id -> true

  const selectedIds = useMemo(() => Object.keys(selected).filter((k) => selected[k]), [selected]);

  async function load({ offset, limit } = {}) {
    setErr(null);
    setFetching(true);
    const nextOffset = offset ?? page.offset ?? 0;
    const nextLimit = limit ?? page.limit ?? 24;

    try {
      // Best effort: ask backend for type=image; if not supported, fallback to local filter.
      let r;
      try {
        r = await apiRequest("/assets", {
          query: { offset: nextOffset, limit: nextLimit, ...(onlyImages ? { type: "image" } : {}) },
        });
        setItems(normalizeAssets(r.data).items);
        setPage(normalizeAssets(r.data).page);
      } catch (e) {
        if ((e?.status === 400 || e?.status === 422) && onlyImages) {
          const r2 = await apiRequest("/assets", { query: { offset: nextOffset, limit: nextLimit } });
          const norm = normalizeAssets(r2.data);
          const filtered = norm.items.filter((a) => (a.type || a.asset_type) === "image");
          setItems(filtered);
          setPage(norm.page);
        } else {
          throw e;
        }
      }
    } catch (e) {
      setErr(e);
    } finally {
      setFetching(false);
    }
  }

  useEffect(() => {
    if (!open) return;
    setSelected({});
    load({ offset: 0, limit: 24 });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  useEffect(() => {
    if (!open) return;
    // when toggle filter, reload from first page
    load({ offset: 0, limit: page.limit });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [onlyImages]);

  function toggle(id) {
    setSelected((prev) => ({ ...(prev || {}), [id]: !prev?.[id] }));
  }

  async function confirm() {
    await onConfirm(selectedIds);
    onClose();
  }

  const footer = (
    <div className="flex flex-wrap items-center justify-between gap-2">
      <div className="text-xs text-gray-600">
        Selected: <span className="font-mono">{selectedIds.length}</span>
      </div>
      <div className="flex items-center gap-2">
        <button
          type="button"
          className="rounded-md border px-3 py-1.5 text-xs hover:bg-gray-50 disabled:opacity-50"
          onClick={onClose}
          disabled={fetching}
        >
          Cancel
        </button>
        <button
          type="button"
          className="rounded-md bg-black px-3 py-1.5 text-xs text-white hover:bg-black/90 disabled:opacity-50"
          onClick={confirm}
          disabled={fetching || selectedIds.length === 0}
        >
          Add Selected
        </button>
      </div>
    </div>
  );

  return (
    <Modal open={open} title="Pick Assets to Add as References" onClose={fetching ? () => {} : onClose} footer={footer}>
      {err ? <ErrorPanel title="Failed to load assets" error={err} onRetry={() => load({ offset: page.offset, limit: page.limit })} /> : null}

      <div className="mb-3 flex flex-wrap items-center gap-2">
        <button
          type="button"
          className={`rounded-md border px-2 py-1 text-xs hover:bg-gray-50 ${onlyImages ? "bg-gray-50" : ""}`}
          onClick={() => setOnlyImages(true)}
        >
          Images
        </button>
        <button
          type="button"
          className={`rounded-md border px-2 py-1 text-xs hover:bg-gray-50 ${!onlyImages ? "bg-gray-50" : ""}`}
          onClick={() => setOnlyImages(false)}
        >
          All
        </button>
        {fetching ? <Badge tone="neutral">loading…</Badge> : null}
      </div>

      <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
        {items.map((a) => {
          const id = a.id;
          const url = pickPreviewUrl(a);
          const checked = !!selected[id];
          return (
            <button
              key={id}
              type="button"
              onClick={() => toggle(id)}
              className={`group relative rounded-md border p-1 text-left hover:bg-gray-50 ${checked ? "border-black" : ""}`}
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
              {checked ? (
                <div className="absolute right-2 top-2 rounded bg-black px-1.5 py-0.5 text-[10px] text-white">selected</div>
              ) : null}
            </button>
          );
        })}
      </div>

      <div className="mt-3">
        <Pagination page={page} disabled={fetching} onChange={({ offset, limit }) => load({ offset, limit })} />
      </div>
    </Modal>
  );
}
