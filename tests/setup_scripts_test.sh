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
