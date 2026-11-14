#!/usr/bin/env bash
# Wrapper so the node-based launcher order-cache suite runs from tests/run.sh.
set -euo pipefail
exec node "$(dirname "${BASH_SOURCE[0]}")/launcher_order_test.js"
