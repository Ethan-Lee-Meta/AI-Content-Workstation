export default async function Page() {
  return (
    <main>
      <h1>AI Content Workstation</h1>
      <p>Frontend is up. Next: connect to API /health on :7000.</p>
      <ul>
        <li>Web: http://127.0.0.1:2000</li>
        <li>API: http://127.0.0.1:7000/health</li>
        <li>OpenAPI: http://127.0.0.1:7000/openapi.json</li>
      </ul>
    </main>
  );
}
