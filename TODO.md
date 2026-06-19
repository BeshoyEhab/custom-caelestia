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

### Bar Position (Left → Top)
Big feature — move bar from left to top with config toggle:
- [ ] Add `bar.vertical` boolean to shell.json and Config.qml
- [ ] Create `HorizontalBar.qml` (RowLayout)
- [ ] Update `Panels.qml`, `BarWrapper.qml`, `ContentWindow.qml` for vertical/horizontal
- [ ] Update `Interactions.qml` for axis swap
- [ ] Update `Regions.qml` for region calculations
- [ ] Update `ClipWrapper.qml` for popout direction
- [ ] Settings UI for bar position selector

### Other
- [ ] Keybind documentation / cheat sheet
- [ ] Touchpad: verify `disable_while_typing`, consider `natural_scroll`
- [ ] Cursor: test Bibata-Modern-Classic stretch plugin, fix white cursor
- [ ] Bar scroll actions: consider enabling workspace/volume/brightness scroll

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
