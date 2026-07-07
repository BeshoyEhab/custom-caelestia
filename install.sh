#!/usr/bin/env bash
# custom-caelestia Installer
# Interactive installer with granular component selection
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color detection
if [[ -t 1 ]] && command -v tput &>/dev/null && [[ "$(tput colors 2>/dev/null)" -ge 8 ]]; then
    HAS_COLOR=true
else
    HAS_COLOR=false
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

c_red()    { $HAS_COLOR && echo -e "${RED}$*${NC}" || echo "$*"; }
c_green()  { $HAS_COLOR && echo -e "${GREEN}$*${NC}" || echo "$*"; }
c_yellow() { $HAS_COLOR && echo -e "${YELLOW}$*${NC}" || echo "$*"; }
c_blue()   { $HAS_COLOR && echo -e "${BLUE}$*${NC}" || echo "$*"; }
c_cyan()   { $HAS_COLOR && echo -e "${CYAN}$*${NC}" || echo "$*"; }

# ── Components ────────────────────────────────────────────────────────────────
# Each component: key|label|description|what_if_skipped
# Packages are handled in install_component(), not here.
declare -A COMP_LABEL COMP_DESC COMP_SKIP
register() {
    COMP_LABEL["$1"]="$2"; COMP_DESC["$1"]="$3"; COMP_SKIP["$1"]="$4"
}

# Core (always installed, shown for awareness)
register core        "Core (required)"           "Hyprland, QuickShell, caelestia-cli & caelestia-shell" \
                                            "System won't work - these are mandatory"

# Configs from the repo
register shell       "Shell config"              "QuickShell config from this repo (theme, modules, services)" \
                                            "Default unstyled shell - you'd need to configure QuickShell yourself"
register hypr        "Hyprland config"           "Window rules, monitors, scripts, systemd services" \
                                            "Stock Hyprland - no custom keybinds or automation"
register fish        "Fish shell config"         "Aliases, functions, zoxide, starship, fzf integration" \
                                            "Plain fish shell with no shortcuts or modern CLI replacements"
register fishguide   "Fish command guide"        "Custom fish-guide script (TUI cheatsheet + alias suggestions)" \
                                            "No command suggestions - you won't learn shorter aliases"
register terminals   "Terminal configs"          "Kitty & Foot terminal configs" \
                                            "Default terminal appearance"
register launcher    "App launcher (Fuzzel)"     "Fuzzel launcher config (appearance, matching)" \
                                            "Stock Fuzzel - no custom styling"
register btop        "System monitor (Btop)"     "Btop config (theme, layout)" \
                                            "Stock Btop appearance"
register cava        "Audio visualizer (Cava)"   "Cava config (colors, smoothing)" \
                                            "Stock Cava appearance"
register starship    "Prompt (Starship)"         "Starship prompt config (modules, style)" \
                                            "Stock Starship prompt"
register wlogout     "Session menu (Wlogout)"    "Wlogout button layout & styling" \
                                            "Stock Wlogout - plain power menu"
register fonts       "Font config"               "Fontconfig for icon fonts & emoji rendering" \
                                            "Missing icons or emoji in some apps"

# System integration
register portal      "XDG Desktop Portal"        "Portal config for screen sharing, file picker, etc." \
                                            "Screen sharing & file picker may not work properly"
register plugin      "C++ plugin (build)"        "Build & install the C++ QML plugin from source" \
                                            "Some shell modules won't load (falls back to QML-only)"
register yay         "AUR helper (yay)"           "Install yay if not present (needed for AUR packages)" \
                                            "You'll need to manually install AUR packages"

# Component order for display
COMP_ORDER=(
    core shell hypr fish fishguide terminals launcher btop cava
    starship wlogout fonts portal plugin yay
)

# State: all enabled by default
declare -A SEL
for k in "${COMP_ORDER[@]}"; do SEL[$k]=1; done
SEL[core]=1  # always on

# ── UI ────────────────────────────────────────────────────────────────────────
print_header() {
    clear
    c_cyan "╔══════════════════════════════════════════════════════════════════╗"
    c_cyan "║              custom-caelestia installer                         ║"
    c_cyan "║                                                                  ║"
    c_cyan "║  Merge of Caelestia Shell + End-4 utilities                      ║"
    c_cyan "║  Toggle each component on/off, then install.                     ║"
    c_cyan "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
}

show_menu() {
    local i=1
    for k in "${COMP_ORDER[@]}"; do
        local mark="  "
        [[ "${SEL[$k]}" == "1" ]] && mark="$(c_green "[*]")" || mark="$(c_red "[ ]")"

        if [[ "$k" == "core" ]]; then
            printf "  %s %s %s\n" "$(c_green "[$i]")" "$(c_green "${COMP_LABEL[$k]}")" "- ${COMP_DESC[$k]}"
            printf "      %s\n" "$(c_yellow "(always installed)")"
        else
            printf "  %s %s %s\n" "$mark" "$(c_blue "[$i]")" "${COMP_LABEL[$k]} - ${COMP_DESC[$k]}"
            printf "      %s\n" "$(c_yellow "If skipped: ${COMP_SKIP[$k]}")"
        fi
        ((i++))
    done

    echo ""
    c_yellow "  [S] Summary  - show what's selected"
    c_yellow "  [I] Install  - start installation"
    c_yellow "  [Q] Quit"
    c_cyan "  Tip: Enter multiple numbers at once, e.g. '1 3 5' or '1,3,5'"
    echo ""
}

show_summary() {
    echo ""
    c_cyan "═══ Installation Summary ═══"
    echo ""
    c_green "Will install:"
    for k in "${COMP_ORDER[@]}"; do
        [[ "${SEL[$k]}" == "1" ]] && printf "  ✓ %s\n" "${COMP_LABEL[$k]}"
    done
    echo ""
    c_red "Will skip:"
    local has_skip=0
    for k in "${COMP_ORDER[@]}"; do
        if [[ "${SEL[$k]}" == "0" ]]; then
            printf "  ✗ %s\n" "${COMP_LABEL[$k]}"
            printf "    %s\n" "$(c_yellow "${COMP_SKIP[$k]}")"
            has_skip=1
        fi
    done
    [[ $has_skip -eq 0 ]] && c_green "  (nothing - full install)"
    echo ""
}

# ── Package installation ─────────────────────────────────────────────────────
install_pkg() {
    local pkg="$1" is_aur="${2:-false}"
    if [[ "$is_aur" == "true" ]]; then
        if command -v yay &>/dev/null; then
            yay -S --noconfirm "$pkg" 2>/dev/null || c_yellow "  Warning: failed to install $pkg"
        elif command -v paru &>/dev/null; then
            paru -S --noconfirm "$pkg" 2>/dev/null || c_yellow "  Warning: failed to install $pkg"
        else
            c_yellow "  No AUR helper found. Install manually: yay -S $pkg"
        fi
    else
        sudo pacman -S --noconfirm "$pkg" 2>/dev/null || c_yellow "  Warning: failed to install $pkg"
    fi
}

install_component() {
    local k="$1"
    case "$k" in
        core)
            c_green "Installing core packages..."
            install_pkg hyprland
            install_pkg quickshell
            install_pkg caelestia-cli true
            install_pkg caelestia-shell true
            ;;
        shell)
            c_green "Deploying shell config from repo..."
            mkdir -p "$HOME/.config/quickshell/caelestia"
            rsync -a --exclude=".git*" "$REPO_DIR/shell/" "$HOME/.config/quickshell/caelestia/"
            ;;
        hypr)
            c_green "Deploying Hyprland config from repo..."
            mkdir -p "$HOME/.config/hypr"
            rsync -a --exclude=".git*" "$REPO_DIR/hyprland/.config/hypr/" "$HOME/.config/hypr/"
            # Deploy caelestia config (shell.json etc.)
            if [[ -d "$REPO_DIR/hyprland/.config/caelestia" ]]; then
                mkdir -p "$HOME/.config/caelestia"
                rsync -a --exclude=".git*" "$REPO_DIR/hyprland/.config/caelestia/" "$HOME/.config/caelestia/"
            fi
            # Systemd services
            if [[ -d "$REPO_DIR/hyprland/.config/systemd" ]]; then
                mkdir -p "$HOME/.config/systemd/user"
                rsync -a --exclude=".git*" "$REPO_DIR/hyprland/.config/systemd/user/" "$HOME/.config/systemd/user/"
                systemctl --user daemon-reload 2>/dev/null || true
            fi
            # Set permissions
            chmod +x "$HOME/.config/hypr/hyprland/scripts/"* &>/dev/null || true
            chmod +x "$HOME/.config/hypr/hyprland/scripts/ai/"* &>/dev/null || true
            ;;
        fish)
            c_green "Installing fish shell and dependencies..."
            install_pkg fish
            install_pkg eza
            install_pkg bat
            install_pkg fd
            install_pkg delta
            install_pkg fzf
            install_pkg btop
            install_pkg zoxide
            install_pkg starship
            install_pkg neovim
            c_green "Deploying fish config..."
            rsync -a --exclude=".git*" "$REPO_DIR/configs/.config/fish/" "$HOME/.config/fish/"
            ;;
        fishguide)
            c_green "Deploying fish-guide..."
            mkdir -p "$HOME/.local/share/bin"
            cp "$REPO_DIR/configs/.local/share/bin/fish-guide" "$HOME/.local/share/bin/fish-guide"
            chmod +x "$HOME/.local/share/bin/fish-guide"
            # Install textual dependency if missing
            if ! python3 -c "import textual" &>/dev/null; then
                c_green "  Installing textual (Python dependency)..."
                pip install --user textual 2>/dev/null || pip3 install --user textual 2>/dev/null || c_yellow "  Install manually: pip install textual"
            fi
            # Ensure the hook is deployed
            mkdir -p "$HOME/.config/fish/conf.d"
            cp "$REPO_DIR/configs/.config/fish/conf.d/fish_guide_hook.fish" "$HOME/.config/fish/conf.d/" 2>/dev/null || true
            ;;
        terminals)
            c_green "Deploying terminal configs..."
            for d in kitty foot; do
                [[ -d "$REPO_DIR/configs/.config/$d" ]] && rsync -a --exclude=".git*" "$REPO_DIR/configs/.config/$d/" "$HOME/.config/$d/"
            done
            ;;
        launcher)
            c_green "Deploying Fuzzel config..."
            [[ -d "$REPO_DIR/configs/.config/fuzzel" ]] && rsync -a --exclude=".git*" "$REPO_DIR/configs/.config/fuzzel/" "$HOME/.config/fuzzel/"
            ;;
        btop)
            c_green "Deploying Btop config..."
            [[ -d "$REPO_DIR/configs/.config/btop" ]] && rsync -a --exclude=".git*" "$REPO_DIR/configs/.config/btop/" "$HOME/.config/btop/"
            ;;
        cava)
            c_green "Deploying Cava config..."
            [[ -d "$REPO_DIR/configs/.config/cava" ]] && rsync -a --exclude=".git*" "$REPO_DIR/configs/.config/cava/" "$HOME/.config/cava/"
            ;;
        starship)
            c_green "Deploying Starship config..."
            [[ -f "$REPO_DIR/configs/.config/starship.toml" ]] && cp "$REPO_DIR/configs/.config/starship.toml" "$HOME/.config/starship.toml"
            ;;
        wlogout)
            c_green "Deploying Wlogout config..."
            [[ -d "$REPO_DIR/configs/.config/wlogout" ]] && rsync -a --exclude=".git*" "$REPO_DIR/configs/.config/wlogout/" "$HOME/.config/wlogout/"
            ;;
        fonts)
            c_green "Deploying font config..."
            [[ -d "$REPO_DIR/configs/.config/fontconfig" ]] && rsync -a --exclude=".git*" "$REPO_DIR/configs/.config/fontconfig/" "$HOME/.config/fontconfig/"
            ;;
        portal)
            c_green "Deploying XDG Desktop Portal config..."
            [[ -d "$REPO_DIR/hyprland/.config/xdg-desktop-portal" ]] && {
                mkdir -p "$HOME/.config/xdg-desktop-portal"
                rsync -a --exclude=".git*" "$REPO_DIR/hyprland/.config/xdg-desktop-portal/" "$HOME/.config/xdg-desktop-portal/"
            }
            ;;
        plugin)
            c_green "Building C++ plugin from source..."
            local build_dir="$REPO_DIR/build"
            mkdir -p "$build_dir"
            cmake -B "$build_dir" -S "$REPO_DIR" -DCMAKE_BUILD_TYPE=Release -DENABLE_MODULES="plugin" 2>&1 | tail -5
            cmake --build "$build_dir" -j"$(nproc 2>/dev/null || echo 4)" 2>&1 | tail -10

            c_green "Installing plugin (qmldir, .so, .qmltypes)..."
            sudo cmake --install "$build_dir" --prefix / 2>&1 | tail -10 || {
                # Fallback: manually copy full module directories
                c_yellow "cmake --install failed, falling back to manual copy..."
                local install_dir="/usr/lib/qt6/qml"
                if [[ -d "$build_dir/qml/Caelestia" ]]; then
                    sudo mkdir -p "$install_dir/Caelestia"
                    sudo cp -r "$build_dir/qml/Caelestia/"* "$install_dir/Caelestia/"
                fi
            }
            ;;
        yay)
            if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
                c_green "Installing yay (AUR helper)..."
                sudo pacman -S --noconfirm --needed git base-devel 2>/dev/null || true
                local tmpdir=$(mktemp -d)
                git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin" 2>/dev/null
                (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm 2>/dev/null) || c_yellow "  Install yay manually"
                rm -rf "$tmpdir"
            else
                c_green "AUR helper already installed."
            fi
            ;;
    esac
}

# ── Stash / restore user files ────────────────────────────────────────────────
stash_user_files() {
    rm -rf /tmp/hypr_custom_stash /tmp/hypr_monitors_lua_stash /tmp/hypr_monitors_conf_stash /tmp/shell_json_stash
    [[ -d "$HOME/.config/hypr/custom" ]] && cp -r "$HOME/.config/hypr/custom" /tmp/hypr_custom_stash
    [[ -f "$HOME/.config/hypr/monitors.lua" ]] && cp "$HOME/.config/hypr/monitors.lua" /tmp/hypr_monitors_lua_stash
    [[ -f "$HOME/.config/hypr/monitors.conf" ]] && cp "$HOME/.config/hypr/monitors.conf" /tmp/hypr_monitors_conf_stash
    [[ -f "$HOME/.config/caelestia/shell.json" ]] && cp "$HOME/.config/caelestia/shell.json" /tmp/shell_json_stash
}

restore_user_files() {
    [[ -d /tmp/hypr_custom_stash ]] && { rm -rf "$HOME/.config/hypr/custom"; mv /tmp/hypr_custom_stash "$HOME/.config/hypr/custom"; }
    [[ -f /tmp/hypr_monitors_lua_stash ]] && mv /tmp/hypr_monitors_lua_stash "$HOME/.config/hypr/monitors.lua"
    [[ -f /tmp/hypr_monitors_conf_stash ]] && mv /tmp/hypr_monitors_conf_stash "$HOME/.config/hypr/monitors.conf"
    [[ -f /tmp/shell_json_stash ]] && { mkdir -p "$HOME/.config/caelestia"; mv /tmp/shell_json_stash "$HOME/.config/caelestia/shell.json"; }
}

cleanup() { restore_user_files 2>/dev/null; }
trap cleanup EXIT INT TERM

# ── Main ──────────────────────────────────────────────────────────────────────
print_header

while true; do
    show_menu
    read -p "Enter choice(s) (e.g. 1 3 5 or 1,3,5): " input

    # Parse space-separated or comma-separated numbers
    IFS=', ' read -ra choices <<< "$input"
    for choice in "${choices[@]}"; do
        case "$choice" in
            [1-9]|1[0-6])
                idx=$((choice - 1))
                if [[ $idx -lt ${#COMP_ORDER[@]} ]]; then
                    k="${COMP_ORDER[$idx]}"
                    if [[ "$k" != "core" ]]; then
                        SEL[$k]=$(( 1 - SEL[$k] ))
                    fi
                fi
                ;;
            [Ss])
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

                # Install yay first if needed and selected
                [[ "${SEL[yay]}" == "1" ]] && install_component yay

                # Install all selected components
                for k in "${COMP_ORDER[@]}"; do
                    [[ "${SEL[$k]}" == "1" ]] && install_component "$k"
                done

                # Restore user-specific files
                restore_user_files

                # Symlink scripts for settings app
                mkdir -p "$HOME/.config/quickshell/caelestia/scripts"
                ln -sf "$REPO_DIR/update.sh" "$HOME/.config/quickshell/caelestia/scripts/update.sh"
                ln -sf "$REPO_DIR/install.sh" "$HOME/.config/quickshell/caelestia/scripts/install.sh"

                trap - EXIT INT TERM

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
