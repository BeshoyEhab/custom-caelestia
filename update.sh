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
BOLD='\033[1m'
NC='\033[0m'

# Options
BACKUP=false
ON_CONFLICT="ask"

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[x]${NC} $1"; exit 1; }

usage() {
    cat <<EOF
${BOLD}Usage:${NC} $0 [OPTIONS]

Update the custom-caelestia repository and deploy config changes.

${BOLD}Options:${NC}
  ${CYAN}--backup${NC}           Create safety backups before deploying
  ${CYAN}--on-conflict${NC} <m>  How to handle file conflicts (default: ask)
                          ${GREEN}ask${NC}      - Prompt for each conflict
                          ${GREEN}replace${NC}  - Always replace with repo version
                          ${GREEN}keep${NC}     - Always keep your local version
                          ${GREEN}backup${NC}   - Backup local file, then replace
                          ${GREEN}new${NC}      - Save repo version as .new, keep local
  ${CYAN}--non-interactive${NC}  Skip prompts, use defaults (replace on conflict)
  ${CYAN}--check${NC}           Check for updates without applying
  ${CYAN}-h, --help${NC}        Show this help

${BOLD}Examples:${NC}
  $0                          Interactive update (prompts on conflicts)
  $0 --backup                 Update with backups enabled
  $0 --on-conflict=replace    Update, replacing all changed files
  $0 --on-conflict=keep       Update, keeping all your local changes
  $0 --on-conflict=backup     Update, backing up each local file first
  $0 --non-interactive        Non-interactive: no prompts, replaces files

${BOLD}Conflict resolution:${NC}
  When the repo has a newer version of a file you also modified,
  you'll be asked what to do (unless --on-conflict or --non-interactive
  is set). Options: replace, keep, backup, new, diff, skip, ignore.
EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --backup)
                BACKUP=true
                shift
                ;;
            --on-conflict)
                [[ -z "${2:-}" ]] && err "--on-conflict requires a value: ask, replace, keep, backup, new"
                ON_CONFLICT="$2"
                shift 2
                ;;
            --on-conflict=*)
                ON_CONFLICT="${1#*=}"
                shift
                ;;
            --non-interactive)
                ON_CONFLICT="replace"
                shift
                ;;
            --check)
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                warn "Unknown option: $1 (use -h for help)"
                shift
                ;;
        esac
    done

    # Validate conflict mode
    case "$ON_CONFLICT" in
        ask|replace|keep|backup|new) ;;
        *) err "Invalid --on-conflict value: $ON_CONFLICT (use: ask, replace, keep, backup, new)" ;;
    esac
}

declare -a IGNORE_PATTERNS=()

load_ignore_patterns() {
    IGNORE_PATTERNS=("custom/" "monitors.lua" "monitors.conf" "shell.json" "shell.json.bak" "custom")

    local ignore_files=("./.updateignore" "$HOME/.updateignore" "$HOME/.config/hypr/.updateignore")
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
        if [[ "$rel_path" == "$pattern" ]]; then return 0; fi
        if [[ "$rel_path" == $pattern ]]; then return 0; fi
        if [[ "$pattern" == */ ]]; then
            local dir_pattern="${pattern%/}"
            if [[ "$rel_path" == "$dir_pattern"/* ]]; then return 0; fi
        fi
    done
    return 1
}

# Apply a conflict resolution action
# Usage: apply_conflict_action <repo_file> <home_file> <action>
apply_conflict_action() {
    local repo_file="$1"
    local home_file="$2"
    local action="$3"
    local filename
    filename=$(basename "$home_file")
    local dirname
    dirname=$(dirname "$home_file")

    case "$action" in
        replace)
            cp -p "$repo_file" "$home_file"
            log "Replaced: $filename"
            ;;
        keep)
            echo -e "  ${BLUE}Kept:${NC} $filename (unchanged)"
            ;;
        backup)
            mv "$home_file" "${dirname}/${filename}.old"
            cp -p "$repo_file" "$home_file"
            log "Backed up to ${filename}.old, replaced with repo version"
            ;;
        new)
            cp -p "$repo_file" "${dirname}/${filename}.new"
            echo -e "  ${YELLOW}Saved:${NC} repo version as ${filename}.new"
            ;;
    esac
}

handle_file_conflict() {
    local repo_file="$1"
    local home_file="$2"
    local filename
    filename=$(basename "$home_file")
    local dirname
    dirname=$(dirname "$home_file")

    # If not asking, apply the pre-set action
    if [[ "$ON_CONFLICT" != "ask" ]]; then
        apply_conflict_action "$repo_file" "$home_file" "$ON_CONFLICT"
        return
    fi

    # Interactive prompt
    echo ""
    echo -e "${YELLOW}┌─ Conflict:${NC} ${BOLD}$filename${NC}"
    echo -e "${YELLOW}│${NC}  Repository version differs from your local file."

    while true; do
        echo -e "${YELLOW}└─${NC} Choose an action:"
        echo "  ${GREEN}r${NC}) Replace local with repo version"
        echo "  ${GREEN}k${NC}) Keep local file unchanged"
        echo "  ${GREEN}b${NC}) Backup local → .old, then replace"
        echo "  ${GREEN}n${NC}) Save repo version as .new, keep local"
        echo "  ${GREEN}d${NC}) Show diff"
        echo "  ${GREEN}s${NC}) Skip this file"
        echo "  ${GREEN}i${NC}) Add to .updateignore and skip"

        local choice
        read -p "  → " choice < /dev/tty

        case "${choice,,}" in
            r) apply_conflict_action "$repo_file" "$home_file" "replace"; break ;;
            k) apply_conflict_action "$repo_file" "$home_file" "keep"; break ;;
            b) apply_conflict_action "$repo_file" "$home_file" "backup"; break ;;
            n) apply_conflict_action "$repo_file" "$home_file" "new"; break ;;
            d)
                echo ""
                echo -e "${CYAN}--- Diff: $filename ---${NC}"
                diff -u "$home_file" "$repo_file" || true
                echo -e "${CYAN}--- End diff ---${NC}"
                echo ""
                ;;
            s)
                echo -e "  ${BLUE}Skipped:${NC} $filename"
                break
                ;;
            i)
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
                echo -e "  ${GREEN}Ignored:${NC} added '$rel_path' to .updateignore"
                break
                ;;
            *)
                echo -e "  ${RED}Invalid choice. Enter r, k, b, n, d, s, or i.${NC}"
                ;;
        esac
    done
}

# Deploy files from a repo directory to a home directory, file by file.
# Handles conflicts via handle_file_conflict.
# Usage: deploy_dir <repo_dir> <home_dir> [find_excludes...]
deploy_dir() {
    local repo_dir="$1"
    local home_dir="$2"
    shift 2
    local find_args=("$@")

    mkdir -p "$home_dir"
    find "$repo_dir" -type f "${find_args[@]}" | while read -r repo_file; do
        local rel_path="${repo_file#$repo_dir/}"
        local home_file="$home_dir/$rel_path"

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
}

deploy_active_updates() {
    log "Deploying configuration updates..."
    load_ignore_patterns

    if [[ "$ON_CONFLICT" != "ask" ]]; then
        echo -e "  Conflict mode: ${BOLD}$ON_CONFLICT${NC}"
    fi

    # ── Safety Backup (only if --backup) ──────────────────────────────────
    if [[ "$BACKUP" == "true" ]]; then
        local ts
        ts=$(date +%Y%m%d%H%M%S)
        local dirs_to_backup=(
            "$HOME/.config/hypr"
            "$HOME/.config/quickshell/caelestia"
            "$HOME/.config/fish"
            "$HOME/.config/btop"
            "$HOME/.config/cava"
            "$HOME/.config/kitty"
            "$HOME/.config/foot"
            "$HOME/.config/fuzzel"
            "$HOME/.config/wlogout"
            "$HOME/.config/fontconfig"
            "$HOME/.config/xdg-desktop-portal"
            "$HOME/.config/systemd"
            "$HOME/.local/share/bin"
        )
        for d in "${dirs_to_backup[@]}"; do
            if [[ -d "$d" ]]; then
                local backup_dir="${d}.bak.${ts}"
                log "Backing up $(basename "$d") → $(basename "$backup_dir")"
                cp -r "$d" "$backup_dir"
            fi
        done
    fi

    # ── Hyprland configs ──────────────────────────────────────────────────
    log "Processing Hyprland configurations..."
    deploy_dir "./hyprland/.config/hypr" "$HOME/.config/hypr"

    # ── Caelestia config (skip shell.json — user-specific) ────────────────
    if [[ -d "./hyprland/.config/caelestia" ]]; then
        log "Processing Caelestia config..."
        mkdir -p "$HOME/.config/caelestia"
        find ./hyprland/.config/caelestia/ -type f | while read -r repo_file; do
            local rel_path="${repo_file#./hyprland/.config/caelestia/}"
            local home_file="$HOME/.config/caelestia/$rel_path"
            # Skip shell.json — it's user-specific (monitors, theme, etc.)
            [[ "$rel_path" == "shell.json" ]] && continue
            if should_ignore "$home_file"; then continue; fi
            mkdir -p "$(dirname "$home_file")"
            if [[ -f "$home_file" ]]; then
                if ! cmp -s "$repo_file" "$home_file"; then
                    handle_file_conflict "$repo_file" "$home_file"
                fi
            else
                cp -p "$repo_file" "$home_file"
            fi
        done
    fi

    # ── Systemd services ──────────────────────────────────────────────────
    if [[ -d "./hyprland/.config/systemd" ]]; then
        log "Processing systemd services..."
        deploy_dir "./hyprland/.config/systemd/user" "$HOME/.config/systemd/user"
        systemctl --user daemon-reload 2>/dev/null || true
    fi

    # ── XDG Desktop Portal config ─────────────────────────────────────────
    if [[ -d "./hyprland/.config/xdg-desktop-portal" ]]; then
        log "Processing XDG portal config..."
        deploy_dir "./hyprland/.config/xdg-desktop-portal" "$HOME/.config/xdg-desktop-portal"
    fi

    # ── Quickshell caelestia configs ──────────────────────────────────────
    log "Processing Quickshell configurations..."
    deploy_dir "./shell" "$HOME/.config/quickshell/caelestia" \
        -not -path "*/build/*" -not -path "*/.git/*" -not -path "*/upstream/*"

    # ── Fish shell config ─────────────────────────────────────────────────
    log "Processing Fish shell configurations..."
    deploy_dir "./configs/.config/fish" "$HOME/.config/fish"

    # ── Other app configs ─────────────────────────────────────────────────
    local app_configs=(
        "btop"
        "cava"
        "kitty"
        "foot"
        "fuzzel"
        "wlogout"
        "fontconfig"
    )
    for app in "${app_configs[@]}"; do
        if [[ -d "./configs/.config/$app" ]]; then
            log "Processing $app configuration..."
            deploy_dir "./configs/.config/$app" "$HOME/.config/$app"
        fi
    done

    # Starship config (single file)
    if [[ -f "./configs/.config/starship.toml" ]]; then
        log "Processing Starship prompt config..."
        local starship_home="$HOME/.config/starship.toml"
        if [[ -f "$starship_home" ]]; then
            if ! cmp -s "./configs/.config/starship.toml" "$starship_home"; then
                handle_file_conflict "./configs/.config/starship.toml" "$starship_home"
            fi
        else
            cp -p "./configs/.config/starship.toml" "$starship_home"
        fi
    fi

    # ── Fish-guide binary ─────────────────────────────────────────────────
    if [[ -f "./configs/.local/share/bin/fish-guide" ]]; then
        log "Installing fish-guide..."
        mkdir -p "$HOME/.local/share/bin"
        cp -p "./configs/.local/share/bin/fish-guide" "$HOME/.local/share/bin/fish-guide"
        chmod +x "$HOME/.local/share/bin/fish-guide"
    fi

    # ── Set executable permissions ────────────────────────────────────────
    chmod +x "$HOME/.config/hypr/hyprland/scripts/"* &>/dev/null || true
    chmod +x "$HOME/.config/hypr/hyprland/scripts/ai/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/musicRecognition/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/colors/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/colors/random/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/thumbnails/"* &>/dev/null || true
    chmod +x "$HOME/.config/quickshell/caelestia/scripts/videos/"* &>/dev/null || true
    chmod +x "$HOME/.local/share/bin/fish-guide" &>/dev/null || true

    # ── Ensure install/update script symlinks for settings app ────────────
    mkdir -p "$HOME/.config/quickshell/caelestia/scripts"
    ln -sf "$MERGED_DIR/update.sh" "$HOME/.config/quickshell/caelestia/scripts/update.sh"
    ln -sf "$MERGED_DIR/install.sh" "$HOME/.config/quickshell/caelestia/scripts/install.sh"

    log "Configuration deployed successfully!"

    # ── C++ plugin rebuild if needed ──────────────────────────────────────
    log "Checking for C++ plugin source changes..."
    local plugin_changed=false
    local plugin_src="$MERGED_DIR/shell/plugin/src"
    local build_dir="$MERGED_DIR/build"

    if [[ -d "$plugin_src" ]]; then
        local stamp_file="$build_dir/.plugin_build_stamp"

        if [[ ! -f "$stamp_file" ]]; then
            plugin_changed=true
        else
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
            -DENABLE_MODULES="plugin" 2>&1 | tail -3 || true

        local NPROC=$(nproc 2>/dev/null || echo 4)
        cmake --build "$BUILD_DIR" -j"$NPROC" 2>&1 | tail -5 || true

        log "Installing plugin (qmldir, .so, .qmltypes)..."
        sudo cmake --install "$BUILD_DIR" --prefix / 2>&1 | tail -10 || {
            # Fallback: manually copy full module directories
            warn "cmake --install failed, falling back to manual copy..."
            local INSTALL_DIR="/usr/lib/qt6/qml"
            if [[ -d "$BUILD_DIR/qml/Caelestia" ]]; then
                sudo mkdir -p "$INSTALL_DIR/Caelestia"
                sudo cp -r "$BUILD_DIR/qml/Caelestia/"* "$INSTALL_DIR/Caelestia/"
            fi
        }

        touch "$stamp_file"
        log "Plugin rebuilt and installed."
    else
        log "Plugin source unchanged — skipping rebuild."
    fi

    # ── Reload Hyprland if running ────────────────────────────────────────
    if command -v hyprctl &>/dev/null && [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
        log "Reloading Hyprland configuration..."
        hyprctl reload &>/dev/null || true
    fi
}

main() {
    parse_args "$@"

    echo "═══════════════════════════════════════════════════════════════"
    echo "  Updating custom-caelestia"
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
exit 0
