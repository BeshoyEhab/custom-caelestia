#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# update.sh - Update custom-caelestia configs
# Only updates sections that are installed. Preserves user-customized files.
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

MERGED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; exit 1; }

# ── Sudo wrapper: show command, ask for confirmation ─────────────────────────
sudo() {
    printf '  >> sudo %s\n' "$*" >/dev/tty
    printf '  %b run? [Y/n] %b ' "$CYAN" "$NC" >/dev/tty
    read -r _confirm < /dev/tty
    [[ "${_confirm,,}" == "n" ]] && return 1
    command sudo "$@"
}

# ── Options ───────────────────────────────────────────────────────────────────
ON_CONFLICT="ask"
BACKUP=false
DRY_RUN=false
FORCE=false

usage() {
    cat <<EOF
${BOLD}Usage:${NC} $0 [OPTIONS]

Update custom-caelestia configs. Only updates sections that are installed.

${BOLD}Options:${NC}
  ${CYAN}--on-conflict${NC} <m>  How to handle file conflicts (default: ask)
                          ${GREEN}ask${NC}      - Prompt for each conflict
                          ${GREEN}replace${NC}  - Always replace with repo version
                          ${GREEN}keep${NC}     - Always keep your local version
                          ${GREEN}backup${NC}   - Backup local, then replace
                          ${GREEN}new${NC}      - Save repo as .new, keep local
  ${CYAN}--backup${NC}           Create safety backups before deploying
  ${CYAN}--dry-run${NC}          Show what would be updated without making changes
  ${CYAN}--force${NC}             Force update — skip mtime check, replace all files
  ${CYAN}--non-interactive${NC}  Skip prompts (replace on conflict)
  ${CYAN}-h, --help${NC}        Show this help
EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --on-conflict)    ON_CONFLICT="${2:-ask}"; shift 2 ;;
            --on-conflict=*)  ON_CONFLICT="${1#*=}"; shift ;;
            --backup)         BACKUP=true; shift ;;
            --dry-run)        DRY_RUN=true; shift ;;
            --force)          FORCE=true; shift ;;
            --non-interactive) ON_CONFLICT="replace"; shift ;;
            -h|--help)        usage ;;
            *)                warn "Unknown option: $1"; shift ;;
        esac
    done
    case "$ON_CONFLICT" in
        ask|replace|keep|backup|new) ;;
        *) err "Invalid --on-conflict: $ON_CONFLICT" ;;
    esac
}

# ── .updateignore ─────────────────────────────────────────────────────────────
declare -a IGNORE_PATTERNS=()

load_ignore_patterns() {
    IGNORE_PATTERNS=()

    local ignore_files=(
        "$MERGED_DIR/.updateignore"
        "$HOME/.updateignore"
        "$HOME/.config/hypr/.updateignore"
        "$HOME/.config/quickshell/.updateignore"
        "$HOME/.config/quickshell/caelestia/.updateignore"
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
    local matched=false
    for pattern in "${IGNORE_PATTERNS[@]}"; do
        local negated=false
        local pat="$pattern"
        [[ "$pat" == "!"* ]] && { negated=true; pat="${pat#!}"; }

        # Absolute path patterns match against the full target path
        if [[ "$pat" == /* ]]; then
            if [[ "$full_path" == "$pat" ]]; then
                [[ "$negated" == "true" ]] && matched=false || matched=true
            fi
            continue
        fi

        if match_gitignore "$rel_path" "$pat"; then
            [[ "$negated" == "true" ]] && matched=false || matched=true
        fi
    done
    [[ "$matched" == "true" ]] && return 0
    return 1
}

match_gitignore() {
    local path="$1" pattern="$2"

    if [[ "$pattern" == $'\*\*' ]]; then
        return 0
    fi

    if [[ "$pattern" == $'\*\*'/* ]]; then
        local rest="${pattern#'**/'}"
        [[ "$path" == "$rest" || "$path" == */"$rest" || "$path" == */"$rest"/* ]] && return 0
        return 1
    fi

    if [[ "$pattern" == */$'\*\*' ]]; then
        local prefix="${pattern%'/**'}"
        [[ "$path" == "$prefix"/* || "$path" == "$prefix" ]] && return 0
        return 1
    fi

    if [[ "$pattern" == */$'\*\*'/* ]]; then
        local prefix="${pattern%'/**/*'}"
        local suffix="${pattern##*'/\*\*/'}"
        [[ "$path" == "$prefix"/"$suffix" || "$path" == "$prefix"/*"$suffix" || "$path" == "$prefix"/*/*"$suffix" ]] && return 0
        return 1
    fi

    [[ "$pattern" == */ ]] && {
        local dir="${pattern%/}"
        [[ "$path" == "$dir" || "$path" == "$dir"/* ]] && return 0
        return 1
    }

    [[ "$path" == $pattern ]] && return 0
    [[ "$path" == */"$pattern" ]] && return 0

    local base
    base=$(basename "$pattern")
    [[ "$base" == $pattern ]] && {
        [[ "$(basename "$path")" == $pattern ]] && return 0
    }

    return 1
}

# ── Section detection ────────────────────────────────────────────────────────
# Detect which sections are installed by checking if target dirs exist.

detect_sections() {
    SECTION_HYPRLAND=false
    SECTION_SHELL_EXTRAS=false
    SECTION_QUICKSHELL=false

    [[ -d "$HOME/.config/hypr/hyprland" ]] && SECTION_HYPRLAND=true
    [[ -d "$HOME/.config/quickshell/caelestia" && ! -L "$HOME/.config/quickshell/caelestia" ]] && SECTION_QUICKSHELL=true
    [[ -d "$HOME/.config/fish" ]] && SECTION_SHELL_EXTRAS=true
}

# ── Conflict handling ────────────────────────────────────────────────────────
handle_conflict() {
    local repo_file="$1" home_file="$2"
    local action="${3:-$ON_CONFLICT}"

    if [[ "$action" != "ask" ]]; then
        case "$action" in
            replace) cp -p "$repo_file" "$home_file"; log "Replaced: $home_file" ;;
            keep)    echo -e "  ${BLUE}Kept:${NC} $home_file" ;;
            backup)
                local dir base
                dir=$(dirname "$home_file"); base=$(basename "$home_file")
                mv "$home_file" "${dir}/${base}.old"
                cp -p "$repo_file" "$home_file"
                log "Backed up → ${base}.old, replaced" ;;
            new)
                local dir base
                dir=$(dirname "$home_file"); base=$(basename "$home_file")
                cp -p "$repo_file" "${dir}/${base}.new"
                echo -e "  ${YELLOW}Saved:${NC} repo as ${base}.new, kept local" ;;
        esac
        return
    fi

    # Interactive prompt
    echo ""
    echo -e "${YELLOW}┌─ Conflict:${NC} ${BOLD}$home_file${NC}"
    echo -e "${YELLOW}│${NC}  Repository version differs from your local file."
    while true; do
        echo -e "${YELLOW}└─${NC} Choose:"
        echo "  ${GREEN}1${NC}) Replace with repo version"
        echo "  ${GREEN}2${NC}) Keep local file"
        echo "  ${GREEN}3${NC}) Backup → .old, then replace"
        echo "  ${GREEN}4${NC}) Save repo as .new, keep local"
        echo "  ${GREEN}5${NC}) Show diff"
        echo "  ${GREEN}6${NC}) Skip"
        echo "  ${GREEN}7${NC}) Add to .updateignore & skip"
        local choice
        read -p "  → " choice < /dev/tty
        case "$choice" in
            1) handle_conflict "$repo_file" "$home_file" "replace"; break ;;
            2) handle_conflict "$repo_file" "$home_file" "keep"; break ;;
            3) handle_conflict "$repo_file" "$home_file" "backup"; break ;;
            4) handle_conflict "$repo_file" "$home_file" "new"; break ;;
            5) echo ""; diff -u "$home_file" "$repo_file" || true; echo "" ;;
            6) echo -e "  ${BLUE}Skipped:${NC} $home_file"; break ;;
            7)
                local ignore_file="$HOME/.updateignore"
                echo "$home_file" >> "$ignore_file"
                IGNORE_PATTERNS+=("$home_file")
                echo -e "  ${GREEN}Ignored:${NC} added '$home_file' to ~/.updateignore"
                break
                ;;
            *) echo -e "  ${RED}Invalid. Enter 1-7.${NC}" ;;
        esac
    done
}

# ── Safe deploy: merge repo into target ──────────────────────────────────────
# Only updates files that haven't been modified by the user.
# Reads .updateignore to skip user-customized files.
deploy_dir() {
    local src="$1" dst="$2"
    shift 2
    local find_excludes=("$@")

    mkdir -p "$dst"

    find "$src" -type f "${find_excludes[@]}" 2>/dev/null | while IFS= read -r repo_file; do
        local rel="${repo_file#"$src"/}"
        local target="$dst/$rel"

        # Skip ignored files
        if should_ignore "$rel" "$target"; then
            continue
        fi

        mkdir -p "$(dirname "$target")"

        if [[ -f "$target" ]]; then
            # File exists — check if it changed
            if ! cmp -s "$repo_file" "$target" 2>/dev/null; then
                # Force mode — always replace without asking
                if [[ "$FORCE" == "true" ]]; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo -e "  ${BLUE}[dry-run]${NC} Would replace: $target"
                        continue
                    fi
                    cp -p "$repo_file" "$target"
                else
                    # Check if user modified it (target newer than repo)
                    local repo_mtime target_mtime
                    repo_mtime=$(stat -c %Y "$repo_file" 2>/dev/null || echo 0)
                    target_mtime=$(stat -c %Y "$target" 2>/dev/null || echo 0)

                    if [[ "$target_mtime" -gt "$repo_mtime" ]]; then
                        # User modified — handle conflict
                        if [[ "$DRY_RUN" == "true" ]]; then
                            echo -e "  ${YELLOW}[dry-run]${NC} Would conflict: $target"
                            continue
                        fi
                        handle_conflict "$repo_file" "$target"
                    else
                        # Repo changed, target not modified — safe to update
                        if [[ "$DRY_RUN" == "true" ]]; then
                            echo -e "  ${BLUE}[dry-run]${NC} Would update: $target"
                            continue
                        fi
                        cp -p "$repo_file" "$target"
                    fi
                fi
            fi
        else
            # New file — copy it
            if [[ "$DRY_RUN" == "true" ]]; then
                echo -e "  ${BLUE}[dry-run]${NC} Would create: $target"
                continue
            fi
            cp -p "$repo_file" "$target"
        fi
    done
}

# ── Section deployers ────────────────────────────────────────────────────────

update_hyprland() {
    log "Updating Hyprland config..."

    deploy_dir "$MERGED_DIR/hyprland/.config/hypr" "$HOME/.config/hypr"

    # Caelestia config — never touch shell.json
    if [[ -d "$MERGED_DIR/hyprland/.config/caelestia" ]]; then
        mkdir -p "$HOME/.config/caelestia"
        find "$MERGED_DIR/hyprland/.config/caelestia" -type f | while IFS= read -r f; do
            local rel="${f#"$MERGED_DIR/hyprland/.config/caelestia/"}"
            local target="$HOME/.config/caelestia/$rel"
            [[ "$rel" == "shell.json" || "$rel" == "shell.json.bak" ]] && continue
            if should_ignore "$rel" "$target"; then continue; fi
            mkdir -p "$(dirname "$target")"
            if [[ -f "$target" ]]; then
                if ! cmp -s "$f" "$target" 2>/dev/null; then
                    local repo_mtime target_mtime
                    repo_mtime=$(stat -c %Y "$f" 2>/dev/null || echo 0)
                    target_mtime=$(stat -c %Y "$target" 2>/dev/null || echo 0)
                    if [[ "$target_mtime" -le "$repo_mtime" ]]; then
                        [[ "$DRY_RUN" == "true" ]] && { echo -e "  ${BLUE}[dry-run]${NC} Would update: $target"; continue; }
                        cp -p "$f" "$target"
                    fi
                fi
            else
                [[ "$DRY_RUN" == "true" ]] && { echo -e "  ${BLUE}[dry-run]${NC} Would create: $target"; continue; }
                cp -p "$f" "$target"
            fi
        done
    fi

    # Systemd
    if [[ -d "$MERGED_DIR/hyprland/.config/systemd" ]]; then
        deploy_dir "$MERGED_DIR/hyprland/.config/systemd/user" "$HOME/.config/systemd/user"
        [[ "$DRY_RUN" != "true" ]] && systemctl --user daemon-reload 2>/dev/null || true
    fi

    # XDG portal
    if [[ -d "$MERGED_DIR/hyprland/.config/xdg-desktop-portal" ]]; then
        deploy_dir "$MERGED_DIR/hyprland/.config/xdg-desktop-portal" "$HOME/.config/xdg-desktop-portal"
    fi

    # Permissions
    [[ "$DRY_RUN" != "true" ]] && {
        chmod +x "$HOME/.config/hypr/hyprland/scripts/"* &>/dev/null || true
        chmod +x "$HOME/.config/hypr/hyprland/scripts/ai/"* &>/dev/null || true
    }

    log "Hyprland config updated."
}

update_shell_extras() {
    log "Updating shell extras..."

    # Fish
    if [[ -d "$MERGED_DIR/configs/.config/fish" ]]; then
        deploy_dir "$MERGED_DIR/configs/.config/fish" "$HOME/.config/fish"
    fi

    # Starship
    if [[ -f "$MERGED_DIR/configs/.config/starship.toml" ]]; then
        local target="$HOME/.config/starship.toml"
        if [[ -f "$target" ]]; then
            if ! cmp -s "$MERGED_DIR/configs/.config/starship.toml" "$target" 2>/dev/null; then
                local repo_mtime target_mtime
                repo_mtime=$(stat -c %Y "$MERGED_DIR/configs/.config/starship.toml" 2>/dev/null || echo 0)
                target_mtime=$(stat -c %Y "$target" 2>/dev/null || echo 0)
                if [[ "$target_mtime" -le "$repo_mtime" ]]; then
                    [[ "$DRY_RUN" != "true" ]] && cp -p "$MERGED_DIR/configs/.config/starship.toml" "$target"
                fi
            fi
        else
            [[ "$DRY_RUN" != "true" ]] && cp -p "$MERGED_DIR/configs/.config/starship.toml" "$target"
        fi
    fi

    # App configs
    local app_configs=(btop cava kitty foot fuzzel wlogout fontconfig)
    for app in "${app_configs[@]}"; do
        if [[ -d "$MERGED_DIR/configs/.config/$app" ]]; then
            deploy_dir "$MERGED_DIR/configs/.config/$app" "$HOME/.config/$app"
        fi
    done

    # fish-guide
    if [[ -f "$MERGED_DIR/configs/.local/share/bin/fish-guide" ]]; then
        local target="$HOME/.local/share/bin/fish-guide"
        mkdir -p "$HOME/.local/share/bin"
        if [[ ! -f "$target" ]] || ! cmp -s "$MERGED_DIR/configs/.local/share/bin/fish-guide" "$target" 2>/dev/null; then
            [[ "$DRY_RUN" != "true" ]] && {
                cp -p "$MERGED_DIR/configs/.local/share/bin/fish-guide" "$target"
                chmod +x "$target"
            }
        fi
    fi

    log "Shell extras updated."
}

update_quickshell() {
    log "Updating Quickshell config..."

    # Handle symlinks
    local dst="$HOME/.config/quickshell/caelestia"
    if [[ -L "$dst" ]]; then
        log "Removing symlink: $dst"
        [[ "$DRY_RUN" != "true" ]] && rm -f "$dst"
    fi

    deploy_dir "$MERGED_DIR/shell" "$dst" \
        -not -path "*/build/*" -not -path "*/upstream/*"

    # Symlink scripts
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$dst/scripts"
        ln -sf "$MERGED_DIR/update.sh" "$dst/scripts/update.sh"
        ln -sf "$MERGED_DIR/install.sh" "$dst/scripts/install.sh"

        # Permissions
        chmod +x "$dst/scripts/"* &>/dev/null || true
    fi

    log "Quickshell config updated."
}

update_plugin() {
    log "Checking for C++ plugin source changes..."
    local plugin_src="$MERGED_DIR/shell/plugin/src"
    local build_dir="$MERGED_DIR/build"
    local stamp_file="$build_dir/.plugin_build_stamp"
    local plugin_changed=false

    if [[ -d "$plugin_src" ]]; then
        if [[ "$FORCE" == "true" ]]; then
            plugin_changed=true
        elif [[ ! -f "$stamp_file" ]]; then
            plugin_changed=true
        elif find "$plugin_src" -type f \( -name "*.hpp" -o -name "*.cpp" \) -newer "$stamp_file" 2>/dev/null | grep -q .; then
            plugin_changed=true
        fi
    fi

    if [[ "$plugin_changed" == "true" ]]; then
        log "Plugin source changed — rebuilding..."
        [[ "$DRY_RUN" == "true" ]] && { echo -e "  ${BLUE}[dry-run]${NC} Would rebuild plugin"; return; }

        [[ -d "$build_dir" ]] && sudo rm -rf "$build_dir"
        mkdir -p "$build_dir"
        cmake -B "$build_dir" -S "$MERGED_DIR" -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DENABLE_MODULES="plugin;m3shapes" || {
            warn "cmake configuration failed. Check that cmake and ninja are installed."
            return
        }
        cmake --build "$build_dir" -j"$(nproc 2>/dev/null || echo 4)" || {
            warn "Plugin build failed. See output above for details."
            return
        }

        local INSTALL_DIR="/usr/lib/qt6/qml"
        sudo cmake --install "$build_dir" --prefix / || {
            warn "cmake --install failed, falling back to manual copy..."
            if [[ -d "$build_dir/qml/Caelestia" ]]; then
                sudo mkdir -p "$INSTALL_DIR/Caelestia"
                sudo cp -r "$build_dir/qml/Caelestia/"* "$INSTALL_DIR/Caelestia/"
                sudo chmod -R a+rX "$INSTALL_DIR/Caelestia/"
            else
                warn "No built plugin found at $build_dir/qml/Caelestia"
                return
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
                    sudo mkdir -p "$INSTALL_DIR/M3Shapes"
                    sudo cp -r "$build_dir/qml/M3Shapes/"* "$INSTALL_DIR/M3Shapes/"
                    sudo chmod -R a+rX "$INSTALL_DIR/M3Shapes/"
                else
                    warn "M3Shapes build output not found at $build_dir/qml/M3Shapes"
                fi
            }
            # Ensure world-readable regardless of how it was installed
            sudo chmod -R a+rX "$INSTALL_DIR/M3Shapes/" 2>/dev/null || true
        fi

        touch "$stamp_file"
        log "Plugin rebuilt and installed."
    else
        log "Plugin source unchanged — skipping rebuild."
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    # ── Sudo check ─────────────────────────────────────────────────────
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root. Run ./update.sh as a normal user instead —"
        warn "the script will ask for sudo when needed."
        exit 1
    fi
    log "Checking sudo access... (you may be prompted)"
    sudo -v || err "sudo required."

    echo "═══════════════════════════════════════════════════════════════"
    echo "  Updating custom-caelestia"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    load_ignore_patterns

    # Detect installed sections
    detect_sections

    if [[ "$SECTION_HYPRLAND" == "true" ]]; then
        log "Detected: Hyprland config"
    else
        warn "Not found: Hyprland config (~/.config/hypr/hyprland) — skipping"
    fi
    if [[ "$SECTION_QUICKSHELL" == "true" ]]; then
        log "Detected: Quickshell config"
    else
        warn "Not found: Quickshell config (~/.config/quickshell/caelestia) — skipping"
    fi
    if [[ "$SECTION_SHELL_EXTRAS" == "true" ]]; then
        log "Detected: Shell extras (fish)"
    else
        warn "Not found: Shell extras (~/.config/fish) — skipping"
    fi
    echo ""

    # Git pull (if in a repo)
    if [[ -d "$MERGED_DIR/.git" ]]; then
        cd "$MERGED_DIR"
        log "Fetching latest changes..."
        git fetch origin 2>/dev/null || warn "Failed to fetch from origin."

        local stash=false
        if ! git diff --quiet || ! git diff --cached --quiet; then
            log "Stashing local changes..."
            git stash push -m "auto-stash before update" &>/dev/null
            stash=true
        fi

        local current_branch
        current_branch=$(git branch --show-current)
        log "Pulling latest on '$current_branch'..."
        git pull origin "$current_branch" --no-rebase 2>/dev/null || warn "Failed to pull automatically."

        if [[ "$stash" == "true" ]]; then
            log "Restoring stashed changes..."
            git stash pop &>/dev/null || warn "Failed to pop stash"
        fi
        echo ""
    fi

    # Safety backup
    if [[ "$BACKUP" == "true" && "$DRY_RUN" != "true" ]]; then
        local ts
        ts=$(date +%Y%m%d%H%M%S)
        local dirs=()
        [[ "$SECTION_HYPRLAND" == "true" ]] && dirs+=("$HOME/.config/hypr")
        [[ "$SECTION_QUICKSHELL" == "true" ]] && dirs+=("$HOME/.config/quickshell/caelestia")
        [[ "$SECTION_SHELL_EXTRAS" == "true" ]] && dirs+=("$HOME/.config/fish" "$HOME/.config/btop" "$HOME/.config/cava" "$HOME/.config/kitty" "$HOME/.config/foot" "$HOME/.config/fuzzel" "$HOME/.config/wlogout")
        for d in "${dirs[@]}"; do
            if [[ -d "$d" ]]; then
                local backup_dir="${d}.bak.${ts}"
                log "Backing up $(basename "$d") → $(basename "$backup_dir")"
                cp -r "$d" "$backup_dir"
            fi
        done
        echo ""
    fi

    # Update installed sections
    [[ "$SECTION_HYPRLAND" == "true" ]] && update_hyprland
    [[ "$SECTION_SHELL_EXTRAS" == "true" ]] && update_shell_extras
    [[ "$SECTION_QUICKSHELL" == "true" ]] && update_quickshell

    # Plugin rebuild (only if quickshell section is installed)
    [[ "$SECTION_QUICKSHELL" == "true" ]] && update_plugin

    # Reload Hyprland
    if [[ "$DRY_RUN" != "true" ]] && command -v hyprctl &>/dev/null && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        log "Reloading Hyprland..."
        hyprctl reload &>/dev/null || true
    fi

    echo ""
    log "Update complete!"
}

main "$@"
exit 0
