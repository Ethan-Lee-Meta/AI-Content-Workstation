"use client";

export default function Topbar({ ctx }) {
  return (
    <header className="topbar">
      <div className="search">
        <input
          placeholder="Omnibox (P0 placeholder) — search assets / runs / prompts"
          onChange={() => {}}
        />
      </div>
      <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
        <span className="badge mono">{ctx.pathname}</span>
        <button className="btn" onClick={() => ctx.toggleInspector()}>
          Toggle Inspector
        </button>
      </div>
    </header>
  );
}
