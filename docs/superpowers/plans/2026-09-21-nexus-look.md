# Nexus Upstream-Look Port (Best-of-Both) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Nexus the upstream look (RowButton-converged rows, search navpane, M3 polish) while keeping every custom feature (Updates/Plugins/IdleLock/Battery pages, confirmReset, SearchBar, wheelStep, CustomSpinBox, icon support) and every sync-compat fix (qsTr, disabled, iface, ScreenState-era wiring).

**Architecture:** Thin-wrapper convergence, not caller migration. Custom commons become upstream-shaped wrappers with alias bridges (`label`→`text`, `status`→`subtext`) so ~100 existing call sites work untouched. Page triage ports visual-only hunks hunk-by-hunk, keeping custom features. Same method repeats for later subsystems.

**Tech Stack:** Quickshell QML (`qs -p shell/shell.qml` headless verify), `diff -u` triage, `deploy.sh` sync, git per-task commits.

**Spec:** Conversation 2026-09-21 debugging (Phases 1-3): frame files (Nexus.qml, PageRegistry, NexusState) already at parity; commons at parity EXCEPT NavRow (custom 70-line hand-built vs upstream 5-line RowButton wrapper); callers split `label:/status:` (custom) vs `text:/subtext:` (upstream); `first:/last:` work on both via ConnectedRect inheritance; `clicked` with/without event param compatible.

## Global Constraints

- Every QML file using `Colours.palette.*` MUST have `import qs.services`.
- Never run `./merge-upstream.sh merge-all`; port hunk-by-hunk with `diff -u shell/<f> shell/upstream/<f>`.
- `Repeater` with `property var` JS-array model does NOT render; use `model: <int>` or `Component.createObject()`.
- Do NOT use `Caelestia.I18n` imports or `Tr.*` calls (module absent in this build); use `qsTr()` (Task 6/8 precedent).
- Do NOT reintroduce `property string interface` on Nmcli models (`interface` is a reserved QML keyword); use `.iface`.
- Keep `shell/upstream/` vendor tree byte-identical to `~/caelestia` (read-only reference); edit ONLY `shell/` (never `shell/upstream/`).
- Commit after every task; verify with `qs -p` (qmllint exits 255 silently here — do NOT rely on it).
- Deploy to live config ONLY via `./deploy.sh` from repo root; never hand-edit `~/.config/quickshell/caelestia/`.

---

### Task 1: NavRow → RowButton wrapper with alias bridges

**Files:**
- Modify: `shell/modules/nexus/common/NavRow.qml` (full rewrite, ~15 lines)
- Test: `timeout 20 qs -p shell/shell.qml` + grep call-site check

**Interfaces:**
- Consumes: `shell/upstream/modules/nexus/common/RowButton.qml` (icon/text/subtext/trailingIcon/disabled/clicked(event), extends ConnectedRect so first:/last: inherit)
- Produces: NavRow accepting BOTH `label:/status:` (custom callers, ~100 sites) AND `text:/subtext:` (upstream style) with identical upstream visuals

- [ ] **Step 1: Record current NavRow line count and caller prop usage (fails = old look)**

```bash
wc -l shell/modules/nexus/common/NavRow.qml
grep -rh "NavRow {" shell/modules/nexus/pages shell/modules/nexus/navpane --include="*.qml" -A8 | grep -cE "label:|status:"
```

Expected: `~70` lines, `label:/status:` count `>50` (proves caller base that must keep working).

- [ ] **Step 2: Run to verify upstream reference shape**

Run: `cat shell/upstream/modules/nexus/common/NavRow.qml`
Expected: 5 lines (`RowButton { trailingIcon: "chevron_right"; subLabel.animate: true }`).

- [ ] **Step 3: Rewrite NavRow as bridge wrapper (exact content)**

```qml
import QtQuick
import Caelestia.Config
import qs.components
import qs.services

RowButton {
    id: root

    // Bridges: custom callers use label:/status:, upstream style uses text:/subtext:.
    // Plain-property + binding (not alias-to-alias) so either spelling works;
    // setting text:/subtext: directly replaces the binding, setting label:/status: flows through.
    property string label
    property string status

    text: root.label
    subtext: root.status
    trailingIcon: "chevron_right"
    subLabel.animate: true
}
```

Keep NO `pragma ComponentBehavior: Bound` (upstream NavRow has none; RowButton carries its own). Keep `first:/last:` working via ConnectedRect inheritance (no code needed — verify in Step 4). Keep `icon:` and `onClicked:` passthrough (inherited signal `clicked(event)` accepts param-less handlers).

- [ ] **Step 4: Verify all call sites still resolve + shell boots**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -i "ERROR\|Failed to load\|NavRow.*not a type\|label.*readonly\|status.*readonly" | head -n 10`
Expected: empty (no errors). Then: `grep -rh "NavRow {" shell/modules/nexus/pages --include="*.qml" | wc -l` (count call sites, all now upstream-styled).

- [ ] **Step 5: Commit**

```bash
git add shell/modules/nexus/common/NavRow.qml
git commit -m "feat(nexus): converge NavRow onto RowButton keep label/status bridges"
```

---

### Task 2: Frame polish (Nexus.qml, PageBase, NavPane/SearchBar parity)

**Files:**
- Modify: `shell/modules/nexus/Nexus.qml` (2 hunks), `shell/modules/nexus/common/PageBase.qml` (2 hunks), `shell/modules/nexus/navpane/SearchBar.qml` (only if parity gaps found)
- Test: `qs -p` boot check

**Interfaces:**
- Consumes: Task 1 NavRow; vendor `Nexus.qml` (Math.round + TapHandler), vendor `PageBase.qml` (focus TapHandler, no scrollSpeed), vendor `NavPane.qml` searchField spec (placeholder "Search settings", body.large font, surfaceContainerLowest bg, outlineVariant border, CAnim border behavior, searchOpen binding)
- Produces: Pixel-parity frame; custom confirmReset + resetAllProc + SearchBar component KEPT

- [ ] **Step 1: Show the exact frame hunks (fails = old behavior)**

Run: `diff shell/modules/nexus/Nexus.qml shell/upstream/modules/nexus/Nexus.qml; diff shell/modules/nexus/common/PageBase.qml shell/upstream/modules/nexus/common/PageBase.qml`
Expected: Nexus.qml shows MouseArea-vs-TapHandler + missing Math.round; PageBase shows scrollSpeed + missing focus TapHandler.

- [ ] **Step 2: Compare SearchBar component against upstream inline spec**

Run: `grep -n "Search settings\|surfaceContainerLowest\|outlineVariant\|searchOpen\|CAnim" shell/modules/nexus/navpane/SearchBar.qml | head -n 10`
Expected: all 5 present (parity) or list which are missing (port only missing ones in Step 3).

- [ ] **Step 3: Apply minimal edits (exact hunks)**

In `Nexus.qml`: wrap `implicitWidth/implicitHeight` in `Math.round(...)`; replace MouseArea-focus-clear block with `TapHandler { onTapped: root.focus = true }` (copy vendor lines 30-31 verbatim). In `PageBase.qml`: delete `scrollSpeed: 16000` lines; add vendor `TapHandler { onTapped: flickable.focus = true }` block verbatim. In `SearchBar.qml`: add ONLY missing spec items from Step 2 (placeholder text via qsTr, never Tr). Keep custom `NavPane.qml` confirmReset/Timer/IconButton/Process untouched.

- [ ] **Step 4: Verify boot + focus behavior compiles**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -i "ERROR\|Failed to load\|Nexus.*not a type" | head -n 5`
Expected: empty.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/nexus/Nexus.qml shell/modules/nexus/common/PageBase.qml shell/modules/nexus/navpane/SearchBar.qml
git commit -m "feat(nexus): frame polish TapHandler rounding focus keep confirmReset"
```

---

### Task 3: Row-component parity (PopupRow, ToggleRow, SliderRow, InfoRow, StepperRow)

**Files:**
- Modify: `shell/modules/nexus/common/PopupRow.qml` (hover/cursor hunk), others ONLY if visual delta found
- Test: `qs -p` boot check

**Interfaces:**
- Consumes: Task 1-2; vendor rows as reference
- Produces: Upstream handling where strictly better; custom controls (CustomSpinBox, wheelStep, icon support) KEPT with written justification per file

- [ ] **Step 1: Show each row diff (fails = any unexamined delta)**

Run: `for f in ToggleRow SliderRow InfoRow PopupRow StepperRow; do echo "===== $f"; diff shell/modules/nexus/common/$f.qml shell/upstream/modules/nexus/common/$f.qml; done`
Expected: ToggleRow line-order only; SliderRow wheelStep custom-add; InfoRow ~identical; PopupRow hover/cursor; StepperRow CustomSpinBox-vs-StyledSpinBox.

- [ ] **Step 2: Decide per file (record in commit message, no code yet)**

Decisions (binding): ToggleRow keep (cosmetic order only); SliderRow keep wheelStep (custom feature beats upstream); InfoRow keep (parity); PopupRow TAKE upstream (`hoverEnabled: popup.open`, `cursorShape` conditional — better handling); StepperRow keep CustomSpinBox (custom control, repo-owned) unless StyledSpinBox renders visibly different — check by reading both controls' visuals first.

- [ ] **Step 3: Apply PopupRow hunk only (exact)**

In `PopupRow.qml` replace `hoverEnabled: true` with vendor's two lines (`hoverEnabled: popup.open`, `cursorShape: popup.open ? Qt.ArrowCursor : undefined`) verbatim. Touch NO other row file.

- [ ] **Step 4: Verify**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -i "ERROR\|Failed to load\|PopupRow" | head -n 5`
Expected: empty.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/nexus/common/PopupRow.qml
git commit -m "feat(nexus): PopupRow hover/cursor handling from upstream keep custom rows"
```

---

### Task 4: Page triage batch 1 (ColourSelect, WallpaperAndStyle, LanguageAndRegion, ServicesPage)

**Files:**
- Modify: `shell/modules/nexus/pages/wallandstyle/ColourSelect.qml`, `shell/modules/nexus/pages/WallpaperAndStyle.qml`, `shell/modules/nexus/pages/LanguageAndRegion.qml`, `shell/modules/nexus/pages/ServicesPage.qml`
- Test: `qs -p` boot + page-resolve grep

**Interfaces:**
- Consumes: Tasks 1-3 (pages inherit new row look automatically)
- Produces: Visual-only hunks ported; custom features KEPT (ColourSelect theme-mode/transparency/palette-preview per TODO Part F; ServicesPage custom services incl BatteryPage link; LanguageAndRegion custom locale/weather wiring)

**Keep-vs-port rule (binding):** port tokens/spacing/layout/RowButton-era component usage; keep custom controls, custom sections, Task 6/9 compat (qsTr, disabled, iface), and any `TODO.md`-listed custom feature. When unsure, KEEP custom and note in report.

- [ ] **Step 1: Emit per-page diff stat (fails = unexamined)**

Run: `for f in wallandstyle/ColourSelect.qml WallpaperAndStyle.qml LanguageAndRegion.qml ServicesPage.qml; do echo "===== $f"; diff shell/modules/nexus/pages/$f shell/upstream/modules/nexus/pages/$f | wc -l; done`
Expected: counts (~516/209/201/189) proving triage surface.

- [ ] **Step 2: Triage ColourSelect hunk-by-hunk (largest, custom-best-known)**

Run: `diff -u shell/modules/nexus/pages/wallandstyle/ColourSelect.qml shell/upstream/modules/nexus/pages/wallandstyle/ColourSelect.qml | head -n 150`
Expected: identify visual hunks (variant tiles, swatches, spacing) vs custom-feature hunks (dark/light toggle via Colours.setMode, transparency toggle, palette preview, real surface/onSurface tiles per git log 185b6518/4bf28fd4/bcba7da6). Port ONLY visual hunks; keep ALL custom-feature hunks.

- [ ] **Step 3: Apply Task-4 pages (one file at a time, boot-check each)**

Port visual hunks into the 4 files; after EACH file run `timeout 20 qs -p shell/shell.qml 2>&1 | grep -i "ERROR\|Failed" | head -n 3` (must stay empty before touching the next file). Never convert qsTr→Tr, never drop `import qs.services`, never touch Task-6 registry wiring.

- [ ] **Step 4: Verify pages resolve**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -i "ColourSelect\|WallpaperAndStyle\|LanguageAndRegion\|ServicesPage.*not a type\|is not a type" | head -n 5`
Expected: empty (all four pages instantiate).

- [ ] **Step 5: Commit**

```bash
git add shell/modules/nexus/pages/wallandstyle/ColourSelect.qml shell/modules/nexus/pages/WallpaperAndStyle.qml shell/modules/nexus/pages/LanguageAndRegion.qml shell/modules/nexus/pages/ServicesPage.qml
git commit -m "feat(nexus): page visuals batch1 keep custom colour theme services features"
```

---

### Task 5: Page triage batch 2 (panels, Audio, Bluetooth, About/Apps, wallandstyle remainder)

**Files:**
- Modify: `shell/modules/nexus/pages/panels/*.qml` (Dashboard/Launcher/Sidebar/Taskbar + taskbar/Bar*), `shell/modules/nexus/pages/AudioPage.qml`, `shell/modules/nexus/pages/BluetoothPage.qml`, `shell/modules/nexus/pages/AboutPage.qml`, `shell/modules/nexus/pages/AppsPage.qml`, `shell/modules/nexus/pages/wallandstyle/WallpaperSelect.qml`, `shell/modules/nexus/pages/audio/AppVolumes.qml`, `shell/modules/nexus/pages/apps/*.qml`, `shell/modules/nexus/pages/bluetooth/*.qml`
- Test: `qs -p` boot + page-resolve grep

**Interfaces:**
- Consumes: Tasks 1-4
- Produces: Same keep-vs-port rule as Task 4; custom Updates/Plugins/IdleLock/Battery/NetworkDetails/AddNetwork pages UNTOUCHED (already best-of-both)

**Keep-vs-port rule (binding):** same as Task 4. Extra keeps: bar-edge selector + variant swatches (git log abbb303c), TaskbarPanel custom entries, AppVolumes custom wiring, BtDeviceInfo pairing flow.

- [ ] **Step 1: Emit batch-2 diff stat**

Run: `diff -rq shell/modules/nexus/pages shell/upstream/modules/nexus/pages 2>&1 | grep differ | awk '{print $2}' | while read f; do n=$(diff "$f" "shell/upstream/${f#shell/}" 2>/dev/null | wc -l); echo "$n $f"; done | sort -rn | head -n 20`
Expected: ranked list (LauncherPanel ~212, DashboardPanel ~170, NotificationsPage ~137, BarStatusIcons ~127, TaskbarPanel ~120, AudioPage ~113, BarWorkspaces ~111, SidebarPanel ~109, BluetoothPage ~105, ...).

- [ ] **Step 2: Port top-down in rank order, boot-checking each file**

Same per-file procedure as Task 4 Step 3 (visual hunks only, keep custom features + compat, qs -p empty after each file). Skip files whose diff is Tr-vs-qsTr only or Task-6/9 compat (verify with `diff <f> upstream | grep -v "^[<>].*qsTr\|^[<>].*Tr\.tr" | head` showing nothing visual → skip with note).

- [ ] **Step 3: Verify batch-2 pages resolve**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -i "is not a type\|Failed to load" | head -n 5`
Expected: empty.

- [ ] **Step 4: Confirm custom pages untouched**

Run: `git status --porcelain shell/modules/nexus/pages/UpdatesPage.qml shell/modules/nexus/pages/PluginsPage.qml shell/modules/nexus/pages/IdleLockPage.qml shell/modules/nexus/pages/services/BatteryPage.qml shell/modules/nexus/pages/NetworkDetails.qml shell/modules/nexus/pages/AddNetwork.qml`
Expected: empty output (not modified by this plan).

- [ ] **Step 5: Commit**

```bash
git add shell/modules/nexus/pages/
git commit -m "feat(nexus): page visuals batch2 keep taskbar variants pairing flows"
```

---

### Task 6: Deploy + live verify

**Files:**
- Modify: none (verification + deploy only)
- Test: full boot log + Nexus open check

**Interfaces:**
- Consumes: Tasks 1-5
- Produces: Live `~/.config/quickshell/caelestia/` synced; Nexus visibly upstream-styled with custom features intact

- [ ] **Step 1: Pre-deploy boot probe (fails = regressions)**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -ci "ERROR\|Failed to load"`
Expected: `0` (the single `m3errorDim` Colours DEBUG substring is benign — confirm with `grep -i ERROR` showing only that line).

- [ ] **Step 2: Deploy (repo root, QML sync + restart)**

Run: `./deploy.sh 2>&1 | tail -n 5`
Expected: `Deployed 589+ files`, `Removed <n> stale files`, `Done`. (Count rises with no new files — same tree.)

- [ ] **Step 3: Confirm live tree matches repo Nexus**

Run: `diff -rq shell/modules/nexus ~/.config/quickshell/caelestia/modules/nexus 2>&1 | wc -l`
Expected: `0`.

- [ ] **Step 4: Live boot check (no ERRORs, Nexus opens)**

Run: `timeout 20 qs -c caelestia 2>&1 | grep -i "ERROR\|Failed to load" | head -n 5` then open Nexus via `SUPER+I` and confirm: rows render upstream-styled (chevron rows, RowButton padding), search filters pages, custom Updates/Plugins pages present, confirmReset button present.
Expected: empty grep; visual confirm yes for all four.

- [ ] **Step 5: Commit plan doc (no code left uncommitted)**

```bash
git add docs/superpowers/plans/2026-09-21-nexus-look.md
git status --porcelain shell/ | head -n 5
git commit -m "docs: nexus upstream-look best-of-both plan" 2>&1 | head -n 3
```

---

## Self-Review

1. **Spec coverage:** NavRow convergence + bridges (Task 1) ✓, frame polish + SearchBar parity (Task 2) ✓, row parity with keep-justifications (Task 3) ✓, page batch 1 incl ColourSelect custom-best (Task 4) ✓, page batch 2 incl panels/audio/bt (Task 5) ✓, custom-pages-untouched gate (Task 5 Step 4) ✓, deploy + live verify (Task 6) ✓. Repeat-method for other subsystems explicitly out of scope (this plan = Nexus; each subsystem gets its own plan per Scope Check).
2. **Placeholder scan:** No TBD/TODO/later/appropriate/edge-cases; every step has exact commands, exact file paths, exact NavRow wrapper code, exact keep-vs-port rule, exact grep expectations. "Visual hunks" is defined (tokens/spacing/layout/RowButton-era components) with keep-list per task.
3. **Type consistency:** `label/status` (custom) vs `text/subtext` (upstream) used consistently; `first:/last:` via ConnectedRect inheritance in all tasks; `clicked`/`clicked(event)` compatibility noted; `Tr.` ban + `qsTr` rule uniform; `iface` (never `interface`) uniform; `shell/` vs `shell/upstream/` paths uniform.
