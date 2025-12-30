"use client";

export default function InspectorDrawer({ ctx }) {
  if (!ctx.inspector.open) {
    return (
      <aside className="inspector">
        <div className="inspectorHeader">
          <div style={{ fontWeight: 700 }}>Inspector</div>
          <button className="btn" onClick={() => ctx.toggleInspector()}>Open</button>
        </div>
        <p className="cardHint">Closed.</p>
      </aside>
    );
  }

  const payload = ctx.inspector.payload || {};
  return (
    <aside className="inspector">
      <div className="inspectorHeader">
        <div style={{ fontWeight: 700, minWidth: 0, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
          {ctx.inspector.title || "Inspector"}
        </div>
        <button className="btn" onClick={() => ctx.closeInspector()}>Close</button>
      </div>

      <div className="card">
        <div className="cardTitle" style={{ fontSize: 14 }}>Debug</div>
        <p className="cardHint">
          P0 要求：错误态至少可见 <span className="mono">request_id</span>。后续 AC-001..004 会在这里与页面错误面板展示。
        </p>
        <div className="kv">
          <span>pathname</span><b className="mono">{ctx.pathname}</b>
          <span>hint</span><b>{String(payload.hint || "—")}</b>
        </div>
      </div>

      <div style={{ marginTop: 12 }} className="notice">
        当前为 STEP-060：仅保证 App Shell 与路由骨架可访问、不崩溃。业务数据与 API 调用在后续 STEP-065..080 接入。
      </div>
    </aside>
  );
}
