#!/usr/bin/env bash
# Wrapper so the node-based clock colour suite runs from tests/run.sh.
set -euo pipefail
exec node "$(dirname "${BASH_SOURCE[0]}")/clock_colours_test.js"
