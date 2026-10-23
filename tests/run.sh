#!/usr/bin/env bash
# custom-caelestia test runner
# Run all test suites, exit 1 if any fail.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo -e "  \033[0;32mPASS\033[0m $1"; ((++PASS)); }
fail() { echo -e "  \033[0;31mFAIL\033[0m $1"; ((++FAIL)); }

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
test_suite "qml_cliprect_test" "tests/qml_cliprect_test.sh"
test_suite "ram_cpu_test" "tests/qml_ram_cpu_test.sh"
test_suite "widget_test"  "tests/widget_test.sh"
test_suite "least_busy_region_test" "tests/python_least_busy_region_test.sh"
test_suite "captive_portal_probe_test" "tests/captive_portal_probe_test.sh"
test_suite "qml_captive_portal_test" "tests/qml_captive_portal_test.sh"
test_suite "qml_kblayout_test" "tests/qml_kblayout_test.sh"
test_suite "captive_portal_launch_fallback_test" "tests/captive_portal_launch_fallback_test.sh"
test_suite "display_math_test" "tests/display_math_test.sh"
test_suite "keybinds_parse_test" "tests/keybinds_parse_test.sh"
test_suite "overview_math_test" "tests/overview_math_test.sh"
test_suite "clock_position_test" "tests/clock_position_test.sh"
test_suite "clock_colours_test" "tests/clock_colours_test.sh"
test_suite "clock_settings_test" "tests/clock_settings_test.sh"
test_suite "qml_clock_bindings_test" "tests/qml_clock_bindings_test.sh"
test_suite "qml_config_scope_test" "tests/qml_config_scope_test.sh"

echo ""
echo "═══════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════"
[[ $FAIL -eq 0 ]]
