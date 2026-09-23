# Bar Best-of-Both (Upstream Design + Custom Layout) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the upstream bar workspaces engine, popout designs, and component polish while keeping the custom Item-split layout, right-edge mirroring, and preview hooks.

**Architecture:** Keep-our-skeleton-port-their-organs. `Bar.qml` stays `Item`+`topLayout/bottomLayout` (no `pragma Bound`, no `DelegateChooser`, no `ColumnLayout` root — AGENTS.md rules). Workspaces engine is rebuilt on upstream logic with custom hooks re-attached. Small popouts triaged classify-first (Tr-only diffs skipped). One rebuild+install+deploy at the end covers this plan; backend-batch install is a PREREQUISITE (its keys/list underpin nothing here except GapMarkers' AnimatedRepeater — verify installed state in Task 6, install both together if needed).

**Tech Stack:** Quickshell QML (`qs -p` gates with `grep -Ei`), C++ config keys on old framework (Task-1-of-backend-batch pattern), `deploy.sh`, git per-task commits.

**Spec:** Conversation 2026-09-22: user chose bar best-of-both (3rd of 3 workstreams after backend batch; VPN excluded). Depth evidence same day: 29 bar diffs ranked (Workspaces 468, SpecialWorkspaces 442, Workspace 365, Bar 350, OccupiedBg 196, ActiveIndicator 113, BarWrapper 112, rest ≤96); `status/` subdir (BatteryStatus/BluetoothStatus/LockStatus) exists only upstream; custom `Audio.qml` still referenced by StatusIcons (`name: "audio"`) + Content (`LocalPopouts.Audio` ×2); `WorkspacePreview.qml` custom-only hooks into workspaces internals; StatusIcons already converged (390 diff = framework difference, NOT in scope).

## Global Constraints

- `Bar.qml` root stays `Item` with `topLayout/bottomLayout` + `activeWindowLoader`; NO `pragma ComponentBehavior: Bound`, NO `ColumnLayout` root, NO `DelegateChooser` restore.
- `BarWrapper` height from parent anchors only (top+bottom vertical, left+right horizontal); popout widths via Tokens, never hardcoded pixels.
- Every QML file using `Colours.palette.*` MUST have `import qs.services`.
- Never run `./merge-upstream.sh merge-all`; work file-by-file.
- `Repeater` with `property var` JS-array model does NOT render; `model: <int>` + index lookup; every `list<var>` read rewraps elements — never use `indexOf`, carry indices explicitly.
- Do NOT use `Caelestia.I18n`/`Tr.*`; use `qsTr()`. Do NOT declare `property string interface` on Nmcli models.
- Keep `shell/upstream/` read-only. Commit per task. `grep -Ei` gates (bare `|` never matches). qmllint unusable (silent 255).
- Plugin install needs sudo + shell restart: implementers NEVER run install/killall in sandbox; Task 6 runs build (no sudo needed) and reports install readiness; human runs `./build-plugin.sh` + `./deploy.sh`.

---

### Task 1: Workspaces backend keys (showUnoccupied, perMonitor on old framework)

**Files:**
- Modify: `shell/plugin/src/Caelestia/Config/barconfig.hpp` (BarWorkspaces class)
- Test: `cmake --build build` compiles (install deferred to Task 6)

**Interfaces:**
- Consumes: Old-framework CONFIG_PROPERTY conventions; upstream names/values as reference
- Produces: `Config.bar.workspaces.showUnoccupied` (bool, true), `Config.bar.workspaces.perMonitor` (bool, true). Custom `showEmptyAsNumber`/`perMonitorWorkspaces` STAY in this task (removed in Task 2 after UI migration proves out).

- [ ] **Step 1: Read BarWorkspaces class + upstream reference values (fails = unexamined)**

Run: `grep -n -B2 -A25 "class BarWorkspaces" shell/plugin/src/Caelestia/Config/barconfig.hpp | head -n 40`
Expected: existing custom keys (`shown`, `perMonitorWorkspaces`, `showEmptyAsNumber`, `overviewScale/Rows`, …). Then: `grep -n "showUnoccupied\|perMonitor\b" shell/upstream/plugin/src/Caelestia/Config/barconfig.hpp | head` for upstream defaults (expect `showUnoccupied true`, `perMonitor true` — use these values verbatim).

- [ ] **Step 2: Add the two keys (exact code, match file style)**

```cpp
CONFIG_PROPERTY(bool, showUnoccupied, true)
CONFIG_PROPERTY(bool, perMonitor, true)
```

Place beside `shown` inside BarWorkspaces. Follow neighboring macro style exactly.

- [ ] **Step 3: Verify compile (no install)**

Run: `cmake --build build -j"$(nproc)" 2>&1 | grep -Ei "error" | head -n 5`
Expected: empty (0 errors).

- [ ] **Step 4: Verify keys exist post-build (without install)**

Run: `grep -c "showUnoccupied\|perMonitor" build/qml/Caelestia/Config/caelestia-config.qmltypes 2>/dev/null || find build -name "caelestia-config.qmltypes" | head -n 3`
Expected: qmltypes path reported; count recorded for Task 6 live comparison (installed file must gain them after human install).

- [ ] **Step 5: Commit**

```bash
git add shell/plugin/src/Caelestia/Config/barconfig.hpp
git commit -m "feat(config): workspaces showUnoccupied perMonitor keys"
```

---

### Task 2: Workspaces engine port (Workspaces + Workspace + OccupiedBg + SpecialWorkspaces + ActiveIndicator)

**Files:**
- Modify: `shell/modules/bar/components/workspaces/Workspaces.qml`, `Workspace.qml`, `OccupiedBg.qml`, `SpecialWorkspaces.qml`, `ActiveIndicator.qml`, `shell/modules/nexus/pages/panels/taskbar/BarWorkspaces.qml` (UI migrates to new keys; DROP `showEmptyAsNumber`/`perMonitorWorkspaces` rows), `shell/plugin/src/Caelestia/Config/barconfig.hpp` (REMOVE the 2 custom keys after migration proves out)
- Test: `qs -p` boot (new keys read undefined pre-install → `?? true` fallbacks hold; state this)

**Interfaces:**
- Consumes: Task 1 keys (source-built, not installed); Task 4 of backend-batch (GapMarkers unguarded but Loader-inactive by default); custom `WorkspacePreview.qml` popout hooks; per-screen `Config` vs `GlobalConfig` rule (non-global props → `Config.bar.workspaces.*`)
- Produces: Upstream engine logic (wsIds filtering, LazyListView windows, animated occupied bg, special workspaces, perMonitor) on custom Item layout with right-edge + preview hooks intact; Nexus UI on upstream key names; custom key names deleted

**Keep-list (binding):** `property var bar` chain, `animationsReady` timer, `visible: !root.fullscreen || Config.general.showOverFullscreen`, right-edge mirroring branches, `workspacePreviewEnabled` popout branch + `WorkspacePreview.qml` hooks, `overviewScale/overviewRows` customs, `label:`/`status:` bridges in Nexus rows, qsTr, `import qs.services`.

- [ ] **Step 1: Diff each engine file, classify hunks (fails = unexamined)**

Run: `for f in Workspaces Workspace OccupiedBg SpecialWorkspaces ActiveIndicator; do echo "===== $f"; diff shell/modules/bar/components/workspaces/$f.qml shell/upstream/modules/bar/components/workspaces/$f.qml | grep -c "^[<>]"; done`
Expected: counts (≈468/365/196/442/113 lines) proving triage surface. Read the three structural diffs fully before touching code: upstream `wsIds` filter, `LazyListView` usage, `GapMarkers` wiring target (what `workspaces:` object does upstream pass? record exact prop names for Step 3).

- [ ] **Step 2: Port engine file-by-file, boot-checking each (order: ActiveIndicator, OccupiedBg, Workspace, SpecialWorkspaces, Workspaces)**

For each file: start from UPSTREAM base, graft the keep-list back (recover customs via `git show HEAD:<path>`). `showUnoccupied`/`perMonitor` read via `Config.bar.workspaces.*` with `?? true` fallback (pre-install safety). NEVER `model: <js-array>`; NEVER add `pragma Bound`. After EACH file: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -Ei "ERROR|Failed to load|is not a type" | head -n 3` must be empty.

- [ ] **Step 3: Resolve GapMarkers delegate contract (fails = placeholder wiring)**

GapMarkers requires Workspace-shaped delegates (`.ws/.focused/.y` per final review); int-model `circles` expose `ws/isActive`. Fix by passing the object the contract wants: feed GapMarkers the same workspace items the ported engine owns (mirror exactly what upstream `Workspaces.qml` passes its `GapMarkers`, prop names verbatim). If upstream passes `LazyListView` items, replicate with local equivalents — do NOT invent a parallel model. Verify: `grep -n "GapMarkers" shell/modules/bar/components/workspaces/Workspaces.qml` shows wired (not commented) sourceComponent with contract-satisfying input.

- [ ] **Step 4: Migrate Nexus UI + delete custom keys**

`BarWorkspaces.qml`: rebind rows to `showUnoccupied`/`perMonitor` (keep StepperRow bounds, SectionHeaders, `label:/status:`, qsTr). Delete `showEmptyAsNumber`/`perMonitorWorkspaces` from `barconfig.hpp`. Prove zero refs: `grep -rn "showEmptyAsNumber\|perMonitorWorkspaces" shell/modules shell/services --include="*.qml" | grep -v upstream` must be empty (QML) — C++ refs die with the props.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/bar/components/workspaces/ shell/modules/nexus/pages/panels/taskbar/BarWorkspaces.qml shell/plugin/src/Caelestia/Config/barconfig.hpp
git commit -m "feat(bar): workspaces engine on upstream logic keep layout hooks"
```

---

### Task 3: AudioPopout repoint + Audio.qml retirement

**Files:**
- Modify: `shell/modules/bar/components/StatusIcons.qml` (`name: "audio"` → audiopopout path), `shell/modules/bar/popouts/Content.qml` (audio/mic → AudioPopout), delete `shell/modules/bar/popouts/Audio.qml` (only if zero refs remain)
- Test: `qs -p` boot + refcounts

**Interfaces:**
- Consumes: Task 5 of backend-batch (qsTr-converted AudioPopout, `LocalPopouts` import pattern in Content.qml)
- Produces: Single audio popout UI (AudioPopout) for speaker+mic; custom Audio.qml deleted iff unreferenced

- [ ] **Step 1: Map every Audio.qml reference (fails = unexamined)**

Run: `grep -rn "LocalPopouts.Audio\|popouts/Audio\|name: \"audio\"\|name: \"mic\"" shell/modules/bar --include="*.qml" | grep -v upstream`
Expected: Content.qml:123/124 (`audio`), :141 (`mic`), StatusIcons.qml:131 (`audio`) — plus any stragglers to handle.

- [ ] **Step 2: Repoint speaker+mic at AudioPopout (keep singleton-shadow qualification)**

Content.qml: `LocalPopouts.Audio` → `LocalPopouts.AudioPopout` at both sites (keep `LocalPopouts.` prefix — bare `Audio` resolves to the `qs.services.Audio` singleton and fails). StatusIcons.qml: `name: "audio"` → the audiopopout name Content expects (read Content's current name string verbatim — do NOT invent; `mic` entry stays as-is only if Content still maps it, else repoint identically).

- [ ] **Step 3: Delete Audio.qml iff zero refs + boot**

Run: `grep -rn "LocalPopouts.Audio[^p]\|popouts/Audio\"" shell/modules --include="*.qml" | grep -v upstream | head`
Expected: empty → `git rm shell/modules/bar/popouts/Audio.qml`. Then: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -Ei "ERROR|Failed to load|is not a type|Audio" | head -n 5` → empty.

- [ ] **Step 4: Verify popout names consistent end-to-end**

Run: `grep -n "audiopopout\|\"mic\"\|'mic'" shell/modules/bar/popouts/Content.qml shell/modules/bar/components/StatusIcons.qml | head -n 10`
Expected: every emitted name has a matching Popout entry (no orphan names).

- [ ] **Step 5: Commit**

```bash
git add shell/modules/bar/components/StatusIcons.qml shell/modules/bar/popouts/Content.qml shell/modules/bar/popouts/Audio.qml
git commit -m "feat(bar): single AudioPopout for speaker mic retire Audio"
```

---

### Task 4: Popouts + components triage (classify-first, small diffs)

**Files:**
- Modify ONLY files with visual (non-Tr) deltas among: popouts/{Battery,Bluetooth,Network,TrayMenu,kblayout/KbLayout,LockStatus,WirelessPassword,Wrapper,ClipWrapper,PopoutState,Content,AudioPopout} + components/{ActiveWindow,Clock,OsIcon,Power,Tray} + adopt `components/status/{BatteryStatus,BluetoothStatus,LockStatus}.qml` IF referenced by converged files, else skip with note
- Test: `qs -p` boot per file

**Interfaces:**
- Consumes: Tasks 1-3; converged rows/bridges; Tokens widths (never hardcode)
- Produces: Visual-only ports; custom Network split-view/ethernet branches, WorkspacePreview entry, right-edge ClipWrapper, `.iface` (never `.interface`), qsTr kept

**Keep-vs-port rule (binding):** port tokens/spacing/layout/component usage; keep custom split-Ethernet views, WorkspacePreview branch + file, right-edge mirroring, `.iface` shape, Task-6/8 compat (qsTr, `LocalPopouts.` qualification), `showClockSeconds` UI from backend-batch (do NOT regress it).

- [ ] **Step 1: Classify each file (fails = unexamined)**

Run: `for f in <each file above relative to shell/modules/bar>; do echo "===== $f"; diff "shell/modules/bar/$f" "shell/upstream/modules/bar/$f" | grep -v "^[<>].*Tr\.tr\|^[<>].*qsTr\|^[<>].*Caelestia.I18n\|^[<>].*qs.services\|^[<>]\s*$" | head -n 8; done`
Expected: per-file visual-delta evidence; empty = converged/Tr-only → skip with note (especially Content 57, TrayMenu 14, Wrapper/PopoutState 3-line diffs).

- [ ] **Step 2: Port files with visual deltas (upstream base + grafts, boot-check each)**

Same inverted method as Nexus converge plan: copy upstream base, graft keep-list back via `git show HEAD:<path>`, qs -p gate per file (must stay empty). TrayMenu hide-empty separator: port the Content-side collapse + menu-side guard together (the deferred pair from the popout-mapping task).

- [ ] **Step 3: status/ adoption decision (evidence first)**

Run: `grep -rn "status/BatteryStatus\|status/BluetoothStatus\|status/LockStatus\|components/status" shell/modules/bar --include="*.qml" | grep -v upstream | head; grep -rn "import.*status\|StatusIcons.*status" shell/upstream/modules/bar/components/StatusIcons.qml | head -n 5`
Expected: adopt the three files verbatim ONLY if a converged consumer imports them; otherwise skip with note (dead files are worse than missing ones).

- [ ] **Step 4: Verify no customary breakage**

Run: `grep -rn "Tr\.tr\|Caelestia.I18n" shell/modules/bar --include="*.qml" | grep -v upstream | head -n 3; grep -rn "\.interface\b" shell/modules/bar/popouts/Network.qml | head -n 3`
Expected: both empty.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/bar/
git commit -m "feat(bar): popouts components visuals keep split preview edge"
```

---

### Task 5: Bar.qml/BarWrapper.qml behavior cherry-picks (layout untouched)

**Files:**
- Modify: `shell/modules/bar/Bar.qml`, `shell/modules/bar/BarWrapper.qml` (behavior hunks only)
- Test: `qs -p` boot + bar render (headless parse + live log after Task 6)

**Interfaces:**
- Consumes: Tasks 1-4; AGENTS.md bar rules (quoted verbatim in constraints)
- Produces: Upstream behaviors (tray-closing traversal adapted to top/bottomRepeaters, popout-splitting via findEntry, workspace-preview hover branch) on the custom split layout

- [ ] **Step 1: Extract behavior hunks (fails = unexamined)**

Run: `diff shell/modules/bar/Bar.qml shell/upstream/modules/bar/Bar.qml | grep "^[<>]" | grep -viE "ColumnLayout|DelegateChooser|EntryWrapper|pragma|repeater|children\[" | head -n 40`
Expected: behavior-only candidates (tray close logic, status-icon child lookup, active-window hover, workspace preview) separated from structural (layout/loader) lines which are OUT of scope.

- [ ] **Step 2: Port behavior hunks adapted to split layout (boot-check after)**

Port each candidate translated to `topRepeater/bottomRepeater/topLayout/bottomLayout/activeWindowLoader` terms (never `repeater.`/`children[]` positionals). Keep `findEntry`, `checkPopout(pos)`, right-edge mirroring, `isVertical`/`positioningEdge` customs. qs -p gate must stay empty.

- [ ] **Step 3: BarWrapper anchoring audit (read-only unless broken)**

Run: `diff shell/modules/bar/BarWrapper.qml shell/upstream/modules/bar/BarWrapper.qml | head -n 40`
Expected: adopt ONLY anchoring fixes that preserve the rule (vertical: top+bottom anchors; horizontal: left+right); never conditional logic that unanchors both axes. If no safe hunk, skip with note.

- [ ] **Step 4: Verify layout invariants hold**

Run: `grep -c "pragma ComponentBehavior: Bound\|ColumnLayout {\|DelegateChooser" shell/modules/bar/Bar.qml; grep -c "topLayout\|bottomLayout" shell/modules/bar/Bar.qml`
Expected: `0` then `>=2` (custom skeleton intact).

- [ ] **Step 5: Commit**

```bash
git add shell/modules/bar/Bar.qml shell/modules/bar/BarWrapper.qml
git commit -m "feat(bar): behavior cherry-picks keep split layout"
```

---

### Task 6: Rebuild + install readiness + deploy + live verify

**Files:**
- Modify: none (verification + plan-doc commit)
- Test: full build, qmltypes proof, live diff, live boot log, live feature checks

**Interfaces:**
- Consumes: Tasks 1-5; backend-batch install state ( prerequisite — verify first: if backend-batch keys/list are NOT in installed qmltypes, install BOTH batches' outputs in this task's Step 2)
- Produces: Installed plugin carrying both batches; live config synced; features proven live

- [ ] **Step 1: Full rebuild (fails = broken batch)**

Run: `cmake --build build -j"$(nproc)" 2>&1 | grep -Ei "error" | head -n 10`
Expected: empty (0 errors; build/ exists from prior tasks — incremental).

- [ ] **Step 2: Install readiness (human runs if sudo prompts — implementer attempts, reports BLOCKED otherwise)**

Run: `./build-plugin.sh 2>&1 | tail -n 8`
Expected: `Installed:` lines INCLUDING root `libcaelestia.so` + `libcaelestiaplugin.so` (glob fix from prior work) and config/services/components libs. If sudo prompts: STOP, report BLOCKED with exact human command, do NOT kill anything. Then: `grep -c "showUnoccupied\|statusIcons" /usr/lib/qt6/qml/Caelestia/Config/caelestia-config.qmltypes` → `>=2` proving install.

- [ ] **Step 3: Deploy + live diff (only after Step 2 install succeeds)**

Run: `./deploy.sh 2>&1 | tail -n 4`
Expected: `Deployed 589+ files`, `Done`. Then: `diff -rq shell/modules/bar ~/.config/quickshell/caelestia/modules/bar 2>&1 | wc -l` → `0`. (Never deploy on the old plugin: status-icons list reads need the new backend.)

- [ ] **Step 4: Live feature proof (code-level, headless; visuals PENDING-HUMAN)**

Single command (background qs does not survive sandbox calls): `timeout 20 qs -p shell/shell.qml 2>&1 | grep -Ei "ERROR|Failed to load|is not a type" | head -n 3` → empty. Plus: `grep -c "audiopopout" ~/.config/.../Content.qml` ≥1, `ls ~/.config/.../popouts/Audio.qml` → absent (retired), `grep -c "GapMarkers" <Workspaces>` wired. Record; bar render + workspace switching + popouts = PENDING-HUMAN.

- [ ] **Step 5: Commit plan doc**

```bash
git add docs/superpowers/plans/2026-09-22-bar-bestofboth.md
git status --porcelain shell/ | head -n 5
git commit -m "docs: bar best-of-both plan" 2>&1 | head -n 3
```

---

## Self-Review

1. **Spec coverage:** backend keys (T1) ✓, engine port + Nexus migration + custom-key deletion (T2) ✓, AudioPopout repoint + retirement gate (T3) ✓, popouts/components triage + status/ decision (T4) ✓, Bar.qml behaviors + BarWrapper audit (T5) ✓, rebuild/install/deploy/verify with backend-batch prerequisite (T6) ✓. StatusIcons excluded (already converged). VPN/rootnodes excluded per prior split.
2. **Placeholder scan:** No TBD/TODO/later/appropriate/edge-cases; every step has exact commands, paths, prop names, defaults, keep-lists, expected outputs; graft/migration shapes specified; sudo/sandbox limits stated (T6).
3. **Type consistency:** `showUnoccupied`/`perMonitor` (Config.bar.workspaces, non-global) vs custom `showEmptyAsNumber`/`perMonitorWorkspaces` (deleted T2) uniform; `audiopopout` naming + `LocalPopouts.` qualification uniform; `label:/status:`, qsTr, `qs.services`, Tokens widths, `.iface`, `grep -Ei`, read-only upstream uniform; AGENTS.md bar rules quoted in constraints and enforced in T5 Step 4.
