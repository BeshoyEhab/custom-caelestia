#!/usr/bin/env bash
# Wrapper so the node-based layout math suite runs from tests/run.sh.
set -euo pipefail
exec node "$(dirname "${BASH_SOURCE[0]}")/display_math_test.js"
