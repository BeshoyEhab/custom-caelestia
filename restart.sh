#!/bin/bash
# Quick restart script for shell development
# Usage:
#   ./restart.sh          — restart only (QML changes, no rebuild needed)
#   ./restart.sh --build  — rebuild C++ plugin THEN restart (for config.hpp changes)

BUILD=false
if [[ "$1" == "--build" ]]; then
    BUILD=true
fi

echo "Stopping shell..."
killall qs 2>/dev/null
sleep 0.5

if $BUILD; then
    echo "Building C++ plugin..."
    cd "$(dirname "$0")"
    cmake --build build 2>&1 | tail -5
    if [[ $? -ne 0 ]]; then
        echo "Build failed!"
        exit 1
    fi
fi

echo "Starting shell..."
qs -c caelestia &
disown
echo "Shell restarted."
