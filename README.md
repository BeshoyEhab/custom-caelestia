# 🌌 custom-caelestia

[![OS](https://img.shields.io/badge/OS-Arch%20Linux-blue?logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![WM](https://img.shields.io/badge/WM-Hyprland%20%28v0.55%2B%29-ff69b4?logo=wayland&logoColor=white)](https://github.com/hyprwm/Hyprland)
[![Shell](https://img.shields.io/badge/Shell-Quickshell-9c27b0?logo=qt&logoColor=white)](https://github.com/outfoxxed/quickshell)
[![License](https://img.shields.io/badge/License-GPL--3.0-green)](LICENSE)

Welcome to **custom-caelestia**, a unified, high-performance, and visually gorgeous desktop environment. This configuration merges the beauty, theming, and animations of the **Caelestia Shell** with the extreme speed, productivity utilities, and keybindings of **End-4's illogical-impulse**.

---

## ⚡ The Vision & Naming
The name **custom-caelestia** represents a synthesis of two design paradigms:
- **Caelestia** (*Celestial*): A heavenly, fluid, and state-of-the-art widget ecosystem with deep Material Design color schemes.
- **Impulse** (*Illogical Impulse*): Rapid, instantaneous, keybinding-driven controls for professional workflows, screen capture, OCR reading, and audio/video controls.

By blending them together, **custom-caelestia** offers a rich aesthetic desktop experience that never compromises on speed or productivity.

---

## 🤝 Credits & Origins

This configuration is built upon the incredible work of the open-source community. Full credit goes to:

*   🌌 **[Caelestia Shell](https://github.com/caelestia-dots/shell) & [Configs](https://github.com/caelestia-dots/caelestia)**: Created by the Caelestia team. It provides the core desktop panels, dashboard, launcher, notifications, lockscreen, widgets, and dynamic theming engine.
*   ⚡ **[End-4's illogical-impulse](https://github.com/end-4/dots-hyprland)**: Created by End-4. It serves as the foundation for the keybinding layout, OCR tools, area recorder, color pickers, and overall UX optimizations.
*   🛠️ **[Bisho](https://github.com/Bisho)**: Merged, refactored, and updated the two projects to run seamlessly as a single integrated system under Hyprland 0.55+ (Lua config format), creating a safe, update-friendly installation and update architecture.

---

## 🎨 Core Features

1. **Dynamic Theme Engine**: Material-based dynamic theme switching powered by Caelestia's color manager.
2. **Interactive Widgets**: Rich Quickshell panels, overview dashboard, customizable widgets, and media controls.
3. **Advanced Keybindings**: Clean Lua-based Hyprland binds incorporating End-4's lightning-fast workflow.
4. **Productivity Utilities**:
    - **OCR Reader**: Extract text from any part of your screen instantly via `Super+Shift+X`.
    - **Area Screen Recorder**: Record selected regions with audio capture toggles.
    - **Clipboard Manager**: Integrates `CopyQ` with keyboard navigation.
    - **Laser Pointer & Screen Annotation**: Integrated `wayscriber` support for presentations.
5. **Modern Layout Support**: Modular layout loaders (supports both vertical and horizontal panel configurations).

---

## 🛠️ Update-Friendly Architecture
Unlike traditional dotfile setups that overwrite personal modifications, **custom-caelestia** separates the configuration into two layers:

*   **Global Defaults** (Tracked in Git): Found in `./hyprland/.config/hypr/` and `./shell/`. These are the core templates updated by the community.
*   **User Customizations** (Ignored by Git): Kept locally in `~/.config/hypr/custom/` and `~/.config/caelestia/shell.json`. This is where you put your keyboard layouts, screen scales, custom startups, or hardware-specific scripts (e.g., custom `lights`, `mic`, or `camera` scripts).

During updates and installation, the installer **automatically stashes** your user customizations to `/tmp`, deploys the latest global templates, and then **safely restores** your private files.

You can skip files from updates via `.updateignore`. The script reads from:
- `$REPO/.updateignore` — project-wide ignores
- `~/.updateignore` — your personal ignores (option 7 in conflict prompts adds absolute paths here)
- `~/.config/hypr/.updateignore`, `~/.config/quickshell/.updateignore`, `~/.config/quickshell/caelestia/.updateignore`
- Patterns support gitignore syntax; absolute paths match the full target path.

---

## 🚀 Getting Started

### Prerequisites
Arch Linux or an Arch-based distribution with an AUR helper (`yay` or `paru`).

The installer (`deploy_core` in `install.sh`) covers everything the dots call:
- **Shell**: `hyprland`, `quickshell-git` (AUR), `caelestia-cli` (AUR), `qt6-base`, `qt6-declarative`, `qt6-wayland`, `qt6-svg`, `qt6-shadertools`
- **Wayland/screencopy**: `wayland`, `wayland-protocols`, `libdrm`, `mesa`, `vulkan-headers`
- **Audio**: `libcava` (AUR), `aubio`, `libpulse`, `pipewire`, `pipewire-pulse`, `wireplumber`, `fftw`
  (`deploy_core` also runs `systemctl --user enable --now pipewire pipewire-pulse wireplumber` — packages alone don't start the server)
- **System**: `networkmanager`, `upower` (battery), `geoclue` (location/weather)
- **Portals**: `xdg-desktop-portal`, `xdg-desktop-portal-hyprland` (file chooser, screenshare)
- **Keyboard**: `xkeyboard-config` (layout database for the Nexus keyboard page)
- **Capture**: `grim`, `slurp`, `hyprpicker`, `hyprshot`, `tesseract`, `gpu-screen-recorder`, `swappy`
- **Clipboard/utils**: `wl-clipboard`, `cliphist`, `copyq`, `emote` (AUR), `jq`, `xdg-user-dirs`, `playerctl`, `bc`, `libxml2` (xmllint), `wtype`, `curl`, `app2unit-git` (AUR)
- **Hardware/system**: `ddcutil`, `brightnessctl`, `lm_sensors`, `networkmanager`, `libqalculate`
- **Build tools**: `cmake`, `ninja`, `pkgconf`, `git`, `spirv-tools`, `cli11`, `jemalloc`

### Quickshell screencopy note
The workspace overview, area picker, and lock-screen capture use Quickshell's
`ScreencopyView` (`Quickshell/Wayland/_Screencopy` QML module), which is compiled
into Quickshell itself — not into this repo's C++ plugin. If your installed
`quickshell-git` lacks that module (overview shows nothing), the installer
detects it and offers a source rebuild. To force it non-interactively:

```bash
./install.sh --rebuild-quickshell
```

This clones/updates `~/quickshell` (override with `QUICKSHELL_SRC`), configures
with `-DDISTRIBUTOR="custom-caelestia"` (screencopy defaults ON), builds, and
installs. Quickshell must also be rebuilt after every Qt minor release (ABI).

### Installation
```bash
git clone https://github.com/BeshoyEhab/custom-caelestia.git
cd custom-caelestia
./install.sh
```

The installer will:
1. Show an interactive menu — press Enter to install with defaults, or toggle sections by number.
2. Install core packages (`hyprland`, `quickshell-git`, tools) via pacman/AUR.
3. Deploy configs while preserving your `shell.json`, custom scripts, and any files listed in `.updateignore`.
4. Build and install the C++ QML plugin (prompts for sudo per command).

**Run as a normal user** — the script caches sudo credentials and asks for confirmation before each privileged command.

### Updating
```bash
./update.sh
```

Supports `--force` (replace all files, skip mtime checks), `--dry-run`, `--backup`, `--on-conflict` (ask/replace/keep/backup/new). During interactive conflict resolution, option 7 adds the file's absolute path to `~/.updateignore` to skip it in future updates.

The Nexus settings app drives the same scripts headlessly:
- `./update.sh --check` — read-only status (`BEHIND`, `PLUGINS_STALE`, …), exit 0 = up to date
- `./update.sh --non-interactive` — full update, conflicts resolved as `replace`, no prompts
- `./install.sh --non-interactive --no-install` — redeploy config files only (no packages, no plugin build, no sudo), always tty-free

---

## ⌨️ Common Keybindings

### Global Desktop Actions
| Key | Action |
| --- | --- |
| `Super` / `Super+Space` | Toggle App Launcher |
| `Super+D` | Toggle Dashboard |
| `Super+A` / `Super+B` / `Super+O` | Toggle Sidebar |
| `Super+I` | Toggle Nexus / Settings App |
| `Super+J` | Toggle Status Bar visibility |
| `Ctrl+Alt+Delete` | Open Session Logout Menu |
| `Ctrl+Super+R` | Restart Quickshell widgets |

### Window Management
| Key | Action |
| --- | --- |
| `Super+Q` | Close Active Window |
| `Super+F` | Fullscreen Window |
| `Super+Alt+F` | Fake Fullscreen |
| `Super+Alt+Space` | Toggle Floating Window |
| `Super+Tab` | Switch to Next Workspace |
| `Super+Shift+Tab` | Switch to Previous Workspace |

### Built-in Utilities
| Key | Action |
| --- | --- |
| `Super+Shift+S` | Take Screenshot (select area) |
| `Super+Shift+X` | Run Screenshot OCR (extracts text to clipboard) |
| `Super+Shift+A` | Google Lens Screenshot search |
| `Super+Shift+C` | Color Picker (hex to clipboard) |
| `Super+Shift+R` | Record Screen Region (video) |
| `Super+Shift+Alt+R` | Record Screen Region (video with system audio) |
| `Super+V` | Open Clipboard History |
| `Super+Period` | Open Emoji Picker |
| `Super+Shift+D` | Toggle Screen Annotation Laser (wayscriber) |
| `Super+Shift+G` | Toggle Drawing Mode (wayscriber) |
