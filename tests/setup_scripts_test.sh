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
    touch -d "2020-01-01" "$dst/a/f.txt"   # target older than repo (unmodified since deploy)
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
    mkdir -p "$dst/a"; echo "mine" > "$dst/a/f.txt"
    touch -d "2030-01-01" "$dst/a/f.txt"   # strictly newer than repo → user-modified
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
    [[ ! -e "$dst" && ! -e "$dst/a/f.txt" ]] && ok "dry-run creates nothing" \
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

t_prune_keeps_file_edited_before_redeploy() {
    local tmp src dst out; tmp=$(mktemp -d); src=$tmp/repo; dst=$tmp/home
    mk_repo "$src"
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false NO_PRUNE=false
        manifest_begin "$dst"; deploy_tree "$src/mods" "$dst"; manifest_finish "$dst"
    )
    echo "hacked" > "$dst/a/f.txt"
    touch -d "2030-01-01" "$dst/a/f.txt"  # newer than repo → conflict-kept, not rewritten
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false NO_PRUNE=false
        manifest_begin "$dst"; deploy_tree "$src/mods" "$dst"; manifest_finish "$dst"
    )
    rm "$src/mods/a/f.txt"          # source deleted from repo
    out=$(
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false NO_PRUNE=false
        manifest_begin "$dst"; deploy_tree "$src/mods" "$dst"; manifest_finish "$dst"
    )
    grep -q "Keeping user-modified stale file" <<<"$out" \
        && ok "prune warns on conflict-kept edited file" \
        || bad "prune warns on conflict-kept edited file"
    [[ -f "$dst/a/f.txt" ]] && ok "prune keeps file edited before re-deploy" \
        || bad "prune keeps file edited before re-deploy"
    rm -rf "$tmp"
}

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

t_update_dry_run_skips_git_pull() {
    local tmp; tmp=$(mktemp -d)
    mkdir -p "$tmp/repo/.git" "$tmp/bin" "$tmp/home"
    cp "$SCRIPTS_DIR/install.sh" "$tmp/repo/install.sh"
    printf '#!/usr/bin/env bash\ntouch "$GIT_STUB_MARKER"\nexit 0\n' > "$tmp/bin/git"
    chmod +x "$tmp/bin/git"
    HOME="$tmp/home" GIT_STUB_MARKER="$tmp/git-was-called" PATH="$tmp/bin:$PATH" \
        "$tmp/repo/install.sh" --update --dry-run --non-interactive >/dev/null 2>&1
    local rc=$?
    [[ "$rc" -eq 0 && ! -e "$tmp/git-was-called" ]] \
        && ok "dry-run update skips git pull" \
        || bad "dry-run update skips git pull (rc=$rc, git stub invoked=$([[ -e "$tmp/git-was-called" ]] && echo yes || echo no))"
    rm -rf "$tmp"
}

t_build_dry_run() {
    local out
    out=$("$SCRIPTS_DIR/install.sh" --build --dry-run --non-interactive 2>&1) || true
    grep -qi "rebuild" <<<"$out" && ok "--build --dry-run mentions rebuild" \
        || bad "--build --dry-run mentions rebuild (got: $out)"
}

# Hermetic stamp-check tests: temp repo copy + scratch HOME with the quickshell
# section detected; --update --dry-run reaches build_plugin_if_changed but the
# dry-run line inside build_plugin cuts the path before cmake/sudo.
_mk_stamp_repo() { # $1=repo dir; seeds shell/plugin/src + fresh build/ stamp
    local repo="$1" i
    mkdir -p "$repo/build" "$repo/shell/plugin/src"
    for i in $(seq 1 150); do
        mkdir -p "$repo/shell/plugin/src/module$i"
        echo "// c" > "$repo/shell/plugin/src/module$i/SomeLongClassName$i.hpp"
    done
    touch -d "2020-01-01" "$repo/build/.plugin_build_stamp"   # older than all sources
}

_run_stamp_check() { # $1=repo dir, $2=home dir → echoes update --dry-run output
    local tmpbin="$1/bin"
    mkdir -p "$tmpbin"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$tmpbin/git"
    chmod +x "$tmpbin/git"
    HOME="$2" PATH="$tmpbin:$PATH" "$1/install.sh" --update --dry-run --non-interactive 2>&1
}

t_stamp_check_multi_file() {
    # >62 newer sources used to SIGPIPE find through `grep -q` under pipefail
    # and false-skip as "unchanged"; must take the rebuild path.
    local tmp repo out; tmp=$(mktemp -d); repo="$tmp/repo"
    mkdir -p "$repo" "$tmp/home/.config/quickshell/caelestia"
    cp "$SCRIPTS_DIR/install.sh" "$repo/install.sh"
    _mk_stamp_repo "$repo"
    out=$(_run_stamp_check "$repo" "$tmp/home") || true
    ! grep -q "Plugin source unchanged" <<<"$out" && grep -q "Would rebuild" <<<"$out" \
        && ok "stamp check rebuilds on 150 newer sources" \
        || bad "stamp check rebuilds on 150 newer sources (got: $out)"
    rm -rf "$tmp"
}

t_stamp_check_unchanged() {
    local tmp repo out; tmp=$(mktemp -d); repo="$tmp/repo"
    mkdir -p "$repo" "$tmp/home/.config/quickshell/caelestia"
    cp "$SCRIPTS_DIR/install.sh" "$repo/install.sh"
    _mk_stamp_repo "$repo"
    touch -d "2030-01-01" "$repo/build/.plugin_build_stamp"   # newer than every source → skip
    out=$(_run_stamp_check "$repo" "$tmp/home") || true
    grep -q "Plugin source unchanged" <<<"$out" && ! grep -q "Would rebuild" <<<"$out" \
        && ok "stamp check skips when no source is newer" \
        || bad "stamp check skips when no source is newer (got: $out)"
    rm -rf "$tmp"
}

t_stamp_check_cmake_lists() {
    # only CMakeLists.txt newer (sources stale) → must still rebuild
    local tmp repo out; tmp=$(mktemp -d); repo="$tmp/repo"
    mkdir -p "$repo" "$tmp/home/.config/quickshell/caelestia"
    cp "$SCRIPTS_DIR/install.sh" "$repo/install.sh"
    _mk_stamp_repo "$repo"
    touch -d "2030-01-01" "$repo/build/.plugin_build_stamp"   # newer than every .hpp/.cpp
    echo "# edited" >> "$repo/shell/plugin/src/module1/CMakeLists.txt"
    touch -d "2030-01-02" "$repo/shell/plugin/src/module1/CMakeLists.txt"  # strictly newer than stamp
    out=$(_run_stamp_check "$repo" "$tmp/home") || true
    ! grep -q "Plugin source unchanged" <<<"$out" && grep -q "Would rebuild" <<<"$out" \
        && ok "stamp check rebuilds on newer CMakeLists.txt" \
        || bad "stamp check rebuilds on newer CMakeLists.txt (got: $out)"
    rm -rf "$tmp"
}

# ── Final-review fixes: C1 / I1 / I3 / I4 ────────────────────────────────────
# Minimal fake repo (with a real .git DIR + git stub marker) so tests can tell
# whether git was invoked, without touching the real worktree.
_mk_fake_repo() { # $1 = repo dir
    local repo="$1"
    mkdir -p "$repo/.git" \
        "$repo/hyprland/.config/hypr/hyprland" \
        "$repo/hyprland/.config/caelestia" \
        "$repo/configs/.config/fish" \
        "$repo/configs/.local/share/bin" \
        "$repo/shell/modules"
    cp "$SCRIPTS_DIR/install.sh" "$repo/install.sh"
    cp "$SCRIPTS_DIR/update.sh" "$repo/update.sh"
    echo "hypr-v2"     > "$repo/hyprland/.config/hypr/hyprland/hyprland.conf"
    echo "cs-v2"       > "$repo/hyprland/.config/caelestia/settings.conf"
    echo "fish-v2"     > "$repo/configs/.config/fish/config.fish"
    echo "starship-v2" > "$repo/configs/.config/starship.toml"
    echo "guide-v2"    > "$repo/configs/.local/share/bin/fish-guide"
    echo "qs-v2"       > "$repo/shell/modules/dummy.qml"
}
_seed_sections() { # $1 = HOME dir (creates all three section dirs)
    mkdir -p "$1/.config/hypr/hyprland" "$1/.config/quickshell/caelestia" "$1/.config/fish"
}
_git_stub() { # $1 = bin dir; fake git that records every invocation in $2
    mkdir -p "$1"
    printf '#!/usr/bin/env bash\ntouch "%s"\nexit 0\n' "$2" > "$1/git"
    chmod +x "$1/git"
}

# C1: spec §4 — bare `--non-interactive --no-install` = headless install,
# configs-only: manifests written, NO git pull, NO plugin build.
t_bare_no_install_routes_install() {
    local tmp repo out rc; tmp=$(mktemp -d); repo="$tmp/repo"
    _mk_fake_repo "$repo"
    _git_stub "$tmp/bin" "$tmp/git-was-called"
    out=$(HOME="$tmp/home" PATH="$tmp/bin:$PATH" \
        "$repo/install.sh" --non-interactive --no-install 2>&1); rc=$?
    [[ "$rc" -eq 0 ]] && ok "bare --no-install exits 0" \
        || bad "bare --no-install exits 0 (rc=$rc, got: $(head -5 <<<"$out"))"
    [[ -f "$tmp/home/.config/hypr/.deploy-manifest" \
        && -f "$tmp/home/.config/quickshell/caelestia/.deploy-manifest" ]] \
        && ok "bare --no-install deploys configs (manifests written)" \
        || bad "bare --no-install deploys configs (manifests written)"
    [[ ! -e "$tmp/git-was-called" ]] \
        && ok "bare --no-install never runs git" \
        || bad "bare --no-install never runs git"
    ! grep -qE "Building C\+\+ plugin|Would rebuild|Plugin source unchanged" <<<"$out" \
        && ok "bare --no-install never attempts plugin build" \
        || bad "bare --no-install never attempts plugin build (got: $(grep -E "plugin|rebuild" <<<"$out" | head -3))"
    rm -rf "$tmp"
}

# I1: `--update --build` must update configs AND rebuild (order-independent).
t_update_build_keeps_update_mode() {
    local tmp repo out; tmp=$(mktemp -d); repo="$tmp/repo"
    _mk_fake_repo "$repo"; _seed_sections "$tmp/home"
    _git_stub "$tmp/bin" "$tmp/git-was-called"
    out=$(HOME="$tmp/home" PATH="$tmp/bin:$PATH" \
        "$repo/install.sh" --update --build --non-interactive --dry-run 2>&1) || true
    grep -q "Updating custom-caelestia" <<<"$out" \
        && ok "--update --build keeps update mode" \
        || bad "--update --build keeps update mode (got: $(head -3 <<<"$out"))"
    grep -q "Would create" <<<"$out" \
        && ok "--update --build still deploys configs" \
        || bad "--update --build still deploys configs (got: $out)"
    rm -rf "$tmp"
}

# I3: the three hand-rolled loops must UPDATE existing differing targets
# (old update.sh behavior), and still honour --on-conflict keep.
t_update_updates_handrolled_files() {
    local tmp repo out rc; tmp=$(mktemp -d); repo="$tmp/repo"
    _mk_fake_repo "$repo"; _seed_sections "$tmp/home"
    _git_stub "$tmp/bin" "$tmp/git-was-called"
    mkdir -p "$tmp/home/.config/caelestia" "$tmp/home/.local/share/bin"
    echo "old-cs"   > "$tmp/home/.config/caelestia/settings.conf"
    echo "old-star" > "$tmp/home/.config/starship.toml"
    echo "old-guide" > "$tmp/home/.local/share/bin/fish-guide"
    touch -d "2020-01-01" "$tmp/home/.config/caelestia/settings.conf" \
        "$tmp/home/.config/starship.toml" "$tmp/home/.local/share/bin/fish-guide"
    out=$(HOME="$tmp/home" PATH="$tmp/bin:$PATH" \
        "$repo/install.sh" --update --non-interactive --no-install 2>&1); rc=$?
    [[ "$rc" -eq 0 ]] && ok "update with --no-install exits 0" \
        || bad "update with --no-install exits 0 (rc=$rc, got: $(tail -5 <<<"$out"))"
    [[ "$(cat "$tmp/home/.config/starship.toml")" == "starship-v2" ]] \
        && ok "update refreshes existing starship.toml" \
        || bad "update refreshes existing starship.toml (got: $(cat "$tmp/home/.config/starship.toml"))"
    [[ "$(cat "$tmp/home/.local/share/bin/fish-guide")" == "guide-v2" ]] \
        && ok "update refreshes existing fish-guide" \
        || bad "update refreshes existing fish-guide (got: $(cat "$tmp/home/.local/share/bin/fish-guide"))"
    [[ "$(cat "$tmp/home/.config/caelestia/settings.conf")" == "cs-v2" ]] \
        && ok "update refreshes existing caelestia config" \
        || bad "update refreshes existing caelestia config (got: $(cat "$tmp/home/.config/caelestia/settings.conf"))"
    # keep-conflict: user-newer target must survive
    echo "user-edit" > "$tmp/home/.config/starship.toml"
    touch -d "2030-01-01" "$tmp/home/.config/starship.toml"
    HOME="$tmp/home" PATH="$tmp/bin:$PATH" \
        "$repo/install.sh" --update --non-interactive --on-conflict keep >/dev/null 2>&1
    [[ "$(cat "$tmp/home/.config/starship.toml")" == "user-edit" ]] \
        && ok "keep-conflict preserves user-edited starship.toml" \
        || bad "keep-conflict preserves user-edited starship.toml (got: $(cat "$tmp/home/.config/starship.toml"))"
    rm -rf "$tmp"
}

# I4: a pre-existing file we never wrote and that has no prior manifest entry
# must NOT be recorded → never pruned when its source later disappears.
t_prune_never_blesses_unwritten() {
    local tmp src dst; tmp=$(mktemp -d); src=$tmp/repo; dst=$tmp/home
    mk_repo "$src"
    mkdir -p "$dst/a"; echo "pre-existing user file" > "$dst/a/f.txt"
    touch -d "2030-06-01" "$dst/a/f.txt"   # future mtime, NO manifest
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false NO_PRUNE=false
        manifest_begin "$dst"; deploy_tree "$src/mods" "$dst"; manifest_finish "$dst"
    )
    ! grep -q "^a/f.txt" "$dst/.deploy-manifest" 2>/dev/null \
        && ok "never-written file not recorded in manifest" \
        || bad "never-written file not recorded in manifest"
    rm "$src/mods/a/f.txt"                  # source disappears
    (
        source_scripts
        ON_CONFLICT=keep DRY_RUN=false FORCE=false NO_PRUNE=false
        manifest_begin "$dst"; deploy_tree "$src/mods" "$dst"; manifest_finish "$dst"
    )
    [[ -f "$dst/a/f.txt" ]] && ok "pre-existing unwritten file never pruned" \
        || bad "pre-existing unwritten file never pruned"
    rm -rf "$tmp"
}

# Follow-up gap: the starship/fish-guide update branches must honour
# .updateignore like deploy_tree — an ignored target is never overwritten,
# even when it is older than the repo source (mtime heuristic).
t_update_honours_updateignore_single_files() {
    local tmp repo out rc; tmp=$(mktemp -d); repo="$tmp/repo"
    _mk_fake_repo "$repo"; _seed_sections "$tmp/home"
    _git_stub "$tmp/bin" "$tmp/git-was-called"
    mkdir -p "$tmp/home/.config" "$tmp/home/.local/share/bin"
    echo "user-star"  > "$tmp/home/.config/starship.toml"
    echo "user-guide" > "$tmp/home/.local/share/bin/fish-guide"
    touch -d "2020-01-01" "$tmp/home/.config/starship.toml" \
        "$tmp/home/.local/share/bin/fish-guide"
    printf 'starship.toml\nfish-guide\n' > "$tmp/home/.updateignore"
    out=$(HOME="$tmp/home" PATH="$tmp/bin:$PATH" \
        "$repo/install.sh" --update --non-interactive --no-install 2>&1); rc=$?
    [[ "$rc" -eq 0 ]] && ok "update with .updateignore exits 0" \
        || bad "update with .updateignore exits 0 (rc=$rc, got: $(tail -5 <<<"$out"))"
    [[ "$(cat "$tmp/home/.config/starship.toml")" == "user-star" ]] \
        && ok "ignored starship.toml not overwritten" \
        || bad "ignored starship.toml not overwritten (got: $(cat "$tmp/home/.config/starship.toml"))"
    [[ "$(cat "$tmp/home/.local/share/bin/fish-guide")" == "user-guide" ]] \
        && ok "ignored fish-guide not overwritten" \
        || bad "ignored fish-guide not overwritten (got: $(cat "$tmp/home/.local/share/bin/fish-guide"))"
    rm -rf "$tmp"
}

main() {
    t_syntax; t_help; t_check_shape; t_check_exit; t_stub_parity; t_bare_defaults_update
    t_deploy_new_and_update; t_conflict_keep_and_replace; t_dry_run_touches_nothing; t_excludes_respected
    t_prune_removes_deleted_source; t_prune_keeps_user_modified; t_no_prune_flag; t_unlisted_never_pruned
    t_prune_keeps_file_edited_before_redeploy
    t_headless_install_configs_only; t_update_skips_uninstalled; t_update_after_install
    t_update_dry_run_skips_git_pull
    t_build_dry_run
    t_stamp_check_multi_file; t_stamp_check_unchanged; t_stamp_check_cmake_lists
    t_bare_no_install_routes_install; t_update_build_keeps_update_mode
    t_update_updates_handrolled_files; t_prune_never_blesses_unwritten
    t_update_honours_updateignore_single_files
    echo ""; echo "RESULT: $PASS passed, $FAIL failed"
    [[ "$FAIL" -eq 0 ]]
}
main "$@"
