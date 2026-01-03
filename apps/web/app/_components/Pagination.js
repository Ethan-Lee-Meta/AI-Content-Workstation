"use client";

export default function Pagination({ page, onChange, disabled }) {
  const limit = page?.limit ?? 20;
  const offset = page?.offset ?? 0;
  const total = page?.total ?? 0;
  const hasMore = page?.has_more ?? false;

  const curStart = total === 0 ? 0 : offset + 1;
  const curEnd = Math.min(offset + limit, total);

  return (
    <div className="flex flex-wrap items-center justify-between gap-2">
      <div className="text-xs text-gray-600">
        {total === 0 ? "No results" : `Showing ${curStart}-${curEnd} of ${total}`}
      </div>

      <div className="flex items-center gap-2">
        <button
          type="button"
          className="rounded-md border px-2 py-1 text-xs hover:bg-gray-50 disabled:opacity-50"
          onClick={() => onChange({ limit, offset: Math.max(0, offset - limit) })}
          disabled={disabled || offset <= 0}
        >
          Prev
        </button>

        <button
          type="button"
          className="rounded-md border px-2 py-1 text-xs hover:bg-gray-50 disabled:opacity-50"
          onClick={() => onChange({ limit, offset: offset + limit })}
          disabled={disabled || !hasMore}
        >
          Next
        </button>
      </div>
    </div>
  );
}
