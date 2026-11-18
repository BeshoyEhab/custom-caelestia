#!/usr/bin/env bash
# Wrapper so the node-based widget registry suite runs from tests/run.sh.
set -euo pipefail
exec node "$(dirname "${BASH_SOURCE[0]}")/widget_registry_test.js"
