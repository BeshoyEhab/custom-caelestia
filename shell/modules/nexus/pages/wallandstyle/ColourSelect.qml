pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Colours")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Theme mode
        SectionHeader {
            first: true
            text: qsTr("Theme")
        }

        ToggleRow {
            first: true
            text: qsTr("Dark mode")
            checked: !Colours.light
            onToggled: Colours.setMode(checked ? "dark" : "light")
        }

        // Transparency
        SectionHeader {
            text: qsTr("Transparency")
        }

        ToggleRow {
            first: true
            text: qsTr("Enable transparency")
            checked: Colours.transparency.enabled
            onToggled: GlobalConfig.appearance.transparency.enabled = checked
        }

        // Colour preview
        SectionHeader {
            text: qsTr("Current palette")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: paletteGrid.implicitHeight + paletteGrid.anchors.margins * 2

            GridLayout {
                id: paletteGrid

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                columns: 5
                rowSpacing: Tokens.spacing.small
                columnSpacing: Tokens.spacing.small

                // Primary colours
                Repeater {
                    model: [
                        { name: "Primary", color: Colours.palette.m3primary },
                        { name: "On Primary", color: Colours.palette.m3onPrimary },
                        { name: "Primary Container", color: Colours.palette.m3primaryContainer },
                        { name: "On Primary Container", color: Colours.palette.m3onPrimaryContainer },
                        { name: "Secondary", color: Colours.palette.m3secondary }
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: modelData.color
                        radius: Tokens.rounding.extraSmall

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.name
                            color: modelData.name.includes("On") ? Colours.palette.m3onSurface : Colours.palette.m3onPrimary
                            font: Tokens.font.label.small
                        }
                    }
                }

                // Secondary colours
                Repeater {
                    model: [
                        { name: "On Secondary", color: Colours.palette.m3onSecondary },
                        { name: "Secondary Container", color: Colours.palette.m3secondaryContainer },
                        { name: "On Secondary Container", color: Colours.palette.m3onSecondaryContainer },
                        { name: "Tertiary", color: Colours.palette.m3tertiary },
                        { name: "On Tertiary", color: Colours.palette.m3onTertiary }
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: modelData.color
                        radius: Tokens.rounding.extraSmall

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.name
                            color: modelData.name.includes("On") ? Colours.palette.m3onSurface : Colours.palette.m3onPrimary
                            font: Tokens.font.label.small
                        }
                    }
                }

                // Surface colours
                Repeater {
                    model: [
                        { name: "Surface", color: Colours.palette.m3surface },
                        { name: "On Surface", color: Colours.palette.m3onSurface },
                        { name: "Surface Variant", color: Colours.palette.m3surfaceVariant },
                        { name: "On Surface Variant", color: Colours.palette.m3onSurfaceVariant },
                        { name: "Outline", color: Colours.palette.m3outline }
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: modelData.color
                        radius: Tokens.rounding.extraSmall

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.name
                            color: modelData.name.includes("On") ? Colours.palette.m3onSurface : Colours.palette.m3onPrimary
                            font: Tokens.font.label.small
                        }
                    }
                }
            }
        }

        // Wallpaper
        SectionHeader {
            text: qsTr("Wallpaper")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Display wallpaper")
            checked: Config.background.wallpaperEnabled
            onToggled: GlobalConfig.background.wallpaperEnabled = checked
        }
    }
}
