import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function ProjectDetailPage({ params }) {
  const p = (params && typeof params.then === "function") ? await params : (params || {});
  const id = p?.project_id || "unknown";

  return (
    <div style={{ padding: 16 }}>
      <div style={{ display: "flex", justifyContent: "space-between", gap: 12, alignItems: "baseline" }}>
        <h1 style={{ margin: 0 }}>Project Detail</h1>
        <div style={{ display: "flex", gap: 10, fontSize: 14 }}>
          <Link href="/projects">Back</Link>
          <Link href="/library">Library</Link>
        </div>
      </div>
      <div style={{ marginTop: 8, fontSize: 13, opacity: 0.85 }}>
        project_id: <code>{id}</code>
      </div>
      <div className="card" style={{ marginTop: 12 }}>
        Placeholder detail page (P0/P1). Safe params handling for Next sync-dynamic-apis.
      </div>
    </div>
  );
}
