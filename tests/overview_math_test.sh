#!/usr/bin/env bash
# Wrapper so the node-based overview math suite runs from tests/run.sh.
set -euo pipefail
exec node "$(dirname "${BASH_SOURCE[0]}")/overview_math_test.js"
