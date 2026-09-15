#!/usr/bin/env bash
# TDD RED test: h:mm:ss clock formatting must go through Strings.clockDuration(s).
# Duplicated in dashboard/media/Details.qml (lengthStr) and utilities/cards/Record.qml
# (inline block). Battery's words-format ("2 hours, 5 mins") is a different format
# with a single site: intentionally not covered. upstream/ mirror excluded by policy.
# Fails before the fix, passes after.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

echo "═══ qml_duration_helper ═══"

if grep -q "function clockDuration(" "$REPO_DIR/shell/utils/Strings.qml"; then
    echo "  PASS Strings.qml defines clockDuration()"
else
    echo "  FAIL Strings.qml has no clockDuration() helper"
    FAIL=1
fi

# hand-rolled h:mm:ss logic: padStart(2, "0") clock math outside the helper
DUPES=$(grep -rn --exclude-dir=upstream 'padStart(2, "0")' "$REPO_DIR/shell" --include="*.qml" | grep -v "shell/utils/Strings.qml" || true)
if [[ -z "$DUPES" ]]; then
    echo "  PASS no hand-rolled clock formatting outside Strings.qml"
else
    echo "  FAIL hand-rolled clock formatting remains:"
    echo "$DUPES" | head -10
    FAIL=1
fi

if grep -q "function lengthStr(" "$REPO_DIR/shell/modules/dashboard/media/Details.qml"; then
    echo "  FAIL Details.qml still carries local lengthStr()"
    FAIL=1
else
    echo "  PASS Details.qml uses the shared helper"
fi

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (red - duplication present)"
    exit 1
fi
echo "RESULT: PASS (green)"
