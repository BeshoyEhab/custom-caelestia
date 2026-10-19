#!/usr/bin/env bash
# Captive-portal QML surface test: Nmcli connectivity state, the
# CaptivePortal singleton (probe / auto-open guards / launch), and the two
# "Sign in to network" rows. Grep-based structural assertions: PASS when the
# feature's code is present, FAIL as soon as one of these surfaces regresses.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$REPO_DIR/shell"
LAUNCH="$REPO_DIR/hyprland/.config/hypr/hyprland/scripts/open_portal_browser.sh"
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
# The launch itself lives in the deployed open_portal_browser.sh (refuses
# non-http(s), preferred Brave app-window with the throwaway profile).
check "throwaway brave profile"     "$LAUNCH" 'user-data-dir'
check "xdg-open fallback"           "$LAUNCH" 'xdg-open'
check "toasts once per episode"     "$S/services/CaptivePortal.qml" 'Toaster.toast'
check "cooldown guard"              "$S/services/CaptivePortal.qml" 'lastOpenTime'
check "IPC target"                  "$S/services/CaptivePortal.qml" 'target: "captivePortal"'
check "re-probe timer"              "$S/services/CaptivePortal.qml" 'interval: 15000'
check "candidateUrl for click"      "$S/services/CaptivePortal.qml" 'property string candidateUrl'

# Round-1 fix: the `active` gate reads Nmcli.isConnected, whose only writer
# lives in refreshStatus() — so the wiring must actually CALL it, or the
# "Sign in to network" rows can never appear. The literal `refreshStatus();`
# matches a call site only; the definition reads `function refreshStatus(...`.
check "Nmcli calls refreshStatus"   "$S/services/Nmcli.qml" 'refreshStatus();'

# Round-1 fix, part 3: refreshStatus() must skip loopback — `lo` reports the
# state `connected (externally)` even when every real device is down, which
# would keep the CaptivePortal visibility gate true on a disconnected network.
check "Nmcli skips loopback"        "$S/services/Nmcli.qml" 'type !== "loopback"'

# The gate value and the interface it resolved stay observable from outside.
check "state exposes connected+iface" "$S/services/CaptivePortal.qml" 'connected=${root.connected} iface=${Nmcli.activeInterface}'

# Final wave (whole-branch review): the automatic-open path must be reachable
# over IPC for a live fixture proof, only http(s) may reach a browser, a wedged
# chain must not leave `probing` stuck true, and the debug probe must refuse to
# run while another probe is in flight.
check "probeAuto on IPC target"    "$S/services/CaptivePortal.qml" 'function probeAuto'
check "https-only launch guard"    "$S/services/CaptivePortal.qml" 'startsWith("https://")'
check "uses portal launch script"  "$S/services/CaptivePortal.qml" 'open_portal_browser.sh'
check "probing watchdog"           "$S/services/CaptivePortal.qml" 'interval: 30000'
check "in-flight probe refused"    "$S/services/CaptivePortal.qml" 'a probe is already in flight'

# Task 5 surface: "Sign in to network" rows in both UI surfaces.
check "Bar popout gated on CaptivePortal" "$S/modules/bar/popouts/Network.qml" 'CaptivePortal.active'
check "Nexus page gated on CaptivePortal" "$S/modules/nexus/pages/NetworkPage.qml" 'CaptivePortal.active'
check "Bar popout has sign-in row"        "$S/modules/bar/popouts/Network.qml" 'qsTr("Sign in to network")'
check "Nexus page has sign-in row"        "$S/modules/nexus/pages/NetworkPage.qml" 'qsTr("Sign in to network")'
# While the portal rows are out, the Wi-Fi row continues their group instead
# of drawing a rounded top mid-group (duplicate `first: true`).
check "wifi row yields first during portal" "$S/modules/nexus/pages/NetworkPage.qml" 'first: !CaptivePortal.active'
# The "Recheck connection" row's click handler: deleting the wiring must fail
# the suite (verified: the pattern matches the page as shipped and does not
# match a copy of it with the call removed).
check "Nexus recheck row wired to recheck()" "$S/modules/nexus/pages/NetworkPage.qml" 'onClicked: CaptivePortal.recheck()'

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (captive-portal surface regression — see the FAIL lines above)"
    exit 1
fi
echo "RESULT: PASS (green)"
