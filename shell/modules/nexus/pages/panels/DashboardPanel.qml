pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Dashboard")
    isSubPage: true

    readonly property list<MenuItem> edgeItems: [
        MenuItem { text: "Top" },
        MenuItem { text: "Bottom" },
        MenuItem { text: "Left" },
        MenuItem { text: "Right" },
        MenuItem { text: "TopLeft" },
        MenuItem { text: "TopRight" },
        MenuItem { text: "BottomLeft" },
        MenuItem { text: "BottomRight" }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Enabled")
            checked: Config.dashboard.enabled
            onToggled: GlobalConfig.dashboard.enabled = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Show on hover")
            subtext: qsTr("Reveal when the cursor reaches the screen edge")
            checked: Config.dashboard.showOnHover
            onToggled: GlobalConfig.dashboard.showOnHover = checked
        }

        // Hover area
        SectionHeader {
            text: qsTr("Hover area")
        }

        SelectRow {
            Layout.fillWidth: true
            first: true
            label: qsTr("Edge")
            subtext: qsTr("Screen edge that triggers the dashboard")
            menuItems: root.edgeItems
            active: root.edgeItems[{
                "top": 0, "bottom": 1, "left": 2, "right": 3,
                "topLeft": 4, "topRight": 5, "bottomLeft": 6, "bottomRight": 7
            }[GlobalConfig.dashboard.hoverEdge] ?? 0]
            onSelected: item => {
                const idx = root.edgeItems.indexOf(item);
                GlobalConfig.dashboard.hoverEdge = ["top","bottom","left","right","topLeft","topRight","bottomLeft","bottomRight"][idx];
            }
        }

        StepperRow {
            Layout.fillWidth: true
            label: qsTr("Hover width")
            subtext: qsTr("Width of the hover trigger area in pixels")
            value: GlobalConfig.dashboard.hoverWidth
            from: 10
            to: 1920
            stepSize: 50
            onMoved: v => GlobalConfig.dashboard.hoverWidth = v
        }

        StepperRow {
            Layout.fillWidth: true
            label: qsTr("Hover height")
            subtext: qsTr("Height of the hover trigger area in pixels")
            value: GlobalConfig.dashboard.hoverHeight
            from: 10
            to: 200
            stepSize: 10
            onMoved: v => GlobalConfig.dashboard.hoverHeight = v
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Show hover area indicator")
            subtext: qsTr("Show a coloured overlay where the hover trigger zone is")
            checked: GlobalConfig.dashboard.showHoverIndicator
            onToggled: GlobalConfig.dashboard.showHoverIndicator = checked
        }

        TextButton {
            Layout.fillWidth: true
            text: qsTr("Reset hover area")
            onClicked: {
                GlobalConfig.dashboard.hoverEdge = "top";
                GlobalConfig.dashboard.hoverWidth = 850;
                GlobalConfig.dashboard.hoverHeight = 20;
                GlobalConfig.dashboard.showHoverIndicator = true;
                if (root.nState.screen && root.nState.screen.name) {
                    const monitorConfig = Config.forScreen(root.nState.screen.name);
                    if (monitorConfig && monitorConfig.dashboard) {
                        monitorConfig.dashboard.resetOption("hoverEdge");
                        monitorConfig.dashboard.resetOption("hoverWidth");
                        monitorConfig.dashboard.resetOption("hoverHeight");
                        monitorConfig.dashboard.resetOption("showHoverIndicator");
                    }
                }
            }
        }

        // Tabs
        SectionHeader {
            text: qsTr("Tabs")
        }

        ToggleRow {
            first: true
            text: qsTr("Dashboard")
            checked: Config.dashboard.showDashboard
            onToggled: GlobalConfig.dashboard.showDashboard = checked
        }

        ToggleRow {
            text: qsTr("Media")
            checked: Config.dashboard.showMedia
            onToggled: GlobalConfig.dashboard.showMedia = checked
        }

        ToggleRow {
            text: qsTr("Performance")
            checked: Config.dashboard.showPerformance
            onToggled: GlobalConfig.dashboard.showPerformance = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Weather")
            checked: Config.dashboard.showWeather
            onToggled: GlobalConfig.dashboard.showWeather = checked
        }

        // Performance widgets
        SectionHeader {
            text: qsTr("Performance widgets")
        }

        ToggleRow {
            first: true
            text: qsTr("Battery")
            checked: Config.dashboard.performance.showBattery
            onToggled: GlobalConfig.dashboard.performance.showBattery = checked
        }

        ToggleRow {
            text: qsTr("GPU")
            checked: Config.dashboard.performance.showGpu
            onToggled: GlobalConfig.dashboard.performance.showGpu = checked
        }

        ToggleRow {
            text: qsTr("CPU")
            checked: Config.dashboard.performance.showCpu
            onToggled: GlobalConfig.dashboard.performance.showCpu = checked
        }

        ToggleRow {
            text: qsTr("Memory")
            checked: Config.dashboard.performance.showMemory
            onToggled: GlobalConfig.dashboard.performance.showMemory = checked
        }

        ToggleRow {
            text: qsTr("Storage")
            checked: Config.dashboard.performance.showStorage
            onToggled: GlobalConfig.dashboard.performance.showStorage = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Network")
            checked: Config.dashboard.performance.showNetwork
            onToggled: GlobalConfig.dashboard.performance.showNetwork = checked
        }

        // Behaviour
        SectionHeader {
            text: qsTr("Behaviour")
        }

        StepperRow {
            first: true
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the dashboard opens")
            value: Config.dashboard.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.dashboard.dragThreshold = v
        }
    }
}
