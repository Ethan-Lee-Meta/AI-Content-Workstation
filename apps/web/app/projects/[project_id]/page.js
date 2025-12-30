export default function ProjectDetailPage({ params }) {
  const id = params?.project_id || "unknown";
  return (
    <div className="card">
      <h1 style={{ margin: 0 }}>Project Detail</h1>
      <p className="cardHint">project_id: <span className="mono">{id}</span></p>
      <p className="cardHint">Placeholder route required by IA lock.</p>
    </div>
  );
}
