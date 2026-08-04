#!/usr/bin/env bash
# custom-caelestia Installer
# Interactive installer with 3 optional config sections
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Flags ─────────────────────────────────────────────────────────────────────
# -v / --verbose : show real command output (pacman/yay/etc.) instead of hiding it
VERBOSE=false
for _arg in "$@"; do
    case "$_arg" in
        -v|--verbose) VERBOSE=true ;;
    esac
done

# ── Colors ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]] && command -v tput &>/dev/null && [[ "$(tput colors 2>/dev/null)" -ge 8 ]]; then
    HAS_COLOR=true
else
    HAS_COLOR=false
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

c_red()    { $HAS_COLOR && echo -e "${RED}$*${NC}" || echo "$*"; }
c_green()  { $HAS_COLOR && echo -e "${GREEN}$*${NC}" || echo "$*"; }
c_yellow() { $HAS_COLOR && echo -e "${YELLOW}$*${NC}" || echo "$*"; }
c_blue()   { $HAS_COLOR && echo -e "${BLUE}$*${NC}" || echo "$*"; }
c_cyan()   { $HAS_COLOR && echo -e "${CYAN}$*${NC}" || echo "$*"; }
c_bold()   { $HAS_COLOR && echo -e "${BOLD}$*${NC}" || echo "$*"; }

# ── Logging ───────────────────────────────────────────────────────────────────
log()   { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[x]${NC} $1"; exit 1; }
vlog()  { if [[ "$VERBOSE" == true ]]; then echo -e "${CYAN}    $1${NC}"; fi; }
# Divert a stream to /dev/null when NOT verbose; otherwise keep it live.
vfd()   { [[ "$VERBOSE" == false ]] && echo "/dev/null" || echo "/dev/stderr"; }

# ── Progress indicator: keeps non-verbose installs from feeling dead ──────────
spin() {
    local pid="$1" label="$2" i=0
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local n=${#frames[@]}
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % n ))
        printf "  \e[0;36m%s\e[0m %s\r" "${frames[$i]}" "$label" >&2
        sleep 0.1
    done
    printf "  \e[0;32m✓\e[0m %s   \n" "$label" >&2
}

# ── Sudo wrapper: show command, ask for confirmation ─────────────────────────
# The prompt/confirmation ALWAYS goes to the terminal (/dev/tty) so it stays
# visible even when the rest of the command output is redirected/spinnered.
sudo() {
    printf '  >> sudo %s\n' "$*" >/dev/tty
    printf '  %b run? [Y/n] %b ' "$CYAN" "$NC" >/dev/tty
    read -r _confirm < /dev/tty
    [[ "${_confirm,,}" == "n" ]] && return 1
    command sudo "$@"
}

# ── Package installation ─────────────────────────────────────────────────────
# Verbose (-v): run the command live so real output streams to the terminal.
# Otherwise: background + spinner so nothing feels dead; failures dump the log.
install_pkg() {
    local pkg="$1" is_aur="${2:-false}" logfile ok
    logfile="$(mktemp "${TMPDIR:-/tmp}/caelestia-pkg-XXXXXX.log")"
    ok=0

    _run() {
        if [[ "$VERBOSE" == true ]]; then
            vlog "Running: $*"
            if ! "$@"; then
                warn "Failed: $*"
                return 1
            fi
        else
            "$@" >"$logfile" 2>&1 & local pid=$!
            spin "$pid" "$pkg"
            wait "$pid" || { warn "Failed: $*"; return 1; }
        fi
        ok=1
    }

    if [[ "$is_aur" == "true" ]]; then
        if command -v yay &>/dev/null; then
            _run yay -S --noconfirm --needed "$pkg"
        elif command -v paru &>/dev/null; then
            _run paru -S --noconfirm --needed "$pkg"
        else
            warn "No AUR helper found. Install manually: yay -S $pkg"
            ok=1
        fi
    else
        _run sudo pacman -S --noconfirm --needed "$pkg"
    fi

    if [[ "$ok" != 1 ]]; then
        warn "Failed to install $pkg"
        [[ "$VERBOSE" == false ]] && cat "$logfile" >&2
    fi
    rm -f "$logfile"
}

# ── Safe deploy: merge repo into target without destroying user files ────────
# Reads .updateignore to skip user-customized files.
# Uses rsync --ignore-existing for first install, then --update for re-installs.
# Files in .updateignore are never touched.
safe_deploy() {
    local src="$1" dst="$2"
    shift 2
    local find_excludes=("$@")

    mkdir -p "$dst"

    # Build rsync args: exclude git, upstream, build dirs
    local rsync_args=(-a --exclude=".git*" --exclude="upstream/" --exclude="build/")

    # First pass: copy only new files (don't overwrite existing)
    find "$src" -type f "${find_excludes[@]}" 2>/dev/null | while IFS= read -r repo_file; do
        local rel="${repo_file#"$src"/}"
        local target="$dst/$rel"

        # Skip if in .updateignore
        if should_ignore "$rel" "$target"; then
            continue
        fi

        # Only create if target doesn't exist
        if [[ ! -f "$target" ]]; then
            mkdir -p "$(dirname "$target")"
            cp -p "$repo_file" "$target"
        fi
    done

    # Second pass: update files that are older or identical (repo is source of truth for non-custom)
    # But ONLY if the target file hasn't been modified by the user
    find "$src" -type f "${find_excludes[@]}" 2>/dev/null | while IFS= read -r repo_file; do
        local rel="${repo_file#"$src"/}"
        local target="$dst/$rel"

        if should_ignore "$rel" "$target"; then
            continue
        fi

        if [[ -f "$target" ]]; then
            # Only replace if files differ AND target matches repo version (not user-modified)
            if ! cmp -s "$repo_file" "$target" 2>/dev/null; then
                # Check if there's a backup of the repo version to compare
                # If user modified it, leave it alone. If repo changed, update.
                # Simple heuristic: if the file was touched after repo last changed, skip
                local repo_mtime
                repo_mtime=$(stat -c %Y "$repo_file" 2>/dev/null || echo 0)
                local target_mtime
                target_mtime=$(stat -c %Y "$target" 2>/dev/null || echo 0)

                # If target is newer than repo, user modified it — skip
                if [[ "$target_mtime" -gt "$repo_mtime" ]]; then
                    continue
                fi

                # Target is same age or older — safe to update
                cp -p "$repo_file" "$target"
            fi
        fi
    done
}

# ── Load .updateignore patterns ──────────────────────────────────────────────
declare -a IGNORE_PATTERNS=()

load_ignore_patterns() {
    IGNORE_PATTERNS=()

    local ignore_files=(
        "$REPO_DIR/.updateignore"
        "$HOME/.updateignore"
        "$HOME/.config/hypr/.updateignore"
        "$HOME/.config/quickshell/.updateignore"
    )
    for f in "${ignore_files[@]}"; do
        if [[ -f "$f" ]]; then
            while IFS= read -r line || [[ -n "$line" ]]; do
                line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                [[ -z "$line" || "$line" =~ ^# ]] && continue
                IGNORE_PATTERNS+=("$line")
            done < "$f"
        fi
    done
}

should_ignore() {
    local rel_path="$1"
    local full_path="$2"
    for pattern in "${IGNORE_PATTERNS[@]}"; do
        # Absolute path patterns match against the full target path
        if [[ "$pattern" == /* ]]; then
            [[ "$full_path" == "$pattern" ]] && return 0
            continue
        fi
        # Exact match
        [[ "$rel_path" == "$pattern" ]] && return 0
        # Glob match
        [[ "$rel_path" == $pattern ]] && return 0
        # Directory pattern: "custom/" matches "custom/anything"
        if [[ "$pattern" == */ ]]; then
            local dir_pattern="${pattern%/}"
            [[ "$rel_path" == "$dir_pattern"/* ]] && return 0
        fi
    done
    return 1
}

# ── Components ────────────────────────────────────────────────────────────────
# 3 sections: hyprland, shell-extras, quickshell
# Core packages (hyprland, quickshell) are always installed.

declare -A SEL
SEL[core]=1
SEL[hyprland]=1
SEL[shell_extras]=1
SEL[quickshell]=1

show_menu() {
    clear
    c_cyan "╔══════════════════════════════════════════════════════════════════╗"
    c_cyan "║               custom-caelestia installer                         ║"
    c_cyan "║                                                                  ║"
    c_cyan "║  Merge of Caelestia Shell + End-4 utilities                      ║"
    c_cyan "║  Toggle each section on/off, then install.                       ║"
    c_cyan "╚══════════════════════════════════════════════════════════════════╝"
    echo ""

    local sections=("core" "hyprland" "shell_extras" "quickshell")
    local labels=("Core (required)" "Hyprland config" "Shell extras (fish/starship/etc)" "Quickshell config (caelestia)")
    local descs=(
        "Hyprland, QuickShell, build tools, fonts"
        "Window rules, keybinds, scripts, systemd services, portal config"
        "Fish shell, Starship prompt, Btop, Cava, Kitty, Foot, Fuzzel, Wlogout, fonts"
        "Caelestia shell theme, modules, services (the actual desktop UI)"
    )
    local skips=(
        "System won't work - these are mandatory"
        "Stock Hyprland - no custom keybinds or automation"
        "Plain shell with no custom styling or modern CLI tools"
        "Default unstyled shell - you'd need to configure QuickShell yourself"
    )

    for i in "${!sections[@]}"; do
        local k="${sections[$i]}"
        if [[ "$k" == "core" ]]; then
            printf "  ${GREEN}[%d]${NC} ${GREEN}%s${NC}\n" "$((i+1))" "${labels[$i]}"
            printf "      %s\n" "$(c_yellow "${descs[$i]}")"
            printf "      ${YELLOW}(always installed)${NC}\n"
        else
            local mark
            if [[ "${SEL[$k]}" == "1" ]]; then
                mark="$(c_green "[+]")"
            else
                mark="$(c_red "[ ]")"
            fi
            printf "  %s ${BLUE}[%d]${NC} %s\n" "$mark" "$((i+1))" "${labels[$i]}"
            printf "      %s\n" "$(c_yellow "${descs[$i]}")"
            printf "      If skipped: %s\n" "$(c_red "${skips[$i]}")"
        fi
        echo ""
    done

    c_yellow "  [s] Show summary"
    c_yellow "  [i] Install (default)"
    c_yellow "  [q] Quit"
    echo ""
    c_cyan "  Enter numbers to toggle, e.g. '2 3' to toggle hyprland and shell-extras"
    echo ""
}

show_summary() {
    echo ""
    c_cyan "═══ Installation Summary ═══"
    echo ""
    c_green "Will install:"
    printf "  ✓ %s\n" "Core packages (always)"
    [[ "${SEL[hyprland]}" == "1" ]] && printf "  ✓ %s\n" "Hyprland config"
    [[ "${SEL[shell_extras]}" == "1" ]] && printf "  ✓ %s\n" "Shell extras (fish/starship/etc)"
    [[ "${SEL[quickshell]}" == "1" ]] && printf "  ✓ %s\n" "Quickshell config (caelestia)"
    echo ""
    c_red "Will skip:"
    local has_skip=0
    [[ "${SEL[hyprland]}" == "0" ]] && { printf "  ✗ Hyprland config\n    %s\n" "$(c_yellow "Stock Hyprland - no custom keybinds")"; has_skip=1; }
    [[ "${SEL[shell_extras]}" == "0" ]] && { printf "  ✗ Shell extras\n    %s\n" "$(c_yellow "Plain shell - no fish/starship/btop styling")"; has_skip=1; }
    [[ "${SEL[quickshell]}" == "0" ]] && { printf "  ✗ Quickshell config\n    %s\n" "$(c_yellow "Default unstyled shell")"; has_skip=1; }
    [[ $has_skip -eq 0 ]] && c_green "  (nothing - full install)"
    echo ""
}

# ── Deploy functions ─────────────────────────────────────────────────────────

deploy_core() {
    log "Installing core packages..."
    # Window manager
    install_pkg hyprland
    # Shell runtime (MUST be git version per upstream)
    install_pkg quickshell-git true
    # Hardware control
    install_pkg ddcutil
    install_pkg brightnessctl
    install_pkg lm_sensors
    # Audio visualiser & beat detection
    install_pkg libcava true
    install_pkg aubio
    install_pkg libpulse
    # System
    install_pkg networkmanager
    # Qt/QML runtime
    install_pkg qt6-base
    install_pkg qt6-declarative
    # Tools the shell uses
    install_pkg swappy
    install_pkg libqalculate
    # Fonts
    install_pkg ttf-cascadia-code-nerd
    install_pkg ttf-material-symbols-variable
    # Build tools (for C++ plugin)
    install_pkg cmake
    install_pkg ninja
}

deploy_hyprland() {
    log "Deploying Hyprland config..."
    local src="$REPO_DIR/hyprland/.config/hypr"
    local dst="$HOME/.config/hypr"

    if [[ -d "$src" ]]; then
        safe_deploy "$src" "$dst"
    fi

    # Caelestia config (shell.json etc.) — always preserve shell.json
    if [[ -d "$REPO_DIR/hyprland/.config/caelestia" ]]; then
        mkdir -p "$HOME/.config/caelestia"
        find "$REPO_DIR/hyprland/.config/caelestia" -type f | while IFS= read -r f; do
            local rel="${f#"$REPO_DIR/hyprland/.config/caelestia/"}"
            local target="$HOME/.config/caelestia/$rel"
            # Never overwrite shell.json — it's user-specific
            [[ "$rel" == "shell.json" || "$rel" == "shell.json.bak" ]] && continue
            if should_ignore "$rel" "$target"; then continue; fi
            if [[ ! -f "$target" ]]; then
                mkdir -p "$(dirname "$target")"
                cp -p "$f" "$target"
            fi
        done
    fi

    # Systemd services
    if [[ -d "$REPO_DIR/hyprland/.config/systemd" ]]; then
        safe_deploy "$REPO_DIR/hyprland/.config/systemd/user" "$HOME/.config/systemd/user"
        systemctl --user daemon-reload 2>/dev/null || true
    fi

    # XDG Desktop Portal
    if [[ -d "$REPO_DIR/hyprland/.config/xdg-desktop-portal" ]]; then
        safe_deploy "$REPO_DIR/hyprland/.config/xdg-desktop-portal" "$HOME/.config/xdg-desktop-portal"
    fi

    # Set permissions
    chmod +x "$HOME/.config/hypr/hyprland/scripts/"* &>/dev/null || true
    chmod +x "$HOME/.config/hypr/hyprland/scripts/ai/"* &>/dev/null || true

    log "Hyprland config deployed."
}

deploy_shell_extras() {
    log "Installing shell extras packages..."
    # Install the apps whose configs are about to be deployed
    install_pkg fish
    install_pkg starship
    install_pkg btop
    install_pkg cava
    install_pkg kitty
    install_pkg foot
    install_pkg fuzzel
    install_pkg wlogout

    log "Deploying shell extras configs..."

    # Fish shell
    if [[ -d "$REPO_DIR/configs/.config/fish" ]]; then
        log "  Fish shell config..."
        safe_deploy "$REPO_DIR/configs/.config/fish" "$HOME/.config/fish"
    fi

    # Starship prompt
    if [[ -f "$REPO_DIR/configs/.config/starship.toml" ]]; then
        local target="$HOME/.config/starship.toml"
        if [[ ! -f "$target" ]]; then
            cp -p "$REPO_DIR/configs/.config/starship.toml" "$target"
            log "  Starship config deployed."
        fi
    fi

    # App configs: btop, cava, kitty, foot, fuzzel, wlogout, fontconfig
    local app_configs=(btop cava kitty foot fuzzel wlogout fontconfig nvim)
    for app in "${app_configs[@]}"; do
        if [[ -d "$REPO_DIR/configs/.config/$app" ]]; then
            safe_deploy "$REPO_DIR/configs/.config/$app" "$HOME/.config/$app"
        fi
    done

    # Fish-guide binary
    if [[ -f "$REPO_DIR/configs/.local/share/bin/fish-guide" ]]; then
        mkdir -p "$HOME/.local/share/bin"
        if [[ ! -f "$HOME/.local/share/bin/fish-guide" ]]; then
            cp -p "$REPO_DIR/configs/.local/share/bin/fish-guide" "$HOME/.local/share/bin/fish-guide"
            chmod +x "$HOME/.local/share/bin/fish-guide"
            log "  fish-guide installed."
        fi
    fi

    log "Shell extras deployed."
}

deploy_quickshell() {
    log "Deploying Quickshell config..."
    local src="$REPO_DIR/shell"
    local dst="$HOME/.config/quickshell/caelestia"

    # Remove symlinks (pointing to old locations)
    if [[ -L "$dst" ]]; then
        rm -f "$dst"
    fi

    safe_deploy "$src" "$dst" \
        -not -path "*/build/*" -not -path "*/upstream/*"

    # Symlink install/update scripts for settings app
    mkdir -p "$dst/scripts"
    ln -sf "$REPO_DIR/update.sh" "$dst/scripts/update.sh"
    ln -sf "$REPO_DIR/install.sh" "$dst/scripts/install.sh"

    # Set permissions on scripts
    chmod +x "$dst/scripts/"* &>/dev/null || true

    log "Quickshell config deployed."
}

build_plugin() {
    log "Building C++ plugin..."
    local build_dir="$REPO_DIR/build"
    [[ -d "$build_dir" ]] && sudo rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cmake -B "$build_dir" -S "$REPO_DIR" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_MODULES="plugin;m3shapes" || {
        warn "cmake configuration failed. Check that cmake and ninja are installed."
        return 1
    }
    cmake --build "$build_dir" -j"$(nproc 2>/dev/null || echo 4)" || {
        warn "Plugin build failed. See output above for details."
        return 1
    }

    log "Installing plugin..."
    local install_dir="/usr/lib/qt6/qml"
    sudo cmake --install "$build_dir" --prefix / || {
        warn "cmake --install failed, falling back to manual copy..."
        if [[ -d "$build_dir/qml/Caelestia" ]]; then
            sudo mkdir -p "$install_dir/Caelestia"
            sudo cp -r "$build_dir/qml/Caelestia/"* "$install_dir/Caelestia/"
            sudo chmod -R a+rX "$install_dir/Caelestia/"
        else
            warn "No built plugin found at $build_dir/qml/Caelestia"
            return 1
        fi
    }

    # cmake --install on the top-level build skips FetchContent deps (M3Shapes)
    # Install M3Shapes from its own build subdirectory
    local m3shapes_build="$build_dir/_deps/m3shapes_external-build"
    if [[ -d "$m3shapes_build" ]]; then
        log "Installing M3Shapes module from FetchContent build dir..."
        sudo cmake --install "$m3shapes_build" --prefix / || {
            warn "M3Shapes cmake --install failed, falling back to manual copy..."
            if [[ -d "$build_dir/qml/M3Shapes" ]]; then
                sudo mkdir -p "$install_dir/M3Shapes"
                sudo cp -r "$build_dir/qml/M3Shapes/"* "$install_dir/M3Shapes/"
                sudo chmod -R a+rX "$install_dir/M3Shapes/"
            else
                warn "M3Shapes build output not found at $build_dir/qml/M3Shapes"
            fi
        }
        # Ensure world-readable regardless of how it was installed
        sudo chmod -R a+rX "$install_dir/M3Shapes/" 2>/dev/null || true
    fi
    log "Plugin installed."
}

# ── Main ──────────────────────────────────────────────────────────────────────
# If CI_TEST=true, only define functions, don't run the installer
if [[ "${CI_TEST:-false}" != "true" ]]; then
load_ignore_patterns

# ── Sudo check ─────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
    warn "Running as root. Run ./install.sh as a normal user instead —"
    warn "the script will ask for sudo when needed."
    exit 1
fi
log "Checking sudo access... (you may be prompted)"
sudo -v || err "sudo required."

while true; do
    show_menu
    read -p "Enter choice(s) (e.g. 2 3) or press Enter to install: " input

    # Empty input defaults to install
    if [[ -z "$input" ]]; then
        input="i"
    fi

    IFS=', ' read -ra choices <<< "$input"
    for choice in "${choices[@]}"; do
        case "$choice" in
            1) ;; # core — always on
            2) SEL[hyprland]=$(( 1 - SEL[hyprland] )) ;;
            3) SEL[shell_extras]=$(( 1 - SEL[shell_extras] )) ;;
            4) SEL[quickshell]=$(( 1 - SEL[quickshell] )) ;;
            [sS])
                show_summary
                read -p "Press Enter to continue..." _
                break
                ;;
            [Ii])
                show_summary
                read -p "Proceed with installation? [Y/n]: " confirm
                [[ "${confirm,,}" == "n" ]] && break

                echo ""
                c_cyan "Starting installation..."
                echo ""

                deploy_core
                [[ "${SEL[hyprland]}" == "1" ]] && deploy_hyprland
                [[ "${SEL[shell_extras]}" == "1" ]] && deploy_shell_extras
                [[ "${SEL[quickshell]}" == "1" ]] && deploy_quickshell

                # Build C++ plugin (required for the Caelestia QML module)
                build_plugin

                echo ""
                c_green "═══════════════════════════════════════════════"
                c_green "Installation complete!"
                c_green "═══════════════════════════════════════════════"
                echo ""
                echo "  Keybinds:"
                echo "    Super            - Launcher"
                echo "    Super + I        - Settings (Nexus)"
                echo "    Super + D        - Dashboard"
                echo "    Super + A        - Sidebar"
                echo "    Ctrl + Alt + Del - Session menu"
                echo "    Super + V        - Clipboard"
                echo "    Super + Period   - Emoji picker"
                echo ""
                echo "  Start: Log out and back in, or run: hyprctl reload"
                echo ""
                exit 0
                ;;
            [Qq])
                c_yellow "Installation cancelled."
                exit 0
                ;;
        esac
    done
done
fi
