#!/usr/bin/env bash
# Structural gate for commits ported from upstream. Each assertion is tied to a
# specific fix; deleting the fix must fail the suite.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_DIR="$REPO_DIR/shell"
PASS=0
FAIL=0

pass() { echo -e "  \033[0;32mPASS\033[0m $1"; ((++PASS)); }
fail() { echo -e "  \033[0;31mFAIL\033[0m $1"; ((++FAIL)); }

DASH="$SHELL_DIR/modules/dashboard/Content.qml"

grep -qF 'Math.min(root.dashState.currentTab, repeater.count - 1)' "$DASH" \
    && pass "dashboard tab index is clamped to the tab count" \
    || fail "dashboard tab index is not clamped (upstream fd630ffe)"

grep -qF 'dashboardTabs.length > 0 ? view.implicitWidth' "$DASH" \
    && pass "dashboard width collapses to zero with no tabs" \
    || fail "dashboard width is not guarded for zero tabs (upstream fd630ffe)"

grep -qF 'root.dashState.currentTab = Math.max(0, count - 1)' "$DASH" \
    && pass "dashboard clamps the stored tab on count change" \
    || fail "dashboard does not clamp the stored tab on count change (upstream fd630ffe)"

BT_POPOUT="$SHELL_DIR/modules/bar/popouts/Bluetooth.qml"
BT_PAIRING="$SHELL_DIR/modules/nexus/pages/bluetooth/BluetoothPairing.qml"

grep -qF '(!a.deviceName - !b.deviceName)' "$BT_POPOUT" \
    && pass "bluetooth popout sorts self-named devices first" \
    || fail "bluetooth popout does not sort unnamed devices last (upstream 72f60b1d)"

grep -qF '(!a.deviceName - !b.deviceName)' "$BT_PAIRING" \
    && pass "pairing list sorts self-named devices first" \
    || fail "pairing list does not sort unnamed devices last (upstream cb43fc71)"

grep -qF 'devices.reduce((total, d) => total + d.connected, 0)' "$BT_POPOUT" \
    && pass "bluetooth popout counts connected devices without an allocation" \
    || fail "bluetooth popout still filters for the connected count (upstream 72f60b1d)"

echo ""
echo "upstream_ports_test: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
