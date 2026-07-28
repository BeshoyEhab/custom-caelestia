#!/usr/bin/env bash
# Install script tests
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0

pass() { echo -e "  \033[0;32mPASS\033[0m $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  \033[0;31mFAIL\033[0m $1"; FAIL=$((FAIL + 1)); }

# ── 1. Shell syntax ────────────────────────────────────────────────────────────
bash -n install.sh       && pass "install.sh syntax"       || fail "install.sh syntax"
bash -n update.sh        && pass "update.sh syntax"        || fail "update.sh syntax"
bash -n build-plugin.sh  && pass "build-plugin.sh syntax"  || fail "build-plugin.sh syntax"

# ── 2. Source install.sh functions ────────────────────────────────────────────
export CI_TEST=true
install_pkg() { :; }
sudo() { "$@"; }
source install.sh && pass "install.sh functions sourced" || fail "install.sh functions sourced"

# ── 3. should_ignore patterns ──────────────────────────────────────────────────
load_ignore_patterns
test_ignore() {
    local desc="$1" path="$2" expected="$3"
    local got=0
    should_ignore "$path" "$path" || got=$?
    if [[ "$got" -eq "$expected" ]]; then
        pass "ignore: $desc"
    else
        fail "ignore: $desc (expected $expected, got $got)"
    fi
}

test_ignore "monitors.lua" "monitors.lua" 0
test_ignore "shell.json" "shell.json" 0
test_ignore "custom/foo" "custom/anything" 0
test_ignore "custom/bar/file" "custom/deep/nested/file" 0
test_ignore "regular file" "hyprland.conf" 1
test_ignore "qml file" "Bar.qml" 1

# ── 4. safe_deploy dry run ────────────────────────────────────────────────────
TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

SRC="$TMPDIR/src"
DST="$TMPDIR/dst"
mkdir -p "$SRC/sub" "$DST"

echo "hello" > "$SRC/file1.txt"
# Ensure src mtime is in the past before we modify dst later
sleep 1.1
echo "world" > "$SRC/sub/file2.txt"

safe_deploy "$SRC" "$DST"

if [[ -f "$DST/file1.txt" ]]; then
    pass "safe_deploy: file1.txt copied"
else
    fail "safe_deploy: file1.txt missing"
fi

if [[ -f "$DST/sub/file2.txt" ]]; then
    pass "safe_deploy: sub/file2.txt copied"
else
    fail "safe_deploy: sub/file2.txt missing"
fi

# Test that existing files are NOT overwritten in pass 2 (user-modified = newer)
sleep 1.1
echo "modified" > "$DST/file1.txt"
safe_deploy "$SRC" "$DST"
content=$(cat "$DST/file1.txt")
if [[ "$content" == "modified" ]]; then
    pass "safe_deploy: existing file preserved (user-modified)"
else
    fail "safe_deploy: existing file was overwritten (got: $content)"
fi

# ── 5. .updateignore in safe_deploy ────────────────────────────────────────────
IGNORE_PATTERNS=("ignored.txt")
mkdir -p "$SRC/ignore_test"
echo "should not appear" > "$SRC/ignore_test/ignored.txt"
echo "should appear" > "$SRC/ignore_test/ok.txt"
DST2="$TMPDIR/dst2"
mkdir -p "$DST2"
safe_deploy "$SRC/ignore_test" "$DST2"

if [[ ! -f "$DST2/ignored.txt" ]]; then
    pass "safe_deploy: ignored file skipped"
else
    fail "safe_deploy: ignored file was copied"
fi

if [[ -f "$DST2/ok.txt" ]]; then
    pass "safe_deploy: non-ignored file copied"
else
    fail "safe_deploy: non-ignored file missing"
fi

# ── 6. deploy_quickshell removes existing symlinks ──────────────────────────
# Simulate the symlink check from deploy_quickshell
SYML_TEST="$TMPDIR/syml_test/caelestia"
mkdir -p "$TMPDIR/syml_test"
ln -sf /nonexistent "$SYML_TEST"
if [[ -L "$SYML_TEST" ]]; then
    rm -f "$SYML_TEST"
    safe_deploy "$SRC" "$SYML_TEST"
    if [[ -d "$SYML_TEST" ]] && [[ ! -L "$SYML_TEST" ]]; then
        pass "deploy_quickshell: symlink removed, then safe_deploy created directory"
    else
        fail "deploy_quickshell: target not a directory after symlink removal + deploy"
    fi
else
    fail "deploy_quickshell: could not create test symlink"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "install_test: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
