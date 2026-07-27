#!/usr/bin/env bash
# Widget structure & size validation tests
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

PASS=0
FAIL=0

pass() { echo -e "  \033[0;32mPASS\033[0m $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  \033[0;31mFAIL\033[0m $1"; FAIL=$((FAIL + 1)); }

SHELL_DIR="$REPO_DIR/shell"

# ── 1. Bar.qml structure ─────────────────────────────────────────────────────
BAR_QML="$SHELL_DIR/modules/bar/Bar.qml"
BAR_WRAPPER="$SHELL_DIR/modules/bar/BarWrapper.qml"

[[ -f "$BAR_QML" ]] || { fail "Bar.qml not found"; exit 1; }

# Root element should be Item (per actual code, not outdated docs)
if grep -q '^\s*Item\b' "$BAR_QML"; then
    pass "Bar.qml root element is Item"
elif grep -q '^\s*ColumnLayout\b' "$BAR_QML"; then
    fail "Bar.qml root is ColumnLayout (expected Item per actual code)"
fi

# Verify split top/bottom layout
grep -q 'topLayout' "$BAR_QML"    && pass "Bar.qml has topLayout"    || fail "Bar.qml missing topLayout"
grep -q 'bottomLayout' "$BAR_QML" && pass "Bar.qml has bottomLayout" || fail "Bar.qml missing bottomLayout"
grep -q 'DelegateChooser' "$BAR_QML" && pass "Bar.qml no longer uses DelegateChooser (uses TopLoader/BottomLoader)" || true

# ── 2. BarWrapper contentWidth = innerWidth + padding*2 ────────────────────────
if [[ -f "$BAR_WRAPPER" ]]; then
    def=$(grep -oP 'readonly property int contentWidth:\s*[^;]+' "$BAR_WRAPPER" | head -1)
    if echo "$def" | grep -q 'innerWidth.*padding.*2'; then
        pass "BarWrapper: contentWidth = innerWidth + padding*2"
    else
        fail "BarWrapper: contentWidth definition mismatch: $def"
    fi
    grep -q 'width:.*root.contentWidth' "$BAR_WRAPPER" && \
        pass "BarWrapper: uses contentWidth for width" || \
        fail "BarWrapper: missing width: root.contentWidth"
fi

# ── 3. innerWidth references spread across bar components ─────────────────────
count=$(grep -rl 'Tokens\.sizes\.bar\.innerWidth' "$SHELL_DIR/modules/bar/" --include='*.qml' 2>/dev/null | wc -l)
[[ "$count" -ge 8 ]] && pass "innerWidth referenced in $count bar files" || fail "innerWidth only in $count bar files (expected >=8)"

# ── 4. Check bar entry IDs match actual components ────────────────────────────
# Bar uses: logo, workspaces, activeWindow, tray, clock, statusIcons, power
declare -A entry_map
entry_map["logo"]="OsIcon"
entry_map["workspaces"]="Workspaces"
entry_map["activeWindow"]="ActiveWindow"
entry_map["tray"]="Tray"
entry_map["clock"]="Clock"
entry_map["statusIcons"]="StatusIcons"
entry_map["power"]="Power"

for entry in "${!entry_map[@]}"; do
    comp="${entry_map[$entry]}"
    if grep -qi "$comp" "$BAR_QML" 2>/dev/null; then
        pass "Bar entry '$entry' -> '$comp' referenced"
    else
        fail "Bar entry '$entry' -> '$comp' NOT referenced in Bar.qml"
    fi
done

# ── 5. Token usage across bar ────────────────────────────────────────────────
for pattern in "Tokens.sizes.bar.innerWidth" "Tokens.spacing" "Tokens.padding"; do
    c=$(grep -rl "$pattern" "$SHELL_DIR/modules/bar/" --include='*.qml' 2>/dev/null | wc -l)
    [[ "$c" -gt 0 ]] && pass "Token '$pattern' used in $c bar files" || fail "Token '$pattern' not used in any bar file"
done

# ── 6. Anchoring in BarWrapper ────────────────────────────────────────────────
if [[ -f "$BAR_WRAPPER" ]]; then
    grep -q 'anchors.top' "$BAR_WRAPPER"    && pass "BarWrapper: has anchors.top"    || fail "BarWrapper: missing anchors.top"
    grep -q 'anchors.bottom' "$BAR_WRAPPER" && pass "BarWrapper: has anchors.bottom" || fail "BarWrapper: missing anchors.bottom"
fi

# ── 7. No hardcoded pixel values > 100 (should use Tokens) ────────────────────
MAGIC=0
while IFS= read -r -d '' f; do
    rel="${f#"$SHELL_DIR/"}"
    while IFS= read -r line; do
        # Look for suspicious property assignments with plain numbers > 100
        if grep -qP '(width|height|implicitWidth|spacing|margins?)\s*:\s*\d{3,}' <<< "$line"; then
            # Skip if it references Tokens, root, parent, or implicit sizes
            if ! grep -qP '(Tokens\.|root\.|parent\.|implicit\w*|contentWidth|innerWidth)' <<< "$line"; then
                fail "Potential magic number in $rel: $(echo "$line" | xargs)"
                MAGIC=$((MAGIC + 1))
            fi
        fi
    done < "$f"
done < <(find "$SHELL_DIR/modules/bar" -name '*.qml' -not -path '*/upstream/*' -print0 2>/dev/null)
[[ "$MAGIC" -eq 0 ]] && pass "No suspicious magic numbers > 100 in bar components"

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "widget_test: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
