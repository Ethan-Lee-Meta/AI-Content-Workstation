export default function ShotDetailPage({ params }) {
  const id = params?.shot_id || "unknown";
  return (
    <div className="card">
      <h1 style={{ margin: 0 }}>Shot Detail</h1>
      <p className="cardHint">shot_id: <span className="mono">{id}</span></p>
      <p className="cardHint">Placeholder route required by IA lock.</p>
    </div>
  );
}
