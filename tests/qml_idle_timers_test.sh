#!/usr/bin/env bash
# TDD RED test: no background polling when the feature is idle.
# - VideoWallpaper supervisorTimer must be gated on video-active state
#   (its body already guards on the same condition; unconditional running
#   spawns pgrep every 10s for users without video wallpapers).
# - Notifs saveTimer must debounce at >=4000ms (1s serializes the full
#   list on every burst).
# Fails before the fix, passes after.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VW="$REPO_DIR/shell/services/VideoWallpaper.qml"
NOTIFS="$REPO_DIR/shell/services/Notifs.qml"
FAIL=0

echo "═══ qml_idle_timers ═══"

# NOTE: range ends at the Timer's own closing brace (4-space indent);
# stopping at the first "}" would match inside onTriggered's guard instead.
VW_TIMER=$(awk '/id: supervisorTimer/{f=1} f{print} f&&/^    }$/{exit}' "$VW")
RUNNING_LINE=$(echo "$VW_TIMER" | grep "running:")
echo "  supervisor running binding:${RUNNING_LINE:- <not found>}"
if echo "$RUNNING_LINE" | grep -q "externalActive"; then
    echo "  PASS supervisorTimer gated on externalActive"
else
    echo "  FAIL supervisorTimer runs unconditionally (no externalActive gate)"
    FAIL=1
fi
if echo "$RUNNING_LINE" | grep -q "lastCmds"; then
    echo "  PASS supervisorTimer gated on lastCmds"
else
    echo "  FAIL supervisorTimer has no lastCmds gate"
    FAIL=1
fi
# crash recovery must still work: body must keep the respawn path
if echo "$VW_TIMER" | grep -q "pendingCheck"; then
    echo "  PASS supervisor body keeps respawn path"
else
    echo "  FAIL supervisor body lost respawn path"
    FAIL=1
fi

SAVE_INTERVAL=$(awk '/id: saveTimer/,/}/' "$NOTIFS" | grep -o "interval: [0-9]*" | awk '{print $2}')
echo "  saveTimer interval = ${SAVE_INTERVAL:-<not found>}"
if [[ "${SAVE_INTERVAL:-0}" -ge 4000 ]]; then
    echo "  PASS saveTimer debounces at >=4000ms"
else
    echo "  FAIL saveTimer interval too aggressive (<4000ms)"
    FAIL=1
fi
# debounce wiring must survive: onListChanged must still restart the timer
if grep -q "saveTimer.restart()" "$NOTIFS"; then
    echo "  PASS onListChanged still restarts saveTimer"
else
    echo "  FAIL onListChanged lost saveTimer.restart()"
    FAIL=1
fi

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (red - idle polling present)"
    exit 1
fi
echo "RESULT: PASS (green)"
