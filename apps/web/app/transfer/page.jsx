import TransferClient from "./TransferClient";

export const dynamic = "force-dynamic";

export default async function TransferPage({ searchParams }) {
  const enabled = process.env.EXPORT_IMPORT_UI_ENABLED !== "0";

  // Next.js may provide searchParams as a Promise (sync-dynamic-apis).
  const sp =
    searchParams && typeof searchParams.then === "function"
      ? await searchParams
      : searchParams;

  const exportId = (sp?.export_id ?? sp?.exportId ?? "").toString();

  if (!enabled) {
    return (
      <div style={{ padding: 16 }}>
        Export/Import UI disabled.
      </div>
    );
  }

  return (
    <main style={{ padding: 24, fontFamily: "ui-sans-serif, system-ui" }}>
      <h1 style={{ margin: "0 0 8px 0" }}>Export / Import</h1>
      <p style={{ margin: "0 0 16px 0" }}>
        No-Import Preview (manifest) + Controlled Import (AC-006)
      </p>
      <TransferClient initialExportId={exportId} />
    </main>
  );
}
