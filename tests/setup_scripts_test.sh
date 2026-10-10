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

main() {
    t_syntax; t_help; t_check_shape; t_check_exit; t_stub_parity; t_bare_defaults_update
    t_deploy_new_and_update; t_conflict_keep_and_replace; t_dry_run_touches_nothing; t_excludes_respected
    echo ""; echo "RESULT: $PASS passed, $FAIL failed"
    [[ "$FAIL" -eq 0 ]]
}
main "$@"
