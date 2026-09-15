#!/usr/bin/env bash
# TDD RED test: dev/test scripts must be safe under set -euo pipefail.
# - deploy.sh/restart.sh must detect BUILD failures (the `| tail -5; [[ $? ]]`
#   pattern tests tail's exit code, always 0: broken builds deploy silently).
# - restart.sh must not die on unguarded $1 (set -u) and needs strict mode.
# - tests/run.sh must complete ALL suites (the ((PASS++)) + set -e bug kills
#   the runner after the first suite: qml/widget tests never run).
# Fails before the fix, passes after.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

echo "═══ script_safety ═══"

for s in deploy.sh restart.sh; do
    if grep -q "set -euo pipefail" "$REPO_DIR/$s"; then
        echo "  PASS $s strict mode"
    else
        echo "  FAIL $s missing 'set -euo pipefail'"
        FAIL=1
    fi
    if grep -q "tail -5" "$REPO_DIR/$s" && grep -q '\$?' "$REPO_DIR/$s"; then
        echo "  FAIL $s tests tail's exit code instead of the build's"
        FAIL=1
    else
        echo "  PASS $s build-failure detection"
    fi
done

if grep -q '"${1:-}"' "$REPO_DIR/restart.sh"; then
    echo "  PASS restart.sh guards \$1"
else
    echo "  FAIL restart.sh uses unguarded \$1 (dies under set -u with no args)"
    FAIL=1
fi

echo "-- run.sh must complete all suites --"
OUT=$(bash "$REPO_DIR/tests/run.sh" 2>&1)
for suite in install_test qml_test widget_test; do
    if echo "$OUT" | grep -q "PASS.*$suite"; then
        echo "  PASS run.sh completes $suite"
    else
        echo "  FAIL run.sh never completes $suite"
        FAIL=1
    fi
done

for s in deploy.sh restart.sh tests/run.sh tests/script_safety_test.sh; do
    if bash -n "$REPO_DIR/$s"; then
        echo "  PASS $s syntax"
    else
        echo "  FAIL $s syntax"
        FAIL=1
    fi
done

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (red - script safety bugs present)"
    exit 1
fi
echo "RESULT: PASS (green)"
