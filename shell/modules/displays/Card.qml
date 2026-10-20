pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

FocusScope {
    id: root

    signal close

    readonly property bool hasSecond: Displays.monitors.filter(m => m.name !== Displays.mainName).length > 0
    readonly property var otherMonitors: Displays.monitors.filter(m => m.name !== Displays.mainName)

    implicitWidth: 880
    implicitHeight: column.implicitHeight + Tokens.padding.largeIncreased * 2
    focus: true

    Keys.onEscapePressed: root.close()

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3surfaceContainerHigh
        border.width: 1
        border.color: Colours.palette.m3outlineVariant
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.large

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: "monitor"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.large
            }

            StyledText {
                text: "Displays"
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.medium
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Text
                onClicked: Displays.refresh()
            }

            IconButton {
                icon: "close"
                type: IconButton.Text
                onClicked: root.close()
            }
        }

        LayoutPreview {
            Layout.fillWidth: true
            Layout.preferredHeight: 210
            monitors: Displays.monitors
            mainName: Displays.mainName
        }

        StyledText {
            Layout.fillWidth: true
            visible: !root.hasSecond
            wrapMode: Text.WordWrap
            text: "Only one display is connected. Plug in a second screen to duplicate it, extend the desktop, or move this screen's output to the other one."
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            ToggleButton {
                toggled: Displays.mode === "main"
                icon: "monitor"
                label: "Main only"
                disabled: !root.hasSecond
                opacity: disabled ? 0.5 : 1
                onClicked: Displays.setMode("main")
            }

            ToggleButton {
                toggled: Displays.mode === "duplicate"
                icon: "content_copy"
                label: "Duplicate"
                disabled: !root.hasSecond
                opacity: disabled ? 0.5 : 1
                onClicked: Displays.setMode("duplicate")
            }

            ToggleButton {
                toggled: Displays.mode === "extend"
                icon: "desktop_windows"
                label: "Extend"
                disabled: !root.hasSecond
                opacity: disabled ? 0.5 : 1
                onClicked: Displays.setMode("extend")
            }

            ToggleButton {
                toggled: Displays.mode === "second"
                icon: "tv"
                label: "Second only"
                disabled: !root.hasSecond
                opacity: disabled ? 0.5 : 1
                onClicked: Displays.setMode("second")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            visible: Displays.mode === "extend"

            StyledText {
                text: "Second screen position"
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }

            RowLayout {
                spacing: Tokens.spacing.small

                ToggleButton {
                    toggled: Displays.placement === "left"
                    icon: "arrow_back"
                    label: "Left"
                    onClicked: Displays.setPlacement("left")
                }

                ToggleButton {
                    toggled: Displays.placement === "top"
                    icon: "arrow_upward"
                    label: "Top"
                    onClicked: Displays.setPlacement("top")
                }

                ToggleButton {
                    toggled: Displays.placement === "right"
                    icon: "arrow_forward"
                    label: "Right"
                    onClicked: Displays.setPlacement("right")
                }

                ToggleButton {
                    toggled: Displays.placement === "bottom"
                    icon: "arrow_downward"
                    label: "Bottom"
                    onClicked: Displays.setPlacement("bottom")
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                text: "Main screen"
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                orientation: ListView.Horizontal
                spacing: Tokens.spacing.small
                clip: true
                model: Displays.activeMonitors

                delegate: ToggleButton {
                    required property var modelData

                    toggled: modelData.name === Displays.mainName
                    icon: modelData.name === Displays.mainName ? "star" : "monitor"
                    label: modelData.name
                    onClicked: Displays.setMain(modelData.name)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            visible: root.otherMonitors.length > 1

            StyledText {
                text: "Second screen"
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                orientation: ListView.Horizontal
                spacing: Tokens.spacing.small
                clip: true
                model: root.otherMonitors

                delegate: ToggleButton {
                    required property var modelData

                    toggled: modelData.name === Displays.secondaryName
                    icon: "tv"
                    label: modelData.name
                    onClicked: Displays.setSecondary(modelData.name)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium
            enabled: root.hasSecond
            opacity: enabled ? 1 : 0.5

            MaterialIcon {
                text: "workspaces"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                Layout.fillWidth: true
                text: "Second screen opens workspace"
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.medium
            }

            IconButton {
                icon: "remove"
                type: IconButton.Tonal
                disabled: Displays.pinnedWorkspace <= 1
                onClicked: Displays.setPinnedWorkspace(Displays.pinnedWorkspace - 1)
            }

            StyledText {
                Layout.preferredWidth: 28
                horizontalAlignment: Text.AlignHCenter
                text: String(Displays.pinnedWorkspace)
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.small
            }

            IconButton {
                icon: "add"
                type: IconButton.Tonal
                disabled: Displays.pinnedWorkspace >= 10
                onClicked: Displays.setPinnedWorkspace(Displays.pinnedWorkspace + 1)
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: Displays.busy
            text: "Applying…"
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }
    }
}
