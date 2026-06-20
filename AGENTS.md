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

## Key Files to Know

| Path | Purpose |
|---|---|
| `shell/services/Colours.qml` | Colour palette singleton |
| `shell/plugin/src/Caelestia/Config/` | C++ config backend (17 config classes) |
| `shell/flake.nix` | Nix flake definition |
| `install.sh` | Interactive installer |
| `update.sh` | Update script |
| `CMakeLists.txt` | Top-level CMake (project: caelestia-shell v2.0.3-custom) |
