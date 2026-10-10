# Unified Setup Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge `install.sh` + `update.sh` into one entry point (`install.sh`) with a single deploy path, manifest-based stale pruning, and one incremental plugin-build flow; `update.sh` becomes a compat stub.

**Architecture:** One bash script with a MODE dispatcher (`install|update|check|build|menu`). All config deployment goes through one `deploy_tree` (merge of old `safe_deploy` + `deploy_dir`) which records written files into a per-root `.deploy-manifest` (`rel\tmtime` lines). After each root deploys, `prune_stale` deletes manifest entries no longer produced by the repo unless the user modified them. `update.sh` is a 3-line `exec` stub so the deployed `scripts/update.sh` symlink and Nexus's hardcoded calls keep working.

**Tech Stack:** Bash 4+ (assoc arrays, process substitution), git, cmake/ninja for the plugin build. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-10-unified-setup-script-design.md`

## Global Constraints

- `set -euo pipefail` throughout; the `--check` command must survive non-zero returns (if-condition exemption, as in old `update.sh:580-586`).
- Nexus contract (must not break): `update.sh --check` prints `REPO_DIR=`, `BRANCH=`, `AHEAD=`, `BEHIND=`, `DIRTY=`, `PLUGINS_STALE=` and exits 0/1/2; `install.sh --non-interactive --no-install` deploys all configs with zero prompts and no sudo.
- Bare flags with no command (`--non-interactive`, `--backup`, `--dry-run`, `--on-conflict X`, `--force`) default to MODE=update (old update.sh dialect).
- `--non-interactive` sets both `NON_INTERACTIVE=true` and `ON_CONFLICT=replace`.
- Never deploy: `build/`, `upstream/`, `plugin/` (find excludes, defined once as `DEPLOY_EXCLUDES`), plus `.git*`.
- Never touch `shell.json`/`shell.json.bak` in `~/.config/caelestia/`.
- Prune must never delete: `.updateignore`d paths, files absent from the manifest, files whose mtime differs from the manifest-recorded deploy mtime.
- Preserve `CI_TEST=true` guard so tests can source functions without running anything.
- Keep `install_pkg`, `sudo()` wrapper (approve-all/once/skip), `spin`, colors, `qs_screencopy_present`, `rebuild_quickshell`, `enable_pipewire` from current install.sh unchanged.

---

### Task 1: Unified arg parser, MODE dispatch, `--check` port

**Files:**
- Modify: `install.sh` (replace flag block lines 8-24; add `cmd_check`, `show_usage`, `parse_args`, `dispatch`; guard main)
- Test: `tests/setup_scripts_test.sh` (new)

**Interfaces:**
- Consumes: nothing new.
- Produces: globals `MODE` (`install|update|check|build|menu`), `ON_CONFLICT`, `BACKUP`, `DRY_RUN`, `FORCE`, `NON_INTERACTIVE`, `NO_INSTALL`, `NO_PRUNE`, `FORCE_REBUILD`, `BUILD_ONLY` (true when `--build` is the command). `cmd_check()` returns 0/1/2. Later tasks call `cmd_update`/`cmd_install`/`cmd_build` (stubs until filled).

- [ ] **Step 1: Write the failing test**

Append to `tests/setup_scripts_test.sh` (create with `#!/usr/bin/env bash` header, `set -uo pipefail` — do NOT `set -e`, scenarios assert exit codes):

```bash
#!/usr/bin/env bash
# Functional tests for the unified install.sh / update.sh stub.
# Runs against scratch HOMEs; never touches the real $HOME.
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok()   { echo "  PASS $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

t_syntax() {
    bash -n "$SCRIPTS_DIR/install.sh" && bash -n "$SCRIPTS_DIR/update.sh" \
        && ok "bash -n both scripts" || bad "bash -n both scripts"
}

t_help() {
    "$SCRIPTS_DIR/install.sh" --help >/dev/null 2>&1 \
        && ok "--help exits 0" || bad "--help exits 0"
}

t_check_shape() {
    local out
    out=$("$SCRIPTS_DIR/install.sh" --check 2>&1) || true
    local k
    for k in REPO_DIR BRANCH AHEAD BEHIND DIRTY PLUGINS_STALE; do
        grep -q "^$k=" <<<"$out" || { bad "--check prints $k"; return; }
    done
    ok "--check prints all KEY=value lines"
}

t_check_exit() {
    "$SCRIPTS_DIR/install.sh" --check >/dev/null 2>&1
    local rc=$?
    [[ "$rc" -eq 0 || "$rc" -eq 1 || "$rc" -eq 2 ]] \
        && ok "--check exit in {0,1,2} (got $rc)" || bad "--check exit in {0,1,2} (got $rc)"
}

t_stub_parity() {
    local a b
    a=$("$SCRIPTS_DIR/install.sh" --check 2>&1) || true
    b=$("$SCRIPTS_DIR/update.sh" --check 2>&1) || true
    [[ "$a" == "$b" ]] && ok "update.sh --check == install.sh --check" \
        || bad "update.sh --check == install.sh --check"
}

t_bare_defaults_update() {
    # --dry-run with no command must take the update path (would-update lines,
    # not the install menu / package installs). Use a scratch HOME.
    local tmp; tmp=$(mktemp -d)
    local out
    out=$(HOME="$tmp" "$SCRIPTS_DIR/install.sh" --update --dry-run --non-interactive 2>&1) || true
    grep -q "Updating" <<<"$out" && ok "--update --dry-run announces update" \
        || bad "--update --dry-run announces update (got: $(head -3 <<<"$out"))"
    rm -rf "$tmp"
}

main() {
    t_syntax; t_help; t_check_shape; t_check_exit; t_stub_parity; t_bare_defaults_update
    echo ""; echo "RESULT: $PASS passed, $FAIL failed"
    [[ "$FAIL" -eq 0 ]]
}
main "$@"
```

- [ ] **Step 2: Run test to verify current state fails**

Run: `bash tests/setup_scripts_test.sh`
Expected: FAIL on `update.sh --check == install.sh --check`? No — old update.sh still owns `--check`; stub parity fails only after Task 6 replaces update.sh. Current failures: `install.sh --help` (no such flag today), `--check` shape on install.sh (not implemented). Record which fail now.

- [ ] **Step 3: Implement parser + dispatch in install.sh**

Replace lines 8-24 (flag block) with:

```bash
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
```

Port `cmd_check` verbatim from **update.sh lines 525-572** into install.sh (rename `MERGED_DIR` → `REPO_DIR` inside it; keep the exact six echo lines and the return 0/1/2 logic). Add dispatch at the bottom, replacing the current main body's entry (keep the existing interactive-install `while true` loop code as-is for now — it becomes the `cmd_install` body in Task 4; for this task wrap it minimally):

At the bottom of install.sh, replace the `if [[ "${CI_TEST:-false}" != "true" ]]; then` … `fi` outer guard's contents with:

```bash
if [[ "${CI_TEST:-false}" != "true" ]]; then
parse_args "$@"
load_ignore_patterns

case "$MODE" in
    check)
        if cmd_check; then exit 0; else exit $?; fi
        ;;
    install|update|build|menu)
        # Filled in by later tasks; until then keep old behavior for install
        # and fail loudly for the rest.
        if [[ "$MODE" == "install" || "$MODE" == "menu" ]]; then
            : # old interactive flow continues below (Task 4 rewires it)
        else
            err "mode '$MODE' not implemented yet (Task 4/5/6)"
        fi
        ;;
esac

# ── legacy interactive install body (unchanged this task) ─────────────────
# (existing lines 656-772 continue here, minus the old NON_INTERACTIVE
# headless block which Task 4 replaces)
...
fi
```

Move the old headless `--non-interactive` block (current lines 661-691) into a function `cmd_install_headless()` but do not wire it yet — Task 4 does. For this task, keep the interactive loop reachable exactly as today when MODE=install/menu.

- [ ] **Step 4: Run test to verify parser works**

Run: `bash tests/setup_scripts_test.sh`
Expected: `--help`, `--check` shape/exit pass; stub parity still passes (old update.sh untouched); `--update --dry-run` fails (mode not implemented) — that one flips green in Task 6. Commit only if the not-yet-implemented failures are the expected ones.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/setup_scripts_test.sh
git commit -m "feat(scripts): unified arg parser + MODE dispatch + --check port"
```

---

### Task 2: `deploy_tree` (single deploy path) + conflict modes

**Files:**
- Modify: `install.sh` (replace `safe_deploy` lines 134-196, `should_ignore` lines 221-241, `load_ignore_patterns` lines 201-219; add `deploy_tree`, `handle_conflict`, `match_gitignore`; update all `safe_deploy` call sites)
- Test: `tests/setup_scripts_test.sh` (append scenarios)

**Interfaces:**
- Consumes: globals from Task 1 (`ON_CONFLICT`, `DRY_RUN`, `FORCE`, `NON_INTERACTIVE`), `IGNORE_PATTERNS`/`should_ignore`.
- Produces: `deploy_tree(src, dst, [find-excludes...])` — deploys, honors all conflict modes, appends written rel-paths to global array `DEPLOYED_RELS`. `should_ignore(rel_path, full_path)` (gitignore-style superset). `handle_conflict(repo_file, home_file, [action])`.

- [ ] **Step 1: Write the failing tests**

Append scenarios (each uses `CI_TEST=true` sourcing — see note at Step 3):

```bash
# Source install.sh functions without running main
source_scripts() { CI_TEST=true source "$SCRIPTS_DIR/install.sh" 2>/dev/null; }

mk_repo() { # $1 = dir; creates a tiny fake repo tree
    mkdir -p "$1/mods/a" "$1/mods/b"
    echo "v1" > "$1/mods/a/f.txt"
    echo "keep" > "$1/mods/b/g.txt"
}

t_deploy_new_and_update() {
    local tmp src dst; tmp=$(mktemp -d); src=$tmp/repo; dst=$tmp/home
    mk_repo "$src"
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false
        DEPLOYED_RELS=()
        deploy_tree "$src/mods" "$dst"
    )
    [[ -f "$dst/a/f.txt" ]] && ok "deploy creates new files" || bad "deploy creates new files"
    echo "v2" > "$src/mods/a/f.txt"
    touch -d "2020-01-01" "$src/mods/a/f.txt"   # repo older than target
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false
        deploy_tree "$src/mods" "$dst"
    )
    [[ "$(cat "$dst/a/f.txt")" == "v2" ]] && ok "unmodified target updated" \
        || bad "unmodified target updated"
    rm -rf "$tmp"
}

t_conflict_keep_and_replace() {
    local tmp src dst; tmp=$(mktemp -d); src=$tmp/repo; dst=$tmp/home
    mk_repo "$src"
    mkdir -p "$dst"; echo "mine" > "$dst/a/f.txt"
    touch "$dst/a/f.txt"   # newer than repo → user-modified
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false
        deploy_tree "$src/mods" "$dst"
    )
    [[ "$(cat "$dst/a/f.txt")" == "mine" ]] && ok "keep preserves local" \
        || bad "keep preserves local"
    (
        source_scripts
        ON_CONFLICT=replace DRY_RUN=false FORCE=false
        deploy_tree "$src/mods" "$dst"
    )
    [[ "$(cat "$dst/a/f.txt")" == "v1" ]] && ok "replace overwrites local" \
        || bad "replace overwrites local"
    rm -rf "$tmp"
}

t_dry_run_touches_nothing() {
    local tmp src dst; tmp=$(mktemp -d); src=$tmp/repo; dst=$tmp/home
    mk_repo "$src"
    (
        source_scripts
        ON_CONFLICT=replace DRY_RUN=true FORCE=false
        deploy_tree "$src/mods" "$dst"
    )
    [[ ! -e "$dst/a/f.txt" ]] && ok "dry-run creates nothing" \
        || bad "dry-run creates nothing"
    rm -rf "$tmp"
}

t_excludes_respected() {
    local tmp src dst; tmp=$(mktemp -d); src=$tmp/repo; dst=$tmp/home
    mkdir -p "$src/mods/plugin" "$src/mods/ok"
    echo x > "$src/mods/plugin/s.cpp"; echo y > "$src/mods/ok/f.txt"
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false
        deploy_tree "$src/mods" "$dst" -not -path "*/plugin/*"
    )
    [[ ! -e "$dst/plugin/s.cpp" && -f "$dst/ok/f.txt" ]] \
        && ok "find excludes honored" || bad "find excludes honored"
    rm -rf "$tmp"
}
```

Add these calls in `main()` before the summary echo.

**Sourcing note:** install.sh currently calls `load_ignore_patterns` etc. inside the `CI_TEST` guard only for the run path — verify `CI_TEST=true source install.sh` defines functions and returns without executing main (the existing guard at line 658 already does this; keep it). If `err()`'s `exit 1` interferes inside subshell tests, the `( ... )` subshells isolate it.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/setup_scripts_test.sh`
Expected: new scenarios FAIL (`deploy_tree: command not found`).

- [ ] **Step 3: Implement deploy_tree + richer should_ignore**

Port `match_gitignore` **verbatim from update.sh lines 137-179** and `handle_conflict` **verbatim from update.sh lines 195-250** into install.sh. Replace install.sh's `load_ignore_patterns` (lines 201-219) with update.sh's version (lines 91-110), changing `MERGED_DIR` → `REPO_DIR` and keeping update.sh's extra path `"$REPO_DIR/.config/quickshell/caelestia/.updateignore"` as `"$HOME/.config/quickshell/caelestia/.updateignore"`. Replace install.sh's `should_ignore` (lines 221-241) with update.sh's version (lines 112-135) which calls `match_gitignore`.

Add one global above the function:

```bash
DEPLOYED_RELS=()       # rel-paths written/confirmed by the last deploy_tree call
```

Replace `safe_deploy` (lines 134-196) with:

```bash
# ── The one deploy path ──────────────────────────────────────────────────────
# Merges repo → dst. Conflict modes via ON_CONFLICT; DRY_RUN prints only;
# FORCE skips the mtime heuristic. Records managed rel-paths in DEPLOYED_RELS.
# NOTE: uses process substitution (not a pipe) so DEPLOYED_RELS survives.
deploy_tree() {
    local src="$1" dst="$2"
    shift 2
    local find_excludes=("$@")
    DEPLOYED_RELS=()
    mkdir -p "$dst"

    local repo_file rel target repo_mtime target_mtime
    while IFS= read -r repo_file; do
        rel="${repo_file#"$src"/}"
        target="$dst/$rel"
        DEPLOYED_RELS+=("$rel")

        should_ignore "$rel" "$target" && continue
        mkdir -p "$(dirname "$target")"

        if [[ ! -f "$target" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "  ${BLUE}[dry-run]${NC} Would create: $target"
                continue
            fi
            cp -p "$repo_file" "$target"
            continue
        fi

        cmp -s "$repo_file" "$target" 2>/dev/null && continue

        if [[ "$FORCE" == true ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "  ${BLUE}[dry-run]${NC} Would replace: $target"
                continue
            fi
            cp -p "$repo_file" "$target"
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
        else
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "  ${YELLOW}[dry-run]${NC} Would conflict: $target"
                continue
            fi
            handle_conflict "$repo_file" "$target"
        fi
    done < <(find "$src" -type f "${find_excludes[@]}" 2>/dev/null)
}
```

Update every call site: `safe_deploy "$src" "$dst"` → `deploy_tree "$src" "$dst"` (lines 440, 461, 467, 494, 510, 537-538). Delete the old `safe_deploy` entirely. Also add `DEPLOY_EXCLUDES` once near the top of the deploy section:

```bash
DEPLOY_EXCLUDES=(-not -path "*/build/*" -not -path "*/upstream/*" -not -path "*/plugin/*")
```

and change the quickshell call (line 537-538) to `deploy_tree "$src" "$dst" "${DEPLOY_EXCLUDES[@]}"`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/setup_scripts_test.sh`
Expected: all previously-passing tests still pass + 4 new scenarios pass.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/setup_scripts_test.sh
git commit -m "feat(scripts): single deploy_tree with conflict modes + gitignore-style ignores"
```

---

### Task 3: Manifest recording + stale pruning

**Files:**
- Modify: `install.sh` (add `manifest_begin`, `manifest_record`, `manifest_finish`, `prune_stale`; call from `deploy_tree` + section deployers)
- Test: `tests/setup_scripts_test.sh` (append scenarios)

**Interfaces:**
- Consumes: `DEPLOYED_RELS` (Task 2), `should_ignore`, `DRY_RUN`, `NO_PRUNE`, `log`/`warn`.
- Produces: `manifest_begin(dst)`, `manifest_finish(dst)` — writes `$dst/.deploy-manifest` with `rel\tmtime` lines and prunes removed sources. Manifest entries never include `.updateignore`d paths.

- [ ] **Step 1: Write the failing tests**

```bash
t_prune_removes_deleted_source() {
    local tmp src dst; tmp=$(mktemp -d); src=$tmp/repo; dst=$tmp/home
    mk_repo "$src"
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false NO_PRUNE=false
        manifest_begin "$dst"
        deploy_tree "$src/mods" "$dst"
        manifest_finish "$dst"
    )
    rm "$src/mods/a/f.txt"          # source deleted from repo
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false NO_PRUNE=false
        manifest_begin "$dst"
        deploy_tree "$src/mods" "$dst"
        manifest_finish "$dst"
    )
    [[ ! -e "$dst/a/f.txt" ]] && ok "prune deletes source-removed file" \
        || bad "prune deletes source-removed file"
    rm -rf "$tmp"
}

t_prune_keeps_user_modified() {
    local tmp src dst; tmp=$(mktemp -d); src=$tmp/repo; dst=$tmp/home
    mk_repo "$src"
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false NO_PRUNE=false
        manifest_begin "$dst"; deploy_tree "$src/mods" "$dst"; manifest_finish "$dst"
    )
    rm "$src/mods/a/f.txt"
    echo "hacked" > "$dst/a/f.txt"  # user touched it after deploy
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false NO_PRUNE=false
        manifest_begin "$dst"; deploy_tree "$src/mods" "$dst"; manifest_finish "$dst"
    )
    [[ -f "$dst/a/f.txt" ]] && ok "prune keeps user-modified file" \
        || bad "prune keeps user-modified file"
    rm -rf "$tmp"
}

t_no_prune_flag() {
    local tmp src dst; tmp=$(mktemp -d); src=$tmp/repo; dst=$tmp/home
    mk_repo "$src"
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false NO_PRUNE=false
        manifest_begin "$dst"; deploy_tree "$src/mods" "$dst"; manifest_finish "$dst"
    )
    rm "$src/mods/a/f.txt"
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false NO_PRUNE=true
        manifest_begin "$dst"; deploy_tree "$src/mods" "$dst"; manifest_finish "$dst"
    )
    [[ -f "$dst/a/f.txt" ]] && ok "--no-prune keeps stale file" \
        || bad "--no-prune keeps stale file"
    rm -rf "$tmp"
}

t_unlisted_never_pruned() {
    local tmp src dst; tmp=$(mktemp -d); src=$tmp/repo; dst=$tmp/home
    mk_repo "$src"
    mkdir -p "$dst"; echo "user own" > "$dst/userfile.txt"  # never deployed
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false NO_PRUNE=false
        manifest_begin "$dst"; deploy_tree "$src/mods" "$dst"; manifest_finish "$dst"
    )
    [[ -f "$dst/userfile.txt" ]] && ok "prune never touches unlisted files" \
        || bad "prune never touches unlisted files"
    rm -rf "$tmp"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/setup_scripts_test.sh` — new scenarios FAIL (`manifest_begin: command not found`).

- [ ] **Step 3: Implement manifest + prune**

Add below `deploy_tree`:

```bash
# ── Deploy manifest: enables safe pruning of repo-deleted files ─────────────
# Format: one "rel<TAB>mtime" line per managed file. mtime is the target's
# stat %Y right after we wrote it — prune deletes only when mtime still
# matches (i.e. the user never touched the file since our deploy).
MANIFEST_PRIOR=""

manifest_begin() {
    local dst="$1"
    MANIFEST_PRIOR=""
    [[ -f "$dst/.deploy-manifest" ]] && MANIFEST_PRIOR="$dst/.deploy-manifest"
}

manifest_finish() {
    local dst="$1"
    if [[ "$DRY_RUN" == true ]]; then
        [[ -n "$MANIFEST_PRIOR" && -f "$MANIFEST_PRIOR" ]] && prune_stale "$dst" "$MANIFEST_PRIOR" || true
        return 0
    fi
    local tmp_manifest="$dst/.deploy-manifest.new"
    : > "$tmp_manifest"
    local rel target
    for rel in ${DEPLOYED_RELS[@]+"${DEPLOYED_RELS[@]}"}; do
        target="$dst/$rel"
        [[ -f "$target" ]] || continue
        should_ignore "$rel" "$target" && continue
        printf '%s\t%s\n' "$rel" "$(stat -c %Y "$target" 2>/dev/null || echo 0)" >> "$tmp_manifest"
    done
    if [[ -n "$MANIFEST_PRIOR" && -f "$MANIFEST_PRIOR" ]]; then
        prune_stale "$dst" "$MANIFEST_PRIOR" "$tmp_manifest"
    fi
    mv "$tmp_manifest" "$dst/.deploy-manifest"
}

# $1=dst $2=prior manifest [$3=current manifest; omit = dry-run]
prune_stale() {
    local dst="$1" prior="$2" current="${3:-}"
    [[ "$NO_PRUNE" == true ]] && return 0

    local p_rel p_mtime target c_rel c_dummy c_found now_mtime
    while IFS=$'\t' read -r p_rel p_mtime; do
        [[ -z "$p_rel" ]] && continue
        # Still produced by this run's deploy? Then nothing to do.
        c_found=false
        if [[ -n "$current" && -f "$current" ]]; then
            while IFS=$'\t' read -r c_rel c_dummy; do
                [[ "$c_rel" == "$p_rel" ]] && { c_found=true; break; }
            done < "$current"
        fi
        [[ "$c_found" == true ]] && continue
        target="$dst/$p_rel"
        [[ -f "$target" ]] || continue
        should_ignore "$p_rel" "$target" && continue
        now_mtime=$(stat -c %Y "$target" 2>/dev/null || echo 0)
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
```

Wire manifest into `deploy_tree`: at the top of `deploy_tree` do NOT call manifest_begin (section deployers own the begin/finish bracket because one root can receive several `deploy_tree` calls — e.g. hyprland root gets hypr + caelestia + systemd + portal as SEPARATE dsts, each with its own manifest). Instead, update section deployers in install.sh:

- `deploy_hyprland` (lines 434-475): wrap each dst:
  - before `deploy_tree "$src" "$dst"` add `manifest_begin "$dst"`; after the call add `manifest_finish "$dst"` (hypr root).
  - caelestia block (lines 444-457): convert the manual find/cp loop into `manifest_begin "$HOME/.config/caelestia"` + a small inline loop that still skips shell.json but appends non-skipped rels to `DEPLOYED_RELS` then `manifest_finish` — simplest: keep the loop, set `DEPLOYED_RELS=()`, inside the loop after a copy (and for already-existing identical files) do `DEPLOYED_RELS+=("$rel")`, then call `manifest_finish "$HOME/.config/caelestia"`. In DRY_RUN mode append rels too but copy nothing.
  - systemd dst and portal dst: same begin/finish bracket.
- `deploy_shell_extras` (lines 477-525): begin/finish around each `deploy_tree` (fish, starship target dir is `$HOME/.config` — do NOT manifest all of `$HOME/.config`; instead record just `starship.toml`: set `DEPLOYED_RELS=("starship.toml")` after copying and call `manifest_begin`/`manifest_finish` with dst=`$HOME/.config` ONLY if you also guard prune to the listed rels — prune already only considers prior-manifest entries, so a `.deploy-manifest` in `$HOME/.config` listing one file is safe. Same for fish-guide with dst=`$HOME/.local/share/bin`.) App-config loop: begin/finish per app dst. 
- `deploy_quickshell` (lines 527-549): begin/finish around its `deploy_tree` call.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/setup_scripts_test.sh` — all green including 4 new prune scenarios.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/setup_scripts_test.sh
git commit -m "feat(scripts): deploy manifest + safe stale-file pruning"
```

---

### Task 4: Unified section deployers (install + update share one implementation)

**Files:**
- Modify: `install.sh` (restructure main: `cmd_install`, `cmd_install_headless`, `cmd_update`, `detect_sections`; delete the now-redundant update-path assumptions)
- Test: `tests/setup_scripts_test.sh` (append scenarios)

**Interfaces:**
- Consumes: `deploy_tree`, `manifest_*` (Tasks 2-3), `parse_args`/`MODE` (Task 1), `install_pkg`, `enable_pipewire`, `qs_screencopy_present`, `rebuild_quickshell`.
- Produces: `cmd_install()`, `cmd_update()`, `detect_sections()` (sets `SECTION_HYPRLAND`, `SECTION_QUICKSHELL`, `SECTION_SHELL_EXTRAS`). `cmd_update` performs: banner → detect → git fetch/stash/pull/pop → optional `--backup` dir backups → section deployers → plugin-if-changed (Task 5) → `hyprctl reload`.

- [ ] **Step 1: Write the failing tests**

```bash
t_headless_install_configs_only() {
    local tmp; tmp=$(mktemp -d)
    HOME="$tmp" "$SCRIPTS_DIR/install.sh" --install --non-interactive --no-install >/dev/null 2>&1
    local rc=$?
    [[ "$rc" -eq 0 ]] && ok "headless --install --no-install exits 0" \
        || bad "headless --install --no-install exits 0 (rc=$rc)"
    [[ -d "$tmp/.config/quickshell/caelestia/modules" ]] \
        && ok "quickshell section deployed" || bad "quickshell section deployed"
    [[ ! -e "$tmp/.config/quickshell/caelestia/plugin" ]] \
        && ok "plugin/ not deployed" || bad "plugin/ not deployed"
    [[ ! -e "$tmp/.config/quickshell/caelestia/upstream" ]] \
        && ok "upstream/ not deployed" || bad "upstream/ not deployed"
    [[ -f "$tmp/.config/quickshell/caelestia/.deploy-manifest" ]] \
        && ok "manifest written" || bad "manifest written"
    rm -rf "$tmp"
}

t_update_skips_uninstalled() {
    local tmp; tmp=$(mktemp -d)   # empty HOME: nothing installed
    HOME="$tmp" "$SCRIPTS_DIR/install.sh" --update --non-interactive --dry-run >/dev/null 2>&1
    local rc=$?
    [[ "$rc" -eq 0 ]] && ok "update on empty HOME exits 0" || bad "update on empty HOME exits 0 (rc=$rc)"
    rm -rf "$tmp"
}

t_update_after_install() {
    local tmp; tmp=$(mktemp -d)
    HOME="$tmp" "$SCRIPTS_DIR/install.sh" --install --non-interactive --no-install >/dev/null 2>&1
    echo "local edit" > "$tmp/.config/hypr/hyprland/CUSTOM_EDIT_MARKER"
    HOME="$tmp" "$SCRIPTS_DIR/install.sh" --update --non-interactive >/dev/null 2>&1
    [[ -f "$tmp/.config/hypr/hyprland/CUSTOM_EDIT_MARKER" ]] \
        && ok "update preserves user-created files" || bad "update preserves user-created files"
    rm -rf "$tmp"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/setup_scripts_test.sh` — new scenarios FAIL (`--install` still runs the old flow that needs sudo / doesn't deploy to scratch HOME correctly; `--update` errors "not implemented").

- [ ] **Step 3: Implement cmd_install / cmd_update / detect_sections**

Port `detect_sections` **verbatim from update.sh lines 184-192**. Port the git pull block **from update.sh lines 630-652** into a function `git_pull_latest()` (`MERGED_DIR` → `REPO_DIR`). Port the backup block **from update.sh lines 655-670** into `backup_targets()` using the `SECTION_*` globals.

Restructure the bottom of install.sh:

```bash
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

    [[ "$SECTION_HYPRLAND" == true ]] && deploy_hyprland
    [[ "$SECTION_SHELL_EXTRAS" == true ]] && deploy_shell_extras
    [[ "$SECTION_QUICKSHELL" == true ]] && deploy_quickshell

    [[ "$SECTION_QUICKSHELL" == true ]] && build_plugin_if_changed

    if [[ "$DRY_RUN" != true ]] && command -v hyprctl &>/dev/null && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        log "Reloading Hyprland..."
        hyprctl reload &>/dev/null || true
    fi
    log "Update complete!"
}

cmd_install_interactive() {
    # Existing section-toggle menu + loop (current lines 702-771), with the
    # inner install actions replaced by:
    #   deploy_core; screencopy check; SEL-gated deploy_*; build_plugin;
    #   keybind footer (unchanged text).
    ...
}
```

Replace the dispatch case from Task 1:

```bash
case "$MODE" in
    check)   if cmd_check; then exit 0; else exit $?; fi ;;
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
    menu)    show_top_menu ;;
esac
exit 0
```

Add `show_top_menu` (Install / Update / Check / Build / Quit loop) that sets `MODE` and breaks to the dispatch. Delete the old headless block (lines 661-691) and the old "MODE not implemented" err stub. Note: `deploy_hyprland` currently deploys packages-free config only in the update path but `deploy_shell_extras` calls `install_pkg` for fish/etc. — gate those package installs on `NO_INSTALL` (they already are: `install_pkg` no-ops when `NO_INSTALL=true`; for `cmd_update` set a local `NO_INSTALL` guard by saving/restoring: in `cmd_update`, run with packages skipped — simplest: `local saved_no_install=$NO_INSTALL; NO_INSTALL=true; ...; NO_INSTALL=$saved_no_install` around the deploy calls, since update must never install packages).

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/setup_scripts_test.sh` — all green. Manually sanity-check the interactive path still opens: `./install.sh` (menu renders; Ctrl-C out).

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/setup_scripts_test.sh
git commit -m "feat(scripts): cmd_install/cmd_update share one section-deployer path"
```

---

### Task 5: One incremental plugin build

**Files:**
- Modify: `install.sh` (replace `build_plugin` lines 605-654; add `build_plugin_if_changed`, `cmd_build`)
- Test: `tests/setup_scripts_test.sh` (append scenario)

**Interfaces:**
- Consumes: `DRY_RUN`, `FORCE_REBUILD`, `BUILD_CMD`, `sudo()`.
- Produces: `build_plugin()` (incremental; `--force-rebuild` wipes `build/` first; touches `build/.plugin_build_stamp`), `build_plugin_if_changed()` (stamp/newer check from update.sh:456-464; skips with log when unchanged), `cmd_build()`.

- [ ] **Step 1: Write the failing test**

```bash
t_build_dry_run() {
    local out
    out=$("$SCRIPTS_DIR/install.sh" --build --dry-run --non-interactive 2>&1) || true
    grep -qi "rebuild\|build" <<<"$out" && ok "--build --dry-run mentions rebuild" \
        || bad "--build --dry-run mentions rebuild (got: $out)"
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/setup_scripts_test.sh` — `cmd_build: command not found` (or old flow tries real build).

- [ ] **Step 3: Implement consolidated build**

Replace `build_plugin` (lines 605-654) with:

```bash
# ── C++ plugin build (one flow for install/update/build) ─────────────────────
# Incremental by default; --force-rebuild wipes build/ first. No unconditional
# sudo rm -rf. M3Shapes FetchContent install kept from the old dual paths.
build_plugin() {
    local build_dir="$REPO_DIR/build"
    if [[ "$FORCE_REBUILD" == true && -d "$build_dir" && "$DRY_RUN" != true ]]; then
        log "Clean rebuild requested — wiping build dir..."
        rm -rf "$build_dir"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${BLUE}[dry-run]${NC} Would rebuild + install C++ plugin"
        return 0
    fi
    log "Building C++ plugin..."
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
        sudo chmod -R a+rX "$install_dir/M3Shapes/" 2>/dev/null || true
    fi
    touch "$build_dir/.plugin_build_stamp"
    log "Plugin installed."
}

build_plugin_if_changed() {
    if [[ "$BUILD_CMD" != true && "$FORCE" != true ]]; then
        # update without --build: only rebuild when sources are newer than stamp
        local stamp="$REPO_DIR/build/.plugin_build_stamp"
        if [[ -f "$stamp" ]] && ! find "$REPO_DIR/shell/plugin/src" -type f \
            \( -name "*.hpp" -o -name "*.cpp" \) -newer "$stamp" 2>/dev/null | grep -q .; then
            log "Plugin source unchanged — skipping rebuild (use --build to force)."
            return 0
        fi
    fi
    build_plugin
}

cmd_build() {
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root. Run as a normal user instead."
        exit 1
    fi
    if [[ "$DRY_RUN" != true ]]; then
        log "Checking sudo access... (you may be prompted)"
        sudo -v || err "sudo required."
    fi
    build_plugin
}
```

Semantics note (matches spec): `--update` alone calls `build_plugin_if_changed` which rebuilds only when sources are newer than the stamp; `--update --build` (BUILD_CMD=true) always rebuilds; `--build` as a command always rebuilds; `--force-rebuild` additionally wipes. `cmd_install` keeps calling `build_plugin` directly (fresh installs always build).

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/setup_scripts_test.sh` — `t_build_dry_run` green; others unchanged.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/setup_scripts_test.sh
git commit -m "feat(scripts): one incremental plugin-build flow, drop sudo rm -rf"
```

---

### Task 6: `update.sh` stub, README/AGENTS docs, full regression

**Files:**
- Modify: `update.sh` (replace all 691 lines with the stub)
- Modify: `README.md` (flags/install-update sections)
- Modify: `AGENTS.md` (Install & Update Scripts section)
- Test: `tests/setup_scripts_test.sh` (full run)

**Interfaces:**
- Consumes: everything Tasks 1-5.
- Produces: final CLI; `t_stub_parity` and `t_bare_defaults_update` from Task 1 go green.

- [ ] **Step 1: Replace update.sh with the stub**

```bash
#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Compat stub — all logic lives in install.sh now (unified setup script).
# Kept so deployed ~/.config/quickshell/caelestia/scripts/update.sh symlinks
# and the Nexus Updates page keep working unchanged.
# ═══════════════════════════════════════════════════════════════════════════
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install.sh" "$@"
```

- [ ] **Step 2: Add the bare-flags test from Task 1 green + regression**

Run: `bash tests/setup_scripts_test.sh` — ALL scenarios green now, including `t_stub_parity` and `t_bare_defaults_update`. If `t_bare_defaults_update` fails because scratch-HOME update prints "Not found" warns but not "Updating", adjust the grep to `Updating custom-caelestia` (the banner) instead of bare `Updating`.

- [ ] **Step 3: Update README.md**

Find the install/update usage sections (search for `--on-conflict`, `update.sh`, `install.sh` examples around lines 51, 105-119) and rewrite to document the unified surface: bare `./install.sh` menu; `--install` / `--update` / `--check` / `--build`; the shared flags table from `show_usage`; note that `update.sh` is a compat stub; note manifest pruning (`.deploy-manifest`, `--no-prune`).

- [ ] **Step 4: Update AGENTS.md**

Replace the "Install & Update Scripts" section (lines ~149-167) with a concise version: one script, command table, `.deploy-manifest` pruning, stub note, `.updateignore` unchanged.

- [ ] **Step 5: Manual scratch-HOME end-to-end**

```bash
tmp=$(mktemp -d)
HOME=$tmp ./install.sh --install --non-interactive --no-install
HOME=$tmp ./install.sh --update --non-interactive --dry-run | tail -5
HOME=$tmp ./install.sh --check; echo "exit=$?"
./update.sh --check | head -3
rm -rf "$tmp"
```

Expected: install deploys all four sections into scratch HOME with manifest; update dry-run lists would-actions and would-prunes; check prints KEY=value lines; stub output matches.

- [ ] **Step 6: Full test suite + commit**

Run: `bash tests/setup_scripts_test.sh` AND the existing guard tests (`bash tests/qml_ram_cpu_test.sh && bash tests/qml_eco_powersaver_test.sh`) — all green.

```bash
git add update.sh README.md AGENTS.md tests/setup_scripts_test.sh install.sh
git commit -m "feat(scripts): unified setup script; update.sh becomes compat stub"
```

---

## Self-Review Notes

- Spec coverage: CLI table → Task 1; deploy_tree → Task 2; manifest/prune → Task 3; section unification + update orchestration → Task 4; build → Task 5; stub + docs + Nexus contract verification → Task 6 (+ Task 1 `cmd_check`).
- One spec deviation, intentional: `--backup` on install backs up section targets via the same `backup_targets` used by update (spec table says "any command").
- `cmd_update` runs deploys with `NO_INSTALL=true` forced (update must never install packages) — spec non-goal #1 upheld.
