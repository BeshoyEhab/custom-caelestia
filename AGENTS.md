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

## Workspace Overview (modules/workspaceoverview/)

**CRITICAL: Repeater with `property var` (JS array) models does NOT render delegates** in this Quickshell/Qt6 build. Delegates are created (Component.onCompleted fires, data is correct) but produce no visual output.

**Working patterns:**
- `model: <integer>` (e.g., `model: 3`, `model: root.workspacesShown`) — delegates render correctly
- `Component.createObject()` / `Qt.createQmlObject()` — dynamic creation works for JS data

**Solution used:** Dynamic object creation via `Component {}` + `createObject()`. Window data is stored in a JS array (`property var windowDataList`), and preview Items are created/destroyed in `onWindowDataListChanged`.

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

### install.sh
Interactive installer with 3 optional config sections:
1. **Core** (always installed): hyprland, quickshell, caelestia-cli; the C++ QML plugin is built locally (caelestia-shell is NOT installed from AUR — it conflicts with the locally-built plugin).
2. **Hyprland config**: window rules, keybinds, scripts, systemd, portal config
3. **Shell extras** (optional): fish, starship, btop, cava, kitty, foot, fuzzel, wlogout, fonts
4. **Quickshell config**: caelestia shell theme, modules, services

- **Reinstall-safe**: Uses `safe_deploy` that never destroys user files
- Reads `.updateignore` to skip user-customized files
- Symlink-aware: removes old symlinks before deploying

### update.sh
Auto-detects installed sections and only updates those. Options:
- `--on-conflict ask|replace|keep|backup|new` (default: ask)
- `--backup` - create safety backups before deploying
- `--dry-run` - show what would change without doing it
- `--non-interactive` - skip prompts, replace on conflict

### .updateignore
File patterns to skip during updates. Read from repo root + user config dirs.
Defaults: `custom/`, `monitors.lua`, `monitors.conf`, `shell.json`, `shell.json.bak`

## Key Files to Know

| Path | Purpose |
|---|---|
| `shell/services/Colours.qml` | Colour palette singleton |
| `shell/plugin/src/Caelestia/Config/` | C++ config backend (17 config classes) |
| `shell/flake.nix` | Nix flake definition |
| `install.sh` | Interactive installer (3 sections, reinstall-safe) |
| `update.sh` | Update script (.updateignore, auto-detect sections) |
| `.updateignore` | Files to skip during updates |
| `CMakeLists.txt` | Top-level CMake (project: caelestia-shell v2.0.3-custom) |
