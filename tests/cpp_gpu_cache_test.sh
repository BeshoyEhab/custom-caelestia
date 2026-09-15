#!/usr/bin/env bash
# TDD RED test: readGenericUsage must not directory-scan /sys/class/drm every tick.
# Card topology is static; paths must be resolved once and cached, re-scanning only
# when a cached file disappears (hotplug). Fails before the fix, passes after.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HPP="$REPO_DIR/shell/plugin/src/Caelestia/Services/gpu.hpp"
CPP="$REPO_DIR/shell/plugin/src/Caelestia/Services/gpu.cpp"
FAIL=0

echo "═══ cpp_gpu_cache ═══"

BODY=$(awk '/void Gpu::readGenericUsage/,/^}/' "$CPP")

# The directory scan may exist only as a guarded one-time population, never unconditional.
GUARD_LINE=$(echo "$BODY" | grep -n "m_genericPaths.isEmpty()" | head -1 | cut -d: -f1)
SCAN_LINE=$(echo "$BODY" | grep -n "entryList" | head -1 | cut -d: -f1)
if [[ -z "$SCAN_LINE" ]]; then
    echo "  PASS readGenericUsage has no directory scan at all"
elif [[ -n "$GUARD_LINE" && "$GUARD_LINE" -lt "$SCAN_LINE" ]]; then
    echo "  PASS directory scan is cache-guarded (guard line $GUARD_LINE, scan line $SCAN_LINE)"
else
    echo "  FAIL readGenericUsage scans directory unconditionally every tick"
    FAIL=1
fi

if grep -q "m_genericPaths" "$HPP" && echo "$BODY" | grep -q "m_genericPaths"; then
    echo "  PASS cached path list declared and used"
else
    echo "  FAIL no cached path list (m_genericPaths) declared/used"
    FAIL=1
fi

# hotplug safety: a vanished card file must invalidate the cache
if echo "$BODY" | grep -q "m_genericPaths.clear()\|m_genericPaths = \|m_genericPaths.clear"; then
    echo "  PASS cache invalidated when topology changes"
else
    echo "  FAIL cache never invalidated (hotplug would read stale paths forever)"
    FAIL=1
fi

# averaging + epsilon + signal behavior must be preserved
echo "$BODY" | grep -q "percentageChanged" && echo "  PASS still emits percentageChanged" || { echo "  FAIL percentageChanged emission lost"; FAIL=1; }

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (red - per-tick rescan present)"
    exit 1
fi
echo "RESULT: PASS (green)"
