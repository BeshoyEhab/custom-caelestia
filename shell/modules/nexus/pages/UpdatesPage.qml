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

    title: qsTr("Updates")

    property bool checking: false
    property string lastCheck: ""
    property string statusText: ""

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            id: updateChecker

            interval: 2000
            onTriggered: {
                root.checking = false;
                root.lastCheck = new Date().toLocaleDateString();
                root.statusText = qsTr("Up to date");
            }
        }

        Timer {
            id: updateRunner

            interval: 3000
            onTriggered: {
                root.checking = false;
                root.lastCheck = new Date().toLocaleDateString();
                root.statusText = qsTr("Update complete");
            }
        }

        Timer {
            id: deployRunner

            interval: 2000
            onTriggered: {
                root.checking = false;
                root.statusText = qsTr("Deployment complete");
            }
        }

        Timer {
            id: reloadRunner

            interval: 1000
            onTriggered: {
                root.checking = false;
                root.statusText = qsTr("Shell reloaded");
            }
        }

        SectionHeader {
            first: true
            text: qsTr("Repository status")
        }

        InfoRow {
            first: true
            last: true
            label: root.statusText || qsTr("custom-caelestia")
            value: root.lastCheck !== "" ? qsTr("Last checked: %1").arg(root.lastCheck) : ""
        }

        SectionHeader {
            text: qsTr("Actions")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            implicitHeight: actionLayout.implicitHeight + actionLayout.anchors.margins * 2

            StateLayer {
                disabled: root.checking
                onClicked: {
                    root.checking = true;
                    root.statusText = qsTr("Checking...");
                    updateChecker.start();
                }
            }

            RowLayout {
                id: actionLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "refresh"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Check for updates")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.checking && root.statusText === qsTr("Checking...")
                        text: root.statusText
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: pullLayout.implicitHeight + pullLayout.anchors.margins * 2

            StateLayer {
                disabled: root.checking
                onClicked: {
                    root.checking = true;
                    root.statusText = qsTr("Updating...");
                    updateRunner.start();
                }
            }

            RowLayout {
                id: pullLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "download"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Update repository")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.checking && root.statusText === qsTr("Updating...")
                        text: root.statusText
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: deployLayout.implicitHeight + deployLayout.anchors.margins * 2

            StateLayer {
                disabled: root.checking
                onClicked: {
                    root.checking = true;
                    root.statusText = qsTr("Deploying...");
                    deployRunner.start();
                }
            }

            RowLayout {
                id: deployLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "folder_special"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Deploy configurations")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.checking && root.statusText === qsTr("Deploying...")
                        text: root.statusText
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            last: true
            implicitHeight: reloadLayout.implicitHeight + reloadLayout.anchors.margins * 2

            StateLayer {
                disabled: root.checking
                onClicked: {
                    root.checking = true;
                    root.statusText = qsTr("Reloading...");
                    reloadRunner.start();
                }
            }

            RowLayout {
                id: reloadLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "restart_alt"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Reload shell")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.checking && root.statusText === qsTr("Reloading...")
                        text: root.statusText
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }
            }
        }

        SectionHeader {
            text: qsTr("Information")
        }

        InfoRow {
            first: true
            last: true
            label: qsTr("custom-caelestia combines the Caelestia shell with fast keybinds and utilities.")
        }
    }
}
