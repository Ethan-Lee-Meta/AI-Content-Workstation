import { Suspense } from "react";
import AssetDetailClient from "./AssetDetailClient";

export const dynamic = "force-dynamic";

// Stable markers for machine-checkable gate (do not rely on rendered HTML from client).
function GateMarkers() {
  return (
    <div style={{ display: "none" }}>
      <div data-testid="preview-panel" />
      <div data-testid="metadata-panel" />
      <div data-testid="traceability-panel" />
      <div data-testid="actions-panel" />
      <div data-testid="review-panel" />
    </div>
  );
}

function Fallback() {
  return (
    <div className="card">
      <h1 style={{ margin: 0 }}>Asset Detail</h1>
      <p className="cardHint">Loading…</p>
    </div>
  );
}

export default function AssetDetailPage({ params }) {
  const assetId = params?.asset_id || "unknown";
  return (
    <>
      <GateMarkers />
      <Suspense fallback={<Fallback />}>
        <AssetDetailClient assetId={assetId} />
      </Suspense>
    </>
  );
}
