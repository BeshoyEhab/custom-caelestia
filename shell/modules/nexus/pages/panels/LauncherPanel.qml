pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Launcher")
    isSubPage: true

    readonly property list<MenuItem> edgeItems: [
        MenuItem { text: "Bottom" },
        MenuItem { text: "Top" },
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
            checked: Config.launcher.enabled
            onToggled: GlobalConfig.launcher.enabled = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Show on hover")
            subtext: qsTr("Reveal when the cursor reaches the screen edge")
            checked: Config.launcher.showOnHover
            onToggled: GlobalConfig.launcher.showOnHover = checked
        }

        // Hover area
        SectionHeader {
            text: qsTr("Hover area")
        }

        SelectRow {
            Layout.fillWidth: true
            first: true
            label: qsTr("Edge")
            subtext: qsTr("Screen edge that triggers the launcher")
            menuItems: root.edgeItems
            active: root.edgeItems[{
                "bottom": 0, "top": 1, "left": 2, "right": 3,
                "topLeft": 4, "topRight": 5, "bottomLeft": 6, "bottomRight": 7
            }[GlobalConfig.launcher.hoverEdge] ?? 0]
            onSelected: item => {
                const idx = root.edgeItems.indexOf(item);
                GlobalConfig.launcher.hoverEdge = ["bottom","top","left","right","topLeft","topRight","bottomLeft","bottomRight"][idx];
            }
        }

        StepperRow {
            Layout.fillWidth: true
            label: qsTr("Hover width")
            subtext: qsTr("Width of the hover trigger area in pixels")
            value: GlobalConfig.launcher.hoverWidth
            from: 10
            to: 1920
            stepSize: 50
            onMoved: v => GlobalConfig.launcher.hoverWidth = v
        }

        StepperRow {
            Layout.fillWidth: true
            label: qsTr("Hover height")
            subtext: qsTr("Height of the hover trigger area in pixels")
            value: GlobalConfig.launcher.hoverHeight
            from: 10
            to: 200
            stepSize: 10
            onMoved: v => GlobalConfig.launcher.hoverHeight = v
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Show hover area indicator")
            subtext: qsTr("Show a coloured overlay where the hover trigger zone is")
            checked: GlobalConfig.launcher.showHoverIndicator
            onToggled: GlobalConfig.launcher.showHoverIndicator = checked
        }

        TextButton {
            Layout.fillWidth: true
            text: qsTr("Reset hover area")
            onClicked: {
                GlobalConfig.launcher.hoverEdge = "bottom";
                GlobalConfig.launcher.hoverWidth = 600;
                GlobalConfig.launcher.hoverHeight = 20;
                GlobalConfig.launcher.showHoverIndicator = true;
                if (root.nState.screen && root.nState.screen.name) {
                    const monitorConfig = Config.forScreen(root.nState.screen.name);
                    if (monitorConfig && monitorConfig.launcher) {
                        monitorConfig.launcher.resetOption("hoverEdge");
                        monitorConfig.launcher.resetOption("hoverWidth");
                        monitorConfig.launcher.resetOption("hoverHeight");
                        monitorConfig.launcher.resetOption("showHoverIndicator");
                    }
                }
            }
        }

        // Display
        SectionHeader {
            text: qsTr("Display")
        }

        StepperRow {
            first: true
            label: qsTr("Max items shown")
            value: Config.launcher.maxShown
            from: 1
            to: 20
            stepSize: 1
            onMoved: v => GlobalConfig.launcher.maxShown = v
        }

        StepperRow {
            label: qsTr("Max wallpapers")
            value: Config.launcher.maxWallpapers
            from: 1
            to: 30
            stepSize: 1
            onMoved: v => GlobalConfig.launcher.maxWallpapers = v
        }

        StepperRow {
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the launcher opens")
            value: Config.launcher.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.launcher.dragThreshold = v
        }

        // Behaviour
        SectionHeader {
            text: qsTr("Behaviour")
        }

        ToggleRow {
            first: true
            text: qsTr("Vim keybinds")
            subtext: qsTr("Navigate results with Ctrl+hjkl")
            checked: GlobalConfig.launcher.vimKeybinds
            onToggled: GlobalConfig.launcher.vimKeybinds = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Enable dangerous actions")
            subtext: qsTr("Allow actions that shut down or log out")
            checked: GlobalConfig.launcher.enableDangerousActions
            onToggled: GlobalConfig.launcher.enableDangerousActions = checked
        }

        // Fuzzy search
        SectionHeader {
            text: qsTr("Fuzzy search")
        }

        ToggleRow {
            first: true
            text: qsTr("Apps")
            checked: GlobalConfig.launcher.useFuzzy.apps
            onToggled: GlobalConfig.launcher.useFuzzy.apps = checked
        }

        ToggleRow {
            text: qsTr("Actions")
            checked: GlobalConfig.launcher.useFuzzy.actions
            onToggled: GlobalConfig.launcher.useFuzzy.actions = checked
        }

        ToggleRow {
            text: qsTr("Schemes")
            checked: GlobalConfig.launcher.useFuzzy.schemes
            onToggled: GlobalConfig.launcher.useFuzzy.schemes = checked
        }

        ToggleRow {
            text: qsTr("Variants")
            checked: GlobalConfig.launcher.useFuzzy.variants
            onToggled: GlobalConfig.launcher.useFuzzy.variants = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Wallpapers")
            checked: GlobalConfig.launcher.useFuzzy.wallpapers
            onToggled: GlobalConfig.launcher.useFuzzy.wallpapers = checked
        }

        // Calculator
        SectionHeader {
            text: qsTr("Calculator")
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Auto-detect expressions")
            subtext: qsTr("Show calculator for math expressions like 2+3*4")
            checked: GlobalConfig.launcher.calcAutoDetect !== false
            onToggled: GlobalConfig.launcher.calcAutoDetect = checked
        }

        // Search
        SectionHeader {
            text: qsTr("Search")
        }

        ToggleRow {
            Layout.fillWidth: true
            last: true
            text: qsTr("Sort by frequency")
            subtext: qsTr("Show frequently used apps first")
            checked: GlobalConfig.launcher.sortByFrequency !== false
            onToggled: GlobalConfig.launcher.sortByFrequency = checked
        }
    }
}
