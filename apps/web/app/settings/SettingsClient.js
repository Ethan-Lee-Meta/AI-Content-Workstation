"use client";

import { useState } from "react";

export default function SettingsClient() {
  const [open, setOpen] = useState(false);

  return (
    <div style={{ padding: 16, display: "grid", gap: 12 }}>
      <header style={{ display: "grid", gap: 6 }}>
        <h1 style={{ margin: 0 }}>Settings</h1>
        <p style={{ margin: 0, opacity: 0.75 }}>
          Skeleton page (v1.1 STEP-080). ProviderProfiles management will be delivered in later batches.
        </p>
      </header>

      <section style={{ border: "1px solid rgba(255,255,255,0.12)", borderRadius: 12, padding: 12 }}>
        <h2 style={{ margin: "0 0 8px 0", fontSize: 16 }}>Provider Profiles</h2>

        <div style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap" }}>
          <button type="button" onClick={() => setOpen(true)} style={{ padding: "6px 10px" }}>
            + New Profile (placeholder)
          </button>
          <span style={{ fontSize: 12, opacity: 0.8 }}>
            Default profile: <b>[placeholder]</b>
          </span>
        </div>

        <div style={{ marginTop: 10, opacity: 0.85 }}>
          <div>• [profile_id] [provider_type] [status] [is_default]</div>
          <div>• [profile_id] [provider_type] [status] [is_default]</div>
        </div>

        <div style={{ marginTop: 10, fontSize: 12, opacity: 0.75 }}>
          Secrets policy: secrets are never shown in plaintext. UI should only display “configured” status.
        </div>

        <div style={{ marginTop: 8, fontSize: 12, opacity: 0.7 }}>
          Future APIs (via api_proxy): <code>/api_proxy/provider_types</code> and <code>/api_proxy/provider_profiles</code>
        </div>
      </section>

      {open && (
        <section style={{ border: "1px dashed rgba(255,255,255,0.25)", borderRadius: 12, padding: 12 }}>
          <h2 style={{ margin: "0 0 8px 0", fontSize: 16 }}>Create Provider Profile (placeholder)</h2>
          <div style={{ fontSize: 12, opacity: 0.85 }}>
            This dialog will be wired to backend in later batches. Close to continue.
          </div>
          <div style={{ marginTop: 10, display: "flex", gap: 8 }}>
            <button type="button" onClick={() => setOpen(false)}>Close</button>
            <button type="button" disabled>Create (disabled)</button>
          </div>
        </section>
      )}

      <section style={{ border: "1px dashed rgba(255,255,255,0.25)", borderRadius: 12, padding: 12 }}>
        <h2 style={{ margin: "0 0 8px 0", fontSize: 16 }}>Error (placeholder)</h2>
        <div style={{ fontSize: 12, opacity: 0.85 }}>
          If an API call fails, show the error envelope and request_id here. Provide request_id when reporting issues.
        </div>
        <div style={{ marginTop: 6, fontSize: 12, opacity: 0.75 }}>
          request_id: <code>__REQUEST_ID__</code>
        </div>
      </section>
    </div>
  );
}
