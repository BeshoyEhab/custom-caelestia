#!/usr/bin/env bash
# Guard the ClipRect port (upstream e62207a3): the old Quickshell clipping
# types are deleted, so any surviving reference is a boot-time
# "StyledClippingRect is not a type" failure. Also pins the C++ side that
# ClipRect.qml needs (RoundedMask + its shader) and the two small service
# hunks ported in the same sync.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_DIR="$REPO_DIR/shell"
PLUGIN_DIR="$SHELL_DIR/plugin/src/Caelestia/Components"
FAIL=0

fail() { echo "  FAIL $1"; FAIL=1; }
pass() { echo "  PASS $1"; }

echo "═══ qml_cliprect ═══"

# 1. The new type exists, the old one is gone.
[[ -s "$SHELL_DIR/components/ClipRect.qml" ]] && pass "ClipRect.qml exists" || fail "ClipRect.qml missing/empty"
[[ ! -e "$SHELL_DIR/components/StyledClippingRect.qml" ]] && pass "StyledClippingRect.qml removed" || fail "StyledClippingRect.qml still present"

# 2. No call site still uses a deleted type (shell/upstream is a vendored copy).
OLD_REFS=$(grep -rn "StyledClippingRect\|ClippingRectangle" "$SHELL_DIR" --include=*.qml --exclude-dir=upstream | wc -l)
[[ "$OLD_REFS" -eq 0 ]] && pass "no StyledClippingRect/ClippingRectangle references" || fail "$OLD_REFS stale clipping-type reference(s)"

# 3. Every ClipRect site can resolve the type.
SITES=$(grep -rn "ClipRect {" "$SHELL_DIR" --include=*.qml --exclude-dir=upstream | wc -l)
[[ "$SITES" -eq 15 ]] && pass "15 ClipRect sites" || fail "expected 15 ClipRect sites, found $SITES"
while IFS= read -r f; do
    grep -q '^import qs\.components' "$f" || fail "$(basename "$f") uses ClipRect without importing qs.components"
done < <(grep -rl "ClipRect {" "$SHELL_DIR" --include=*.qml --exclude-dir=upstream)

# 4. The C++ side is wired into the module.
grep -q 'roundedmask\.cpp' "$PLUGIN_DIR/CMakeLists.txt" \
    && pass "roundedmask.cpp in Components CMakeLists" \
    || fail "roundedmask.cpp missing from Components CMakeLists"
grep -q 'qt_add_shaders(caelestia-components' "$PLUGIN_DIR/CMakeLists.txt" \
    && pass "roundedmask shaders wired via qt_add_shaders" \
    || fail "qt_add_shaders block missing"
[[ -s "$PLUGIN_DIR/roundedmask.cpp" && -s "$PLUGIN_DIR/shaders/roundedmask.frag" && -s "$PLUGIN_DIR/shaders/roundedmask.vert" ]] \
    && pass "roundedmask sources present" \
    || fail "roundedmask sources missing"

# 5. Service hunks from the same sync (upstream f7447a81, 588562ea).
CODE66=$(grep -c 'code:66' "$SHELL_DIR/services/Hypr.qml")
[[ "$CODE66" -eq 2 ]] && pass "code:66 Caps Lock bind in both branches" || fail "expected 2 code:66 bindings, found $CODE66"
GIF_GUARD=$(grep -c 'sessionGif\.trim()' "$SHELL_DIR/modules/session/Content.qml")
[[ "$GIF_GUARD" -eq 1 ]] && pass "session gif gated on non-empty path" || fail "expected 1 sessionGif.trim() guard, found $GIF_GUARD"

exit "$FAIL"
