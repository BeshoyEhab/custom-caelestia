#!/usr/bin/env bash
# custom-caelestia test runner
# Run all test suites, exit 1 if any fail.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo -e "  \033[0;32mPASS\033[0m $1"; ((PASS++)); }
fail() { echo -e "  \033[0;31mFAIL\033[0m $1"; ((FAIL++)); }

test_suite() {
    local name="$1" script="$2"
    echo ""
    echo "═══ $name ═══"
    if bash "$script"; then
        pass "$name"
    else
        fail "$name"
    fi
}

cd "$REPO_DIR"

test_suite "install_test" "tests/install_test.sh"
test_suite "qml_test"     "tests/qml_test.sh"
test_suite "widget_test"  "tests/widget_test.sh"

echo ""
echo "═══════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════"
[[ $FAIL -eq 0 ]]
