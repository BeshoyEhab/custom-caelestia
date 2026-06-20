pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.bar as Bar
import qs.modules.bar.popouts as BarPopouts

CustomMouseArea {
    id: root

    required property ShellScreen screen
    required property BarPopouts.Wrapper popouts
    required property DrawerVisibilities visibilities
    required property Panels panels
    required property Bar.BarWrapper bar
    required property real borderThickness
    required property bool fullscreen

    property point dragStart
    property bool dashboardShortcutActive
    property bool osdShortcutActive
    property bool utilitiesShortcutActive
    property bool sidebarShortcutActive

    function withinPanelHeight(panel: Item, x: real, y: real): bool {
        const panelY = root.borderThickness + panel.y;
        return y >= panelY - Config.border.rounding && y <= panelY + panel.height + Config.border.rounding;
    }

    function withinPanelWidth(panel: Item, x: real, y: real): bool {
        const panelX = bar.implicitWidth + panel.x;
        return x >= panelX - Config.border.rounding && x <= panelX + panel.width + Config.border.rounding;
    }

    function inLeftPanel(panel: Item, x: real, y: real): bool {
        return x < bar.implicitWidth + panel.x + panel.width && withinPanelHeight(panel, x, y);
    }

    function inRightPanel(panel: Item, x: real, y: real): bool {
        return x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panel.x) && withinPanelHeight(panel, x, y);
    }

    function inTopPanel(panel: Item, x: real, y: real): bool {
        const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0)); // qmllint disable missing-property
        return y < Math.max(Config.border.minThickness, Config.border.thickness + panelHeight) && withinPanelWidth(panel, x, y);
    }

    function inBottomPanel(panel: Item, x: real, y: real, isCorner = false): bool {
        const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0)); // qmllint disable missing-property
        return y > height - Math.max(Config.border.minThickness, Config.border.thickness + panelHeight) - (isCorner ? Config.border.rounding : 0) && withinPanelWidth(panel, x, y);
    }

    function inHoverArea(panel: Item, x: real, y: real, edge: string, hoverWidth: real, hoverHeight: real): bool {
        const g = hoverAreaGeometry(edge, hoverWidth, hoverHeight);
        return x >= g.x && x <= g.x + g.width && y >= g.y && y <= g.y + g.height;
    }

    function hoverAreaGeometry(edge: string, hoverWidth: real, hoverHeight: real): rect {
        if (edge === "top")
            return Qt.rect((width - hoverWidth) / 2, 0, hoverWidth, hoverHeight);
        if (edge === "bottom")
            return Qt.rect((width - hoverWidth) / 2, height - hoverHeight, hoverWidth, hoverHeight);
        if (edge === "left")
            return Qt.rect(0, (height - hoverHeight) / 2, hoverWidth, hoverHeight);
        if (edge === "right")
            return Qt.rect(width - hoverWidth, (height - hoverHeight) / 2, hoverWidth, hoverHeight);
        if (edge === "topLeft")
            return Qt.rect(0, 0, hoverWidth, hoverHeight);
        if (edge === "topRight")
            return Qt.rect(width - hoverWidth, 0, hoverWidth, hoverHeight);
        if (edge === "bottomLeft")
            return Qt.rect(0, height - hoverHeight, hoverWidth, hoverHeight);
        if (edge === "bottomRight")
            return Qt.rect(width - hoverWidth, height - hoverHeight, hoverWidth, hoverHeight);
        return Qt.rect(0, 0, 0, 0);
    }

    function onWheel(event: WheelEvent): void {
        if (fullscreen)
            return;
        if (event.x < bar.implicitWidth) {
            bar.handleWheel(event.y, event.angleDelta);
        }
    }

    anchors.fill: parent
    acceptedButtons: fullscreen ? Qt.NoButton : Qt.AllButtons
    hoverEnabled: true

    onPressed: event => dragStart = Qt.point(event.x, event.y)
    onContainsMouseChanged: {
        if (!containsMouse) {
            // Only hide if not activated by shortcut
            if (!osdShortcutActive) {
                visibilities.osd = false;
                root.panels.osd.hovered = false;
            }

            if (!dashboardShortcutActive)
                visibilities.dashboard = false;

            if (!utilitiesShortcutActive)
                visibilities.utilities = false;

            // Close launcher only if opened via hover (not keybind) and user hasn't typed
            if (!visibilities.launcherShortcutActive && visibilities.launcher && !inBottomPanel(panels.launcher, mouseX, mouseY)) {
                visibilities.launcher = false;
            }

            if (!popouts.currentName.startsWith("traymenu") || ((popouts.current as StackView)?.depth ?? 0) <= 1) {
                popouts.hasCurrent = false;
                bar.closeTray();
            }

            if (Config.bar.showOnHover)
                bar.isHovered = false;
        }
    }

    onPositionChanged: event => {
        if (popouts.isDetached)
            return;

        const x = event.x;
        const y = event.y;
        const dragX = x - dragStart.x;
        const dragY = y - dragStart.y;

        if (fullscreen) {
            root.panels.osd.hovered = inRightPanel(panels.osdWrapper, x, y);
            return;
        }

        // Show bar in non-exclusive mode on hover
        if (!visibilities.bar && Config.bar.showOnHover && x < bar.clampedWidth)
            bar.isHovered = true;

        // Show/hide bar on drag
        if (pressed && dragStart.x < bar.clampedWidth) {
            if (dragX > Config.bar.dragThreshold)
                visibilities.bar = true;
            else if (dragX < -Config.bar.dragThreshold)
                visibilities.bar = false;
        }

        // Show sidebar on hover
        if (panels.sidebar.offsetScale === 1 && !visibilities.sidebar) {
            const sEdge = GlobalConfig.sidebar.hoverEdge || "topRight";
            if (inHoverArea(panels.sidebar, x, y, sEdge, GlobalConfig.sidebar.hoverWidth, GlobalConfig.sidebar.hoverHeight)) {
                visibilities.sidebar = true;
            }
        }

        if (panels.sidebar.offsetScale === 1) {
            // Show osd on hover
            const showOsd = inRightPanel(panels.osdWrapper, x, y);

            // Always update visibility based on hover if not in shortcut mode
            if (!osdShortcutActive) {
                visibilities.osd = showOsd;
                root.panels.osd.hovered = showOsd;
            } else if (showOsd) {
                // If hovering over OSD area while in shortcut mode, transition to hover control
                osdShortcutActive = false;
                root.panels.osd.hovered = true;
            }

            const showSidebar = pressed && dragStart.x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panels.sidebar.x);

            // Show/hide session on drag
            if (pressed && inRightPanel(panels.sessionWrapper, dragStart.x, dragStart.y) && withinPanelHeight(panels.sessionWrapper, x, y)) {
                if (dragX < -Config.session.dragThreshold)
                    visibilities.session = true;
                else if (dragX > Config.session.dragThreshold)
                    visibilities.session = false;

                // Show sidebar on drag if in session area and session is nearly fully visible
                if (showSidebar && panels.session.offsetScale <= 0 && dragX < -Config.sidebar.dragThreshold)
                    visibilities.sidebar = true;
            } else if (showSidebar && dragX < -Config.sidebar.dragThreshold) {
                // Show sidebar on drag if not in session area
                visibilities.sidebar = true;
            }
        } else {
            const outOfSidebar = x < width - panels.sidebar.width * (1 - panels.sidebar.offsetScale);
            // Show osd on hover
            const showOsd = outOfSidebar && inRightPanel(panels.osdWrapper, x, y);

            // Always update visibility based on hover if not in shortcut mode
            if (!osdShortcutActive) {
                visibilities.osd = showOsd;
                root.panels.osd.hovered = showOsd;
            } else if (showOsd) {
                // If hovering over OSD area while in shortcut mode, transition to hover control
                osdShortcutActive = false;
                root.panels.osd.hovered = true;
            }

            // Show/hide session on drag
            if (pressed && outOfSidebar && inRightPanel(panels.sessionWrapper, dragStart.x, dragStart.y) && withinPanelHeight(panels.sessionWrapper, x, y)) {
                if (dragX < -Config.session.dragThreshold)
                    visibilities.session = true;
                else if (dragX > Config.session.dragThreshold)
                    visibilities.session = false;
            }

            // Hide sidebar on drag
            if (pressed && inRightPanel(panels.sidebar, dragStart.x, 0) && dragX > Config.sidebar.dragThreshold)
                visibilities.sidebar = false;
        }

        // Show launcher on hover, or show/hide on drag if hover is disabled
        if (Config.launcher.showOnHover) {
            const lEdge = GlobalConfig.launcher.hoverEdge || "bottom";
            const inHover = inHoverArea(panels.launcher, x, y, lEdge, GlobalConfig.launcher.hoverWidth, GlobalConfig.launcher.hoverHeight);
            if (!visibilities.launcher && inHover) {
                visibilities.launcher = true;
                visibilities.launcherShortcutActive = false;
            }
            if (visibilities.launcher && !visibilities.launcherShortcutActive && !inHover && !inBottomPanel(panels.launcher, x, y) && !visibilities.launcherHasText) {
                visibilities.launcher = false;
            }
        } else if (pressed && inBottomPanel(panels.launcher, dragStart.x, dragStart.y) && withinPanelWidth(panels.launcher, x, y)) {
            if (dragY < -Config.launcher.dragThreshold)
                visibilities.launcher = true;
            else if (dragY > Config.launcher.dragThreshold)
                visibilities.launcher = false;
        }

        // Show dashboard on hover
        const dEdge = GlobalConfig.dashboard.hoverEdge || "top";
        const inDHover = Config.dashboard.showOnHover && inHoverArea(panels.dashboard, x, y, dEdge, GlobalConfig.dashboard.hoverWidth, GlobalConfig.dashboard.hoverHeight);
        const inDPanel = inTopPanel(panels.dashboard, x, y);

        // Always update visibility based on hover if not in shortcut mode
        if (!dashboardShortcutActive) {
            if (inDHover) {
                visibilities.dashboard = true;
            } else if (visibilities.dashboard && !inDPanel) {
                visibilities.dashboard = false;
            }
        } else if (inDHover) {
            // If hovering over dashboard area while in shortcut mode, transition to hover control
            dashboardShortcutActive = false;
        }

        // Show/hide dashboard on drag (for touchscreen devices)
        if (pressed && inTopPanel(panels.dashboard, dragStart.x, dragStart.y) && withinPanelWidth(panels.dashboard, x, y)) {
            if (dragY > Config.dashboard.dragThreshold)
                visibilities.dashboard = true;
            else if (dragY < -Config.dashboard.dragThreshold)
                visibilities.dashboard = false;
        }

        // Show utilities on hover
        const showUtilities = inBottomPanel(panels.utilities, x, y, true);

        // Always update visibility based on hover if not in shortcut mode
        if (!utilitiesShortcutActive) {
            visibilities.utilities = showUtilities;
        } else if (showUtilities) {
            // If hovering over utilities area while in shortcut mode, transition to hover control
            utilitiesShortcutActive = false;
        }

        // Show popouts on hover
        if (x < bar.implicitWidth) {
            bar.checkPopout(y);
        } else if ((!popouts.currentName.startsWith("traymenu") || ((popouts.current as StackView)?.depth ?? 0) <= 1) && !inLeftPanel(panels.popoutsWrapper, x, y)) {
            popouts.hasCurrent = false;
            bar.closeTray();
        }

        // Close sidebar on mouse move if opened via hover and mouse is outside sidebar area
        if (!sidebarShortcutActive && visibilities.sidebar) {
            const sEdge2 = GlobalConfig.sidebar.hoverEdge || "topRight";
            if (!inRightPanel(panels.sidebar, x, y) && !inHoverArea(panels.sidebar, x, y, sEdge2, GlobalConfig.sidebar.hoverWidth, GlobalConfig.sidebar.hoverHeight)) {
                visibilities.sidebar = false;
            }
        }
    }

    // Monitor individual visibility changes
    Connections {
        function onLauncherChanged() {
            if (root.visibilities.launcher) {
                const inLauncherArea = root.inBottomPanel(root.panels.launcher, root.mouseX, root.mouseY);
                if (!inLauncherArea) {
                    root.visibilities.launcherShortcutActive = true;
                }
                root.visibilities.launcherHasText = false;

            } else {
                root.visibilities.launcherShortcutActive = false;
            }
            if (!root.visibilities.launcher) {
                root.dashboardShortcutActive = false;
                root.osdShortcutActive = false;
                root.utilitiesShortcutActive = false;

                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                const inOsdArea = root.inRightPanel(root.panels.osdWrapper, root.mouseX, root.mouseY);

                if (!inDashboardArea) {
                    root.visibilities.dashboard = false;
                }
                if (!inOsdArea) {
                    root.visibilities.osd = false;
                    root.panels.osd.hovered = false;
                }
            }
        }

        function onDashboardChanged() {
            if (root.visibilities.dashboard) {
                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                if (!inDashboardArea) {
                    root.dashboardShortcutActive = true;
                }

            } else {
                root.dashboardShortcutActive = false;
            }
        }

        function onOsdChanged() {
            if (root.visibilities.osd) {
                // OSD became visible, immediately check if this should be shortcut mode
                const inOsdArea = root.inRightPanel(root.panels.osdWrapper, root.mouseX, root.mouseY);
                if (!inOsdArea) {
                    root.osdShortcutActive = true;
                }
            } else {
                // OSD hidden, clear shortcut flag
                root.osdShortcutActive = false;
            }
        }

        function onUtilitiesChanged() {
            if (root.visibilities.utilities) {
                // Utilities became visible, immediately check if this should be shortcut mode
                const inUtilitiesArea = root.inBottomPanel(root.panels.utilities, root.mouseX, root.mouseY);
                if (!inUtilitiesArea) {
                    root.utilitiesShortcutActive = true;
                }
            } else {
                // Utilities hidden, clear shortcut flag
                root.utilitiesShortcutActive = false;
            }
        }

        function onSidebarChanged() {
            if (root.visibilities.sidebar) {
                const cornerSize = 100;
                const inTopRightCorner = root.mouseX > root.width - cornerSize && root.mouseY < cornerSize;
                const inSidebarArea = root.inRightPanel(root.panels.sidebar, root.mouseX, root.mouseY);
                if (!inTopRightCorner && !inSidebarArea) {
                    root.sidebarShortcutActive = true;
                }

            } else {
                root.sidebarShortcutActive = false;
            }
        }

        target: root.visibilities
    }

    Rectangle {
        id: launcherIndicator

        visible: GlobalConfig.launcher.showHoverIndicator && Config.launcher.showOnHover

        property var geom: hoverAreaGeometry(GlobalConfig.launcher.hoverEdge, GlobalConfig.launcher.hoverWidth, GlobalConfig.launcher.hoverHeight)

        x: geom.x
        y: geom.y
        width: geom.width
        height: geom.height

        color: Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.15)
        border.color: Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.4)
        border.width: 2
        radius: 8

        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Rectangle {
        id: dashboardIndicator

        visible: GlobalConfig.dashboard.showHoverIndicator && Config.dashboard.showOnHover

        property var geom: hoverAreaGeometry(GlobalConfig.dashboard.hoverEdge, GlobalConfig.dashboard.hoverWidth, GlobalConfig.dashboard.hoverHeight)

        x: geom.x
        y: geom.y
        width: geom.width
        height: geom.height

        color: Qt.rgba(Colours.palette.m3tertiary.r, Colours.palette.m3tertiary.g, Colours.palette.m3tertiary.b, 0.15)
        border.color: Qt.rgba(Colours.palette.m3tertiary.r, Colours.palette.m3tertiary.g, Colours.palette.m3tertiary.b, 0.4)
        border.width: 2
        radius: 8

        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Rectangle {
        id: sidebarIndicator

        visible: GlobalConfig.sidebar.showHoverIndicator

        property var geom: hoverAreaGeometry(GlobalConfig.sidebar.hoverEdge, GlobalConfig.sidebar.hoverWidth, GlobalConfig.sidebar.hoverHeight)

        x: geom.x
        y: geom.y
        width: geom.width
        height: geom.height

        color: Qt.rgba(Colours.palette.m3secondary.r, Colours.palette.m3secondary.g, Colours.palette.m3secondary.b, 0.15)
        border.color: Qt.rgba(Colours.palette.m3secondary.r, Colours.palette.m3secondary.g, Colours.palette.m3secondary.b, 0.4)
        border.width: 2
        radius: 8

        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
}
