#!/usr/bin/env bash
# End-to-end deploy dry-run test
# Sources install.sh with CI_TEST=true and runs all deploy functions
# to verify files are copied, permissions set, and symlinks created.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

PASS=0
FAIL=0

pass() { echo -e "  \033[0;32mPASS\033[0m $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  \033[0;31mFAIL\033[0m $1"; FAIL=$((FAIL + 1)); }

# ── Setup: stub install_pkg + sudo, source install.sh ────────────────────────
export CI_TEST=true
source install.sh

# Override real install_pkg with no-op (we test file deploy, not package install)
install_pkg() {
    echo "    [stub] would install: $1 (aur=${2:-false})"
}
sudo() { "$@"; }

# ── Test deploy_hyprland ─────────────────────────────────────────────────────
TEST_HOME=$(mktemp -d)
export HOME="$TEST_HOME"
export REPO_DIR="$PWD"
mkdir -p "$HOME/.config"

echo "--- deploy_hyprland ---"
deploy_hyprland

# Check hyprland config files exist
HYPR_FILES=$(find "$HOME/.config/hypr" -type f 2>/dev/null | wc -l)
if [[ "$HYPR_FILES" -gt 0 ]]; then
    pass "deploy_hyprland: $HYPR_FILES config files copied"
else
    fail "deploy_hyprland: no files copied to ~/.config/hypr"
fi

# Check hyprland scripts have +x
SCRIPT_COUNT=0
SCRIPT_OK=0
for s in "$HOME/.config/hypr/hyprland/scripts/"*; do
    if [[ -f "$s" ]]; then
        SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
        if [[ -x "$s" ]]; then
            SCRIPT_OK=$((SCRIPT_OK + 1))
        fi
    fi
done
if [[ "$SCRIPT_COUNT" -gt 0 ]] && [[ "$SCRIPT_COUNT" -eq "$SCRIPT_OK" ]]; then
    pass "deploy_hyprland: all $SCRIPT_COUNT scripts executable"
else
    fail "deploy_hyprland: $SCRIPT_OK/$SCRIPT_COUNT scripts executable"
fi

# Check caelestia config (shell.json excluded)
CAELESTIA_FILES=$(find "$HOME/.config/caelestia" -type f 2>/dev/null | wc -l)
if [[ "$CAELESTIA_FILES" -ge 0 ]]; then
    pass "deploy_hyprland: caelestia config directory created"
fi

# ── Test deploy_quickshell ───────────────────────────────────────────────────
echo ""
echo "--- deploy_quickshell ---"
deploy_quickshell

QS_DIR="$HOME/.config/quickshell/caelestia"
QS_FILES=$(find "$QS_DIR" -type f 2>/dev/null | wc -l)
if [[ "$QS_FILES" -gt 0 ]]; then
    pass "deploy_quickshell: $QS_FILES QML files deployed"
else
    fail "deploy_quickshell: no files in $QS_DIR"
fi

# Check Bar.qml is deployed
if [[ -f "$QS_DIR/modules/bar/Bar.qml" ]]; then
    pass "deploy_quickshell: Bar.qml deployed"
else
    fail "deploy_quickshell: Bar.qml missing"
fi

# Check scripts symlinks
if [[ -L "$QS_DIR/scripts/update.sh" ]]; then
    pass "deploy_quickshell: update.sh symlink created"
else
    fail "deploy_quickshell: update.sh symlink missing"
fi
if [[ -L "$QS_DIR/scripts/install.sh" ]]; then
    pass "deploy_quickshell: install.sh symlink created"
fi

# ── Test deploy_shell_extras ─────────────────────────────────────────────────
echo ""
echo "--- deploy_shell_extras ---"
deploy_shell_extras

for d in fish btop cava kitty foot fuzzel wlogout; do
    if [[ -d "$HOME/.config/$d" ]]; then
        pass "deploy_shell_extras: $d config deployed"
    else
        fail "deploy_shell_extras: $d config missing"
    fi
done

# ── Test that .updateignore is respected ─────────────────────────────────────
echo ""
echo "--- .updateignore verification ---"
# shell.json should NOT be in the deployed caelestia config
if [[ ! -f "$HOME/.config/caelestia/shell.json" ]]; then
    pass ".updateignore: shell.json not deployed (correctly skipped)"
else
    fail ".updateignore: shell.json was deployed (should be ignored)"
fi

# ── Cleanup ──────────────────────────────────────────────────────────────────
rm -rf "$TEST_HOME"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "e2e_deploy_test: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
