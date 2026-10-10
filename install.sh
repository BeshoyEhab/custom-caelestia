#!/usr/bin/env bash
# custom-caelestia Installer
# Interactive installer with 3 optional config sections
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Options ───────────────────────────────────────────────────────────────────
MODE=""                # install | update | check | build | menu ("" → resolve later)
ON_CONFLICT="ask"
BACKUP=false
DRY_RUN=false
FORCE=false
NON_INTERACTIVE=false
NO_INSTALL=false
VERBOSE=false
REBUILD_QS=false
NO_PRUNE=false
FORCE_REBUILD=false
BUILD_CMD=false        # true when --build given as a command

show_usage() {
    cat <<EOF
${BOLD}Usage:${NC} $(basename "$0") [COMMAND] [OPTIONS]

Commands (default with no command + no flags: interactive menu):
  ${CYAN}--install${NC}   Full install: packages + configs + plugin
  ${CYAN}--update${NC}    Update deployed configs (auto-detects installed sections)
  ${CYAN}--check${NC}     Read-only status (prints REPO_DIR/BRANCH/AHEAD/BEHIND/DIRTY/PLUGINS_STALE;
                 exit 0 = up to date, 1 = updates, 2 = error)
  ${CYAN}--build${NC}     Rebuild + install the C++ plugin only

Options:
  ${CYAN}--on-conflict${NC} <m>  ask (default) | replace | keep | backup | new
  ${CYAN}--backup${NC}           Timestamped backup of targets before deploy
  ${CYAN}--dry-run${NC}          Print actions; change nothing (not even manifests)
  ${CYAN}--force${NC}            Skip mtime check; replace differing files
  ${CYAN}--force-rebuild${NC}    Clean-build the plugin (wipes build dir)
  ${CYAN}--no-prune${NC}         Never delete stale deployed files
  ${CYAN}--no-install${NC}       Skip packages + plugin build (configs only)
  ${CYAN}--non-interactive${NC}  No prompts; implies --on-conflict replace
  ${CYAN}--rebuild-quickshell${NC} Force Quickshell source rebuild (screencopy)
  ${CYAN}-v, --verbose${NC}      Show real command output
  ${CYAN}-h, --help${NC}         Show this help

Bare flags with no command (e.g. --non-interactive alone) default to --update.
EOF
    exit 0
}

parse_args() {
    local cmd_seen=false flag_seen=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install)           MODE="install"; cmd_seen=true; shift ;;
            --update)            MODE="update"; cmd_seen=true; shift ;;
            --check)             MODE="check"; cmd_seen=true; shift ;;
            --build)             MODE="build"; BUILD_CMD=true; cmd_seen=true; shift ;;
            --on-conflict)       ON_CONFLICT="${2:-ask}"; flag_seen=true; shift 2 ;;
            --on-conflict=*)     ON_CONFLICT="${1#*=}"; flag_seen=true; shift ;;
            --backup)            BACKUP=true; flag_seen=true; shift ;;
            --dry-run)           DRY_RUN=true; flag_seen=true; shift ;;
            --force)             FORCE=true; flag_seen=true; shift ;;
            --force-rebuild)     FORCE_REBUILD=true; flag_seen=true; shift ;;
            --no-prune)          NO_PRUNE=true; flag_seen=true; shift ;;
            --no-install)        NO_INSTALL=true; flag_seen=true; shift ;;
            --non-interactive)   NON_INTERACTIVE=true; ON_CONFLICT="replace"; flag_seen=true; shift ;;
            --rebuild-quickshell) REBUILD_QS=true; flag_seen=true; shift ;;
            -v|--verbose)        VERBOSE=true; flag_seen=true; shift ;;
            -h|--help)           show_usage ;;
            *)                   warn "Unknown option: $1"; flag_seen=true; shift ;;
        esac
    done
    # Bare flags (old update.sh dialect) default to update mode.
    if [[ -z "$MODE" ]]; then
        if [[ "$cmd_seen" == true ]]; then
            MODE="menu"   # unreachable; cmd_seen implies MODE set
        elif [[ "$flag_seen" == true ]]; then
            MODE="update"
        else
            MODE="menu"
        fi
    fi
    case "$ON_CONFLICT" in
        ask|replace|keep|backup|new) ;;
        *) err "Invalid --on-conflict: $ON_CONFLICT" ;;
    esac
}

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

# ── Sudo wrapper: show command, ask for confirmation ONCE ────────────────────
# The prompt/confirmation ALWAYS goes to the terminal (/dev/tty) so it stays
# visible even when the rest of the command output is redirected/spinnered.
# Skipped entirely in --non-interactive mode (no prompts for GUI integration).
# First invocation asks: [Y] approve all sudo for this run (default), [o] just
# this once, [n] skip. Later invocations only echo the command and run it.
SUDO_APPROVED=false
sudo() {
    if [[ "$NON_INTERACTIVE" == true || "$SUDO_APPROVED" == true ]]; then
        command sudo "$@"
        return
    fi
    printf '  >> sudo %s\n' "$*" >/dev/tty
    printf '  %brun? [Y=yes to all, o=once, n=skip] %b ' "$CYAN" "$NC" >/dev/tty
    read -r _confirm < /dev/tty
    case "${_confirm,,}" in
        n*) return 1 ;;
        o*) ;; # once: run this command, ask again next time
        *) SUDO_APPROVED=true ;; # default (empty/Y): approve all for this run
    esac
    command sudo "$@"
}

# ── Package installation ─────────────────────────────────────────────────────
# Verbose (-v): run the command live so real output streams to the terminal.
# Otherwise: background + spinner so nothing feels dead; failures dump the log.
install_pkg() {
    local pkg="$1" is_aur="${2:-false}" logfile ok
    if [[ "$NO_INSTALL" == true ]]; then
        log "Skipped (no-install): $pkg"
        return 0
    fi
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

# ── .updateignore ─────────────────────────────────────────────────────────────
declare -a IGNORE_PATTERNS=()

load_ignore_patterns() {
    IGNORE_PATTERNS=()

    local ignore_files=(
        "$REPO_DIR/.updateignore"
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

# ── Conflict handling ────────────────────────────────────────────────────────
# Sets CONFLICT_WROTE=true only on paths that actually overwrite the target
# (replace/backup); keep/new/skip leave it false so the manifest keeps the
# prior mtime and a user-edited file is never re-blessed as ours.
CONFLICT_WROTE=false
handle_conflict() {
    local repo_file="$1" home_file="$2"
    local action="${3:-$ON_CONFLICT}"
    CONFLICT_WROTE=false

    if [[ "$action" != "ask" ]]; then
        case "$action" in
            replace) cp -p "$repo_file" "$home_file"; CONFLICT_WROTE=true; log "Replaced: $home_file" ;;
            keep)    echo -e "  ${BLUE}Kept:${NC} $home_file" ;;
            backup)
                local dir base
                dir=$(dirname "$home_file"); base=$(basename "$home_file")
                mv "$home_file" "${dir}/${base}.old"
                cp -p "$repo_file" "$home_file"
                CONFLICT_WROTE=true
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
        read -r -p "  → " choice < /dev/tty
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

# ── The one deploy path ──────────────────────────────────────────────────────
# Merges repo → dst. Conflict modes via ON_CONFLICT; DRY_RUN prints only;
# FORCE skips the mtime heuristic. Records managed rel-paths in DEPLOYED_RELS.
# NOTE: uses process substitution (not a pipe) so DEPLOYED_RELS survives.
DEPLOYED_RELS=()       # rel-paths written/confirmed by the last deploy_tree call
DEPLOYED_WRITTEN=()    # subset of those we actually (over)wrote THIS run
DEPLOY_EXCLUDES=(-not -path "*/build/*" -not -path "*/upstream/*" -not -path "*/plugin/*")
deploy_tree() {
    local src="$1" dst="$2"
    shift 2
    local find_excludes=("$@")
    DEPLOYED_RELS=()
    DEPLOYED_WRITTEN=()
    [[ "$DRY_RUN" != true ]] && mkdir -p "$dst"

    local repo_file rel target repo_mtime target_mtime
    while IFS= read -r repo_file; do
        rel="${repo_file#"$src"/}"
        target="$dst/$rel"

        should_ignore "$rel" "$target" && continue
        DEPLOYED_RELS+=("$rel")
        [[ "$DRY_RUN" != true ]] && mkdir -p "$(dirname "$target")"

        if [[ ! -f "$target" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "  ${BLUE}[dry-run]${NC} Would create: $target"
                continue
            fi
            cp -p "$repo_file" "$target"
            DEPLOYED_WRITTEN+=("$rel")
            continue
        fi

        cmp -s "$repo_file" "$target" 2>/dev/null && continue

        if [[ "$FORCE" == true ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "  ${BLUE}[dry-run]${NC} Would replace: $target"
                continue
            fi
            cp -p "$repo_file" "$target"
            DEPLOYED_WRITTEN+=("$rel")
            continue
        fi

        repo_mtime=$(stat -c %Y "$repo_file" 2>/dev/null || echo 0)
        target_mtime=$(stat -c %Y "$target" 2>/dev/null || echo 0)
        if [[ "$target_mtime" -le "$repo_mtime" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "  ${BLUE}[dry-run]${NC} Would update: $target"
                continue
            fi
            cp -p "$repo_file" "$target"
            DEPLOYED_WRITTEN+=("$rel")
        else
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "  ${YELLOW}[dry-run]${NC} Would conflict: $target"
                continue
            fi
            handle_conflict "$repo_file" "$target"
            if [[ "$CONFLICT_WROTE" == true ]]; then
                DEPLOYED_WRITTEN+=("$rel")
            fi
        fi
    done < <(find "$src" -type f "${find_excludes[@]}" 2>/dev/null)
}

# ── Deploy manifest: enables safe pruning of repo-deleted files ─────────────
# Format: one "rel<TAB>mtime" line per managed file. mtime is the target's
# stat %y (nanosecond precision) right after we wrote it — prune deletes only
# when mtime still matches (i.e. the user never touched the file since our
# deploy). NOTE: %y, not %Y — second granularity would treat a same-second
# user edit as "untouched" and prune it, breaking prune safety.
MANIFEST_PRIOR=""

manifest_begin() {
    local dst="$1"
    MANIFEST_PRIOR=""
    # NOTE: if, not `[[ ]] &&` — the latter would make the function return 1
    # when there is no prior manifest, which aborts callers under `set -e`.
    if [[ -f "$dst/.deploy-manifest" ]]; then
        MANIFEST_PRIOR="$dst/.deploy-manifest"
    fi
}

manifest_finish() {
    local dst="$1"
    if [[ "$DRY_RUN" == true ]]; then
        # Dry-run: never write/overwrite the manifest. Prune only reports;
        # membership falls back to DEPLOYED_RELS when no current file exists.
        [[ -n "$MANIFEST_PRIOR" && -f "$MANIFEST_PRIOR" ]] && prune_stale "$dst" "$MANIFEST_PRIOR" || true
        return 0
    fi
    [[ -d "$dst" ]] || return 0
    local tmp_manifest="$dst/.deploy-manifest.new"
    : > "$tmp_manifest"

    # Prior manifest indexed by rel. mtime source per rel: fresh stat only for
    # files we actually wrote THIS run; kept/identical files carry the prior
    # record forward (first sighting gets a baseline stat). Otherwise a
    # user-edited file's NEW mtime would be re-blessed as ours here, and a
    # later prune would delete it silently when the source disappears.
    local -A prior_map=()
    if [[ -n "$MANIFEST_PRIOR" && -f "$MANIFEST_PRIOR" ]]; then
        local pr_rel pr_mtime
        while IFS=$'\t' read -r pr_rel pr_mtime; do
            [[ -z "$pr_rel" ]] && continue
            prior_map["$pr_rel"]="$pr_mtime"
        done < "$MANIFEST_PRIOR"
    fi

    local rel target w written mtime
    for rel in ${DEPLOYED_RELS[@]+"${DEPLOYED_RELS[@]}"}; do
        target="$dst/$rel"
        [[ -f "$target" ]] || continue
        should_ignore "$rel" "$target" && continue
        written=false
        for w in ${DEPLOYED_WRITTEN[@]+"${DEPLOYED_WRITTEN[@]}"}; do
            [[ "$w" == "$rel" ]] && { written=true; break; }
        done
        if [[ "$written" == true || -z "${prior_map[$rel]+x}" ]]; then
            mtime=$(stat -c %y "$target" 2>/dev/null || echo 0)
        else
            mtime="${prior_map[$rel]}"
        fi
        printf '%s\t%s\n' "$rel" "$mtime" >> "$tmp_manifest"
    done
    if [[ -n "$MANIFEST_PRIOR" && -f "$MANIFEST_PRIOR" ]]; then
        prune_stale "$dst" "$MANIFEST_PRIOR" "$tmp_manifest"
    fi
    mv "$tmp_manifest" "$dst/.deploy-manifest"
}

# $1=dst $2=prior manifest [$3=current manifest; omit = membership from DEPLOYED_RELS]
prune_stale() {
    local dst="$1" prior="$2" current="${3:-}"
    [[ "$NO_PRUNE" == true ]] && return 0
    [[ -f "$prior" ]] || return 0

    local p_rel p_mtime target c_rel c_dummy c_found now_mtime
    while IFS=$'\t' read -r p_rel p_mtime; do
        [[ -z "$p_rel" ]] && continue
        # Still produced by this run's deploy? Then nothing to do.
        c_found=false
        if [[ -n "$current" && -f "$current" ]]; then
            while IFS=$'\t' read -r c_rel c_dummy; do
                [[ "$c_rel" == "$p_rel" ]] && { c_found=true; break; }
            done < "$current"
        else
            # No current-manifest file (dry-run): DEPLOYED_RELS is still
            # populated by deploy_tree (and manual section loops).
            for c_rel in ${DEPLOYED_RELS[@]+"${DEPLOYED_RELS[@]}"}; do
                [[ "$c_rel" == "$p_rel" ]] && { c_found=true; break; }
            done
        fi
        [[ "$c_found" == true ]] && continue
        target="$dst/$p_rel"
        [[ -f "$target" ]] || continue
        should_ignore "$p_rel" "$target" && continue
        now_mtime=$(stat -c %y "$target" 2>/dev/null || echo 0)
        if [[ "$now_mtime" != "$p_mtime" ]]; then
            warn "Keeping user-modified stale file: $target"
            continue
        fi
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "  ${BLUE}[dry-run]${NC} Would prune: $target"
        else
            rm -f "$target"
            log "Pruned stale: $target"
        fi
    done < "$prior"
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
        "Hyprland, QuickShell, caelestia-cli, build tools, fonts"
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
    # Caelestia CLI (wallpaper, scheme, record commands)
    install_pkg caelestia-cli true
    # Hardware control
    install_pkg ddcutil
    install_pkg brightnessctl
    install_pkg lm_sensors
    # Audio visualiser & beat detection
    install_pkg libcava true
    install_pkg aubio
    install_pkg libpulse
    install_pkg pipewire
    install_pkg pipewire-pulse
    install_pkg fftw
    # System
    install_pkg networkmanager
    install_pkg wireplumber
    install_pkg upower
    install_pkg geoclue
    # Portals (file chooser, screenshare; config shipped in hyprland section)
    install_pkg xdg-desktop-portal
    install_pkg xdg-desktop-portal-hyprland
    # Keyboard layout database (Nexus keyboard page reads base.xml)
    install_pkg xkeyboard-config
    # Qt/QML runtime
    install_pkg qt6-base
    install_pkg qt6-declarative
    install_pkg qt6-wayland
    install_pkg qt6-svg
    install_pkg qt6-shadertools
    # Wayland protocols (needed for quickshell screencopy rebuilds)
    install_pkg wayland
    install_pkg wayland-protocols
    install_pkg libdrm
    install_pkg mesa
    # Tools the shell uses
    install_pkg swappy
    install_pkg libqalculate
    install_pkg wl-clipboard
    install_pkg cliphist
    install_pkg copyq
    install_pkg jq
    install_pkg xdg-user-dirs
    install_pkg playerctl
    install_pkg bc
    install_pkg libxml2
    install_pkg wtype
    install_pkg curl
    # Screenshots / capture (keybinds depend on these)
    install_pkg grim
    install_pkg slurp
    install_pkg hyprpicker
    install_pkg hyprshot
    install_pkg tesseract
    install_pkg gpu-screen-recorder
    install_pkg emote true
    # Video wallpaper backend (mpvpaper; QS Video is the fallback)
    install_pkg mpvpaper true
    # Launcher helper (app2unit -- terminal wrapping)
    install_pkg app2unit-git true
    # Fonts
    install_pkg ttf-cascadia-code-nerd
    install_pkg ttf-material-symbols-variable
    # Build tools (for C++ plugin + quickshell rebuilds)
    install_pkg cmake
    install_pkg ninja
    install_pkg pkgconf
    install_pkg git
    install_pkg vulkan-headers
    install_pkg spirv-tools
    install_pkg cli11
    install_pkg jemalloc

    enable_pipewire
}

# ── PipeWire user services ───────────────────────────────────────────────────
# Packages alone don't produce sound: PipeWire runs as per-user systemd units.
# Skipped with --no-install so headless GUI deploys stay side-effect free.
enable_pipewire() {
    if [[ "$NO_INSTALL" == true ]]; then
        return 0
    fi
    if [[ $EUID -eq 0 ]]; then
        warn "Skipping PipeWire user services (running as root)."
        return 0
    fi
    if ! command -v systemctl &>/dev/null; then
        return 0
    fi
    if [[ -z "${XDG_RUNTIME_DIR:-}" || ! -d "$XDG_RUNTIME_DIR/systemd" ]]; then
        warn "No user systemd session; enable PipeWire manually:"
        warn "  systemctl --user enable --now pipewire pipewire-pulse wireplumber"
        return 0
    fi
    log "Enabling PipeWire user services..."
    systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || {
        warn "Could not enable PipeWire services; run manually:"
        warn "  systemctl --user enable --now pipewire pipewire-pulse wireplumber"
    }
}

deploy_hyprland() {
    log "Deploying Hyprland config..."
    local src="$REPO_DIR/hyprland/.config/hypr"
    local dst="$HOME/.config/hypr"

    if [[ -d "$src" ]]; then
        manifest_begin "$dst"
        deploy_tree "$src" "$dst"
        manifest_finish "$dst"
    fi

    # Caelestia config (shell.json etc.) — always preserve shell.json
    if [[ -d "$REPO_DIR/hyprland/.config/caelestia" ]]; then
        local csrc="$REPO_DIR/hyprland/.config/caelestia"
        local cdst="$HOME/.config/caelestia"
        [[ "$DRY_RUN" != true ]] && mkdir -p "$cdst"
        manifest_begin "$cdst"
        DEPLOYED_RELS=()
        DEPLOYED_WRITTEN=()
        local f rel target
        while IFS= read -r f; do
            rel="${f#"$csrc"/}"
            target="$cdst/$rel"
            # Never overwrite shell.json — it's user-specific
            [[ "$rel" == "shell.json" || "$rel" == "shell.json.bak" ]] && continue
            if should_ignore "$rel" "$target"; then continue; fi
            if [[ ! -f "$target" ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    echo -e "  ${BLUE}[dry-run]${NC} Would create: $target"
                else
                    mkdir -p "$(dirname "$target")"
                    cp -p "$f" "$target"
                    DEPLOYED_WRITTEN+=("$rel")
                fi
            fi
            DEPLOYED_RELS+=("$rel")
        done < <(find "$csrc" -type f 2>/dev/null)
        manifest_finish "$cdst"
    fi

    # Systemd services
    if [[ -d "$REPO_DIR/hyprland/.config/systemd" ]]; then
        manifest_begin "$HOME/.config/systemd/user"
        deploy_tree "$REPO_DIR/hyprland/.config/systemd/user" "$HOME/.config/systemd/user"
        manifest_finish "$HOME/.config/systemd/user"
        systemctl --user daemon-reload 2>/dev/null || true
    fi

    # XDG Desktop Portal
    if [[ -d "$REPO_DIR/hyprland/.config/xdg-desktop-portal" ]]; then
        manifest_begin "$HOME/.config/xdg-desktop-portal"
        deploy_tree "$REPO_DIR/hyprland/.config/xdg-desktop-portal" "$HOME/.config/xdg-desktop-portal"
        manifest_finish "$HOME/.config/xdg-desktop-portal"
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
        manifest_begin "$HOME/.config/fish"
        deploy_tree "$REPO_DIR/configs/.config/fish" "$HOME/.config/fish"
        manifest_finish "$HOME/.config/fish"
    fi

    # Starship prompt — single-file dst: the manifest in ~/.config records
    # only starship.toml, so pruning can never touch anything else there.
    manifest_begin "$HOME/.config"
    DEPLOYED_RELS=()
    DEPLOYED_WRITTEN=()
    if [[ -f "$REPO_DIR/configs/.config/starship.toml" ]]; then
        local starship_target="$HOME/.config/starship.toml"
        if [[ ! -f "$starship_target" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "  ${BLUE}[dry-run]${NC} Would create: $starship_target"
            else
                mkdir -p "$HOME/.config"
                cp -p "$REPO_DIR/configs/.config/starship.toml" "$starship_target"
                DEPLOYED_WRITTEN+=("starship.toml")
                log "  Starship config deployed."
            fi
        fi
        DEPLOYED_RELS=("starship.toml")
    fi
    manifest_finish "$HOME/.config"

    # App configs: btop, cava, kitty, foot, fuzzel, wlogout, fontconfig
    local app_configs=(btop cava kitty foot fuzzel wlogout fontconfig nvim)
    for app in "${app_configs[@]}"; do
        if [[ -d "$REPO_DIR/configs/.config/$app" ]]; then
            manifest_begin "$HOME/.config/$app"
            deploy_tree "$REPO_DIR/configs/.config/$app" "$HOME/.config/$app"
            manifest_finish "$HOME/.config/$app"
        fi
    done

    # Fish-guide binary — single-file dst: manifest records only fish-guide.
    manifest_begin "$HOME/.local/share/bin"
    DEPLOYED_RELS=()
    DEPLOYED_WRITTEN=()
    if [[ -f "$REPO_DIR/configs/.local/share/bin/fish-guide" ]]; then
        local fish_guide_target="$HOME/.local/share/bin/fish-guide"
        if [[ ! -f "$fish_guide_target" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "  ${BLUE}[dry-run]${NC} Would create: $fish_guide_target"
            else
                mkdir -p "$HOME/.local/share/bin"
                cp -p "$REPO_DIR/configs/.local/share/bin/fish-guide" "$fish_guide_target"
                DEPLOYED_WRITTEN+=("fish-guide")
                chmod +x "$fish_guide_target"
                log "  fish-guide installed."
            fi
        fi
        DEPLOYED_RELS=("fish-guide")
    fi
    manifest_finish "$HOME/.local/share/bin"

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

    manifest_begin "$dst"
    deploy_tree "$src" "$dst" "${DEPLOY_EXCLUDES[@]}"
    manifest_finish "$dst"

    # Symlink install/update scripts for settings app
    mkdir -p "$dst/scripts"
    ln -sf "$REPO_DIR/update.sh" "$dst/scripts/update.sh"
    ln -sf "$REPO_DIR/install.sh" "$dst/scripts/install.sh"

    # Set permissions on scripts
    chmod +x "$dst/scripts/"* &>/dev/null || true

    log "Quickshell config deployed."
}

# ── Quickshell screencopy check & rebuild ────────────────────────────────────
# ScreencopyView (area picker, workspace overview, lock screen) lives inside
# Quickshell's own Wayland/_Screencopy QML module. If the installed quickshell
# was built without it, overview/picker render nothing. This detects that case
# and offers a scripted source rebuild with screencopy enabled (see BUILD.md
# in the quickshell repo for the full dependency list).
qs_screencopy_present() {
    local qmldirs=()
    if command -v qtpaths6 &>/dev/null; then
        qmldirs+=("$(qtpaths6 --query QT_INSTALL_QML 2>/dev/null)")
    fi
    qmldirs+=("/usr/lib/qt6/qml" "/usr/local/lib/qt6/qml")
    local d
    for d in "${qmldirs[@]}"; do
        [[ -n "$d" && -d "$d/Quickshell/Wayland/_Screencopy" ]] && return 0
    done
    return 1
}

rebuild_quickshell() {
    log "Rebuilding Quickshell from source (screencopy enabled)..."
    local src="${QUICKSHELL_SRC:-$HOME/quickshell}"
    if [[ ! -d "$src" ]]; then
        git clone https://git.outfoxxed.me/outfoxxed/quickshell "$src" || {
            warn "quickshell clone failed."
            return 1
        }
    else
        log "Updating existing checkout at $src ..."
        git -C "$src" pull --ff-only || warn "git pull failed, building current checkout."
    fi
    cmake -GNinja -B "$src/build" -S "$src" \
        -DCMAKE_BUILD_TYPE=Release \
        -DDISTRIBUTOR="custom-caelestia" || {
        warn "quickshell cmake configure failed."
        return 1
    }
    cmake --build "$src/build" -j"$(nproc 2>/dev/null || echo 4)" || {
        warn "quickshell build failed."
        return 1
    }
    log "Installing quickshell (needs sudo)..."
    sudo cmake --install "$src/build" || {
        warn "quickshell install failed."
        return 1
    }
    if qs_screencopy_present; then
        log "Screencopy module present."
    else
        warn "Screencopy module still missing after rebuild."
        return 1
    fi
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

# TODO(Task 5): replace with real incremental build logic
build_plugin_if_changed() {
    log "Plugin rebuild deferred (Task 5)."
}

# ── Read-only status check for GUI integration ───────────────────────────────
# Machine-readable output, no side effects (no fetch, no file changes).
# Exit: 0 = up to date, 1 = updates available, 2 = error.
cmd_check() {
    [[ -d "$REPO_DIR/.git" ]] || {
        echo "REPO_DIR=$REPO_DIR"
        echo "ERROR=not a git repository"
        return 2
    }

    local branch remote_sha ahead behind dirty stale
    branch=$(git -C "$REPO_DIR" branch --show-current 2>/dev/null || echo "unknown")

    # Remote tip without fetching (read-only). Fall back to the last-fetched
    # remote-tracking ref when offline or when the branch has no upstream.
    remote_sha=$(git -C "$REPO_DIR" ls-remote origin "$branch" 2>/dev/null | awk '{print $1}')
    if [[ -n "$remote_sha" ]]; then
        ahead=$(git -C "$REPO_DIR" rev-list --count "$remote_sha"..HEAD 2>/dev/null || echo 0)
        behind=$(git -C "$REPO_DIR" rev-list --count HEAD.."$remote_sha" 2>/dev/null || echo 0)
    else
        ahead=$(git -C "$REPO_DIR" rev-list --count '@{u}'..HEAD 2>/dev/null || echo 0)
        behind=$(git -C "$REPO_DIR" rev-list --count HEAD..'@{u}' 2>/dev/null || echo 0)
    fi

    if [[ -n "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]]; then
        dirty=true
    else
        dirty=false
    fi

    local stamp_file="$REPO_DIR/build/.plugin_build_stamp"
    if [[ ! -f "$stamp_file" ]]; then
        stale=true
    elif [[ -n "$(find "$REPO_DIR/shell/plugin/src" -type f \( -name "*.hpp" -o -name "*.cpp" \) -newer "$stamp_file" 2>/dev/null)" ]]; then
        stale=true
    else
        stale=false
    fi

    echo "REPO_DIR=$REPO_DIR"
    echo "BRANCH=$branch"
    echo "AHEAD=$ahead"
    echo "BEHIND=$behind"
    echo "DIRTY=$dirty"
    echo "PLUGINS_STALE=$stale"

    if [[ "$behind" != "0" || "$stale" == "true" ]]; then
        return 1
    fi
    return 0
}

# ── Section detection (ported from update.sh) ────────────────────────────────
# Detect which sections are installed by checking if target dirs exist.
detect_sections() {
    SECTION_HYPRLAND=false
    SECTION_SHELL_EXTRAS=false
    SECTION_QUICKSHELL=false

    [[ -d "$HOME/.config/hypr/hyprland" ]] && SECTION_HYPRLAND=true
    [[ -d "$HOME/.config/quickshell/caelestia" && ! -L "$HOME/.config/quickshell/caelestia" ]] && SECTION_QUICKSHELL=true
    [[ -d "$HOME/.config/fish" ]] && SECTION_SHELL_EXTRAS=true
    # explicit 0: an empty HOME must not abort the caller under `set -e`
    return 0
}

# ── Git pull (ported from update.sh) ─────────────────────────────────────────
git_pull_latest() {
    if [[ -d "$REPO_DIR/.git" ]]; then
        cd "$REPO_DIR"
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
}

# ── Safety backup (ported from update.sh) ────────────────────────────────────
backup_targets() {
    if [[ "$BACKUP" == "true" && "$DRY_RUN" != "true" ]]; then
        local ts
        ts=$(date +%Y%m%d%H%M%S)
        local dirs=()
        [[ "$SECTION_HYPRLAND" == "true" ]] && dirs+=("$HOME/.config/hypr")
        [[ "$SECTION_QUICKSHELL" == "true" ]] && dirs+=("$HOME/.config/quickshell/caelestia")
        [[ "$SECTION_SHELL_EXTRAS" == "true" ]] && dirs+=("$HOME/.config/fish" "$HOME/.config/btop" "$HOME/.config/cava" "$HOME/.config/kitty" "$HOME/.config/foot" "$HOME/.config/fuzzel" "$HOME/.config/wlogout" "$HOME/.config/nvim")
        for d in "${dirs[@]}"; do
            if [[ -d "$d" ]]; then
                local backup_dir="${d}.bak.${ts}"
                log "Backing up $(basename "$d") → $(basename "$backup_dir")"
                cp -a "$d" "$backup_dir"
            fi
        done
        echo ""
    fi
}

# ── Commands ─────────────────────────────────────────────────────────────────
# Headless install (Nexus "Deploy configurations"): --no-install additionally
# skips packages, the plugin build, and the sudo check, so the run needs no
# tty and always works headless from the settings app.
cmd_install() {
    if [[ "$NO_INSTALL" != true ]]; then
        if [[ $EUID -eq 0 ]]; then
            warn "Running as root. Run as a normal user — the script will ask for sudo when needed."
            exit 1
        fi
        log "Checking sudo access... (you may be prompted)"
        sudo -v || err "sudo required."
        deploy_core
    fi

    deploy_hyprland
    deploy_shell_extras
    deploy_quickshell

    if [[ "$NO_INSTALL" != true ]]; then
        build_plugin
        if [[ "$REBUILD_QS" == true ]]; then
            rebuild_quickshell
        elif ! qs_screencopy_present; then
            warn "Quickshell screencopy module not found (overview/picker will be broken)."
            warn "Re-run with --rebuild-quickshell to rebuild it from source."
        fi
    fi
    log "Deployment complete!"
}

cmd_update() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Updating custom-caelestia"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    detect_sections
    [[ "$SECTION_HYPRLAND" == true ]] && log "Detected: Hyprland config" || warn "Not found: Hyprland config (~/.config/hypr/hyprland) — skipping"
    [[ "$SECTION_QUICKSHELL" == true ]] && log "Detected: Quickshell config" || warn "Not found: Quickshell config (~/.config/quickshell/caelestia) — skipping"
    [[ "$SECTION_SHELL_EXTRAS" == true ]] && log "Detected: Shell extras (fish)" || warn "Not found: Shell extras (~/.config/fish) — skipping"
    echo ""

    [[ -d "$REPO_DIR/.git" ]] && git_pull_latest
    [[ "$BACKUP" == true ]] && backup_targets

    # Update never installs packages: force NO_INSTALL for the deployers only
    # (plugin-if-changed and the reload below run regardless).
    local saved_no_install=$NO_INSTALL
    NO_INSTALL=true
    [[ "$SECTION_HYPRLAND" == true ]] && deploy_hyprland
    [[ "$SECTION_SHELL_EXTRAS" == true ]] && deploy_shell_extras
    [[ "$SECTION_QUICKSHELL" == true ]] && deploy_quickshell
    NO_INSTALL=$saved_no_install

    [[ "$SECTION_QUICKSHELL" == true ]] && build_plugin_if_changed

    if [[ "$DRY_RUN" != true ]] && command -v hyprctl &>/dev/null && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        log "Reloading Hyprland..."
        hyprctl reload &>/dev/null || true
    fi
    log "Update complete!"
}

cmd_install_interactive() {
    while true; do
        show_menu
        read -r -p "Enter choice(s) (e.g. 2 3) or press Enter to install: " input

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
                    read -r -p "Press Enter to continue..." _
                    break
                    ;;
                [Ii])
                    show_summary
                    read -r -p "Proceed with installation? [Y/n]: " confirm
                    [[ "${confirm,,}" == "n" ]] && break

                    echo ""
                    c_cyan "Starting installation..."
                    echo ""

                    deploy_core
                    if [[ "$REBUILD_QS" == true ]]; then
                        rebuild_quickshell
                    elif ! qs_screencopy_present; then
                        warn "Quickshell screencopy module not found (overview/picker will be broken)."
                        read -r -p "Rebuild Quickshell from source now? [Y/n]: " _rb
                        if [[ "${_rb,,}" != "n" ]]; then rebuild_quickshell; fi
                    fi
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
}

show_top_menu() {
    while true; do
        clear 2>/dev/null || true
        c_cyan "╔════════════════════════════════════════════════════════════════╗"
        c_cyan "║                 custom-caelestia setup                          ║"
        c_cyan "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        c_yellow "  [1] Install  - packages + configs + plugin"
        c_yellow "  [2] Update   - refresh deployed configs"
        c_yellow "  [3] Check    - read-only repo status"
        c_yellow "  [4] Build    - rebuild the C++ plugin"
        c_yellow "  [5] Quit"
        echo ""
        local choice
        read -r -p "  → " choice || exit 0
        case "$choice" in
            1|i|I) MODE="install"; return 0 ;;
            2|u|U) MODE="update"; return 0 ;;
            3|c|C) MODE="check"; return 0 ;;
            4|b|B) MODE="build"; return 0 ;;
            5|q|Q) c_yellow "Cancelled."; exit 0 ;;
            *) warn "Invalid choice: $choice" ;;
        esac
    done
}

# ── Main ──────────────────────────────────────────────────────────────────────
# If CI_TEST=true, only define functions, don't run the installer
if [[ "${CI_TEST:-false}" != "true" ]]; then
parse_args "$@"
load_ignore_patterns

if [[ "$MODE" == "menu" ]]; then
    show_top_menu
fi

case "$MODE" in
    check)
        # (if-condition is exempt from set -e, so the 1/2 codes survive.)
        if cmd_check; then exit 0; else exit $?; fi
        ;;
    install)
        if [[ "$NON_INTERACTIVE" == true ]]; then cmd_install; else
            # interactive: root/sudo check then section menu
            [[ $EUID -eq 0 ]] && { warn "Run as a normal user."; exit 1; }
            sudo -v || err "sudo required."
            cmd_install_interactive
        fi
        ;;
    update)  cmd_update ;;
    build)   cmd_build ;;   # Task 5
esac
exit 0
fi
