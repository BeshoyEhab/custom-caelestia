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

PAM="$SHELL_DIR/modules/lock/Pam.qml"

grep -qF 'event.key === Qt.Key_U' "$PAM" \
    && pass "lock screen clears the password with Ctrl+U" \
    || fail "lock screen ignores Ctrl+U (upstream 48b323fa)"

NOTIFS="$SHELL_DIR/services/Notifs.qml"

grep -qF 'name: "toggleDnd"' "$NOTIFS" \
    && pass "notifications expose a toggleDnd shortcut" \
    || fail "no toggleDnd shortcut (upstream be553a69)"

grep -qF 'onPressed: root.dnd = !root.dnd' "$NOTIFS" \
    && pass "toggleDnd writes the same flag as the IPC handler" \
    || fail "toggleDnd writes a different flag than the IPC handler"

# This fork has no I18n module: a verbatim upstream hunk containing `Tr.` would
# fail at load ("Tr is not defined") and take the whole shell down. The five
# files below are where a port could reintroduce it.
TR_HITS=$(grep -nE -e 'Tr\.tr\b|Tr\.trN\b|Tr\.trCtx\b|Tr\.formatDateTime\b|Tr\.locale\b' \
    "$DASH" "$BT_POPOUT" "$BT_PAIRING" "$PAM" "$NOTIFS" 2>/dev/null || true)
if [[ -n "$TR_HITS" ]]; then
    fail "ported QML references Tr, which this fork does not have (shell will not load)"
    echo "$TR_HITS" | head -3 | sed 's/^/      /'
else
    pass "ported files use qsTr, not the upstream-only Tr API"
fi

echo ""
echo "upstream_ports_test: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
