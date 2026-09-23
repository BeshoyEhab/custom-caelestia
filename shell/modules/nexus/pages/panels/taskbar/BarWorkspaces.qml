import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: qsTr("Workspaces")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StepperRow {
            first: true
            // TRANSLATORS: the number of workspaces shown on the bar
            label: qsTr("Shown")
            subtext: qsTr("Number of workspaces displayed")
            value: Config.bar.workspaces.shown
            from: 1
            to: 20
            stepSize: 1
            onMoved: v => GlobalConfig.bar.workspaces.shown = v
        }

        ToggleRow {
            text: qsTr("Active indicator")
            checked: Config.bar.workspaces.activeIndicator
            onToggled: GlobalConfig.bar.workspaces.activeIndicator = checked
        }

        ToggleRow {
            text: qsTr("Active trail")
            checked: Config.bar.workspaces.activeTrail
            onToggled: GlobalConfig.bar.workspaces.activeTrail = checked
        }

        ToggleRow {
            text: qsTr("Occupied background")
            checked: Config.bar.workspaces.occupiedBg
            onToggled: GlobalConfig.bar.workspaces.occupiedBg = checked
        }

        ToggleRow {
            text: qsTr("Show unoccupied")
            subtext: qsTr("Show workspaces that are inactive and empty")
            checked: Config.bar.workspaces.showUnoccupied
            onToggled: GlobalConfig.bar.workspaces.showUnoccupied = checked
        }

        ToggleRow {
            text: qsTr("Per monitor")
            subtext: qsTr("Hide workspaces not on the current monitor")
            checked: Config.bar.workspaces.perMonitor
            onToggled: GlobalConfig.bar.workspaces.perMonitor = checked
        }

        ToggleRow {
            text: qsTr("Show app icon")
            subtext: qsTr("Show the last focused app icon instead of dots/pacman")
            checked: Config.bar.workspaces.showAppIcon
            onToggled: GlobalConfig.bar.workspaces.showAppIcon = checked
        }

        SelectRow {
            label: qsTr("Workspace display")
            subtext: qsTr("Shapes, text or app icons in the bar")
            menuItems: [
                MenuItem {
                    text: qsTr("Shapes")
                },
                MenuItem {
                    text: qsTr("Text")
                },
                MenuItem {
                    text: qsTr("Icons")
                }
            ]
            active: menuItems[Config.bar.workspaces.displayType] ?? menuItems[2]
            onSelected: {
                const map = [0, 1, 2];
                GlobalConfig.bar.workspaces.displayType = map[menuItems.indexOf(item)] ?? 2;
            }
        }

        ToggleRow {
            text: qsTr("Show windows")
            subtext: qsTr("Show icons of open windows on each workspace")
            checked: Config.bar.workspaces.showWindows
            onToggled: GlobalConfig.bar.workspaces.showWindows = checked
        }

        ToggleRow {
            text: qsTr("Hover preview")
            subtext: qsTr("Show a workspace preview when hovering indicators")
            checked: Config.bar.workspaces.workspacePreviewEnabled ?? true
            onToggled: GlobalConfig.bar.workspaces.workspacePreviewEnabled = checked
        }

        ToggleRow {
            text: qsTr("Windows on special workspaces")
            checked: Config.bar.workspaces.showWindowsOnSpecialWorkspaces
            onToggled: GlobalConfig.bar.workspaces.showWindowsOnSpecialWorkspaces = checked
        }

        StepperRow {
            // TRANSLATORS: maximum number of window icons shown per workspace
            label: qsTr("Max window icons")
            value: Config.bar.workspaces.maxWindowIcons
            from: 0
            to: 20
            stepSize: 1
            onMoved: v => GlobalConfig.bar.workspaces.maxWindowIcons = v
        }

        SectionHeader {
            text: qsTr("Overview")
        }

        ToggleRow {
            text: qsTr("Enable overview")
            subtext: qsTr("Show workspace overview on shortcut press")
            checked: Config.bar.workspaces.overviewEnabled
            onToggled: GlobalConfig.bar.workspaces.overviewEnabled = checked
        }

        StepperRow {
            label: qsTr("Overview rows")
            subtext: qsTr("Number of workspace rows in the overview")
            value: Config.bar.workspaces.overviewRows
            from: 1
            to: 4
            stepSize: 1
            onMoved: v => GlobalConfig.bar.workspaces.overviewRows = v
        }

        StepperRow {
            label: qsTr("Overview columns")
            subtext: qsTr("Number of workspace columns in the overview")
            value: Config.bar.workspaces.overviewColumns
            from: 1
            to: 10
            stepSize: 1
            onMoved: v => GlobalConfig.bar.workspaces.overviewColumns = v
        }

        StepperRow {
            last: true
            label: qsTr("Overview scale")
            subtext: qsTr("Size of workspace previews (0.1-0.5)")
            value: Math.round(Config.bar.workspaces.overviewScale * 100)
            from: 10
            to: 50
            stepSize: 1
            onMoved: v => GlobalConfig.bar.workspaces.overviewScale = v / 100
        }
    }
}
