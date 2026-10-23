#!/usr/bin/env bash
# Guard the desktop-clock bindings against two runtime warning classes:
#
# 1. `Tokens.font.clock.family` — `FontBuilder::family()` is Q_INVOKABLE, not a
#    property, so the expression is a JS function. Assigning it to
#    `font.family` logs "Unable to assign a function to a property of any type
#    other than var" and leaves the font unset. Use `.build().family`.
#    `Tokens.font.regular` does not exist at all.
# 2. Per-monitor `Config.*` read inside a `Behavior` or `Connections` — those
#    attached objects are raw QObjects (not QQuickItems), so they cannot
#    inherit a screen and fall back to GlobalConfig with
#    "Config.<name> accessed without a screen set on ...".
#    Hoist the read to a binding on an item (which does inherit the screen).
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_DIR="$REPO_DIR/shell"
FAIL=0

fail() { echo "  FAIL $1"; FAIL=1; }
pass() { echo "  PASS $1"; }

echo "═══ qml_clock_bindings ═══"

# 1. No direct read of the FontBuilder::family() method.
FAMILY=$(grep -rn 'Tokens\.font\.clock\.family' "$SHELL_DIR" --include=*.qml --exclude-dir=upstream | wc -l)
[[ "$FAMILY" -eq 0 ]] \
    && pass "no Tokens.font.clock.family (use .build().family)" \
    || fail "$FAMILY Tokens.font.clock.family read(s) — FontBuilder::family() is a method"

# 2. No reference to a nonexistent Tokens.font.regular.
REGULAR=$(grep -rn 'Tokens\.font\.regular' "$SHELL_DIR" --include=*.qml --exclude-dir=upstream | wc -l)
[[ "$REGULAR" -eq 0 ]] \
    && pass "no Tokens.font.regular (property does not exist)" \
    || fail "$REGULAR Tokens.font.regular reference(s)"

# 3. The intended clock-family spelling is used at least once.
grep -rq 'Tokens\.font\.clock\.build()\.family' "$SHELL_DIR" --include=*.qml --exclude-dir=upstream \
    && pass "clock family read via .build().family" \
    || fail "no Tokens.font.clock.build().family use"

# 4. No per-monitor Config read inside a Behavior block.
BEHAVIOR=$(find "$SHELL_DIR" -name '*.qml' -not -path '*/upstream/*' -print0 | xargs -0 awk '
/Behavior[[:space:]]+on[[:space:]]/ { inb = 1; depth = 0 }
inb {
    d = gsub(/\{/, "{"); c = gsub(/\}/, "}"); depth += d - c
    if ($0 ~ /Config\./) printf "%s:%d\n", FILENAME, FNR
    if (depth <= 0) inb = 0
}' | wc -l)
[[ "$BEHAVIOR" -eq 0 ]] \
    && pass "no Config.* read inside a Behavior" \
    || fail "$BEHAVIOR Config.* read(s) inside Behavior blocks (screenless QQuickBehavior)"

# 5. No per-monitor Config read as a Connections target.
CONNECTIONS=$(grep -rn 'target:[[:space:]]*Config\.' "$SHELL_DIR" --include=*.qml --exclude-dir=upstream | wc -l)
[[ "$CONNECTIONS" -eq 0 ]] \
    && pass "no Config.* as a Connections target" \
    || fail "$CONNECTIONS Connections target(s) read Config.* (screenless QQmlConnections)"

# 6. The clock font builder is centralized in ClockText.qml.
CENTRAL=$(grep -rn 'Tokens\.font\.clock\.build()\.family' "$SHELL_DIR" \
    --include=*.qml --exclude-dir=upstream | grep -v 'modules/background/ClockText.qml' | wc -l)
[[ "$CENTRAL" -eq 0 ]] \
    && pass "clock family builder is centralized in ClockText.qml" \
    || fail "$CENTRAL clock family builder(s) outside ClockText.qml"

# 7. Digital-specific date formatting is centralized in ClockText.qml.
DIGITAL_DATES=$(grep -n 'Time\.format(' "$SHELL_DIR/modules/background/DigitalClock.qml" | wc -l)
[[ "$DIGITAL_DATES" -eq 0 ]] \
    && pass "DigitalClock uses ClockText date formatting" \
    || fail "$DIGITAL_DATES Time.format call(s) remain in DigitalClock.qml"

exit $FAIL
