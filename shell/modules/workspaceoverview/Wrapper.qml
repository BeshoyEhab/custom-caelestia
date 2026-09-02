pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property DrawerVisibilities visibilities

    readonly property bool shouldBeActive: visibilities.workspaceOverview && Config.bar.workspaces.overviewEnabled
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(QsWindow.window?.screen ?? null)
    readonly property int activeWsId: GlobalConfig.bar.workspaces.perMonitorWorkspaces ? (monitor?.activeWorkspace?.id ?? 1) : Hypr.activeWsId
    readonly property int rows: Config.bar.workspaces.overviewRows ?? 2
    readonly property int columns: Config.bar.workspaces.overviewColumns ?? 5
    readonly property real overviewScale: Config.bar.workspaces.overviewScale ?? 0.18

    readonly property real cardPadding: 20
    readonly property real cardSpacing: 10
    readonly property real wsWidth: (QsWindow.window?.width ?? 1920) * overviewScale
    readonly property real wsHeight: (QsWindow.window?.height ?? 1080) * overviewScale
    readonly property real cardWidth: columns * wsWidth + (columns - 1) * cardSpacing + cardPadding * 2
    readonly property real cardHeight: rows * wsHeight + (rows - 1) * cardSpacing + cardPadding * 2

    visible: opacity > 0
    opacity: shouldBeActive ? 1 : 0
    anchors.fill: parent

    focus: shouldBeActive

    Connections {
        target: root.visibilities
        function onLauncherChanged() { if (root.visibilities.launcher) root.visibilities.workspaceOverview = false; }
        function onDashboardChanged() { if (root.visibilities.dashboard) root.visibilities.workspaceOverview = false; }
        function onUtilitiesChanged() { if (root.visibilities.utilities) root.visibilities.workspaceOverview = false; }
        function onSidebarChanged() { if (root.visibilities.sidebar) root.visibilities.workspaceOverview = false; }
        function onSessionChanged() { if (root.visibilities.session) root.visibilities.workspaceOverview = false; }
    }

    // Floating card background
    StyledRect {
        id: cardBg

        anchors.centerIn: parent
        width: root.cardWidth
        height: root.cardHeight
        radius: Tokens.rounding.extraLarge
        color: Colours.layer(Colours.palette.m3surfaceContainer, 3)
        border.width: 1
        border.color: Colours.layer(Colours.palette.m3outline, 0.2)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3shadow
            shadowOpacity: 0.4
            shadowBlur: 0.8
        }

        OverviewGrid {
            id: overviewGrid

            anchors.centerIn: parent
            activeWsId: root.activeWsId
            overviewOpen: root.shouldBeActive
            rows: root.rows
            columns: root.columns
            wsWidth: root.wsWidth
            wsHeight: root.wsHeight
            cardSpacing: root.cardSpacing
            overviewScale: root.overviewScale
            onClose: root.visibilities.workspaceOverview = false
        }
    }

    // Click outside card closes overview
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        propagateComposedEvents: true
        onPressed: mouse => {
            const lp = mapToItem(cardBg, mouse.x, mouse.y);
            if (lp.x < 0 || lp.y < 0 || lp.x > cardBg.width || lp.y > cardBg.height) {
                mouse.accepted = true;
            } else {
                mouse.accepted = false;
            }
        }
        onReleased: mouse => {
            const lp = mapToItem(cardBg, mouse.x, mouse.y);
            if (lp.x < 0 || lp.y < 0 || lp.x > cardBg.width || lp.y > cardBg.height) {
                root.visibilities.workspaceOverview = false;
            }
        }
    }

    Keys.onEscapePressed: root.visibilities.workspaceOverview = false

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
