export default function SeriesDetailPage({ params }) {
  const id = params?.series_id || "unknown";
  return (
    <div className="card">
      <h1 style={{ margin: 0 }}>Series Detail</h1>
      <p className="cardHint">series_id: <span className="mono">{id}</span></p>
      <p className="cardHint">Placeholder route required by IA lock.</p>
    </div>
  );
}
