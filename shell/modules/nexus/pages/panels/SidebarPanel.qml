pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Sidebar")
    isSubPage: true

    readonly property list<MenuItem> edgeItems: [
        MenuItem { text: "TopRight" },
        MenuItem { text: "BottomRight" },
        MenuItem { text: "TopLeft" },
        MenuItem { text: "BottomLeft" },
        MenuItem { text: "Top" },
        MenuItem { text: "Bottom" },
        MenuItem { text: "Left" },
        MenuItem { text: "Right" }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Enabled")
            checked: Config.sidebar.enabled
            onToggled: GlobalConfig.sidebar.enabled = checked
        }

        StepperRow {
            Layout.fillWidth: true
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the sidebar opens")
            value: Config.sidebar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.sidebar.dragThreshold = v
        }

        // Hover area
        SectionHeader {
            text: qsTr("Hover area")
        }

        SelectRow {
            Layout.fillWidth: true
            first: true
            label: qsTr("Edge")
            subtext: qsTr("Screen edge that triggers the sidebar")
            menuItems: root.edgeItems
            active: root.edgeItems[{
                "topRight": 0, "bottomRight": 1, "topLeft": 2, "bottomLeft": 3,
                "top": 4, "bottom": 5, "left": 6, "right": 7
            }[GlobalConfig.sidebar.hoverEdge] ?? 0]
            onSelected: item => {
                const idx = root.edgeItems.indexOf(item);
                GlobalConfig.sidebar.hoverEdge = ["topRight","bottomRight","topLeft","bottomLeft","top","bottom","left","right"][idx];
            }
        }

        StepperRow {
            Layout.fillWidth: true
            label: qsTr("Hover width")
            subtext: qsTr("Width of the hover trigger area in pixels")
            value: GlobalConfig.sidebar.hoverWidth
            from: 10
            to: 500
            stepSize: 25
            onMoved: v => GlobalConfig.sidebar.hoverWidth = v
        }

        StepperRow {
            Layout.fillWidth: true
            label: qsTr("Hover height")
            subtext: qsTr("Height of the hover trigger area in pixels")
            value: GlobalConfig.sidebar.hoverHeight
            from: 10
            to: 500
            stepSize: 25
            onMoved: v => GlobalConfig.sidebar.hoverHeight = v
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Show hover area indicator")
            subtext: qsTr("Show a coloured overlay where the hover trigger zone is")
            checked: GlobalConfig.sidebar.showHoverIndicator
            onToggled: GlobalConfig.sidebar.showHoverIndicator = checked
        }

        TextButton {
            Layout.fillWidth: true
            text: qsTr("Reset hover area")
            onClicked: {
                GlobalConfig.sidebar.hoverEdge = "topRight";
                GlobalConfig.sidebar.hoverWidth = 60;
                GlobalConfig.sidebar.hoverHeight = 60;
                GlobalConfig.sidebar.showHoverIndicator = true;
                if (root.nState.screen && root.nState.screen.name) {
                    const monitorConfig = Config.forScreen(root.nState.screen.name);
                    if (monitorConfig && monitorConfig.sidebar) {
                        monitorConfig.sidebar.resetOption("hoverEdge");
                        monitorConfig.sidebar.resetOption("hoverWidth");
                        monitorConfig.sidebar.resetOption("hoverHeight");
                        monitorConfig.sidebar.resetOption("showHoverIndicator");
                    }
                }
            }
        }
    }
}
