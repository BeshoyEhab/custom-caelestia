#!/usr/bin/env bash
# TDD RED test: remaining-items batch.
# 1. Single nmcli monitor: VPN.qml must not spawn its own `nmcli monitor`
#    (Nmcli.qml already runs one with auto-restart and emits connectionChanged).
#    VPN must react via Connections on Nmcli.connectionChanged instead.
# 2. Popout widths via Tokens: WirelessPassword/WorkspacePreview must use
#    Tokens.sizes.bar.* like every other popout (new BarTokens properties).
# 3. Script parity: read -r everywhere, cp -a backups, CI covers all scripts,
#    build-plugin.sh builds the same modules as install/update.
# Fails before the fix, passes after.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

echo "═══ remaining_batch ═══"

echo "-- single nmcli monitor --"
if grep -q '"nmcli", "monitor"' "$REPO_DIR/shell/services/VPN.qml"; then
    echo "  FAIL VPN.qml spawns its own nmcli monitor"
    FAIL=1
else
    echo "  PASS VPN.qml has no nmcli monitor process"
fi
if grep -q "target: Nmcli" "$REPO_DIR/shell/services/VPN.qml" && grep -q "onConnectionChanged" "$REPO_DIR/shell/services/VPN.qml"; then
    echo "  PASS VPN.qml reacts to Nmcli.connectionChanged"
else
    echo "  FAIL VPN.qml not wired to Nmcli.connectionChanged"
    FAIL=1
fi
if grep -q "monitorRestartTimer" "$REPO_DIR/shell/services/Nmcli.qml"; then
    echo "  PASS Nmcli monitor keeps auto-restart (robustness retained)"
else
    echo "  FAIL Nmcli monitor lost auto-restart"
    FAIL=1
fi

echo "-- popout widths via Tokens --"
for prop in wirelessPasswordWidth workspacePreviewWidth; do
    grep -q "CONFIG_PROPERTY(int, $prop," "$REPO_DIR/shell/plugin/src/Caelestia/Config/tokens.hpp" \
        && echo "  PASS BarTokens.$prop exists" \
        || { echo "  FAIL BarTokens.$prop missing"; FAIL=1; }
done
grep -q "Tokens.sizes.bar.wirelessPasswordWidth" "$REPO_DIR/shell/modules/bar/popouts/WirelessPassword.qml" \
    && echo "  PASS WirelessPassword uses token" \
    || { echo "  FAIL WirelessPassword hardcodes width"; FAIL=1; }
grep -q "Tokens.sizes.bar.workspacePreviewWidth" "$REPO_DIR/shell/modules/bar/popouts/WorkspacePreview.qml" \
    && echo "  PASS WorkspacePreview uses token" \
    || { echo "  FAIL WorkspacePreview hardcodes width"; FAIL=1; }
if grep -q "implicitWidth: 400" "$REPO_DIR/shell/modules/bar/popouts/WirelessPassword.qml" \
    || grep -q "implicitWidth: 200" "$REPO_DIR/shell/modules/bar/popouts/WorkspacePreview.qml"; then
    echo "  FAIL hardcoded popout widths remain"
    FAIL=1
else
    echo "  PASS no hardcoded popout widths"
fi

echo "-- script parity --"
RAW_READS=$(grep -n "read -p" "$REPO_DIR/install.sh" "$REPO_DIR/update.sh" | grep -v "read -r" || true)
if [[ -z "$RAW_READS" ]]; then
    echo "  PASS all read prompts use -r"
else
    echo "  FAIL read without -r:"; echo "$RAW_READS" | head -6
    FAIL=1
fi
grep -q 'cp -a "$d" "$backup_dir"' "$REPO_DIR/update.sh" \
    && echo "  PASS backups preserve attributes (cp -a)" \
    || { echo "  FAIL backup still uses cp -r"; FAIL=1; }
for s in deploy.sh restart.sh merge-upstream.sh test-notifs.sh; do
    grep -q "$s" "$REPO_DIR/.github/workflows/ci.yml" \
        && echo "  PASS CI covers $s" \
        || { echo "  FAIL CI omits $s"; FAIL=1; }
done
grep -q 'ENABLE_MODULES="plugin;m3shapes"' "$REPO_DIR/build-plugin.sh" \
    && echo "  PASS build-plugin.sh builds full module set" \
    || { echo "  FAIL build-plugin.sh ships incomplete plugin"; FAIL=1; }

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (red - remaining items open)"
    exit 1
fi
echo "RESULT: PASS (green)"
