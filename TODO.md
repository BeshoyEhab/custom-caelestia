# custom-caelestia

## User Priorities (New)

### 1. Bar Position Generalization (Any Direction) [PRIORITY]
Move bar from hardcoded left to any of 4 sides (Top, Bottom, Left, Right) via config.
- [ ] Add `bar.position` to `shell.json`.
- [ ] Update `BarWrapper.qml` and `Bar.qml` to handle orientation (RowLayout vs ColumnLayout).
- [ ] Adjust `ContentWindow.qml` and `Panels.qml` margins based on bar position.
- [ ] Update `Interactions.qml` and `Regions.qml` for edge-awareness.
- [ ] Add settings UI in `Nexus` to change bar position.

### 2. Generalized Hover Area [PRIORITY]
Apply "hover to open" pattern to any widget (Launcher, Sidebar, Dashboard, OSD, etc.).
- [ ] Refactor `Interactions.qml` to use a more generic `inHoverArea` approach for all drawers.
- [ ] Ensure any widget can be configured with its own hover edge/size.

### 3. Dynamic Colors & Theming
- [ ] Fix color generation from wallpaper (Material You style).
- [ ] Investigate why `matugen` or `caelestia-cli` isn't updating `scheme.json`.
- [ ] Add option for random wallpaper every N hours in settings.
- [ ] Fix wallpaper randomization (currently broken).
- [ ] Fix white theme in some apps (ensure GTK/Qt themes are correctly applied).
- [ ] Add color scheme selection to Settings app.

### 4. Background Clock
- [ ] Add/Enable desktop clock in background (similar to end-4 dots).
- [ ] Add settings UI for clock position, scale, and styling.

### 5. Utility Fixes
- [x] **CopyQ**: Fix not closing on item select or mouse-away. — Fixed by enabling "Hide main window" in CopyQ Preferences > Layout (Wayland limitation).
- [x] **Launcher Calculator**: Fix hardcoded terminal/shell when opening `qalc`. — Fixed: replaced `fish -C` with `sh -c` (POSIX standard).
- [x] **Discord**: Fix screen share source selection window not opening. — Added xwaylandvideobridge window rules (no_initial_focus, no_focus, no_anim, no_blur, max_size 1x1, opacity 0).
- [ ] **Settings App**: Add featured wallpapers and missing color schemas.

### 6. Bugs
- [x] **Launcher Search**: Typing "f" shows Fluid above Ferdium despite Ferdium being more frequently used. Same for "d" showing something above Discord. Scoring/weighting needs fixing. — Fixed: short queries (≤3 chars) now always use match+frequency scoring instead of FZF.
- [x] **Settings App**: Broken layout after recent changes — text mixed in buttons, panels halved. — Fixed: rebuilt C++ plugin from custom source, synced live config, fixed UpdatesPage Timer/Item wrapper issue.
- [x] **OSD**: Mic mute was opening OSD. — Fixed: removed `onSourceMutedChanged` handler from `osd/Wrapper.qml`.
- [x] **Hover indicators**: Were visible by default. — Fixed: set `showHoverIndicator: false` for dashboard, launcher, sidebar in `shell.json`.

### 7. Settings App — Script Integration & UI/UX Overhaul [IN PROGRESS]

> **Goal:** Make the settings app fully functional with real commands (not fake Timers),
> consistent across all pages, and polished UI/UX. Each part is independently completable.

---

#### Part A: Script Flags for GUI Integration

**Files:** `update.sh`, `install.sh`

##### A1. `--check` flag (read-only, no side effects)

Add `--check` to `update.sh` that outputs machine-readable status:

```bash
./update.sh --check
```

Output format (one per line):
```
REPO_DIR=/home/Bisho/custom-caelestia
BRANCH=master
AHEAD=0
BEHIND=2          # commits behind origin
DIRTY=true        # has uncommitted changes
PLUGINS_STALE=true  # plugin source newer than build stamp
```

Implementation:
- `git fetch --dry-run` to check behind/ahead (no actual fetch)
- `git status --porcelain` for dirty state
- `find plugin/src -newer build/.plugin_build_stamp` for plugin stale check
- Exit code: 0 = up to date, 1 = updates available, 2 = error

##### A2. `--non-interactive` flag

Add `--non-interactive` to both scripts that:
- Skips all `read -p` prompts
- Uses default conflict strategy: `backup` (saves old as `.old`, uses repo version)
- Uses default for extra dotfiles: `no` (skip)
- Still requires sudo (piped via `echo password | sudo -S` or ` askpass`)

Usage from QML:
```bash
./update.sh --non-interactive 2>&1
```

##### A3. Sudo password from GUI

Two approaches (pick one):

**Option 1: Polkit agent** (recommended)
- Use `pkexec` instead of `sudo` for plugin install
- The desktop's polkit agent handles the password dialog
- No password handling in scripts at all

**Option 2: Pipe password**
- QML reads password from a config file or prompts user
- Script accepts `UPDATE_SUDO_PASS` env var
- `UPDATE_SUDO_PASS=xxx ./update.sh --non-interactive`

Recommendation: Option 1 (polkit) — it's the standard Linux way and secure.

---

#### Part B: Settings App — Real Commands

**Files:** `shell/modules/nexus/pages/UpdatesPage.qml`

##### B1. Replace fake Timers with real Process calls

```qml
import qs.services

Process {
    id: updateCheckProc
    command: ["sh", "-c", "~/.config/quickshell/caelestia/scripts/update.sh --check"]
    onRunningChanged: {
        if (!running) {
            // Parse stdout for BEHIND, DIRTY, PLUGINS_STALE
            // Update root.updateAvailable, root.statusText
        }
    }
}
```

##### B2. Update button states based on --check result

- "Check for updates" → runs `--check`, shows result
- "Update repository" → runs `update.sh --non-interactive`, shows progress
- "Deploy configurations" → runs `install.sh --non-interactive --no-install`
- "Reload shell" → runs `pkill quickshell && qs -c caelestia &`

##### B3. Handle script not found

```qml
// Before running, check if symlink exists
// Show "Repository not configured. Run install.sh first."
```

---

#### Part C: Settings App — Consistency Fixes

> Each checkbox is an independent task. Check off as completed.
>
> **Known visual bugs on Updates & Plugins pages:**
> - Black text on gray background (not using `Colours.palette.m3onSurface` properly)
> - Content not centered — ColumnLayout uses `anchors.horizontalCenter` but `width: root.cappedWidth` without `Layout.fillWidth`
> - Buttons/rows have wrong background colors (not using `Colours.tPalette.m3surfaceContainer`)
> - Icon colors don't match the rest of the app
> - Overall these pages look nothing like the other polished pages (Network, Audio, Bluetooth)

##### C1. UpdatesPage.qml — Fix structural + visual issues
- [x] Remove `Item` wrapper (move Timers inside ColumnLayout using a different pattern)
- [x] Add `first: true` / `last: true` to ConnectedRect button groups
- [x] Use `Layout.preferredHeight` consistently with other pages
- [x] Add `SectionHeader` before each section
- [x] Fix colors: all text must use `Colours.palette.m3onSurface` / `m3onSurfaceVariant`
- [x] Fix centering: use `Layout.fillWidth: true` instead of `anchors.horizontalCenter`
- [x] Fix button styling: use proper `IconTextButton` colors from M3 palette
- [x] Fix status icon color: use `Colours.palette.m3tertiary` for checkmark

##### C2. PluginsPage.qml — Fix structural + visual issues
- [x] Fix Repeater ConnectedRects: compute `first`/`last` from `index` and `model.count`
- [x] Fix font tokens: use `Tokens.font.body.large` for name, `Tokens.font.body.small` for description
- [x] Fix inner spacing: use `Tokens.spacing.extraSmall` instead of magic `2`
- [x] Fix padding: use standard row padding pattern
- [x] Fix colors: all text must use `Colours.palette.m3onSurface` / `m3onSurfaceVariant`
- [x] Fix centering: use `Layout.fillWidth: true` instead of `anchors.horizontalCenter`
- [x] Fix icon colors: use `Colours.palette.m3primary` for installed, `Colours.palette.m3outline` for not installed
- [x] Fix status indicator: use proper M3 tertiary/error colors

##### C3. WallpaperAndStyle.qml — Fix spacing
- [ ] Change ColumnLayout spacing from `Tokens.spacing.large` to `Tokens.spacing.extraSmall / 2`
- [ ] Remove manual `Layout.topMargin` hacks
- [ ] Add `SectionHeader` for each logical group

##### C4. AudioPage.qml — Add SectionHeaders
- [ ] Add `SectionHeader { text: "Output" }` before output section
- [ ] Add `SectionHeader { text: "Input" }` before input section
- [ ] Remove `Layout.topMargin` hack

##### C5. BluetoothPage.qml — Add SectionHeaders
- [ ] Add `SectionHeader { text: "Saved devices" }` before device list
- [ ] Add `SectionHeader { text: "Discoverable" }` before discoverable toggles
- [ ] Remove `Layout.topMargin` hack

##### C6. NetworkPage.qml — Fix padding
- [ ] Align network list delegate margins with standard row padding pattern

##### C7. AppsPage.qml — Fix first/last
- [ ] Add `first: true` to first DefaultRow in each group

---

#### Part D: Settings App — UI/UX Enhancements

##### D1. Error states for all pages
- [ ] UpdatesPage: show error message if script fails (not just "Up to date")
- [ ] BluetoothPage: show retry button on scan failure
- [ ] NetworkPage: show retry button on scan failure

##### D2. Loading states
- [ ] UpdatesPage: show spinner during real script execution (already has `checking` property)
- [ ] PluginsPage: add loading state while checking installed status

##### D3. Empty states
- [ ] PluginsPage: show "No plugins installed" when list is empty
- [ ] UpdatesPage: show "No repository configured" if script not found

##### D4. Visual polish
- [ ] Consistent `SectionHeader` usage across ALL pages
- [ ] Consistent `ConnectedRect` first/last grouping across ALL pages
- [ ] Consistent font tokens across ALL pages
- [ ] Consistent spacing tokens across ALL pages

---

#### Part E: Settings App — Functional Plugins & Updates

> Make the settings app actually control the system. Install/uninstall plugins,
> run updates, and manage services from the GUI.

##### E1. PluginsPage — Enable/Disable plugins via toggle
- [ ] Each plugin has a toggle (like other Nexus pages) to enable/disable
- [ ] Enable: start the plugin's background process (e.g., `copyq`, `easyeffects`, `hyprland-per-window-layout`)
- [ ] Disable: kill the plugin's process (`pkill <name>`)
- [ ] Check if plugin is running: `pgrep <name>` or `systemctl --user is-active <service>`
- [ ] Store enabled/disabled state in `~/.config/quickshell/caelestia/plugins.json`
- [ ] On shell restart, auto-start enabled plugins

##### E2. PluginsPage — Install/Uninstall plugins
- [ ] "Install" button on not-installed plugins runs `./install.sh` with the plugin name
- [ ] "Uninstall" button removes the plugin (if possible) or just disables it
- [ ] Show installation progress/status (spinner + status text)
- [ ] Handle sudo requirement for system-level plugins (polkit agent)

##### E3. UpdatesPage — Real update commands
- [ ] "Check for updates" runs `update.sh --check` and parses output
- [ ] "Update repository" runs `update.sh --non-interactive`
- [ ] "Deploy configurations" runs `install.sh --non-interactive --no-install`
- [ ] "Reload shell" runs `pkill quickshell && qs -c caelestia &`
- [ ] Show real-time output/status from scripts
- [ ] Handle script not found gracefully

##### E4. New page: Services
- [ ] List systemd user services related to Caelestia
- [ ] Toggle start/stop for each service
- [ ] Show service status (active/inactive/failed)
- [ ] Services: `caelestia-wallpaper`, `caelestia-random-wallpaper`, `caelestia-notifications`

##### E5. Plugin configuration
- [ ] Plugins can have settings (stored in `~/.config/quickshell/caelestia/plugins/<name>/config.json`)
- [ ] Settings page for each plugin with relevant options
- [ ] Examples: CopyQ theme, EasyEffects presets, Tesseract language

---

#### Part F: Colour Settings Page [NEW]

> **Files:** `shell/modules/nexus/pages/wallandstyle/ColourSelect.qml`

##### F1. Theme mode toggle
- [x] Dark/light mode toggle using `Colours.setMode()`
- [x] Reflect current state from `Colours.light`

##### F2. Transparency toggle
- [x] Enable/disable transparency using `GlobalConfig.appearance.transparency.enabled`
- [x] Show current base/layers values

##### F3. Colour palette preview
- [x] Show current Material 3 palette colours (primary, secondary, tertiary, surface)
- [x] Update live when wallpaper changes

##### F4. Wallpaper controls
- [x] Toggle wallpaper display on/off
- [ ] Link to WallpaperSelect sub-page for browsing

---

#### Part G: Plugin Management [NEW]

> **Files:** `shell/modules/nexus/pages/PluginsPage.qml`

##### G1. Plugin status detection
- [x] Show installed vs not-installed status
- [x] Show "Not installed" notice with error colour for missing plugins
- [x] Use `pgrep` to check if plugin process is running

##### G2. Plugin enable/disable
- [ ] Add toggle to start/stop plugin processes
- [ ] Store enabled/disabled state in config
- [ ] Auto-start enabled plugins on shell restart

##### G3. Plugin installation
- [ ] "Install" button that runs `./install.sh` with plugin name
- [ ] Show installation progress
- [ ] Handle sudo requirement

---

#### Implementation Order

1. **Part A** (scripts) — do first, everything depends on it
2. **Part B** (UpdatesPage real commands) — depends on Part A
3. **Part C** (consistency fixes) — independent, can be done in parallel
4. **Part D** (UI/UX) — independent, can be done in parallel
5. **Part E** (functional plugins) — depends on Parts A, B, C
6. **Part F** (colour settings) — independent, can be done in parallel
7. **Part G** (plugin management) — depends on Part A

Each Part can be a separate commit/PR. Parts C and D can be split into individual
checkboxes and done by different people.

---

## Done

### Hyprland Config
- [x] Lua config format (Hyprland 0.55+)
- [x] Global shortcuts: `caelestia:xxx` prefix (not `quickshell:xxx`)
- [x] Brightness IPC: `set +5%` / `set 5%-`
- [x] `numlock_by_default = false` in general.lua
- [x] Removed duplicate keybinds (D, U, P, SHIFT+P, V, L)
- [x] Removed non-existent features (cheatsheet, osk, mediaControls, overlay, wallpaperSelector, lightDark, panelFamilyCycle)
- [x] SUPER+D = maximize toggle, SUPER+G = dashboard
- [x] SUPER+ALT+F = fake fullscreen

### Launcher
- [x] Launcher hover-to-open from bottom, mouse-leave closes (unless typed)
- [x] Launcher toggle via SUPER key
- [x] Calculator auto-detection (math expressions show without `>calc` prefix)
- [x] Search: fuzzysort for ≤3 chars, levenshtein for >3 chars (auto-switch)
- [x] Search: frequency scoring with first-letter match bonus/penalty
- [x] Search: 1-char = 40% match / 60% freq, 2-char = 50/50, 3-char = 60/40, 4+ = 70/30

### Bar
- [x] Bar workspaces/apps fix: `required property var bar` → `property var bar`
- [x] Bar workspaces: pass `bar` from Bar→Workspaces→Workspace delegate chain
- [x] Workspace right-click → overview popout
- [x] Bar hide animation: 1.5x slower

### Sidebar & Drawers
- [x] Sidebar hover top-right corner (100x100px) opens it
- [x] Sidebar mouse-move closes it when opened via hover
- [x] Sidebar keybind-opened stays open regardless of mouse
- [x] Shortcuts.qml syntax error fixed

### Scroll Bounce
- [x] CustomMouseArea: 150ms cooldown for scroll direction-flip ignore
- [x] StyledFlickable: velocity 8000→2000, flickDeceleration 1500
- [x] `scroll_event_delay` increased from 50 to 200

### Theming
- [x] Dolphin: `QT_QPA_PLATFORMTHEME=kde` + `widgetStyle=Darkly` in kdeglobals
- [x] Cursor: `XCURSOR_THEME=Bibata-Modern-Classic` + `XCURSOR_SIZE=24` env vars
- [x] MaterialAdw Kvantum theme applied on startup

---

## Needs Testing (implemented but not verified)

- [ ] Calculator: test `2+3*4`, `100/3`, `2^8` etc. in launcher (uses `sh -c` now)
- [ ] Discord screen share: test with xwaylandvideobridge rules
- [ ] Search: test "D" shows Discord above Ferdium, "Di" same
- [ ] Search: test typo tolerance for queries >3 chars
- [ ] Bar hide animation: verify 1.5x speed feels right
- [ ] Workspace right-click: verify overview popout shows
- [ ] Workspace hover: verify thumbnails appear on hover in bar
- [ ] Dolphin dark theme: test after logout/login
- [ ] Scroll bounce: test on sidebar, dashboard, launcher with touchpad
- [ ] Wayscriber: `SUPER+SHIFT+D` daemon toggle, `SUPER+SHIFT+G` light toggle
- [ ] Random wallpaper: `Ctrl+Super+Alt+T` + systemd timer
- [ ] OSD: mute mic → no OSD, volume change → OSD shows
- [ ] Notifications: top-right hover opens panel
- [ ] Session menu: `Ctrl+Alt+Delete`

---

## Technical Details & Implementation Notes

### 1. Bar Position Generalization
Key files: `BarWrapper.qml`, `Bar.qml`, `Panels.qml`, `ContentWindow.qml`, `Interactions.qml`, `ClipWrapper.qml`, `Regions.qml`, `TaskbarPanel.qml`

### 2. Hover Area Generalization
Key files: `Interactions.qml`, `shell.json`, relevant settings pages under `nexus/pages/panels/`

### 3. Background Clock
Key files: `WallpaperAndStyle.qml`, `Background.qml`, `DesktopClock.qml`

### 4. Random Wallpaper Timer
Key files: `Wallpapers.qml`, `WallpaperAndStyle.qml`, `shell.json`

### 5. CopyQ Fix
Key files: `custom/keybinds.lua`, `custom/rules.lua`

### 6. Color Generation
Key files: `~/.config/caelestia/cli.json`, `Colours.qml`, `Wallpapers.qml`

---

## Known Online Issues / Enhancements (from caelestia-dots/shell GitHub)

### Active Crashes (as of June 2026)
- **#1599** `[CRASH] Settings page layout is broken after update` — Known upstream issue from v2.0.0 Material 3 revamp. Fix: rebuild quickshell from latest git.
- **#1584** `[CRASH] Crash when disabling monitor in Hyprland`
- **#471** `[CRASH] Quickshell crashes when killing a window in multi-monitor setup`

### Known Bugs
- **#1594** Media player bar doesn't work properly on YouTube
- **#1591** `bug(shortcuts): App launcher keybind fails to toggle due to onPressed vs onReleased mismatch`
- **#1069** VPN causes weather to break
- **#637** `IdleMonitor is not a type`
- **#1578** `[BUG] Cannot share screen in discord` — Fix: xwaylandvideobridge rules added + launch Discord with `XDG_SESSION_TYPE=x11`
- **#1535** Super key not opening launcher (Hyprland 0.55.4+) — Workaround: add `bindr = Super, Super_L, exec, caelestia shell drawers toggle launcher` to hypr-user.conf

### Recent Releases
- **v2.0.3** (Jun 15, 2026): Expressive lock input, HyprExtras usingLua fix
- **v2.0.2** (Jun 8, 2026): Lock/weather 24h fix, VPN disconnection toast fix
- **v2.0.0** (Jun 7, 2026): Material 3 expressive revamp (#1509), Nexus v2 (#1510)

### Planned Features (Open Issues)
- **#1383**: Revamp control center
- **#1385**: Redesign launcher
- **#1384**: Plugin system
- **#1149**: Launcher calculator combi mode (auto-detect without prefix)

---

## Keybind Reference (Simplified)
| Key | Action |
|-----|--------|
| `SUPER` | Toggle launcher |
| `SUPER+I` | Toggle nexus/settings |
| `SUPER+G` | Toggle dashboard |
| `SUPER+V` | Clipboard (CopyQ) |
| `SUPER+Return` | Terminal (kitty) |
| `SUPER+Q` | Close window |
| `SUPER+Shift+S` | Screenshot |
