#!/usr/bin/env bash
# Caelestia-Impulse (Celestimpulse) Installer
# Interactive installer with component selection

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Components array: name|description|missing后果|arch_package|aur_package
declare -A COMPONENTS
COMPONENTS=(
    ["core"]="Core System|Required for basic functionality|Shell won't work at all|hyprland quickshell|caelestia-shell caelestia-cli"
    ["clipboard"]="Clipboard History|CopyQ clipboard manager|No clipboard history, Ctrl+V won't have history|copyq|"
    ["emoji"]="Emoji Picker|Emote emoji picker|No emoji picker, Super+E won't work|emote|"
    ["annotations"]="Screen Annotations|Wayscriber screen laser|No screen annotation, Super+Shift+D/G won't work||wayscriber"
    ["pypr"]="Pypr Helpers|Pyprland helpers|No magnifier, scratchpads, or corner helpers||pypr"
    ["per-window-layout"]="Per-Window Layout|Automatic keyboard layout per window|Keyboard layout won't auto-switch between windows||hyprland-per-window-layout"
    ["ocr"]="OCR Text Extraction|Screenshot OCR|No OCR text extraction from screenshots||tesseract"
    ["easyeffects"]="Audio Effects|EasyEffects audio processing|No audio effects or equalizer||easyeffects"
)

# Installation state
declare -A INSTALLED

print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║            Caelestia-Impulse (Celestimpulse)                 ║${NC}"
    echo -e "${CYAN}║                   Desktop Environment                        ║${NC}"
    echo -e "${CYAN}║  A unified dotfiles setup blending:                        ║${NC}"
    echo -e "${CYAN}║  • Caelestia shell (fluid UX, Material design, themes)     ║${NC}"
    echo -e "${CYAN}║  • Fast keybinds & utilities (lightning speed, capture tools)║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_component_menu() {
    echo -e "${YELLOW}Select components to install:${NC}"
    echo ""
    
    local i=1
    local keys=($(echo "${!COMPONENTS[@]}" | tr ' ' '\n' | sort))
    
    for key in "${keys[@]}"; do
        IFS='|' read -r name desc consequence arch aur <<< "${COMPONENTS[$key]}"
        
        if [[ "$key" == "core" ]]; then
            echo -e "${GREEN}[$i] $name${NC} - $desc"
            echo -e "    ${RED}(Required - cannot be skipped)${NC}"
        else
            local status="${RED}[ ]${NC}"
            if [[ "${INSTALLED[$key]}" == "true" ]]; then
                status="${GREEN}[✓]${NC}"
            fi
            echo -e "$status ${BLUE}[$i] $name${NC} - $desc"
        fi
        echo -e "    ${YELLOW}If missing: $consequence${NC}"
        
        local pkg_info=""
        if [[ -n "$arch" ]]; then
            pkg_info="pacman: $arch"
        fi
        if [[ -n "$aur" ]]; then
            if [[ -n "$pkg_info" ]]; then
                pkg_info="$pkg_info, AUR: $aur"
            else
                pkg_info="AUR: $aur"
            fi
        fi
        echo -e "    ${CYAN}Package: $pkg_info${NC}"
        echo ""
        
        ((i++))
    done
    
    echo -e "${YELLOW}[A] Select All${NC}"
    echo -e "${YELLOW}[N] Select None (except core)${NC}"
    echo -e "${YELLOW}[I] Install Selected${NC}"
    echo -e "${YELLOW}[Q] Quit${NC}"
    echo ""
}

install_package() {
    local pkg="$1"
    local is_aur="${2:-false}"
    
    if [[ "$is_aur" == "true" ]]; then
        if command -v yay &>/dev/null; then
            yay -S --noconfirm "$pkg" 2>/dev/null || echo -e "${YELLOW}Warning: Failed to install $pkg${NC}"
        elif command -v paru &>/dev/null; then
            paru -S --noconfirm "$pkg" 2>/dev/null || echo -e "${YELLOW}Warning: Failed to install $pkg${NC}"
        else
            echo -e "${YELLOW}Warning: No AUR helper found. Install $pkg manually with: yay -S $pkg${NC}"
        fi
    else
        sudo pacman -S --noconfirm "$pkg" 2>/dev/null || echo -e "${YELLOW}Warning: Failed to install $pkg${NC}"
    fi
}

install_components() {
    echo -e "${CYAN}Installing selected components...${NC}"
    echo ""
    
    # Always install core
    echo -e "${GREEN}Installing core components...${NC}"
    install_package "hyprland"
    install_package "quickshell"
    install_package "caelestia-cli" true
    install_package "caelestia-shell" true
    
    # Install selected components
    local keys=($(echo "${!COMPONENTS[@]}" | tr ' ' '\n' | sort))
    
    for key in "${keys[@]}"; do
        if [[ "$key" == "core" ]]; then
            continue
        fi
        
        if [[ "${INSTALLED[$key]}" == "true" ]]; then
            IFS='|' read -r name desc consequence arch aur <<< "${COMPONENTS[$key]}"
            echo -e "${GREEN}Installing $name...${NC}"
            
            if [[ -n "$arch" ]]; then
                install_package "$arch" false
            fi
            if [[ -n "$aur" ]]; then
                install_package "$aur" true
            fi
        fi
    done
    
    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo ""
}

deploy_configs() {
    echo -e "${CYAN}Deploying configuration files...${NC}"

    # Setup safety exit/error trap to restore stashed configs in case of failure
    cleanup() {
        if [[ -d /tmp/hypr_custom_stash ]]; then
            mkdir -p "$HOME/.config/hypr"
            rm -rf "$HOME/.config/hypr/custom"
            mv /tmp/hypr_custom_stash "$HOME/.config/hypr/custom"
        fi
        if [[ -f /tmp/hypr_monitors_lua_stash ]]; then
            mkdir -p "$HOME/.config/hypr"
            mv /tmp/hypr_monitors_lua_stash "$HOME/.config/hypr/monitors.lua"
        fi
        if [[ -f /tmp/hypr_monitors_conf_stash ]]; then
            mkdir -p "$HOME/.config/hypr"
            mv /tmp/hypr_monitors_conf_stash "$HOME/.config/hypr/monitors.conf"
        fi
        if [[ -f /tmp/shell_json_stash ]]; then
            mkdir -p "$HOME/.config/caelestia"
            mv /tmp/shell_json_stash "$HOME/.config/caelestia/shell.json"
        fi
    }
    trap cleanup EXIT INT TERM
    
    # 1. Stash existing user/device-specific files temporarily
    if [[ -d "$HOME/.config/hypr/custom" ]]; then
        echo -e "${BLUE}Stashing your custom Hyprland configs...${NC}"
        rm -rf /tmp/hypr_custom_stash
        cp -r "$HOME/.config/hypr/custom" /tmp/hypr_custom_stash
    fi
    if [[ -f "$HOME/.config/hypr/monitors.lua" ]]; then
        cp "$HOME/.config/hypr/monitors.lua" /tmp/hypr_monitors_lua_stash
    fi
    if [[ -f "$HOME/.config/hypr/monitors.conf" ]]; then
        cp "$HOME/.config/hypr/monitors.conf" /tmp/hypr_monitors_conf_stash
    fi
    if [[ -f "$HOME/.config/caelestia/shell.json" ]]; then
        echo -e "${BLUE}Stashing your shell.json settings...${NC}"
        cp "$HOME/.config/caelestia/shell.json" /tmp/shell_json_stash
    fi

    # 2. Backup existing active configs
    if [[ -d "$HOME/.config/hypr" ]]; then
        echo -e "${YELLOW}Backing up existing Hyprland config folder to ~/.config/hypr.bak...${NC}"
        rm -rf "$HOME/.config/hypr.bak"
        mv "$HOME/.config/hypr" "$HOME/.config/hypr.bak.$(date +%Y%m%d%H%M%S)"
    fi
    if [[ -d "$HOME/.config/quickshell/caelestia" ]]; then
        echo -e "${YELLOW}Backing up existing Quickshell caelestia folder to ~/.config/quickshell/caelestia.bak...${NC}"
        rm -rf "$HOME/.config/quickshell/caelestia.bak"
        mv "$HOME/.config/quickshell/caelestia" "$HOME/.config/quickshell/caelestia.bak.$(date +%Y%m%d%H%M%S)"
    fi

    # 3. Deploy new global configs from repository
    mkdir -p "$HOME/.config/hypr"
    rsync -a --exclude=".git*" ./hyprland/.config/hypr/ "$HOME/.config/hypr/"

    mkdir -p "$HOME/.config/quickshell/caelestia"
    rsync -a --exclude=".git*" ./shell/ "$HOME/.config/quickshell/caelestia/"

    # 4. Restore stashed custom/device-specific files
    if [[ -d /tmp/hypr_custom_stash ]]; then
        echo -e "${GREEN}Restoring your custom Hyprland configs...${NC}"
        rm -rf "$HOME/.config/hypr/custom"
        mv /tmp/hypr_custom_stash "$HOME/.config/hypr/custom"
    fi
    if [[ -f /tmp/hypr_monitors_lua_stash ]]; then
        mv /tmp/hypr_monitors_lua_stash "$HOME/.config/hypr/monitors.lua"
    fi
    if [[ -f /tmp/hypr_monitors_conf_stash ]]; then
        mv /tmp/hypr_monitors_conf_stash "$HOME/.config/hypr/monitors.conf"
    fi
    if [[ -f /tmp/shell_json_stash ]]; then
        echo -e "${GREEN}Restoring your shell.json settings...${NC}"
        mkdir -p "$HOME/.config/caelestia"
        mv /tmp/shell_json_stash "$HOME/.config/caelestia/shell.json"
    else
        echo -e "${BLUE}No existing shell.json found, deploying default template...${NC}"
        mkdir -p "$HOME/.config/caelestia"
        cp ./hyprland/.config/caelestia/shell.json "$HOME/.config/caelestia/shell.json"
    fi

    # 5. Set executable permissions on scripts
    chmod +x "$HOME/.config/hypr/hyprland/scripts/"* &>/dev/null || true
    chmod +x "$HOME/.config/hypr/hyprland/scripts/ai/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/musicRecognition/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/colors/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/colors/random/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/thumbnails/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/videos/"* &>/dev/null || true

    # Disable trap since deployment finished successfully
    trap - EXIT INT TERM
    echo -e "${GREEN}Configuration deployed successfully!${NC}"

    # Automatically reload Hyprland if running
    if command -v hyprctl &>/dev/null && [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
        echo -e "${BLUE}Reloading Hyprland configuration...${NC}"
        hyprctl reload &>/dev/null || true
    fi
}

show_summary() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Installation Summary${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${GREEN}Installed components:${NC}"
    local keys=($(echo "${!COMPONENTS[@]}" | tr ' ' '\n' | sort))
    
    for key in "${keys[@]}"; do
        IFS='|' read -r name desc consequence arch aur <<< "${COMPONENTS[$key]}"
        
        if [[ "$key" == "core" ]] || [[ "${INSTALLED[$key]}" == "true" ]]; then
            echo -e "  ${GREEN}✓${NC} $name"
        else
            echo -e "  ${RED}✗${NC} $name"
            echo -e "    ${YELLOW}Missing: $consequence${NC}"
        fi
    done
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Keybinds:${NC}"
    echo -e "  Super              - Launcher"
    echo -e "  Super + I          - Settings (Nexus)"
    echo -e "  Super + D          - Dashboard"
    echo -e "  Super + A          - Sidebar"
    echo -e "  Ctrl + Alt + Del   - Session menu"
    echo -e "  Super + Slash      - Toggle OSD"
    echo -e "  Super + V          - Clipboard (CopyQ or Caelestia Fuzzel-Clip)"
    echo -e "  Super + Period     - Emoji picker (Emote or Caelestia Fuzzel-Emoji)"
    echo ""
    echo -e "${YELLOW}Optional keybinds (if installed):${NC}"
    echo -e "  Super + Shift + D  - Screen annotation (if wayscriber installed)"
    echo -e "  Super + Shift + G  - Screen laser (if wayscriber installed)"
    echo ""
    echo -e "${GREEN}To start: Log out and log back in, or run: hyprctl reload${NC}"
    echo ""
}

# Main
print_header

# Initialize all components as selected except core
for key in "${!COMPONENTS[@]}"; do
    if [[ "$key" != "core" ]]; then
        INSTALLED[$key]="true"
    fi
done

while true; do
    show_component_menu
    
    read -p "Enter choice: " choice
    
    case "$choice" in
        [1-8])
            local keys=($(echo "${!COMPONENTS[@]}" | tr ' ' '\n' | sort))
            local idx=$((choice - 1))
            if [[ $idx -lt ${#keys[@]} ]]; then
                local key="${keys[$idx]}"
                if [[ "$key" != "core" ]]; then
                    if [[ "${INSTALLED[$key]}" == "true" ]]; then
                        INSTALLED[$key]="false"
                    else
                        INSTALLED[$key]="true"
                    fi
                fi
            fi
            ;;
        [Aa])
            for key in "${!COMPONENTS[@]}"; do
                INSTALLED[$key]="true"
            done
            ;;
        [Nn])
            for key in "${!COMPONENTS[@]}"; do
                if [[ "$key" != "core" ]]; then
                    INSTALLED[$key]="false"
                fi
            done
            ;;
        [Ii])
            install_components
            deploy_configs
            show_summary
            exit 0
            ;;
        [Qq])
            echo -e "${YELLOW}Installation cancelled.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
done
