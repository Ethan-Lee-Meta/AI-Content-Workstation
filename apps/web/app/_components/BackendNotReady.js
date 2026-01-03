"use client";

export default function BackendNotReady({ title = "Backend not ready", detail, onRetry }) {
  return (
    <div className="rounded-md border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
      <div className="font-semibold">{title}</div>
      <div className="mt-1 text-amber-800">
        {detail || "Required API routes are unavailable (404) or the API server is unreachable."}
      </div>
      {onRetry ? (
        <div className="mt-3">
          <button
            type="button"
            className="rounded-md border border-amber-300 bg-white px-3 py-1.5 text-xs hover:bg-amber-100"
            onClick={onRetry}
          >
            Retry
          </button>
        </div>
      ) : null}
    </div>
  );
}
