#!/bin/bash
# Deploy source files to installed config
# Usage: ./deploy.sh          — deploy QML only, restart shell
#        ./deploy.sh --build  — also rebuild C++ plugin (for barconfig.hpp changes)
#
# Syncs every *.qml under shell/ (except shell/plugin/) into the running
# config, so newly added/renamed files are deployed and files deleted from
# the repo are removed from the running config. No manual file list to drift.

set -u

BUILD=false
if [[ "${1:-}" == "--build" ]]; then
    BUILD=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/shell"
DST="$HOME/.config/quickshell/caelestia"

[[ -d "$SRC" ]] || { echo "Source not found: $SRC"; exit 1; }

echo "Deploying QML files..."
deployed=0
while IFS= read -r src_file; do
    rel="${src_file#$SRC/}"
    dst_file="$DST/$rel"
    mkdir -p "$(dirname "$dst_file")"
    cp "$src_file" "$dst_file"
    deployed=$((deployed + 1))
done < <(find "$SRC" -name "*.qml" -not -path "$SRC/plugin/*")
echo "Deployed $deployed files."

echo "Removing stale files..."
removed=0
while IFS= read -r dst_file; do
    rel="${dst_file#$DST/}"
    # Never touch user customizations or state
    case "$rel" in custom/*|shell.json*) continue ;; esac
    if [[ ! -f "$SRC/$rel" ]]; then
        rm -f "$dst_file"
        removed=$((removed + 1))
    fi
done < <(find "$DST" -name "*.qml" 2>/dev/null)
echo "Removed $removed stale files."

if $BUILD; then
    echo "Building C++ plugin..."
    cd "$SCRIPT_DIR"
    touch shell/plugin/src/Caelestia/Config/barconfig.hpp
    cmake --build build 2>&1 | tail -5
    if [[ $? -ne 0 ]]; then
        echo "Build failed!"
        exit 1
    fi
fi

echo "Restarting shell..."
killall qs 2>/dev/null
sleep 0.5
# setsid detaches so the shell survives the parent terminal/session ending.
# Startup output goes to a log (never /dev/null) so failed launches stay visible.
setsid qs -c caelestia > /tmp/qs-deploy.log 2>&1 < /dev/null &
echo "Done."
