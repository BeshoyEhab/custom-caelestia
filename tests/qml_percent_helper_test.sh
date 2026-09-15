#!/usr/bin/env bash
# TDD RED test: percent formatting must go through Strings.percent(v).
# Raw Math.round(x * 100) + "%" repeats in 12+ live files in two shapes
# (concatenation and template literal). The shell/upstream/ mirror is
# excluded by policy (never touch upstream copies).
# Fails before the fix, passes after.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

echo "═══ qml_percent_helper ═══"

if grep -q "function percent(" "$REPO_DIR/shell/utils/Strings.qml"; then
    echo "  PASS Strings.qml defines percent()"
else
    echo "  FAIL Strings.qml has no percent() helper"
    FAIL=1
fi

# shape 1: Math.round(<expr> * 100) + "%" (the single definition in Strings.qml is the canonical one)
CONCAT=$(grep -rn --exclude-dir=upstream --exclude=Strings.qml 'Math\.round([^`]*\* 100)[^`]*"%"' "$REPO_DIR/shell" | grep -v "Strings.percent" || true)
if [[ -z "$CONCAT" ]]; then
    echo "  PASS no raw concat percent formatting outside upstream/"
else
    echo "  FAIL raw concat percent formatting remains:"
    echo "$CONCAT" | head -20
    FAIL=1
fi

# shape 2: `${Math.round(<expr> * 100)}%`
TEMPLATE=$(grep -rn --exclude-dir=upstream 'Math\.round([^}]*\* 100)}%' "$REPO_DIR/shell" | grep -v "Strings.percent" || true)
if [[ -z "$TEMPLATE" ]]; then
    echo "  PASS no raw template percent formatting outside upstream/"
else
    echo "  FAIL raw template percent formatting remains:"
    echo "$TEMPLATE" | head -20
    FAIL=1
fi

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (red - duplication present)"
    exit 1
fi
echo "RESULT: PASS (green)"
