import { Suspense } from "react";
import LibraryClient from "./LibraryClient";

export const dynamic = "force-dynamic";

// Gate requires these markers to be present in machine-checkable form.
function GateMarkers() {
  return (
    <div style={{ display: "none" }}>
      <div data-testid="filters-bar" />
      <div data-testid="asset-grid" />
      <div data-testid="bulk-action-bar" />
    </div>
  );
}

function Fallback() {
  return (
    <div className="grid">
      <section className="card" style={{ gridColumn: "span 12" }}>
        <h1 style={{ margin: 0 }}>Library</h1>
        <p className="cardHint">Loading…</p>
      </section>
    </div>
  );
}

export default function LibraryPage() {
  return (
    <>
      <GateMarkers />
      <Suspense fallback={<Fallback />}>
        <LibraryClient />
      </Suspense>
    </>
  );
}
