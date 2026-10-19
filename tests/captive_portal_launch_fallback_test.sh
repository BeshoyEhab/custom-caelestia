#!/usr/bin/env bash
# Hermetic tests for hyprland/.config/hypr/hyprland/scripts/open_portal_browser.sh
# Each case runs the script with a temp PATH holding only stub launchers, so no
# real browser is ever started: no network, no sudo, no X/Wayland session needed.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCH="$REPO_DIR/hyprland/.config/hypr/hyprland/scripts/open_portal_browser.sh"

PASS=0
FAIL=0
pass() { echo -e "  \033[0;32mPASS\033[0m $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  \033[0;31mFAIL\033[0m $1"; FAIL=$((FAIL + 1)); }

BASH_BIN="$(command -v bash)"
TMP="$(mktemp -d)"
LOG="$TMP/launch.log"
trap 'rm -rf "$TMP"' EXIT

echo "═══ captive_portal_launch_fallback ═══"

# Stub launcher: appends "<name> <args...>" to $LAUNCH_STUB_LOG and exits 0.
# Pure shell, and the shebang pins the absolute bash — PATH inside the test is
# restricted to the stub directory, so `#!/usr/bin/env bash` could not resolve.
mk_stub() { # <dir> <name>
    mkdir -p "$1"
    printf '#!%s\nprintf "%%s %%s\\n" "${0##*/}" "$*" >> "$LAUNCH_STUB_LOG"\n' "$BASH_BIN" > "$1/$2"
    chmod +x "$1/$2"
}

run_launch() { # <bin-dir> [args...]
    local dir="$1"; shift
    : > "$LOG"
    LAUNCH_STUB_LOG="$LOG" PATH="$dir" "$BASH_BIN" "$LAUNCH" "$@" 2>&1
}

# ── (a) no brave on PATH → the URL goes to xdg-open ─────────────────────────
mkdir -p "$TMP/only-xdg"
mk_stub "$TMP/only-xdg" xdg-open
out="$(run_launch "$TMP/only-xdg" "http://portal.example.test/login" "$TMP/profile-a")"
rc=$?
if [[ $rc -eq 0 ]] && grep -q '^xdg-open http://portal.example.test/login$' "$LOG" && ! grep -q '^brave' "$LOG"; then
    pass "no brave on PATH -> execs xdg-open with the URL"
else
    fail "no brave on PATH -> execs xdg-open with the URL (rc=$rc out='$out' log: $(tr '\n' ';' <"$LOG"))"
fi

# ── (b) brave on PATH → preferred app-window with the throwaway profile ─────
mkdir -p "$TMP/with-brave"
mk_stub "$TMP/with-brave" brave
mk_stub "$TMP/with-brave" xdg-open
out="$(run_launch "$TMP/with-brave" "http://portal.example.test/login" "$TMP/profile-b")"
rc=$?
if [[ $rc -eq 0 ]] && grep -q "^brave --app=http://portal.example.test/login --user-data-dir=$TMP/profile-b$" "$LOG" && ! grep -q '^xdg-open' "$LOG"; then
    pass "brave on PATH -> execs brave --app with the profile, not xdg-open"
else
    fail "brave on PATH -> execs brave --app with the profile, not xdg-open (rc=$rc out='$out' log: $(tr '\n' ';' <"$LOG"))"
fi

# ── (c) non-http(s) URL → refused (exit 2), nothing launched ────────────────
out="$(run_launch "$TMP/with-brave" "file:///etc/passwd" "$TMP/profile-c")"
rc=$?
if [[ $rc -eq 2 && ! -s "$LOG" && "$out" == *Refusing* ]]; then
    pass "file:/// URL -> exit 2, launches neither"
else
    fail "file:/// URL -> exit 2, launches neither (rc=$rc out='$out' log: $(tr '\n' ';' <"$LOG"))"
fi

# ── (d) second argument omitted → default throwaway profile under XDG_RUNTIME_DIR
: > "$LOG"
XDG_RUNTIME_DIR="$TMP/xdg-run" LAUNCH_STUB_LOG="$LOG" PATH="$TMP/with-brave" "$BASH_BIN" "$LAUNCH" "http://portal.example.test/login" >/dev/null 2>&1
drc=$?
if [[ $drc -eq 0 ]] && grep -q "^brave --app=http://portal.example.test/login --user-data-dir=$TMP/xdg-run/caelestia/portal-profile$" "$LOG"; then
    pass "no profile argument -> default \$XDG_RUNTIME_DIR/caelestia/portal-profile"
else
    fail "no profile argument -> default \$XDG_RUNTIME_DIR/caelestia/portal-profile (rc=$drc log: $(tr '\n' ';' <"$LOG"))"
fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
