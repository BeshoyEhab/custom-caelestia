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

# Task 4 surface: CaptivePortal singleton.
check "CaptivePortal singleton"     "$S/services/CaptivePortal.qml" 'pragma Singleton'
check "CaptivePortal seen by loader" "$S/modules/ServiceLoader.qml" 'CaptivePortal'
check "active covers unknown"       "$S/services/CaptivePortal.qml" 'connectivity === "unknown"'
check "auto-open requires portal"   "$S/services/CaptivePortal.qml" 'lastProbe === "portal"'
check "uses probe script"           "$S/services/CaptivePortal.qml" 'captive_portal_probe.sh'
check "throwaway brave profile"     "$S/services/CaptivePortal.qml" 'user-data-dir'
check "xdg-open fallback"           "$S/services/CaptivePortal.qml" 'xdg-open'
check "toasts once per episode"     "$S/services/CaptivePortal.qml" 'Toaster.toast'
check "cooldown guard"              "$S/services/CaptivePortal.qml" 'lastOpenTime'
check "IPC target"                  "$S/services/CaptivePortal.qml" 'target: "captivePortal"'
check "re-probe timer"              "$S/services/CaptivePortal.qml" 'interval: 15000'
check "candidateUrl for click"      "$S/services/CaptivePortal.qml" 'property string candidateUrl'

# Task 5 surface: "Sign in to network" rows in both UI surfaces.
check "Bar popout gated on CaptivePortal" "$S/modules/bar/popouts/Network.qml" 'CaptivePortal.active'
check "Nexus page gated on CaptivePortal" "$S/modules/nexus/pages/NetworkPage.qml" 'CaptivePortal.active'
check "Bar popout has sign-in row"        "$S/modules/bar/popouts/Network.qml" 'qsTr("Sign in to network")'
check "Nexus page has sign-in row"        "$S/modules/nexus/pages/NetworkPage.qml" 'qsTr("Sign in to network")'

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (red - connectivity not implemented)"
    exit 1
fi
echo "RESULT: PASS (green)"
