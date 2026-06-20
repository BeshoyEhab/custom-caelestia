#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# update.sh - Update the custom-caelestia repo & active configs
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

MERGED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[x]${NC} $1"; exit 1; }

declare -a IGNORE_PATTERNS=()

load_ignore_patterns() {
    # Default ignored files (always stashed or hardware specific)
    IGNORE_PATTERNS=("custom/" "monitors.lua" "monitors.conf" "shell.json" "shell.json.bak" "custom")
    
    local ignore_files=("./.updateignore" "$HOME/.updateignore" "$HOME/.config/hypr/.updateignore")
    for f in "${ignore_files[@]}"; do
        if [[ -f "$f" ]]; then
            while IFS= read -r line || [[ -n "$line" ]]; do
                # Trim whitespace, skip comments and empty lines
                line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                [[ -z "$line" || "$line" =~ ^# ]] && continue
                IGNORE_PATTERNS+=("$line")
            done < "$f"
        fi
    done
}

should_ignore() {
    local file_path="$1"
    local rel_path=""
    if [[ "$file_path" == "$HOME/.config/hypr/"* ]]; then
        rel_path="${file_path#$HOME/.config/hypr/}"
    elif [[ "$file_path" == "$HOME/.config/quickshell/caelestia/"* ]]; then
        rel_path="${file_path#$HOME/.config/quickshell/caelestia/}"
    else
        rel_path="${file_path#$HOME/}"
    fi

    for pattern in "${IGNORE_PATTERNS[@]}"; do
        # Exact match
        if [[ "$rel_path" == "$pattern" ]]; then
            return 0
        fi
        # Glob match
        if [[ "$rel_path" == $pattern ]]; then
            return 0
        fi
        # Directory pattern (ends in /)
        if [[ "$pattern" == */ ]]; then
            local dir_pattern="${pattern%/}"
            if [[ "$rel_path" == "$dir_pattern"/* ]]; then
                return 0
            fi
        fi
    done
    return 1
}

handle_file_conflict() {
    local repo_file="$1"
    local home_file="$2"
    local filename=$(basename "$home_file")
    local dirname=$(dirname "$home_file")
    local choice=""

    echo -e "\n${YELLOW}[!] Conflict detected in:${NC} $home_file"
    echo -e "Repository version differs from your active version."
    echo ""
    echo "Choose an action:"
    echo "1) Replace local file with repository version"
    echo "2) Keep local file unchanged"
    echo "3) Backup local as ${filename}.old and use repository version"
    echo "4) Save repository version as ${filename}.new and keep local"
    echo "5) Show diff and decide"
    echo "6) Skip this file"
    echo "7) Add to .updateignore and skip"
    echo ""

    while true; do
        read -p "Enter choice (1-7): " choice < /dev/tty
        case "$choice" in
            1)
                cp -p "$repo_file" "$home_file"
                echo -e "${GREEN}Replaced with repository version.${NC}"
                break
                ;;
            2)
                echo -e "${BLUE}Kept local version unchanged.${NC}"
                break
                ;;
            3)
                mv "$home_file" "${dirname}/${filename}.old"
                cp -p "$repo_file" "$home_file"
                echo -e "${GREEN}Backed up to ${filename}.old and replaced.${NC}"
                break
                ;;
            4)
                cp -p "$repo_file" "${dirname}/${filename}.new"
                echo -e "${GREEN}Saved repository version as ${filename}.new.${NC}"
                break
                ;;
            5)
                echo -e "\n${CYAN}--- Differences in $filename ---${NC}"
                diff -u "$home_file" "$repo_file" || true
                echo -e "${CYAN}----------------------------------${NC}\n"
                # Prompt again
                ;;
            6)
                echo -e "${BLUE}Skipped.${NC}"
                break
                ;;
            7)
                local rel_path=""
                if [[ "$home_file" == "$HOME/.config/hypr/"* ]]; then
                    rel_path="${home_file#$HOME/.config/hypr/}"
                elif [[ "$home_file" == "$HOME/.config/quickshell/caelestia/"* ]]; then
                    rel_path="${home_file#$HOME/.config/quickshell/caelestia/}"
                else
                    rel_path="${home_file#$HOME/}"
                fi
                mkdir -p "$HOME/.config/hypr"
                echo "$rel_path" >> "$HOME/.config/hypr/.updateignore"
                IGNORE_PATTERNS+=("$rel_path")
                echo -e "${GREEN}Added '$rel_path' to ~/.config/hypr/.updateignore and skipped.${NC}"
                break
                ;;
            *)
                echo -e "${RED}Invalid choice.${NC}"
                ;;
        esac
    done
}

deploy_active_updates() {
    log "Deploying configuration updates..."
    load_ignore_patterns

    # 1. Safety Backup of existing active configurations (copy-based so active files remain for comparison)
    if [[ -d "$HOME/.config/hypr" ]]; then
        local backup_dir="$HOME/.config/hypr.bak.$(date +%Y%m%d%H%M%S)"
        log "Creating safety backup of ~/.config/hypr to $(basename "$backup_dir")..."
        cp -r "$HOME/.config/hypr" "$backup_dir"
    fi
    if [[ -d "$HOME/.config/quickshell/caelestia" ]]; then
        local backup_dir="$HOME/.config/quickshell/caelestia.bak.$(date +%Y%m%d%H%M%S)"
        log "Creating safety backup of ~/.config/quickshell/caelestia to $(basename "$backup_dir")..."
        cp -r "$HOME/.config/quickshell/caelestia" "$backup_dir"
    fi

    # 2. Deploy Hyprland configs file by file
    log "Processing Hyprland configurations..."
    mkdir -p "$HOME/.config/hypr"
    find ./hyprland/.config/hypr/ -type f | while read -r repo_file; do
        local rel_path="${repo_file#./hyprland/.config/hypr/}"
        local home_file="$HOME/.config/hypr/$rel_path"
        
        if should_ignore "$home_file"; then
            continue
        fi
        
        mkdir -p "$(dirname "$home_file")"
        if [[ -f "$home_file" ]]; then
            if ! cmp -s "$repo_file" "$home_file"; then
                handle_file_conflict "$repo_file" "$home_file"
            fi
        else
            cp -p "$repo_file" "$home_file"
        fi
    done

    # 3. Deploy Quickshell caelestia configs file by file
    log "Processing Quickshell configurations..."
    mkdir -p "$HOME/.config/quickshell/caelestia"
    find ./shell/ -type f -not -path "*/build/*" -not -path "*/.git/*" | while read -r repo_file; do
        local rel_path="${repo_file#./shell/}"
        local home_file="$HOME/.config/quickshell/caelestia/$rel_path"
        
        if should_ignore "$home_file"; then
            continue
        fi
        
        mkdir -p "$(dirname "$home_file")"
        if [[ -f "$home_file" ]]; then
            if ! cmp -s "$repo_file" "$home_file"; then
                handle_file_conflict "$repo_file" "$home_file"
            fi
        else
            cp -p "$repo_file" "$home_file"
        fi
    done

    # 4. Set executable permissions on scripts
    chmod +x "$HOME/.config/hypr/hyprland/scripts/"* &>/dev/null || true
    chmod +x "$HOME/.config/hypr/hyprland/scripts/ai/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/musicRecognition/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/colors/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/colors/random/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/thumbnails/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/videos/"* &>/dev/null || true

    # 5. Ensure install/update script symlinks exist for settings app
    mkdir -p "$HOME/.config/quickshell/caelestia/scripts"
    ln -sf "$MERGED_DIR/update.sh" "$HOME/.config/quickshell/caelestia/scripts/update.sh"
    ln -sf "$MERGED_DIR/install.sh" "$HOME/.config/quickshell/caelestia/scripts/install.sh"

    log "Configuration deployed successfully!"

    # 5. Detect plugin source changes and rebuild if needed
    log "Checking for C++ plugin source changes..."
    local plugin_changed=false
    local plugin_src="$MERGED_DIR/shell/plugin/src"
    local build_dir="$MERGED_DIR/build"

    if [[ -d "$plugin_src" ]]; then
        # Use a stamp file to track last build time
        local stamp_file="$build_dir/.plugin_build_stamp"

        if [[ ! -f "$stamp_file" ]]; then
            # No stamp = never built, rebuild
            plugin_changed=true
        else
            # Check if any plugin source file is newer than the stamp
            if find "$plugin_src" -type f \( -name "*.hpp" -o -name "*.cpp" \) -newer "$stamp_file" 2>/dev/null | grep -q .; then
                plugin_changed=true
            fi
        fi
    fi

    if [[ "$plugin_changed" == "true" ]]; then
        log "Plugin source changed — rebuilding..."
        local BUILD_DIR="$MERGED_DIR/build"
        mkdir -p "$BUILD_DIR"
        cmake -B "$BUILD_DIR" -S "$MERGED_DIR" \
            -DCMAKE_BUILD_TYPE=Release \
            -DENABLE_MODULES="plugin" 2>&1 | tail -3

        local NPROC=$(nproc 2>/dev/null || echo 4)
        cmake --build "$BUILD_DIR" --target caelestia-configplugin -j"$NPROC" 2>&1 | tail -5

        local INSTALL_DIR="/usr/lib/qt6/qml"
        find "$BUILD_DIR" -name "libcaelestia-*.so" -type f | while read -r lib; do
            local modname=$(basename "$lib")
            local subdir
            if [[ "$modname" == *"plugin.so" ]]; then
                subdir=$(echo "$modname" | sed 's/^libcaelestia-//;s/plugin\.so$//' | sed 's/\b\(.\)/\U\1/')
            else
                subdir=$(echo "$modname" | sed 's/^libcaelestia-//;s/\.so$//' | sed 's/\b\(.\)/\U\1/')
            fi
            local target_dir="$INSTALL_DIR/Caelestia/$subdir"
            sudo mkdir -p "$target_dir"
            sudo cp -p "$lib" "$target_dir/$modname"
            echo "  Installed: $modname -> $target_dir/"
        done

        touch "$stamp_file"
        log "Plugin rebuilt and installed."
    else
        log "Plugin source unchanged — skipping rebuild."
    fi

    # Automatically reload Hyprland if running
    if command -v hyprctl &>/dev/null && [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
        log "Reloading Hyprland configuration..."
        hyprctl reload &>/dev/null || true
    fi
}

main() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Updating custom-caelestia Repository"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    if [ ! -d "$MERGED_DIR/.git" ]; then
        warn "Not a git repository: $MERGED_DIR"
        warn "Proceeding with configuration deployment directly."
        deploy_active_updates
        exit 0
    fi

    log "Updating repository at $MERGED_DIR..."
    cd "$MERGED_DIR"

    # Fetch origin
    git fetch origin 2>/dev/null || {
        err "Failed to fetch from origin."
    }

    # Stash any local changes
    local stash=false
    if ! git diff --quiet || ! git diff --cached --quiet; then
        log "Stashing local changes..."
        git stash push -m "auto-stash before update" &>/dev/null
        stash=true
    fi

    local current_branch
    current_branch=$(git branch --show-current)
    
    log "Pulling latest changes on branch '$current_branch'..."
    git pull origin "$current_branch" --no-rebase 2>/dev/null || warn "Failed to pull updates automatically."

    # Restore stash
    if [ "$stash" = true ]; then
        log "Restoring stashed changes..."
        git stash pop &>/dev/null || warn "Failed to pop stash - manual resolution required"
    fi

    echo ""
    log "Repository updated successfully!"
    echo ""
    
    deploy_active_updates
}

main "$@"
