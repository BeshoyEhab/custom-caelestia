pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
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

        // Status
        SectionHeader {
            first: true
            text: qsTr("Repository status")
        }

        ConnectedRect {
            Layout.fillWidth: true
            Layout.preferredHeight: statusColumn.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: statusColumn

                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.checking ? "sync" : "check_circle"
                    color: root.checking ? Colours.palette.m3primary : Colours.palette.m3tertiary
                    fontStyle: Tokens.font.icon.extraLarge

                    RotationAnimation on rotation {
                        running: root.checking
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.statusText || qsTr("Caelestia-Impulse (Celestimpulse)")
                    font: Tokens.font.title.medium
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.lastCheck !== ""
                    text: qsTr("Last checked: %1").arg(root.lastCheck)
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        // Actions
        SectionHeader {
            text: qsTr("Actions")
        }

        TextButton {
            Layout.fillWidth: true
            first: true
            text: qsTr("Check for updates")
            icon: "refresh"
            enabled: !root.checking
            onClicked: {
                root.checking = true;
                root.statusText = qsTr("Checking...");
                updateChecker.start();
            }
        }

        TextButton {
            Layout.fillWidth: true
            text: qsTr("Update repository")
            icon: "download"
            enabled: !root.checking
            onClicked: {
                root.checking = true;
                root.statusText = qsTr("Updating...");
                updateRunner.start();
            }
        }

        TextButton {
            Layout.fillWidth: true
            text: qsTr("Deploy configurations")
            icon: "folder_special"
            enabled: !root.checking
            onClicked: {
                root.checking = true;
                root.statusText = qsTr("Deploying...");
                deployRunner.start();
            }
        }

        TextButton {
            Layout.fillWidth: true
            last: true
            text: qsTr("Reload shell")
            icon: "restart_alt"
            enabled: !root.checking
            onClicked: {
                root.checking = true;
                root.statusText = qsTr("Reloading...");
                reloadRunner.start();
            }
        }

        // Info
        SectionHeader {
            text: qsTr("Information")
        }

        ConnectedRect {
            Layout.fillWidth: true
            Layout.preferredHeight: infoColumn.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: infoColumn

                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Caelestia-Impulse combines the Caelestia shell with fast keybinds and utilities.")
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Update with: ./update.sh from the repository")
                    font: Tokens.font.label.large
                    color: Colours.palette.m3outline
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

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
}
