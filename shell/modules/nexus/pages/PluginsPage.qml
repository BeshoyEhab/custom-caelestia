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
            installed: true
        },
        {
            name: "Emote",
            description: qsTr("Emoji picker"),
            icon: "mood",
            installed: true
        },
        {
            name: "Pyprland",
            description: qsTr("Scratchpads, magnifier, corner helpers"),
            icon: "widgets",
            installed: true
        },
        {
            name: "Wayscriber",
            description: qsTr("Screen laser annotation tool"),
            icon: "draw",
            installed: true
        },
        {
            name: "Hyprland Per-Window Layout",
            description: qsTr("Automatic keyboard layout per window"),
            icon: "keyboard",
            installed: true
        },
        {
            name: "EasyEffects",
            description: qsTr("Audio effects and equalizer"),
            icon: "graphic_eq",
            installed: false
        },
        {
            name: "Tesseract OCR",
            description: qsTr("Optical character recognition from screenshots"),
            icon: "document_scanner",
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
            text: qsTr("Installed plugins")
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
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.name
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.description
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    MaterialIcon {
                        text: modelData.installed ? "check_circle" : "cancel"
                        color: Colours.palette.m3onSurfaceVariant
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
