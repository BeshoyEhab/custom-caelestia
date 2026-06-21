pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
        "dynamic", "catppuccin", "dracula", "everforest", "gruvbox",
        "nord", "oldworld", "onedark", "rosepine", "solarized",
        "tokyonight", "caelestia"
    ]

    readonly property list<string> variantNames: [
        "tonalspot", "vibrant", "expressive", "fidelity",
        "fruitsalad", "monochrome", "neutral", "rainbow", "content"
    ]

    property string currentScheme: Colours.scheme || "dynamic"
    property string currentVariant: "tonalspot"

    Process {
        id: schemeSetProc

        property string pendingScheme
        property string pendingMode

        command: ["sh", "-c"]
        onRunningChanged: {
            if (!running && exitCode === 0) {
                root.currentScheme = pendingScheme;
                if (pendingMode)
                    root.currentMode = pendingMode;
            }
        }
    }

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

        // Scheme selection
        SectionHeader {
            text: qsTr("Colour scheme")
        }

        SelectRow {
            first: true
            label: qsTr("Scheme")
            subtext: qsTr("Base colour palette")
            menuItems: Variants {
                model: root.schemeNames
                MenuItem {
                    required property string modelData
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    icon: modelData === root.currentScheme ? "check" : ""
                }
            }
            active: menuItems.find(i => i.text.toLowerCase() === root.currentScheme) ?? null
            onSelected: item => {
                const scheme = item.text.toLowerCase();
                schemeSetProc.command = ["sh", "-c", `caelestia scheme set -n ${scheme} --notify`];
                schemeSetProc.pendingScheme = scheme;
                schemeSetProc.running = true;
            }
        }

        SelectRow {
            last: true
            label: qsTr("Variant")
            subtext: qsTr("Colour expression style")
            menuItems: Variants {
                model: root.variantNames
                MenuItem {
                    required property string modelData
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    icon: modelData === root.currentVariant ? "check" : ""
                }
            }
            active: menuItems.find(i => i.text.toLowerCase() === root.currentVariant) ?? null
            onSelected: item => {
                const variant = item.text.toLowerCase();
                schemeSetProc.command = ["sh", "-c", `caelestia scheme set -v ${variant} --notify`];
                schemeSetProc.pendingScheme = root.currentScheme;
                schemeSetProc.running = true;
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
