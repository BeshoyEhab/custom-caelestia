#!/usr/bin/env bash
# Every desktopClock config key exposed by the Clock settings page.
# The list is hardcoded from the design spec so a renamed/dropped binding fails
# here even when the QML still parses.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAGE="$REPO_DIR/shell/modules/nexus/pages/wallandstyle/ClockSettings.qml"

keys=(
    enabled
    clockStyle
    scale
    animatePosition
    invertColors
    quote.enabled
    quote.text
    background.enabled
    background.opacity
    background.blur
    shadow.enabled
    shadow.opacity
    shadow.blur
    digital.orientation
    digital.showDate
    digital.showSeconds
    digital.animateChange
    digital.adaptiveAlignment
    digital.font.family
    digital.font.size
    digital.font.weight
    digital.font.width
    digital.font.roundness
    cookie.useSineCookie
    cookie.sides
    cookie.constantlyRotate
    cookie.dateInClock
    cookie.hourMarks
    cookie.timeIndicators
    cookie.dialNumberStyle
    cookie.hourHandStyle
    cookie.minuteHandStyle
    cookie.secondHandStyle
    cookie.dateStyle
)

fail=0
for key in "${keys[@]}"; do
    if ! grep -q "desktopClock\.$key" "$PAGE"; then
        echo "FAIL: ClockSettings.qml does not bind desktopClock.$key"
        fail=1
    fi
done

if [[ $fail -ne 0 ]]; then
    echo "clock_settings: ${#keys[@]} keys checked, missing bindings found"
    exit 1
fi

echo "clock_settings: ${#keys[@]} keys bound in ClockSettings.qml"
