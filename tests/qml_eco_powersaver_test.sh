#!/usr/bin/env bash
# TDD RED test: Eco / PowerSaver.
# Fails before the feature, passes after.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$REPO_DIR/shell"
FAIL=0

echo "=== qml_eco_powersaver ==="

check() { # check <desc> <file> <grep-pattern>
    if grep -q "$3" "$2"; then
        echo "  PASS $1"
    else
        echo "  FAIL $1"
        FAIL=1
    fi
}

# Service exists and is registered
check "PowerSaver singleton exists" "$S/services/PowerSaver.qml" "pragma Singleton"
check "PowerSaver exposes ecoActive" "$S/services/PowerSaver.qml" "ecoActive"
check "PowerSaver IPC target" "$S/services/PowerSaver.qml" 'target: "powerSaver"'
check "PowerSaver watches UPower" "$S/services/PowerSaver.qml" "UPower.onBattery"
check "PowerSaver eager-loaded" "$S/modules/ServiceLoader.qml" "PowerSaver"

# Phase-1 guards
check "Time seconds gated" "$S/services/Time.qml" "secondsNeeded"
check "Visualiser layer gated" "$S/modules/background/Visualiser.qml" "layer.enabled: .*opacity"

# Eco consumer wiring
check "Visualiser eco gate" "$S/modules/background/Visualiser.qml" "PowerSaver.ecoActive"
check "Video eco gate" "$S/services/VideoWallpaper.qml" "PowerSaver"
check "Cava eco bars" "$S/services/Audio.qml" "PowerSaver"
check "Media interval stretch" "$S/modules/dashboard/dash/Media.qml" "intervalStretch"
check "Details interval stretch" "$S/modules/dashboard/media/Details.qml" "intervalStretch"
check "NetworkUsage interval stretch" "$S/services/NetworkUsage.qml" "intervalStretch"

# Surfaces
check "Quick toggle eco" "$S/modules/utilities/cards/Toggles.qml" 'roleValue: "eco"'
check "UtilitiesPanel eco row" "$S/modules/nexus/pages/panels/UtilitiesPanel.qml" '"eco"'
check "Battery popout eco" "$S/modules/bar/popouts/Battery.qml" "PowerSaver\.ecoActive"
check "Nexus Power section" "$S/modules/nexus/pages/ServicesPage.qml" "PowerSaver"
check "C++ quick-toggle default" "$S/plugin/src/Caelestia/Config/utilitiesconfig.hpp" '"eco"'

# QML-side animation gates (eco drives durations.scale=0: freezes all
# durations-derived motion incl. every explicit override site, no per-site edits)
check "Anim scale eco drive" "$S/services/PowerSaver.qml" "durations.scale = 0"
check "Anim scale save/restore" "$S/services/PowerSaver.qml" "prevAnimScale"
check "Media wave eco gate" "$S/modules/dashboard/dash/Media.qml" "wavePaused:.*PowerSaver.ecoActive"
check "Details wave eco gate" "$S/modules/dashboard/media/Details.qml" "animateWave:.*PowerSaver.ecoActive"
check "Bongocat eco gate" "$S/modules/dashboard/dash/Media.qml" "playing:.*PowerSaver.ecoActive"

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (red - eco not implemented)"
    exit 1
fi
echo "RESULT: PASS (green)"
