# AGENTS.md

## Project Overview

**custom-caelestia** is a Hyprland desktop environment that merges [Caelestia Shell](https://github.com/caelestia-dots/shell) with [End-4's illogical-impulse](https://github.com/end-4/dots-hyprland) keybindings and utilities.

- **Author:** [Bisho](https://github.com/Bisho)
- **Git remote:** `https://github.com/BeshoyEhab/custom-caelestia.git`
- **Previously named:** "Caelestia-Impulse" / "Celestimpulse" (renamed to "custom-caelestia")

## Important: Shell Config Locations

The shell runs via `qs -c caelestia` which loads from the **user config directory**, NOT the source directory.

| Location | Purpose |
|---|---|
| `~/.config/quickshell/caelestia/` | **Running config** - what `qs -c caelestia` actually loads |
| `/etc/xdg/quickshell/caelestia/` | System-installed config (fallback) |
| `<repo>/shell/` | Source files you edit |

**Always edit files in BOTH locations** when making changes:
1. `<repo>/shell/` (source of truth for version control)
2. `~/.config/quickshell/caelestia/` (what actually runs)

Alternatively, symlink the source into the user config directory.

## Known Issues & Solutions

### "Colours is not defined" ReferenceError

**Symptom:** QML pages render black icons/text instead of palette-colored ones.

**Cause:** Missing `import qs.services` - the `Colours` singleton is defined in `shell/services/Colours.qml` and exposed via the `qs.services` module.

**Fix:** Add `import qs.services` to the QML file's imports. Every QML file that uses `Colours.palette.*` must import this module.

**Example fix:**
```qml
// Before (broken)
import qs.components
import qs.components.controls
import qs.modules.nexus.common

// After (fixed)
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common
```

### Files affected by this issue
- `modules/nexus/pages/UpdatesPage.qml`
- `modules/nexus/pages/PluginsPage.qml`

### Bar Rendering (modules/bar/)

The bar uses an `Item` root with a split layout (`topLayout` + `bottomLayout` + active window loader), replacing upstream's `DelegateChooser`. Entry components are loaded via inline `TopLoader`/`BottomLoader` components.

**Current entry layout (hardcoded in Bar.qml):**
- `topLayout`: `logo`, `workspaces`
- `middle`: `activeWindow` (separate `Loader`)
- `bottomLayout`: `tray`, `clock`, `statusIcons`, `power`

**Critical rules:**
1. **`pragma ComponentBehavior: Bound` must NOT be used in Bar.qml** — it prevents inline component loaders from resolving component references.
2. **No `ColumnLayout` root** — the root is `Item` with separate `ColumnLayout` for top/bottom sections.
3. **Popout widths use Tokens** — each popout has a dedicated token: `batteryWidth` (250), `networkWidth` (320), `kbLayoutWidth` (320), `bluetoothWidth` (300), `trayMenuWidth` (300). Never hardcode pixel values.
4. **ContentWindow.qml BarWrapper anchoring**: For vertical bars, use `anchors.top/parent.top` + `anchors.bottom/parent.bottom`. For horizontal bars, use `anchors.left/parent.left` + `anchors.right/parent.right`. Never use conditional logic that removes both top AND bottom anchors for vertical bars — the BarWrapper gets 0 height and nothing renders.
5. **BarWrapper has no `implicitHeight`** — it gets its height from parent anchors (top+bottom for vertical, left+right for horizontal).
6. **`Tokens.sizes.bar.innerWidth`** is the content width; `contentWidth = innerWidth + padding*2`.

### Display switcher (SUPER+P)

Windows-style projection picker: main screen, duplicate, extend (left/right/up/down of the main), second-screen-only, plus a workspace pin.

| File | Purpose |
|---|---|
| `shell/services/Displays.qml` | Singleton: refresh from `hyprctl monitors all -j`, apply, heal, persistence |
| `shell/services/DisplayMath.js` | Pure layout math, Lua generation, `healRules`, `keepsAPhysicalOutput`, `isVirtual` |
| `shell/modules/displays/DisplaySwitcher.qml` | Real window (FloatingWindow), IPC target `displays` |
| `tests/display_math_test.js` | Node suite (wrapped by `tests/display_math_test.sh`) |
| `tests/displays_e2e_test.sh` | Opt-in live test (`DISPLAYS_E2E=1`), creates a headless output |

Writes the same files as nwg-displays 0.4.3 so both tools share state:
`~/.config/hypr/monitors.lua` (`hl.monitor({...})`), `~/.config/hypr/workspaces.lua` (`hl.workspace_rule({...})`), and `~/.config/caelestia/displays.json` (`{main, secondary, workspace, placement}`).

Rules that must not regress:

1. **Apply with `hyprctl eval`, never `hyprctl reload`.** Reloading while a virtual output was disabled crashed Hyprland 0.56. The files are still written for the next login.
2. **`hl.monitor` merges into the rule already stored for that output.** An omitted field keeps its old value, so `disabled` and `mirror` are sticky: "main only" then "extend" left the second screen off, and "duplicate" then "extend" left it mirrored. Every enabled rule written by `luaMonitor()` states `disabled = false` and `mirror = ""` (or the mirror target) explicitly — runtime `eval` and the file both, because startup `heal()` reloads that file into the live rules.
3. **`keepsAPhysicalOutput()` guard.** Any layout that would leave only HEADLESS/FALLBACK enabled is refused with a visible message. A persisted "second only" on a transient virtual output left the next session with the panel disabled — that was the black-screen incident. `FALLBACK` is Hyprland's automatic output when every real output is off; treat it as virtual.
4. **Startup `heal()`.** When no physical output is active (or the panel is enabled but 0x0), rewrite a safe layout and `hyprctl reload`. Reload is used only here, the written file always keeps a physical panel on, and a failed heal is retried at most once a minute so the monitor poll cannot reload in a loop.
5. `hyprctl keyword` does not work under the Lua parser; use `eval`/`dispatch`.
6. `hyprctl monitors all -j` reports `mirrorOf` as the target monitor **ID string**, so mode detection compares both id and name.
7. `setMode("main")` must work with a single display (it writes the file and prunes workspace pins for missing outputs). Workspace pins are only kept for outputs the new layout leaves enabled.
8. **Never read a derived binding inside its source's change handler.** In `LayoutPreview.rebuild()`, `onMonitorsChanged` fires before QML has invalidated the bindings that depend on `monitors`, so a bound `activeMonitors` still returns the previous (empty) list and the preview stays blank until the next refresh. Filter `monitors` inline there; the same pattern caused the "no screen until I press reload" report.
9. The main/second monitor button rows are horizontal `ListView`s: size them with `Math.max(46, contentHeight)`, not a fixed 46, or the `ToggleButton` (≈50px) is clipped at the bottom.
10. `DisplaySwitcher` retries `Displays.refresh()` every 600ms while `monitors` is empty (the first `hyprctl` after login can beat Hyprland), capped at 20 tries, and `Displays.refresh()` queues a run if `hyprctl` is already in flight.

## Cheat sheet (SUPER+/)

Dynamic sheet built from `hyprctl binds -j` (the OSD moved to SUPER+Shift+/).

| File | Purpose |
|---|---|
| `shell/services/Keybinds.js` | Pure parser/grouping/filtering (`parseBinds`, `group`, `filterBinds`) |
| `shell/services/KeybindsModel.qml` | Singleton state: groups, rows, query, `includeUnlabeled`, reload |
| `shell/modules/cheatsheet/CheatSheet.qml` | Window, IPC target `cheatsheet`, `configreloaded` refresh |
| `shell/modules/cheatsheet/Content.qml` | Search field, category headers, keycap rows |
| `tests/keybinds_parse_test.js` | Node suite (wrapped by `tests/keybinds_parse_test.sh`) |

- Description prefix before `": "` is the category; binds without one go to `Unlabeled` and are **hidden by default** (toggle in the header).
- Repetitive binds collapse: workspace 1-10 → `<Number>`, keeping only the first. Directions are **not** merged: "focus left" and "focus right" are different actions, and merging produced eight-combo rows.
- Binds with the same description (case-insensitive) are the same action: they share one row, with one keycap line per combo (a nested `ListView` over `combos`).
- Hyprland reports `key: ""` for binds written as `code:<n>` (the loop-generated workspace binds); the parser recovers them from a trailing number in the description.
- Keycaps use Windows-style labels (`⊞ Ctrl Alt Shift`) and fit five slots in a 290px column. A `Repeater` over a JS array does not render, so the row spells out five `KeyCap` slots.
- **Both this popup and the display switcher are real `FloatingWindow` toplevels**, not layer-shell surfaces, so SUPER+Q closes them instead of the app behind. They get `float` + `center` window rules matched by title (`^(Keyboard shortcuts)$`, `^(Displays)$`) in `hyprland/.config/hypr/hyprland/rules.lua`; keep the titles and rules in sync. `onVisibleChanged` mirrors a compositor close back into `opened`, otherwise the next toggle would be a no-op.
- Use the attached form `StyledScrollBar.vertical: StyledScrollBar { flickable: list }`. Putting it as a plain child of a `ListView` makes the list scroll itself to the end instead of drawing a bar.

## Captive portal / portal Wi-Fi

**Symptom:** On cafe/hotel Wi-Fi the sign-in page never loads, NetworkManager never reports `PORTAL`, and the bar/Nexus offer no way to reach the login page.

**Cause:** Three independent root causes, each with its own fix:

1. **Strict `DNSOverTLS=yes`** — portal networks hand out DNS servers that don't speak DNS-over-TLS, so every lookup fails and the login page is unreachable.
   **Fix:** `system/resolved.conf.d/10-captive-portal.conf` (`DNSOverTLS=opportunistic`) applied to `/etc/systemd/resolved.conf.d/` by `install.sh`'s `deploy_system_config()` (needs `sudo`; skipped with `--no-install`, shown as `Would install` / `Would restart systemd-resolved` by `--dry-run`).
2. **No connectivity check** — without NetworkManager's connectivity probe there is no `PORTAL`/`LIMITED`/`unknown` state for the shell to react to.
   **Fix:** `system/NetworkManager/conf.d/30-connectivity-enabled.conf` (`enabled=true`), applied by the same `deploy_system_config()`; the runtime half is the unprivileged `busctl set-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager ConnectivityCheckEnabled b true`.
3. **No portal helper** — nothing probes for the portal or opens the login page.
   **Fix:** the `qs.services.CaptivePortal` singleton (`shell/services/CaptivePortal.qml`) driven by the `online|portal|unknown` classifier `hyprland/.config/hypr/hyprland/scripts/captive_portal_probe.sh`, plus the two "Sign in to network" rows: `shell/modules/bar/popouts/Network.qml` (bar network popout) and `shell/modules/nexus/pages/NetworkPage.qml` (Nexus, with "Recheck connection"). IPC: `qs -c caelestia ipc call captivePortal state|probe|open`, plus the debug-only `probeAuto <url>`, which drives the *automatic* open path (toast + episode key + launch) against a local fixture behind exactly the same guards.

**Verification notes:**
- On a healthy network `qs -c caelestia ipc call captivePortal state` must show `connectivity=full`, `connected=true`, `iface=` naming a real device (e.g. `wlp1s0`, never `lo`) and `active=false`; `ipc call captivePortal open` probes first and opens **no** window when the probe returns `online` (`lastProbe=online`).
- **Known limit that reproduces the original symptom (not handled):** a gated portal that answers `200` with the exact body `NetworkManager is online` classifies `online`, *and* NetworkManager — probing that same URI — reports `full`, so `active` is false, no row appears and there is no manual escape.
- **Known limit where the row still works:** an HTTPS-only portal with no redirect classifies `unknown`; `unknown` is part of the `active` gate, so the row appears and opens the URL by hand.
- **Residuals ruled on by the review ledger:**
  (a) `Nmcli.refreshStatus()`'s loopback exclusion closes the observed instance of its defect class, not the class itself: `lo` reports `connected (externally)` even with every real device down (now skipped), but an externally-connected virtual device (`docker0`/`virbr0`, `tun0`/`wg0`) still counts as connected. Blacklist over whitelist is deliberate — a blacklist fails *open* (an extra sign-in row), a whitelist fails *closed* (the rows never appear, i.e. the original bug).
  (b) The automatic path's reset when connectivity returns to `full`, and its 60 s floor, are reasoned from the code, not executed live (connectivity never left `full` on the test machine).
- Tests never touch `/etc`: `deploy_system_config` honours `SYSTEM_CONFIG_ROOT` and `CI_TEST`, and `tests/setup_scripts_test.sh` stubs `sudo`/`systemctl` on `PATH`.

## Workspace Overview (modules/workspaceoverview/)

**CRITICAL: Repeater with `property var` (JS array) models does NOT render delegates** in this Quickshell/Qt6 build. Delegates are created (Component.onCompleted fires, data is correct) but produce no visual output.

**Working patterns:**
- `model: <integer>` (e.g., `model: 3`, `model: root.workspacesShown`) — delegates render correctly
- `Component.createObject()` / `Qt.createQmlObject()` — dynamic creation works for JS data

**Solution used:** Dynamic object creation via `Component {}` + `createObject()`. Window data is stored in a JS array (`property var windowDataList`), and preview Items are created/destroyed in `onWindowDataListChanged`.

**Drag-and-drop (OverviewGrid.qml):**
- Cross-workspace: `hl.dsp.window.move({ window = "address:0x...", workspace = N, follow = false })` (`movetowsilent` non-Lua). `DropArea.onExited` must NOT reset `dragTargetWorkspace`.
- Same-workspace: floating windows reposition via `window.move({ x, y })`; tiled windows nudge one layout slot toward the drop point via `window.move({ window, direction })` (single dispatch: no focus change, no cursor warp, stays tiled). Exact positional insert is impossible — Hyprland exposes no such dispatcher. Never dispatch `cursor.move` on drag paths (Hyprland warp + our restore fight; see git log Sep 2026).
- Click vs drag split: `onReleased` handles drags, `onClicked` handles focus/close (guarded by `wasDragged` flag set in `onXChanged/onYChanged`).
- `WindowPreview.qml` / `WorkspaceCell.qml` were deleted (dead code); do not re-add.

**Known failures:**
- `ListModel` with `required property` causes "Unable to assign [undefined]" errors that break the entire component
- `model: root.windowDataList.length` with `root.windowDataList[index]` access also causes assignment errors

## Settings App ("Nexus")

The settings app lives at `shell/modules/nexus/`. Key files:

| File | Purpose |
|---|---|
| `PageRegistry.qml` | Defines all 11 top-level pages with labels, icons, descriptions, categories |
| `PageCompRegistry.qml` | Maps page indices to QML components |
| `NexusState.qml` | State management (current page, sub-page stack) |
| `common/NavRow.qml` | Reusable nav row component (icon + label + status + chevron) |
| `common/SectionHeader.qml` | Section header component |
| `common/ConnectedRect.qml` | Rounded rectangle group component |
| `common/PageBase.qml` | Base page layout |

### Pages
- `pages/WallpaperAndStyle.qml` - Appearance settings
- `pages/NetworkPage.qml` - Wi-Fi/ethernet
- `pages/BluetoothPage.qml` - Bluetooth devices
- `pages/AudioPage.qml` - Volume/audio devices
- `pages/UpdatesPage.qml` - System updates
- `pages/PluginsPage.qml` - Plugin management
- `pages/PanelsPage.qml` - Dashboard, taskbar, launcher, sidebar
- `pages/AppsPage.qml` - Default apps, favourites
- `pages/ServicesPage.qml` - Poll intervals, lyrics, GPU
- `pages/LanguageAndRegion.qml` - Locale, weather, units
- `pages/AboutPage.qml` - System info, versions

### Sub-pages
- `pages/panels/` - DashboardPanel, TaskbarPanel, LauncherPanel, SidebarPanel
- `pages/panels/taskbar/` - BarWorkspaces, BarActiveWindow, BarTray, BarStatusIcons, BarClock
- `pages/wallandstyle/` - WallpaperSelect, WallpaperCategory, ColourSelect
- `pages/apps/` - AllApps, AppInfo
- `pages/audio/` - AppVolumes
- `pages/bluetooth/` - BtDeviceInfo, BluetoothPairing
- `pages/services/` - NotificationsPage

## QML Conventions

### Colour tokens
Always use palette tokens from `Colours.palette`:
- `m3onSurface` - Primary text on surface
- `m3onSurfaceVariant` - Secondary text/icons on surface
- `m3outline` - Subtle text (descriptions, status)
- `m3outlineVariant` - Placeholder/placeholder text
- `m3primary` - Active/selected indicators
- `m3onPrimary` - Text on primary

### Component patterns
- `NavRow` - For navigation items (icon + label + status + chevron)
- `ToggleRow` - For boolean settings
- `StepperRow` - For numeric settings with +/- buttons
- `SelectRow` - For dropdown selections
- `InfoRow` - For read-only display values
- `ConnectedRect` - For grouping related rows
- `SectionHeader` - For section dividers

### Page structure
```qml
PageBase {
    id: root
    title: qsTr("Page Title")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Content here
    }
}
```

## Build System

- **CMake** builds the C++ plugin (`shell/plugin/`)
- **Quickshell** loads QML files directly (no build step for QML)
- **Nix** packages everything (`shell/nix/default.nix`)
- Run with `qs -c caelestia` from `~/.config/quickshell/caelestia/`

## Install & Update Scripts

`install.sh` is the single setup script. `update.sh` is a compat stub that just
`exec`s `install.sh` — deployed `~/.config/quickshell/caelestia/scripts/update.sh`
symlinks and the Nexus Updates page keep working unchanged.

| Command | Purpose |
|---|---|
| `./install.sh` | Interactive menu (bare flags with no command → `--update`) |
| `./install.sh --install` | Full install: packages + configs + plugin |
| `./install.sh --update` | Update deployed configs (auto-detects installed sections) |
| `./install.sh --check` | Read-only status (`REPO_DIR`/`BRANCH`/`AHEAD`/`BEHIND`/`DIRTY`/`PLUGINS_STALE`); exit 0 = up to date, 1 = updates, 2 = error |
| `./install.sh --build` | Rebuild + install the C++ plugin only |

Shared flags (apply to any command): `--on-conflict ask|replace|keep|backup|new`,
`--backup`, `--dry-run`, `--force`, `--force-rebuild`, `--no-prune`, `--no-install`,
`--non-interactive`, `--rebuild-quickshell`, `-v/--verbose`, `-h/--help`.

Install sections:
1. **Core** (always installed): hyprland, quickshell, caelestia-cli; the C++ QML plugin is built locally (caelestia-shell is NOT installed from AUR — it conflicts with the locally-built plugin).
2. **Hyprland config**: window rules, keybinds, scripts, systemd, portal config
3. **Shell extras** (optional): fish, starship, btop, cava, kitty, foot, fuzzel, wlogout, fonts
4. **Quickshell config**: caelestia shell theme, modules, services

- **Reinstall-safe**: Uses `deploy_tree` that never destroys user files. Each deploy records a sha256 baseline per file; the next update updates files you never touched, and asks only about files you edited (showing the diff, defaulting to keeping yours, and saving a timestamped `.bak` when you take the repo version).
- Reads `.updateignore` to skip user-customized files
- Symlink-aware: removes old symlinks before deploying
- **Manifest pruning**: each deploy records `rel<TAB>mtime<TAB>sha256` in `.deploy-manifest`
  inside the target; update deletes files removed from the repo unless `--no-prune`
  (user-modified files are kept and warned about)

### .updateignore
File patterns to skip during updates. Read from repo root + user config dirs.
Defaults: `custom/`, `monitors.lua`, `monitors.conf`, `shell.json`, `shell.json.bak`

## Upstream Sync Cadence

- **Plan an upstream sync at least once every 2 weeks.** Never let the gap between sync plans (`~/caelestia` → `shell/upstream` → `shell/`) exceed 14 days, even if only a few upstream commits landed.
- Freshness check: `git -C ~/caelestia fetch origin && git -C ~/caelestia rev-list --count HEAD..origin/main`; last-plan date = newest `docs/superpowers/plans/*-upstream-sync.md`.
- Every sync gets its own plan in `docs/superpowers/plans/YYYY-MM-DD-upstream-sync.md`, modeled on `2026-09-21-upstream-sync.md` / `2026-10-10-upstream-sync.md`: refresh vendored base → verbatim-copy untouched files → targeted 3-way hand-ports of functional commits only → build/boot/deploy verification.
- Do not port cosmetic-only upstream commits (clang-tidy sweeps, formatting) into hand-merged custom files; they stay in `shell/upstream` only.
- Never run `./merge-upstream.sh merge-all`.

## Key Files to Know

| Path | Purpose |
|---|---|
| `shell/services/Colours.qml` | Colour palette singleton |
| `shell/services/CaptivePortal.qml` | Captive-portal helper singleton (probe chain, auto-open guard, IPC target `captivePortal`) |
| `shell/services/Displays.qml` | Display layout service (SUPER+P), IPC target `displays` |
| `shell/services/Keybinds.js` | Keybind parser used by the SUPER+/ cheat sheet |
| `shell/modules/cheatsheet/` | Cheat sheet window and UI |
| `hyprland/.config/hypr/hyprland/scripts/captive_portal_probe.sh` | Portal probe classifier — prints `online\|portal\|unknown <url> <http-status>`, exits `0\|1\|2` |
| `hyprland/.config/hypr/hyprland/scripts/open_portal_browser.sh` | Portal sign-in launcher — preferred Brave app-window on a throwaway profile, `xdg-open` fallback, refuses non-http(s) URLs (exit 2) |
| `system/resolved.conf.d/10-captive-portal.conf` | DoT drop-in (`DNSOverTLS=opportunistic`) installed into `/etc` by `deploy_system_config()` |
| `system/NetworkManager/conf.d/30-connectivity-enabled.conf` | NetworkManager connectivity-check drop-in (`enabled=true`) installed into `/etc` by `deploy_system_config()` |
| `shell/plugin/src/Caelestia/Config/` | C++ config backend (17 config classes) |
| `shell/flake.nix` | Nix flake definition |
| `install.sh` | Unified setup script: menu / `--install` / `--update` / `--check` / `--build` |
| `update.sh` | Compat stub — `exec`s `install.sh` |
| `.updateignore` | Files to skip during updates |
| `CMakeLists.txt` | Top-level CMake (project: caelestia-shell v2.0.3-custom) |
