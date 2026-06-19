# Caelestia-Impulse (Celestimpulse)

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

## Not Started (needs implementation)

### 1. Bar Position Generalization (Any Direction)
Move bar from hardcoded left to any of 4 sides via config. This is a large structural change.

**Config changes:**
- [ ] Add `bar.position` string (`"left"` | `"top"` | `"right"` | `"bottom"`) to shell.json, replacing the implicit left assumption
- [ ] Update `Config.qml` (or wherever `bar.*` is parsed) to expose `bar.position`

**Shell layout changes:**
- [ ] `BarWrapper.qml`: swap `implicitWidth`/`implicitHeight`, `anchors.right`/`anchors.bottom`, and `clip` axis based on `bar.position`. The bar currently animates width; for top/bottom it should animate height.
- [ ] `Bar.qml`: currently a `ColumnLayout`. For top/bottom positions it needs to become a `RowLayout`. Best done with a property alias or a `Loader` that picks the layout type.
- [ ] `Bar.qml`: `vPadding` and top/bottom margins in `WrappedLoader` need to become edge-aware (left/right padding for horizontal bar).
- [ ] `ContentWindow.qml` (`Panels.qml`): `anchors.leftMargin: bar.implicitWidth` needs to become a 4-way anchor depending on bar position.
- [ ] `Interactions.qml`: nearly every helper (`inLeftPanel`, `inRightPanel`, `inTopPanel`, `inBottomPanel`, wheel handler, bar hover) is axis-specific. Add a `barEdge` helper and remap all these to respect `bar.position`.
- [ ] `ClipWrapper.qml` (popout clip): currently animates `x` offset from the left bar. For top bar, it should animate `y` from the top edge, and for bottom/right accordingly.
- [ ] `Regions.qml`: update region exclusion/anchor to use the correct screen edge.

**Settings UI:**
- [ ] Add `SelectRow` in `TaskbarPanel.qml` (or `BarPanel.qml`) with options: Left / Top / Right / Bottom → writes to `GlobalConfig.bar.position`

**Key files:** `BarWrapper.qml`, `Bar.qml`, `Panels.qml`, `ContentWindow.qml`, `Interactions.qml`, `ClipWrapper.qml`, `Regions.qml`, `TaskbarPanel.qml`

---

### 2. Hover Area Generalization (Any Widget with Hover-to-Open)
Currently the hover trigger for sidebar, launcher, and dashboard are each hardcoded in `Interactions.qml` with their own edge/width/height config keys. The `hoverAreaGeometry()` function already exists and handles all 8 edges correctly — what's missing is hooking up OSD and any future widget to the same pattern.

**Current state:** Launcher, dashboard, and sidebar all use `inHoverArea()` with their own GlobalConfig keys (`launcher.hoverEdge`, `dashboard.hoverEdge`, `sidebar.hoverEdge`). The OSD hover is still hardcoded to `inRightPanel`.

- [ ] **OSD hover**: add `osd.hoverEdge`, `osd.hoverWidth`, `osd.hoverHeight`, `osd.showHoverIndicator` to shell.json (default: `"right"`, 40, 200). Replace `inRightPanel(panels.osdWrapper, ...)` with `inHoverArea(panels.osdWrapper, x, y, osdEdge, osdW, osdH)` in `Interactions.qml`.
- [ ] **OSD settings UI**: add hover area controls to the OSD section in the settings page.
- [ ] **Visual indicator**: add `Rectangle` for OSD hover zone in `Interactions.qml` (same pattern as `launcherIndicator`, `dashboardIndicator`, `sidebarIndicator`).
- [ ] **Session panel**: same treatment for `sessionWrapper` — currently uses `inRightPanel` drag logic. Could expose `session.hoverEdge` for consistency.
- [ ] **Document the pattern** in TODO/README so future widgets reuse `inHoverArea()` instead of inventing new helpers.

**Key files:** `Interactions.qml`, `shell.json`, relevant settings pages under `nexus/pages/panels/`

---

### 3. Desktop Clock (Already Exists — Enable & Surface in Settings)
`DesktopClock.qml` and `Background.qml` already implement the full desktop clock with 9-position placement, blur background, shadow, scale, AM/PM, and invertColors. It's also already enabled in `shell.json` (`"enabled": true`, `"position": "bottom-right"`).

**What's missing is settings UI exposure:**
- [ ] Add a "Desktop Clock" section to the `WallpaperAndStyle.qml` page (or a new sub-page) with:
  - `ToggleRow` → `GlobalConfig.background.desktopClock.enabled`
  - `SelectRow` for position: top-left / top-center / top-right / middle-left / middle-center / middle-right / bottom-left / bottom-center / bottom-right → `GlobalConfig.background.desktopClock.position`
  - `SliderRow` for scale (0.5–2.0) → `GlobalConfig.background.desktopClock.scale`
  - `ToggleRow` → `GlobalConfig.background.desktopClock.invertColors`
  - `ToggleRow` → `GlobalConfig.background.desktopClock.background.enabled`
  - `SliderRow` for background opacity → `GlobalConfig.background.desktopClock.background.opacity`
  - `ToggleRow` → `GlobalConfig.background.desktopClock.background.blur`
  - `ToggleRow` → `GlobalConfig.background.desktopClock.shadow.enabled`
- [ ] The `anchors.leftMargin` in `Background.qml` (clockLoader) hardcodes a bar offset — make it conditional on `bar.position` once bar position generalization is done.

**Key files:** `WallpaperAndStyle.qml`, `Background.qml`, `DesktopClock.qml`

---

### 4. Random Wallpaper Timer in Settings (broken + missing UI)
`Wallpapers.qml` has `setRandom()` which calls `caelestia wallpaper -r`. The existing `Ctrl+Super+Alt+T` keybind triggers this once, and a systemd timer was mentioned but isn't implemented.

**Why random doesn't work reliably:** `caelestia wallpaper -r` just picks a random file from `Paths.wallsdir` and calls `caelestia wallpaper -f <path>` on it. If the wallsdir is empty or the path doesn't exist, it silently does nothing. Also, the timer keybind triggers a one-shot random switch but there's no persistent N-hour interval that persists across reboots.

**Implementation plan:**
- [ ] Add to `shell.json`: `"wallpaper": { "randomTimer": { "enabled": false, "intervalHours": 1 } }`
- [ ] In `Wallpapers.qml` (or a new `WallpaperTimer.qml` service): add a `Timer` that fires every `intervalHours * 3600 * 1000` ms, calls `setRandom()` when `GlobalConfig.wallpaper.randomTimer.enabled` is true
- [ ] Add settings UI in `WallpaperAndStyle.qml`:
  - `ToggleRow` → enable/disable random rotation
  - `StepperRow` → interval in hours (1–24, step 1) → `GlobalConfig.wallpaper.randomTimer.intervalHours`
- [ ] Fix: ensure `Paths.wallsdir` is set and populated before the first random call (add a guard in `setRandom()` — `if (list.length === 0) return`)
- [ ] Optional: also write to a systemd timer unit for persistence across qs restarts (post-hook in `caelestia-cli` or a separate script started by execs.lua)

**Key files:** `Wallpapers.qml`, `WallpaperAndStyle.qml`, `shell.json`

---

### 5. CopyQ Fix (Closes on Item Select / Mouse Leave)
The `copyq toggle` command in `custom/keybinds.lua` maps to CopyQ's built-in toggle behavior. The problem is two-fold:

**Why it closes on mouse-away:** CopyQ in "tray" mode (launched with `--start-server`) has a `hide_on_unfocus` behavior by default. When CopyQ is shown via `copyq show` or `copyq toggle`, it's treated as a popup window and loses focus → auto-hides.

**Why it closes on item select:** After selecting/pasting an item, CopyQ hides itself (this is actually end-4's intended behavior — select → paste → close). But if you want it to stay open, you need to configure CopyQ's own settings.

**Fix options:**
1. **Simplest**: Configure CopyQ via its GUI: Options → uncheck "Hide main window when it loses focus". Then the window stays unless you press Escape or click outside.
2. **Keybind fix**: Use `copyq show` instead of `copyq toggle` in the keybind. `toggle` re-hides if already visible; `show` always brings it to front.
3. **Window rule**: Add a Hyprland rule to keep CopyQ focused: `hl.window_rule({ match = { class = "^(com\\.github\\.hluk\\.copyq|copyq)$" }, focus_on_activation = true })`. The existing rule in `custom/rules.lua` only sets float+move, not focus behavior.
4. **End-4 approach**: end-4 used `cliphist` + a custom wofi/rofi picker that runs inline and closes itself (not CopyQ). Consider switching `SUPER+V` back to the `cliphist` + `caelestia clipboard` approach (already in `keybinds.lua` as fallback).

**Recommended action:**
- [ ] Change `custom/keybinds.lua` SUPER+V from `copyq toggle` to `copyq show` (avoids the "already visible → toggle hides it" edge case)
- [ ] Add to `custom/rules.lua`: `stay_focused = true` for CopyQ window rule, or configure CopyQ's built-in settings to not hide on unfocus
- [ ] Test: open CopyQ, move mouse away → should not close; select item → should paste and close (or stay, per preference)

**Key files:** `custom/keybinds.lua`, `custom/rules.lua`

---

### 6. Color Generation from Wallpaper (Investigation + Fix)
**Why it's broken / why only wallpaper is set without colors:**

Caelestia's color pipeline works like this:
1. `caelestia wallpaper -f <path>` is called
2. The `caelestia-cli` tool generates a Material You color scheme from the wallpaper using `matugen` (a Rust tool that implements Material Color Utilities)
3. It writes the scheme to `~/.local/state/caelestia/scheme.json`
4. `Colours.qml` watches `scheme.json` via `FileView { watchChanges: true }` and calls `load()` on change
5. The shell re-colors all widgets from the new palette

**The most common reasons this breaks:**
- `matugen` is not installed — `caelestia-cli` silently falls back to just setting the wallpaper via `swww` without generating colors. Check: `which matugen` or `pacman -Q matugen`
- `caelestia-cli` is outdated — older versions had the color generation step disabled or buggy. The `--no-smart` flag (controlled by `GlobalConfig.services.smartScheme`) skips smart scheme selection; irrelevant to color generation itself.
- `~/.local/state/caelestia/` directory doesn't exist or `scheme.json` doesn't get written
- End-4's color generation: end-4 dots use `material-color-utility` (a Python/JS tool) directly in a shell script, calling it with the wallpaper path. It's not via `caelestia-cli` at all — it's a separate `colorgen.sh` or similar script.

**To integrate end-4-style color generation:**
- The end-4 approach runs `matugen image <wallpath>` with template files in `~/.config/matugen/templates/` and outputs colors to `~/.cache/matugen/colors.json`. It then applies the colors to the terminal, GTK, etc. via its own template system.
- Caelestia-cli already does this internally — if `matugen` is present, `caelestia wallpaper -f <path>` calls it automatically.
- **Action**: check if `matugen` is installed and if `~/.local/state/caelestia/scheme.json` is being updated on wallpaper change.

**TODO items:**
- [ ] Verify `matugen` is installed: `which matugen`
- [ ] Verify `caelestia-cli` version: `caelestia --version` (should be ≥1.0.8)
- [ ] Test: `caelestia wallpaper -f ~/some_wallpaper.jpg` then check `cat ~/.local/state/caelestia/scheme.json` to see if colors were generated
- [ ] If matugen is missing: `yay -S matugen` or `paru -S matugen`
- [ ] If scheme.json isn't generated even with matugen: check `caelestia-cli` source for the `theme.enableHypr` flag — it must be `true` in `~/.config/caelestia/cli.json`
- [ ] (Optional) Port end-4's `postHook` pattern: add a `wallpaper.postHook` in `~/.config/caelestia/cli.json` that runs any extra theming (e.g., reloading Kvantum theme, regenerating GTK colors). See `caelestia-cli` README for `postHook` syntax.

**Key files:** `~/.config/caelestia/cli.json` (not in repo), `Colours.qml`, `Wallpapers.qml`

---

### 7. Other (pre-existing)
- [ ] Keybind documentation / cheat sheet
- [ ] Touchpad: verify `disable_while_typing`, consider `natural_scroll`
- [ ] Cursor: test Bibata-Modern-Classic stretch plugin, fix white cursor
- [ ] Bar scroll actions: consider enabling workspace/volume/brightness scroll

---

## Known Online Issues / Enhancements (from caelestia-dots/shell GitHub)

These are tracked upstream. Knowing them helps avoid debugging issues that are already known:

### Active Crashes (as of June 2026)
- **#1599** `[CRASH] Settings page layout is broken after update` — settings page may break after upstream update; if Nexus looks wrong after `git pull`, this is likely it.
- **#1584** `[CRASH] Crash when disabling monitor in Hyprland` — known crash when toggling monitor enable/disable while QS is running. Workaround: restart QS after monitor changes.
- **#471** `[CRASH] Quickshell crashes when killing a window in multi-monitor setup` — multi-monitor window close can crash QS. If using multiple monitors, this may be intermittent.

### Known Bugs
- **#1594** Media player bar doesn't work properly on YouTube — the bar media controls don't reflect YouTube playback state correctly. Upstream issue.
- **#1591** `bug(shortcuts): App launcher keybind fails to toggle due to onPressed vs onReleased mismatch` — the launcher `SUPER` press/release event handling has a race condition. This may explain occasional double-toggle behavior.
- **#1069** VPN causes weather to break — if VPN is active, weather service may fail silently.
- **#637** `IdleMonitor is not a type` — type error in older Quickshell builds; fixed in current version but may appear if QS is not up-to-date.

### Feature Requests (relevant to this project)
- **#1587** `[FEATURE] Animated Wallpapers Support` — upstream doesn't support video wallpapers natively. The `__restore_video_wallpaper.sh` custom script in `custom/scripts/` is our workaround.
- **#845** `Side bar on only 1 monitor` — per-monitor sidebar is a requested feature, not yet upstream.
- **#1210** `Bright switch colors that don't match theme` — color generation mismatch on light/dark mode switch; likely related to our issue #6 above.

---

## Config Separation & Scripts Customization (Completed)

### 1. Hardware/Device-Specific Scripts Separation
- [x] Retained device-specific scripts (`lights`, `mic`, `camera`) as private custom scripts in `~/.local/share/bin/` as they are hardware-dependent and shouldn't be pushed globally.
- [x] Maintained them within the `custom/` keybinds and execs configurations to keep the global repository clean and portable.

### 2. Global Hyprland Config Integration
- [x] Updated global keybinds in `hyprland/.config/hypr/hyprland/keybinds.lua` to use standard, portable utilities (like `wpctl` for mic toggle) rather than hardcoded personal script paths.
- [x] Kept user-specific bindings/overrides inside the stashed and ignored `custom/` folder.

### 3. Custom Config Safeguarding
- [x] Configured the repository and installation process to ignore and preserve the local `custom/` configuration directory and settings.

### 4. Installer and Updater Improvements (Done)
- [x] Rewrote `install.sh` to cleanly deploy global configurations from the repo (`./hyprland/.config/hypr` and `./shell`) instead of copying target-to-target.
- [x] Implemented robust stashing logic (`/tmp/` backup with EXIT trap) to ensure the user's `custom/` config, `monitors.lua`/`monitors.conf`, and `shell.json` are never lost or overwritten.
- [x] Simplified `update.sh` to pull latest changes on the parent repository safely without submodule conflicts.
- [x] Added `caelestia-cli` and `caelestia-shell` to AUR installation list to avoid manual cloning/compilation.

---

## Done (this session)

- [x] Launcher hover tracking: close on mouse leave only if no text typed
- [x] Settings app: calculator auto-detect toggle, search frequency toggle in LauncherPanel.qml
- [x] DrawerVisibilities: added `launcherHasText` property
- [x] Content.qml: clears search on launcher open, tracks text state
- [x] All changes copied to repo (shell/ and hyprland/ directories)

---

## Keybind Reference

### Shell
| Key | Action |
|-----|--------|
| `SUPER` | Toggle launcher |
| `SUPER+Space` | Open launcher |
| `SUPER+I` | Toggle nexus/settings |
| `SUPER+G` | Toggle dashboard |
| `SUPER+A` / `SUPER+B` / `SUPER+O` | Toggle sidebar |
| `Ctrl+Alt+Delete` | Toggle session menu |
| `SUPER+J` | Toggle bar |
| `SUPER+/` | Toggle OSD |
| `Ctrl+Super+R` | Restart widgets |

### Window
| Key | Action |
|-----|--------|
| `SUPER+D` | Maximize toggle |
| `SUPER+F` | Fullscreen |
| `SUPER+Alt+F` | Fake fullscreen |
| `SUPER+Q` | Close window |
| `SUPER+Alt+Space` | Float toggle |

### Utilities
| Key | Action |
|-----|--------|
| `SUPER+V` | Clipboard history (CopyQ or Caelestia) |
| `SUPER+Period` | Emoji picker (Emote or Caelestia) |
| `SUPER+Shift+S` | Screenshot (region) |
| `SUPER+Shift+A` | Google Lens |
| `SUPER+Shift+X` | OCR to clipboard |
| `SUPER+Shift+C` | Color picker |
| `SUPER+Shift+R` | Record region |
| `SUPER+Shift+Alt+R` | Record screen (with sound) |
| `Print` | Screenshot to clipboard |
| `Ctrl+Print` | Screenshot to file + clipboard |

### User Custom (custom/keybinds.lua)
| Key | Action |
|-----|--------|
| `SUPER+Return/T` | Terminal (kitty) |
| `SUPER+W` | Browser (brave) |
| `SUPER+E` | File manager (dolphin) |
| `SUPER+Z` | Code editor (zeditor) |
| `SUPER+C` | VS Code |
| `SUPER+V` | Clipboard (copyq) |
| `SUPER+Period` | Emoji (emote) |
| `SUPER+Tab` | Workspace next |
| `SUPER+Shift+Tab` | Workspace prev |
| `SUPER+P` | Screen mirror toggle |
| `SUPER+U` | Shutdown menu |
| `SUPER+Shift+P` | Audio settings (pavucontrol) |
| `SUPER+Shift+D` | Wayscriber daemon toggle |
| `SUPER+Shift+G` | Wayscriber light toggle |
| `XF86WebCam` | Webcam toggle |
| `XF86AudioMicMute` | Mic mute (custom script) |

---

## Key Files

| File | Path |
|------|------|
| Main entry | `~/.config/hypr/hyprland.lua` |
| Keybinds | `~/.config/hypr/hyprland/keybinds.lua` |
| Custom keybinds | `~/.config/hypr/custom/keybinds.lua` |
| Execs | `~/.config/hypr/hyprland/execs.lua` |
| Env vars | `~/.config/hypr/hyprland/env.lua` |
| General | `~/.config/hypr/hyprland/general.lua` |
| Custom general | `~/.config/hypr/custom/general.lua` |
| Shell config | `~/.config/caelestia/shell.json` |
| Searcher | `~/.config/quickshell/caelestia/utils/Searcher.qml` |
| Apps search | `~/.config/quickshell/caelestia/modules/launcher/services/Apps.qml` |
| Calc item | `~/.config/quickshell/caelestia/modules/launcher/items/CalcItem.qml` |
| App list | `~/.config/quickshell/caelestia/modules/launcher/AppList.qml` |
| Shortcuts | `~/.config/quickshell/caelestia/modules/Shortcuts.qml` |
| Interactions | `~/.config/quickshell/caelestia/modules/drawers/Interactions.qml` |
| BarWrapper | `~/.config/quickshell/caelestia/modules/bar/BarWrapper.qml` |
| Workspace | `~/.config/quickshell/caelestia/modules/bar/components/workspaces/Workspace.qml` |
| Workspaces | `~/.config/quickshell/caelestia/modules/bar/components/workspaces/Workspaces.qml` |
| Kdeglobals | `~/.config/kdeglobals` |
| dot-man config | `~/dot-man/config.toml` |
| Installer | `~/caelestia-merged/install.sh` |
| Updater | `~/caelestia-merged/update.sh` |
