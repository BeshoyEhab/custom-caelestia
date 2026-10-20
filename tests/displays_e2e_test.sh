#!/usr/bin/env bash
# Opt-in end-to-end check for the SUPER+P display switcher.
#
# Creates a temporary headless output, drives every projection mode through the
# shell's IPC, asserts the result from hyprctl, then removes the fake output.
#
#   DISPLAYS_E2E=1 bash tests/displays_e2e_test.sh
#
# The script never runs `hyprctl reload`: Hyprland 0.56 has crashed on reload
# while a virtual output was disabled, and a crashed session is worse than the
# thing under test. Persistence is checked by reading monitors.lua instead.
# It is not part of tests/run.sh.
set -euo pipefail

FAKE=HEADLESS-1

if [[ "${DISPLAYS_E2E:-0}" != "1" ]]; then
    echo "skipped (set DISPLAYS_E2E=1 to run)"
    exit 0
fi

PASS=0
FAIL=0

pass() { echo -e "  \033[0;32mPASS\033[0m $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  \033[0;31mFAIL\033[0m $1"; FAIL=$((FAIL + 1)); }

ipc() { qs -c caelestia ipc call displays "$@"; }

monitors_json() { hyprctl monitors all -j; }

field() { # field <name> <key>
    monitors_json | python3 -c "
import json, sys
name, key = sys.argv[1], sys.argv[2]
for m in json.load(sys.stdin):
    if m['name'] == name:
        print(m.get(key, ''))
        break
" "$1" "$2"
}

# ── preconditions ────────────────────────────────────────────────────────────
if monitors_json | grep -qE '"name" : "(HEADLESS|FALLBACK)'; then
    echo "refusing to run: a virtual output is already present; clean the session first"
    exit 1
fi

REAL=$(monitors_json | python3 -c "
import json, sys
real = [m['name'] for m in json.load(sys.stdin) if not m.get('disabled')]
print(real[0] if real else '')
")
if [[ -z "$REAL" ]]; then
    echo "refusing to run: no active monitor"
    exit 1
fi

cleanup() {
    # Re-enable the real panel first, whatever state the assertions left.
    ipc setMode main >/dev/null 2>&1 || true
    sleep 1
    # A disabled virtual output cannot be removed; enable it, remove it, then
    # rewrite the layout without it.
    if monitors_json | grep -q "\"$FAKE\""; then
        ipc setMode extend >/dev/null 2>&1 || true
        sleep 1
        hyprctl output remove "$FAKE" >/dev/null 2>&1 || true
    fi
    ipc refresh >/dev/null 2>&1 || true
    sleep 1
    ipc setMode main >/dev/null 2>&1 || true
    ipc close >/dev/null 2>&1 || true
}
trap cleanup EXIT

ipc open >/dev/null
hyprctl output create headless "$FAKE" >/dev/null
sleep 1.2
ipc refresh >/dev/null
sleep 1

# ── detection ────────────────────────────────────────────────────────────────
if ipc state | grep -q "secondary=$FAKE"; then
    pass "second output detected ($FAKE)"
else
    fail "second output not detected: $(ipc state)"
fi

# ── extend right ─────────────────────────────────────────────────────────────
ipc setMode extend >/dev/null
ipc setPlacement right >/dev/null
sleep 2
real_w=$(field "$REAL" width)
real_scale=$(field "$REAL" scale)
expected_x=$(python3 -c "print(int($real_w / $real_scale))")
fake_x=$(field "$FAKE" x)
if [[ "$fake_x" == "$expected_x" ]]; then
    pass "extend right: $FAKE x=$fake_x"
else
    fail "extend right: expected x=$expected_x, got x=$fake_x"
fi

# ── extend left ──────────────────────────────────────────────────────────────
ipc setPlacement left >/dev/null
sleep 2
fake_x=$(field "$FAKE" x)
fake_w=$(field "$FAKE" width)
fake_scale=$(field "$FAKE" scale)
expected_x=$(python3 -c "print(-int($fake_w / $fake_scale))")
if [[ "$fake_x" == "$expected_x" ]]; then
    pass "extend left: $FAKE x=$fake_x"
else
    fail "extend left: expected x=$expected_x, got x=$fake_x"
fi

# ── duplicate ────────────────────────────────────────────────────────────────
ipc setMode duplicate >/dev/null
sleep 2
mirror=$(field "$FAKE" mirrorOf)
real_id=$(field "$REAL" id)
if [[ "$mirror" == "$real_id" || "$mirror" == "$REAL" ]]; then
    pass "duplicate: $FAKE mirrors $REAL"
else
    fail "duplicate: expected mirrorOf=$real_id ($REAL), got '$mirror'"
fi
if ipc state | grep -q "mode=duplicate"; then
    pass "state reports duplicate"
else
    fail "state does not report duplicate: $(ipc state)"
fi

# ── main only + persistence ──────────────────────────────────────────────────
ipc setMode main >/dev/null
sleep 2
if [[ "$(field "$FAKE" disabled)" == "True" ]]; then
    pass "main only: $FAKE disabled"
else
    fail "main only: $FAKE still enabled"
fi
if [[ "$(field "$REAL" disabled)" == "False" ]]; then
    pass "main only: $REAL stays enabled"
else
    fail "main only: $REAL was disabled"
fi
if grep -q "disabled = true" ~/.config/hypr/monitors.lua && grep -q "output = \"$FAKE\"" ~/.config/hypr/monitors.lua; then
    pass "main only written to monitors.lua"
else
    fail "monitors.lua does not record the disabled output"
fi

# ── second only is refused when it would switch off the last panel ───────────
before=$(ipc state)
ipc setMode second >/dev/null
sleep 1.5
if [[ "$(field "$REAL" disabled)" == "False" ]]; then
    pass "second only refused: $REAL stays on"
else
    fail "second only disabled the only physical panel"
fi
if ipc state | grep -q "Refusing to switch off every physical display"; then
    pass "refusal is explained to the user"
else
    fail "no refusal message: $(ipc state)"
fi

# ── workspace pin ────────────────────────────────────────────────────────────
ipc setMode extend >/dev/null
sleep 1.5
ipc setWorkspace 4 >/dev/null
sleep 1.5
if grep -q 'workspace = "4"' ~/.config/hypr/workspaces.lua && grep -q "monitor = \"$FAKE\"" ~/.config/hypr/workspaces.lua; then
    pass "workspace 4 pinned to $FAKE"
else
    fail "workspace pin missing from ~/.config/hypr/workspaces.lua"
fi
if grep -q 'workspace = "2"' ~/.config/hypr/workspaces.lua; then
    fail "old workspace pin (2) was not replaced"
else
    pass "old workspace pin replaced, not duplicated"
fi

# ── back to a single screen ──────────────────────────────────────────────────
ipc setMode main >/dev/null
sleep 2
if [[ "$(field "$REAL" disabled)" == "False" ]]; then
    pass "restored: $REAL enabled"
else
    fail "restore failed: $REAL still disabled"
fi

echo ""
echo "displays e2e: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
