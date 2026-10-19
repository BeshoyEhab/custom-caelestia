#!/usr/bin/env bash
# Hermetic tests for hyprland/.config/hypr/hyprland/scripts/captive_portal_probe.sh
# No external network, no sudo: a local python3 fixture serves canned portal
# responses on 127.0.0.1, plus one refused-port case on 127.0.0.1:1.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0
pass() { echo -e "  \033[0;32mPASS\033[0m $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  \033[0;31mFAIL\033[0m $1"; FAIL=$((FAIL + 1)); }

PROBE="$REPO_DIR/hyprland/.config/hypr/hyprland/scripts/captive_portal_probe.sh"
FIXTURE="$REPO_DIR/tests/fixtures/fake_portal_server.py"

FIXTURE_PID=""
PORT_FILE="$(mktemp)"
OUT_FILE="$(mktemp)"

stop_fixture() {
    if [[ -n "$FIXTURE_PID" ]]; then
        kill "$FIXTURE_PID" 2>/dev/null
        wait "$FIXTURE_PID" 2>/dev/null
        FIXTURE_PID=""
    fi
}

cleanup() {
    stop_fixture
    rm -f "$PORT_FILE" "$OUT_FILE"
}
trap cleanup EXIT

echo "═══ captive_portal_probe ═══"

# Start the fixture in the background and poll its first stdout line (the
# port) for up to ~5 s. Sets PORT (empty if the fixture never came up).
start_fixture() { # <mode>
    stop_fixture
    PORT=""
    python3 "$FIXTURE" "$1" >"$PORT_FILE" 2>/dev/null &
    FIXTURE_PID=$!
    local i
    for ((i = 0; i < 100; i++)); do
        PORT="$(head -n 1 "$PORT_FILE" 2>/dev/null)"
        [[ -n "$PORT" ]] && return 0
        kill -0 "$FIXTURE_PID" 2>/dev/null || return 1
        sleep 0.05
    done
    return 1
}

# Run the probe against <url> and assert the exact single stdout line, the
# exit code, and the one-newline-terminated-line stdout contract.
assert_case() { # <desc> <url> <expected-line> <expected-rc>
    bash "$PROBE" "$2" >"$OUT_FILE"
    local rc=$? out lines
    out="$(cat "$OUT_FILE")"
    lines="$(wc -l < "$OUT_FILE")"
    if [[ "$out" == "$3" && "$rc" -eq "$4" && "$lines" -eq 1 ]]; then
        pass "$1"
    else
        fail "$1 (got: '$out' rc=$rc lines=$lines; want: '$3' rc=$4 lines=1)"
    fi
}

start_fixture online
url="http://127.0.0.1:$PORT/"
assert_case "mode=online -> online <url> 200 (exit 0)" "$url" "online $url 200" 0

start_fixture no-content
url="http://127.0.0.1:$PORT/"
assert_case "mode=no-content -> online <url> 204 (exit 0)" "$url" "online $url 204" 0

start_fixture redirect
url="http://127.0.0.1:$PORT/"
assert_case "mode=redirect -> portal <location> 302 (exit 1)" "$url" "portal http://portal.example.test/login 302" 1

# Review branch: a 3xx with NO Location header — curl's %{redirect_url} is
# empty, so the probe must classify portal against the probed URL itself.
start_fixture redirect-no-location
url="http://127.0.0.1:$PORT/"
assert_case "mode=redirect-no-location -> portal <url> 302 (exit 1)" "$url" "portal $url 302" 1

start_fixture html
url="http://127.0.0.1:$PORT/"
assert_case "mode=html -> portal <url> 200 (exit 1)" "$url" "portal $url 200" 1

# Review branch: a hard HTTP error must report the OBSERVED status, not 000 —
# 000 is reserved for "there was no HTTP response at all" (refused/timeout).
start_fixture error500
url="http://127.0.0.1:$PORT/"
assert_case "mode=error500 -> unknown <url> 500 (exit 2)" "$url" "unknown $url 500" 2

url="http://127.0.0.1:1/"
assert_case "refused port -> unknown <url> 000 (exit 2)" "$url" "unknown $url 000" 2

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
