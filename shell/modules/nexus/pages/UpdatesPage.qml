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
    property string busyAction: ""
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
            command: ["sh", "-c", "test -x ~/.config/quickshell/caelestia/scripts/update.sh"]
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
                    root.busyAction = "";
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
            command: ["sh", "-c", "set -o pipefail; ~/.config/quickshell/caelestia/scripts/update.sh --non-interactive 2>&1 | tail -5"]
            onRunningChanged: {
                if (!running) {
                    root.checking = false;
                    root.busyAction = "";
                    root.lastCheck = new Date().toLocaleDateString();
                    root.statusText = exitCode === 0 ? qsTr("Update complete") : qsTr("Update failed");
                }
            }
        }

        Process {
            id: deployRunProc
            command: ["sh", "-c", "set -o pipefail; ~/.config/quickshell/caelestia/scripts/install.sh --non-interactive --no-install 2>&1 | tail -5"]
            onRunningChanged: {
                if (!running) {
                    root.checking = false;
                    root.busyAction = "";
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

        RowButton {
            first: true
            icon: "refresh"
            text: qsTr("Check for updates")
            subtext: root.busyAction === "check" ? root.statusText : ""
            disabled: root.checking
            onClicked: {
                root.checking = true;
                root.busyAction = "check";
                root.statusText = qsTr("Checking...");
                updateCheckProc.running = true;
            }
        }

        RowButton {
            icon: "download"
            text: qsTr("Update repository")
            subtext: root.busyAction === "update" ? root.statusText : ""
            disabled: root.checking
            onClicked: {
                root.checking = true;
                root.busyAction = "update";
                root.statusText = qsTr("Updating...");
                updateRunProc.running = true;
            }
        }

        RowButton {
            icon: "folder_special"
            text: qsTr("Deploy configurations")
            subtext: root.busyAction === "deploy" ? root.statusText : ""
            disabled: root.checking
            onClicked: {
                root.checking = true;
                root.busyAction = "deploy";
                root.statusText = qsTr("Deploying...");
                deployRunProc.running = true;
            }
        }

        RowButton {
            last: true
            icon: "restart_alt"
            text: qsTr("Reload shell")
            subtext: root.busyAction === "reload" ? root.statusText : ""
            disabled: root.checking
            onClicked: {
                root.checking = true;
                root.busyAction = "reload";
                root.statusText = qsTr("Reloading...");
                reloadRunProc.running = true;
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
