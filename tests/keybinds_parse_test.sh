#!/usr/bin/env bash
# Wrapper so the node-based keybind parser suite runs from tests/run.sh.
set -euo pipefail
exec node "$(dirname "${BASH_SOURCE[0]}")/keybinds_parse_test.js"
