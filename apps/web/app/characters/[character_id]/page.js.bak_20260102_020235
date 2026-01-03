export const metadata = { title: "Character Detail — AI Content Workstation" };

// Keep async to be compatible with Next "sync-dynamic-apis" style promise unwrap changes.
export default async function CharacterDetailPage({ params }) {
  const p = await params;
  const characterId = p?.character_id || "(missing)";

  return (
    <div style={{ padding: 16, display: "grid", gap: 12 }}>
      <header style={{ display: "grid", gap: 6 }}>
        <h1 style={{ margin: 0 }}>Character Detail</h1>
        <div style={{ fontSize: 12, opacity: 0.75 }}>
          character_id: <code>{String(characterId)}</code>
        </div>
        <p style={{ margin: 0, opacity: 0.75 }}>
          Skeleton page (v1.1 STEP-080). RefSets + reference assets UI will be delivered in later batches.
        </p>
      </header>

      <section style={{ border: "1px solid rgba(0,0,0,0.1)", borderRadius: 12, padding: 12 }}>
        <h2 style={{ margin: "0 0 8px 0", fontSize: 16 }}>Profile Summary (placeholder)</h2>
        <div style={{ opacity: 0.8 }}>
          <div>name: [placeholder]</div>
          <div>status: [placeholder]</div>
          <div>active_ref_set_id: [placeholder]</div>
        </div>
        <div style={{ marginTop: 8, fontSize: 12, opacity: 0.7 }}>
          Future API (via api_proxy): <code>/api_proxy/characters/{String(characterId)}</code>
        </div>
      </section>

      <section style={{ border: "1px solid rgba(0,0,0,0.1)", borderRadius: 12, padding: 12 }}>
        <h2 style={{ margin: "0 0 8px 0", fontSize: 16 }}>Ref Sets (placeholder)</h2>
        <div style={{ opacity: 0.8 }}>
          <div>• [ref_set_id] [draft|confirmed] [created_at]</div>
          <div>• [ref_set_id] [draft|confirmed] [created_at]</div>
        </div>
      </section>

      <section style={{ border: "1px solid rgba(0,0,0,0.1)", borderRadius: 12, padding: 12 }}>
        <h2 style={{ margin: "0 0 8px 0", fontSize: 16 }}>Reference Assets (placeholder)</h2>
        <div style={{ opacity: 0.8 }}>
          <div>[asset grid placeholder]</div>
        </div>
      </section>

      <section style={{ border: "1px dashed rgba(0,0,0,0.25)", borderRadius: 12, padding: 12 }}>
        <h2 style={{ margin: "0 0 8px 0", fontSize: 16 }}>Error (placeholder)</h2>
        <div style={{ fontSize: 12, opacity: 0.85 }}>
          If an API call fails, show the error envelope and request_id here.
        </div>
        <div style={{ marginTop: 6, fontSize: 12, opacity: 0.75 }}>
          request_id: <code>__REQUEST_ID__</code>
        </div>
      </section>
    </div>
  );
}
