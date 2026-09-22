# Nexus Pages Full Convergence (Upstream Design + Custom Grafts) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every Nexus page uses the upstream design; custom features survive as grafts on top of upstream files.

**Architecture:** INVERTED method vs the earlier visuals plan (which kept custom files and ported hunks — correctly, but the user still sees custom layouts). Now: copy the upstream page over the custom one, then graft the inventoried custom features back in. Each batch is independently boot-testable. Custom-only pages (Updates/Plugins/IdleLock/Battery/AddNetwork/NetworkDetails) have no upstream design and are untouched except for a final row-usage audit.

**Tech Stack:** Quickshell QML (`timeout 20 qs -p shell/shell.qml` headless verify), `diff -u` graft verification, `deploy.sh` sync, git per-task commits.

**Spec:** Conversation 2026-09-22: user chose "Everything — converge all kept pages, keep only custom features". Prior plans proved: rows/frame converged (NavRow bridges, TapHandler, PopupRow), batch triage kept most pages (reviewer-approved), live layers verified new (QML diff 0, plugin .so Sep 21 with new symbols, scheme.json fresh today). Graft inventory below was extracted 2026-09-22 via custom-only identifier diffs and reviewer-verified keep rationales.

## Global Constraints

- Every QML file using `Colours.palette.*` MUST have `import qs.services`.
- Never run `./merge-upstream.sh merge-all`; work file-by-file per this plan.
- `Repeater` with `property var` JS-array model does NOT render; use `model: <int>` or `Component.createObject()`.
- Do NOT use `Caelestia.I18n` imports or `Tr.*` calls (module absent in this build); use `qsTr()`.
- Do NOT declare `property string interface` on Nmcli models (`interface` is reserved); use `.iface`.
- Keep `shell/upstream/` byte-identical to `~/caelestia` (read-only reference); copy FROM it, never edit it.
- Preserve NavRow `label:`/`status:` bridges (Task 1 of nexus-look plan): grafted rows MUST keep working with both spellings; do NOT reintroduce hand-built row internals.
- Commit after every task; verify with `qs -p` (qmllint exits 255 silently here — do NOT rely on it).
- Deploy ONLY via `./deploy.sh` from repo root; never hand-edit `~/.config/quickshell/caelestia/`.

---

### Task 1: wallandstyle (WallpaperAndStyle converge + video/rotation grafts)

**Files:**
- Modify: `shell/modules/nexus/pages/WallpaperAndStyle.qml` (upstream base + grafts), verify `shell/modules/nexus/pages/wallandstyle/WallpaperSelect.qml` + `shell/modules/nexus/pages/wallandstyle/ColourSelect.qml` unchanged
- Test: `qs -p` boot + graft-key grep

**Interfaces:**
- Consumes: `shell/upstream/modules/nexus/pages/WallpaperAndStyle.qml` (3-row redesign, `large` spacing with `topMargin` compensation), converged rows/NavRow bridges
- Produces: Upstream 3-row layout carrying custom video + rotation + forceMode controls

**Graft list (binding — all verified present in custom file 2026-09-22):** `GlobalConfig.background.videoBackend`, `videoAutoMode`, `videoAutoStop`, `wallpaperRotation`, `wallpaperRotationInterval`, `Config.background.wallpaperEnabled`, `GlobalConfig.services.forceMode`. ColourSelect: NO-OP (upstream is a 48-line stub vs custom 493-line feature — document, do not touch).

- [ ] **Step 1: Copy upstream base (fails = custom layout still live)**

```bash
cp shell/upstream/modules/nexus/pages/WallpaperAndStyle.qml shell/modules/nexus/pages/WallpaperAndStyle.qml
grep -c "videoBackend\|wallpaperRotation" shell/modules/nexus/pages/WallpaperAndStyle.qml
```

Expected: `0` (custom controls absent — proves the base swap, grafts come next).

- [ ] **Step 2: Graft custom controls back (exact anchors)**

Re-add, in upstream style (SectionHeader + rows, qsTr labels): a Wallpaper section row bound to `Config.background.wallpaperEnabled`; a Video section (mode/backend/autostop/automode rows bound to the four `GlobalConfig.background.video*` keys); a Rotation section (toggle `wallpaperRotation` + interval stepper `wallpaperRotationInterval`); forceMode row bound to `GlobalConfig.services.forceMode`. Reuse the custom file's row code from git (`git show HEAD:shell/modules/nexus/pages/WallpaperAndStyle.qml`) with only token/spacing normalization — do NOT copy hand-built row internals.

- [ ] **Step 3: Verify grafts live + boot clean**

Run: `grep -c "videoBackend\|wallpaperRotation\|forceMode\|wallpaperEnabled" shell/modules/nexus/pages/WallpaperAndStyle.qml`
Expected: `>=10`. Then: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -i "ERROR\|Failed to load\|WallpaperAndStyle" | head -n 5`
Expected: empty.

- [ ] **Step 4: Verify WallpaperSelect/ColourSelect untouched**

Run: `git status --porcelain shell/modules/nexus/pages/wallandstyle/WallpaperSelect.qml shell/modules/nexus/pages/wallandstyle/ColourSelect.qml`
Expected: empty.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/nexus/pages/WallpaperAndStyle.qml
git commit -m "feat(nexus): converge WallpaperAndStyle on upstream graft video rotation"
```

---

### Task 2: Services area (ServicesPage + NotificationsPage converge)

**Files:**
- Modify: `shell/modules/nexus/pages/ServicesPage.qml`, `shell/modules/nexus/pages/services/NotificationsPage.qml`; gate `shell/modules/nexus/pages/services/BatteryPage.qml` unchanged
- Test: `qs -p` boot + graft-key grep

**Interfaces:**
- Consumes: Upstream `ServicesPage.qml` + `services/NotificationsPage.qml`
- Produces: Upstream service layouts carrying gpuType/defaultPlayer rows + Battery link + fullscreen toggle

**Graft list (binding):** ServicesPage: Battery sub-page NavRow link, `GlobalConfig.services.gpuType` row (string-mapped, backend is QString), `GlobalConfig.services.defaultPlayer` row, keep `label:/status:` spellings + qsTr. NotificationsPage: `GlobalConfig.notifs.fullscreen` row.

- [ ] **Step 1: Copy upstream bases**

```bash
cp shell/upstream/modules/nexus/pages/ServicesPage.qml shell/modules/nexus/pages/ServicesPage.qml
cp shell/upstream/modules/nexus/pages/services/NotificationsPage.qml shell/modules/nexus/pages/services/NotificationsPage.qml
grep -c "Battery\|gpuType\|defaultPlayer" shell/modules/nexus/pages/ServicesPage.qml; grep -c "fullscreen" shell/modules/nexus/pages/services/NotificationsPage.qml
```

Expected: `0` and `0` (grafts absent — next step restores them).

- [ ] **Step 2: Graft from git history (exact sources)**

Recover row code via `git show HEAD:shell/modules/nexus/pages/ServicesPage.qml` (Battery NavRow with `first:/last:` grouping intact, gpuType/defaultPlayer rows) and `git show HEAD:shell/modules/nexus/pages/services/NotificationsPage.qml` (fullscreen row). Restyle rows to upstream tokens only; keep `label:/status:` (bridges handle them), qsTr, `import qs.services`.

- [ ] **Step 3: Verify grafts + boot**

Run: `grep -c "Battery\|gpuType\|defaultPlayer" shell/modules/nexus/pages/ServicesPage.qml; grep -c "notifs.fullscreen" shell/modules/nexus/pages/services/NotificationsPage.qml`
Expected: `>=3` and `>=1`. Then: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -i "ERROR\|Failed to load\|ServicesPage\|NotificationsPage" | head -n 5`
Expected: empty.

- [ ] **Step 4: Gate BatteryPage untouched**

Run: `git status --porcelain shell/modules/nexus/pages/services/BatteryPage.qml`
Expected: empty.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/nexus/pages/ServicesPage.qml shell/modules/nexus/pages/services/NotificationsPage.qml
git commit -m "feat(nexus): converge Services Notifications graft Battery gpu fullscreen"
```

---

### Task 3: Panels (Dashboard/Launcher/Sidebar/Taskbar + PanelsPage converge)

**Files:**
- Modify: `shell/modules/nexus/pages/panels/DashboardPanel.qml`, `shell/modules/nexus/pages/panels/LauncherPanel.qml`, `shell/modules/nexus/pages/panels/SidebarPanel.qml`, `shell/modules/nexus/pages/panels/TaskbarPanel.qml`, `shell/modules/nexus/pages/PanelsPage.qml`
- Test: `qs -p` boot + graft-key grep

**Interfaces:**
- Consumes: Upstream panels/* + PanelsPage
- Produces: Upstream panel layouts carrying resetOption + hover-geometry + launcher prefs + showOverFullscreen/enabled toggles

**Graft list (binding):** Each of Dashboard/Launcher/Sidebar: `Config.<panel>.resetOption` row + hover section (`GlobalConfig.<panel>.showHoverIndicator/hoverWidth/hoverHeight/hoverEdge`). Launcher extra: `GlobalConfig.launcher.sortByFrequency`, `GlobalConfig.launcher.calcAutoDetect`. PanelsPage: `Config.general.showOverFullscreen` row + enabled toggles (`Config.dashboard/launcher/sidebar/utilities.enabled`). TaskbarPanel: `GlobalConfig.bar.positioningEdge` (bar edge selector) — keep even though upstream lacks it.

- [ ] **Step 1: Copy upstream bases (fails = customs live)**

```bash
for f in panels/DashboardPanel.qml panels/LauncherPanel.qml panels/SidebarPanel.qml panels/TaskbarPanel.qml PanelsPage.qml; do cp "shell/upstream/modules/nexus/pages/$f" "shell/modules/nexus/pages/$f"; done
grep -rc "resetOption\|showHoverIndicator\|positioningEdge" shell/modules/nexus/pages/panels/ shell/modules/nexus/pages/PanelsPage.qml | grep -v ":0" | head
```

Expected: empty (all grafts absent).

- [ ] **Step 2: Graft per list (recover via `git show HEAD:<path>`)**

One panel at a time; after EACH file run `timeout 20 qs -p shell/shell.qml 2>&1 | grep -i "ERROR\|Failed" | head -n 3` (must stay empty before next file). Restyle to upstream tokens; keep `label:/status:`, qsTr, `import qs.services`.

- [ ] **Step 3: Verify all grafts + boot**

Run: `grep -rc "resetOption" shell/modules/nexus/pages/panels/ | grep -v ":0"; grep -c "sortByFrequency\|calcAutoDetect" shell/modules/nexus/pages/panels/LauncherPanel.qml; grep -c "positioningEdge" shell/modules/nexus/pages/panels/TaskbarPanel.qml; grep -c "showOverFullscreen" shell/modules/nexus/pages/PanelsPage.qml`
Expected: 3 resetOption files, `>=2`, `>=1`, `>=1`. Then boot grep empty.

- [ ] **Step 4: Verify no registry/wiring damage**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -i "is not a type\|UtilitiesPanel\|NetworkDetail" | head -n 5`
Expected: empty (Task-6 wiring intact).

- [ ] **Step 5: Commit**

```bash
git add shell/modules/nexus/pages/panels/ shell/modules/nexus/pages/PanelsPage.qml
git commit -m "feat(nexus): converge panels on upstream graft hover reset edge"
```

---

### Task 4: taskbar/Bar* rows (BarWorkspaces + BarStatusIcons converge)

**Files:**
- Modify: `shell/modules/nexus/pages/panels/taskbar/BarWorkspaces.qml`, `shell/modules/nexus/pages/panels/taskbar/BarStatusIcons.qml`; verify BarClock/BarTray/BarActiveWindow need no change
- Test: `qs -p` boot + graft-key grep

**Interfaces:**
- Consumes: Upstream taskbar/* rows
- Produces: Upstream rows carrying perMonitorWorkspaces/showEmptyAsNumber/showAppIcon/overviewScale/overviewRows + per-icon show* toggles

**Graft list (binding):** BarWorkspaces: `GlobalConfig.bar.workspaces.perMonitorWorkspaces`, `showEmptyAsNumber`, `showAppIcon`, `overviewScale`, `overviewRows` (keep StepperRow/ToggleRow usage, SectionHeader). BarStatusIcons: per-icon `GlobalConfig.bar.status.show{Wifi,Network,Microphone,LockStatus,KbLayout,Bluetooth,Battery}` ToggleRows (backend has per-icon bools, NO list API — do NOT adopt ListEditor). BarClock/BarTray/BarActiveWindow: adopt upstream verbatim ONLY if diff is more than Tr-vs-qsTr (else leave untouched with note).

- [ ] **Step 1: Copy upstream bases + check the three small files**

```bash
for f in panels/taskbar/BarWorkspaces.qml panels/taskbar/BarStatusIcons.qml panels/taskbar/BarClock.qml panels/taskbar/BarTray.qml panels/taskbar/BarActiveWindow.qml; do cp "shell/upstream/modules/nexus/pages/$f" "shell/modules/nexus/pages/$f"; done
diff shell/modules/nexus/pages/panels/taskbar/BarClock.qml shell/upstream/modules/nexus/pages/panels/taskbar/BarClock.qml | grep -v "Tr\.tr\|qsTr\|Caelestia.I18n\|qs.services" | head -n 5
```

Expected: BarClock (and ideally Tray/ActiveWindow) show nothing beyond Tr/qsTr — those stay as pure upstream copies (already converged).

- [ ] **Step 2: Graft BarWorkspaces + BarStatusIcons (recover via `git show HEAD:<path>`)**

Restyle to upstream tokens; keep `label:/status:`, qsTr, SectionHeaders, StepperRow bounds. Boot-check after each file (same qs -p gate, must stay empty).

- [ ] **Step 3: Verify grafts + boot**

Run: `grep -c "perMonitorWorkspaces\|showEmptyAsNumber\|showAppIcon\|overviewScale\|overviewRows" shell/modules/nexus/pages/panels/taskbar/BarWorkspaces.qml; grep -c "bar.status.show" shell/modules/nexus/pages/panels/taskbar/BarStatusIcons.qml`
Expected: `>=5` and `>=7`. Then boot grep empty.

- [ ] **Step 4: Confirm no non-ASCII/Tr regressions**

Run: `grep -rn "Tr\.tr\|Caelestia.I18n" shell/modules/nexus/pages/panels/taskbar/ | head -n 5`
Expected: empty.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/nexus/pages/panels/taskbar/
git commit -m "feat(nexus): converge taskbar rows graft monitor icons overview"
```

---

### Task 5: Audio + Bluetooth + About/Apps converge

**Files:**
- Modify (only where visual delta beyond Tr/qsTr exists): `shell/modules/nexus/pages/AudioPage.qml`, `shell/modules/nexus/pages/BluetoothPage.qml`, `shell/modules/nexus/pages/AboutPage.qml`, `shell/modules/nexus/pages/AppsPage.qml`, `shell/modules/nexus/pages/apps/AllApps.qml`, `shell/modules/nexus/pages/apps/AppInfo.qml`, `shell/modules/nexus/pages/audio/AppVolumes.qml`, `shell/modules/nexus/pages/bluetooth/BtDeviceInfo.qml`
- Test: `qs -p` boot + resolve grep

**Interfaces:**
- Consumes: Upstream versions of the same files; Tasks 1-4
- Produces: Upstream designs carrying SectionHeader polish + AppVolumes wiring + pairing flow customs

**Graft list (binding):** AudioPage/BluetoothPage: custom SectionHeader rows (keep where upstream lacks them). AppVolumes: custom wiring entirely (verify against upstream, keep on conflict). BtDeviceInfo: pairing-flow customs. About/Apps/AllApps/AppInfo: adopt upstream unless proper-noun/custom rows exist (keep those). Prior triage found most of these near-identical — copy upstream base ONLY when the non-Tr diff is visual; otherwise leave untouched with a report note.

- [ ] **Step 1: Classify each file (fails = unexamined)**

Run: `for f in AudioPage.qml BluetoothPage.qml AboutPage.qml AppsPage.qml apps/AllApps.qml apps/AppInfo.qml audio/AppVolumes.qml bluetooth/BtDeviceInfo.qml; do echo "===== $f"; diff "shell/modules/nexus/pages/$f" "shell/upstream/modules/nexus/pages/$f" | grep -v "^[<>].*Tr\.tr\|^[<>].*qsTr\|^[<>].*Caelestia.I18n\|^[<>].*qs.services\|^[<>]\s*$" | head -n 10; done`
Expected: per-file visual-delta evidence (empty = already converged, skip file).

- [ ] **Step 2: Converge files with visual deltas (upstream base + grafts, boot-check each)**

Same method as Tasks 1-4 (copy base, graft customs from `git show HEAD:<path>`, qs -p gate per file). Keep `label:/status:`, qsTr, `import qs.services`.

- [ ] **Step 3: Verify boot + resolve**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -i "ERROR\|Failed to load\|is not a type" | head -n 5`
Expected: empty.

- [ ] **Step 4: Gate custom-only pages untouched**

Run: `git status --porcelain shell/modules/nexus/pages/UpdatesPage.qml shell/modules/nexus/pages/PluginsPage.qml shell/modules/nexus/pages/IdleLockPage.qml shell/modules/nexus/pages/services/BatteryPage.qml shell/modules/nexus/pages/NetworkDetails.qml shell/modules/nexus/pages/AddNetwork.qml shell/modules/nexus/pages/wallandstyle/ColourSelect.qml`
Expected: empty.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/nexus/pages/
git commit -m "feat(nexus): converge audio bluetooth about apps keep wirings"
```

---

### Task 6: Network-area verify + custom-pages row audit + deploy

**Files:**
- Modify: network pages ONLY if visual deltas found; otherwise none (verification + deploy)
- Test: full boot + live diff + deploy

**Interfaces:**
- Consumes: Tasks 1-5
- Produces: Network area confirmed converged; custom-only pages confirmed on converged rows; live config synced

- [ ] **Step 1: Network visual-delta check**

Run: `for f in NetworkPage.qml network/NetworkDetailPage.qml network/EthernetDetailPage.qml network/AllNetworksPage.qml network/SavedNetworksPage.qml network/AddNetworkPage.qml network/AddVpnPage.qml; do echo "===== $f"; diff "shell/modules/nexus/pages/$f" "shell/upstream/modules/nexus/pages/$f" | grep -v "^[<>].*Tr\.tr\|^[<>].*qsTr\|^[<>].*Caelestia.I18n\|^[<>].*qs.services\|^[<>]\s*$" | wc -l; done`
Expected: counts; `0` = converged (likely — Task 6 of sync plan + Task 5 fixes already aligned them). Port any visual remainder with grafts intact (legacy NetworkDetails/AddNetwork fallback at indices 7-8 MUST stay reachable).

- [ ] **Step 2: Custom-pages row audit (fails = old row internals)**

Run: `grep -l "StateLayer\|navLayout\|chevron_right" shell/modules/nexus/pages/UpdatesPage.qml shell/modules/nexus/pages/PluginsPage.qml shell/modules/nexus/pages/IdleLockPage.qml shell/modules/nexus/pages/services/BatteryPage.qml shell/modules/nexus/pages/NetworkDetails.qml shell/modules/nexus/pages/AddNetwork.qml`
Expected: empty (no hand-built row internals — all rows via converged commons). If hits: convert those rows to NavRow/ToggleRow/etc. usage (do NOT edit commons).

- [ ] **Step 3: Full boot probe**

Run: `timeout 20 qs -p shell/shell.qml 2>&1 | grep -ci "ERROR\|Failed to load"`
Expected: `0` (single benign `m3errorDim` Colours DEBUG substring — confirm via `grep -i ERROR` showing only that line).

- [ ] **Step 4: Deploy + live diff**

Run: `./deploy.sh 2>&1 | tail -n 4`
Expected: `Deployed 589+ files`, `Done`. Then: `diff -rq shell/modules/nexus ~/.config/quickshell/caelestia/modules/nexus 2>&1 | wc -l`
Expected: `0`.

- [ ] **Step 5: Commit plan doc**

```bash
git add docs/superpowers/plans/2026-09-22-nexus-pages-converge.md
git status --porcelain shell/ | head -n 5
git commit -m "docs: nexus pages full-convergence plan" 2>&1 | head -n 3
```

---

## Self-Review

1. **Spec coverage:** wallandstyle converge+grafts (T1, ColourSelect documented NO-OP) ✓, Services/Notifications+grafts (T2, BatteryPage gate) ✓, panels+PanelsPage+grafts incl positioningEdge (T3, wiring gate) ✓, taskbar rows+grafts incl per-icon bools (T4, no-ListEditor rule) ✓, audio/bt/about/apps converge+grafts (T5, custom-pages gate) ✓, network verify + row audit + deploy (T6) ✓. Inverted method (upstream base + grafts) is specified per task with exact graft keys.
2. **Placeholder scan:** No TBD/TODO/later/appropriate/edge-cases; every step has exact commands with exact paths, exact graft key names, exact expected outputs; `git show HEAD:<path>` recovery procedure specified wherever history is needed; "visual hunks" replaced by copy-base-then-graft (no judgment ambiguity except T5 classification, which has an explicit evidence-first step).
3. **Type consistency:** upstream-base-then-graft uniform across T1-T5; `label:/status:` + qsTr + `import qs.services` keep-rules uniform; `interface`-ban, no-merge-all, shell/upstream-read-only uniform; graft key namespaces (`GlobalConfig.background.video*`, `GlobalConfig.<panel>.hover*`, `Config.<panel>.resetOption`, `GlobalConfig.bar.workspaces.*`, `GlobalConfig.bar.status.show*`) match the inventoried custom code.
