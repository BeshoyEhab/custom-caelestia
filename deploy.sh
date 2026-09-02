#!/bin/bash
# Deploy source files to installed config
# Usage: ./deploy.sh          — deploy QML only, restart shell
#        ./deploy.sh --build  — also rebuild C++ plugin (for barconfig.hpp changes)

BUILD=false
if [[ "$1" == "--build" ]]; then
    BUILD=true
fi

SRC="/home/Bisho/custom-caelestia/shell"
DST="/home/Bisho/.config/quickshell/caelestia"

echo "Deploying QML files..."

# Services
cp "$SRC/services/Hypr.qml" "$DST/services/"
cp "$SRC/services/Notifs.qml" "$DST/services/"

# Components
cp "$SRC/components/DrawerVisibilities.qml" "$DST/components/"

# Modules
cp "$SRC/modules/Shortcuts.qml" "$DST/modules/"
cp "$SRC/modules/drawers/Panels.qml" "$DST/modules/drawers/"
cp "$SRC/modules/drawers/ContentWindow.qml" "$DST/modules/drawers/"
cp "$SRC/modules/bar/Bar.qml" "$DST/modules/bar/"
cp "$SRC/modules/bar/popouts/Content.qml" "$DST/modules/bar/popouts/"
cp "$SRC/modules/bar/popouts/PopoutState.qml" "$DST/modules/bar/popouts/"
cp "$SRC/modules/bar/popouts/Wrapper.qml" "$DST/modules/bar/popouts/"
cp "$SRC/modules/bar/components/workspaces/Workspace.qml" "$DST/modules/bar/components/workspaces/"
cp "$SRC/modules/bar/components/workspaces/Workspaces.qml" "$DST/modules/bar/components/workspaces/"
cp "$SRC/modules/bar/components/workspaces/ActiveIndicator.qml" "$DST/modules/bar/components/workspaces/"
cp "$SRC/modules/nexus/pages/panels/taskbar/BarWorkspaces.qml" "$DST/modules/nexus/pages/panels/taskbar/"

# Sidebar
cp "$SRC/modules/sidebar/NotifDock.qml" "$DST/modules/sidebar/"
cp "$SRC/modules/sidebar/NotifDockList.qml" "$DST/modules/sidebar/"
cp "$SRC/modules/sidebar/NotifGroup.qml" "$DST/modules/sidebar/"

# Workspace overview (new module)
mkdir -p "$DST/modules/workspaceoverview"
cp "$SRC/modules/workspaceoverview/"*.qml "$DST/modules/workspaceoverview/"

# Background clock
cp "$SRC/modules/background/DesktopClock.qml" "$DST/modules/background/"
cp "$SRC/modules/background/ClockText.qml" "$DST/modules/background/"

echo "Deployed."

if $BUILD; then
    echo "Building C++ plugin..."
    cd "$(dirname "$0")"
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
qs -c caelestia &
disown
echo "Done."
