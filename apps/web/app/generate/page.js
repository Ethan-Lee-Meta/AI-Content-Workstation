import GenerateClient from "./GenerateClient";

export default function Page({ searchParams }) {
  const initialType = (searchParams && searchParams.type) ? String(searchParams.type) : "t2i";
  return (
    <div style={{ padding: 16 }}>
      <h1 style={{ margin: "0 0 8px 0" }}>Generate</h1>
      <div style={{ color: "#666", marginBottom: 12 }}>
        AC-003: t2i / i2i / t2v / i2v — submit run, refresh status, show results (via /api_proxy).
      </div>
      <GenerateClient initialType={initialType} />
    </div>
  );
}
