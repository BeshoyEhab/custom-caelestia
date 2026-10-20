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

    implicitWidth: 1100
    implicitHeight: 760
    focus: true

    Keys.onEscapePressed: root.close()

    Component.onCompleted: search.forceActiveFocus()

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3surfaceContainerHigh
        border.width: 1
        border.color: Colours.palette.m3outlineVariant
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: "keyboard"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.large
            }

            StyledText {
                text: "Keyboard shortcuts"
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.medium
            }

            StyledText {
                Layout.fillWidth: true
                text: `${KeybindsModel.bindCount} shortcuts in ${KeybindsModel.groups.length} groups`
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            ToggleButton {
                toggled: KeybindsModel.includeUnlabeled
                icon: "help"
                label: "Unlabeled"
                tooltip: "Show binds that have no description in the config"
                onClicked: KeybindsModel.includeUnlabeled = !KeybindsModel.includeUnlabeled
            }

            IconButton {
                icon: "close"
                type: IconButton.Text
                onClicked: root.close()
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: Tokens.rounding.medium
            color: Colours.palette.m3surfaceContainerHighest

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "search"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                }

                StyledTextField {
                    id: search

                    Layout.fillWidth: true
                    placeholderText: "Search by action, key or group…"
                    focus: true
                    onTextChanged: KeybindsModel.query = text
                }

                IconButton {
                    icon: "backspace"
                    type: IconButton.Text
                    visible: search.text.length > 0
                    onClicked: {
                        search.text = "";
                        search.forceActiveFocus();
                    }
                }
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: KeybindsModel.rows

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: list
            }

            delegate: Item {
                id: row

                required property var modelData

                width: list.width
                height: modelData.kind === "header" ? 46 : 12 + Math.max(1, (modelData.combos || []).length) * 36

                HoverHandler {
                    id: rowHover
                }

                StyledRect {
                    anchors.fill: parent
                    anchors.leftMargin: -Tokens.padding.small
                    anchors.rightMargin: -Tokens.padding.small
                    radius: Tokens.rounding.small
                    color: Colours.palette.m3surfaceContainerHighest
                    opacity: rowHover.hovered && row.modelData.kind === "bind" ? 0.4 : 0
                    Behavior on opacity {
                        Anim {
                            type: Anim.StandardSmall
                        }
                    }
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    visible: row.modelData.kind === "header"
                    text: visible ? `${row.modelData.label}  ·  ${row.modelData.count}` : ""
                    color: Colours.palette.m3primary
                    font: Tokens.font.title.small
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.medium
                    visible: row.modelData.kind === "bind"

                    // One line per equivalent key combo: same description means
                    // the same action, so they share the row.
                    ListView {
                        id: keyList

                        Layout.preferredWidth: 290
                        Layout.preferredHeight: Math.max(1, (row.modelData.combos || []).length) * 36
                        interactive: false
                        clip: true
                        model: row.modelData.combos

                        delegate: Row {
                            id: comboRow

                            required property var modelData

                            width: keyList.width
                            height: 32
                            spacing: 3

                            function token(index) {
                                const keys = comboRow.modelData.keys ?? [];
                                return index < keys.length ? keys[index] : "";
                            }

                            KeyCap {
                                label: comboRow.token(0)
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: comboRow.token(1).length > 0
                                text: "+"
                                color: Colours.palette.m3outline
                                font: Tokens.font.body.small
                            }

                            KeyCap {
                                label: comboRow.token(1)
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: comboRow.token(2).length > 0
                                text: "+"
                                color: Colours.palette.m3outline
                                font: Tokens.font.body.small
                            }

                            KeyCap {
                                label: comboRow.token(2)
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: comboRow.token(3).length > 0
                                text: "+"
                                color: Colours.palette.m3outline
                                font: Tokens.font.body.small
                            }

                            KeyCap {
                                label: comboRow.token(3)
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: comboRow.token(4).length > 0
                                text: "+"
                                color: Colours.palette.m3outline
                                font: Tokens.font.body.small
                            }

                            KeyCap {
                                label: comboRow.token(4)
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: row.modelData.kind === "bind" ? row.modelData.action : ""
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.medium
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                text: "Type to search"
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: "Esc to close"
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: KeybindsModel.rows.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: KeybindsModel.lastError.length > 0 ? KeybindsModel.lastError : "No shortcuts match that search."
            color: KeybindsModel.lastError.length > 0 ? Colours.palette.m3error : Colours.palette.m3outline
            font: Tokens.font.body.medium
        }
    }

// One key of a shortcut, drawn like a physical keycap. Kept as an inline
// component: a Repeater over a JS array of tokens does not render in this
// Quickshell build (see AGENTS.md), so the row spells out five slots.
component KeyCap: StyledRect {
    id: cap

    property string label

    visible: label.length > 0
    implicitWidth: capText.implicitWidth + Tokens.padding.small * 2
    implicitHeight: 32
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHighest
    border.width: 1
    border.color: Colours.palette.m3outlineVariant

    StyledText {
        id: capText

        anchors.centerIn: parent
        text: cap.label
        color: Colours.palette.m3onSurface
        font: Tokens.font.body.medium
    }
}
}
