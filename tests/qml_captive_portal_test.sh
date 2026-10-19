#!/usr/bin/env bash
# TDD RED test: Captive portal — Nmcli connectivity state.
# Fails before the feature, passes after.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$REPO_DIR/shell"
FAIL=0

echo "=== qml_captive_portal ==="

check() { # check <desc> <file> <grep-pattern>
    if grep -q "$3" "$2"; then
        echo "  PASS $1"
    else
        echo "  FAIL $1"
        FAIL=1
    fi
}

# Task 3 surface: connectivity state on the Nmcli singleton, consumed by
# the CaptivePortal singleton in Task 4.
check "Nmcli exposes connectivity"      "$S/services/Nmcli.qml" 'property string connectivity'
check "Nmcli queries CONNECTIVITY"      "$S/services/Nmcli.qml" '"-t", "-f", "CONNECTIVITY", "general"'
check "Nmcli refreshes on monitor line" "$S/services/Nmcli.qml" 'getConnectivity'
check "Nmcli recheck API"               "$S/services/Nmcli.qml" 'function recheckConnectivity'

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (red - connectivity not implemented)"
    exit 1
fi
echo "RESULT: PASS (green)"
