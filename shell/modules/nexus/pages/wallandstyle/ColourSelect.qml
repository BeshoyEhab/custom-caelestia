pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Colours")
    isSubPage: true

    readonly property list<var> schemes: [
        { name: "Dynamic", primary: Qt.rgba(0.706, 0.780, 0.929, 1), secondary: Qt.rgba(0.741, 0.780, 0.875, 1), tertiary: Qt.rgba(0.918, 0.867, 1.0, 1), surface: Qt.rgba(0.047, 0.055, 0.071, 1) },
        { name: "Catppuccin", primary: Qt.rgba(0.800, 0.651, 0.969, 1), secondary: Qt.rgba(0.961, 0.761, 0.914, 1), tertiary: Qt.rgba(0.580, 0.886, 0.835, 1), surface: Qt.rgba(0.118, 0.118, 0.180, 1) },
        { name: "Dracula", primary: Qt.rgba(0.741, 0.576, 0.976, 1), secondary: Qt.rgba(0.314, 0.980, 0.482, 1), tertiary: Qt.rgba(1.0, 0.475, 0.776, 1), surface: Qt.rgba(0.157, 0.165, 0.212, 1) },
        { name: "Everforest", primary: Qt.rgba(0.655, 0.753, 0.502, 1), secondary: Qt.rgba(0.859, 0.733, 0.498, 1), tertiary: Qt.rgba(0.902, 0.494, 0.502, 1), surface: Qt.rgba(0.176, 0.208, 0.231, 1) },
        { name: "Gruvbox", primary: Qt.rgba(0.843, 0.600, 0.129, 1), secondary: Qt.rgba(0.722, 0.733, 0.149, 1), tertiary: Qt.rgba(0.827, 0.525, 0.608, 1), surface: Qt.rgba(0.157, 0.157, 0.157, 1) },
        { name: "Nord", primary: Qt.rgba(0.533, 0.753, 0.816, 1), secondary: Qt.rgba(0.639, 0.745, 0.549, 1), tertiary: Qt.rgba(0.706, 0.553, 0.678, 1), surface: Qt.rgba(0.180, 0.204, 0.251, 1) },
        { name: "Old World", primary: Qt.rgba(0.816, 0.706, 0.549, 1), secondary: Qt.rgba(0.549, 0.722, 0.604, 1), tertiary: Qt.rgba(0.769, 0.573, 0.478, 1), surface: Qt.rgba(0.102, 0.086, 0.078, 1) },
        { name: "One Dark", primary: Qt.rgba(0.380, 0.686, 0.937, 1), secondary: Qt.rgba(0.596, 0.765, 0.482, 1), tertiary: Qt.rgba(0.776, 0.471, 0.867, 1), surface: Qt.rgba(0.157, 0.173, 0.204, 1) },
        { name: "Rose Pine", primary: Qt.rgba(0.769, 0.655, 0.906, 1), secondary: Qt.rgba(0.192, 0.510, 0.804, 1), tertiary: Qt.rgba(0.922, 0.435, 0.573, 1), surface: Qt.rgba(0.098, 0.090, 0.141, 1) },
        { name: "Solarized", primary: Qt.rgba(0.149, 0.545, 0.824, 1), secondary: Qt.rgba(0.165, 0.631, 0.596, 1), tertiary: Qt.rgba(0.424, 0.443, 0.765, 1), surface: Qt.rgba(0.0, 0.169, 0.212, 1) },
        { name: "Tokyo Night", primary: Qt.rgba(0.478, 0.635, 0.969, 1), secondary: Qt.rgba(0.612, 0.800, 0.416, 1), tertiary: Qt.rgba(0.714, 0.604, 0.969, 1), surface: Qt.rgba(0.102, 0.106, 0.149, 1) },
        { name: "Caelestia", primary: Qt.rgba(0.706, 0.780, 0.929, 1), secondary: Qt.rgba(0.741, 0.780, 0.875, 1), tertiary: Qt.rgba(0.918, 0.867, 1.0, 1), surface: Qt.rgba(0.047, 0.055, 0.071, 1) }
    ]

    readonly property list<string> variantNames: [
        "tonalspot", "vibrant", "expressive", "fidelity",
        "fruitsalad", "monochrome", "neutral", "rainbow", "content"
    ]

    property string currentScheme: Colours.scheme || "dynamic"
    property string currentVariant: "tonalspot"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            id: schemeSetProc

            property string pendingScheme

            command: ["sh", "-c"]
            onRunningChanged: {
                if (!running && exitCode === 0)
                    root.currentScheme = pendingScheme;
            }
        }

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

        // Scheme selection as colour buttons
        SectionHeader {
            text: qsTr("Colour scheme")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: schemeGrid.implicitHeight + schemeGrid.anchors.margins * 2

            GridLayout {
                id: schemeGrid

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                columns: 4
                rowSpacing: Tokens.spacing.small
                columnSpacing: Tokens.spacing.small

                Repeater {
                    model: root.schemes

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        color: modelData.surface
                        radius: Tokens.rounding.medium
                        border.color: modelData.name.toLowerCase() === root.currentScheme
                            ? Colours.palette.m3primary
                            : "transparent"
                        border.width: modelData.name.toLowerCase() === root.currentScheme ? 2 : 0

                        StateLayer {
                            onClicked: {
                                const scheme = modelData.name.toLowerCase();
                                schemeSetProc.command = ["sh", "-c", `caelestia scheme set -n ${scheme} --notify`];
                                schemeSetProc.pendingScheme = scheme;
                                schemeSetProc.running = true;
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Row {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 4

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: modelData.primary
                                }

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: modelData.secondary
                                }

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: modelData.tertiary
                                }
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.name
                                color: modelData.name.toLowerCase() === root.currentScheme
                                    ? Colours.palette.m3primary
                                    : Colours.palette.m3onSurface
                                font: Tokens.font.label.small
                            }
                        }
                    }
                }
            }
        }

        // Variant selection
        SectionHeader {
            text: qsTr("Variant")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: variantRow.implicitHeight + variantRow.anchors.margins * 2

            Flow {
                id: variantRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                Repeater {
                    model: root.variantNames

                    Rectangle {
                        width: variantLabel.implicitWidth + Tokens.padding.large * 2
                        height: 32
                        color: modelData === root.currentVariant
                            ? Colours.palette.m3primaryContainer
                            : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                        radius: Tokens.rounding.full

                        StateLayer {
                            onClicked: {
                                schemeSetProc.command = ["sh", "-c", `caelestia scheme set -v ${modelData} --notify`];
                                schemeSetProc.pendingScheme = root.currentScheme;
                                schemeSetProc.running = true;
                            }
                        }

                        StyledText {
                            id: variantLabel

                            anchors.centerIn: parent
                            text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                            color: modelData === root.currentVariant
                                ? Colours.palette.m3onPrimaryContainer
                                : Colours.palette.m3onSurface
                            font: Tokens.font.label.small
                        }
                    }
                }
            }
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

        // Current palette preview
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
