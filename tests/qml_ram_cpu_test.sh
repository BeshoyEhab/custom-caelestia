#!/usr/bin/env bash
# TDD RED test: RAM/CPU guards.
# - Visualiser bars advance at most ~30fps (frame accumulator).
# - Tray icon source is debounced so a churning app can't drive repaint rate.
# - Image disk cache is pruned (count + byte caps) instead of growing forever.
# Fails before the fix, passes after.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$REPO_DIR/shell"
FAIL=0

echo "=== qml_ram_cpu ==="

check() { # check <desc> <file> <grep-pattern>
    if grep -q "$3" "$2"; then
        echo "  PASS $1"
    else
        echo "  FAIL $1"
        FAIL=1
    fi
}

check "Visualiser 30fps cap" "$S/modules/background/Visualiser.qml" "frameAccum"
check "Tray icon debounce" "$S/modules/bar/components/TrayItem.qml" "iconDebounce"
check "Tray shown icon" "$S/modules/bar/components/TrayItem.qml" "shownIcon"
check "ImageCache prune" "$S/plugin/src/Caelestia/Images/imagecacher.cpp" "prune"
check "ImageCache file cap" "$S/plugin/src/Caelestia/Images/imagecacher.cpp" "kMaxFiles"
check "ImageCache byte cap" "$S/plugin/src/Caelestia/Images/imagecacher.cpp" "kMaxBytes"

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (red - ram/cpu guards missing)"
    exit 1
fi
echo "RESULT: PASS (green)"
