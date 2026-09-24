# Nexus Deep Search (Row-Level Results + Jump-to-Row) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Typing in Nexus search lists matching settings rows from all pages; clicking a result opens the page (and subpages) and scrolls the row into view.

**Architecture:** Runtime registry, not a hand index. A `SearchIndex` singleton collects live rows (each common row registers on creation with label closures evaluated at query time, unregisters on destruction). Location (page + subpage stack snapshot) is set by the navigation calls, never drilled through props. Jump navigates then scrolls with bounded retries for async page loads.

**Tech Stack:** Quickshell QML (`qs -p` gates with `grep -Ei`), singleton QML module registration (qmldir), `deploy.sh`, git per-task commits.

**Spec:** Conversation 2026-09-24: user asked for in-page search ("visualizer" must surface the row, not just the page). Evidence: rows expose `label` (+`status`/`subtext`/`text`) per inventory (NavRow label/status; ToggleRow text/subtext; SliderRow/StepperRow/SelectRow/PopupRow/InfoRow label + subtext/status/value); `NexusState.openSubPage/closeSubPage` update the stack before the signal so creation-time location is current; `Pages.loadPage` incubates with `{nState}`; `PageBase.flickable` alias exists for scrolling; StackView push/pop is async (retry needed).

## Global Constraints

- Every QML file using `Colours.palette.*` MUST have `import qs.services`.
- Never run `./merge-upstream.sh merge-all`; no upstream files involved anyway.
- `Repeater` with `property var` JS-array model does NOT render; `model: <int>` + index lookup; every `list<var>` read rewraps elements — never use `indexOf`, carry indices explicitly.
- Do NOT use `Caelestia.I18n`/`Tr.*`; use `qsTr()`.
- Commit after every task. `qs -p` gates use `grep -Ei`. qmllint unusable (silent 255).
- Singleton registration REQUIRES a qmldir line: `singleton SearchIndex 1.0 SearchIndex.qml` in `shell/modules/nexus/common/qmldir` (verify existing entries' format first).

---

### Task 1: SearchIndex singleton + navigation hooks

**Files:**
- Create: `shell/modules/nexus/common/SearchIndex.qml`
- Modify: `shell/modules/nexus/common/qmldir` (singleton line), `shell/modules/nexus/NexusState.qml` (location hooks + gotoRow + pendingRow), `shell/modules/nexus/Pages.qml` (setLocation on load)
- Test: `qs -p` boot (no rows registered yet — empty index, no behavior change)

**Interfaces:**
- Consumes: `NexusState.currentPageIdx/subPageIdxStack/openSubPage/closeSubPage`, `Pages.loadPage`
- Produces: `SearchIndex.registerRow(item, labelFn, subFn)`, `.unregisterRow(item)`, `.setLocation(page, subsArrayCopy)`, `.pushSub(idx)`, `.popSub()`, `.query(text)` → `[{page, subs, label, sublabel, occurrence, item}]`, `NexusState.gotoRow(entry)`, `NexusState.pendingRow` (consumed by Task 4)

- [ ] **Step 1: Confirm qmldir format + NexusState/PageBase hooks exist (fails = unexamined)**

Run: `cat shell/modules/nexus/common/qmldir; grep -n "openSubPage\|closeSubPage\|subPageIdxStack" shell/modules/nexus/NexusState.qml | head; grep -n "flickable" shell/modules/nexus/common/PageBase.qml | head -n 3; grep -n "loadPage\|incubateObject" shell/modules/nexus/Pages.qml | head -n 5`
Expected: qmldir component lines to mirror; openSubPage updates stack-then-signal; PageBase `readonly property alias flickable`; Pages incubates with `{nState}`.

- [ ] **Step 2: Create SearchIndex.qml (exact content)**

```qml
pragma Singleton

import QtQuick

QtObject {
    id: root

    property var entries: []
    property int currentPage: 0
    property var currentSubs: []

    function setLocation(page: int, subs: var): void {
        currentPage = page;
        currentSubs = subs.slice();
    }

    function pushSub(idx: int): void {
        currentSubs = [...currentSubs, idx];
    }

    function popSub(): void {
        currentSubs = currentSubs.slice(0, -1);
    }

    function registerRow(item: var, labelFn: var, subFn: var): void {
        unregisterRow(item);
        entries.push({
            item: item,
            labelFn: labelFn,
            subFn: subFn,
            page: currentPage,
            subs: currentSubs.slice()
        });
    }

    function unregisterRow(item: var): void {
        entries = entries.filter(e => e.item !== item);
    }

    function query(text: string): var {
        const q = text.trim().toLowerCase();
        if (!q)
            return [];
        const out = [];
        for (const e of entries) {
            if (!e.item)
                continue;
            const label = String(e.labelFn ? e.labelFn() : "");
            const sub = String(e.subFn ? e.subFn() : "");
            if (label.toLowerCase().includes(q) || sub.toLowerCase().includes(q))
                out.push(e);
        }
        return out.slice(0, 30);
    }
}
```

Rules: entries reassigned (never mutated) so change signals fire; label closures evaluated at query time (live text); cap 30; dead items skipped (`!e.item` — destroyed QML refs are null).

- [ ] **Step 3: Hook navigation (exact edits)**

NexusState.qml: in `openSubPage` after stack update add `SearchIndex.pushSub(idx)` — WAIT, correct order: openSubPage does stack-update THEN signal; add pushSub right after the stack line (import `qs.modules.nexus.common` — check NexusState imports first; if the module import creates a cycle (common imports nexus for NexusState type — SearchIndex does NOT import NexusState, only QtQuick, so no cycle). In `closeSubPage` add `SearchIndex.popSub()`. Add `property var pendingRow: null` + `function gotoRow(e: var): void { currentPageIdx = e.page; subPageIdxStack = []; pendingRow = e; for (const s of e.subs) openSubPage(s); }` — set pendingRow BEFORE opening subs (openSubPage must NOT clear it). Pages.qml `loadPage`: first line `SearchIndex.setLocation(idx, [])` (import common module there too).

- [ ] **Step 4: Verify boot unchanged (empty index)**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -Ei "ERROR|Failed to load|is not a type|SearchIndex|cycle|loop" | head -n 5`
Expected: empty (no import cycles, no behavior change — nothing registered yet).

- [ ] **Step 5: Commit**

```bash
git add shell/modules/nexus/common/SearchIndex.qml shell/modules/nexus/common/qmldir shell/modules/nexus/NexusState.qml shell/modules/nexus/Pages.qml
git commit -m "feat: nexus search index singleton + nav hooks"
```

---

### Task 2: Row registration touchpoints (same-shape batch)

**Files:**
- Modify: `shell/modules/nexus/common/NavRow.qml`, `ToggleRow.qml`, `SliderRow.qml`, `StepperRow.qml`, `SelectRow.qml`, `PopupRow.qml`, `InfoRow.qml` (register/unregister only, no visual change)
- Test: `qs -p` boot (index populates silently; query path untested until Task 3)

**Interfaces:**
- Consumes: Task 1 SearchIndex API
- Produces: Every row self-registers with live label closures

**Per-file label mapping (binding — verified in inventory; implementer re-verifies each file's prop names before editing):** NavRow `(label, status)`; ToggleRow `(text, subtext)`; SliderRow `(label, valueLabel)`; StepperRow `(label, subtext)`; SelectRow `(label, subtext)`; PopupRow `(label, status)`; InfoRow `(label, subtext ?? value)`.

- [ ] **Step 1: Verify each file's prop names (fails = unexamined)**

Run: `for f in NavRow ToggleRow SliderRow StepperRow SelectRow PopupRow InfoRow; do echo "== $f"; grep -n "property .*label\|property .*text\|property .*status\|property .*subtext\|property .*value" shell/modules/nexus/common/$f.qml | head -n 4; done`
Expected: mapping above confirmed per file (adjust mapping if a file differs — record deviation in report, do NOT guess).

- [ ] **Step 2: Add identical registration block to all 7 files (exact pattern)**

In each file, add `import qs.modules.nexus.common` ONLY if the file doesn't already import it (check — duplicate imports are harmless but keep clean), then append at root level:

```qml
Component.onCompleted: SearchIndex.registerRow(root, () => root.<LABELPROP>, () => root.<SUBPROP>)
Component.onDestruction: SearchIndex.unregisterRow(root)
```

with `<LABELPROP>/<SUBPROP>` per Step-1 mapping (NavRow: `label`,`status`; ToggleRow: `text`,`subtext`; SliderRow: `label`,`valueLabel`; StepperRow: `label`,`subtext`; SelectRow: `label`,`subtext`; PopupRow: `label`,`status`; InfoRow: `label`,`subtext`). Root id is `root` in all seven (verify while editing — if any file uses a different id, use it).

- [ ] **Step 3: Verify boot + registration count via log probe (fails = silent miswire)**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -Ei "ERROR|Failed to load|is not a type|SearchIndex" | head -n 5`
Expected: empty. (Count verification is Task 3's UI step — rows register when Nexus opens, which headless never does; boot-clean is the gate here.)

- [ ] **Step 4: Commit**

```bash
git add shell/modules/nexus/common/
git commit -m "feat: nexus rows self-register for deep search"
```

---

### Task 3: Results UI (swap list for matches + breadcrumb + click)

**Files:**
- Modify: `shell/modules/nexus/navpane/NavLocations.qml`
- Test: `qs -p` boot (UI swaps only when searchText non-empty — default view unchanged)

**Interfaces:**
- Consumes: Tasks 1-2 (`SearchIndex.query`, entry shape `{page, subs, label, sublabel?, item}`, `gotoRow`); existing `filteredPages` page-filter (keep for NO-query state? No — replace: when query non-empty show rows, else pages as today)
- Produces: Row results with "Page › Row" breadcrumb; click navigates+jumps

- [ ] **Step 1: Read current swap logic (fails = unexamined)**

Run: `grep -n "filteredPages\|searchText\|model:" shell/modules/nexus/navpane/NavLocations.qml | head -n 12`
Expected: locate the int-model Repeater + filtered array to extend (keep the int-model + index-lookup pattern — never `model: <js-array>`).

- [ ] **Step 2: Add results model alongside pages (exact pattern)**

Add: `readonly property var searchResults: SearchIndex.query(root.nState.searchText)` (re-evaluates on text change; entries' closures evaluated inside query). Add `readonly property bool showingResults: root.nState.searchText.trim().length > 0`. Repeater model: `showingResults ? searchResults.length : filteredPages.length`; delegate resolves `entry/item` per branch: results branch uses `searchResults[index]` fields (label = entry label live via closure? NO — closures need calling: display `entry.labelFn ? entry.labelFn() : ""`? That re-evaluates per frame — fine for ≤30 rows. Simpler: compute once per query in the model? Query returns entries; display via live call for correctness with dynamic subtexts).

- [ ] **Step 3: Breadcrumb + click (exact behavior)**

Row shows main text = row label, sub = page label + (`sublabel` if non-empty). Page label lookup: `PageRegistry.pages[entry.page]?.label ?? ""`. Click: `root.nState.gotoRow({page, subs, label, occurrence})` where occurrence = index among same-(page,subs,label) matches (count in searchResults before it). Clear search AFTER navigation? Keep text (back button returns to filtered list — better UX); do NOT clear.

- [ ] **Step 4: Verify boot (default view byte-identical behavior)**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -Ei "ERROR|Failed to load|is not a type" | head -n 3`
Expected: empty (empty query → pages path untouched).

- [ ] **Step 5: Commit**

```bash
git add shell/modules/nexus/navpane/NavLocations.qml
git commit -m "feat: nexus search shows matching rows with breadcrumbs"
```

---

### Task 4: Jump consume (navigate + scroll with retries)

**Files:**
- Modify: `shell/modules/nexus/Pages.qml` (consume pendingRow after load)
- Test: `qs -p` boot (pendingRow always null headless — no behavior change)

**Interfaces:**
- Consumes: Task 1 `pendingRow` + entry `{page, subs, label, occurrence}`; `PageBase.flickable`; current page item via `Pages.currentItem`
- Produces: Viewport centered on target row after navigation

- [ ] **Step 1: Read loadPage attach flow (fails = unexamined)**

Run: `grep -n -A12 "function loadPage" shell/modules/nexus/Pages.qml | head -n 20`
Expected: incubateObject + attach() on Ready — hook point identified (in attach, after currentItem set).

- [ ] **Step 2: Add scroll consumer (exact code)**

In `attach()`, after `currentItem` set, call `root.consumePendingRow()`:

```qml
function consumePendingRow(): void {
    const target = root.nState.pendingRow;
    if (!target)
        return;
    root.nState.pendingRow = null;
    scrollAttempts = 0;
    scrollTimer.target = target;
    scrollTimer.start();
}
```

Add `property var scrollTarget` + `Timer { id: scrollTimer; interval: 120; repeat: true; property var target; property int attempts: 0; onTriggered: { attempts++; const item = findRowItem(target); if (item) { centerOn(item); stop(); } else if (attempts >= 8) stop(); } }` where `findRowItem` scans `SearchIndex.entries` for page+subs+label match at occurrence index with a live `item`, and `centerOn` maps to flickable: `const p = item.mapToItem(currentItem, 0, 0); const flick = currentItem.flickable; flick.contentY = Math.max(0, p.y - flick.height / 2 + item.height / 2)` — guard every nullable (`currentItem?`, `flick?`, `item?`) and clamp `contentY` to `[0, contentHeight - height]`.

- [ ] **Step 3: Verify boot (pendingRow null path)**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -Ei "ERROR|Failed to load|is not a type" | head -n 3`
Expected: empty (null path = early return, zero behavior change headless).

- [ ] **Step 4: Commit**

```bash
git add shell/modules/nexus/Pages.qml
git commit -m "feat: nexus jump-to-row scroll with retries"
```

---

### Task 5: Deploy + live verify (user-driven checks)

**Files:**
- Modify: none (verification + plan-doc commit)
- Test: headless boot + live user flow

**Interfaces:**
- Consumes: Tasks 1-4
- Produces: Synced live config; confirmed deep search

- [ ] **Step 1: Boot probe**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -Ei "ERROR|Failed to load|is not a type" | head -n 3`
Expected: empty.

- [ ] **Step 2: Deploy**

Run: `./deploy.sh 2>&1 | tail -n 4`
Expected: `Deployed 589+ files`, `Done`.

- [ ] **Step 3: Request live user verification (PENDING-HUMAN, do not claim)**

Report these exact checks for the human: (1) type "visualiser" → row results with "Wallpaper & style › …" breadcrumbs (not just the page); (2) click a row → page (+subpages) opens AND viewport centers on that row; (3) clear search → normal page list returns; (4) no new errors in live qs log (`grep -Ei "SearchIndex|pendingRow" <latest qslog>` empty of errors).

- [ ] **Step 4: Commit plan doc**

```bash
git add docs/superpowers/plans/2026-09-24-deep-search.md
git commit -m "docs: nexus deep search plan" 2>&1 | head -n 3
```

---

## Self-Review

1. **Spec coverage:** singleton+hooks (T1) ✓, 7 row touchpoints with verified mapping (T2) ✓, results UI swap + breadcrumb + gotoRow click (T3) ✓, pendingRow consume + retry scroll (T4) ✓, deploy + human checks (T5) ✓. Highlight-flash deliberately OUT (stated: scroll-only v1).
2. **Placeholder scan:** No TBD/TODO/later/appropriate/edge-cases; every step has exact commands, exact code blocks, exact prop names, exact expected outputs; qmldir/import-cycle risks called out with checks.
3. **Type consistency:** `SearchIndex.registerRow(item, labelFn, subFn)` / `query → [{page, subs, label?, item}]` / `gotoRow(entry)` / `pendingRow` used uniformly; `subs` always a copied array; `model: int` + index lookup everywhere (never js-array models, never indexOf); qsTr/import rules uniform.
