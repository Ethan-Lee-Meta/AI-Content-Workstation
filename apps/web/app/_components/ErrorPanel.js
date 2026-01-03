"use client";

import { useMemo, useState } from "react";

export default function ErrorPanel({ title = "Error", error, onRetry }) {
  const [open, setOpen] = useState(false);

  const normalized = useMemo(() => {
    if (!error) return null;
    const msg = error.message || "Unknown error";
    const rid = error.request_id || error.requestId || null;
    const details = error.details || null;
    const status = error.status || null;
    return { msg, rid, details, status };
  }, [error]);

  if (!normalized) return null;

  return (
    <div className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-900">
      <div className="flex items-start justify-between gap-2">
        <div>
          <div className="font-semibold">{title}</div>
          <div className="mt-1">{normalized.msg}</div>
          <div className="mt-2 flex flex-wrap items-center gap-2 text-xs text-red-800">
            {normalized.status ? <span>status: {normalized.status}</span> : null}
            {normalized.rid ? <span>request_id: {normalized.rid}</span> : <span>request_id: n/a (client)</span>}
          </div>
        </div>

        <div className="flex items-center gap-2">
          {onRetry ? (
            <button
              className="rounded-md border border-red-300 bg-white px-2 py-1 text-xs hover:bg-red-100"
              onClick={onRetry}
              type="button"
            >
              Retry
            </button>
          ) : null}
          <button
            className="rounded-md border border-red-300 bg-white px-2 py-1 text-xs hover:bg-red-100"
            onClick={() => setOpen(!open)}
            type="button"
          >
            {open ? "Hide details" : "Show details"}
          </button>
        </div>
      </div>

      {open ? (
        <pre className="mt-2 max-h-64 overflow-auto rounded bg-white/70 p-2 text-xs text-red-900">
{JSON.stringify({ status: normalized.status, request_id: normalized.rid, details: normalized.details }, null, 2)}
        </pre>
      ) : null}
    </div>
  );
}
