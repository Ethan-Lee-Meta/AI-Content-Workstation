import Link from 'next/link';
import ReviewPanelClient from './ReviewPanelClient';

export const dynamic = 'force-dynamic';

export default async function AssetDetailPage({ params }) {
  const p = (params && typeof params.then === "function") ? await params : (params || {});
  const assetId = p?.asset_id || 'unknown';
  return (
    <div style={{ padding: 16 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, alignItems: 'baseline' }}>
        <h1 style={{ margin: 0 }}>Asset Detail</h1>
        <div style={{ display: 'flex', gap: 10, fontSize: 14 }}>
          <Link href="/library">Back to Library</Link>
          <Link href="/generate">Generate</Link>
        </div>
      </div>

      <div style={{ marginTop: 8, fontSize: 13, opacity: 0.8 }}>
        asset_id: <code>{assetId}</code>
      </div>

      <div style={{ marginTop: 16, display: 'grid', gap: 12 }}>
        <section style={{ border: '1px solid #eee', borderRadius: 10, padding: 12 }}>
          <div style={{ fontWeight: 700 }}>PreviewPanel</div>
          <div style={{ fontSize: 13, opacity: 0.8, marginTop: 6 }}>
            Preview is shown when an asset has a resolvable URL/path (client-side render in later batches).
          </div>
        </section>

        <section style={{ border: '1px solid #eee', borderRadius: 10, padding: 12 }}>
          <div style={{ fontWeight: 700 }}>MetadataPanel</div>
          <div style={{ fontSize: 13, opacity: 0.8, marginTop: 6 }}>
            Minimal metadata: <code>asset_id</code> is visible; additional fields come from API payload.
          </div>
        </section>

        <section style={{ border: '1px solid #eee', borderRadius: 10, padding: 12 }}>
          <div style={{ fontWeight: 700 }}>TraceabilityPanel</div>
          <div style={{ fontSize: 13, opacity: 0.8, marginTop: 6 }}>
            Traceability links will be surfaced here (Links graph / run lineage) in later batches.
          </div>
        </section>

        <section style={{ border: '1px solid #eee', borderRadius: 10, padding: 12 }}>
          <div style={{ fontWeight: 700 }}>ActionsPanel</div>
          <div style={{ display: 'flex', gap: 10, marginTop: 8, flexWrap: 'wrap' }}>
            <Link href="/library">Open in Library</Link>
            <Link href={`/assets/${assetId}`}>Refresh</Link>
          </div>
        </section>

        <section style={{ border: '1px solid #eee', borderRadius: 10, padding: 12 }}>
          <ReviewPanelClient assetId={assetId} />
        </section>
      </div>
    </div>
  );
}
