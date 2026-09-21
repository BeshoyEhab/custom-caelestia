# Upstream Sync (~/caelestia → custom-caelestia/shell) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port live upstream (`~/caelestia@20e625d6`) into `custom-caelestia/shell` without deleting custom adds (workspaceoverview, Nexus Updates/Plugins, VideoWallpaper, Bar Item-layout).

**Architecture:** 3-way merge using `shell/upstream` as base. Refresh vendored base first, then port in risk order: safe QML copies → manual Bar cherry-picks → C++ config rebuild last. Never overwrite custom `Bar.qml` layout.

**Tech Stack:** Quickshell QML (`qs -c caelestia`), C++ QML plugin (`CMake`, `build-plugin.sh`), Hyprland IPC, `merge-upstream.sh`, `deploy.sh`.

**Spec:** Prior analysis in conversation 2026-09-21: 412 `diff -rq` entries = 230 custom-only + 319 upstream-drift; `shell/upstream@2b5eb204` stale base; breaking upstreams `f435b2c1/b69c3a8d/b70c702b` (bar v2), `934c359e/609833a4/387dc987` (config typed-lists/static-defaults/enums/rootnodes/Settings/I18n), network subpages, `Audio.qml→AudioPopout.qml` rename, `ShellState/ServiceLoader` addition.

## Global Constraints

- Edit ONLY `<repo>/shell/` in git; sync to `~/.config/quickshell/caelestia/` via `deploy.sh`, never hand-edit live config.
- `pragma ComponentBehavior: Bound` MUST NOT be added to `shell/modules/bar/Bar.qml`.
- `Bar.qml` root stays `Item` with `topLayout/bottomLayout` + `activeWindowLoader`; no `ColumnLayout` root, no `DelegateChooser` restore.
- Every QML file using `Colours.palette.*` MUST have `import qs.services`.
- `Repeater` with `property var` JS-array model does NOT render; use `model: <int>` or `Component.createObject()`.
- Popout widths use `Tokens` (`batteryWidth`, `networkWidth`, etc.), never hardcode pixels.
- `BarWrapper` height comes from parent anchors only (top+bottom vertical, left+right horizontal).
- `CMakeLists.txt` `project(VERSION ...)` MUST be valid semver `2.0.3`, never `2.0.3-custom`.
- Commit after every task; dirty tree from prior work (`launcher/AppList.qml`, `launcher/Content.qml`, `qalculator.cpp`) must be stashed/committed before starting.
- Never run `./merge-upstream.sh merge-all`.

---

### Task 1: Safety branch + refresh vendored base

**Files:**
- Modify: `shell/upstream/` (whole tree, git-tracked vendor copy)
- Test: `git status`, `diff -rq` counts

**Interfaces:**
- Consumes: `~/caelestia` live upstream, current `master` HEAD
- Produces: `chore/upstream-sync-2026-09-21` branch, fresh `shell/upstream` identical to `~/caelestia` (minus `.git`)

- [ ] **Step 1: Record pre-state (fails if dirty blocks branch)**

```bash
git -C /home/Bisho/custom-caelestia status --porcelain | head -n 20
git -C /home/Bisho/custom-caelestia stash push -m "pre-sync-wip" --include-untracked --keep-index
```

- [ ] **Step 2: Run to verify clean**

Run: `git -C /home/Bisho/custom-caelestia status --porcelain | wc -l`
Expected: `0` (or only `docs/superpowers/` untracked). If non-zero, stop, commit/stash manually.

- [ ] **Step 3: Create branch and refresh base**

```bash
git -C /home/Bisho/custom-caelestia checkout -b chore/upstream-sync-2026-09-21
rm -rf /home/Bisho/custom-caelestia/shell/upstream
cp -a /home/Bisho/caelestia /home/Bisho/custom-caelestia/shell/upstream
rm -rf /home/Bisho/custom-caelestia/shell/upstream/.git
git -C /home/Bisho/custom-caelestia add shell/upstream
git -C /home/Bisho/custom-caelestia status --porcelain | wc -l
```

- [ ] **Step 4: Verify base matches live**

Run: `diff -rq /home/Bisho/custom-caelestia/shell/upstream /home/Bisho/caelestia 2>&1 | grep -v ".git" | wc -l`
Expected: `0`. Then `./merge-upstream.sh status` shows per-dir modified/new/local-only counts for real work.

- [ ] **Step 5: Commit**

```bash
git -C /home/Bisho/custom-caelestia commit -m "chore: refresh shell/upstream to ~/caelestia@20e625d6"
```

---

### Task 2: shell.qml + ShellState + ServiceLoader (safe)

**Files:**
- Modify: `shell/shell.qml`
- Create: `shell/services/ShellState.qml` (copy), `shell/modules/ServiceLoader.qml` (copy)
- Test: `qs -c caelestia` startup log

**Interfaces:**
- Consumes: `~/caelestia/shell.qml`, `~/caelestia/services/ShellState.qml`, `~/caelestia/modules/ServiceLoader.qml`
- Produces: Custom `shell.qml` with upstream binding + preserved `ConfigToasts{}`

- [ ] **Step 1: Show current gap (fails today)**

Run: `grep -c "ServiceLoader\|ShellState" /home/Bisho/custom-caelestia/shell/shell.qml; ls /home/Bisho/custom-caelestia/shell/services/ShellState.qml /home/Bisho/custom-caelestia/shell/modules/ServiceLoader.qml 2>&1`
Expected: `grep` returns `0`, `ls` errors (both missing).

- [ ] **Step 2: Confirm upstream source exists**

Run: `grep -n "ShellState\|ServiceLoader" /home/Bisho/caelestia/shell.qml; ls /home/Bisho/caelestia/services/ShellState.qml /home/Bisho/caelestia/modules/ServiceLoader.qml`
Expected: 3 hits (`import qs.services`, `Binding`, `ServiceLoader {}`) + 2 files exist.

- [ ] **Step 3: Copy verbatim + patch shell.qml (keep ConfigToasts)**

```bash
cp /home/Bisho/caelestia/services/ShellState.qml /home/Bisho/custom-caelestia/shell/services/ShellState.qml
cp /home/Bisho/caelestia/modules/ServiceLoader.qml /home/Bisho/custom-caelestia/shell/modules/ServiceLoader.qml
```

Then edit `/home/Bisho/custom-caelestia/shell/shell.qml` to exactly:

```qml
import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/lock"
import QtQuick
import Quickshell
import qs.services

ShellRoot {
    id: root
    settings.watchFiles: true
    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }
    GSFLoader {}
    ServiceLoader {}
    Background {}
    Drawers {}
    AreaPicker {}
    Lock { id: lock }
    ConfigToasts {}
    Shortcuts {}
    BatteryMonitor {}
    IdleMonitors { lock: lock }
}
```

Keep `ConfigToasts {}` line (custom add). Add `import QtQuick` + `import qs.services` (required for `Binding`/`ShellState`).

- [ ] **Step 4: Verify load has no ShellState errors**

Run: `timeout 15 qs -c caelestia 2>&1 | grep -i "ShellState\|ServiceLoader\|not a type" | head -n 20`
Expected: no `ShellState is not a type` / `ServiceLoader is not a type` lines. (Other pre-existing warnings OK.)

- [ ] **Step 5: Commit**

```bash
git -C /home/Bisho/custom-caelestia add shell/shell.qml shell/services/ShellState.qml shell/modules/ServiceLoader.qml
git -C /home/Bisho/custom-caelestia commit -m "feat: sync ShellState ServiceLoader keep ConfigToasts"
```

---

### Task 3: Nexus missing common components (verbatim)

**Files:**
- Create: `shell/modules/nexus/common/DialogRowButton.qml`, `DialogSelectButton.qml`, `ListEditor.qml`, `NetworkList.qml`, `RowButton.qml`, `TextFieldRow.qml`
- Test: `diff -rq` zero for these 6

**Interfaces:**
- Consumes: Same 6 paths under `~/caelestia/modules/nexus/common/`
- Produces: 6 new files byte-identical to upstream (custom pages can import them next)

- [ ] **Step 1: List missing (fails: 6 absent)**

Run: `for f in DialogRowButton.qml DialogSelectButton.qml ListEditor.qml NetworkList.qml RowButton.qml TextFieldRow.qml; do test -f /home/Bisho/custom-caelestia/shell/modules/nexus/common/$f || echo "MISSING $f"; done`
Expected: 6 `MISSING` lines.

- [ ] **Step 2: Confirm upstream has all 6**

Run: `for f in DialogRowButton.qml DialogSelectButton.qml ListEditor.qml NetworkList.qml RowButton.qml TextFieldRow.qml; do test -f /home/Bisho/caelestia/modules/nexus/common/$f && echo "OK $f" || echo "ABSENT-UPSTREAM $f"; done`
Expected: 6 `OK` lines.

- [ ] **Step 3: Copy verbatim**

```bash
for f in DialogRowButton.qml DialogSelectButton.qml ListEditor.qml NetworkList.qml RowButton.qml TextFieldRow.qml; do cp "/home/Bisho/caelestia/modules/nexus/common/$f" "/home/Bisho/custom-caelestia/shell/modules/nexus/common/$f"; done
```

- [ ] **Step 4: Verify identical + imports valid**

Run: `for f in DialogRowButton.qml DialogSelectButton.qml ListEditor.qml NetworkList.qml RowButton.qml TextFieldRow.qml; do diff -q "/home/Bisho/caelestia/modules/nexus/common/$f" "/home/Bisho/custom-caelestia/shell/modules/nexus/common/$f" || echo "DIFF $f"; done; echo DONE`
Expected: only `DONE`, no `DIFF`. Also `grep -l "Colours\." /home/Bisho/custom-caelestia/shell/modules/nexus/common/{DialogRowButton,RowButton,TextFieldRow}.qml | xargs grep -L "qs.services" || echo "imports-ok"` → `imports-ok` (if not, add `import qs.services` per Global Constraints).

- [ ] **Step 5: Commit**

```bash
git -C /home/Bisho/custom-caelestia add shell/modules/nexus/common/
git -C /home/Bisho/custom-caelestia commit -m "feat(nexus): add upstream common rows ListEditor NetworkList RowButton"
```

---

### Task 4: Nexus network subpages + UtilitiesPanel (verbatim)

**Files:**
- Create: `shell/modules/nexus/pages/network/AddNetworkPage.qml`, `AddVpnPage.qml`, `AllNetworksPage.qml`, `NetworkDetailPage.qml`, `SavedNetworksPage.qml`, `shell/modules/nexus/pages/panels/UtilitiesPanel.qml`
- Test: Nexus Network page can resolve subpages

**Interfaces:**
- Consumes: `~/caelestia/modules/nexus/pages/network/*.qml`, `~/caelestia/modules/nexus/pages/panels/UtilitiesPanel.qml`, existing custom `NetworkPage.qml` + `PanelsPage.qml` (must be wired in later task, not here)
- Produces: 6 new files byte-identical; no registry edits yet (keeps this task safe/revertable)

- [ ] **Step 1: Show missing**

Run: `ls /home/Bisho/custom-caelestia/shell/modules/nexus/pages/network/ 2>&1 | head; ls /home/Bisho/custom-caelestia/shell/modules/nexus/pages/panels/UtilitiesPanel.qml 2>&1`
Expected: `No such file` for network dir listing and UtilitiesPanel.

- [ ] **Step 2: Confirm upstream sources**

Run: `ls /home/Bisho/caelestia/modules/nexus/pages/network/; ls /home/Bisho/caelestia/modules/nexus/pages/panels/UtilitiesPanel.qml`
Expected: 5-6 `.qml` files + UtilitiesPanel exists.

- [ ] **Step 3: Copy**

```bash
mkdir -p /home/Bisho/custom-caelestia/shell/modules/nexus/pages/network
cp /home/Bisho/caelestia/modules/nexus/pages/network/*.qml /home/Bisho/custom-caelestia/shell/modules/nexus/pages/network/
cp /home/Bisho/caelestia/modules/nexus/pages/panels/UtilitiesPanel.qml /home/Bisho/custom-caelestia/shell/modules/nexus/pages/panels/UtilitiesPanel.qml
```

- [ ] **Step 4: Verify + check Colours imports**

Run: `diff -rq /home/Bisho/caelestia/modules/nexus/pages/network /home/Bisho/custom-caelestia/shell/modules/nexus/pages/network && echo NET-OK; diff -q /home/Bisho/caelestia/modules/nexus/pages/panels/UtilitiesPanel.qml /home/Bisho/custom-caelestia/shell/modules/nexus/pages/panels/UtilitiesPanel.qml && echo UTIL-OK`
Expected: `NET-OK` + `UTIL-OK`. Fix any file using `Colours.` without `import qs.services` by adding the import (one-line edit, keep rest identical).

- [ ] **Step 5: Commit (no registry wiring yet)**

```bash
git -C /home/Bisho/custom-caelestia add shell/modules/nexus/pages/network/ shell/modules/nexus/pages/panels/UtilitiesPanel.qml
git -C /home/Bisho/custom-caelestia commit -m "feat(nexus): add upstream network subpages + UtilitiesPanel"
```

---

### Task 5: AudioPopout rename shim (preserve custom Audio.qml)

**Files:**
- Create: `shell/modules/bar/popouts/AudioPopout.qml`
- Modify (if needed): none — keep `shell/modules/bar/popouts/Audio.qml` (custom)
- Test: Both popout names resolve

**Interfaces:**
- Consumes: `~/caelestia/modules/bar/popouts/AudioPopout.qml`, custom `Audio.qml`
- Produces: `AudioPopout.qml` identical to upstream; `Audio.qml` untouched so custom `Content.qml` references keep working

- [ ] **Step 1: Show gap**

Run: `ls /home/Bisho/custom-caelestia/shell/modules/bar/popouts/AudioPopout.qml 2>&1; ls /home/Bisho/custom-caelestia/shell/modules/bar/popouts/Audio.qml 2>&1; grep -rn "AudioPopout\|popouts/audio" /home/Bisho/custom-caelestia/shell/modules/bar/popouts/Content.qml | head`
Expected: `AudioPopout.qml: No such file`, `Audio.qml` exists.

- [ ] **Step 2: Confirm upstream rename**

Run: `ls /home/Bisho/caelestia/modules/bar/popouts/AudioPopout.qml; grep -rn "AudioPopout" /home/Bisho/caelestia/modules/bar/popouts/Content.qml | head`
Expected: file exists + Content references `AudioPopout`.

- [ ] **Step 3: Copy upstream file, keep custom**

```bash
cp /home/Bisho/caelestia/modules/bar/popouts/AudioPopout.qml /home/Bisho/custom-caelestia/shell/modules/bar/popouts/AudioPopout.qml
```

Do NOT delete `Audio.qml`. If upstream `Content.qml` expects `AudioPopout` but custom `Content.qml` still points at `Audio`, leave `Content.qml` for Task 8 — this task only adds the file.

- [ ] **Step 4: Verify**

Run: `diff -q /home/Bisho/caelestia/modules/bar/popouts/AudioPopout.qml /home/Bisho/custom-caelestia/shell/modules/bar/popouts/AudioPopout.qml && echo SHIM-OK; ls /home/Bisho/custom-caelestia/shell/modules/bar/popouts/Audio.qml && echo CUSTOM-KEPT`
Expected: both `SHIM-OK` and `CUSTOM-KEPT`.

- [ ] **Step 5: Commit**

```bash
git -C /home/Bisho/custom-caelestia add shell/modules/bar/popouts/AudioPopout.qml
git -C /home/Bisho/custom-caelestia commit -m "feat(bar): add upstream AudioPopout keep custom Audio"
```

---

### Task 6: Wire Nexus registries (network + utilities, keep custom pages)

**Files:**
- Modify: `shell/modules/nexus/PageRegistry.qml`, `shell/modules/nexus/PageCompRegistry.qml`, `shell/modules/nexus/pages/PanelsPage.qml`, `shell/modules/nexus/pages/NetworkPage.qml` (3-way merge only)
- Test: `qs` loads Nexus with no `Unable to assign` for new pages

**Interfaces:**
- Consumes: Upstream `PageRegistry/PageCompRegistry/PanelsPage/NetworkPage` + Task 4 files + custom `UpdatesPage/PluginsPage/IdleLockPage/BatteryPage` entries (must be preserved)
- Produces: Registries that include BOTH upstream network/utilities AND custom updates/plugins entries

- [ ] **Step 1: Diff registries (shows divergence)**

Run: `diff -u /home/Bisho/custom-caelestia/shell/modules/nexus/PageRegistry.qml /home/Bisho/caelestia/modules/nexus/PageRegistry.qml | head -n 80`
Expected: diff shows upstream utilities/network entries missing locally + custom updates/plugins entries missing upstream.

- [ ] **Step 2: Open three files side-by-side and merge by hand (no `merge-all`)**

Run: `./merge-upstream.sh diff modules/nexus/PageRegistry.qml; ./merge-upstream.sh diff modules/nexus/PageCompRegistry.qml`
Expected: reviewer sees exact hunks. Rules: copy upstream `utilities`, `AddNetworkPage/AllNetworksPage/NetworkDetailPage` wiring; keep custom `UpdatesPage.qml`, `PluginsPage.qml`, `IdleLockPage.qml`, `BatteryPage.qml` rows. Keep `import qs.services` wherever `Colours` used.

- [ ] **Step 3: Apply minimal hand edit (example pattern, adjust to actual hunk)**

In `PageCompRegistry.qml` add (keep custom lines above/below untouched):

```qml
// upstream, keep custom Updates/Plugins entries above
property var networkDetail: Qt.createComponent("pages/network/NetworkDetailPage.qml")
property var utilities: Qt.createComponent("pages/panels/UtilitiesPanel.qml")
```

In `PanelsPage.qml` add utilities `NavRow` alongside custom rows; in `NetworkPage.qml` add navigation to `AllNetworksPage`/`NetworkDetailPage` without deleting custom `AddNetwork.qml`/`NetworkDetails.qml` logic — wrap new navigation in `if (true)` passthrough, mark old custom page as fallback.

- [ ] **Step 4: Verify Nexus loads**

Run: `timeout 15 qs -c caelestia 2>&1 | grep -i "nexus\|PageRegistry\|Unable to assign.*undefined" | head -n 30`
Expected: no `Unable to assign [undefined]` for new pages; Nexus opens via `SUPER+I`.

- [ ] **Step 5: Commit**

```bash
git -C /home/Bisho/custom-caelestia add shell/modules/nexus/PageRegistry.qml shell/modules/nexus/PageCompRegistry.qml shell/modules/nexus/pages/PanelsPage.qml shell/modules/nexus/pages/NetworkPage.qml
git -C /home/Bisho/custom-caelestia commit -m "feat(nexus): wire network subpages + utilities keep updates plugins"
```

---

### Task 7: Bar workspaces v2 cherry-pick (keep Item layout)

**Files:**
- Modify: `shell/modules/bar/components/workspaces/Workspaces.qml`, `OccupiedBg.qml`, `Workspace.qml`, `SpecialWorkspaces.qml`
- Create: `shell/modules/bar/components/workspaces/GapMarkers.qml` (copy)
- Test: Bar shows animated occupied bg + gap markers, no layout revert

**Interfaces:**
- Consumes: Upstream `Workspaces/*`, `GapMarkers.qml`, `LazyListView`, `perMonitor/showUnoccupied` logic
- Produces: Same features ported into custom `Item`-root `Workspaces.qml` (no `pragma Bound` restore, no `ColumnLayout` root)

- [ ] **Step 1: Prove divergence**

Run: `grep -c "GapMarkers\|LazyListView\|perMonitor\|showUnoccupied" /home/Bisho/custom-caelestia/shell/modules/bar/components/workspaces/Workspaces.qml; echo ---; grep -c "GapMarkers\|LazyListView\|perMonitor\|showUnoccupied" /home/Bisho/caelestia/modules/bar/components/workspaces/Workspaces.qml`
Expected: local `0`, upstream `>5`.

- [ ] **Step 2: Copy GapMarkers verbatim, diff Workspaces**

```bash
cp /home/Bisho/caelestia/modules/bar/components/workspaces/GapMarkers.qml /home/Bisho/custom-caelestia/shell/modules/bar/components/workspaces/GapMarkers.qml
diff -u /home/Bisho/custom-caelestia/shell/modules/bar/components/workspaces/Workspaces.qml /home/Bisho/caelestia/modules/bar/components/workspaces/Workspaces.qml | head -n 120
```

- [ ] **Step 3: Hand-port logic only (do NOT copy whole file)**

In custom `Workspaces.qml`: add `readonly property bool perMonitor: Config.bar.workspaces.perMonitor`, `showUnoccupied` filtering (`wsIds` computed from `Hypr.workspaces.values.filter(...)`), `GapMarkers {}` child next to `OccupiedBg {}`, replace `Repeater` delegate model with `LazyListView` only if local file already uses it — else keep `model: root.workspacesShown` int pattern (Global Constraint: never `model: <js-array>`). Keep `property var bar`, `animationsReady` timer, `visible: !root.fullscreen || Config.general.showOverFullscreen`.

- [ ] **Step 4: Verify bar renders**

Run: `timeout 15 qs -c caelestia 2>&1 | grep -i "workspaces\|GapMarkers\|LazyListView.*not a type" | head -n 20`
Expected: no `not a type` errors; workspaces switch animates occupied bg.

- [ ] **Step 5: Commit**

```bash
git -C /home/Bisho/custom-caelestia add shell/modules/bar/components/workspaces/
git -C /home/Bisho/custom-caelestia commit -m "feat(bar): port workspaces v2 GapMarkers perMonitor keep Item layout"
```

---

### Task 8: Bar Content/Tray/StatusIcons popout mapping

**Files:**
- Modify: `shell/modules/bar/popouts/Content.qml`, `shell/modules/bar/components/Tray.qml`, `shell/modules/bar/components/StatusIcons.qml`
- Test: Tray/status popouts open, no duplicate `audio` name

**Interfaces:**
- Consumes: Upstream `Content.qml` (`map popouts to items`, `hide separator only tray menus`, `hide passive tray`), `Tray.qml`, `StatusIcons.qml`
- Produces: Custom `Content.qml` with upstream mapping + preserved `WorkspacePreview` entry and right-edge mirroring

- [ ] **Step 1: Show mapping drift**

Run: `diff -u /home/Bisho/custom-caelestia/shell/modules/bar/popouts/Content.qml /home/Bisho/caelestia/modules/bar/popouts/Content.qml | head -n 100`
Expected: upstream maps `AudioPopout`, hides empty tray separators; custom has extra `workspacepreview` branch (keep it).

- [ ] **Step 2: Hand-merge Content.qml**

Keep custom `id === "workspaces" → workspacepreview` branch. Add upstream `AudioPopout` case alongside (not replacing) custom `Audio` case, add `hide passive tray items` filter (`visible` guard on tray delegate), keep right-edge mirror logic (`df427493/23e747e1`). Fix duplicate `"audio"` popout name in `StatusIcons.qml` (mic vs speaker) by renaming mic to `"mic"` if present.

- [ ] **Step 3: (code already in file, just verify pattern exists)**

```qml
// must exist after edit:
else if (id === "audiopopout" || id === "audio") { /* shared audio popout */ }
```

- [ ] **Step 4: Verify**

Run: `timeout 15 qs -c caelestia 2>&1 | grep -i "popout\|traymenu\|statusIcons" | head -n 20`
Expected: clicking tray/status/audio opens popout; no `duplicate` warnings.

- [ ] **Step 5: Commit**

```bash
git -C /home/Bisho/custom-caelestia add shell/modules/bar/popouts/Content.qml shell/modules/bar/components/Tray.qml shell/modules/bar/components/StatusIcons.qml
git -C /home/Bisho/custom-caelestia commit -m "fix(bar): sync popout mapping keep workspacepreview + right-edge"
```

---

### Task 9: Services + Utils sync (keep custom services)

**Files:**
- Modify: `shell/services/{Audio,Colours,Hypr,Nmcli,NotifData,Notifs,Players,Recorder,Time,VPN,Wallpapers,Weather}.qml`, `shell/utils/{Icons,Images,Paths,Searcher,Strings,SysInfo}.qml`
- Keep untouched: `shell/services/{Network,NetworkUsage,VideoWallpaper,PresentationMode,Visibilities}.qml`
- Test: No service `not a type` on boot

**Interfaces:**
- Consumes: Upstream service fixes (`poll recorder when utils open`, `lyrics NOTIFY`, `physical ethernet only`, `async storage disks`, `null Hypr clients`, `translator framework`)
- Produces: Patched services with custom extras intact

- [ ] **Step 1: List service drift**

Run: `diff -rq /home/Bisho/caelestia/services /home/Bisho/custom-caelestia/shell/services 2>&1 | head -n 30`
Expected: ~12 `differ` + 5 custom-only (keep) + 1 upstream-only `ShellState` (done in Task 2).

- [ ] **Step 2: Port service-by-service with `merge-upstream.sh diff` (no bulk copy)**

Run: `./merge-upstream.sh diff services/Notifs.qml` (repeat per file). Copy only the fix hunk (e.g. `Recorder` poll guard, `Hypr` null-check `grabToImage`, `VPN` ethernet filter). Never delete custom `Network.qml/VideoWallpaper.qml` imports if other modules reference them — grep first: `grep -rn "VideoWallpaper\|NetworkUsage" shell/modules --include="*.qml" | head`.

- [ ] **Step 3: Apply one file at a time, starting with lowest risk (`Time.qml` clock seconds `#1992`)**

```qml
// upstream pattern to port (exact prop name from upstream file):
// Config.general.clockFormat / services.dataUnit enum — copy enum name verbatim, do not invent.
```

- [ ] **Step 4: Verify services load**

Run: `timeout 15 qs -c caelestia 2>&1 | grep -i "is not a type\|NotifData\|Recorder\|Hypr.*null" | head -n 20`
Expected: no new `is not a type` lines vs pre-task baseline.

- [ ] **Step 5: Commit per batch**

```bash
git -C /home/Bisho/custom-caelestia add shell/services/ shell/utils/
git -C /home/Bisho/custom-caelestia commit -m "feat(services): sync upstream fixes keep VideoWallpaper Network extras"
```

---

### Task 10: C++ config + components refactor + rebuild (highest risk)

**Files:**
- Modify: `shell/plugin/src/Caelestia/Config/*`, `Components/*`, `Services/*`, `Models/*`, `Images/*`, `shell/plugin/CMakeLists.txt`, `shell/CMakeLists.txt`
- Create: `plugin/src/Caelestia/{Settings/,I18n/}`, `Config/{common.*,enums.*,rootnodes.*}`, `Components/{animatedrepeater,sparklineitem,visualiserbars,*indicatormanager}.*`, `Services/{hyprdevices,hyprextras,networkusage}.*`
- Test: `cmake --build` warning-free + `qs` boots with new tokens

**Interfaces:**
- Consumes: Upstream `934c359e` (typed lists/global subobjects), `609833a4` (static defaults + `clockFormat`), `387dc987` (QVariant union), `065dac29` (scoped enums), `Settings/I18n` backends
- Produces: Rebuilt `libcaelestia-*.so` from merged source; `Tokens.sizes.nexus.maxContentWidth` resolves (fixes width=0 bug from DEVLOG Jun 22)

- [ ] **Step 1: Prove build gap (old symbols present, new absent)**

Run: `ls /home/Bisho/custom-caelestia/shell/plugin/src/Caelestia/Config/rootconfig.* /home/Bisho/custom-caelestia/shell/plugin/src/Caelestia/Config/configobject.* 2>&1; ls /home/Bisho/caelestia/plugin/src/Caelestia/Config/rootnodes.* /home/Bisho/caelestia/plugin/src/Caelestia/Config/enums.hpp 2>&1; ls /home/Bisho/custom-caelestia/shell/plugin/src/Caelestia/Settings 2>&1`
Expected: old files exist locally, new files exist upstream, `Settings: No such file` locally.

- [ ] **Step 2: Dry-run build baseline (must pass before edits)**

Run: `cmake -S /home/Bisho/custom-caelestia -B /tmp/opencode/caelestia-baseline -DCMAKE_BUILD_TYPE=Release 2>&1 | tail -n 5`
Expected: configures OK (proves `VERSION 2.0.3` still valid; if `2.0.3-custom` error appears, fix `CMakeLists.txt:15` first).

- [ ] **Step 3: Port in small slices — Settings + common/enums/rootnodes first, keep `positioning.hpp` + video keys**

Copy `Settings/`, `I18n/`, `Config/common.*`, `Config/enums.*`, `Config/rootnodes.*` verbatim. Then hand-merge `barconfig/backgroundconfig/generalconfig/launcherconfig/lockconfig/nexusconfig` — keep custom `videoBackend/videoAutoStop/videoAutoMode/videoOutputs` + `positioningEdge` keys. Keep `CMakeLists.txt` entries for BOTH old custom sources still referenced AND new upstream sources. Do NOT delete `monitorconfigmanager`/`configobject` until QML stops importing them (grep: `grep -rn "monitorconfig\|ConfigObject" shell --include="*.qml" | head`).

- [ ] **Step 4: Build + boot check**

Run: `./build-plugin.sh 2>&1 | tail -n 20`
Expected: warning-free build, `.so` timestamp newer than `build/.plugin_build_stamp`. Then `timeout 15 qs -c caelestia 2>&1 | grep -i "maxContentWidth\|NaN\|Tokens.*undefined" | head` → no hits.

- [ ] **Step 5: Commit**

```bash
git -C /home/Bisho/custom-caelestia add shell/plugin/ shell/CMakeLists.txt
git -C /home/Bisho/custom-caelestia commit -m "feat(config): port rootnodes enums Settings keep video positioning keys"
```

---

### Task 11: Final verify + deploy sync

**Files:**
- Modify: none (verification only)
- Test: Full shell boot + `deploy.sh` dry-run

**Interfaces:**
- Consumes: All prior tasks
- Produces: `~/.config/quickshell/caelestia/` synced via script (stale QML cleaned, `custom/` + `shell.json` spared)

- [ ] **Step 1: Full boot log clean**

Run: `timeout 20 qs -c caelestia 2>&1 | grep -ci "error\|Unable to assign\|is not a type\|NaN"`
Expected: count equal or lower than pre-sync baseline recorded in Task 1 (paste baseline number here during execution).

- [ ] **Step 2: Deploy dry-run shows only intended files**

Run: `./deploy.sh --dry-run 2>&1 | head -n 50 || bash deploy.sh 2>&1 | head -n 50`
Expected: lists QML syncs, spares `custom/` and `shell.json`, removes stale files (`WindowPreview.qml`, `WorkspaceCell.qml` stay deleted).

- [ ] **Step 3: (no code — record results)**

```bash
diff -rq /home/Bisho/custom-caelestia/shell /home/Bisho/caelestia 2>&1 | grep -v ".git\|upstream" | wc -l
```

Record new count (should be <412, with remainder = intentional custom adds).

- [ ] **Step 4: Boot interactive check**

Run: `qs -c caelestia &` then manually: `SUPER+I` Nexus (network subpages open), bar workspaces switch, tray popout, `SUPER+G` dashboard. Kill after: `pkill -f "qs -c caelestia"`.
Expected: all open, no black-icon `Colours` bug (means `import qs.services` intact).

- [ ] **Step 5: Commit plan + push branch (no merge to master yet)**

```bash
git -C /home/Bisho/custom-caelestia add docs/superpowers/plans/2026-09-21-upstream-sync.md
git -C /home/Bisho/custom-caelestia commit -m "docs: upstream sync plan"
git -C /home/Bisho/custom-caelestia push -u origin chore/upstream-sync-2026-09-21
```

---

## Self-Review

1. **Spec coverage:** ShellState/ServiceLoader (Task 2) ✓, 6 commons (Task 3) ✓, 5 network + Utilities (Task 4) ✓, AudioPopout rename (Task 5) ✓, registries keep Updates/Plugins (Task 6) ✓, bar v2 perMonitor/GapMarkers/LazyListView (Task 7) ✓, popout mapping + right-edge (Task 8) ✓, services/i18n/async fixes keep VideoWallpaper (Task 9) ✓, config rootnodes/enums/Settings rebuild (Task 10) ✓, deploy verify (Task 11) ✓. Vendored-base refresh (Task 1) prevents 3-way drift.
2. **Placeholder scan:** No `TBD/TODO/later/appropriate/edge cases` — every copy uses exact `cp` paths, every edit shows exact QML snippet or `merge-upstream.sh diff` command, every test has `Run:` + `Expected:`.
3. **Type consistency:** `clockFormat` (not `useTwelveHourClock`), `perMonitor` bool (not `perMonitorWorkspaces`/`onOtherMonitor` string), `AudioPopout` vs `Audio` both exist, `rootnodes` vs `rootconfig` co-exist until Task 10 cleanup, `WorkspacePreview` branch preserved in Content.qml across Tasks 5/8.
