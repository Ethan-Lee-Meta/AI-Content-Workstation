export default function HomePage() {
  return (
    <div className="grid">
      <section className="card" style={{ gridColumn: "span 12" }}>
        <h1 style={{ margin: 0 }}>Home</h1>
        <p className="cardHint">
          Sections required: QuickActions / RecentAssets / StatusPanel (P0 placeholders)
        </p>
      </section>

      <section className="card" style={{ gridColumn: "span 5" }}>
        <h2 className="cardTitle">QuickActions</h2>
        <p className="cardHint">Go to Library / Generate / Review (wired later)</p>
        <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
          <a className="btn" href="/library">Open Library</a>
          <a className="btn" href="/generate">Open Generate</a>
          <a className="btn" href="/assets/demo-asset">Open Demo Detail</a>
        </div>
      </section>

      <section className="card" style={{ gridColumn: "span 4" }}>
        <h2 className="cardTitle">RecentAssets</h2>
        <p className="cardHint">Empty-state safe render (data later)</p>
        <div className="badge">No data loaded</div>
      </section>

      <section className="card" style={{ gridColumn: "span 3" }}>
        <h2 className="cardTitle">StatusPanel</h2>
        <p className="cardHint">Backend health + gates summary (later)</p>
        <div className="kv">
          <span>web</span><b className="mono">ok</b>
          <span>api</span><b className="mono">pending</b>
        </div>
      </section>
    </div>
  );
}
