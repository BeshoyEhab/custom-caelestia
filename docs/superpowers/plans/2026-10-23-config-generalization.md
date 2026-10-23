# Config/Screen Generalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the three competing screen/config idioms and the duplicated desktop-clock typography with one C++ screen-resolution model, one QML call-site policy, and one clock-text component.

**Architecture:** Attached `Config` and `Tokens` resolve their screen from the nearest `QQuickItem`/window when their QObject parent is not itself an item. That covers `Behavior`, `Connections`, and other raw QML objects without per-site hoists. Genuinely screenless singletons use `GlobalConfig`; code that explicitly addresses another screen uses `GlobalConfig.forScreen(name)`. The per-monitor overlay remains a complete read view, so global-only reads are debug-level, overlay writes still warn, and the startup sync is guarded from write warnings. Desktop-clock text is built in one `ClockText` component, which owns the `FontBuilder` chain and date formatting.

**Tech Stack:** Qt 6.11 / Quickshell QML, the C++ config plugin (`shell/plugin/src/Caelestia/Config`), bash guard tests, Node-free static QML checks.

**Spec:** none separate; this plan records the design decisions made from the repository inventory on 2026-10-23.

## Global Constraints

- Source of truth is `shell/`; the running shell loads `~/.config/quickshell/caelestia/`. Deploy changed QML with `./install.sh --update --on-conflict keep </dev/null`.
- Never edit `shell/upstream/`, never run `merge-upstream.sh merge-all`, never touch `~/.config/nvim`.
- Do not reload Hyprland for monitor changes; use `hyprctl eval`. Restarting `qs` is allowed.
- Any C++ change is built and installed by the user with `./install.sh --build` (needs sudo and a TTY), then followed by `./install.sh --update`.
- `bash tests/run.sh` must stay green. The 16 existing suites may become 17 with one new suite.
- Do not push. Commit locally per logical change.
- The live tree must match the repo after deploy: `diff -rq shell/modules ~/.config/quickshell/caelestia/modules` must print 0 lines.
- Do not widen manifest pruning to delete user files.

## Phase 1 Inventory

Measured on branch `master` at `fd423722` (custom tree only; `shell/upstream` excluded).

| Pattern | Files / count | Risk | Proposed owner |
|---|---|---|---|
| `contentItem.Config.*` | 24 occurrences in 9 files: `components/containers/StyledWindow.qml`, `modules/background/Background.qml`, `modules/cheatsheet/CheatSheet.qml`, `modules/displays/DisplaySwitcher.qml`, `modules/drawers/ContentWindow.qml`, `modules/drawers/Exclusions.qml`, `modules/drawers/Regions.qml`, `modules/lock/LockSurface.qml`, `modules/nexus/WindowFactory.qml` | Low. This is the correct contextual form for window-local UI. | QML call sites, no churn. |
| `GlobalConfig.forScreen(name)` | 6 occurrences: `services/Screens.qml` (2), `modules/background/Background.qml` (1), `modules/nexus/pages/panels/{Dashboard,Launcher,Sidebar}Panel.qml` (3) | Low. Correct when explicitly addressing another screen. | QML call sites. |
| `Config.forScreen(name)` alias | 3 occurrences, all in `modules/nexus/pages/panels/*Panel.qml` | Low, but a second spelling of the same operation. | QML call sites -> `GlobalConfig.forScreen`. Leave the C++ alias for compatibility but stop using it. |
| Bare `Config.*` in `pragma Singleton` files | 3 reads in 2 files: `services/Time.qml` (2), `services/Hypr.qml` (1) | Low correctness (silently global today), but warns on every startup. | QML call sites -> `GlobalConfig`. |
| `Config.*` in `Behavior` / `Connections` | 1 Behavior pair in `modules/background/Background.qml` and 1 in `cookie/CookieHands.qml`, plus a `Connections` target in `Background.qml`; currently hoisted | Medium: the hoists work, but the class will return whenever a new raw QObject is used. | C++ config layer (propagation), then the hoists can stay as cheap isolation. |
| `contentItem.Config.screen` / `contentItem.Tokens.screen` | 5 window roots each: `StyledWindow`, `CheatSheet`, `DisplaySwitcher`, `LockSurface`, `Nexus/WindowFactory` | Low. Intentional explicit screen handoff at window creation. | QML call sites, keep. |
| Global-only options read through a per-monitor overlay | 130+ startup warnings; observed `general.logo` x26 and each `launcher.*` x13 | Medium: noisy logs hide real config errors. The overlay intentionally mirrors global-only values for reads. | C++ config layer (`ConfigObject`). |
| Desktop clock font chain | 9 `Tokens.font.clock.build().family` reads across `ClockText.qml`, `CookieClock.qml`, `cookie/CookieDate.qml`, `cookie/CookieDial.qml` | Medium: repeated builder chains are how the `family()` vs `.build().family` bug reappeared. | QML helper: one `ClockText` component. |
| Desktop clock date formatting | 12 `Time.format(...)` calls in `DigitalClock.qml` + `cookie/CookieDate.qml` | Low/medium: two date stacks with the same month/day/weekday grammar. | QML helper: `ClockText` date properties. |
| Cookie hand animation | 3 near-identical `Behavior on rotation` + `RotationAnimation` blocks in `cookie/CookieHands.qml` | Low. Shapes differ (hour classic/hollow, minute classic, second dot/classic). | Deliberately left; a generic hand would obscure more than it saves. |
| Cookie dial tick rings | 4 `Repeater` rings in `cookie/CookieDial.qml` | Low. One file, different counts/radii/visibility. | Deliberately left. |
| Bar edge booleans | `barIsLeft/Right/Top/Bottom` repeated in `drawers/{ContentWindow,Exclusions,Interactions,Panels,Regions}.qml` | Low, unrelated to config resolution. | Deliberately left as a separate layout cleanup. |

**Policy decision (Phase 2):** choose (a) fix propagation in C++ and add an explicit `GlobalConfig` fallback at genuinely screenless call sites. Rejected:

- (b) a new per-screen helper API: it would add a fourth idiom and still require every call site to know whether it is screenless.
- (c) require `GlobalConfig` everywhere: correct for singletons, wrong for `Behavior`/`Connections` inside a per-screen window, where per-monitor values are the intended data.

The resulting rule is:

1. Inside a per-screen window, use `Config.*` / `Tokens.*`. The attached object now resolves through raw QObject parents to the nearest item/window screen, so `Behavior`, `Connections`, and inline objects need no hoist.
2. In a `pragma Singleton` or other genuinely screenless object, use `GlobalConfig.*` for global state and `GlobalConfig.forScreen(name)` when explicitly addressing another screen.
3. Global-only options are read through an overlay as a normal part of the overlay's complete read view. Only writes through the overlay warn; the startup sync is silent.

## Review Focus

1. A `Behavior` attached directly to an item inside a per-screen window must read the per-screen value, not silently fall back to global.
2. A `Connections` object in a per-screen window must resolve the same screen as its parent item.
3. A screenless singleton must not emit `Config.* accessed without a screen set`; it must use global values without noise.
4. An overlay's initial `syncFromGlobal` / `resyncFromGlobal` must not emit write warnings; a real QML write to a global-only option through an overlay must still warn.
5. The digital clock must keep its existing user-config font behavior, and cookie/analog text must not gain an unwanted raised-text style.
6. The clock must remain readable after the refactor: digital, cookie, and analog modes; bar clock; launcher; Nexus.

Each line gets a test in the task that owns it, or an explicit manual smoke step where the behavior is visual.

---

### Task 1: Guard tests (RED)

**Files:**
- Create: `tests/qml_config_scope_test.sh`
- Modify: `tests/qml_clock_bindings_test.sh`
- Modify: `tests/run.sh`

**Interfaces:**
- Produces: suite 17, `qml_config_scope_test`, which fails on the current tree and passes only after Tasks 2-4.

- [ ] **Step 1: Write the failing config-scope suite**

Create `tests/qml_config_scope_test.sh` with these checks:

```bash
#!/usr/bin/env bash
# Guard the one screen/config resolution policy:
# 1. Config/Tokens resolve a screen from the nearest item/window in C++.
# 2. Screenless singletons use GlobalConfig, never bare Config.
# 3. Explicit other-screen reads use GlobalConfig.forScreen, never Config.forScreen.
# 4. Global-only reads through an overlay are debug-level; writes still warn.
# 5. The overlay's startup sync is guarded from write warnings.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_DIR="$REPO_DIR/shell"
CFG="$SHELL_DIR/plugin/src/Caelestia/Config"
FAIL=0
fail() { echo "  FAIL $1"; FAIL=1; }
pass() { echo "  PASS $1"; }

echo "═══ qml_config_scope ═══"

# 1. Shared resolver exists and both attached types use it.
[[ -f "$CFG/screenresolver.hpp" ]] \
    && pass "screenresolver.hpp exists" \
    || fail "missing $CFG/screenresolver.hpp"
for f in configattached.cpp tokensattached.cpp; do
    grep -q 'screenNameForObject<' "$CFG/$f" \
        && pass "$f uses screenNameForObject" \
        || fail "$f does not use screenNameForObject"
done
grep -q 'QQuickItem' "$CFG/screenresolver.hpp" && grep -q 'QQuickWindow' "$CFG/screenresolver.hpp" \
    && pass "resolver walks items and windows" \
    || fail "resolver does not walk items/windows"

# 2. The old warning class is gone.
HITS=$(grep -rn 'accessed without a screen set' "$CFG" | wc -l)
[[ "$HITS" -eq 0 ]] \
    && pass "no 'accessed without a screen set' warning" \
    || fail "$HITS old screenless warnings remain"

# 3. Screenless singletons do not use bare Config.
BARE=$(grep -rnE '(^|[^A-Za-z0-9_.])Config\.' "$SHELL_DIR/services" --include='*.qml' | wc -l)
[[ "$BARE" -eq 0 ]] \
    && pass "no bare Config.* in shell/services singletons" \
    || fail "$BARE bare Config.* read(s) in shell/services"

# 4. One spelling for explicit other-screen config.
FORSCREEN=$(grep -rn 'Config\.forScreen' "$SHELL_DIR" --include='*.qml' --exclude-dir=upstream | wc -l)
[[ "$FORSCREEN" -eq 0 ]] \
    && pass "no Config.forScreen in QML" \
    || fail "$FORSCREEN Config.forScreen call(s); use GlobalConfig.forScreen"

# 5. Global-only reads are debug; writes are still warnings and sync is guarded.
READ=$(grep -c 'qCDebug(caelestia::config::lcConfig, "Reading global-only option' "$CFG/configobject.hpp")
WRITE=$(grep -c 'qCWarning(caelestia::config::lcConfig, "Writing global-only option' "$CFG/configobject.hpp")
SYNC=$(grep -c 'QScopedValueRollback<bool>' "$CFG/configobject.cpp")
[[ "$READ" -eq 1 && "$WRITE" -eq 1 && "$SYNC" -ge 2 ]] \
    && pass "global-only read is debug, write is warning, sync is guarded" \
    || fail "global-only warning policy is not implemented (read=$READ write=$WRITE sync=$SYNC)"

exit $FAIL
```

- [ ] **Step 2: Add clock-centralization checks**

In `tests/qml_clock_bindings_test.sh`, add:

```bash
# 6. The clock font builder is centralized in ClockText.qml.
CENTRAL=$(grep -rn 'Tokens\.font\.clock\.build()\.family' "$SHELL_DIR" \
    --include=*.qml --exclude-dir=upstream | grep -v 'modules/background/ClockText.qml' | wc -l)
[[ "$CENTRAL" -eq 0 ]] \
    && pass "clock family builder is centralized in ClockText.qml" \
    || fail "$CENTRAL clock family builder(s) outside ClockText.qml"

# 7. Digital-specific date formatting is centralized in ClockText.qml.
DIGITAL_DATES=$(grep -n 'Time\.format(' "$SHELL_DIR/modules/background/DigitalClock.qml" | wc -l)
[[ "$DIGITAL_DATES" -eq 0 ]] \
    && pass "DigitalClock uses ClockText date formatting" \
    || fail "$DIGITAL_DATES Time.format call(s) remain in DigitalClock.qml"
```

- [ ] **Step 3: Run the new suite and verify it fails**

Run: `bash tests/qml_config_scope_test.sh`
Expected: FAIL on the missing resolver / bare `Config.*` / global-only policy.

Run: `bash tests/qml_clock_bindings_test.sh`
Expected: FAIL on the clock-centralization checks.

- [ ] **Step 4: Wire suite 17 into the runner**

Add `test_suite "qml_config_scope_test" "tests/qml_config_scope_test.sh"` after the clock bindings line in `tests/run.sh`.

- [ ] **Step 5: Commit the failing tests**

```bash
git add tests/qml_config_scope_test.sh tests/qml_clock_bindings_test.sh tests/run.sh
git commit -m "test(config): pin the screen resolution and clock typography policy"
```

---

### Task 2: C++ screen resolution and global-only policy

**Files:**
- Create: `shell/plugin/src/Caelestia/Config/screenresolver.hpp`
- Modify: `shell/plugin/src/Caelestia/Config/configattached.hpp`
- Modify: `shell/plugin/src/Caelestia/Config/configattached.cpp`
- Modify: `shell/plugin/src/Caelestia/Config/tokensattached.hpp`
- Modify: `shell/plugin/src/Caelestia/Config/tokensattached.cpp`
- Modify: `shell/plugin/src/Caelestia/Config/configobject.hpp`
- Modify: `shell/plugin/src/Caelestia/Config/configobject.cpp`
- Modify: `shell/plugin/src/Caelestia/Config/CMakeLists.txt`

**Interfaces:**
- Produces: `template <typename Attached> QString caelestia::config::screenNameForObject(const QObject* object)`.
- Produces: private `Config::ensureScreen()` / `Tokens::ensureScreen()`, called by getters and parser-status hooks.
- Produces: `ConfigObject::isSyncing()` protected accessor and `m_syncing`.

- [ ] **Step 1: Implement `screenresolver.hpp`**

Create a header-only resolver. It walks `parent()` from the attached object's parent, prefers the nearest item's attached screen (which preserves an explicit `contentItem.Config.screen`), then the item's window screen, then any `QQuickWindow` screen. Return an empty `QString` when no screen is reachable.

```cpp
#pragma once

#include <qobject.h>
#include <qqml.h>
#include <qquickitem.h>
#include <qquickwindow.h>
#include <qscreen.h>

namespace caelestia::config {

template <typename Attached>
QString screenNameForObject(const QObject* object) {
    for (const QObject* current = object; current; current = current->parent()) {
        if (const auto* item = qobject_cast<const QQuickItem*>(current)) {
            if (const auto* attached =
                    qobject_cast<const Attached*>(qmlAttachedPropertiesObject<Attached>(item, false))) {
                if (!attached->screen().isEmpty())
                    return attached->screen();
            }
            if (const auto* window = item->window()) {
                if (const auto* screen = window->screen())
                    return screen->name();
            }
        }
        if (const auto* window = qobject_cast<const QQuickWindow*>(current)) {
            if (const auto* screen = window->screen())
                return screen->name();
        }
    }
    return {};
}

} // namespace caelestia::config
```

- [ ] **Step 2: Add `ensureScreen()` to `Config`**

In `configattached.hpp`, add `void ensureScreen();` next to `propagateScreen()`. In `configattached.cpp`:

```cpp
void Config::ensureScreen() {
    if (!m_screen.isEmpty())
        return;
    const auto screen = screenNameForObject<Config>(parent());
    if (!screen.isEmpty())
        inheritScreen(screen);
}
```

Call it from `componentComplete()`, from `attachedParentChange()` when `newParent` is not a `Config`, and at the top of every `CONFIG_ATTACHED_GETTER`. Remove the `accessed without a screen set` warning and the now-unused `m_complete` checks from the getter macro; keep `m_complete` if another path needs it, otherwise delete it. In `qmlAttachedProperties`, call `ensureScreen()` before returning the new object.

- [ ] **Step 3: Add `ensureScreen()` to `Tokens`**

Mirror the `Config` changes in `tokensattached.hpp` / `.cpp`. `resolveAppearance` becomes:

```cpp
const AppearanceConfig* resolveAppearance(GlobalConfig* config) {
    if (config)
        return config->appearance();
    return GlobalConfig::instance()->appearance();
}
```

Call `ensureScreen()` at the top of the `TOKENS_ATTACHED_GETTER` macro and in `sizes()`, plus `componentComplete()`, `attachedParentChange()`, and `qmlAttachedProperties()`. Remove the `Tokens.* accessed without a screen set` warnings.

- [ ] **Step 4: Make global-only reads quiet and sync writes silent**

In `configobject.hpp`:

- Change the read warning in `CONFIG_GLOBAL_PROPERTY` to `qCDebug(caelestia::config::lcConfig, ...)`.
- Change the write guard to `if (isOverlay() && !isSyncing())`.
- Add `protected: [[nodiscard]] bool isSyncing() const { return m_syncing; }` and `bool m_syncing = false;`.

In `configobject.cpp`, add `QScopedValueRollback<bool> syncing(m_syncing, true);` at the top of `syncFromGlobal()`, `resyncFromGlobal()`, and `onGlobalPropertiesChanged()`. Include `<qscopedvaluerollback.h>`.

- [ ] **Step 5: Add the resolver header to the module sources**

Add `screenresolver.hpp` to the `SOURCES` list in `shell/plugin/src/Caelestia/Config/CMakeLists.txt` so it is tracked by the QML module build.

- [ ] **Step 6: Build the plugin locally and run the harness**

Run:

```bash
cmake --build build -j"$(nproc)"
```

Expected: build succeeds.

Run the local harness from Task 0's temp config with `QML_IMPORT_PATH=$PWD/build/qml` and confirm the log contains no `QQuickBehavior`, `QQmlConnections`, `accessed without a screen`, or `global-only option` warning lines. The harness must print the per-screen probe values.

- [ ] **Step 7: Commit**

```bash
git add shell/plugin/src/Caelestia/Config/screenresolver.hpp \
    shell/plugin/src/Caelestia/Config/configattached.hpp \
    shell/plugin/src/Caelestia/Config/configattached.cpp \
    shell/plugin/src/Caelestia/Config/tokensattached.hpp \
    shell/plugin/src/Caelestia/Config/tokensattached.cpp \
    shell/plugin/src/Caelestia/Config/configobject.hpp \
    shell/plugin/src/Caelestia/Config/configobject.cpp \
    shell/plugin/src/Caelestia/Config/CMakeLists.txt
git commit -m "fix(config): resolve screens through raw QML parents"
```

---

### Task 3: QML call sites

**Files:**
- Modify: `shell/services/Time.qml`
- Modify: `shell/services/Hypr.qml`
- Modify: `shell/modules/nexus/pages/panels/DashboardPanel.qml`
- Modify: `shell/modules/nexus/pages/panels/LauncherPanel.qml`
- Modify: `shell/modules/nexus/pages/panels/SidebarPanel.qml`

**Interfaces:**
- Consumes: `GlobalConfig.bar`, `GlobalConfig.background`, `GlobalConfig.forScreen(name)`.
- Produces: no bare `Config.*` in `shell/services`, no `Config.forScreen` in QML.

- [ ] **Step 1: Replace screenless singleton reads**

In `Time.qml`, change `secondsNeeded` to:

```qml
readonly property bool secondsNeeded: GlobalConfig.bar.clock.showSeconds || GlobalConfig.background.desktopClock.enabled || (Visibilities.getForActive()?.dashboard ?? false)
```

In `Hypr.qml`, change `circleShowsIcon` to read `GlobalConfig.bar.workspaces.showAppIconOnActive`.

- [ ] **Step 2: Replace the Nexus alias**

In each of `DashboardPanel.qml`, `LauncherPanel.qml`, and `SidebarPanel.qml`, change:

```qml
const monitorConfig = Config.forScreen(root.nState.screen.name);
```

to:

```qml
const monitorConfig = GlobalConfig.forScreen(root.nState.screen.name);
```

- [ ] **Step 3: Run the config-scope suite**

Run: `bash tests/qml_config_scope_test.sh`
Expected: the QML checks pass; the C++ checks already pass from Task 2.

- [ ] **Step 4: Commit**

```bash
git add shell/services/Time.qml shell/services/Hypr.qml \
    shell/modules/nexus/pages/panels/DashboardPanel.qml \
    shell/modules/nexus/pages/panels/LauncherPanel.qml \
    shell/modules/nexus/pages/panels/SidebarPanel.qml
git commit -m "refactor(config): use GlobalConfig for screenless and explicit screen reads"
```

---

### Task 4: One clock-text component

**Files:**
- Modify: `shell/modules/background/ClockText.qml`
- Modify: `shell/modules/background/DigitalClock.qml`
- Modify: `shell/modules/background/CookieClock.qml`
- Modify: `shell/modules/background/cookie/CookieDate.qml`
- Modify: `shell/modules/background/cookie/CookieDial.qml`

**Interfaces:**
- Produces `ClockText` properties: `pointSize: real`, `scale: real`, `weight: int`, `letterSpacing: real`, `fontSettings: var`, `dateFormat: string`, `uppercaseDate: bool`, `raised: bool`.
- Consumes `Tokens.font.clock`, `Time.format`, and optional `DesktopClockFont` (`size`, `family`, `width`, `roundness`).

- [ ] **Step 1: Rewrite `ClockText.qml`**

Keep it a `StyledText`. Build the font once in the component:

```qml
StyledText {
    id: root

    property var fontSettings: null
    property real pointSize: 20
    property real scale: 1
    property int weight: -1
    property real letterSpacing: 0
    property string dateFormat: ""
    property bool uppercaseDate: false
    property bool raised: true

    readonly property real effectivePointSize: Math.max(1, Math.round(root.pointSize * root.scale * (root.fontSettings?.size ?? 1)))
    readonly property string clockFamily: Tokens.font.clock.build().family

    text: root.dateFormat.length > 0
        ? (root.uppercaseDate ? Time.format(root.dateFormat).toUpperCase() : Time.format(root.dateFormat))
        : ""

    font: {
        let b = Tokens.font.clock.size(root.effectivePointSize);
        if (root.weight > 0)
            b = b.weight(root.weight);
        if (root.clockFamily.length > 0)
            b = b.family(root.clockFamily);
        if (root.fontSettings) {
            b = b.vaxes({
                "wdth": root.fontSettings.width,
                "ROND": root.fontSettings.roundness
            });
        }
        if (root.letterSpacing !== 0)
            b = b.letterSpacing(root.letterSpacing);
        return b.build();
    }
    style: root.raised ? Text.Raised : Text.Normal
    styleColor: Colours.palette.m3shadow
}
```

- [ ] **Step 2: Refactor `DigitalClock.qml`**

Add `readonly property var digitalFont: Config.background.desktopClock.digital.font`, delete `clockFont()`, and replace every `ClockText`'s `font:` with `pointSize`/`scale`/`weight`/`letterSpacing`/`dateFormat`/`uppercaseDate`. Time, colon, seconds and AM/PM pass `fontSettings: root.digitalFont`. Date lines do not pass `fontSettings`, preserving the current typography. The month uses `dateFormat: "MMMM"` + `uppercaseDate: true`; the vertical month uses `dateFormat: "MMM dd"` + `uppercaseDate: true`.

- [ ] **Step 3: Refactor cookie text**

In `CookieClock.qml`, replace the three `StyledText` time indicators with `ClockText` (`raised: false`, `pointSize: (root.hourMarks ? 40 : 68)`, `scale: root.k`, `weight: Font.Bold`; the AM/PM uses the 20/26 size). Add `import ".."` to `cookie/CookieDate.qml` and `cookie/CookieDial.qml`.

In `CookieDate.qml`, replace the bubble/rect/below/border `StyledText`s with `ClockText` (`raised: false`), using `dateFormat` for `d`, `MM`, `dd`, `MMMM`, `dddd`; keep the border `dateText` property as `Time.format("ddd dd")` because it feeds the per-character layout. In `CookieDial.qml`, replace the number `StyledText` with `ClockText` (`raised: false`, `pointSize: 80`, `scale: root.k`, `weight: Font.Black`).

- [ ] **Step 4: Run the clock guard and suite**

Run: `bash tests/qml_clock_bindings_test.sh`
Expected: all checks pass, including centralization and no `Time.format` in `DigitalClock.qml`.

Run: `bash tests/clock_settings_test.sh`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/background/ClockText.qml \
    shell/modules/background/DigitalClock.qml \
    shell/modules/background/CookieClock.qml \
    shell/modules/background/cookie/CookieDate.qml \
    shell/modules/background/cookie/CookieDial.qml
git commit -m "refactor(clock): centralize clock typography and date text"
```

---

### Task 5: Deploy and verify

**Files:** deployed tree under `~/.config/quickshell/caelestia/`.

**Interfaces:** none new.

- [ ] **Step 1: Run the full suite**

Run: `bash tests/run.sh`
Expected: 17/17 suites pass.

- [ ] **Step 2: Ask the user to install the plugin**

The C++ change needs `sudo` and a TTY. Ask the user to run:

```bash
./install.sh --build
```

Do not run it yourself. If the build fails, stop and report the compiler output.

- [ ] **Step 3: Deploy QML**

Run:

```bash
./install.sh --update --on-conflict keep </dev/null
```

- [ ] **Step 4: Restart the shell and capture a fresh log**

Run:

```bash
SIG=$(ls -t /run/user/1000/hypr/ | head -1)
pkill -x qs
sleep 1
setsid env HYPRLAND_INSTANCE_SIGNATURE="$SIG" qs -c caelestia >/tmp/opencode/qs-config-generalization.log 2>&1 < /dev/null &
```

- [ ] **Step 5: Grep the targeted warning strings**

Run:

```bash
grep -c 'Config\..*accessed without a screen set' /tmp/opencode/qs-config-generalization.log
grep -c 'global-only option' /tmp/opencode/qs-config-generalization.log
grep -c 'Unable to assign a function' /tmp/opencode/qs-config-generalization.log
```

Expected: `0` for each. Also grep for `QQuickBehavior` and `QQmlConnections`; expect 0.

- [ ] **Step 6: Verify the live tree**

Run:

```bash
diff -rq shell/modules ~/.config/quickshell/caelestia/modules
```

Expected: no output.

- [ ] **Step 7: Visual smoke**

Use `grim` on the clock, bar, launcher and Nexus. Check digital and cookie clock modes, the bar clock, a launcher open, and the Nexus clock page. Report the screenshots and any visible regression.

- [ ] **Step 8: Commit the final state**

If deploy or verification changed tracked files, commit only those changes. Do not commit deployed copies.

---

## Self-Review

- **Spec coverage:** screen resolution policy -> Tasks 2-3; global-only warnings -> Task 2; clock duplication -> Task 4; tests -> Task 1; deploy -> Task 5.
- **Step scan:** every code step names the file and signature; every test step has a command and expected result.
- **Type consistency:** `screenNameForObject<Attached>` is used by both attached types; `ClockText` property names are used consistently in all refactored clock files.
- **Review focus:** each item has a static guard in Task 1 or a live smoke check in Task 5.
- **Deliberate leftovers:** cookie hand/dial local repetition and the bar-edge boolean duplication are documented in the inventory and not changed.
