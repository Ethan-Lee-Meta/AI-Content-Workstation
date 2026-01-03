# EVIDENCE — AC-005 (UI Interaction Depth <= 3)

## AC-005 Requirement
核心任务（从首页发起生成并查看结果）交互层级（页面/弹层）<= 3。

> 交互层级定义（用于本证据与 gates 机检）  
> - **层** = 用户需要显式进入的“页面(route)”或“模态弹层(modal)”之一。  
> - 同一页面内的区块切换/滚动/区域刷新不增加层级。  

## Confirmed Core Task Path (Depth Count)
- interaction_layers_count: 2

### Layer 1 — Home
- Route: `/`
- Action: 点击直达 `/generate` 的入口（无需先进入其它中间页）

### Layer 2 — Generate + Results (same page)
- Route: `/generate`
- Actions:
  1) 在同一页完成“提交生成”
  2) 在同一页的 ResultsPanel 查看结果（无需打开新页面或弹层）

## Evidence Pointers (Code Markers)
- Home has direct `/generate` entry:
  - `apps/web/app/page.js` contains `href="/generate"` (e.g. "Open Generate")
  - Sidebar also contains `/generate` item (`apps/web/app/_components/Sidebar.js`)
- Generate page contains stable section markers:
  - `apps/web/app/generate/GenerateClient.js` contains:
    - `InputTypeSelector`
    - `PromptEditor`
    - `RunQueuePanel`
    - `ResultsPanel`

## Notes / Risk
- 功能闭环（提交生成与结果刷新）由 P0 gates（如 AC-003）已覆盖；本 AC-005 仅固化“交互层级”约束与证据。
