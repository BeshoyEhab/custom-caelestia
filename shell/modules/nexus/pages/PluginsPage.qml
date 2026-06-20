pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
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
                Layout.preferredHeight: row.implicitHeight + Tokens.padding.medium * 2

                required property var modelData
                required property int index

                RowLayout {
                    id: row

                    anchors.centerIn: parent
                    width: parent.width - Tokens.padding.large * 2
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: modelData.icon
                        color: modelData.installed ? Colours.palette.m3primary : Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.large
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: modelData.name
                            font: Tokens.font.title.medium
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            text: modelData.description
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    MaterialIcon {
                        text: modelData.installed ? "check_circle" : "cancel"
                        color: modelData.installed ? Colours.palette.m3tertiary : Colours.palette.m3error
                        fontStyle: Tokens.font.icon.medium
                    }
                }
            }
        }

        SectionHeader {
            text: qsTr("Install new plugins")
        }

        ConnectedRect {
            Layout.fillWidth: true
            Layout.preferredHeight: installColumn.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: installColumn

                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "info"
                    color: Colours.palette.m3outlineVariant
                    fontStyle: Tokens.font.icon.extraLarge
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Additional plugins can be installed via the terminal.")
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Run ./install.sh to configure components")
                    font: Tokens.font.label.large
                    color: Colours.palette.m3outline
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
