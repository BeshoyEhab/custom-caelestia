#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Compat stub — all logic lives in install.sh now (unified setup script).
# Kept so deployed ~/.config/quickshell/caelestia/scripts/update.sh symlinks
# and the Nexus Updates page keep working unchanged.
# ═══════════════════════════════════════════════════════════════════════════
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install.sh" "$@"
