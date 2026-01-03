"use client";

import Badge from "../../_components/Badge";

export default function RequirementsPanel({ refCount, snapshot }) {
  const min = 8;
  const rec = 12;
  const ok = (refCount || 0) >= min;

  const cov = snapshot && typeof snapshot === "object" ? snapshot : null;
  const unknown = cov?.unknown;

  return (
    <div className="rounded-lg border bg-white p-3">
      <div className="flex items-center justify-between">
        <div className="text-sm font-semibold">Requirements (D-008)</div>
        {ok ? <Badge tone="green">meets min</Badge> : <Badge tone="amber">below min</Badge>}
      </div>

      <div className="mt-2 text-sm text-gray-700">
        refs: <span className="font-mono">{refCount || 0}</span> / min <span className="font-mono">{min}</span>, recommended{" "}
        <span className="font-mono">{rec}</span>
      </div>

      {!ok ? (
        <div className="mt-2 text-xs text-amber-800">
          refs &lt; {min}: creating a confirmed ref_set or setting active may be rejected by backend policy.
        </div>
      ) : (
        <div className="mt-2 text-xs text-gray-600">
          refs ≥ {min}: you should be able to create a confirmed version (policy-dependent).
        </div>
      )}

      {cov ? (
        <div className="mt-3 rounded-md border bg-gray-50 p-2 text-xs text-gray-700">
          <div className="font-medium">Coverage snapshot (best-effort)</div>
          <pre className="mt-1 max-h-40 overflow-auto rounded bg-white p-2">
{JSON.stringify(cov, null, 2)}
          </pre>
          {unknown !== undefined ? (
            <div className="mt-2 text-gray-600">
              unknown: assets lack structured tags, so coverage cannot be fully verified.
            </div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
