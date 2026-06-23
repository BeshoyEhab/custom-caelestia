#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# build-plugin.sh - Build & install ALL plugins from custom-caelestia
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
INSTALL_DIR="/usr/lib/qt6/qml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[x]${NC} $1"; exit 1; }

[[ -f "$SCRIPT_DIR/CMakeLists.txt" ]] || err "Not a custom-caelestia directory: $SCRIPT_DIR"
[[ -f "$SCRIPT_DIR/shell/plugin/CMakeLists.txt" ]] || err "Plugin source not found"

# ── Configure ──────────────────────────────────────────────────────────────
log "Configuring build..."
mkdir -p "$BUILD_DIR"
cmake -B "$BUILD_DIR" -S "$SCRIPT_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_MODULES="plugin"

# ── Build ──────────────────────────────────────────────────────────────────
NPROC=$(nproc 2>/dev/null || echo 4)
log "Building plugin ($NPROC threads)..."
cmake --build "$BUILD_DIR" -j"$NPROC"

# ── Install (needs sudo) ──────────────────────────────────────────────────
log "Installing to $INSTALL_DIR ..."

# Find and copy all built plugin .so files
find "$BUILD_DIR" -name "libcaelestia-*.so" -type f | while read -r lib; do
    modname=$(basename "$lib")
    # Extract module path from filename: libcaelestia-config.so -> Caelestia/Config/
    subdir=$(echo "$modname" | sed 's/^libcaelestia-//;s/\.so$//' | sed 's/\b\(.\)/\U\1/')
    target_dir="$INSTALL_DIR/Caelestia/$subdir"
    sudo mkdir -p "$target_dir"
    sudo cp -p "$lib" "$target_dir/$modname"
    echo "  Installed: $modname -> $target_dir/"
done

# Copy plugin loader .so files
find "$BUILD_DIR" -name "libcaelestia-*plugin.so" -type f | while read -r lib; do
    modname=$(basename "$lib")
    subdir=$(echo "$modname" | sed 's/^libcaelestia-//;s/plugin\.so$//' | sed 's/\b\(.\)/\U\1/')
    target_dir="$INSTALL_DIR/Caelestia/$subdir"
    sudo mkdir -p "$target_dir"
    sudo cp -p "$lib" "$target_dir/$modname"
    echo "  Installed: $modname -> $target_dir/"
done

log "Done! Plugin rebuilt from custom-caelestia."
log "Restart quickshell: pkill quickshell && qs -c caelestia &"
