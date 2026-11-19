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

# The dock is three widget-host regions, not hardcoded loaders/entry lists
grep -q 'WidgetHost' "$BAR_QML" && pass "Bar.qml hosts widgets" || fail "Bar.qml does not use WidgetHost"
grep -q 'startHost' "$BAR_QML" && pass "Bar.qml has startHost" || fail "Bar.qml missing startHost"
grep -q 'centerHost' "$BAR_QML" && pass "Bar.qml has centerHost" || fail "Bar.qml missing centerHost"
grep -q 'endHost' "$BAR_QML" && pass "Bar.qml has endHost" || fail "Bar.qml missing endHost"
grep -q 'TopLoader\|BottomLoader' "$BAR_QML" && fail "Bar.qml still has its old loaders" || pass "Bar.qml has no old loaders"
grep -q 'topEntries\|bottomEntries' "$BAR_QML" && fail "Bar.qml still hardcodes entry lists" || pass "Bar.qml has no hardcoded entry lists"
grep -q 'fromBarEntries' "$BAR_QML" && pass "Bar.qml migrates Config.bar.entries" || fail "Bar.qml does not migrate entries"
grep -q 'closeTray' "$BAR_QML" && pass "Bar.qml keeps tray handling" || fail "Bar.qml lost tray handling"
grep -q 'handleWheel' "$BAR_QML" && pass "Bar.qml keeps wheel actions" || fail "Bar.qml lost wheel actions"

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
[[ "$count" -ge 7 ]] && pass "innerWidth referenced in $count bar files" || fail "innerWidth only in $count bar files (expected >=7)"

# ── 4. Check bar entry IDs match actual components ────────────────────────────
# Now hosted through the registry: id -> component lives in WidgetCatalog.qml
# (componentFor switch) and builtin/ (the adapters wrap the original bar
# components, e.g. DockLogo wraps OsIcon), so grep those instead of Bar.qml.
# Bar uses: logo, workspaces, activeWindow, tray, clock, statusIcons, power
declare -A entry_map
entry_map["logo"]="OsIcon"
entry_map["workspaces"]="Workspaces"
entry_map["activeWindow"]="ActiveWindow"
entry_map["tray"]="Tray"
entry_map["clock"]="Clock"
entry_map["statusIcons"]="StatusIcons"
entry_map["power"]="Power"

CATALOG_QML="$SHELL_DIR/modules/widgets/WidgetCatalog.qml"
BUILTIN_DIR="$SHELL_DIR/modules/widgets/builtin"

for entry in "${!entry_map[@]}"; do
    comp="${entry_map[$entry]}"
    if grep -qi "$comp" "$CATALOG_QML" 2>/dev/null \
        || grep -rqi "$comp" "$BUILTIN_DIR" 2>/dev/null; then
        pass "Bar entry '$entry' -> '$comp' referenced"
    else
        fail "Bar entry '$entry' -> '$comp' NOT referenced in WidgetCatalog.qml/builtin"
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

# ── 8. Widget host/frame contract ────────────────────────────────────────────
WIDGETS_DIR="$SHELL_DIR/modules/widgets"

[[ -f "$WIDGETS_DIR/WidgetHost.qml" ]] && pass "WidgetHost.qml exists" || fail "WidgetHost.qml missing"
[[ -f "$WIDGETS_DIR/WidgetFrame.qml" ]] && pass "WidgetFrame.qml exists" || fail "WidgetFrame.qml missing"

grep -q '^ColumnLayout' "$WIDGETS_DIR/WidgetHost.qml" && pass "WidgetHost root is ColumnLayout" || fail "WidgetHost root is not ColumnLayout"
grep -q 'ScriptModel' "$WIDGETS_DIR/WidgetHost.qml" && pass "WidgetHost uses ScriptModel" || fail "WidgetHost does not use ScriptModel"
# Disabled items must be filtered out: validateItems keeps them, so the host
# has to render through visibleItems or a disabled widget would still show.
grep -q 'visibleItems' "$WIDGETS_DIR/WidgetHost.qml" && pass "WidgetHost filters disabled items" || fail "WidgetHost does not filter disabled items"
grep -q 'ComponentBehavior: Bound' "$WIDGETS_DIR/WidgetHost.qml" && fail "WidgetHost must not use ComponentBehavior: Bound" || pass "WidgetHost is unbound"
grep -qE '^\s*implicit(Width|Height)\s*:' "$WIDGETS_DIR/WidgetHost.qml" && fail "WidgetHost must size itself from the layout" || pass "WidgetHost takes implicit size from the layout"
grep -q 'function hitTest' "$WIDGETS_DIR/WidgetHost.qml" && pass "WidgetHost exposes hitTest" || fail "WidgetHost missing hitTest"

grep -q 'createObject' "$WIDGETS_DIR/WidgetFrame.qml" && pass "WidgetFrame creates the widget with initial properties" || fail "WidgetFrame missing createObject"
grep -q 'errorText' "$WIDGETS_DIR/WidgetFrame.qml" && pass "WidgetFrame reports widget failures" || fail "WidgetFrame missing errorText"
grep -q 'entryId' "$WIDGETS_DIR/WidgetFrame.qml" && pass "WidgetFrame exposes entryId" || fail "WidgetFrame missing entryId"

# ── 9. Widget creation-order pin (review fix 94fabd8f) ───────────────────────
# The frame builds in its own Component.onCompleted, so the delegate must
# supply the frame's inputs as bindings (initial properties) and the host
# must derive its frames from the repeater.
grep -qPz 'delegate: WidgetFrame\s*\{[^}]*required property var modelData[^}]*item:\s*modelData' \
    "$WIDGETS_DIR/WidgetHost.qml" \
    && pass "WidgetHost delegate supplies item as an initial property" \
    || fail "WidgetHost delegate does not supply item as an initial property"
grep -qPz 'delegate: WidgetFrame\s*\{[^}]*hostContext:\s*root\.hostContext' \
    "$WIDGETS_DIR/WidgetHost.qml" \
    && pass "WidgetHost delegate forwards hostContext" \
    || fail "WidgetHost delegate missing hostContext"
grep -q 'Component\.onCompleted' "$WIDGETS_DIR/WidgetHost.qml" \
    && fail "WidgetHost must not assign frame inputs imperatively" \
    || pass "WidgetHost assigns frame inputs via bindings only"
grep -q 'frameList' "$WIDGETS_DIR/WidgetHost.qml" \
    && fail "WidgetHost must derive frames from the repeater" \
    || pass "WidgetHost frames are derived from the repeater"
grep -q 'onItemChanged' "$WIDGETS_DIR/WidgetFrame.qml" \
    && pass "WidgetFrame rebuilds when item changes" \
    || fail "WidgetFrame missing onItemChanged"
grep -q 'destroy()' "$WIDGETS_DIR/WidgetFrame.qml" \
    && pass "WidgetFrame destroys replaced widgets on rebuild" \
    || fail "WidgetFrame missing destroy() on rebuild"

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "widget_test: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
