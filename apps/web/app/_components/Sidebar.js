"use client";

import Link from "next/link";

const NAV = [
  { href: "/", label: "Home" },
  { href: "/library", label: "Library" },
  { href: "/generate", label: "Generate" },
  { href: "/projects", label: "Projects" },
  { href: "/series", label: "Series" },
  { href: "/shots", label: "Shots" },
  { href: "/trash", label: "Trash" },
];

export default function Sidebar({ ctx }) {
  return (
    <aside className="sidebar">
      <div className="brand">
        <div className="brandDot" />
        <div style={{ minWidth: 0 }}>
          <div className="brandTitle">AI Content Workstation</div>
          <div className="brandSub">P0 • App Shell + Routes</div>
        </div>
      </div>

      <nav className="nav">
        {NAV.map((n) => {
          const active = ctx.pathname === n.href;
          return (
            <Link
              key={n.href}
              href={n.href}
              className={"navItem " + (active ? "navItemActive" : "")}
            >
              <span>{n.label}</span>
              {active ? <span className="badge">active</span> : <span className="badge">route</span>}
            </Link>
          );
        })}
      </nav>

      <div style={{ marginTop: 14 }} className="card">
        <div className="cardTitle" style={{ fontSize: 14 }}>Required Routes</div>
        <p className="cardHint">All must exist (placeholders allowed):</p>
        <div className="kv">
          <span>/</span><b className="mono">home</b>
          <span>/library</span><b className="mono">overview</b>
          <span>/assets/:id</span><b className="mono">detail</b>
          <span>/generate</span><b className="mono">run</b>
          <span>/projects/*</span><b className="mono">placeholder</b>
          <span>/series/*</span><b className="mono">placeholder</b>
          <span>/shots/*</span><b className="mono">placeholder</b>
        </div>
      </div>
    </aside>
  );
}
