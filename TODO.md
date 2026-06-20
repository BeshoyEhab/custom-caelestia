# Caelestia-Impulse (Celestimpulse)

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
- [ ] **CopyQ**: Fix not closing on item select or mouse-away.
- [ ] **Launcher Calculator**: Fix hardcoded terminal/shell when opening `qalc`.
- [ ] **Discord**: Fix screen share source selection window not opening.
- [ ] **Settings App**: Add featured wallpapers and missing color schemas.

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

- [ ] Calculator: test `2+3*4`, `100/3`, `2^8` etc. in launcher
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
- **#1599** `[CRASH] Settings page layout is broken after update`
- **#1584** `[CRASH] Crash when disabling monitor in Hyprland`
- **#471** `[CRASH] Quickshell crashes when killing a window in multi-monitor setup`

### Known Bugs
- **#1594** Media player bar doesn't work properly on YouTube
- **#1591** `bug(shortcuts): App launcher keybind fails to toggle due to onPressed vs onReleased mismatch`
- **#1069** VPN causes weather to break
- **#637** `IdleMonitor is not a type`

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
