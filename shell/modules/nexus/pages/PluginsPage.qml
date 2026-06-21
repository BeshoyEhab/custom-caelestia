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

    title: qsTr("Plugins")

    readonly property list<var> plugins: [
        {
            name: "CopyQ",
            description: qsTr("Clipboard history manager"),
            icon: "content_paste",
            processName: "copyq",
            installed: true
        },
        {
            name: "Emote",
            description: qsTr("Emoji picker"),
            icon: "mood",
            processName: "emote",
            installed: true
        },
        {
            name: "Pyprland",
            description: qsTr("Scratchpads, magnifier, corner helpers"),
            icon: "widgets",
            processName: "pypr",
            installed: true
        },
        {
            name: "Wayscriber",
            description: qsTr("Screen laser annotation tool"),
            icon: "draw",
            processName: "wayscriber",
            installed: true
        },
        {
            name: "Hyprland Per-Window Layout",
            description: qsTr("Automatic keyboard layout per window"),
            icon: "keyboard",
            processName: "hycov",
            installed: true
        },
        {
            name: "EasyEffects",
            description: qsTr("Audio effects and equalizer"),
            icon: "graphic_eq",
            processName: "easyeffects",
            installed: false
        },
        {
            name: "Tesseract OCR",
            description: qsTr("Optical character recognition from screenshots"),
            icon: "document_scanner",
            processName: "tesseract",
            installed: true
        }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Plugins")
        }

        Repeater {
            model: root.plugins

            ConnectedRect {
                Layout.fillWidth: true
                implicitHeight: pluginLayout.implicitHeight + pluginLayout.anchors.margins * 2
                first: index === 0
                last: index === root.plugins.length - 1

                required property var modelData
                required property int index

                RowLayout {
                    id: pluginLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: modelData.icon
                        color: modelData.installed ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.name
                            font: Tokens.font.body.small
                            color: modelData.installed ? Colours.palette.m3onSurface : Colours.palette.m3outline
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.installed ? modelData.description : qsTr("Not installed")
                            color: modelData.installed ? Colours.palette.m3outline : Colours.palette.m3error
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    MaterialIcon {
                        visible: modelData.installed
                        text: "check_circle"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.medium
                    }

                    MaterialIcon {
                        visible: !modelData.installed
                        text: "info"
                        color: Colours.palette.m3error
                        fontStyle: Tokens.font.icon.medium
                    }
                }
            }
        }

        SectionHeader {
            text: qsTr("Install new plugins")
        }

        InfoRow {
            first: true
            last: true
            label: qsTr("Additional plugins can be installed via the terminal.")
            value: qsTr("./install.sh")
        }
    }
}
