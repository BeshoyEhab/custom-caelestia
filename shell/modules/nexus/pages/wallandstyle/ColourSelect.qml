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

    readonly property list<string> schemeNames: [
        "dynamic", "catppuccin", "dracula", "everforest",
        "gruvbox", "nord", "oldworld", "onedark",
        "rosepine", "solarized", "tokyonight", "caelestia"
    ]

    readonly property list<string> schemeLabels: [
        "Dynamic", "Catppuccin", "Dracula", "Everforest",
        "Gruvbox", "Nord", "Old World", "One Dark",
        "Rose Pine", "Solarized", "Tokyo Night", "Caelestia"
    ]

    readonly property list<string> schemeSurfaces: [
        "#0c0e12", "#1e1e2e", "#282a36", "#2d353b",
        "#282828", "#2e3440", "#1a1614", "#282c34",
        "#191724", "#002b36", "#1a1b26", "#0c0e12"
    ]

    readonly property list<string> schemePrimaries: [
        "#b4c7ed", "#cba6f7", "#bd93f9", "#a7c080",
        "#d79921", "#88c0d0", "#d0b48c", "#61afef",
        "#c4a7e7", "#268bd2", "#7aa2f7", "#b4c7ed"
    ]

    readonly property list<string> schemeSecondaries: [
        "#bdc7dc", "#f5c2e7", "#50fa7b", "#dbbc7f",
        "#b8bb26", "#a3be8c", "#8cb89a", "#98c379",
        "#3182ce", "#2aa198", "#9ece6a", "#bdc7dc"
    ]

    readonly property list<string> schemeTertiaries: [
        "#eaddff", "#94e2d5", "#ff79c6", "#e67e80",
        "#d3869b", "#b48ead", "#c4927a", "#c678dd",
        "#eb6f92", "#6c71c4", "#bb9af7", "#eaddff"
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
                    model: root.schemeNames.length

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        color: root.schemeSurfaces[index]
                        radius: Tokens.rounding.medium
                        border.color: root.schemeNames[index] === root.currentScheme
                            ? Colours.palette.m3primary
                            : "transparent"
                        border.width: root.schemeNames[index] === root.currentScheme ? 2 : 0

                        StateLayer {
                            onClicked: {
                                const scheme = root.schemeNames[index];
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
                                    color: root.schemePrimaries[index]
                                }

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: root.schemeSecondaries[index]
                                }

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: root.schemeTertiaries[index]
                                }
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.schemeLabels[index]
                                color: root.schemeNames[index] === root.currentScheme
                                    ? Colours.palette.m3primary
                                    : Colours.palette.m3onSurface
                                font: Tokens.font.label.small
                            }
                        }
                    }
                }
            }
        }

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

        SectionHeader {
            text: qsTr("Transparency")
        }

        ToggleRow {
            first: true
            text: qsTr("Enable transparency")
            checked: Colours.transparency.enabled
            onToggled: GlobalConfig.appearance.transparency.enabled = checked
        }

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
                        { label: "Primary", val: Colours.palette.m3primary },
                        { label: "On Primary", val: Colours.palette.m3onPrimary },
                        { label: "Primary Container", val: Colours.palette.m3primaryContainer },
                        { label: "On Primary Container", val: Colours.palette.m3onPrimaryContainer },
                        { label: "Secondary", val: Colours.palette.m3secondary }
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: modelData.val
                        radius: Tokens.rounding.extraSmall

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: modelData.label.includes("On") ? Colours.palette.m3onSurface : Colours.palette.m3onPrimary
                            font: Tokens.font.label.small
                        }
                    }
                }

                Repeater {
                    model: [
                        { label: "On Secondary", val: Colours.palette.m3onSecondary },
                        { label: "Secondary Container", val: Colours.palette.m3secondaryContainer },
                        { label: "On Secondary Container", val: Colours.palette.m3onSecondaryContainer },
                        { label: "Tertiary", val: Colours.palette.m3tertiary },
                        { label: "On Tertiary", val: Colours.palette.m3onTertiary }
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: modelData.val
                        radius: Tokens.rounding.extraSmall

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: modelData.label.includes("On") ? Colours.palette.m3onSurface : Colours.palette.m3onPrimary
                            font: Tokens.font.label.small
                        }
                    }
                }

                Repeater {
                    model: [
                        { label: "Surface", val: Colours.palette.m3surface },
                        { label: "On Surface", val: Colours.palette.m3onSurface },
                        { label: "Surface Variant", val: Colours.palette.m3surfaceVariant },
                        { label: "On Surface Variant", val: Colours.palette.m3onSurfaceVariant },
                        { label: "Outline", val: Colours.palette.m3outline }
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: modelData.val
                        radius: Tokens.rounding.extraSmall

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: modelData.label.includes("On") ? Colours.palette.m3onSurface : Colours.palette.m3onPrimary
                            font: Tokens.font.label.small
                        }
                    }
                }
            }
        }

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
