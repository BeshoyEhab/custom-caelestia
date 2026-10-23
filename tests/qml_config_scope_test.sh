#!/usr/bin/env bash
# Guard the one screen/config resolution policy:
# 1. Config/Tokens resolve a screen from the nearest item/window in C++.
# 2. Screenless singletons use GlobalConfig, never bare Config.
# 3. Explicit other-screen reads use GlobalConfig.forScreen, never Config.forScreen.
# 4. Global-only reads through an overlay are debug-level; writes still warn.
# 5. The overlay's startup sync is guarded from write warnings.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_DIR="$REPO_DIR/shell"
CFG="$SHELL_DIR/plugin/src/Caelestia/Config"
FAIL=0

fail() { echo "  FAIL $1"; FAIL=1; }
pass() { echo "  PASS $1"; }

echo "═══ qml_config_scope ═══"

# 1. Shared resolver exists and both attached types use it.
if [[ -f "$CFG/screenresolver.hpp" ]]; then
    pass "screenresolver.hpp exists"
else
    fail "missing $CFG/screenresolver.hpp"
fi
for f in configattached.cpp tokensattached.cpp; do
    if grep -q 'screenNameForObject<' "$CFG/$f"; then
        pass "$f uses screenNameForObject"
    else
        fail "$f does not use screenNameForObject"
    fi
done
if grep -q 'QQuickItem' "$CFG/screenresolver.hpp" && grep -q 'QQuickWindow' "$CFG/screenresolver.hpp"; then
    pass "resolver walks items and windows"
else
    fail "resolver does not walk items/windows"
fi

# 2. The old warning class is gone.
HITS=$(grep -rn 'accessed without a screen set' "$CFG" | wc -l)
if [[ "$HITS" -eq 0 ]]; then
    pass "no 'accessed without a screen set' warning"
else
    fail "$HITS old screenless warnings remain"
fi

# 3. Screenless singletons do not use bare Config.
BARE=$(grep -rnE '(^|[^A-Za-z0-9_.])Config\.' "$SHELL_DIR/services" --include='*.qml' | wc -l)
if [[ "$BARE" -eq 0 ]]; then
    pass "no bare Config.* in shell/services singletons"
else
    fail "$BARE bare Config.* read(s) in shell/services"
fi

# 4. One spelling for explicit other-screen config.
FORSCREEN=$(grep -rnE '(^|[^A-Za-z0-9_.])Config\.forScreen' "$SHELL_DIR" --include='*.qml' --exclude-dir=upstream | wc -l)
if [[ "$FORSCREEN" -eq 0 ]]; then
    pass "no Config.forScreen in QML"
else
    fail "$FORSCREEN Config.forScreen call(s); use GlobalConfig.forScreen"
fi

# 5. Global-only reads are debug; writes are still warnings and sync is guarded.
READ=$(grep -c 'qCDebug(caelestia::config::lcConfig, "Reading global-only option' "$CFG/configobject.hpp" || true)
WRITE=$(grep -c 'qCWarning(caelestia::config::lcConfig, "Writing global-only option' "$CFG/configobject.hpp" || true)
SYNC=$(grep -c 'QScopedValueRollback<bool>' "$CFG/configobject.cpp" || true)
if [[ "$READ" -eq 1 && "$WRITE" -eq 1 && "$SYNC" -ge 2 ]]; then
    pass "global-only read is debug, write is warning, sync is guarded"
else
    fail "global-only warning policy is not implemented (read=$READ write=$WRITE sync=$SYNC)"
fi

exit $FAIL
