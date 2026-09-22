# Backend Batch: Keys, Lists, Types (Best-of-Both) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the missing small backend keys, migrate status icons to a list model, and export the AnimatedRepeater QML type so guarded features can turn on.

**Architecture:** Backend-first (C++ keys land before the UI that binds them), one rebuild+reinstall+live-verify at the end. Old ConfigObject framework throughout — no new-framework migration in this plan. VPN multi-provider (838-line service + new config subtree) and rootnodes/I18n framework migration (blocked on duplicate GlobalConfig singleton design) are explicitly OUT — separate follow-up plans, reasons in Self-Review.

**Tech Stack:** C++ Qt QML plugin (`cmake --build build`, `./build-plugin.sh` sudo install), Quickshell QML (`qs -p` gates), `deploy.sh`, git per-task commits.

**Spec:** Conversation 2026-09-22: user chose "Backend batch". Depth evidence gathered same day: AnimatedRepeater has QML_ELEMENT + is compiled into the .so yet missing from qmltypes/qmldir (registration gap, not source gap); old framework supports QVariantList props (specialWorkspaceIcons, windowIcons, iconSubs, entries, actions, provider precedents); upstream Clock seconds = Loader on `Config.bar.clock.showSeconds` + `Time.format("ss")`; local Clock has no seconds path; local `showSeconds`-class keys absent from both backends.

## Global Constraints

- Every QML file using `Colours.palette.*` MUST have `import qs.services`.
- Never run `./merge-upstream.sh merge-all`; copy upstream reference hunks file-by-file.
- `Repeater` with `property var` JS-array model does NOT render; use `model: <int>` + index lookup.
- Do NOT use `Caelestia.I18n` imports or `Tr.*` calls; use `qsTr()`.
- Do NOT declare `property string interface` on Nmcli models; use `.iface`.
- Keep `shell/upstream/` read-only; edit ONLY `shell/` (QML) and `shell/plugin/` (C++).
- `CMakeLists.txt` project VERSION stays valid semver (`2.0.3`); never `2.0.3-custom`.
- Commit after every task. `qs -p` gates use `grep -Ei` (bare `|` never matches without `-E`); qmllint is unusable here (silent 255).
- Plugin install needs sudo + shell restart: implementers NEVER run `./build-plugin.sh --install` or `killall qs` in sandbox; Task 6 performs install+deploy once for the whole batch (human runs it if sudo prompts).

---

### Task 1: Backend keys (showSeconds x2, maxNetworksShown, statusIcons list)

**Files:**
- Modify: `shell/plugin/src/Caelestia/Config/barconfig.hpp`, `shell/plugin/src/Caelestia/Config/dashboardconfig.hpp`, `shell/plugin/src/Caelestia/Config/nexusconfig.hpp` (or wherever NexusConfig lives — verify first)
- Test: `cmake --build build` compiles (install deferred to Task 6)

**Interfaces:**
- Consumes: Old-framework CONFIG_PROPERTY/CONFIG_GLOBAL_PROPERTY conventions; upstream defaults as reference values
- Produces: `Config.bar.clock.showSeconds` (bool, false), `Config.dashboard.showClockSeconds` (bool, false), `NexusConfig.maxNetworksShown` (int, 5), `GlobalConfig.bar.statusIcons` QVariantList of `{id, enabled}` maps defaulting to upstream set (lockStatus:true, audio:false, microphone:false, kbLayout:false, network:true, bluetooth:true, battery:true)

**Conventions to copy (binding):** list default shape follows `specialWorkspaceIcons`/`windowIcons` QVariantList precedents in `barconfig.hpp` (vmap entries). Per-icon bool props (`showWifi`, `showNetwork`, …) STAY in this task (removed in Task 5 after migration proves out).

- [ ] **Step 1: Locate exact insertion points (fails = unexamined)**

```bash
grep -n "class BarClock\|class Dashboard\b\|showHoverIndicator" shell/plugin/src/Caelestia/Config/barconfig.hpp shell/plugin/src/Caelestia/Config/dashboardconfig.hpp | head -n 10
grep -rn "class NexusConfig" shell/plugin/src/Caelestia/Config/ | head -n 3
```

Expected: anchor lines for BarClock, Dashboard panel config, NexusConfig file path.

- [ ] **Step 2: Add the three scalar keys (exact code)**

```cpp
// barconfig.hpp, inside BarClock class after existing clock props:
CONFIG_PROPERTY(bool, showSeconds, false)
// dashboardconfig.hpp, inside dashboard panel class:
CONFIG_PROPERTY(bool, showClockSeconds, false)
// nexusconfig.hpp (verified path from Step 1):
CONFIG_PROPERTY(int, maxNetworksShown, 5)
```

Match surrounding style (Q_OBJECT/QML_ANONYMOUS classes need no other change; global vs attached follows the neighboring props).

- [ ] **Step 3: Add statusIcons QVariantList (exact shape)**

```cpp
// barconfig.hpp, BarStatus class (where showWifi/showNetwork/... live):
CONFIG_GLOBAL_PROPERTY(QVariantList, statusIcons,
    { vmap({ { u"id"_s, u"lockStatus"_s }, { u"enabled"_s, true } }),
      vmap({ { u"id"_s, u"audio"_s }, { u"enabled"_s, false } }),
      vmap({ { u"id"_s, u"microphone"_s }, { u"enabled"_s, false } }),
      vmap({ { u"id"_s, u"kbLayout"_s }, { u"enabled"_s, false } }),
      vmap({ { u"id"_s, u"network"_s }, { u"enabled"_s, true } }),
      vmap({ { u"id"_s, u"bluetooth"_s }, { u"enabled"_s, true } }),
      vmap({ { u"id"_s, u"battery"_s }, { u"enabled"_s, true } }) })
```

Verify `vmap`/`u""_s` helpers are already used in this file (specialWorkspaceIcons precedent — if the file uses a different map helper, match the file, not this snippet).

- [ ] **Step 4: Verify compile (no install)**

Run: `cmake --build build -j"$(nproc)" 2>&1 | tail -n 3`
Expected: `Built target` lines, 0 errors (warnings OK if pre-existing).

- [ ] **Step 5: Commit**

```bash
git add shell/plugin/src/Caelestia/Config/
git commit -m "feat(config): showSeconds x2, maxNetworksShown, statusIcons list"
```

---

### Task 2: showSeconds UI (bar Clock, dashboard clock, 2 Nexus rows)

**Files:**
- Modify: `shell/modules/bar/components/Clock.qml`, dashboard clock file (find: the file rendering the dashboard main clock — grep `Time.format("hh` under `shell/modules/dashboard/`), `shell/modules/nexus/pages/panels/taskbar/BarClock.qml`, `shell/modules/nexus/pages/panels/DashboardPanel.qml`
- Test: `qs -p` boot (rows render unchecked against not-yet-installed backend — boot-clean but dead until Task 6 install; state this in report)

**Interfaces:**
- Consumes: Task 1 keys (source-built, not yet installed); upstream `Clock.qml:112-121` Loader pattern
- Produces: Seconds loaders gated on the new keys + re-added dashboard row + new BarClock row

- [ ] **Step 1: Read upstream seconds Loader verbatim (fails = unexamined)**

Run: `sed -n '100,130p' shell/upstream/modules/bar/components/Clock.qml`
Expected: Loader with `active: Config.bar.clock.showSeconds`, `Time.format("ss")`, `fontFor`/`secMetrics` helpers — note the exact helper names to mirror or adapt.

- [ ] **Step 2: Port bar Clock seconds (adapt, don't paste blind)**

Add the seconds Loader to local `Clock.qml` in upstream position/style, gated on `Config.bar.clock.showSeconds`. If local file lacks `fontFor`/`secMetrics` helpers, render with the file's existing date-font pattern instead (keep visual consistency with the local minutes rendering, not upstream's).

- [ ] **Step 3: Port dashboard clock seconds + re-add Nexus rows**

Dashboard clock file: same gated pattern on `Config.dashboard.showClockSeconds`. DashboardPanel.qml: re-add the clock-seconds ToggleRow removed during simplification (place after Show-on-hover row with `last: true` moved onto it). BarClock.qml: add matching ToggleRow bound to `Config.bar.clock.showSeconds`. All labels qsTr, `label:/status:` spellings, `import qs.services` where Colours used.

- [ ] **Step 4: Verify boot (dead-toggles-expected note)**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -Ei "ERROR|Failed to load|is not a type|Clock" | head -n 5`
Expected: empty (rows render unchecked pre-install — correct, they go live in Task 6).

- [ ] **Step 5: Commit**

```bash
git add shell/modules/bar/components/Clock.qml shell/modules/dashboard/ shell/modules/nexus/pages/panels/
git commit -m "feat: clock seconds UI on new backend keys"
```

---

### Task 3: maxNetworksShown + action-prefix + preview fidelity (QML)

**Files:**
- Modify: `shell/modules/nexus/pages/NetworkPage.qml` (replace `maxShown: 5` literal), launcher panel or launcher config UI file hosting action-prefix (find via `actionPrefix` grep — backend key exists), `shell/modules/nexus/pages/WallpaperAndStyle.qml` (preview image only)
- Test: `qs -p` boot

**Interfaces:**
- Consumes: Task 1 `maxNetworksShown`; existing `launcherconfig.hpp:37` actionPrefix key; upstream preview (`Wallpapers.current`, no fillMode)
- Produces: Clamp honoring config; action-prefix row grafted with hover-section coexistence; preview with colourSource+fillMode restored on the image only

- [ ] **Step 1: Locate each site (fails = unexamined)**

Run: `grep -n "maxShown" shell/modules/nexus/pages/NetworkPage.qml; grep -rn "actionPrefix" shell/modules/ shell/services --include="*.qml" | grep -v upstream | head; grep -n "colourSource\|fillMode\|Wallpapers.current" shell/modules/nexus/pages/WallpaperAndStyle.qml | head`
Expected: maxShown literal site(s); actionPrefix backend-only (no UI) + hover-section location; preview image block lines.

- [ ] **Step 2: Apply the three grafts (one file at a time, boot-check each)**

maxNetworksShown: `maxShown: 5` → `maxShown: Config.nexus.maxNetworksShown` (verify NexusConfig QML path — `Config.nexus.*` vs `GlobalConfig.nexus.*` — match how NetworkPage reads other NexusConfig keys). action-prefix: add TextFieldRow bound to the existing backend key alongside (not inside) the hover section; preserve `last:`-chain grouping radii (verify neighbors' first:/last: flags still alternate correctly). Preview: restore `colourSource` + `fillMode` bindings on the preview image element only (from `git show HEAD:shell/modules/nexus/pages/WallpaperAndStyle.qml` pre-convergence if needed — actually from the current file's git history: the committed converge removed them; recover exact lines via `git log -p --follow`).

- [ ] **Step 3: Verify boot after each file**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -Ei "ERROR|Failed to load|is not a type" | head -n 3` after EACH file.
Expected: empty every time.

- [ ] **Step 4: Verify grafts present**

Run: `grep -c "maxNetworksShown" shell/modules/nexus/pages/NetworkPage.qml; grep -c "actionPrefix" <launcher-ui-file>; grep -c "colourSource" shell/modules/nexus/pages/WallpaperAndStyle.qml`
Expected: `>=1` each.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/nexus/pages/NetworkPage.qml shell/modules/launcher/ shell/modules/nexus/pages/WallpaperAndStyle.qml shell/modules/nexus/pages/panels/LauncherPanel.qml
git commit -m "feat: maxNetworksShown clamp, action-prefix row, preview fidelity"
```

---

### Task 4: AnimatedRepeater export + GapMarkers unguard

**Files:**
- Modify: `shell/plugin/cmake/qml-module.cmake` and/or `shell/plugin/src/Caelestia/Components/CMakeLists.txt` (registration fix), `shell/modules/bar/components/workspaces/Workspaces.qml` (unguarded Loader restore)
- Test: `cmake --build build` + qmltypes contains AnimatedRepeater (install deferred to Task 6)

**Interfaces:**
- Consumes: `animatedrepeater.hpp:40` QML_ELEMENT (present), sources already compiled into the .so (strings-proven), current guard (`active: false` + commented sourceComponent with restore notes)
- Produces: `AnimatedRepeater` in generated qmltypes/qmldir; GapMarkers Loader restored to `active: opacity > 0` + uncommented sourceComponent

- [ ] **Step 1: Diagnose why the type is missing (fails = guessing)**

Run: `grep -n "HEADERS\|SOURCES\|QML_ELEMENT\|qt_add_qml_module\|qml_module" shell/plugin/cmake/qml-module.cmake | head -n 20`
Expected: identify the mechanism (e.g. headers not listed, executable target scanning sources only, AUTOMOC gap). Compare with how `LazyListView` (exported, working) is registered — AnimatedRepeater must match that path exactly.

- [ ] **Step 2: Minimal registration fix (one mechanism only)**

Apply the smallest change that puts AnimatedRepeater on the LazyListView path (e.g. add header to the scanned list, or missing QML_URI macro —evidence from Step 1 decides; do NOT restructure the module system, do NOT touch new-framework files).

- [ ] **Step 3: Verify type export WITHOUT install**

Run: `cmake --build build -j"$(nproc)" 2>&1 | tail -n 2 && grep -c "AnimatedRepeater" build/qml/Caelestia/Components/caelestia-components.qmltypes build/shell/plugin/src/Caelestia/Components/.qt/qmltypes/caelestia-components.qmltypes 2>/dev/null`
Expected: build success + count `>=1` in at least one generated qmltypes (if the function writes elsewhere, `find build -name "*.qmltypes" | xargs grep -l AnimatedRepeater` must hit).

- [ ] **Step 4: Unguard GapMarkers (only after Step 3 proves export)**

In `Workspaces.qml`: restore `active: opacity > 0`, uncomment the `sourceComponent: GapMarkers { … }` block per the restore notes left in the guard commit. Keep the `showUnoccupied ?? true` fallback and int-model Repeater untouched.

- [ ] **Step 5: Commit**

```bash
git add shell/plugin/cmake/ shell/plugin/src/Caelestia/Components/CMakeLists.txt shell/modules/bar/components/workspaces/Workspaces.qml
git commit -m "feat: export AnimatedRepeater, unguard GapMarkers"
```

---

### Task 5: StatusIcons list migration (backend use + Nexus ListEditor + bool removal)

**Files:**
- Modify: `shell/modules/bar/components/StatusIcons.qml` (list-driven), `shell/modules/nexus/pages/panels/taskbar/BarStatusIcons.qml` (ListEditor), `shell/plugin/src/Caelestia/Config/barconfig.hpp` (REMOVE 7 per-icon bools — Task 1 list replaces them)
- Test: `qs -p` boot (list unreadable pre-install? No — old installed plugin LACKS the list prop → `GlobalConfig.bar.statusIcons` undefined → StatusIcons must degrade gracefully: empty list fallback. State this; live proof in Task 6)

**Interfaces:**
- Consumes: Task 1 `statusIcons` QVariantList; `shell/modules/nexus/common/ListEditor.qml` API (read it fully first); current per-icon bool rows as migration reference
- Produces: List-driven status icons; ListEditor-based Nexus page; 7 bool props deleted

- [ ] **Step 1: Read ListEditor API + current StatusIcons fully (fails = guessing)**

Run: `wc -l shell/modules/nexus/common/ListEditor.qml shell/modules/bar/components/StatusIcons.qml && grep -n "property\|signal\|function" shell/modules/nexus/common/ListEditor.qml | head -n 20`
Expected: ListEditor's exact model contract (expects list of what shape? emits what on change?) + StatusIcons' current bool reads enumerated.

- [ ] **Step 2: Rewrite StatusIcons list-driven with graceful fallback**

`const icons = (GlobalConfig.bar.statusIcons ?? []).filter(e => e.enabled).map(e => e.id)` — empty/undefined list → no icons (safe pre-install). Preserve popout-name mapping (`audio`/`mic` split from the popout-mapping task), Tokens widths, `qs.services` import. Keep component/registration names identical.

- [ ] **Step 3: Rewrite BarStatusIcons Nexus page on ListEditor + delete the 7 bools**

Port the 7 toggles' labels/icons into ListEditor entries bound at `GlobalConfig.bar.statusIcons`. Delete `showWifi/showNetwork/showMicrophone/showLockStatus/showKbLayout/showBluetooth/showBattery` from `barconfig.hpp`. Verify zero remaining refs: `grep -rn "bar.status.show\|bar\.status\.\(show\)" shell/modules shell/services --include="*.qml" | grep -v upstream` must be empty.

- [ ] **Step 4: Verify boot (empty-icons-expected note)**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -Ei "ERROR|Failed to load|is not a type|StatusIcons|ListEditor" | head -n 5`
Expected: empty (icons absent pre-install — correct; they appear after Task 6 install).

- [ ] **Step 5: Commit**

```bash
git add shell/modules/bar/components/StatusIcons.qml shell/modules/nexus/pages/panels/taskbar/BarStatusIcons.qml shell/plugin/src/Caelestia/Config/barconfig.hpp
git commit -m "feat: statusIcons list model, drop per-icon bools"
```

---

### Task 6: Rebuild + reinstall + deploy + live verify

**Files:**
- Modify: none (verification + install + deploy + plan-doc commit)
- Test: full build, live boot log, live feature checks

**Interfaces:**
- Consumes: Tasks 1-5
- Produces: Installed plugin with new keys/list/type; live config synced; features proven live

- [ ] **Step 1: Full rebuild (fails = broken batch)**

Run: `cmake --build build -j"$(nproc)" 2>&1 | grep -Ei "error|warning.*caelestia" | head -n 10`
Expected: empty (0 errors; pre-existing warnings only if already present on base — compare against `git stash`-free baseline only if unsure; do NOT stash user files).

- [ ] **Step 2: Install + deploy (human runs if sudo prompts — implementer attempts, reports)**

Run: `./build-plugin.sh 2>&1 | tail -n 5 && ./deploy.sh 2>&1 | tail -n 4`
Expected: `Installed:` lines for config/services/components libs; `Deployed 589+ files`, `Done`. If sudo demands a password the sandbox cannot provide: STOP, report BLOCKED with exact command for the human, do NOT kill the running shell.

- [ ] **Step 3: Live boot log check (single command: launch-check in one call — background qs does not survive sandbox calls)**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -Ei "ERROR|Failed to load|is not a type" | head -n 5`
Expected: empty. Then live: `diff -rq shell/modules ~/.config/quickshell/caelestia/modules 2>&1 | wc -l` → `0`.

- [ ] **Step 4: Live feature proof (code-level, headless)**

Run: `grep -c "showSeconds" ~/.config/quickshell/caelestia/modules/bar/components/Clock.qml; ls /usr/lib/qt6/qml/Caelestia/Components/ | grep -ci animated; grep -c "statusIcons" ~/.config/quickshell/caelestia/modules/bar/components/StatusIcons.qml`
Expected: `>=1`, `>=0` (qmltypes file presence decides — report actual), `>=1`. Record results; visual confirmation (seconds ticking, GapMarkers animating, list editing) is PENDING-HUMAN.

- [ ] **Step 5: Commit plan doc**

```bash
git add docs/superpowers/plans/2026-09-22-backend-batch.md
git status --porcelain shell/ | head -n 5
git commit -m "docs: backend batch keys lists types plan" 2>&1 | head -n 3
```

---

## Self-Review

1. **Spec coverage:** showSeconds backend+UI (T1+T2) ✓, maxNetworksShown (T1+T3) ✓, action-prefix UI (T3) ✓, preview fidelity (T3) ✓, AnimatedRepeater export + GapMarkers unguard (T4) ✓, statusIcons list + bool removal (T1+T5) ✓, rebuild/install/deploy/verify (T6) ✓. VPN multi-provider + rootnodes/I18n explicitly OUT with reasons below — user chose "backend batch" expecting them; this is a deliberate scope split, flagged in handoff, not a silent drop.
2. **Placeholder scan:** No TBD/TODO/later/appropriate/edge-cases; every step has exact commands, paths, prop names, defaults, expected outputs; graft/migration shapes specified (vmap entries, Loader pattern, ListEditor-first reading); sudo/sandbox limits stated (T6).
3. **Type consistency:** `showSeconds`/`showClockSeconds`/`maxNetworksShown`/`statusIcons[{id,enabled}]` uniform; `qsTr`, `label:/status:`, `qs.services`, no-merge-all, `grep -Ei`, read-only upstream uniform; Task 5's graceful-degradation (`?? []`) consistent with pre-install boot-clean requirement.

**OUT-OF-SCOPE with reasons (follow-up plans):** VPN multi-provider — 838-line service + new `utilities.vpn.{providers,selectedProvider}` config subtree + AddVpn UI rework; needs its own plan (service behavior, not keys). rootnodes/I18n framework migration — Task 10 proved new `settings::ObjectNode` GlobalConfig cannot compile alongside old `ConfigObject` roots (duplicate QML singleton); requires designed cutover, not a batch task.
