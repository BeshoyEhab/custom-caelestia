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

    title: qsTr("Updates")

    property bool checking: false
    property string lastCheck: ""
    property string statusText: ""
    property bool scriptAvailable: false

    Component.onCompleted: scriptCheckProc.running = true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            id: scriptCheckProc
            command: ["test", "-x", "~/.config/quickshell/caelestia/scripts/update.sh"]
            onRunningChanged: {
                if (!running)
                    root.scriptAvailable = exitCode === 0;
            }
        }

        Process {
            id: updateCheckProc
            command: ["sh", "-c", "~/.config/quickshell/caelestia/scripts/update.sh --check"]
            onRunningChanged: {
                if (!running) {
                    root.checking = false;
                    root.lastCheck = new Date().toLocaleDateString();
                    if (exitCode === 0) {
                        root.statusText = qsTr("Up to date");
                    } else {
                        const lines = text.trim().split("\n");
                        const behind = lines.find(l => l.startsWith("BEHIND="))?.split("=")[1] ?? "0";
                        const stale = lines.find(l => l.startsWith("PLUGINS_STALE="))?.split("=")[1] ?? "false";
                        let parts = [];
                        if (parseInt(behind) > 0) parts.push(qsTr("%1 commits behind").arg(behind));
                        if (stale === "true") parts.push(qsTr("plugin source changed"));
                        root.statusText = parts.length > 0 ? parts.join(", ") : qsTr("Updates available");
                    }
                }
            }
        }

        Process {
            id: updateRunProc
            command: ["sh", "-c", "~/.config/quickshell/caelestia/scripts/update.sh --non-interactive 2>&1 | tail -5"]
            onRunningChanged: {
                if (!running) {
                    root.checking = false;
                    root.lastCheck = new Date().toLocaleDateString();
                    root.statusText = exitCode === 0 ? qsTr("Update complete") : qsTr("Update failed");
                }
            }
        }

        Process {
            id: deployRunProc
            command: ["sh", "-c", "~/.config/quickshell/caelestia/scripts/install.sh --non-interactive --no-install 2>&1 | tail -5"]
            onRunningChanged: {
                if (!running) {
                    root.checking = false;
                    root.statusText = exitCode === 0 ? qsTr("Deployment complete") : qsTr("Deployment failed");
                }
            }
        }

        Process {
            id: reloadRunProc
            command: ["sh", "-c", "pkill quickshell; sleep 0.5; qs -c caelestia &"]
            onRunningChanged: {
                if (!running) {
                    root.checking = false;
                    root.statusText = qsTr("Shell reloaded");
                }
            }
        }

        SectionHeader {
            first: true
            text: qsTr("Repository status")
        }

        InfoRow {
            first: true
            last: !root.scriptAvailable
            label: root.scriptAvailable ? (root.statusText || qsTr("custom-caelestia")) : qsTr("Repository not configured")
            value: root.scriptAvailable ? (root.lastCheck !== "" ? qsTr("Last checked: %1").arg(root.lastCheck) : "") : qsTr("Run install.sh first")
        }

        ConnectedRect {
            visible: !root.scriptAvailable
            Layout.fillWidth: true
            last: true
            implicitHeight: notConfiguredLayout.implicitHeight + notConfiguredLayout.anchors.margins * 2

            RowLayout {
                id: notConfiguredLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "info"
                    color: Colours.palette.m3error
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("The update scripts are not available. Please run install.sh from the repository to set up the configuration.")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }
            }
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
                    updateCheckProc.running = true;
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
                    updateRunProc.running = true;
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
                    deployRunProc.running = true;
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
                    reloadRunProc.running = true;
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
