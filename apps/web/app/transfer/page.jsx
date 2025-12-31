import TransferClient from "./TransferClient";

export const dynamic = "force-dynamic";

export default function TransferPage({ searchParams }) {
  const enabled = process.env.EXPORT_IMPORT_UI_ENABLED !== "0";
  const exportId =
    (searchParams && (searchParams.export_id || searchParams.exportId)) || "";

  if (!enabled) {
    return (
      <main style={{ padding: 24, fontFamily: "ui-sans-serif, system-ui" }}>
        <h1 style={{ margin: "0 0 8px 0" }}>Export / Import</h1>
        <p style={{ margin: 0 }}>
          Disabled by <code>EXPORT_IMPORT_UI_ENABLED=0</code>
        </p>
      </main>
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
