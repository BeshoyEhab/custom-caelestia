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
        { name: "Dynamic", primary: "#b4c7ed", secondary: "#bdc7dc", tertiary: "#eaddff", surface: "#0c0e12" },
        { name: "Catppuccin", primary: "#cba6f7", secondary: "#f5c2e7", tertiary: "#94e2d5", surface: "#1e1e2e" },
        { name: "Dracula", primary: "#bd93f9", secondary: "#50fa7b", tertiary: "#ff79c6", surface: "#282a36" },
        { name: "Everforest", primary: "#a7c080", secondary: "#dbbc7f", tertiary: "#e67e80", surface: "#2d353b" },
        { name: "Gruvbox", primary: "#d79921", secondary: "#b8bb26", tertiary: "#d3869b", surface: "#282828" },
        { name: "Nord", primary: "#88c0d0", secondary: "#a3be8c", tertiary: "#b48ead", surface: "#2e3440" },
        { name: "Old World", primary: "#d0b48c", secondary: "#8cb89a", tertiary: "#c4927a", surface: "#1a1614" },
        { name: "One Dark", primary: "#61afef", secondary: "#98c379", tertiary: "#c678dd", surface: "#282c34" },
        { name: "Rose Pine", primary: "#c4a7e7", secondary: "#3182ce", tertiary: "#eb6f92", surface: "#191724" },
        { name: "Solarized", primary: "#268bd2", secondary: "#2aa198", tertiary: "#6c71c4", surface: "#002b36" },
        { name: "Tokyo Night", primary: "#7aa2f7", secondary: "#9ece6a", tertiary: "#bb9af7", surface: "#1a1b26" },
        { name: "Caelestia", primary: "#b4c7ed", secondary: "#bdc7dc", tertiary: "#eaddff", surface: "#0c0e12" }
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
