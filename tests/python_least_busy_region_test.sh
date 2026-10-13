#!/usr/bin/env bash
# TDD test: desktop clock auto-placement analysis (least_busy_region.py).
# Finds the flattest/noisiest region of the wallpaper so Background.qml can
# snap the desktop clock there (position = auto-empty / auto-full).
# Fails before the script exists, passes after.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "═══ python_least_busy_region ═══"

if python3 -c "import numpy, PIL" 2>/dev/null; then
    python3 -m pytest "$REPO_DIR/tests/test_least_busy_region.py" -q
else
    echo "  SKIP numpy/Pillow not available"
fi
