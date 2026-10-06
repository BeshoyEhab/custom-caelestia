# Eco / PowerSaver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship hybrid Eco power-saving (silent guards + PowerSaver service + quick-toggle and battery-popout surfaces) with tests written first.

**Architecture:** QML-only feature (plus one C++ default-list line). A new `qs.services.PowerSaver` singleton owns `ecoActive` from UPower + manual toggle; consumers degrade via bindings; Hypr low-gfx mirrors `GameMode`. No `plugin/` logic, no config-schema change.

**Tech Stack:** Quickshell QML, `Quickshell.Services.UPower`, `Hypr.extras.applyOptions`, repo structural bash tests (`tests/`).

**Spec:** `docs/superpowers/specs/2026-10-06-eco-powersaver-design.md`

## Global Constraints

- Edit files in BOTH `<repo>/shell/` and `~/.config/quickshell/caelestia/` (or symlink); `qs -c caelestia` loads the user-config copy (AGENTS.md).
- Never touch `shell/upstream/`.
- QML files using `PowerSaver.*` must have `import qs.services` (same rule as the `Colours` fix in AGENTS.md).
- `pragma ComponentBehavior: Bound` rules and bar layout rules in AGENTS.md stay intact.
- TDD: test file first (RED), then minimal implementation (GREEN). Commit per task.
- Run `qs` from `~/.config/quickshell/caelestia/` when smoke-testing.

---

### Task 1: RED tests for Eco

**Files:**
- Create: `tests/qml_eco_powersaver_test.sh`
- Modify: none

**Interfaces:**
- Consumes: repo test conventions from `tests/qml_idle_timers_test.sh` (bash structural asserts, `RESULT: PASS/FAIL`, exit codes).
- Produces: `tests/qml_eco_powersaver_test.sh` executable; later tasks make each assert pass.

- [ ] **Step 1: Write the failing test**

Create `tests/qml_eco_powersaver_test.sh` (executable, `set -uo pipefail`), following `tests/qml_idle_timers_test.sh` style. It must assert all of:

```bash
#!/usr/bin/env bash
# TDD RED test: Eco / PowerSaver.
# Fails before the feature, passes after.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$REPO_DIR/shell"
FAIL=0

echo "=== qml_eco_powersaver ==="

check() { # check <desc> <file> <grep-pattern>
    if grep -q "$3" "$2"; then
        echo "  PASS $1"
    else
        echo "  FAIL $1"
        FAIL=1
    fi
}

# Service exists and is registered
check "PowerSaver singleton exists" "$S/services/PowerSaver.qml" "pragma Singleton"
check "PowerSaver exposes ecoActive" "$S/services/PowerSaver.qml" "ecoActive"
check "PowerSaver IPC target" "$S/services/PowerSaver.qml" 'target: "powerSaver"'
check "PowerSaver watches UPower" "$S/services/PowerSaver.qml" "UPower.onBattery"
check "PowerSaver eager-loaded" "$S/modules/ServiceLoader.qml" "PowerSaver"

# Phase-1 guards
check "Time seconds gated" "$S/services/Time.qml" "secondsNeeded"
check "Visualiser layer gated" "$S/modules/background/Visualiser.qml" "layer.enabled: .*opacity"

# Eco consumer wiring
check "Visualiser eco gate" "$S/modules/background/Visualiser.qml" "PowerSaver.ecoActive"
check "Video eco gate" "$S/services/VideoWallpaper.qml" "PowerSaver"
check "Cava eco bars" "$S/services/Audio.qml" "PowerSaver"
check "Media interval stretch" "$S/modules/dashboard/dash/Media.qml" "intervalStretch"
check "Details interval stretch" "$S/modules/dashboard/media/Details.qml" "intervalStretch"
check "NetworkUsage interval stretch" "$S/services/NetworkUsage.qml" "intervalStretch"

# Surfaces
check "Quick toggle eco" "$S/modules/utilities/cards/Toggles.qml" 'roleValue: "eco"'
check "UtilitiesPanel eco row" "$S/modules/nexus/pages/panels/UtilitiesPanel.qml" '"eco"'
check "Battery popout eco" "$S/modules/bar/popouts/Battery.qml" "PowerSaver"
check "Nexus Power section" "$S/modules/nexus/pages/ServicesPage.qml" "PowerSaver"
check "C++ quick-toggle default" "$S/plugin/src/Caelestia/Config/utilitiesconfig.hpp" '"eco"'

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (red - eco not implemented)"
    exit 1
fi
echo "RESULT: PASS (green)"
```

- [ ] **Step 2: Run test to verify it FAILS**

Run: `bash tests/qml_eco_powersaver_test.sh`
Expected: FAIL (red), non-zero exit, missing-file/assert failures for `PowerSaver.qml` onward.

- [ ] **Step 3: Commit the RED test**

```bash
git add tests/qml_eco_powersaver_test.sh
git commit -m "test: RED eco powersaver structural tests"
```

---

### Task 2: PowerSaver service

**Files:**
- Create: `shell/services/PowerSaver.qml`
- Modify: `shell/modules/ServiceLoader.qml:7-19` (add eager-load line)

**Interfaces:**
- Consumes: UPower (`UPower.onBattery`, `displayDevice.{percentage,isLaptopBattery}`), `GlobalConfig.general.battery.warningLevel` (`generalconfig.hpp:55-61`), `Hypr.extras.applyOptions` + `Hypr.onConfigReloaded` (pattern: `shell/services/GameMode.qml:16-25,48-54`), `PersistentProperties`/`IpcHandler` (pattern: `GameMode.qml:40-46,57-75`).
- Produces: `PowerSaver.{enabled,autoOnBattery,ecoActive,videoBlocked,intervalStretch,ecoVisualiserBars,debug(),toggle(),enable(),disable()}` for Tasks 4-5.

- [ ] **Step 1: Verify the test still fails on service asserts**

Run: `bash tests/qml_eco_powersaver_test.sh`
Expected: FAIL naming `PowerSaver singleton exists`.

- [ ] **Step 2: Write minimal `shell/services/PowerSaver.qml`**

Model exactly on `shell/services/GameMode.qml`. Full content:

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia
import Caelestia.Config
import qs.services

Singleton {
    id: root

    property alias enabled: props.enabled
    property alias autoOnBattery: props.autoOnBattery

    readonly property bool hasBattery: UPower.displayDevice.isLaptopBattery
    readonly property bool onBattery: UPower.onBattery
    readonly property real batteryPct: UPower.displayDevice.percentage

    // Latched so the threshold has 2-point hysteresis (no flapping).
    property bool autoLatched: false

    readonly property bool autoWantsEco: root.hasBattery && props.autoOnBattery && root.autoLatched
    readonly property bool ecoActive: props.enabled || root.autoWantsEco
    readonly property bool videoBlocked: root.ecoActive
    readonly property int intervalStretch: root.ecoActive ? 4 : 1
    readonly property int ecoVisualiserBars: 24

    function evalAuto(): void {
        if (!root.hasBattery || !props.autoOnBattery || !UPower.onBattery) {
            if (root.autoLatched)
                root.autoLatched = false;
            return;
        }
        const pct = UPower.displayDevice.percentage * 100;
        const warn = GlobalConfig.general.battery.warningLevel;
        if (!root.autoLatched && pct <= warn)
            root.autoLatched = true;
        else if (root.autoLatched && pct >= warn + 2)
            root.autoLatched = false;
    }

    function setLowGfx(): void {
        Hypr.extras.applyOptions({
            "animations:enabled": 0,
            "decoration:shadow:enabled": 0,
            "decoration:blur:enabled": 0,
            "general:gaps_in": 0,
            "general:gaps_out": 0,
            "general:border_size": 1,
            "decoration:rounding": 0
        });
    }

    function restoreGfx(): void {
        // GameMode owns the low-gfx state while it is on; never reload under it.
        if (!GameMode.enabled)
            Hypr.extras.message("reload");
    }

    onEcoActiveChanged: {
        if (root.ecoActive)
            root.setLowGfx();
        else
            root.restoreGfx();
    }

    Connections {
        function onOnBatteryChanged(): void {
            root.evalAuto();
        }

        target: UPower
    }

    Connections {
        function onPercentageChanged(): void {
            root.evalAuto();
        }

        target: UPower.displayDevice
    }

    Connections {
        function onWarningLevelChanged(): void {
            root.evalAuto();
        }

        target: GlobalConfig.general.battery
    }

    Connections {
        function onConfigReloaded(): void {
            if (root.ecoActive)
                root.setLowGfx();
        }

        target: Hypr
    }

    PersistentProperties {
        id: props

        property bool enabled: false
        property bool autoOnBattery: true
        property bool toastOnChange: true

        reloadableId: "powerSaver"
    }

    IpcHandler {
        function isEnabled(): bool {
            return root.ecoActive;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
            root.autoLatched = false;
        }

        function debug(): string {
            return `ecoActive=${root.ecoActive} manual=${props.enabled} auto=${props.autoOnBattery} latched=${root.autoLatched} onBattery=${root.onBattery} pct=${Math.round(root.batteryPct * 100)} hasBattery=${root.hasBattery}`;
        }

        target: "powerSaver"
    }
}
```

Notes: the change toast ships in Task 5 (it needs `props.toastOnChange`,
already declared above). Ship this task with a plain gfx-only handler:

```qml
    onEcoActiveChanged: {
        if (root.ecoActive)
            root.setLowGfx();
        else
            root.restoreGfx();
    }
```

Task 5 Step 6 upgrades it to the toast version. (The test does not assert toasts.)

- [ ] **Step 3: Register eager-load in `shell/modules/ServiceLoader.qml`**

```qml
        IdleInhibitor;
        GameMode;
        PowerSaver;
```

- [ ] **Step 4: Run Eco test, expect service asserts to pass**

Run: `bash tests/qml_eco_powersaver_test.sh`
Expected: service lines PASS; guard/consumer/surface lines still FAIL.

- [ ] **Step 5: Smoke-load the shell**

Run: `qs -c caelestia` from `~/.config/quickshell/caelestia/` (after dual-deploy copy), then `qs ipc call powerSaver debug`.
Expected: shell starts with no new errors; debug prints `ecoActive=false ...`.

- [ ] **Step 6: Commit**

```bash
git add shell/services/PowerSaver.qml shell/modules/ServiceLoader.qml
git commit -m "feat: add PowerSaver service with battery-aware eco state"
```

---

### Task 3: Phase-1 silent guards

**Files:**
- Modify: `shell/services/Time.qml:38-42` (gate seconds clock)
- Modify: `shell/modules/background/Visualiser.qml:43` (layer gate)

**Interfaces:**
- Consumes: `PowerSaver` (not required here; guards are unconditional).
- Produces: `Time.secondsNeeded`; later tasks rely on nothing from this task.

- [ ] **Step 1: Gate the seconds clock in `shell/services/Time.qml`**

Current:

```qml
    SystemClock {
        id: secClock

        precision: SystemClock.Seconds
    }
```

New:

```qml
    // Seconds wake the shell every second; only run when a visible
    // seconds consumer exists. Bar seconds are Loader-gated in
    // bar/components/Clock.qml:102; desktop clocks only exist when enabled.
    readonly property bool secondsNeeded: Config.bar.clock.showSeconds || Config.background.desktopClock.enabled

    SystemClock {
        id: secClock

        enabled: root.secondsNeeded
        precision: SystemClock.Seconds
    }
```

`Time.qml` already imports `Caelestia.Config` (line 5); `Config.bar.clock.showSeconds` verified in `nexus/pages/panels/taskbar/BarClock.qml:40-42`, `Config.background.desktopClock.enabled` verified in `plugin/.../backgroundconfig.hpp` (`DesktopClock.enabled,false`). No new import needed.

- [ ] **Step 2: Gate the visualiser layer in `shell/modules/background/Visualiser.qml:43`**

Current: `layer.enabled: true`. New: `layer.enabled: root.opacity > 0`.

- [ ] **Step 3: Run Eco test**

Run: `bash tests/qml_eco_powersaver_test.sh`
Expected: `Time seconds gated` and `Visualiser layer gated` now PASS.

- [ ] **Step 4: Regression-check seconds consumers**

Run: `rg -n "Time\.seconds|Time\.secondsStr" shell --glob '*.qml' | grep -v upstream`
Expected consumers: `bar/components/Clock.qml` (Loader-gated on `showSeconds`), `dashboard/dash/DateTime.qml:67`, `background/AnalogClock.qml`, `background/CookieClock.qml:31`. Manually verify: enable bar seconds + desktop clock, confirm seconds tick; open lock screen, confirm its clock renders (lock uses minute precision; if any lock consumer reads `Time.seconds`, add its flag to `secondsNeeded` before committing).

- [ ] **Step 5: Commit**

```bash
git add shell/services/Time.qml shell/modules/background/Visualiser.qml
git commit -m "feat: gate seconds clock and visualiser layer when idle"
```

---

### Task 4: Eco consumer wiring

**Files:**
- Modify: `shell/modules/background/Visualiser.qml:18` (eco gate)
- Modify: `shell/services/VideoWallpaper.qml` (`externalActive` + eco)
- Modify: `shell/services/Audio.qml:175-179` (eco bars + add `import qs.services`)
- Modify: `shell/modules/dashboard/dash/Media.qml:36` (interval stretch)
- Modify: `shell/modules/dashboard/media/Details.qml:19` (interval stretch)
- Modify: `shell/services/NetworkUsage.qml:7,159` (add `import qs.services`, interval stretch)

**Interfaces:**
- Consumes: `PowerSaver.{ecoActive,videoBlocked,intervalStretch,ecoVisualiserBars}` from Task 2.
- Produces: all consumer asserts GREEN; Task 5 surfaces toggle `PowerSaver.enabled`.

- [ ] **Step 1: Visualiser eco gate (`Visualiser.qml:18`)**

Current:

```qml
    readonly property bool shouldBeActive: Config.background.visualiser.enabled && (!Config.background.visualiser.autoHide || (Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true))
```

New: append `&& !PowerSaver.ecoActive`. File already has `import qs.services` (line 10).

- [ ] **Step 2: Video block (`VideoWallpaper.qml`)**

Current (lines 23-28):

```qml
    readonly property bool externalActive: available
        && GlobalConfig.background.wallpaperEnabled
        && GlobalConfig.background.videoBackend === "mpvpaper"
        && Wallpapers.actualCurrent !== ""
        && Images.isVideo(Wallpapers.actualCurrent)
        && root.workspaceVisible
```

New: append `&& !PowerSaver.videoBlocked`. File already has `import qs.services` (line 7).

- [ ] **Step 3: Cava eco bars (`Audio.qml`)**

Add `import qs.services` (verified absent; same fix pattern as AGENTS.md `Colours` issue). Change:

```qml
        bars: GlobalConfig.services.visualiserBars
```

to:

```qml
        bars: PowerSaver.ecoActive ? PowerSaver.ecoVisualiserBars : GlobalConfig.services.visualiserBars
```

- [ ] **Step 4: Interval stretch (3 sites, same one-line pattern)**

`dash/Media.qml:36` and `media/Details.qml:19` (both already import `qs.services`):

```qml
        interval: Math.max(500, GlobalConfig.dashboard.mediaUpdateInterval)
```

to:

```qml
        interval: Math.max(500, GlobalConfig.dashboard.mediaUpdateInterval) * PowerSaver.intervalStretch
```

`NetworkUsage.qml:159` (add `import qs.services` first; verified absent):

```qml
        interval: Math.max(2000, GlobalConfig.dashboard.resourceUpdateInterval)
```

to:

```qml
        interval: Math.max(2000, GlobalConfig.dashboard.resourceUpdateInterval) * PowerSaver.intervalStretch
```

- [ ] **Step 5: Run Eco test**

Run: `bash tests/qml_eco_powersaver_test.sh`
Expected: all consumer lines PASS; only surface lines FAIL.

- [ ] **Step 6: Live toggle check**

With shell running: `qs ipc call powerSaver enable`, confirm Hypr blur/animations off (`hyprctl getoption animations:enabled`), visualiser hidden, video paused; `qs ipc call powerSaver disable`, confirm `reload` restores. With `GameMode.enabled=true`, enable eco then disable eco: confirm NO `reload` fires (gfx stays low).

- [ ] **Step 7: Commit**

```bash
git add shell/modules/background/Visualiser.qml shell/services/VideoWallpaper.qml shell/services/Audio.qml shell/modules/dashboard/dash/Media.qml shell/modules/dashboard/media/Details.qml shell/services/NetworkUsage.qml
git commit -m "feat: wire eco state into visualiser, video, cava and polling"
```

---

### Task 5: Surfaces (quick toggle + battery popout + Nexus)

**Files:**
- Modify: `shell/modules/utilities/cards/Toggles.qml:126-133` (add eco DelegateChoice)
- Modify: `shell/modules/nexus/pages/panels/UtilitiesPanel.qml:120-127` (add eco ToggleRow; demote nothing — `last:true` stays on VPN row)
- Modify: `shell/plugin/src/Caelestia/Config/utilitiesconfig.hpp:61` (add eco default; rebuild plugin via `./install.sh --rebuild-quickshell`)
- Modify: `shell/modules/bar/popouts/Battery.qml` (Eco switch row above `profiles`)
- Modify: `shell/modules/nexus/pages/ServicesPage.qml:204-236` (new Power section)
- Modify: `shell/services/PowerSaver.qml` (add toast block from Task 2 notes)

**Interfaces:**
- Consumes: `PowerSaver.enabled/autoOnBattery/ecoActive` from Task 2; `ToggleRow` API (`text/subtext/checked/onToggled/first/last`, cf. `ServicesPage.qml:221-226`); `DelegateChoice roleValue` pattern (cf. `Toggles.qml:126-133`); `setToggleOn` auto-inserts unknown ids (`UtilitiesPanel.qml:15-28`, so the toggle works before the C++ rebuild lands).
- Produces: user-visible Eco controls; all surface asserts GREEN.

- [ ] **Step 1: Quick-toggle delegate (`Toggles.qml`, after gameMode choice)**

```qml
                DelegateChoice {
                    roleValue: "eco"
                    delegate: Toggle {
                        icon: "energy_savings_leaf"
                        checked: PowerSaver.ecoActive
                        onClicked: PowerSaver.enabled = !PowerSaver.enabled
                    }
                }
```

File already imports `qs.services` (line 10).

- [ ] **Step 2: UtilitiesPanel row (after Game mode row, `UtilitiesPanel.qml:120-126`)**

```qml
        ToggleRow {
            text: qsTr("Eco mode")
            subtext: qsTr("Shell power saver (visuals, video, polling)")
            disabled: !Config.utilities.cards.quickToggles
            checked: root.isToggleOn("eco")
            onToggled: root.setToggleOn("eco", checked)
        }
```

- [ ] **Step 3: C++ default (`utilitiesconfig.hpp:61`, after gameMode line)**

```cpp
            vmap({ { u"id"_s, u"eco"_s }, { u"enabled"_s, true } }),
```

Then rebuild the plugin: `./install.sh --rebuild-quickshell` (per `README.md:84-87`). Existing installs work without the rebuild (`setToggleOn` inserts the id on first use).

- [ ] **Step 4: Battery popout Eco row (`Battery.qml`, above `profiles` rect at line 97)**

```qml
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.spacing.small

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: "energy_savings_leaf"
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: PowerSaver.ecoActive ? qsTr("Eco on") : qsTr("Eco off")
        }

        StyledSwitch {
            anchors.verticalCenter: parent.verticalCenter
            checked: PowerSaver.enabled
            onToggled: PowerSaver.enabled = checked
        }
    }
```

Verify `StyledSwitch` prop names against its use in `nexus/common/ToggleRow.qml:9-26` before committing (same component family). File already imports `qs.services` (line 7).

- [ ] **Step 5: Nexus Power section (`ServicesPage.qml`, after Service tuning section, lines 204-236)**

Insert after the GPU `SelectRow` — move `last: true` from the GPU row to the new final row:

```qml
        // Power
        SectionHeader {
            text: qsTr("Power")
        }

        ToggleRow {
            first: true
            text: qsTr("Eco mode")
            subtext: qsTr("Reduce visuals, video wallpaper and polling")
            checked: PowerSaver.ecoActive
            onToggled: PowerSaver.enabled = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Auto eco on battery")
            subtext: qsTr("Engage automatically at the low-battery warning level")
            checked: PowerSaver.autoOnBattery
            onToggled: PowerSaver.autoOnBattery = checked
        }
```

`ServicesPage.qml` already imports `qs.services` (line 8).

- [ ] **Step 6: Toast block (`PowerSaver.qml onEcoActiveChanged`)**

Replace the plain gfx handler with this exact version (toast key lives in
`props`, not in any C++ schema, so no schema change is needed):

```qml
    onEcoActiveChanged: {
        if (root.ecoActive)
            root.setLowGfx();
        else
            root.restoreGfx();
        if (props.toastOnChange)
            root.ecoActive ? Toaster.toast(qsTr("Eco mode enabled"), qsTr("Reduced visuals and background work to save power"), "energy_savings_leaf") : Toaster.toast(qsTr("Eco mode disabled"), qsTr("Full visuals restored"), "energy_savings_leaf");
    }
```

- [ ] **Step 7: Run Eco test, expect FULL PASS**

Run: `bash tests/qml_eco_powersaver_test.sh`
Expected: `RESULT: PASS (green)`.

- [ ] **Step 8: Commit**

```bash
git add shell/modules/utilities/cards/Toggles.qml shell/modules/nexus/pages/panels/UtilitiesPanel.qml shell/plugin/src/Caelestia/Config/utilitiesconfig.hpp shell/modules/bar/popouts/Battery.qml shell/modules/nexus/pages/ServicesPage.qml shell/services/PowerSaver.qml
git commit -m "feat: eco quick toggle, battery popout row and nexus section"
```

---

### Task 6: Full verification

**Files:**
- Modify: none (verification only; dual-deploy copies to `~/.config/quickshell/caelestia/`)

**Interfaces:**
- Consumes: all tasks above.
- Produces: green suite + manual matrix sign-off.

- [ ] **Step 1: Run the full repo suite**

Run: `bash tests/run.sh && bash tests/qml_eco_powersaver_test.sh`
Expected: `Results: 3 passed, 0 failed` (or current baseline count with no NEW failures) plus `RESULT: PASS (green)` for eco.

- [ ] **Step 2: Battery matrix (laptop)**

Unplug AC: confirm `qs ipc call powerSaver debug` shows `onBattery=true`; drain (or temporarily raise `warningLevel`) to threshold: confirm eco auto-engages with toast; replug: confirm release at threshold+2. No-battery desktop: confirm auto never fires, manual toggle works.

- [ ] **Step 3: Low-spec matrix**

Manual eco on: confirm `mpvpaper` killed, visualiser hidden, Hypr `animations:enabled 0`, dashboard media/network intervals ×4 (observe `resourceUpdateInterval` behavior), cava bars 24.

- [ ] **Step 4: Dual-deploy and restart**

Deploy repo `shell/` to `~/.config/quickshell/caelestia/` (symlink-aware, respecting `.updateignore`), restart `qs -c caelestia`, repeat `powerSaver debug`.

- [ ] **Step 5: Commit any verification fixes separately (if clean, no commit needed)**
