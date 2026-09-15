#!/usr/bin/env bash
# TDD RED test: palette colors with custom alpha must use Qt.alpha(c, a),
# not manual channel decomposition Qt.rgba(c.r, c.g, c.b, a).
# (Colours.layer() is NOT equivalent: it applies transparency settings and
# luminance-shifts rgb. Qt.alpha() is pixel-identical to the decomposition.)
# Fails before the fix, passes after.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILES=(
    "$REPO_DIR/shell/modules/workspaceoverview/OverviewGrid.qml"
    "$REPO_DIR/shell/modules/drawers/Interactions.qml"
)
FAIL=0

echo "═══ qml_alpha_cleanup ═══"

for f in "${FILES[@]}"; do
    name=$(basename "$f")
    COUNT=$(grep -o "Colours\.palette\.[A-Za-z0-9_]*\.r," "$f" | wc -l)
    if [[ "$COUNT" -eq 0 ]]; then
        echo "  PASS $name: no manual channel decompositions"
    else
        echo "  FAIL $name: $COUNT manual decomposition(s) remain"
        FAIL=1
    fi
    # no decomposed green/blue channels may survive either
    for ch in g b; do
        CCOUNT=$(grep -o "Colours\.palette\.[A-Za-z0-9_]*\.$ch," "$f" | wc -l)
        if [[ "$CCOUNT" -ne 0 ]]; then
            echo "  FAIL $name: $CCOUNT '.$ch,' decompositions remain"
            FAIL=1
        fi
    done
done

# the conversions must preserve behavior: every Qt.alpha on a palette color
# keeps an explicit alpha value
ALPHA_USES=$(grep -o "Qt\.alpha(Colours\.palette\.[A-Za-z0-9_]*, [0-9.]*" "${FILES[@]}" | wc -l)
echo "  Qt.alpha palette uses: $ALPHA_USES"
if [[ "$ALPHA_USES" -ge 14 ]]; then
    echo "  PASS all translucent palette spots converted (expect ~15)"
else
    echo "  FAIL expected ~15 Qt.alpha conversions, found $ALPHA_USES"
    FAIL=1
fi

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (red - decompositions present)"
    exit 1
fi
echo "RESULT: PASS (green)"
